FROM rabbitmq:3.8-management

# Copy the entrypoint script to the container
COPY entrypoint.sh /usr/local/bin/

# Set the entrypoint script as the default entrypoint
ENTRYPOINT ["entrypoint.sh"]

# Expose RabbitMQ default port
EXPOSE 5672
