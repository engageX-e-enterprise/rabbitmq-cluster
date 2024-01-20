#!/bin/bash

# Configure the host machine to resolve the RabbitMQ node FQDNs to their IP addresses
# Run this script on the host machine one time only.

# Load environment variables from the file
env_file=".env"  # Replace with the actual path to your file
if [ -f "$env_file" ]; then
    source "$env_file"
fi

# Function to check if a line exists in the hosts file
line_exists() {
    grep -qF "$1" /etc/hosts
}



# Add RabbitMQ node FQDNs and IP addresses to the host machine's hosts file
if ! line_exists "${RABBITMQ_NODE_1_IP} ${RABBITMQ_NODE_1_FQDN}"; then
    echo "${RABBITMQ_NODE_1_IP} ${RABBITMQ_NODE_1_FQDN}" | sudo tee -a /etc/hosts
fi

if ! line_exists "${RABBITMQ_NODE_2_IP} ${RABBITMQ_NODE_2_FQDN}"; then
    echo "${RABBITMQ_NODE_2_IP} ${RABBITMQ_NODE_2_FQDN}" | sudo tee -a /etc/hosts
fi

if ! line_exists "${RABBITMQ_NODE_3_IP} ${RABBITMQ_NODE_3_FQDN}"; then
    echo "${RABBITMQ_NODE_3_IP} ${RABBITMQ_NODE_3_FQDN}" | sudo tee -a /etc/hosts
fi

# cluster_formation.classic_config.nodes.1 = rabbit@ip-13-127-156-93
# cluster_formation.classic_config.nodes.2 = rabbit@ip-3-108-41-19
# cluster_formation.classic_config.nodes.3 = rabbit@ip-35-154-195-7
line_exists_configured() {
    grep -qF "$1" ./rabbitmq.conf
}
if ! line_exists "cluster_formation.classic_config.nodes.1 = rabbit@${RABBITMQ_NODE_1_FQDN}"; then
    echo "cluster_formation.classic_config.nodes.1 = rabbit@${RABBITMQ_NODE_1_FQDN}" | sudo tee -a /etc/hosts
fi

if ! line_exists "cluster_formation.classic_config.nodes.2 = rabbit@${RABBITMQ_NODE_2_FQDN}"; then
    echo "cluster_formation.classic_config.nodes.2 = rabbit@${RABBITMQ_NODE_2_FQDN}" | sudo tee -a /etc/hosts
fi

if ! line_exists "cluster_formation.classic_config.nodes.3 = rabbit@${RABBITMQ_NODE_3_FQDN}"; then
    echo "cluster_formation.classic_config.nodes.3 = rabbit@${RABBITMQ_NODE_3_FQDN}" | sudo tee -a /etc/hosts
fi
