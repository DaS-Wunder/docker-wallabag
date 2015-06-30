#!/bin/bash
#used from https://github.com/Zuhkov/docker-containers/blob/master/paperwork/mariadb.sh


echo "Starting MariaDB..."
/usr/bin/mysqld_safe --skip-syslog --datadir='/config/databases'

