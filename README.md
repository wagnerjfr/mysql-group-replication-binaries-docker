# MySQL Group Replication using MySQL binaries and Docker containers
Setting up Group Replication using MySQL binaries and Docker containers

#### The MySQL Group Replication feature is a multi-master update anywhere replication plugin  for MySQL with built-in conflict detection and resolution, automatic distributed recovery and group membership.

## References
1. https://dev.mysql.com/doc/refman/8.0/en/group-replication.html
2. https://mysqlhighavailability.com/mysql-group-replication-its-in-5-7-17-ga/

## Another approach, using MySQL Images
https://github.com/wagnerjfr/mysql-group-replication-docker

## Prerequisites
1. Docker installed
2. Do not run while connected to VPN
3. MySQL binaries compatible to run in Ubuntu

## Overview
We start by building our Docker image, then we are going to create a Docker network and later create a group replication topology with 3 group members in different hosts.

## MySQL Download
https://dev.mysql.com/downloads/mysql/
You can choose any MySQL Community Server version (5.7, 8, or both) but you must select **Linux-Generic** in "Select Operating System". That's because we are going to run it in a Ubuntu Docker Image.

Download and unpack the tar file into a directory of your choice.
In my example, I'm going to use: */home/wfranchi/MySQL/mysql-8.0.11*

## Building the Image
Create a file named **Dockerfile** in a directory of your choice.

Copy and paste the below content to the file. Save and close it.
```
FROM ubuntu:16.04

MAINTAINER Wagner Franchin <wagner.franchin@oracle.com>

RUN apt-get update && apt-get install -y \
  libaio1 \
  libnuma1 \
  && rm -rf /var/lib/apt/lists/*

RUN useradd rpl_user
WORKDIR /mysql
USER rpl_user

ENV SERVERID 1
ENV DATADIR d0

CMD rm -rf $PWD/$DATADIR && ./bin/mysqld --no-defaults --datadir=$PWD/$DATADIR \
  --basedir=$PWD --initialize-insecure && \
  ./bin/mysqld --no-defaults --basedir=$PWD --datadir=$PWD/$DATADIR \
  --socket=/tmp/mysql.0.sock --log-bin=mysql-bin-1.log --server_id=$SERVERID \
  --port=3308 --enforce-gtid-consistency --log-slave-updates --gtid-mode=on \
  --transaction-write-set-extraction=XXHASH64 --binlog-checksum=NONE \
  --master-info-repository=TABLE --relay_log_info_repository=TABLE \
  --plugin-dir=lib/plugin/ --plugin-load=group_replication.so --relay-log-recovery=on \
  --group_replication_start_on_boot=0
```
Now that the Dockerfile is ready, let’s create the image.

Go to the folder where Dockerfile is and run this command:
```
docker build -t mysqlubuntu .
```
A path is a mandatory argument for the build command. We used . as the path because we’re currently in the same directory. We also used the -t flag to tag the image.
The name of the image is mysqlubuntu and can be any name you want.

Check if the image was created:
```
docker images
```
If the build was successful you should have:
```
$ docker images
REPOSITORY           TAG                 IMAGE ID            CREATED             SIZE
mysqlubuntu          latest              422a05ed125c        10 seconds ago      114MB
```
## Creating a Docker network
```
docker network create group1
```
Just need to create it once, unless you remove it from docker network.

To see all Docker Network:
```
docker network ls
```

## Creating 3 containers with shared MySQL
You must have the binaries or compiled MySQL servers that can be executed in Ubuntu (since we are using Ubuntu as the OS in the container).
It's also possible to use different MySQL versions.

The command to start the containers is:

*docker run -d --rm --net [network_name] --name [container_name] --hostname [container_hostname] -v [Path-MySQL-Folder]/:/mysql -e DATADIR=[data_directory] -e SERVERID=[server_id] mysqlubuntu*

Run the below commands:
```
docker run -d --rm --net group1 --name node1 --hostname node1 -v /home/wfranchi/MySQL/mysql-8.0.11/:/mysql -e DATADIR='d0' -e SERVERID=1 mysqlubuntu

docker run -d --rm --net group1 --name node2 --hostname node2 -v /home/wfranchi/MySQL/mysql-8.0.11/:/mysql -e DATADIR='d1' -e SERVERID=2 mysqlubuntu

docker run -d --rm --net group1 --name node3 --hostname node3 -v /home/wfranchi/MySQL/mysql-8.0.11/:/mysql -e DATADIR='d2' -e SERVERID=3 mysqlubuntu
```
| Command       | Description   |
| ------------- |:-------------:|
| docker run    | starts the container |
| -d            | detached mode (background)      |
| --rm          | remove container automatically after it exits |
| --net         | container's network |
| --name        | container's name |
| --hostname    | container's hostname |
| -v            | shared volume between host and container |
| -e            | environment variable |

