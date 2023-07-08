#!/bin/bash
#
#********************************************************************
#Author:            wangxiaochun
#QQ:                29308620
#Date:              2022-03-05
#FileName:          install_zabbix_server6.0.sh
#URL:               http://www.wangxiaochun.com
#Description:       The test script
#Copyright (C):     2022 All rights reserved
#********************************************************************

ZABBIX_MAJOR_VER=6.0
ZABBIX_VER=${ZABBIX_MAJOR_VER}-4

URL="mirror.tuna.tsinghua.edu.cn/zabbix"

MYSQL_HOST=localhost
MYSQL_ZABBIX_USER="zabbix@localhost"

#MYSQL_HOST=10.0.0.100
#MYSQL_ZABBIX_USER="zabbix@'10.0.0.%'"

MYSQL_ZABBIX_PASS='123456'
MYSQL_ROOT_PASS='123456'

FONT=msyhbd.ttc

ZABBIX_IP=hostname -I|awk '{print $1}'
GREEN="echo -e \E[32;1m"
END="\E[0m"

. /etc/os-release 

color () {
    RES_COL=60
    MOVE_TO_COL="echo -en \\033[${RES_COL}G"
    SETCOLOR_SUCCESS="echo -en \\033[1;32m"
    SETCOLOR_FAILURE="echo -en \\033[1;31m"
    SETCOLOR_WARNING="echo -en \\033[1;33m"
    SETCOLOR_NORMAL="echo -en \E[0m"
    echo -n "$1" && $MOVE_TO_COL
    echo -n "["
    if [ $2 = "success" -o $2 = "0" ] ;then
        ${SETCOLOR_SUCCESS}
        echo -n $"  OK  "    
    elif [ $2 = "failure" -o $2 = "1"  ] ;then 
        ${SETCOLOR_FAILURE}
        echo -n $"FAILED"
    else
        ${SETCOLOR_WARNING}
        echo -n $"WARNING"
    fi
    ${SETCOLOR_NORMAL}
    echo -n "]"
    echo 
}

install_mysql () {
    [ $MYSQL_HOST != "localhost" ] && return 
    if [ $ID = "centos" -o $ID = "rocky" ] ;then
        VERSION_ID=echo $VERSION_ID | cut -d . -f1
        if [ ${VERSION_ID} == "8" ];then
            yum  -y install mysql-server
            systemctl enable --now mysqld
        elif [ ${VERSION_ID} == "7" ];then
            yum -y install mariadb-server
            systemctl enable --now mariadb
        else
            color "不支持的操作系统,退出" 1
        fi 
    else
        apt update
        apt -y install mysql-server
        sed -i "/^bind-address.*/c bind-address  = 0.0.0.0" /etc/mysql/mysql.conf.d/mysqld.cnf
        systemctl restart mysql
    fi
    mysqladmin -uroot password $MYSQL_ROOT_PASS
    mysql -uroot -p$MYSQL_ROOT_PASS <