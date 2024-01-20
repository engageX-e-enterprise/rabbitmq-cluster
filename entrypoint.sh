#!/bin/bash

# Start RabbitMQ
rabbitmq-server &

# Wait for RabbitMQ to be ready (adjust the sleep duration based on your system)
sleep 100

# Enable RabbitMQ Management and Federation plugins
rabbitmq-plugins enable rabbitmq_management
rabbitmq-plugins enable rabbitmq_federation

NODE_1=${RABBITMQ_NODE_1_FQDN:-"rabbit-1"}
NODE_2=${RABBITMQ_NODE_2_FQDN:-"rabbit-2"}
NODE_3=${RABBITMQ_NODE_3_FQDN:-"rabbit-3"}

# RabbitMQ nodes
RABBITMQ_NODES=("$NODE_1" "$NODE_2" "$NODE_3")

# RabbitMQ policy parameters

POLICY_NAME="ha-fed"
POLICY_PATTERN=".*"
POLICY_DEFINITION='{"federation-upstream-set":"all", "ha-sync-mode":"automatic", "ha-mode":"nodes", "ha-params":['$(printf '"%s",' "${RABBITMQ_NODES[@]}" | sed 's/,$//')']}'
POLICY_PRIORITY=1

# Set RabbitMQ policy to mirror the queue and sync once a node recover from a failure.
rabbitmqctl set_policy "$POLICY_NAME" "$POLICY_PATTERN" "$POLICY_DEFINITION" --priority "$POLICY_PRIORITY" --apply-to queues  

# Keep the script running (entrypoint)
exec "$@"
