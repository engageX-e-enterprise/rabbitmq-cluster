-- Ensure schema
CREATE SCHEMA IF NOT EXISTS "public";



INSERT INTO public."_ef_migrations_history" (migration_id,product_version) VALUES
	 ('20231030110221_matrerialized_views','7.0.5');


-- Create table "ad_user"
CREATE TABLE IF NOT EXISTS "public"."ad_user" (
    "id" TEXT NOT NULL,
    "display_name" TEXT,
    "email" TEXT,
    "mobile" TEXT,
    "status" TEXT,
    "allowed_permission" TEXT,
    CONSTRAINT "pk_ad_user" PRIMARY KEY ("id")
);

-- Create table "application"
CREATE TABLE IF NOT EXISTS "public"."application" (
    "code" VARCHAR(100) NOT NULL,
    "name" VARCHAR(100),
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "application_secret" TEXT NOT NULL,
    "application_url" TEXT NOT NULL,
    CONSTRAINT "pk_application" PRIMARY KEY ("code")
);

-- Create table "sms_notification"
CREATE TABLE IF NOT EXISTS "public"."sms_notification" (
    "Id" SERIAL NOT NULL,
    "corelation_id" UUID NOT NULL,
    "transaction_id" TEXT,
    "template_id" UUID,
    "message" TEXT,
    "language" VARCHAR(20),
    "mobile_number" VARCHAR(20),
    "created_on" TIMESTAMP NOT NULL,
    "modified_on" TIMESTAMP,
    "acknowledged_on" TIMESTAMP,
    "status" VARCHAR(20),
    "application_code" VARCHAR(20),
    "senderName" VARCHAR(11),
    "is_otp" BOOLEAN NOT NULL DEFAULT false,
    "number_of_segments" INTEGER NOT NULL,
    CONSTRAINT "pk_sms_notification" PRIMARY KEY ("Id")
);

-- Create table "template"
CREATE TABLE IF NOT EXISTS "public"."template" (
    "id" UUID NOT NULL,
    "name" VARCHAR(100),
    "body" TEXT,
    "locale" TEXT,
    "application_code" VARCHAR(100),
    "created_on" TIMESTAMP NOT NULL,
    "isActive" BOOLEAN NOT NULL,
    "is_otp" BOOLEAN NOT NULL DEFAULT false,
    "variables" TEXT,
    CONSTRAINT "pk_template" PRIMARY KEY ("id"),
    CONSTRAINT "fk_template_application_application_temp_id" FOREIGN KEY ("application_code") REFERENCES "public"."application" ("code")
);

-- Indexes
CREATE INDEX IF NOT EXISTS "ix_application_code" ON "public"."application" ("code");
CREATE INDEX IF NOT EXISTS "ix_sms_notification_application_code" ON "public"."sms_notification" ("application_code");
CREATE INDEX IF NOT EXISTS "ix_sms_notification_created_on" ON "public"."sms_notification" ("created_on");
CREATE INDEX IF NOT EXISTS "ix_sms_notification_status" ON "public"."sms_notification" ("status");
CREATE INDEX IF NOT EXISTS "ix_sms_notification_template_id" ON "public"."sms_notification" ("template_id");
CREATE INDEX IF NOT EXISTS "ix_sms_notification_transaction_id" ON "public"."sms_notification" ("transaction_id");
CREATE INDEX IF NOT EXISTS "ix_template_application_code" ON "public"."template" ("application_code");



using Humanizer;
using Microsoft.EntityFrameworkCore.Migrations;
using Notification.Engine.API.Domain.Entities;
using Notification.Engine.API.Endpoints.sms;
using System.Security.Policy;
using System.Text.RegularExpressions;

#nullable disable

