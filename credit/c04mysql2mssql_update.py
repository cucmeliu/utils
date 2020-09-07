#__author: liuchunming
#date: 2020/05/28

# coding:utf8  

import sys  
# import openpyxl
#import MySQLdb
import pymysql as MySQLdb
import pymssql as MsSQLdb
import datetime  
import time 
import logging
import yaml
import traceback

# 将一个表的数据从一个库转到另一个库，在目标库更新

myname = sys.argv[0]

f       = open('Conf-'+myname+'.yaml', encoding='utf-8')
conf    = yaml.load(f, Loader=yaml.FullLoader)

# print('conf---')
# print(f.)

# 设置日志
LOG_FORMAT  = conf['LOG']['LOG_FORMAT'] # "%(asctime)s - %(levelname)s - %(message)s"
DATE_FORMAT = conf['LOG']['DATE_FORMAT'] # "%m/%d/%Y %H:%M:%S %p"
LOG_PATH    = conf['LOG']['LOG_PATH']
logging.basicConfig(filename=LOG_PATH + 'log.log', level=logging.INFO, format=LOG_FORMAT, datefmt=DATE_FORMAT)

logging.info("------------------")
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

logging.info("Dealing with " + DEST_TABLE + ".........")
# 读取数据库
logging.info("connect to SRC database ")
src_db      = MySQLdb.connect(SRC_HOST, SRC_USER, SRC_PWD, SRC_DB, charset='utf8') 
src_cursor  = src_db.cursor()  

logging.info("connect to DEST database ")
dest_db     = MsSQLdb.connect(DEST_HOST, DEST_USER, DEST_PWD, DEST_DB, charset='utf8') 
dest_cursor = dest_db.cursor()

try:
    if IS_TRUNC_DEST: 
        # 先清空目标表
        logging.info("TRUNCATE table " + DEST_TABLE)
        dest_cursor.execute("delete  from " + DEST_TABLE)
        dest_db.commit()

    # 读入源表
    list = []

    count = src_cursor.execute( SRC_SQL )
    logging.info("read from table count: ")
    logging.info(count)
    src_cursor.scroll(0, mode='absolute')  
    results = src_cursor.fetchall()
    fields = src_cursor.description

    print(results)
    print(DEST_SQL)


# (('M10154210H0001', '4', '92', 'JXFLMY2019092400075', 360102, '20190924', '20200924', 'CNY', 68000, 68000, 68000, 2, '03', '12', '2', '20200624', '20200725', 6362, 18749, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 3, '/////////////*NNNNNNNNNC', 0, '1', '曾冰', '0', '51062319891006071X', '51062319891006071X', '', datetime.datetime
# (2020, 7, 31, 1, 1), 2), 'JXFLMY2019092400075', '20200624')
    for r in results:
        # print((r, r[3], r[15]))
        # sql_line = DEST_SQL % (r[0], r[1],r[2],r[3],r[4]) # r[5],r[6],r[7],str(r[8]),str(r[9]),str(r[10]),str(r[11]),r[12],r[13],r[14],r[15],r[16],str(r[17]),str(r[18]),str(r[19]),str(r[20]), str(r[21]),str(r[22]),str(r[23]),str(r[24]),str(r[25]),str(r[26]),str(r[27]),str(r[28]),str(r[29]),r[30], str(r[31]),r[32],r[33],r[34],r[35],r[36],r[37],r[38],str(r[39]),r[3],r[15],)
        dest_cursor.execute(DEST_SQL, (r[0], r[1],r[2],r[3],str(r[4]),r[5],r[6],r[3],r[15]))
        # dest_cursor.execute(DEST_SQL, (r[0], r[1],r[2],r[3],r[4],r[5],r[6],r[7],r[8],r[9],r[10],r[11],r[12],r[13],r[14],r[15],r[16],r[17],r[18],r[19],
        # r[20], r[21],r[22],r[23],r[24],r[25],r[26],r[27],r[28],r[29],r[30], r[31],r[32],r[33],r[34],r[35],r[36],r[37],r[38],r[39],r[3],r[15]))  # , r[3].encode(), r[15].encode()
    dest_db.commit()


    # list.append(results)
    # for line in results: 
    #     list.append(line)
    # print(results)

    # if (len(results) > 0):
    #     dest_cursor.executemany(DEST_SQL, (results,,))
    #     # 提交
    #     dest_db.commit()

except Exception as e:
    traceback.print_exc()
    logging.warning("exec failed, failed msg:" + traceback.format_exc())

logging.info("closeing database ")
dest_cursor.close
src_cursor.close
dest_db.close
src_db.close
logging.info("closeing database: done ")

logging.info("done!")
print("done!")