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

# 将一个表的数据从一个库转到另一个库
myname = sys.argv[0]

f       = open('Conf-'+myname+'.yaml', encoding='utf-8')
# f       = open('Conf-mysql2mysql.yaml', encoding='utf-8')
conf    = yaml.load(f, Loader=yaml.FullLoader)

print('conf---')
print(conf)

# 设置日志
LOG_FORMAT  = conf['LOG']['LOG_FORMAT'] # "%(asctime)s - %(levelname)s - %(message)s"
DATE_FORMAT = conf['LOG']['DATE_FORMAT'] # "%m/%d/%Y %H:%M:%S %p"
LOG_PATH    = conf['LOG']['LOG_PATH']
logging.basicConfig(filename=LOG_PATH + 'log.log', level=logging.INFO, format=LOG_FORMAT, datefmt=DATE_FORMAT)
logging.info("start..."+myname)
print("start..."+myname)

# global参数
IS_TRUNC_DEST = conf['GLOBAL']['IS_TRUNC_DEST']

# SRC数据库信息
SRC_HOST    = conf['SRC_DB']['HOST'] # '172.16.0.52'  
SRC_USER    = conf['SRC_DB']['USER'] # 'query01'  
SRC_PWD     = conf['SRC_DB']['PWD'] # 'query01'  
SRC_DB      = conf['SRC_DB']['DB'] # 'small_core'  
SRC_TABLE   = conf['SRC_DB']['TABLE'] # 'tmp_xxx' 
SRC_SQL     =  conf['SRC_DB']['SQL']

# dest数据库信息
DEST_HOST   = conf['DEST_DB']['HOST'] # '172.16.0.52'  
DEST_USER   = conf['DEST_DB']['USER'] # 'query01'  
DEST_PWD    = conf['DEST_DB']['PWD'] # 'query01'  
DEST_DB     = conf['DEST_DB']['DB'] # 'small_core'  
DEST_TABLE  = conf['DEST_DB']['TABLE'] # 'tmp_xxx'  
DEST_SQL    =  conf['DEST_DB']['SQL']

# 读取数据库
logging.info("connect to SRC database ")
src_db      = MySQLdb.connect(SRC_HOST, SRC_USER, SRC_PWD, SRC_DB, charset='utf8') 
src_cursor  = src_db.cursor()  

logging.info("connect to DEST database ")
dest_db     = MySQLdb.connect(DEST_HOST, DEST_USER, DEST_PWD, DEST_DB, charset='utf8') 
dest_cursor = dest_db.cursor()

try:
    if IS_TRUNC_DEST: 
        # 先清空目标表
        logging.info("TRUNCATE table " + DEST_TABLE)
        dest_cursor.execute("TRUNCATE table " + DEST_TABLE)
        dest_db.commit()

    # 读入源表
    # list = []

    count = src_cursor.execute( SRC_SQL )
    logging.info("read from table count: ")
    logging.info(count)
    src_cursor.scroll(0, mode='absolute')  
    results = src_cursor.fetchall()
    fields = src_cursor.description

    # list.append(results)
    # for line in results: 
    #     list.append(line)
    # print(results)

    if (len(results) > 0):
        dest_cursor.executemany(DEST_SQL, results)
        # 提交
        dest_db.commit()

except Exception as e:
    traceback.print_exc()
    logging.warning("exec failed, failed msg:" + traceback.format_exc())

logging.info("closeing database ")
dest_cursor.close
src_cursor.close
src_db.close
dest_db.close
logging.info("closeing database: done ")
logging.info("done!")
print("done!")