namespace Notification.Engine.API.Migrations
{
    /// <inheritdoc />
    public partial class matrerializedviews : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // message count by status ..
            migrationBuilder.Sql(@"
                CREATE MATERIALIZED VIEW if not exists public.mv_message_count_by_status
                TABLESPACE pg_default
                AS WITH all_statuses AS (
                            SELECT 'Queued'::text AS status
                        UNION ALL
                            SELECT 'Sent'::text AS status
                        UNION ALL
                            SELECT 'Delivered'::text AS status
                        UNION ALL
                            SELECT 'Failed'::text AS status
                        UNION ALL
                            SELECT 'Scheduled'::text AS status
                        )
                    SELECT all_statuses.status,
                    sum(
                        CASE
                            WHEN sms.status::text = all_statuses.status THEN 1
                            ELSE 0
                        END) AS message_count
                    FROM all_statuses
                        LEFT JOIN sms_notification sms ON all_statuses.status = sms.status::text
                    GROUP BY all_statuses.status
                WITH DATA;
            ");

            migrationBuilder.Sql(@"CREATE UNIQUE INDEX if not exists idx_mv_message_count_by_status ON mv_message_count_by_status (status);");

            // message count by language
            migrationBuilder.Sql(@"
                CREATE MATERIALIZED VIEW if not exists mv_message_count_by_language AS
                SELECT language, COUNT(*) as message_count
                FROM sms_notification
                GROUP BY language;
            ");

            migrationBuilder.Sql(@"CREATE UNIQUE INDEX if not exists idx_mv_message_count_by_language ON mv_message_count_by_language (language);");

            migrationBuilder.Sql(@"
                CREATE MATERIALIZED VIEW if not exists mv_message_count_by_application AS
                    SELECT application_code, COUNT(*) as message_count
                    FROM sms_notification s
                    where s.application_code  is not Null
                GROUP BY application_code;
            ");

            migrationBuilder.Sql(@"CREATE UNIQUE INDEX if not exists idx_mv_message_count_by_application
                ON mv_message_count_by_application (application_code);
            ");

            migrationBuilder.Sql(@"
                CREATE MATERIALIZED VIEW if not exists mv_message_count_by_template AS
                SELECT s.template_id, t.name, COUNT(*) as message_count
                FROM sms_notification s
                INNER JOIN ""template"" t ON t.id = s.template_id 
                WHERE s.template_id IS NOT NULL 
                GROUP BY s.template_id, t.name;
            ");

            migrationBuilder.Sql(@"CREATE UNIQUE INDEX if not exists idx_message_count_by_template
                ON mv_message_count_by_template (template_id, name);
            ");

            migrationBuilder.Sql(@"
                CREATE MATERIALIZED VIEW if not exists mv_message_acknowledgment_rate AS
                SELECT
                    COUNT(*) AS total_messages,
                    COUNT(acknowledged_on) AS acknowledged_messages,
                    CASE
                    WHEN COUNT(*) = 0 THEN NULL
                    ELSE(COUNT(acknowledged_on)::float / NULLIF(COUNT(*), 0) * 100)
                    END AS acknowledgment_rate
                FROM sms_notification;
            ");

            migrationBuilder.Sql(@"CREATE UNIQUE INDEX if not exists idx_mv_message_acknowledgment_rate
                ON mv_message_acknowledgment_rate (total_messages);");

            migrationBuilder.Sql(@"
                CREATE MATERIALIZED VIEW if not exists mv_message_failure_rate AS
                SELECT
                    COUNT(*) AS total_messages,
                    COUNT(CASE WHEN status = 'failed' THEN 1 END) AS failed_messages,
                    CASE
                    WHEN COUNT(*) = 0 THEN NULL
                    ELSE(COUNT(CASE WHEN status = 'failed' THEN 1 END)::float / NULLIF(COUNT(*), 0) * 100)
                    END AS failure_rate
                    FROM sms_notification;
            ");

            migrationBuilder.Sql(@"CREATE UNIQUE INDEX if not exists idx_mv_message_failure_rate
                            ON mv_message_failure_rate (total_messages);
                           ");
            migrationBuilder.Sql(@"
                CREATE MATERIALIZED VIEW mv_average_response_time AS
                SELECT AVG(EXTRACT(EPOCH FROM (acknowledged_on - created_on))) as avg_response_time_seconds
                FROM sms_notification
                WHERE acknowledged_on IS NOT NULL;
                            ");
            migrationBuilder.Sql(@"CREATE UNIQUE INDEX if not exists idx_mv_average_response_time
                            ON mv_average_response_time (avg_response_time_seconds);
            ");

            migrationBuilder.Sql(@"            
                CREATE MATERIALIZED VIEW  if not exists mv_top_sender_names AS
                SELECT ""senderName"", COUNT(*) as message_count
                FROM sms_notification
                GROUP BY ""senderName""
                ORDER BY message_count DESC
                LIMIT 10;
                            ");
            migrationBuilder.Sql(@"CREATE UNIQUE INDEX if not exists idx_mv_top_sender_names
                            ON mv_top_sender_names (""senderName"");
            ");
            migrationBuilder.Sql(@"
                CREATE MATERIALIZED VIEW if not exists mv_otp_usage_rate AS
                    SELECT
                        COUNT(*) AS total_messages,
                        COUNT(CASE WHEN is_otp THEN 1 END) AS otp_messages,
                        CASE
                            WHEN COUNT(*) = 0 THEN NULL
                            ELSE(COUNT(CASE WHEN is_otp THEN 1 END)::float / NULLIF(COUNT(*), 0) * 100)
                        END AS otp_usage_rate
                    FROM sms_notification;
             ");
            migrationBuilder.Sql(@"CREATE UNIQUE INDEX if not exists idx_mv_otp_usage_rate
                            ON mv_otp_usage_rate (total_messages);
            ");
            migrationBuilder.Sql(@"
                            CREATE MATERIALIZED VIEW  if not exists mv_message_volume_trend AS
                            SELECT DATE_TRUNC('day', created_on) as message_date,
                                   COUNT(*) as message_count
                            FROM sms_notification
                            GROUP BY message_date
                            ORDER BY message_date;
                            ");
            migrationBuilder.Sql(@"CREATE UNIQUE INDEX if not exists idx_message_volume_trend
                            ON mv_message_volume_trend (message_date);
                           ");
            migrationBuilder.Sql(@"
                            CREATE MATERIALIZED VIEW if not exists message_sent_by_day_of_week AS
            WITH weekdays AS(
              SELECT generate_series(
                       date_trunc('week', current_date),
                       date_trunc('week', current_date) + interval '6 days',
                       interval '1 day'
                     )::date AS day
            )
            SELECT
                TO_CHAR(w.day, 'Day') AS day_of_week,
                COALESCE(COUNT(sms.created_on), 0) AS count,
                COALESCE(COUNT(CASE WHEN sms.is_otp THEN 1 END), 0) AS otp_count
            FROM weekdays w
            LEFT JOIN sms_notification sms
                ON w.day::date = sms.created_on::date
            WHERE
                w.day >= date_trunc('week', current_date)-- Start of current week
                AND w.day < date_trunc('week', current_date) + interval '7 days'-- End of current week
            GROUP BY
                w.day, day_of_week
            ORDER BY
                w.day;");
            migrationBuilder.Sql(@"CREATE UNIQUE INDEX if not exists idx_message_sent_by_day_of_week
                            ON message_sent_by_day_of_week (day_of_week);
                            ");
            migrationBuilder.Sql(@"
                            CREATE MATERIALIZED VIEW if not exists message_sent_by_hour_of_day AS
                                WITH hour_list AS(
                                  SELECT generate_series(0, 23) AS hour_of_day
                                )
                                SELECT
                                  LPAD(hour_list.hour_of_day::text, 2, '0') || ':00 AM' AS hour_of_day,
                                  COALESCE(COUNT(sms.created_on), 0) AS message_count
                                FROM
                                  hour_list
                                LEFT JOIN
                                  sms_notification AS sms
                                  ON EXTRACT(HOUR FROM sms.created_on AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Dubai') = hour_list.hour_of_day
                                  AND sms.created_on >= NOW() - INTERVAL '1 day'
                                GROUP BY
                                  hour_list.hour_of_day
                                ORDER BY
                                  hour_list.hour_of_day;

                            ");

            migrationBuilder.Sql(@"CREATE UNIQUE INDEX if not exists idx_message_sent_by_hour_of_day
                            ON message_sent_by_hour_of_day (hour_of_day);
                            ");


            // refresh fucntions to refresh the data in the views. 
            migrationBuilder.Sql(@"
                            CREATE OR REPLACE FUNCTION refresh_materialized_views()
                            RETURNS void AS
                            $$
                            BEGIN
                                -- Refresh your materialized views here
                                REFRESH MATERIALIZED VIEW CONCURRENTLY message_sent_by_hour_of_day;         
                                REFRESH MATERIALIZED VIEW CONCURRENTLY message_sent_by_day_of_week;   
                                REFRESH MATERIALIZED VIEW CONCURRENTLY mv_message_volume_trend;
                                REFRESH MATERIALIZED VIEW CONCURRENTLY mv_otp_usage_rate;
                                REFRESH MATERIALIZED VIEW CONCURRENTLY mv_top_sender_names;
                                REFRESH MATERIALIZED VIEW CONCURRENTLY mv_average_response_time;
                                REFRESH MATERIALIZED VIEW CONCURRENTLY mv_message_failure_rate;
                                REFRESH MATERIALIZED VIEW CONCURRENTLY mv_message_acknowledgment_rate;
                                REFRESH MATERIALIZED VIEW CONCURRENTLY mv_message_count_by_template;
                                REFRESH MATERIALIZED VIEW CONCURRENTLY mv_message_count_by_application;
                                REFRESH MATERIALIZED VIEW CONCURRENTLY mv_message_count_by_language;
                                REFRESH MATERIALIZED VIEW CONCURRENTLY mv_message_count_by_status;
                                -- Refresh other materialized views
                            END;
                            $$
                            LANGUAGE plpgsql;
                        ");

            //migrationBuilder.Sql("SELECT refresh_materialized_views();");

        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("DROP MATERIALIZED VIEW IF EXISTS mv_message_count_by_status;");
            migrationBuilder.Sql("DROP MATERIALIZED VIEW IF EXISTS mv_message_count_by_language;");

            migrationBuilder.Sql("DROP MATERIALIZED VIEW IF EXISTS mv_message_count_by_application;");
            migrationBuilder.Sql("DROP MATERIALIZED VIEW IF EXISTS mv_message_count_by_template;");
            migrationBuilder.Sql("DROP MATERIALIZED VIEW IF EXISTS mv_message_acknowledgment_rate;");
            migrationBuilder.Sql("DROP MATERIALIZED VIEW IF EXISTS mv_message_failure_rate;");
            migrationBuilder.Sql("DROP MATERIALIZED VIEW IF EXISTS mv_average_response_time;");
            migrationBuilder.Sql("DROP MATERIALIZED VIEW IF EXISTS mv_top_sender_names;");
            migrationBuilder.Sql("DROP MATERIALIZED VIEW IF EXISTS mv_otp_usage_rate;");
            migrationBuilder.Sql("DROP MATERIALIZED VIEW IF EXISTS mv_message_volume_trend;");
            migrationBuilder.Sql("DROP MATERIALIZED VIEW IF EXISTS mv_message_sent_by_day_of_week;");
            migrationBuilder.Sql("DROP MATERIALIZED VIEW IF EXISTS mv_message_sent_by_hour_of_day;");

            migrationBuilder.Sql("DROP FUNCTION IF EXISTS refresh_materialized_views();");
        }
    }
}
