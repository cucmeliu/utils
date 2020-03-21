# coding:utf8  

# -- o: 24个月（账户）还款状态
# i: 逾期报表 (overdue_rpt)
# p1: 按项目和期数排序
# SELECT 
# OVERDUE_DAYS, PLAN_STATUS
# FROM 
# SETT_REPAYMENT_PLAN , overdue_rpt
# WHERE 
# overdue_rpt.project_id=SETT_REPAYMENT_PLAN.PROJECT_ID 
# and overdue_rpt.period = SETT_REPAYMENT_PLAN.PERIOD 
# and SETT_REPAYMENT_PLAN.PLAN_STATUS<>0  
# ORDER BY PROJECT_ID, PERIOD  
# ==> pList

######## PList 
# {project_id, 
# period, 
# PLAN_STATUS, 当期还款计划状态（0：等待执行；1：正常执行中；2：逾期执行中；3：已结清；4：已终止；5：已核销）
# overdue_days  0 正常， 1 该期曾逾期
# }
# 每个项目按期数倒序
prj_id = ''
period_idx = 0
flags = []
for prj in PList:
    # 一个新项目
    if (prj.project_id != prj_id):
        # 先完成上一个项目，（简化）只基于当前连续逾期期数，向前反推，不考虑前面多期逾期但已经结清的逻辑
        if (len(flags)>0):
            # 
            for i in range(len(flags)):
                s = ''
                for j in range(len(flags), 0, -1):
                    s = s + flags[j]
                    if (int(flags[j]) in range(1, 9):     #range(49, 57)):  # ASCII 49-57 为 1-9
                        flags[j] = int(flags[j]) - 1



        # 新的一个项目 
        prj_id = prj.project_id
        period_count = prj.period   # 该项目已执行的期数
        cont_overdue = 0 # 连续标志
        flags = []
        month_24_stat = '///////////////////////*'   // 初始开户状态
    
    flags[prj.period] = get_flag(prj.overdue_days)
    if (overdue_days==0):
        cont_overdue = 0
    else:
        cont_overdue++
    




def get_flag(overdue_days):
    f = 'N'
    
    if (overdue_days>=1 and overdue_days<=30):
        f = '1'
    elif (overdue_days>=31 and overdue_days<=60):
        f = '2'
    elif (overdue_days>=61 and overdue_days<=90):
        f = '3'
    elif (overdue_days>=91 and overdue_days<=120):
        f = '4'
    elif (overdue_days>=121 and overdue_days<=150):
        f = '5'
    elif (overdue_days>=151 and overdue_days<=180):
        f = '6'
    else:  #elif (overdue_days>=181):
        f = '7'
    # // 现逾期的，应该不存在后续 D Z C G 状态

# p2:
# -- for project in 逾期Project List
# projectID = ''
# for pi in pList
# 	if projectID != pi.project_id
# 		projectID = pi.project_id
# 		period_idx = 0
# 		continue_overdue = 0  -- 连续标志，如果当前期为不逾期，置 0，否则 ++
# 		flag = '///////////////////////*'   // 开户
# 	if OVERDUE_DAYS=0 
# 		f = 'N'
# 	ELSE { 
# 		if (逾期天数 >= 1 and 逾期天数 <= 30)
# 			f = '1'
# 		ELSEIF (逾期天数 >= 31 and 逾期天数 <= 60)
# 			f = '2'
# 		ELSEIF  (逾期天数 >= 61 and 逾期天数 <= 90)
# 			f = '3'
# 		ELSEIF  (逾期天数 >= 91 and 逾期天数 <= 120)
# 			f = '4'
# 		ELSEIF  (逾期天数 >= 121 and 逾期天数 <= 150)
# 			f = '5'
# 		ELSEIF  (逾期天数 >= 151 and 逾期天数 <= 180)
# 			f = '6'
# 		ELSEIF  (逾期天数 >= 181)
# 			f = '7'
# 		# // 现逾期的，应该不存在后续 D Z C G 状态
			
# 	}
# 	flag = flag.SUBSTRING(1, ).concate(f)
		
# 	pi.逾期天数 
	

