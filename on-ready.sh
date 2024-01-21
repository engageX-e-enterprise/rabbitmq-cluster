#!/bin/bash

 
# Enable RabbitMQ Management and Federation plugins
 
docker exec -it rabbit rabbitmq-plugins enable rabbitmq_management
docker exec -it rabbit rabbitmq-plugins enable rabbitmq_federation 

docker exec -it rabbit  rabbitmqctl set_policy ha-fed \
".*" '{"federation-upstream-set":"all", "ha-sync-mode":"automatic", "ha-mode":"nodes", "ha-params":["rabbit@node1.rabbit.local","rabbit@node2.rabbit.local","rabbit@node3.rabbit.local"]}' \
--priority 1 \
--apply-to queues