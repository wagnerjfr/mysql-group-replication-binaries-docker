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
ENV PORT 3306

CMD rm -rf $PWD/$DATADIR && ./bin/mysqld --no-defaults --datadir=$PWD/$DATADIR \
  --basedir=$PWD --initialize-insecure && \
  ./bin/mysqld --no-defaults --basedir=$PWD --datadir=$PWD/$DATADIR \
  --socket=/tmp/mysql.0.sock --log-bin=mysql-bin-1.log --server_id=$SERVERID \
  --port=$PORT --enforce-gtid-consistency --log-slave-updates --gtid-mode=on \
  --transaction-write-set-extraction=XXHASH64 --binlog-checksum=NONE \
  --master-info-repository=TABLE --relay_log_info_repository=TABLE \
  --plugin-dir=lib/plugin/ --plugin-load=group_replication.so --relay-log-recovery=on \
  --group_replication_start_on_boot=0

