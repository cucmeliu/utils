# coding:utf8  
import sys  
# import openpyxl
#import MySQLdb
import pymysql as MySQLdb
import datetime  
import time 
import logging
import yaml
import traceback

f       = open('Conf-call-process.yaml', encoding='utf-8')
conf    = yaml.load(f, Loader=yaml.FullLoader)

print('conf---')
print(conf)

# 设置日志
LOG_FORMAT  = conf['LOG']['LOG_FORMAT'] # "%(asctime)s - %(levelname)s - %(message)s"
DATE_FORMAT = conf['LOG']['DATE_FORMAT'] # "%m/%d/%Y %H:%M:%S %p"
LOG_PATH    = conf['LOG']['LOG_PATH']

logging.basicConfig(filename=LOG_PATH + 'log.log', level=logging.INFO, format=LOG_FORMAT, datefmt=DATE_FORMAT)
logging.info("starting...")

# global参数
# IS_TRUNC_DEST = conf['GLOBAL']['IS_TRUNC_DEST']

# SRC数据库信息
SRC_HOST    = conf['SRC_DB']['HOST'] # '172.16.0.52'  
SRC_USER    = conf['SRC_DB']['USER'] # 'query01'  
SRC_PWD     = conf['SRC_DB']['PWD'] # 'query01'  
SRC_DB      = conf['SRC_DB']['DB'] # 'small_core'  
SRC_SP      = conf['SRC_DB']['SP'] # 'tmp_xxx' 
SRC_ARGS    =  conf['SRC_DB']['ARGS']

# 读取数据库
logging.info("connect to database ")
db      = MySQLdb.connect(SRC_HOST, SRC_USER, SRC_PWD, SRC_DB, charset='utf8') 
cursor  = db.cursor(MySQLdb.cursors.DictCursor)  
cursor.callproc(SRC_SP) # , *SRC_ARGS参数为存储过程名称和存储过程接收的参数
db.commit()
# 获取数据
# data = cursor.fetchall()
# 关闭数据库连接
db.close()
print('end---')
