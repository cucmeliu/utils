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

# pyinstaller -F filename.py 打包生成 exe

# 按征信要求，生成24个月的还款状态

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
sql = conf['DB']['SQL'] # 'select * from VIEW_REPORT_PROJECT_RENT'  

# excel 信息
strToday = time.strftime("%Y-%m-%d", time.localtime(int(time.time()))) 
sheet_name = conf['EXCEL']['SHEET_NAME'] # '租金收取情况报表' 
out_path = conf['EXCEL']['OUT_PATH'] + conf['EXCEL']['FILE_BASE'] + strToday + '.xlsx'

# todo: 以上，可以修改为配置文件中读取
logging.info("Out Path: " + out_path)

# 读取数据库
logging.info("connect to database ")
logging.info("Query: " + sql)
conn = MySQLdb.connect(host, user, pwd, db, charset='utf8')  
cursor = conn.cursor()  
try:
    logging.info("read from table ")
    count = cursor.execute(sql)
    logging.info("read from table count: ")
    logging.info(count)
    # print(count)  
    cursor.scroll(0, mode='absolute')  
    results = cursor.fetchall()
    fields = cursor.description

    print('fields: ')
    print(fields)

    i = 2  # 注意：'cell'函数中行列起始值为1
    cur_project_id = ''
    cur_period = 0
    over_day_counts = []
    over_duration_period = []
    m24_status = []
    orig_str = '///////////////////////*'

    for line in results:  
        if cur_project_id !=  line[0]:
            # 处理掉上一个项目
            print('--- deal with project: ' + cur_project_id)
            if len(over_duration_period)>0:
                c_str = ''
                i = 0
                while i < len(over_duration_period):
                    p = over_duration_period[i]
                    if p == 0:
                        c_str = c_str + 'N'
                        i = i + 1
                    else:
                        for c in range(p):
                            c_str = c_str + str(c+1)
                            # c_str = c_str + ('N' if(p - c - 1==0) else str(p - c - 1))
                            i = i + p
                # print('c_str:' + c_str)
                # logging.info('c_str:' + c_str)

                for m in range(len(over_duration_period)):
                    c_s = orig_str[m+1:len(orig_str)] + c_str[:m+1]
                    m24_status.append(c_s)
                    print(c_s)
                    logging.info(c_s)

                    # print('project:' + cur_project_id + ' - ' + str(m))
                # 写入数据库
                # update set  = str where project=project and period = period

            # 初始化下一个新的项目
            cur_project_id = line[0]
            cur_period = line[1]
            over_duration_period = []
            m24_status = []
            # last_str = '///////////////////////*'
        # dur_period：逾期的状态，1-表示逾期1-30天；2-表示逾期31-60天；3-表示逾期61-90天；4-表示逾期91-120天；5-表示逾期121-150天；6-表示逾期151-180天；7-表示逾期180天以上；
        dur_period = (int(line[2]) - 1) // 30 + 1
        print('project:' + str(line[0]) + ' - period:' + str(line[1]) + '- dur_period:' + str(dur_period))
        logging.info('project:' + str(line[0]) + ' - period:' + str(line[1]) + '- dur_period:' + str(dur_period))
        over_duration_period.append(dur_period)  # 最大影响期数

        
    logging.info("write to excel file: done ")

except Exception as e:
    traceback.print_exc()
    logging.warning("exec failed, failed msg:" + traceback.format_exc())

logging.info("closeing database ")
conn.close
logging.info("closeing database: done ")
