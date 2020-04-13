#!/bin/bash
date_dir="`date +%Y-%m-%d`"
date="`date +%Y-%m-%d_%H%M`"
rm -rf /data/dbdump_backup/*
BK_DR=/data/dbdump_backup/
#备份指定库
mysqldump -u backup -p密码 数据库名称 | zip -P $date%FFGulsdssdwdw2rrpzwTR2 > /data/dbdump_backup/$date-数据库名称.zip
#备份所有库
#mysqldump -u backup -p密码 --all-databases | zip -P $date%xxxxxx > /data/dbdump_backup/$date-DB-Backup.zip
#todir=10.7_dumpbackup          #目标文件夹
ip=192.168.10.25     #服务器
user=mysqldump     #ftp用户名
password=密码       #ftp密码
sss=`find $BK_DR -type d -printf $date_dir/'%P\n'| awk '{if ($0 == "")next;print "mkdir " $0}'`
aaa=`find $BK_DR -type f -printf 'put %p %P \n'`
ftp -nv $ip <<EOF 
user $user $password
type binary 
prompt 
$sss 
cd $date_dir 
$aaa 
quit 
EOF
#钉钉预警
#size=`(ls -all /data/dbdump_backup/|grep "2019"|awk '{print $5}')`
#echo "$size"
#if [ "$size" -gt 104857600 ]
#then
#echo "备份成功"
#else
#
#curl 'https://oapi.dingtalk.com/robot/send?access_token=xxxxxxxxxxxxxxxxxxxxx' \
#   -H 'Content-Type: application/json' \
#   -d '{"msgtype": "text", 
#        "text": {
#             "content": "数据备份失败,请检查相关策略"
#        }
#      }'

#fi

