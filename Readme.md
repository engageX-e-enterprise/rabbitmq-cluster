All files required is availabel even the iamge for local setup in a private network.

The container use mirrored queues and enable the mirroring of the queues. 

## First step the .env file with the crosponding IP addresses, and virtual FQDN's.

We will use these values into multiple file , so instead of doing it multiple time in multiple distination we are automating all the process, just put the values here and follow the next steps that will run multiple scripts, to configure the values in their places. 


The FQDN's are used localy for inter node discovery, as rabbitMQ doesn't enable us tp put the IP address directly.

```
nano .env 
```


## Second step configuring the host machine and prepare the config

Run the script `configure-hosts.sh` as follow.
```
bash configure-hosts.sh 
```
The script will use the values provided in the .env files to :
- Configure the local `/etc/hosts` the local DNS in order to resolve the remote IP's Addresses.

- Add the Instances FQDN to the `rabbitmq.conf` file in the cluster configuration section.

## The `entrypoint.sh`
This File is configured as the entry point to the docker image,  used to enable the require plugins, and configure the required ha-policies. 

## run the Node Container.
To start the container :

```
docker compose up -d
```
this command will build the image if not built before if buit before it will skip the build process.

if you changed any config that require rebuilding the image jsut run the command with additional `--build`

```
docker compose up -d --build
```
