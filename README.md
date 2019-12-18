# `MySQL Group Replication using MySQL binaries and Docker containers`
Setting up Group Replication using MySQL binaries and Docker containers

#### The MySQL Group Replication feature is a multi-master update anywhere replication plugin  for MySQL with built-in conflict detection and resolution, automatic distributed recovery and group membership.

## References
1. https://dev.mysql.com/doc/refman/8.0/en/group-replication.html
2. https://mysqlhighavailability.com/mysql-group-replication-its-in-5-7-17-ga/

## Other ways to setup Group Replication using Docker containers
https://github.com/wagnerjfr/mysql-group-replication-docker

https://github.com/wagnerjfr/mysql-group-replication-binaries-docker

## Prerequisites
1. Docker installed
2. MySQL binaries compatible to run on Ubuntu (which is the OS used in the Docker image)

## Overview
We start by building our Docker image, then we are going to create a Docker network and later create a group replication topology with 3 group members in different hosts.

## MySQL Download
https://dev.mysql.com/downloads/mysql/

You can choose any MySQL Community Server version (5.7, 8, or both) but you must select **Linux-Generic** in *"Select Operating System"*. That's because we are going to run it in a **Ubuntu Docker Image**.

Download and unpack the tar file into a directory of your choice.

In my example, I'm going to use: `/home/wfranchi/MySQL/mysql-8.0.11`

## Building the Image
Let’s create the image by running this command:
```
$ docker build -t mysqlubuntu .
```

A path is a mandatory argument for the build command. We used . as the path because we’re currently in the same directory. We also used the -t flag to tag the image.
The name of the image is mysqlubuntu and can be any name you want.

The following output show be printed:
```console
Successfully built 3c9769f24bf0
Successfully tagged mysqlubuntu:latest
```
Check whether the image was created:
```
$ docker images
```
If the build was successful you should have:
```console
REPOSITORY           TAG                 IMAGE ID            CREATED             SIZE
mysqlubuntu          latest              422a05ed125c        10 seconds ago      114MB
```
## Creating a Docker network
Fire the following command to create a network:
```
$ docker network create group1
```
You just need to create it once, unless you remove it from Docker.

To see all Docker networks:
```
$ docker network ls
```
This network by default is a IPv4 network.

You can check it by running:
```
$ docker inspect -f '{{.EnableIPv6}}' groupnet
```
The output should be "false".

> **Note**: To create a  Docker network with IPv6 enabled true:

> $ docker network create --ipv6 --subnet 2a02:6b8:b010:9020:1::/80 group1

