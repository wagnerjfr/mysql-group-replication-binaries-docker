# MySQL Group Replication using MySQL binaries and Docker containers
Setting up Group Replication using MySQL binaries and Docker containers

#### The MySQL Group Replication feature is a multi-master update anywhere replication plugin  for MySQL with built-in conflict detection and resolution, automatic distributed recovery, and group membership.

## References
1. https://dev.mysql.com/doc/refman/8.0/en/group-replication.html
2. https://mysqlhighavailability.com/mysql-group-replication-its-in-5-7-17-ga/

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
