CREATE DEFINER=`root`@`%` PROCEDURE `small_core`.`sp_gen_credit`(IN EXEC_DATE datetime)
BEGIN

-- 每天增量
-- { todo list }
-- 每日增量
-- 只报当期
-- 提前结清/回购
-- 身份/居住/职业，增量

-- =====================================
# 	v1  说明：只导出应还款日之后一天，处于逾期状态的
-- v2说明      v3全量
-- 1 
-- 1.1.一个人只要报过，就要一直报到结清
-- 1.2. 从逾期报表取出tmp_overdue_rpt没有的，插入到tmp_overdue_rpt表中
-- 1.3. 结清/回购后，删除项目
-- 2
-- 2.1 生成特殊交易表
-- {todo} 3 bug
-- 3.1 有总分计划还款时间PLAN_REPAY_DT超过当前日期的，需查下原因
-- {todo} 4 按日期跑

## -- tmp_overdue_repo：所有有过逾期的项目，一直跟踪到项目结清，第一次上报后，就不能清空，
# 需要上报记录的状态 settle_flag=0，
# 项目标记：第一次进入库：0（默认）；第一次报送完成后即改为1；项目结束为100；1x状态有各种不报送的特殊情况
# 结清后上报一条记录，并置settle_flag=100，不再上报
# 从每天自动生成的逾期报表（REPORT_OVERDUE）中拿到当前逾期的项目编号，加入到 tmp_overdue_repo 表中

-- set @EXPORT_START_DATE=DATE_FORMAT('2020-06-01' , '%Y-%m-%d');
# 通用的
-- 设置逾期天数，即逾期超过@OVERDUE_DAYS才报逾期
SET @OVERDUE_DAYS = 10; 
## -- 1. 设置导出时间
set @EXPORT_DATE=DATE_FORMAT(NOW() , '%Y-%m-%d');
-- 10号前
if EXEC_DATE is not null then
	set @EXPORT_DATE=DATE_FORMAT(EXEC_DATE , '%Y-%m-%d');
	if EXEC_DATE < '2020-06-10' then
		SET @OVERDUE_DAYS = 1; 
	end if;
end if;
set @EXPORT_START_DATE=DATE_FORMAT(date_add(@EXPORT_DATE, interval 0 - @OVERDUE_DAYS day)  , '%Y-%m-%d');
-- select  @EXPORT_START_DATE, @EXPORT_DATE; 
-- select  @EXPORT_START_DATE, @EXPORT_DATE; 
## -- 1. 设置导出时间
-- set @EXPORT_DATE=DATE_FORMAT(NOW() , '%Y-%m-%d');
-- set @EXEC_DATE=DATE_FORMAT('2020-06-01' , '%Y-%m-%d');
-- if EXEC_DATE is not null then
-- 	set @EXPORT_DATE=DATE_FORMAT(@EXEC_DATE , '%Y-%m-%d');
-- 	if @EXEC_DATE < '2020-06-10' then
-- 		SET @OVERDUE_DAYS = 2; 
-- 	end if;   	
-- else
--     set @EXPORT_DATE=DATE_FORMAT(NOW() , '%Y-%m-%d');
-- -- 	SET @OVERDUE_DAYS = 10; 
-- end if;
-- set @EXPORT_START_DATE=DATE_FORMAT(date_add(@EXPORT_DATE, interval 1 - @OVERDUE_DAYS day)  , '%Y-%m-%d');
-- -- select  @EXPORT_START_DATE, @EXPORT_DATE; 
-- 	
-- 未结清的，加入repo
-- INSERT INTO tmp_overdue_repo( PROJECT_ID )
-- (
-- 	SELECT APPLY_NO 
-- 	FROM APPLY_ORDER x
-- 	WHERE APPLY_STATUS = 10 AND  NO_SETT_PERIOD > 0
-- 		AND APPLY_NO NOT IN ( SELECT PROJECT_ID FROM tmp_overdue_repo )
-- );

# 将申请延期的项目的状态修改为12：settl_flag=12
-- update tmp_overdue_repo set settle_flag	= 12  where PROJECT_ID in (
-- 	SELECT DISTINCT APPLY_NO from temp_delay 
-- );

# 将不上报的项目的状态修改为13：settl_flag=13
-- update tmp_overdue_repo set settle_flag	= 13  where PROJECT_ID in (
-- 	SELECT DISTINCT APPLY_NO from temp_no_repo
-- );

## 从tmp_overdue_repo中取出今天要上报的项目清单
-- ==================================
-- v5 增量的报送范围
-- 1。逾期10天的（即应还日期在报送日前第10天）
-- 2。近10天内，正常还款的
-- 3。近10天内，回购和提前结清的，同时报送特殊交易
-- 4。最后一期后仍处于逾期的，在下一个自然月的1号开始报
-- ==================================

TRUNCATE table tmp_overdue_projects;

-- 在 (start_date, export_date] 提前结清（12），
INSERT INTO tmp_overdue_projects(PROJECT_ID , `type` )
( 
	SELECT DISTINCT PROJECT_ID , 12
	FROM tmp_overdue_repo tor
	WHERE 
		tor.settle_flag in (0, 1)
		AND PROJECT_ID NOT in ( SELECT PROJECT_ID FROM tmp_overdue_projects )
		AND PROJECT_ID IN  
		(SELECT APPLY_NO FROM APPLY_ORDER WHERE APPLY_STATUS = 12 and END_DATE > @EXPORT_START_DATE AND END_DATE <= @EXPORT_DATE )
);

-- 在(start_date, export_date] 回购（13）
INSERT INTO tmp_overdue_projects(PROJECT_ID , `type` )
( 
	SELECT DISTINCT PROJECT_ID , 13
	FROM tmp_overdue_repo tor
	WHERE 
		tor.settle_flag in (0, 1)
		AND PROJECT_ID NOT in ( SELECT PROJECT_ID FROM tmp_overdue_projects )
		AND PROJECT_ID IN  
		(SELECT APPLY_NO FROM APPLY_ORDER WHERE APPLY_STATUS = 13 and END_DATE > @EXPORT_START_DATE AND END_DATE <= @EXPORT_DATE )
);

-- 应还日在(start_date, export_date] 期间，且已还款的（正常还清本期 / 逾期但在期间还清的）
INSERT INTO tmp_overdue_projects(PROJECT_ID , `type` )
( 
	SELECT DISTINCT tor.PROJECT_ID,  0
	FROM tmp_overdue_repo tor,
		SETT_REPAYMENT_PLAN srp				
	WHERE 
		tor.settle_flag in (0, 1)	
		AND tor.PROJECT_ID 			= 	srp.PROJECT_ID
		
  		AND (srp.PLAN_END_DATE 		> 	@EXPORT_START_DATE
  		AND srp.PLAN_END_DATE 		<= 	@EXPORT_DATE)  	
  		
		AND (srp.PLAN_SETTLE_DATE 	> 	@EXPORT_START_DATE
		AND srp.PLAN_SETTLE_DATE 	<=  @EXPORT_DATE)
		
		AND srp.PLAN_SETTLE_DATE 	> 	tor.last_date
		AND tor.PROJECT_ID NOT IN ( SELECT PROJECT_ID FROM tmp_overdue_projects )
);


