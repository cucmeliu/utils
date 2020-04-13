#!/bin/bash

#服务器
SERVER_HOST="172.16.0.52"
SERVER_PORT="3306"
SERVER_USER="root"
SERVER_PASSWORD="mysql"
SERVER_DB="small_core"

#本地
LOCAL_HOST="localhost"
LOCAL_PORT="3306"
LOCAL_USER="root"
LOCAL_PASSWORD="mysql"
LOCAL_SERVER_DB="small_core"


#在本地创建对应数据库
create_db_sql="create database IF NOT EXISTS ${LOCAL_SERVER_DB}"
mysql -h${LOCAL_HOST}  -P${LOCAL_PORT}  -u${LOCAL_USER} -p${LOCAL_PASSWORD} -e "${create_db_sql}"

#从远程数据库备份到本地数据库
mysqldump --host=${SERVER_HOST} -u${SERVER_USER} -p${SERVER_PASSWORD} --opt ${SERVER_DB} | mysql --host=${LOCAL_HOST} -u${LOCAL_USER} -p${LOCAL_PASSWORD} -C ${LOCAL_SERVER_DB}

# mysqldump --host=172.16.0.52 -uroot -pmysql --opt small_core | mysql --host=localhost -uroot -proot -C small_core