> More information about IPv6 on Docker [here](http://collabnix.com/enabling-ipv6-functionality-for-docker-and-docker-compose/) and [here](https://docs.docker.com/v17.09/engine/userguide/networking/default_network/ipv6/#how-ipv6-works-on-docker).

## Creating 3 containers with shared MySQL
You must have the binaries or compiled MySQL servers that can be executed in Ubuntu (since we are using Ubuntu as the OS in the container).
It's also possible to use different MySQL versions.

The command to start the containers is:

*docker run -d --rm --net [**network_name**] --name [**container_name**] --hostname [**container_hostname**] -v [**Path-MySQL-Folder**]/:/mysql -e DATADIR=[**data_directory**] -e SERVERID=[**server_id**] -e PORT=[**port_number**] mysqlubuntu*

Run the below commands:
``` 
for N in 1 2 3
do docker run -d --rm \
  --net group1 \
  --name node$N \
  --hostname node$N \
  -v /home/wfranchi/MySQL/mysql-8.0.11/:/mysql \
  -e DATADIR="d$N" \
  -e SERVERID=$N \
  -e PORT=3308 \
  mysqlubuntu
done
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
$ docker ps -a
```
![alt text](https://github.com/wagnerjfr/mysql-group-replication-binaries-docker/blob/master/figures/Docker-GR-binaries1.png)

Fetch the logs of a container (ex. in node1), run:
```
$ docker logs node1
```
To get container's IP from all the containers, run:
```
$ docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' node1 node2 node3
```
In our example, it prints something like:
```console
172.19.0.2
172.19.0.3
172.19.0.4
```
To fetch all the container's information:
```
$ docker inspect node1
```

## Creating a group replication with 3 nodes

Open 3 new terminals and run the below commands in each one:

### node1
Access MySQL server inside the container:
```
$ docker exec -it node1 ./bin/mysql -uroot --socket=/tmp/mysql.0.sock
```
| Command       | Description   |
| ------------- |:-------------:|
| docker exec   | run this command *./bin/mysql -uroot -P 3308 --socket=/tmp/mysql.0.sock* in a running container |
| -it           | iterative mode using container's OS shell |

Run these commands in server console:
```mysql
create user 'repl'@'%';
GRANT ALL  ON * . * TO repl@'%';
flush privileges;
SET @@GLOBAL.group_replication_group_name='aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
SET @@GLOBAL.group_replication_local_address='node1:6606';
SET @@GLOBAL.group_replication_group_seeds='node1:6606,node2:6606,node3:6606';
SET @@GLOBAL.group_replication_bootstrap_group=1;
change master to master_user='repl' for channel 'group_replication_recovery';
START GROUP_REPLICATION;
SET @@GLOBAL.group_replication_bootstrap_group=0;
SELECT * FROM performance_schema.replication_group_members;
```
### node2
Access MySQL server inside the container:
```
$ docker exec -it node2 ./bin/mysql -uroot --socket=/tmp/mysql.0.sock
```
Run these commands in server console:
```mysql
SET @@GLOBAL.group_replication_group_name='aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
SET @@GLOBAL.group_replication_local_address='node2:6606';
SET @@GLOBAL.group_replication_group_seeds='node1:6606,node2:6606,node3:6606';
SET @@GLOBAL.group_replication_bootstrap_group=0;
SET @@global.group_replication_recovery_retry_count=5;
change master to master_user='repl' for channel 'group_replication_recovery';
START GROUP_REPLICATION;
SELECT * FROM performance_schema.replication_group_members;
```
### node3

Access MySQL server inside the container:
```
$ docker exec -it node3 ./bin/mysql -uroot --socket=/tmp/mysql.0.sock
```
Run these commands in server console:
```mysql
SET @@GLOBAL.group_replication_group_name='aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
SET @@GLOBAL.group_replication_local_address='node3:6606';
SET @@GLOBAL.group_replication_group_seeds='node1:6606,node2:6606,node3:6606';
SET @@GLOBAL.group_replication_bootstrap_group=0;
SET @@global.group_replication_recovery_retry_count=5;
change master to master_user='repl' for channel 'group_replication_recovery';
START GROUP_REPLICATION;
SELECT * FROM performance_schema.replication_group_members;
```
By now, you should see:
![alt text](https://github.com/wagnerjfr/mysql-group-replication-binaries-docker/blob/master/figures/Docker-GR-binaries2.png)

## Dropping network in one of the nodes

Docker allows us to drop the network from a container by just running a command.

In another terminal, let's disconnect node3 from the network:
```
$ docker network disconnect group1 node3
```
Running the query (```SELECT * FROM performance_schema.replication_group_members;```) in node3 terminal we should see:
![alt text](https://github.com/wagnerjfr/mysql-group-replication-binaries-docker/blob/master/figures/Docker-GR-binaries3.png)

Running the same query in node1 terminal, we noticed that node3 was expelled from the group:
![alt text](https://github.com/wagnerjfr/mysql-group-replication-binaries-docker/blob/master/figures/Docker-GR-binaries4.png)

To kill running container(s):
```
$ docker kill node3
```

## Stopping containers, removing created network and image

Stopping running container(s):
```
$ docker stop node1 node2
```
Stopping running MySQL inside the container (ex. node3)
```
$ docker exec node3 ./bin/mysqladmin -h node3 -P 3308 -u root shutdown
```
Removing the created network:
```
$ docker network rm group1
```
Removing the created image:
```
$ docker rmi mysqlubuntu
```