-- 6.1 - 应还日是10天前（start_date+1），且至今未结清本期的
INSERT INTO tmp_overdue_projects(PROJECT_ID , `type` )
( 
	SELECT DISTINCT tor.PROJECT_ID 	, 10
	FROM tmp_overdue_repo tor,
		SETT_REPAYMENT_PLAN srp	
	WHERE 
		tor.settle_flag in (0, 1)
		AND  @OVERDUE_DAYS = 10
		AND tor.PROJECT_ID = srp.PROJECT_ID 
		AND DATE_FORMAT(tor.last_date , '%m') <> DATE_FORMAT(@EXPORT_DATE , '%m')
		AND srp.PLAN_END_DATE 		= DATE_FORMAT(date_add(@EXPORT_START_DATE, interval 1 day)  , '%Y-%m-%d')
-- 		AND srp.PLAN_END_DATE 		>= 	@EXPORT_START_DATE
-- 		AND srp.PLAN_END_DATE 		<=	date_add(@EXPORT_DATE, interval 0-@OVERDUE_DAYS day) 
		AND (srp.PLAN_SETTLE_DATE IS NULL OR  TIMESTAMPDIFF(DAY, REPAYMENT_DATE, srp.PLAN_SETTLE_DATE) >= @OVERDUE_DAYS)
		AND tor.PROJECT_ID NOT IN ( SELECT PROJECT_ID FROM tmp_overdue_projects )
		
);


-- 每月1号，报送最后一期超期的（总逾期30天以上）
INSERT INTO tmp_overdue_projects(PROJECT_ID , `type` )
( 
	SELECT DISTINCT APPLY_NO , 11
	FROM tmp_overdue_repo tor,
		APPLY_ORDER  ao
	where
		DATE_FORMAT(@EXPORT_DATE , '%d') = '01'
		AND tor.settle_flag in (0, 1)
		AND tor.PROJECT_ID = ao.APPLY_NO 	
		AND ao.END_DATE < date_add(@EXPORT_DATE, interval -1 MONTH ) 
		AND NO_SETT_PERIOD > 0
		AND tor.PROJECT_ID NOT IN ( SELECT PROJECT_ID FROM tmp_overdue_projects )
);





