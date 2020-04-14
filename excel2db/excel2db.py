# coding:utf8  
import sys  
import openpyxl
from openpyxl import load_workbook
#import MySQLdb
import pymysql as MySQLdb
import datetime  
import time 
import logging
import yaml
import traceback

# pyinstaller -F filename.py 打包生成 exe

f = open('Conf.yaml', encoding='utf-8')
conf = yaml.load(f, Loader=yaml.FullLoader)

print('conf---')
print(conf)

# 设置日志
LOG_FORMAT = conf['LOG']['LOG_FORMAT'] # "%(asctime)s - %(levelname)s - %(message)s"
DATE_FORMAT = conf['LOG']['DATE_FORMAT'] # "%m/%d/%Y %H:%M:%S %p"
LOG_PATH = conf['LOG']['LOG_PATH']
logging.basicConfig(filename=LOG_PATH + 'log.log', level=logging.INFO, format=LOG_FORMAT, datefmt=DATE_FORMAT)
logging.info("starting...")

# 数据库信息
host = conf['DB']['HOST'] # '172.16.0.52'  
user = conf['DB']['USER'] # 'query01'  
pwd = conf['DB']['PWD'] # 'query01'  
db = conf['DB']['DB'] # 'small_core'  
query = conf['DB']['SQL'] # 'select * from VIEW_REPORT_PROJECT_RENT'  

# excel 信息
in_file = conf['EXCEL']['FILE_PATH'] + conf['EXCEL']['FILE_NAME']
sheet_name = conf['EXCEL']['SHEET_NAME'] 
wb2 = load_workbook(in_file)
ws = wb2[sheet_name]
# 
logging.info("IMPORT FILE: " + in_file)

# 读取数据库
logging.info("connect to database ")
logging.info("Query: " + query)
# 建立一个MySQL连接
conn = MySQLdb.connect(host, user, pwd, db, charset='utf8')  
# 获得游标对象, 用于逐行遍历数据库数据
cursor = conn.cursor()  
try:
    logging.info("read from EXCEL ")

    for r in ws.iter_rows(min_row=2, min_col=1):
        # for c in r:
        #     print(c.value, end= " ")
        # print()
        c0 = r[0].value
        c1 = r[1].value
        c2 = r[2].value
        c3 = r[3].value
        c4 = r[4].value
        c5 = r[5].value
        c6 = r[6].value
        c7 = r[7].value
        c8 = r[8].value
        c9 = r[9].value
       
        values = (c0, c1, c2, c3, c4, c5, c6, c7, c8, c9)
        cursor.execute(query, values)
        # print(values)
        # print()

    
    logging.info("transfer from excel to db: done ")

except Exception as e:
    traceback.print_exc()
    logging.warning("exec failed, failed msg:" + traceback.format_exc())

logging.info("closeing database ")
# 关闭游标
cursor.close()
# 提交
conn.commit()
# 关闭数据库连接
conn.close()
logging.info("closeing database: done ")