The containers are running in background. To see the containers, run:
```
docker ps -a
```
![alt text](https://github.com/wagnerjfr/mysql-group-replication-binaries-docker/blob/master/Docker-GR-binaries1.png)

Fetch the logs of a container (ex. in node1), run:
```
docker logs node1
```
To get container's IP from all the containers, run:
```
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' node1 node2 node3
```
In our example, it prints:
```
172.19.0.2
172.19.0.3
172.19.0.4
```
To fetch all the container's information:
```
docker inspect node1
```

## Creating a group replication with 3 nodes

Open 3 new terminals and run the below commands in each one:

### node1
Access MySQL server inside the container:
```
docker exec -it node1 ./bin/mysql -uroot --socket=/tmp/mysql.0.sock
```
| Command       | Description   |
| ------------- |:-------------:|
| docker exec   | run this command *./bin/mysql -uroot -P 3308 --socket=/tmp/mysql.0.sock* in a running container |
| -it           | iterative mode using container's OS shell |

Run these commands in server console:
```
create user 'root'@'%';
GRANT ALL  ON * . * TO root@'%';
flush privileges;
SET @@GLOBAL.group_replication_group_name='8a94f357-aab4-11df-86ab-c80aa9429562';
SET @@GLOBAL.group_replication_local_address='node1:6606';
SET @@GLOBAL.group_replication_group_seeds='node1:6606,node2:6606,node3:6606';
SET @@GLOBAL.group_replication_bootstrap_group=1;
change master to master_user='root' for channel 'group_replication_recovery';
START GROUP_REPLICATION;
SELECT * FROM performance_schema.replication_group_members;
```
### node2
Access MySQL server inside the container:
```
docker exec -it node2 ./bin/mysql -uroot --socket=/tmp/mysql.0.sock
```
Run these commands in server console:
```
SET @@GLOBAL.group_replication_group_name='8a94f357-aab4-11df-86ab-c80aa9429562';
SET @@GLOBAL.group_replication_local_address='node2:6606';
SET @@GLOBAL.group_replication_group_seeds='node1:6606,node2:6606,node3:6606';
SET @@GLOBAL.group_replication_bootstrap_group=0;
SET @@global.group_replication_recovery_retry_count=5;
change master to master_user='root' for channel 'group_replication_recovery';
START GROUP_REPLICATION;
SELECT * FROM performance_schema.replication_group_members;
```
### node3

Access MySQL server inside the container:
```
docker exec -it node3 ./bin/mysql -uroot --socket=/tmp/mysql.0.sock
```
Run these commands in server console (now using the IPs from the containers, just as example):
```
SET @@GLOBAL.group_replication_group_name='8a94f357-aab4-11df-86ab-c80aa9429562';
SET @@GLOBAL.group_replication_local_address='172.19.0.4:6606';
SET @@GLOBAL.group_replication_group_seeds='172.19.0.2:6606,172.19.0.3:6606,172.19.0.4:6606';
SET @@GLOBAL.group_replication_bootstrap_group=0;
SET @@global.group_replication_recovery_retry_count=5;
change master to master_user='root' for channel 'group_replication_recovery';
START GROUP_REPLICATION;
SELECT * FROM performance_schema.replication_group_members;
```
By now, you should see:
![alt text](https://github.com/wagnerjfr/mysql-group-replication-binaries-docker/blob/master/Docker-GR-binaries2.png)

## Dropping network in one of the nodes

Docker allows us to drop the network from a container by just running a command.

In another terminal, let's disconnect node3 from the network:
```
docker network disconnect group1 node3
```
Running the query (*SELECT * FROM performance_schema.replication_group_members;*) in node3 terminal we should see:
![alt text](https://github.com/wagnerjfr/mysql-group-replication-binaries-docker/blob/master/Docker-GR-binaries3.png)

Running the same query in node1 terminal, we noticed that node3 was expelled from the group:
![alt text](https://github.com/wagnerjfr/mysql-group-replication-binaries-docker/blob/master/Docker-GR-binaries4.png)

To kill running container(s):
```
docker kill node3
```

## Stopping containers, removing created network and image

Stopping running container(s):
```
docker stop node1 node2
```
Stopping running MySQL inside the container (ex. node3)
```
docker exec node3 ./bin/mysqladmin -h node3 -P 3308 -u root shutdown
```
Removing the created network:
```
docker network rm group1
```
Removing the created image:
```
docker rmi mysqlubuntu
```