-- 期间 回购和提前结清的，同时报送特殊交易 (合并到结清）
-- INSERT INTO tmp_overdue_projects
-- ( 
-- 	SELECT DISTINCT PROJECT_ID 
-- 	FROM tmp_overdue_repo tor
-- 	WHERE 
-- 		tor.settle_flag in (0, 1)
-- 		AND PROJECT_ID IN 
-- 		(SELECT APPLY_NO FROM APPLY_ORDER WHERE APPLY_STATUS in (12, 13) and END_DATE > "2020-05-31")
-- );

-- -- 1。逾期10天的
-- DROP table IF EXISTS tmp_overdue_projects;
-- CREATE TABLE tmp_overdue_projects 
-- TRUNCATE TABLE tmp_overdue_projects;
-- INSERT INTO tmp_overdue_projects
-- ( 
-- 	SELECT DISTINCT tor.PROJECT_ID 	
-- 	FROM tmp_overdue_repo tor,
-- 		SETT_REPAYMENT_PLAN srrp,
-- 		REPORT_OVERDUE ro		
-- 	WHERE 
-- 		tor.settle_flag in (0, 1)
-- 		AND ro.overdue_days = 10
-- 		AND srrp.PROJECT_ID = tor.PROJECT_ID
-- 		AND ro.PROJECT_ID 	= tor.PROJECT_ID
-- 		AND srrp.PLAN_END_DATE =  date_add(@EXPORT_DATE, interval 0-@OVERDUE_DAYS day)
-- );

-- -- 2。近10天内，正常还款的，且未报送的
-- INSERT INTO tmp_overdue_projects
-- ( 
-- 	SELECT DISTINCT tor.PROJECT_ID
-- 	FROM 
-- 		SETT_REPAYMENT_PLAN srp,
-- 		tmp_overdue_repo tor
-- 		
-- 	WHERE 
-- 		tor.settle_flag in (0, 1)
-- 		AND srp.PLAN_SETTLE_DATE 	>= 	date_add(@EXPORT_DATE, interval 0 - @OVERDUE_DAYS day)
-- 		AND srp.PLAN_SETTLE_DATE 	> 	tor.last_date 
-- 		-- AND tor.last_date 			< 	date_add(@EXPORT_DATE, interval 0-@OVERDUE_DAYS day)
-- 		AND tor.PROJECT_ID 			= 	srp.PROJECT_ID
-- 		AND tor.PROJECT_ID NOT IN ( SELECT PROJECT_ID FROM tmp_overdue_projects )
-- );

-- -- 3。近10天内，回购和提前结清的，同时报送特殊交易
-- INSERT INTO tmp_overdue_projects
-- ( 
-- 	SELECT DISTINCT PROJECT_ID 
-- 	FROM tmp_overdue_repo tor
-- 	WHERE 
-- 		tor.settle_flag in (0, 1)
-- 		AND PROJECT_ID IN 
-- 			(SELECT APPLY_NO FROM APPLY_ORDER 
-- 			WHERE APPLY_STATUS in (12, 13) 
-- 			and END_DATE > date_add(@EXPORT_DATE, interval 0 - @OVERDUE_DAYS day))
-- );

-- {todo}报送日前10天内提前结清的和回购的，要增加一条
-- 无法保证及时性，考虑？？？   状态为提前结清或回购，且未报送该报文的

-- 4。最后一期后仍处于逾期的的，在1号统一报送
-- 超过最后一次还款的数据构造 1。在下下一个自然月的第一天生成上一自然月的数据 2。应还日期设置为自然月的最后一天 3。一直未还的，则24月状态一直向前循环
-- set @EXPORT_DATE=DATE_FORMAT('2020-06-1' , '%Y-%m-%d');
-- INSERT INTO tmp_overdue_projects
-- ( 	
-- 	SELECT tor.PROJECT_ID -- ,srp.REPAYMENT_DATE
-- 	FROM 
-- 		SETT_REPAYMENT_PLAN srp ,
-- 		tmp_overdue_repo tor
-- 	WHERE DAY(@EXPORT_DATE) = 1   -- 只在 1 号报送
-- 		AND tor.PROJECT_ID = srp.PROJECT_ID 
-- 		AND srp.PLAN_SETTLE_DATE IS NULL 
-- 		GROUP by PROJECT_ID 
-- 		HAVING max(REPAYMENT_DATE) < date_add(@EXPORT_DATE, interval -1 MONTH )
-- );


-- =====================================
-- =====================================
-- =====================================
-- start: 核心逻辑过程
-- =====================================

## -- 当前逾期项目的查询字段
-- AND PROJECT_ID in ( SELECT DISTINCT PROJECT_ID FROM tmp_overdue_projects )

## -- 逾期的租金计划
-- DROP table if exists tmp_SETT_RENT_RECEIPT_PLAN;
-- CREATE table tmp_SETT_RENT_RECEIPT_PLAN
TRUNCATE TABLE tmp_SETT_RENT_RECEIPT_PLAN;
INSERT INTO tmp_SETT_RENT_RECEIPT_PLAN
(
    select * from SETT_RENT_RECEIPT_PLAN
    WHERE PROJECT_ID in (SELECT PROJECT_ID FROM tmp_overdue_projects)
);

-- 逾期的租金计划detail
-- DROP table if exists tmp_SETT_RENT_RECEIPT_PLAN_DETAIL;
-- CREATE table tmp_SETT_RENT_RECEIPT_PLAN_DETAIL
TRUNCATE TABLE tmp_SETT_RENT_RECEIPT_PLAN_DETAIL;
INSERT INTO tmp_SETT_RENT_RECEIPT_PLAN_DETAIL
(
    select srrpd.*, srrp.PERIOD  from SETT_RENT_RECEIPT_PLAN_DETAIL srrpd, SETT_RENT_RECEIPT_PLAN srrp
    WHERE srrpd.RENT_RECEIPT_PLAN_ID = srrp.RECEIPT_PLAN_ID 
		and srrpd.PROJECT_ID in (SELECT PROJECT_ID FROM tmp_overdue_projects)
);

-- apply_order
-- DROP table if exists tmp_APPLY_ORDER;
-- CREATE table tmp_APPLY_ORDER
TRUNCATE TABLE tmp_APPLY_ORDER;
INSERT INTO tmp_APPLY_ORDER
(
    SELECT * FROM APPLY_ORDER ao 
    WHERE APPLY_NO in (SELECT PROJECT_ID FROM tmp_overdue_projects)
);

-- repayment-detail
-- DROP table if exists tmp_repay_plan_detail;
-- CREATE table tmp_repay_plan_detail
TRUNCATE TABLE tmp_repay_plan_detail;
INSERT INTO tmp_repay_plan_detail
(
    select 
        srrp.PROJECT_ID, RECEIPT_PLAN_DATE, PERIOD, CURRENCY, 
        GENERATE_FINE_RECEIPT_PLAN_MARK, LAST_END_OF_DAY_HANDLE_DATE, WRITE_BUSINESS_DATE,
        -- detail below
        SUBJECT, srrpd.RECEIPT_AMOUNT_IT
    FROM 
        SETT_RENT_RECEIPT_PLAN srrp , 
        SETT_RENT_RECEIPT_PLAN_DETAIL srrpd
    WHERE -- srrp.PROJECT_ID in (SELECT PROJECT_ID FROM tmp_overdue_projects)
        -- and 
        srrpd.PROJECT_ID in (SELECT PROJECT_ID FROM tmp_overdue_projects)
        and srrp.RECEIPT_PLAN_ID = srrpd.RENT_RECEIPT_PLAN_ID 
);
 

-- 逾期的 instmnt
-- select * from  tmp_repay_instmnt order by PROJECT_ID, PERIOD;
-- DROP TABLE if exists tmp_repay_instmnt;
-- CREATE table tmp_repay_instmnt
TRUNCATE TABLE tmp_repay_instmnt;
INSERT INTO tmp_repay_instmnt
(
select
        PROJECT_ID, PERIOD, REPAYMENT_DATE, PLAN_START_DATE, PLAN_END_DATE, 
        EXPECTED_AMT, CURRENCY, PLAN_STATUS, OVERDUE_DAYS, OVERDUE_TOTAL_DAYS, 
        PLAN_SETTLE_DATE
        -- instmnt below
        CONTRACT_NO,  REPAY_AMT_TYPE, REPAY_DATE, CURR_PRIN_BAL, CURR_INT_BAL, 
        CURR_OVD_PRIN_PNLT_BAL, CURR_OVD_INT_PNLT_BAL, REPAY_AMT, PAID_PRIN_AMT, PAID_INT_AMT, 
        PAID_OVD_PRIN_PNLT_AMT, PAID_OVD_INT_PNLT_AMT
    FROM 
        SETT_REPAYMENT_PLAN srrp,
        REPAY_INSTMNT_DETAIL rid 
    WHERE srrp.PROJECT_ID = rid.APPLY_NO 
        and srrp.PERIOD = rid.TERM_NO 
        -- and srrp.PROJECT_ID in (SELECT PROJECT_ID FROM tmp_overdue_projects)
        and rid.APPLY_NO in (SELECT PROJECT_ID FROM tmp_overdue_projects)
);






-- set @EXPORT_DATE=DATE_FORMAT(NOW() , '%Y-%m-%d');

-- SELECT @EXPORT_DATE;
# -- 基础信息
-- 逾期的人从第一期到今的还款计划，即所有需要计算的 project + period
-- SELECT * FROM tmp_repay_plan_till_now order by PROJECT_ID, PERIOD;
-- DROP table if exists tmp_repay_plan_till_now;
-- CREATE TABLE tmp_repay_plan_till_now
TRUNCATE TABLE tmp_repay_plan_till_now;
INSERT INTO tmp_repay_plan_till_now
(
SELECT
    PROJECT_ID,
    PERIOD,
    REPAYMENT_DATE,
    PLAN_START_DATE,
    REPAYMENT_DATE as PLAN_END_DATE,
    EXPECTED_AMT,
    PLAN_STATUS ,
    OVERDUE_DAYS ,
    PLAN_SETTLE_DATE
FROM
    SETT_REPAYMENT_PLAN 
WHERE
    PROJECT_ID in ( SELECT DISTINCT PROJECT_ID FROM tmp_overdue_projects )
    -- PROJECT_ID =  '201906070682845776A' 
    and (REPAYMENT_DATE <= @EXPORT_DATE OR PLAN_SETTLE_DATE <= @EXPORT_DATE)
ORDER BY
    PROJECT_ID,
    PERIOD 
   );

-- SELECT * FROM tmp_repay_plan_till_now order by PROJECT_ID , PERIOD ;

   
-- 最后一期已经逾期的
##################
-- 补充超过12期的
CALL sp_add_overdue(@EXPORT_DATE) ;
######################

--  不再从原始表中查询数据，只从生成的 tmp_xxx 表
######################


-- ===============================================
# -- 说明
-- 包括3种类型字段 
-- a. 通用字段，同一用户的每条记录都相同
-- b. 同一用户，分期
-- c. 统计期向上（已经产生的）或向下汇总（剩余）
-- 所有项目为目前正在逾期的
-- 所有记录（除向下汇总的剩余相关）为截止当前已经发生的期
-- --------------------------

# -- 3. 通用信息
-- == fixed 以下为共用的字段
-- 取 finance_lease_apply中的 apply_order

## 通用-- ===========================
TRUNCATE table tmp_overdue;
INSERT INTO tmp_overdue 
(ProjectID,
    Peroid,
    over_day_count,
    FINORGCODE,
    LOANTYPE,
    LOANBIZTYPE,
    BUSINESS_NO,
    AREACODE,
    STARTDATE,
    ENDDATE,
    CURRENCY,
    CREDIT_TOTAL_AMT,
    SHARE_CREDIT_TOTAL_AMT,
    MAX_DEBT_AMT,
    GUARANTEEFORM,
    PAYMENT_RATE,
    PAYMENT_MONTHS,
    NO_PAYMENT_MONTHS,
    PLAN_REPAY_DT,
    LAST_REPAY_AMT,
    OVERDRAFT_180DAYS_BAL,
    LOAN_ACCOUNT_STAT,
    CUSTNAME,
    CERTTYPE,
    CERTNO,
    CUSTID,
    BAKE)
(SELECT
    ao.APPLY_NO as ProjectID,
    trptn.PERIOD as Peroid,
    0 as over_day_count, 
    'M10154210H0001' AS FINORGCODE,
    '4' AS LOANTYPE,
    '92' AS LOANBIZTYPE,
    ao.LEASE_CONTRACT_NO AS BUSINESS_NO,
    '360102' AS AREACODE,
    -- {todo}
    DATE_FORMAT(ao.START_DATE, '%Y%m%d') AS STARTDATE,
    DATE_FORMAT(ao.END_DATE, '%Y%m%d') AS ENDDATE,
    'CNY' AS CURRENCY,
    ao.ACTUAL_AMOUNT AS CREDIT_TOTAL_AMT,
    ao.ACTUAL_AMOUNT AS SHARE_CREDIT_TOTAL_AMT,
    ao.ACTUAL_AMOUNT AS MAX_DEBT_AMT,
    ao.LEASE_TYPE AS GUARANTEEFORM,
    '03' AS PAYMENT_RATE,
    ao.PERIOD AS PAYMENT_MONTHS,
    (ao.PERIOD - trptn.PERIOD) AS NO_PAYMENT_MONTHS,
    -- causion
    DATE_FORMAT(trptn.REPAYMENT_DATE, '%Y%m%d') as PLAN_REPAY_DT,
    0 as LAST_REPAY_AMT,
    0 as OVERDRAFT_180DAYS_BAL,
    '1' as LOAN_ACCOUNT_STAT,
    ao.USER_ACCOUNT_NAME AS CUSTNAME,
    '0' AS CERTTYPE,
    ao.ID_CARD_NO AS CERTNO,
    ao.ID_CARD_NO AS CUSTID,
    '' AS BAKE
FROM
    tmp_APPLY_ORDER ao,
    tmp_repay_plan_till_now trptn
WHERE
    ao.APPLY_NO = trptn.PROJECT_ID
    and trptn.PERIOD <= ao.PERIOD 
ORDER BY
    ao.APPLY_NO,
    ao.PERIOD
    );



### -- 目前还处于逾期执行中的，进行汇总
 -- 方法：每期的完成时间与当前期的时间对比，大于当前期则 +1  
-- SELECT * from tmp_CUR_OVERDUE_TOTAL_INT;
-- DROP table if exists tmp_CUR_OVERDUE_TOTAL_INT; 
-- CREATE table tmp_CUR_OVERDUE_TOTAL_INT 
TRUNCATE TABLE tmp_CUR_OVERDUE_TOTAL_INT;
INSERT INTO tmp_CUR_OVERDUE_TOTAL_INT
(
	SELECT 
	    PROJECT_ID , PERIOD ,REPAYMENT_DATE, IFNULL(PLAN_SETTLE_DATE, @EXPORT_DATE ) as SETTLE_DATE
	FROM 
	    tmp_repay_plan_till_now
	-- WHERE 
	    -- PROJECT_ID in ( SELECT DISTINCT PROJECT_ID FROM tmp_overdue_projects )
	    -- and 
	--    REPAYMENT_DATE < IFNULL(PLAN_SETTLE_DATE, @EXPORT_DATE )
	 order by PROJECT_ID , PERIOD
);

-- 
UPDATE
    tmp_overdue
inner JOIN ( 
    SELECT a.PROJECT_ID , a.PERIOD, COUNT(b.SETTLE_DATE)  as CUR_OVERDUE_TOTAL_INT
    FROM tmp_CUR_OVERDUE_TOTAL_INT a
    JOIN tmp_CUR_OVERDUE_TOTAL_INT b
    ON 
        a.PROJECT_ID = b.PROJECT_ID 
    WHERE
        b.PERIOD <= a.PERIOD
        and b.SETTLE_DATE > a.REPAYMENT_DATE
    GROUP by a.PROJECT_ID , a.PERIOD
    ORDER by a.PROJECT_ID , a.PERIOD
) as up_tab ON
    tmp_overdue.ProjectID = up_tab.PROJECT_ID
    AND tmp_overdue.Peroid = up_tab.PERIOD 
SET
    tmp_overdue.CUR_OVERDUE_TOTAL_INT = up_tab.CUR_OVERDUE_TOTAL_INT;

### --  其他全部置 0
UPDATE tmp_overdue set CUR_OVERDUE_TOTAL_INT=0 where CUR_OVERDUE_TOTAL_INT is NULL;

## 最高逾期期数 MAX_OVERDUE_INT
-- 所有已经产生的逾期期数中，取最大值
UPDATE tmp_overdue 
inner JOIN (
    SELECT
        a.ProjectID,
        a.Peroid,
        MAX(b.CUR_OVERDUE_TOTAL_INT) AS MAX_OVERDUE_INT
    FROM
        tmp_overdue a
    JOIN tmp_overdue b
    WHERE
        a.ProjectID = b.ProjectID
        AND b.Peroid <= a.Peroid
        
    GROUP BY
        a.ProjectID,
        a.Peroid 
)as up_tab ON
    tmp_overdue.ProjectID = up_tab.ProjectID
    AND tmp_overdue.Peroid = up_tab.Peroid 
SET
    tmp_overdue.MAX_OVERDUE_INT = up_tab.MAX_OVERDUE_INT;
   
 
## -- == 累计逾期期数
UPDATE
    tmp_overdue
inner JOIN (
    SELECT
            a.PROJECT_ID,
            a.PERIOD,
            COUNT(b.PERIOD) as total_overdue
        FROM
            tmp_CUR_OVERDUE_TOTAL_INT a
        JOIN
            tmp_CUR_OVERDUE_TOTAL_INT b
        WHERE
            a.PROJECT_ID=b.PROJECT_ID
        AND b.PERIOD <= a.PERIOD
        AND b.SETTLE_DATE > b.REPAYMENT_DATE
        GROUP BY
            a.PROJECT_ID,
            a.PERIOD  )as up_tab ON
    tmp_overdue.ProjectID = up_tab.PROJECT_ID
    AND tmp_overdue.Peroid = up_tab.PERIOD 
SET
    tmp_overdue.SUM_OVERDUE_INT = up_tab.total_overdue;   
   
   
# 处理  1、到期前提前结清，应还日错误，24个月状态错误。正确的为：应还日=实还日，与上一期在同一个月内结清，24个月状态更新上期最后一位为C，例如附件中第78行和第79行，应还日为2月8日的款项实际逾期，2月份24个月状态为：////////////*NNNNNNNNNN1，客户于2月23日全额提前结清，24个月状态应为////////////*NNNNNNNNNNC。该情况下仅用C更新掉1，累计逾期期数与最高逾期期数不做维护。   

############################
CALL  sp_add_overdue_period(@EXPORT_DATE) ;
##########################
   
# -- 不需汇总字段
## -- 本月应还款金额（以还款计划表为准）
UPDATE
    tmp_overdue
inner JOIN (
    SELECT
        PROJECT_ID,
        PERIOD, 
        RECEIPT_AMOUNT_IT
        FROM tmp_SETT_RENT_RECEIPT_PLAN
    group by
        PROJECT_ID,
        PERIOD ) as up_tab 
    ON
        tmp_overdue.ProjectID = up_tab.PROJECT_ID
        AND tmp_overdue.Peroid = up_tab.PERIOD 
    SET
        tmp_overdue.PLAN_REPAY_AMT = up_tab.RECEIPT_AMOUNT_IT;



## -- 本月实际还款金额（以蚂蚁实收报表为准）
### v2.0每期还款时间内还款金额
UPDATE
    tmp_overdue
inner JOIN (   
    SELECT 
        srp.PROJECT_ID, srp.PERIOD, SUM(rid.REPAY_AMT)  as LAST_REPAY_AMT , max(rid.REPAY_DATE) as LAST_REPAY_DT
    FROM 
        tmp_repay_plan_till_now srp 
    left join 
        tmp_repay_instmnt rid -- REPAY_INSTMNT_DETAIL  
    on srp.PROJECT_ID = rid.PROJECT_ID
    WHERE -- srp.PROJECT_ID = rid.APPLY_NO
        -- and rid.APPLY_NO in ( SELECT DISTINCT PROJECT_ID FROM tmp_overdue_projects ) 
        -- and srp.PROJECT_ID in ( SELECT DISTINCT PROJECT_ID FROM tmp_overdue_projects ) 
        -- AND 
        (rid.REPAY_DATE > srp.PLAN_START_DATE  
        AND rid.REPAY_DATE <= srp.REPAYMENT_DATE )
    GROUP by PROJECT_ID, PERIOD
) as up_tab 
ON
    tmp_overdue.ProjectID = up_tab.PROJECT_ID
    AND tmp_overdue.Peroid = up_tab.PERIOD 
SET 
    tmp_overdue.LAST_REPAY_DT = up_tab.LAST_REPAY_DT,
    tmp_overdue.LAST_REPAY_AMT = up_tab.LAST_REPAY_AMT;

## -- 最近一次实际还款日期；本期无，则用历史最新
UPDATE
    tmp_overdue
inner JOIN (
SELECT
    a.ProjectID,
    a.Peroid,
    MAX(b.LAST_REPAY_DT) as max_dt_till_now
FROM
    tmp_overdue a
JOIN tmp_overdue b
WHERE
    a.ProjectID = b.ProjectID
    and b.Peroid <= a.Peroid
    and a.LAST_REPAY_DT IS NULL 
group by
    a.ProjectID,
    a.Peroid
) as up_tab ON
    tmp_overdue.ProjectID = up_tab.ProjectID
    AND tmp_overdue.Peroid = up_tab.Peroid 
SET
    tmp_overdue.LAST_REPAY_DT = up_tab.max_dt_till_now; -- ,
    -- tmp_overdue.LAST_REPAY_AMT = 0;

-- 回购的
-- set
-- LAST_REPAY_AMT = PLAN_REPAY_AMT   
-- 
-- FROM 
-- 	tmp_overdue to2 ,
-- 	tmp_overdue_repo tor
-- WHERE 
-- 	tor.settle_flag in (0, 1)
-- 	AND PROJECT_ID NOT in ( SELECT PROJECT_ID FROM tmp_overdue_projects )
-- 	AND PROJECT_ID IN  
-- 	(SELECT APPLY_NO FROM APPLY_ORDER WHERE APPLY_STATUS in (12, 13) and END_DATE > @EXPORT_START_DATE AND END_DATE <= @EXPORT_DATE )
--     
# --   ======  以下为需要汇总的字段 
## -- ==余额 
-- 此数据项是指贷款本金余额。 用总贷款本金ao.ACTUAL_AMOUNT - 已还本金
-- 先计算已还本金
    
-- 改为截止当期还款时间，即在每一期还款时间内的还款本金
-- select * from tmp_paid_prin order by PROJECT_ID, PERIOD;
-- DROP TABLE if exists tmp_paid_prin;
-- CREATE TABLE tmp_paid_prin 
TRUNCATE TABLE tmp_paid_prin;
INSERT INTO tmp_paid_prin
(
	select
		a.PROJECT_ID ,
		a.PERIOD ,
		ifnull(SUM(PAID_PRIN_AMT),0) as paid_prin
	FROM
		tmp_repay_plan_till_now a
	left join tmp_repay_instmnt b 
	on
		a.PROJECT_ID = b.PROJECT_ID
		and (b.REPAY_DATE <= a.REPAYMENT_DATE or REPAY_DATE is NULL)

	GROUP by PROJECT_ID , PERIOD 
	order by PROJECT_ID , PERIOD 
	
);
	
### 截止每一期时，实际总共已还款本金
   
### -- 余额 = 总本金 - 已还本金   
UPDATE
    tmp_overdue
inner JOIN (
    SELECT
        ao.PROJECT_ID,
        tmp_paid_prin.PERIOD,
        (ao.TOTAL_PRI_AMT - IFNULL(tmp_paid_prin.paid_prin, 0)) as BALANCE
    FROM
        (SELECT
			PROJECT_ID , SUM(RECEIPT_AMOUNT_IT)  as TOTAL_PRI_AMT
			FROM 
			tmp_SETT_RENT_RECEIPT_PLAN_DETAIL
			WHERE SUBJECT = 'PRI'
			group by PROJECT_ID) ao 
			left JOIN 
		tmp_paid_prin
    on 
        ao.PROJECT_ID = tmp_paid_prin.PROJECT_ID
    GROUP BY
        ao.PROJECT_ID,
        tmp_paid_prin.PERIOD
    order by ao.PROJECT_ID,
        tmp_paid_prin.PERIOD
        ) as up_tab 
        ON
    tmp_overdue.ProjectID = up_tab.PROJECT_ID
    AND tmp_overdue.Peroid = up_tab.PERIOD 
SET
    tmp_overdue.BALANCE = up_tab.BALANCE;


    
-- 向前累积求和，截止当前所有逾期的总额
-- 每期租金
-- DROP table if exists tmp_period_EXPECTED_AMT;
-- CREATE  table tmp_period_EXPECTED_AMT
TRUNCATE TABLE tmp_period_EXPECTED_AMT;
INSERT INTO tmp_period_EXPECTED_AMT
(
	-- SELECT
	-- 	PROJECT_ID , PERIOD , REPAYMENT_DATE , EXPECTED_AMT 
	-- FROM 
	-- 	SETT_REPAYMENT_PLAN 
	-- WHERE 
	-- 	PROJECT_ID in ( SELECT DISTINCT PROJECT_ID FROM tmp_overdue_projects ) 
	-- 	and (REPAYMENT_DATE < @EXPORT_DATE OR PLAN_SETTLE_DATE < @EXPORT_DATE) 
		
	SELECT 
	    srrp.PROJECT_ID, srrp.PERIOD, srrp.RECEIPT_PLAN_DATE, srrp.RECEIPT_AMOUNT_IT
	FROM 
	    SETT_RENT_RECEIPT_PLAN srrp,
	    SETT_REPAYMENT_PLAN srp    
	WHERE 
	    srrp.PROJECT_ID in ( SELECT DISTINCT PROJECT_ID FROM tmp_overdue_projects ) 
	    and srp.PROJECT_ID IN  ( SELECT DISTINCT PROJECT_ID FROM tmp_overdue_projects ) 
	    and srp.PROJECT_ID = srrp.PROJECT_ID 
	    AND srp.PERIOD = srrp.PERIOD 
	    and (srrp.RECEIPT_PLAN_DATE <= @EXPORT_DATE  OR srp.PLAN_SETTLE_DATE <= @EXPORT_DATE) 
	    
    
);
    
-- 截止每期时间的总租金
-- SELECT * from tmp_EXPECTED_AMT;  TEMPORARY
-- DROP TABLE if exists tmp_EXPECTED_AMT;
-- CREATE  TABLE tmp_EXPECTED_AMT
TRUNCATE TABLE tmp_EXPECTED_AMT;
INSERT INTO tmp_EXPECTED_AMT
(
	select 
		a.PROJECT_ID,
	    a.PERIOD,
	    a.REPAYMENT_DATE,
	    sum(b.EXPECTED_AMT) AS p_EXPECTED_AMT
	from tmp_repay_plan_till_now a , tmp_period_EXPECTED_AMT b
	WHERE a.PROJECT_ID = b.PROJECT_ID 
	AND b.PERIOD <= a.PERIOD
	GROUP BY
	    a.PROJECT_ID,
	    a.PERIOD
);



-- 截止每期时间的总罚息
-- SELECT * FROM tmp_fine_AMT;
-- DROP TABLE if exists tmp_fine_AMT;
-- CREATE TEMPORARY TABLE tmp_fine_AMT
-- (
-- SELECT tea.PROJECT_ID, tea.PERIOD,  sum(sfrp.RECEIPT_AMOUNT_IT) as p_fine_AMT
-- FROM 
--     tmp_EXPECTED_AMT tea
-- left join 
--     SETT_FINE_RECEIPT_PLAN sfrp
-- on 
--     tea.PROJECT_ID = sfrp.PROJECT_ID 
-- WHERE sfrp.RECEIPT_PLAN_DATE <= tea.REPAYMENT_DATE
-- GROUP by tea.PROJECT_ID, tea.PERIOD
-- );

-- 截止每期时间的总租金还款        TEMPORARY
-- DROP TABLE IF EXISTS tmp_REPAY_AMT;
-- CREATE  TABLE tmp_REPAY_AMT
TRUNCATE TABLE tmp_REPAY_AMT;
INSERT INTO tmp_REPAY_AMT
(
	SELECT tea.PROJECT_ID, tea.PERIOD,  sum(rid.PAID_PRIN_AMT+rid.PAID_INT_AMT) as p_repay_AMT
	FROM 
	    tmp_EXPECTED_AMT tea
	left join tmp_repay_instmnt rid
	on 
	    tea.PROJECT_ID = rid.PROJECT_ID 
	WHERE rid.REPAY_DATE <= tea.REPAYMENT_DATE
	GROUP by tea.PROJECT_ID, tea.PERIOD
);

-- 已还租金
-- 


-- SELECT * FROM tmp_REPAY_AMT;
-- 当前逾期总额
UPDATE
    tmp_overdue
inner JOIN (
	SELECT
	    te.PROJECT_ID, te.PERIOD, (te.p_EXPECTED_AMT-IFNULL(tr.p_repay_AMT,0)) as CUR_OVERDUE_TOTAL_AMT   -- +IFNULL(tf.p_fine_AMT,0)
	FROM tmp_EXPECTED_AMT te
	-- left join tmp_fine_AMT tf
	-- on
	--     te.PROJECT_ID = tf.PROJECT_ID
	--     and te.PERIOD = tf.PERIOD
	left join tmp_REPAY_AMT tr
	on 
	    te.PROJECT_ID = tr.PROJECT_ID
	    and te.PERIOD = tr.PERIOD
	GROUP BY te.PROJECT_ID, te.PERIOD
    ) as up_tab ON
    tmp_overdue.ProjectID = up_tab.PROJECT_ID
    AND tmp_overdue.Peroid = up_tab.PERIOD 
SET
    tmp_overdue.CUR_OVERDUE_TOTAL_AMT = up_tab.CUR_OVERDUE_TOTAL_AMT;


   
##############################
## -- 五级分类状态，从低级开始更新
# 应该根据这个来 CUR_OVERDUE_TOTAL_INT 
-- 1-正常；到目前为止，即使历史记录出现过逾期，但是客户已经偿还逾期款，目前没有逾期未还的租金，则当期征信上报五级分类为1-正常
UPDATE
    tmp_overdue
    set CLASSIFY5 = 1
    where CUR_OVERDUE_TOTAL_INT = 0;
    
-- 2-关注；到目前为止，有逾期未还的租金，且其中所有逾期未还租金中对应的逾期天数最高的在1-90天（含1天和90天），则当期征信上报五级分类为2-关注
UPDATE
    tmp_overdue
    set CLASSIFY5 = 2
    where CUR_OVERDUE_TOTAL_INT in (1, 2, 3);
-- 3-次级；到目前为止，有逾期未还的租金，且其中所有逾期未还租金中对应的逾期天数最高的在91-120天（含91天和120天），则当期征信上报五级分类为3-次级
UPDATE
    tmp_overdue
    set CLASSIFY5 = 3
    where CUR_OVERDUE_TOTAL_INT = 4 ;
-- 4-可疑；到目前为止，有逾期未还的租金，且其中所有逾期未还租金中对应的逾期天数最高的在121-180天（含121天和180天），则当期征信上报五级分类为4-可疑---改为 121 – 150 天
UPDATE
    tmp_overdue
    set CLASSIFY5 = 4
    where CUR_OVERDUE_TOTAL_INT in (5, 6);
-- 5-损失；到目前为止，有逾期未还的租金，且其中所有逾期未还租金中对应的逾期天数最高的在181天（含181天）以上，则当期征信上报五级分类为5-损失--- 改为151天以上
UPDATE
    tmp_overdue
    set CLASSIFY5 = 5
    where CUR_OVERDUE_TOTAL_INT >=7;
-- 9-未知.
 
## 24个月状态
-- 算法：计算每一期的逾期天数，向后面各期更新对应字符  
-- PLAN_STATUS 只有 0，1，2，3 这三种状态

### 1. 没有逾期
UPDATE
    tmp_overdue
inner JOIN (
	SELECT
	    PROJECT_ID,
	    PERIOD
	    FROM tmp_repay_plan_till_now 
	WHERE
	    OVERDUE_DAYS = 0
	    and PLAN_STATUS = 3
	group by
	    PROJECT_ID ,
	    PERIOD 
    )as up_tab ON
    tmp_overdue.ProjectID = up_tab.PROJECT_ID
    AND tmp_overdue.Peroid = up_tab.PERIOD 
SET
    tmp_overdue.over_day_count = 0;

### 2. 逾期且结清
UPDATE
    tmp_overdue
inner JOIN (
	SELECT PROJECT_ID, PERIOD,  datediff( PLAN_SETTLE_DATE , REPAYMENT_DATE ) as over_day_count -- TO_DAYS(PLAN_SETTLE_DATE) - TO_DAYS(REPAYMENT_DATE) -- datediff( PLAN_SETTLE_DATE , REPAYMENT_DATE )
	FROM tmp_repay_plan_till_now  
	WHERE 
		OVERDUE_DAYS = 1 and PLAN_STATUS=3  
	group by
    	PROJECT_ID , PERIOD 
    )as up_tab ON
    tmp_overdue.ProjectID = up_tab.PROJECT_ID
    AND tmp_overdue.Peroid = up_tab.PERIOD 
SET
    tmp_overdue.over_day_count = up_tab.over_day_count;

### 3. 逾期且未结清

--   SELECT * from tmp_repay_plan_till_now;
UPDATE
    tmp_overdue
inner JOIN (
	SELECT 
		PROJECT_ID, PERIOD,  datediff( @EXPORT_DATE , REPAYMENT_DATE ) as over_day_count -- TO_DAYS(PLAN_SETTLE_DATE) - TO_DAYS(REPAYMENT_DATE) -- datediff( PLAN_SETTLE_DATE , REPAYMENT_DATE )
	FROM 
		tmp_repay_plan_till_now trptn 
	WHERE 
		OVERDUE_DAYS = 1 and PLAN_STATUS=2
	group by
	    PROJECT_ID ,
	    PERIOD 
    )as up_tab ON
    tmp_overdue.ProjectID = up_tab.PROJECT_ID
    AND tmp_overdue.Peroid = up_tab.PERIOD 
SET
    tmp_overdue.over_day_count = up_tab.over_day_count;
   


## -- 账户状态
-- PLAN_STATUS  
--     当期还款计划状态（0：等待执行；1：正常执行中；2：逾期执行中；3：已结清；4：已终止；5：已核销）
-- LOAN_STAT
--     "1-正常：目前所有应还租金都已经还清
--     2-逾期：目前还有应还未还的租金未结清
--     3-结清：整个合同结清时上报的的最后一条数据"

-- 1-正常：目前所有应还租金都已经还清
UPDATE
    tmp_overdue
set LOAN_STAT = 1 
WHERE 
    CUR_OVERDUE_TOTAL_INT = 0;
-- 
-- 
-- -- 2-逾期：目前还有应还未还的租金未结清
UPDATE
    tmp_overdue
set LOAN_STAT = 2 
WHERE 
    CUR_OVERDUE_TOTAL_INT > 0;


-- 3-结清：整个合同结清时上报的的最后一条数据
UPDATE
    tmp_overdue
inner JOIN (
	SELECT APPLY_NO, PERIOD as max_period 
	FROM
	APPLY_ORDER
	WHERE APPLY_NO in ( SELECT DISTINCT PROJECT_ID FROM tmp_overdue_projects )
) as up_tab 
ON
    tmp_overdue.ProjectID = up_tab.APPLY_NO
    AND tmp_overdue.Peroid = up_tab.max_period 
AND (tmp_overdue.LOAN_STAT = 1 or tmp_overdue.BALANCE = 0)
SET
    tmp_overdue.LOAN_STAT = 3;
  

-- 特殊处理：提前结清，应还日还款，并提前结清
DELETE FROM tmp_overdue 
where LAST_REPAY_AMT=0 AND BALANCE=0;

UPDATE tmp_overdue 
set CUR_OVERDUE_TOTAL_AMT=0, LOAN_STAT=3, PLAN_REPAY_DT = LAST_REPAY_DT
-- PAYMENT_MONTHS = 
-- NO_PAYMENT_MONTHS = 
-- SELECT * FROM tmp_overdue 
where BALANCE=0 AND ProjectID IN (SELECT PROJECT_ID FROM tmp_overdue_projects where `type` = 12);

-- 特殊处理，结束
   
   
   
   
## 在这里插入每个人的第一条
## -- -- 第一条记录是新开户相关信息
-- 为减少影响，这条放在所有数据处理完后，最后再执行
INSERT
    INTO
    tmp_overdue (ProjectID,
    Peroid,
    over_day_count,
    FINORGCODE,
    LOANTYPE,
    LOANBIZTYPE,
    BUSINESS_NO,
    AREACODE,
    STARTDATE,
    ENDDATE,
    CURRENCY,
    CREDIT_TOTAL_AMT,
    SHARE_CREDIT_TOTAL_AMT,
    MAX_DEBT_AMT,
    GUARANTEEFORM,
    PAYMENT_RATE,
    PAYMENT_MONTHS,
    NO_PAYMENT_MONTHS,
    PLAN_REPAY_DT,
    LAST_REPAY_DT,
    PLAN_REPAY_AMT,
    LAST_REPAY_AMT,
    BALANCE,
    CUR_OVERDUE_TOTAL_INT,
    CUR_OVERDUE_TOTAL_AMT,
    OVERDUE31_60DAYS_AMT,
    OVERDUE61_90DAYS_AMT,
    OVERDUE91_180DAYS_AMT,
    OVERDUE_180DAYS_AMT,
    SUM_OVERDUE_INT,
    MAX_OVERDUE_INT,
    CLASSIFY5,
    LOAN_STAT,
    REPAY_MONTH_24_STAT,
    OVERDRAFT_180DAYS_BAL,
    LOAN_ACCOUNT_STAT,
    CUSTNAME,
    CERTTYPE,
    CERTNO,
    CUSTID,
    BAKE) (
    SELECT
        ao.APPLY_NO as ProjectID,
        '0' as Peroid,
        0 as over_day_count,
        'M10154210H0001' AS FINORGCODE,
        '4' AS LOANTYPE,
        '92' AS LOANBIZTYPE,
        ao.LEASE_CONTRACT_NO AS BUSINESS_NO,
        '360102' AS AREACODE,
        -- {todo}
        DATE_FORMAT(ao.START_DATE,'%Y%m%d') AS STARTDATE,
        DATE_FORMAT(ao.END_DATE,'%Y%m%d')  AS ENDDATE,
        'CNY' AS CURRENCY,
        ao.ACTUAL_AMOUNT AS CREDIT_TOTAL_AMT,
        ao.ACTUAL_AMOUNT AS SHARE_CREDIT_TOTAL_AMT,
        ao.ACTUAL_AMOUNT AS MAX_DEBT_AMT,
        ao.LEASE_TYPE AS GUARANTEEFORM,
        '03' AS PAYMENT_RATE,
        ao.PERIOD AS PAYMENT_MONTHS,
        ao.PERIOD AS NO_PAYMENT_MONTHS,
        DATE_FORMAT(ao.START_DATE,'%Y%m%d') as PLAN_REPAY_DT,
        DATE_FORMAT(ao.START_DATE,'%Y%m%d') as LAST_REPAY_DT,
        '0' as PLAN_REPAY_AMT,
        '0' as LAST_REPAY_AMT,
        ao.ACTUAL_AMOUNT as BALANCE,
        '0' as CUR_OVERDUE_TOTAL_INT,
        '0' as CUR_OVERDUE_TOTAL_AMT,
        '0' as OVERDUE31_60DAYS_AMT,
        '0' as OVERDUE61_90DAYS_AMT,
        '0' as OVERDUE91_180DAYS_AMT,
        '0' as OVERDUE_180DAYS_AMT,
        '0' as SUM_OVERDUE_INT,
        '0' as MAX_OVERDUE_INT,
        '1' as CLASSIFY5,
        '1' as LOAN_STAT,
        '///////////////////////*' as REPAY_MONTH_24_STAT,
        '0' as OVERDRAFT_180DAYS_BAL,
        '2' as LOAN_ACCOUNT_STAT,
        ao.USER_ACCOUNT_NAME AS CUSTNAME,
        '0' AS CERTTYPE,
        ao.ID_CARD_NO AS CERTNO,
        ao.ID_CARD_NO AS CUSTID,
        '' AS BAKE
    FROM
    tmp_APPLY_ORDER ao 
    
    --    APPLY_ORDER ao, 
    -- WHERE
    --    ao.APPLY_NO in ( SELECT DISTINCT PROJECT_ID FROM tmp_overdue_projects ) 
    );

-- DELETE FROM tmp_overdue WHERE Peroid = 0
-- UPDATE tmp_overdue set STARTDATE = DATE_FORMAT(STARTDATE, '%Y%m%d');
-- UPDATE tmp_overdue set ENDDATE = DATE_FORMAT(ENDDATE, '%Y%m%d');
-- UPDATE tmp_overdue set PLAN_REPAY_DT = DATE_FORMAT(PLAN_REPAY_DT, '%Y%m%d');
-- UPDATE tmp_overdue set LOAN_ACCOUNT_STAT = 1 WHERE Peroid <> 0;
-- UPDATE tmp_overdue set LAST_REPAY_AMT = 0;
-- UPDATE tmp_overdue set LAST_REPAY_DT = NULL;


## -- 最近一次实际还款日期；本期无，则用历史最新(对第一期都没还款的）
UPDATE
    tmp_overdue
inner JOIN (
	SELECT
	    a.ProjectID,
	    a.Peroid,
	    MAX(b.LAST_REPAY_DT) as max_dt_till_now
	FROM
	    tmp_overdue a
	JOIN tmp_overdue b
	WHERE
	    a.ProjectID = b.ProjectID
	    and b.Peroid <= a.Peroid
	    and a.LAST_REPAY_DT IS NULL 
	group by
	    a.ProjectID,
	    a.Peroid
) as up_tab ON
    tmp_overdue.ProjectID = up_tab.ProjectID
    AND tmp_overdue.Peroid = up_tab.Peroid 
SET
    tmp_overdue.LAST_REPAY_DT = up_tab.max_dt_till_now;    


## 以下，处理逾期31-60天、61-90天、91-180天、180天以上
## -- 逾期31-60天未归还贷款本金 -- 逾期31天未还清 > 0，但60天已还清 = 0
    -- 逾期61-90天未归还贷款本金  -- 逾期61天未还清，但90天已还清
    -- 逾期91-180天未归还贷款本金
    -- 逾期180天以上未归还贷款本金
    -- SELECT * from tmp_RECEIPT_PLAN_till_now;
-- DROP TABLE IF EXISTS tmp_RECEIPT_PLAN_till_now;
-- CREATE TABLE tmp_RECEIPT_PLAN_till_now 
TRUNCATE TABLE tmp_RECEIPT_PLAN_till_now;
INSERT INTO tmp_RECEIPT_PLAN_till_now
(
	select trptn.PROJECT_ID , trptn.PERIOD , srrp.RECEIPT_PLAN_DATE, srrp.RECEIPT_PLAN_ID -- , srrpd.RECEIPT_AMOUNT_IT
	FROM 
		tmp_repay_plan_till_now trptn
	left join
		SETT_RENT_RECEIPT_PLAN srrp
	on trptn.PROJECT_ID = srrp.PROJECT_ID 
	and trptn.PERIOD = srrp.PERIOD
	WHERE trptn.PROJECT_ID  in (SELECT DISTINCT PROJECT_ID FROM tmp_overdue_projects )
	order by  trptn.PROJECT_ID , trptn.PERIOD 
);

-- SELECT * from tmp_RECEIPT_PLAN_DETAIL_PRI order by PROJECT_ID;
-- DROP TABLE IF EXISTS tmp_RECEIPT_PLAN_DETAIL_PRI;
-- CREATE TABLE tmp_RECEIPT_PLAN_DETAIL_PRI 
TRUNCATE TABLE tmp_RECEIPT_PLAN_DETAIL_PRI;
INSERT INTO tmp_RECEIPT_PLAN_DETAIL_PRI
(
	select RENT_RECEIPT_PLAN_ID, PROJECT_ID, RECEIPT_AMOUNT_IT
	FROM SETT_RENT_RECEIPT_PLAN_DETAIL
	WHERE SUBJECT = 'PRI' AND PROJECT_ID in (SELECT DISTINCT PROJECT_ID FROM tmp_overdue_projects )
);

### -- 项目本金表，每一期的本金计划
-- SELECT * from tmp_project_period_prin;
-- DROP TABLE IF EXISTS tmp_project_period_prin;
-- CREATE  TABLE tmp_project_period_prin 
TRUNCATE TABLE tmp_project_period_prin;
INSERT INTO tmp_project_period_prin
(
	select trptn.PROJECT_ID, trptn.PERIOD, ifnull(trpdp.RECEIPT_AMOUNT_IT, 0) as RECEIPT_AMOUNT_IT,  trptn.RECEIPT_PLAN_DATE
	FROM 
	tmp_RECEIPT_PLAN_till_now trptn
	left join 
	tmp_RECEIPT_PLAN_DETAIL_PRI trpdp
	on trptn.RECEIPT_PLAN_ID = trpdp.RENT_RECEIPT_PLAN_ID
	order by PROJECT_ID, PERIOD
);

-- 更新超过12期的本金

UPDATE
    tmp_project_period_prin
inner JOIN (
	SELECT
	    PROJECT_ID,
	    PERIOD,
	    RECEIPT_AMOUNT_IT
	FROM
	    tmp_project_period_prin
	WHERE
	    PERIOD = 12
	group by
	    PROJECT_ID
) as up_tab ON
    tmp_project_period_prin.PROJECT_ID = up_tab.PROJECT_ID
    AND tmp_project_period_prin.PERIOD > 12 
SET
    tmp_project_period_prin.RECEIPT_AMOUNT_IT = up_tab.RECEIPT_AMOUNT_IT;
	
	
-- CALL sp_gen_30_180_amt;
CALL sp_over_30_180;

UPDATE tmp_overdue set OVERDUE31_60DAYS_AMT=0 WHERE OVERDUE31_60DAYS_AMT is NULL;
UPDATE tmp_overdue set OVERDUE61_90DAYS_AMT=0 WHERE OVERDUE61_90DAYS_AMT is NULL;
UPDATE tmp_overdue set OVERDUE91_180DAYS_AMT=0 WHERE OVERDUE91_180DAYS_AMT is NULL;
UPDATE tmp_overdue set OVERDUE_180DAYS_AMT=0 WHERE OVERDUE_180DAYS_AMT is NULL;


# 下面两个问题已解决，先保留这两条特别处理语句
-- SELECT * 
DELETE 
FROM tmp_overdue WHERE over_day_count <0;

-- SELECT *
DELETE 
FROM tmp_overdue 
where PLAN_REPAY_DT > DATE_FORMAT(@EXPORT_DATE , '%Y%m%d');

-- 当期多还的情况
UPDATE tmp_overdue set CUR_OVERDUE_TOTAL_AMT = 0 WHERE CUR_OVERDUE_TOTAL_AMT < 0;

-- 保留最后一条 ，在视图中实现
-- DROP table IF EXISTS tmp_tmp_overdue;
-- CREATE TEMPORARY TABLE tmp_tmp_overdue 
-- SELECT * 
--  	FROM tmp_overdue 
-- 	where (ProjectID , Peroid ) in (
-- 	SELECT ProjectID , max(Peroid) FROM small_core.tmp_overdue x
-- 	group by ProjectID 
-- 	)  order by ProjectID , Peroid ;
-- 
-- TRUNCATE TABLE  tmp_overdue;
-- INSERT INTO tmp_overdue
-- 	SELECT * FROM tmp_tmp_overdue ;
-- DROP table IF EXISTS tmp_tmp_overdue;

-- =====================================
-- end: 核心逻辑过程
-- =====================================
-- =====================================
-- =====================================


-- 第一次报送的项目，收集出来，给后面步骤（转到 租前库 finance_lease_apply 去匹配身份/居住/职业等信息）
-- TRUNCATE table tmp_overdue_projects ;
-- INSERT INTO tmp_overdue_projects
-- (
-- 	select PROJECT_ID from tmp_overdue_repo where settle_flag = 0
-- );

-- 第一次报送的状态改为已报送1次，后续不用再报 身份/居住/职业等信息
-- UPDATE tmp_overdue_repo set settle_flag = 1 where settle_flag = 0;


#####################
# 执行Python 代码 
-- python MONTH_24_STAT.py
#####################




	
END