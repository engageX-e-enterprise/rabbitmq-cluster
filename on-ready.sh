#!/bin/bash

 
# Enable RabbitMQ Management and Federation plugins
 
docker exec -it rabbit rabbitmq-plugins enable rabbitmq_management
docker exec -it rabbit rabbitmq-plugins enable rabbitmq_federation 

docker exec -it rabbit-1  rabbitmqctl set_policy ha-fed \
".*" '{"federation-upstream-set":"all", "ha-sync-mode":"automatic", "ha-mode":"nodes", "ha-params":["rabbit@ip-13-127-156-93","rabbit@ip-3-108-41-19","rabbit@ip-35-154-195-7"]}' \
--priority 1 \
--apply-to queues