
-- =====================================
只导出应还款日之后一天，处于逾期状态的

# 通用的
set @export_date=DATE_FORMAT('2020-03-19', '%Y-%m-%d');
SELECT @export_date;



## -- 所有当前逾期的项目
DROP table overdue_projects;
CREATE TEMPORARY TABLE overdue_projects 
( SELECT DISTINCT PROJECT_ID FROM tmp_repay_plan_till_now )

## -- 当前逾期项目
AND PROJECT_ID in ( SELECT DISTINCT PROJECT_ID FROM overdue_projects )

## -- 累积代码
SELECT
	a.APPLY_NO,
	a.TERM_NO,
	sum(b.paid_prin) AS p_paid_prin
FROM
	tmp_paid_prin a
JOIN tmp_paid_prin b
WHERE
	a.APPLY_NO = b.APPLY_NO
	AND b.TERM_NO <= a.TERM_NO
GROUP BY
	a.APPLY_NO,
	a.TERM_NO 


## -- 项目本金表
CREATE TEMPORARY TABLE project_period_prin 
(
SELECT
	srrp.PROJECT_ID ,
	srrp.PERIOD ,
	srrp.RECEIPT_PLAN_DATE,
	srrpd.RECEIPT_AMOUNT_IT
FROM
	SETT_RENT_RECEIPT_PLAN srrp ,
	SETT_RENT_RECEIPT_PLAN_DETAIL srrpd
WHERE
	srrp.RECEIPT_PLAN_ID = srrpd.RENT_RECEIPT_PLAN_ID
	and srrpd.SUBJECT = 'PRI'
	and srrpd.PROJECT_ID in (
	SELECT
		DISTINCT PROJECT_ID
	FROM
		overdue_projects )
order by
	srrp.PROJECT_ID,
	srrp.PERIOD )
	



# -- 基础信息
-- 1. 找出逾期的人
--  	逾期报表 as overdue_rpt
-- DROP TABLE tmp_overdue_rpt;
-- CREATE  TABLE tmp_overdue_rpt;
TRUNCATE(tmp_overdue_rpt) ;

INSERT INTO tmp_overdue_rpt
SELECT
	rp.PROJECT_ID,
	rp.CLIENT_NAME,
	cmi.JXFL_CONTRACT_NO,
	rp.REPAYMENT_DATE,
	rp.PLAN_STATUS,
	PPPPD.PERIOD,
	PPPPD.PRI_AMT,
	PPPPD.INT_AMT,
	datediff(now(),
	PPPPD.RECEIPT_PLAN_DATE) as overdue_days
FROM
	SETT_REPAYMENT_PLAN rp,
	APPLY_ORDER ao,
	CONTRACT_MAPPING_INFO cmi,
	(
	SELECT
		PPD.PROJECT_ID,
		PPD.PERIOD,
		PPD.RECEIPT_PLAN_ID,
		PPD.RECEIPT_PLAN_DATE,
		SUM(PPD.PRI_AMT) AS PRI_AMT,
		SUM(PPD.INT_AMT) AS INT_AMT
	FROM
		(
		SELECT
			P.PROJECT_ID,
			P.PERIOD,
			P.RECEIPT_PLAN_ID,
			P.RECEIPT_PLAN_DATE,
			PD.RECEIPT_AMOUNT_IT AS PRI_AMT,
			0 AS INT_AMT
		FROM
			SETT_RENT_RECEIPT_PLAN P,
			SETT_RENT_RECEIPT_PLAN_DETAIL PD
		WHERE
			PD.SUBJECT = 'PRI'
			AND P.WRITE_STATUS = 0
			AND P.PROJECT_ID = PD.PROJECT_ID
			AND P.RECEIPT_PLAN_ID = PD.RENT_RECEIPT_PLAN_ID
	UNION ALL
		SELECT
			P.PROJECT_ID,
			P.PERIOD,
			P.RECEIPT_PLAN_ID,
			P.RECEIPT_PLAN_DATE,
			0 AS PRI_AMT,
			PD.RECEIPT_AMOUNT_IT AS INT_AMT
		FROM
			SETT_RENT_RECEIPT_PLAN P,
			SETT_RENT_RECEIPT_PLAN_DETAIL PD
		WHERE
			SUBJECT = 'INT'
			AND P.WRITE_STATUS = 0
			AND P.PROJECT_ID = PD.PROJECT_ID
			AND P.RECEIPT_PLAN_ID = PD.RENT_RECEIPT_PLAN_ID) PPD
	GROUP BY
		PPD.PROJECT_ID,
		PPD.PERIOD ) as PPPPD
WHERE
	rp.PROJECT_ID = ao.APPLY_NO
	AND ao.APPLY_STATUS = 10
	and rp.REPAYMENT_PLAN_ID = PPPPD.RECEIPT_PLAN_ID
	AND rp.PROJECT_ID = cmi.CHANNEL_APPLY_NO
	AND rp.PLAN_STATUS = 2
	AND rp.OVERDUE_DAYS = 1
	-- 	AND rrp.WRITE_STATUS=2
	ORDER BY overdue_days DESC ;
-- 

-- 2. 逾期的人从第一期到今的还款计划，即所有需要计算的 project + period
DROP table tmp_repay_plan_till_now;
CREATE TABLE tmp_repay_plan_till_now
SELECT
	PROJECT_ID,
	PERIOD,
	REPAYMENT_DATE,
	EXPECTED_AMT,
	PLAN_STATUS ,
	OVERDUE_DAYS ,
	PLAN_SETTLE_DATE
FROM
	SETT_REPAYMENT_PLAN
WHERE
	PROJECT_ID in (
	SELECT
		DISTINCT PROJECT_ID
	FROM
		overdue_projects )
	and REPAYMENT_DATE < NOW()
ORDER BY
	PROJECT_ID,
	PERIOD ;


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
INSERT INTO small_core_like_prod.tmp_overdue 
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
 ao.START_DATE AS STARTDATE,
	ao.END_DATE AS ENDDATE,
	'CNY' AS CURRENCY,
	ao.ACTUAL_AMOUNT AS CREDIT_TOTAL_AMT,
	ao.ACTUAL_AMOUNT AS SHARE_CREDIT_TOTAL_AMT,
	ao.ACTUAL_AMOUNT AS MAX_DEBT_AMT,
	ao.LEASE_TYPE AS GUARANTEEFORM,
	'03' AS PAYMENT_RATE,
	ao.PERIOD AS PAYMENT_MONTHS,
	ao.PERIOD - trptn.PERIOD AS NO_PAYMENT_MONTHS,
	-- causion
 trptn.REPAYMENT_DATE as PLAN_REPAY_DT,
	-- 
 '2' as LOAN_ACCOUNT_STAT,
	ao.USER_ACCOUNT_NAME AS CUSTNAME,
	'0' AS CERTTYPE,
	ao.ID_CARD_NO AS CERTNO,
	ao.ID_CARD_NO AS CUSTID,
	'' AS BAKE
FROM
	APPLY_ORDER ao,
	tmp_repay_plan_till_now trptn
WHERE
	ao.APPLY_NO = trptn.PROJECT_ID
ORDER BY
	ao.APPLY_NO,
	ao.PERIOD
	)
		
## -- -- 第一条记录是新开户相关信息
-- 为减少影响，这条放在所有数据处理完后，最后再执行
 INSERT
	INTO
	small_core_like_prod.tmp_overdue (ProjectID,
	Peroid,
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
		'M10154210H0001' AS FINORGCODE,
		'4' AS LOANTYPE,
		'92' AS LOANBIZTYPE,
		ao.LEASE_CONTRACT_NO AS BUSINESS_NO,
		'360102' AS AREACODE,
		-- {todo}
        ao.START_DATE AS STARTDATE,
		ao.END_DATE AS ENDDATE,
		'CNY' AS CURRENCY,
		ao.ACTUAL_AMOUNT AS CREDIT_TOTAL_AMT,
		ao.ACTUAL_AMOUNT AS SHARE_CREDIT_TOTAL_AMT,
		ao.ACTUAL_AMOUNT AS MAX_DEBT_AMT,
		ao.LEASE_TYPE AS GUARANTEEFORM,
		'03' AS PAYMENT_RATE,
		ao.PERIOD AS PAYMENT_MONTHS,
		ao.PERIOD AS NO_PAYMENT_MONTHS,
		ao.START_DATE as PLAN_REPAY_DT,
		ao.START_DATE as LAST_REPAY_DT,
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
		APPLY_ORDER ao
	WHERE
		ao.APPLY_NO in ( SELECT DISTINCT PROJECT_ID FROM overdue_projects ) )
select
	count(1)
from
	tmp_overdue ;
    

# -- 不需汇总字段
## -- 本月应还款金额（以还款计划表为准）
UPDATE
	tmp_overdue
inner JOIN (
	SELECT
		PROJECT_ID,
		PERIOD, 
 		RECEIPT_AMOUNT_IT
			
		FROM SETT_RENT_RECEIPT_PLAN
	WHERE
		PROJECT_ID in (
		SELECT
			DISTINCT PROJECT_ID
		FROM
			overdue_projects )
	group by
		PROJECT_ID,
		PERIOD ) as up_tab 
	ON
		tmp_overdue.ProjectID = up_tab.PROJECT_ID
		AND tmp_overdue.Peroid = up_tab.PERIOD 
	SET
		tmp_overdue.PLAN_REPAY_AMT = up_tab.RECEIPT_AMOUNT_IT
	
## -- 最近一次实际还款日期；本期有，则用本期最新；本期无，则用历史最新 {下一个步骤}
## -- 本月实际还款金额（以蚂蚁实收报表为准）
UPDATE
	tmp_overdue
inner JOIN (
	SELECT
		APPLY_NO,
		TERM_NO,
		max(REPAY_DATE) as LAST_REPAY_DT,
		-- 简化：本期无还款的，结果为null，手动补上。
        SUM(REPAY_INSTMNT_DETAIL.REPAY_AMT) as LAST_REPAY_AMT
	FROM
		REPAY_INSTMNT_DETAIL
	WHERE
		APPLY_NO in (
		SELECT
			DISTINCT PROJECT_ID
		FROM
			overdue_projects )
	group by
		APPLY_NO,
		TERM_NO ) as up_tab ON
	tmp_overdue.ProjectID = up_tab.APPLY_NO
	AND tmp_overdue.Peroid = up_tab.TERM_NO 
	SET
	tmp_overdue.LAST_REPAY_DT = up_tab.LAST_REPAY_DT,
	tmp_overdue.LAST_REPAY_AMT = up_tab.LAST_REPAY_AMT

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
    tmp_overdue.LAST_REPAY_DT = up_tab.max_dt_till_now;







## -- 账户状态（todo 这个有问题）
PLAN_STATUS  
    当期还款计划状态（0：等待执行；1：正常执行中；2：逾期执行中；3：已结清；4：已终止；5：已核销）
LOAN_STAT
    "1-正常：目前所有应还租金都已经还清
    2-逾期：目前还有应还未还的租金未结清
    3-结清：整个合同结清时上报的的最后一条数据"

UPDATE
	tmp_overdue
inner JOIN (
	SELECT
		PROJECT_ID,
		PERIOD,
		PLAN_STATUS
	FROM
		SETT_REPAYMENT_PLAN
	WHERE
		PROJECT_ID in (
		SELECT
			DISTINCT PROJECT_ID
		FROM
			overdue_projects )
	group by
		PROJECT_ID,
		PERIOD ) as up_tab ON
	tmp_overdue.ProjectID = up_tab.PROJECT_ID
	AND tmp_overdue.Peroid = up_tab.PERIOD 
SET
	tmp_overdue.LOAN_STAT = up_tab.PLAN_STATUS;

	
	
# --   ======  以下为需要汇总的字段 
## -- ==余额 
-- 此数据项是指贷款本金余额。 用总贷款本金ao.ACTUAL_AMOUNT - 已还本金
-- 先计算已还本金
### -- 每期最终还款本金
(
SELECT
    PROJECT_ID ,
    PERIOD ,
    sum(PAID_PRIN_AMT) as paid_prin_during
FROM
    (
    SELECT
        srp.PROJECT_ID,
        srp.PERIOD,
        srp.PLAN_START_DATE,
        srp.PLAN_END_DATE,
        rid.REPAY_DATE,
        rid.PAID_PRIN_AMT
    FROM
        SETT_REPAYMENT_PLAN srp ,
        REPAY_INSTMNT_DETAIL rid
    WHERE
        srp.PROJECT_ID = rid.APPLY_NO
        and srp.PERIOD = rid.TERM_NO
        -- and rid.REPAY_DATE between srp.PLAN_START_DATE and srp.PLAN_END_DATE 
        ) paid_during
GROUP BY
    PROJECT_ID,
    PERIOD
) paid_prin_amount_period


### -- 每期还款时间内还款本金
(
SELECT
    PROJECT_ID ,
    PERIOD ,
    sum(PAID_PRIN_AMT) as paid_prin_during
FROM
    (
    SELECT
        srp.PROJECT_ID,
        srp.PERIOD,
        srp.PLAN_START_DATE,
        srp.PLAN_END_DATE,
        rid.REPAY_DATE,
        rid.PAID_PRIN_AMT
    FROM
        SETT_REPAYMENT_PLAN srp ,
        REPAY_INSTMNT_DETAIL rid
    WHERE
        srp.PROJECT_ID = rid.APPLY_NO
        and srp.PERIOD = rid.TERM_NO
        and rid.REPAY_DATE between srp.PLAN_START_DATE and srp.PLAN_END_DATE 
        ) paid_during
GROUP BY
    PROJECT_ID,
    PERIOD
) paid_prin_amount_druing

### 每期实际还本金
DROP TABLE tmp_paid_prin;
CREATE TABLE tmp_paid_prin (
SELECT
	APPLY_NO ,
	TERM_NO ,
	SUM(PAID_PRIN_AMT) as paid_prin
FROM
	REPAY_INSTMNT_DETAIL
WHERE
	APPLY_NO in (
	SELECT
		DISTINCT PROJECT_ID
	FROM
		overdue_projects )
Group by
	APPLY_NO ,
	TERM_NO )

### 截止每一期时，实际总共已还款本金
DROP TABLE tmp_paid;
CREATE TEMPORARY TABLE tmp_paid (
SELECT
	a.APPLY_NO,
	a.TERM_NO,
	sum(b.paid_prin) as p_paid_prin
FROM
	tmp_paid_prin a
JOIN tmp_paid_prin b
WHERE
	a.APPLY_NO = b.APPLY_NO
	and b.TERM_NO <= a.TERM_NO
group by
	a.APPLY_NO,
	a.TERM_NO )


### -- 余额 = 总本金 - 已还本金
UPDATE
	tmp_overdue
inner JOIN (
	SELECT
		ao.APPLY_NO,
		tmp_paid.TERM_NO,
		(ao.ACTUAL_AMOUNT - tmp_paid.p_paid_prin) as BALANCE
	FROM
		APPLY_ORDER ao,
		tmp_paid
	WHERE
		ao.APPLY_NO = tmp_paid.APPLY_NO
	GROUP BY
		ao.APPLY_NO,
		tmp_paid.TERM_NO ) as up_tab ON
	tmp_overdue.ProjectID = up_tab.APPLY_NO
	AND tmp_overdue.Peroid = up_tab.TERM_NO 
SET
	tmp_overdue.BALANCE = up_tab.BALANCE;

## -- == 当前逾期期数
-- 当前处于逾期的期数  简化，已经结清的只算1期，目前还处于逾期执行中的，进行汇总
-- {todo:}

	
	
### -- 已结清的，直接按1
 UPDATE
	tmp_overdue
inner JOIN (
	select
		PROJECT_ID,
		PERIOD,
		OVERDUE_DAYS as CUR_OVERDUE_TOTAL_INT
	FROM
		SETT_REPAYMENT_PLAN
	where
		PLAN_STATUS = 3
	GROUP by
		PROJECT_ID,
		PERIOD ) as up_tab ON
	tmp_overdue.ProjectID = up_tab.PROJECT_ID
	AND tmp_overdue.Peroid = up_tab.PERIOD SET
	tmp_overdue.CUR_OVERDUE_TOTAL_INT = up_tab.CUR_OVERDUE_TOTAL_INT;
### -- 处于逾期的
-- 需程序扫描 游标
-- 向前累积求和

	
## -- 当前逾期总额
-- 租金计划 - 记录还款分期流水
-- SETT_REPAYMENT_PLAN - REPAY_INSTMNT_DETAIL
-- 如果当期没有实际还款，要考虑罚息
### 每一期的逾期总额
DROP TABLE tmp_CUR_OVERDUE_AMT;
CREATE TABLE tmp_CUR_OVERDUE_AMT (
SELECT
	srp_sfrp.PROJECT_ID,
	srp_sfrp.PERIOD,
	(srp_sfrp.EXPECTED_AMT + IFNULL(srp_sfrp.fine_RECEIPT_AMOUNT_IT, 0) - IFNULL(SUM(rid.REPAY_AMT), 0)) as CUR_OVERDUE_AMT
FROM
	(
	SELECT
		srp.PROJECT_ID,
		srp.PERIOD,
		srp.EXPECTED_AMT,
		sfrp.fine_RECEIPT_AMOUNT_IT
	FROM
		SETT_REPAYMENT_PLAN srp
	LEFT JOIN (
		SELECT
			PROJECT_ID,
			PERIOD,
			sum(RECEIPT_AMOUNT_IT) fine_RECEIPT_AMOUNT_IT
		FROM
			SETT_FINE_RECEIPT_PLAN
		GROUP BY
			PROJECT_ID,
			PERIOD
		order by
			PROJECT_ID ) sfrp ON
		srp.PROJECT_ID = sfrp.PROJECT_ID
		and srp.PERIOD = sfrp.PERIOD
	WHERE
		srp.PROJECT_ID in (
		SELECT
			DISTINCT PROJECT_ID
		FROM
			overdue_projects)
		and srp.REPAYMENT_DATE < NOW() ) srp_sfrp,
	REPAY_INSTMNT_DETAIL rid
WHERE
	srp_sfrp.PROJECT_ID = rid.APPLY_NO
	and srp_sfrp.PERIOD = rid.TERM_NO
GROUP BY
	srp_sfrp.PROJECT_ID,
	srp_sfrp.PERIOD
order by
	srp_sfrp.PROJECT_ID,
	srp_sfrp.PERIOD );

SELECT
	*
from
	tmp_CUR_OVERDUE_AMT;
	
-- 向前累积求和，截止当前所有逾期的总额
DROP TABLE tmp_CUR_OVERDUE_TOTAL_AMT;
CREATE TEMPORARY TABLE tmp_CUR_OVERDUE_TOTAL_AMT (

UPDATE
    tmp_overdue
inner JOIN (
SELECT
	a.PROJECT_ID,
	a.PERIOD,
	sum(b.CUR_OVERDUE_AMT) as CUR_OVERDUE_TOTAL_AMT
FROM
	tmp_CUR_OVERDUE_AMT a
JOIN tmp_CUR_OVERDUE_AMT b
WHERE
	a.PROJECT_ID = b.PROJECT_ID
	and b.PERIOD <= a.PERIOD
group by
	a.PROJECT_ID,
	a.PERIOD ) as up_tab ON
    tmp_overdue.ProjectID = up_tab.PROJECT_ID
    AND tmp_overdue.Peroid = up_tab.PERIOD 
SET
    tmp_overdue.CUR_OVERDUE_TOTAL_AMT = up_tab.CUR_OVERDUE_TOTAL_AMT;

	
	
## -- 逾期31-60天未归还贷款本金 -- 逾期31天未还清 > 0，但60天已还清 = 0
	-- 逾期61-90天未归还贷款本金  -- 逾期61天未还清，但90天已还清
	-- 逾期91-180天未归还贷款本金
	-- 逾期180天以上未归还贷款本金
	
### 逾期31天内已还本金 < 31
DROP table paid_prin_amount_31day;
CREATE TEMPORARY TABLE paid_prin_amount_31day
(
SELECT
	PROJECT_ID ,
	PERIOD ,
	sum(PAID_PRIN_AMT) as paid_prin_during
FROM
	(
	SELECT
		srp.PROJECT_ID,
		srp.PERIOD,
		srp.PLAN_START_DATE,
		srp.PLAN_END_DATE,
		-- date_add(srp.PLAN_END_DATE, interval 30 day),
		rid.REPAY_DATE,
		rid.PAID_PRIN_AMT
	FROM
		SETT_REPAYMENT_PLAN srp ,
		REPAY_INSTMNT_DETAIL rid
	WHERE
		srp.PROJECT_ID = rid.APPLY_NO
		and srp.PERIOD = rid.TERM_NO
		and rid.APPLY_NO in ( SELECT DISTINCT PROJECT_ID FROM overdue_projects )
		and date_add(srp.PLAN_END_DATE, interval 30 day) <= @export_date --  NOW()
		and rid.REPAY_DATE between srp.PLAN_START_DATE and date_add(srp.PLAN_END_DATE, interval 30 day)
		ORDER by PLAN_END_DATE desc
		) paid_during
GROUP BY
	PROJECT_ID,
	PERIOD
) ;
SELECT * FROM paid_prin_amount_31day;


### 逾期61天内已还本金 < 61
DROP table paid_prin_amount_61day;
CREATE TEMPORARY TABLE paid_prin_amount_61day
(
SELECT
	PROJECT_ID ,
	PERIOD ,
	sum(PAID_PRIN_AMT) as paid_prin_during
FROM
	(
	SELECT
		srp.PROJECT_ID,
		srp.PERIOD,
		srp.PLAN_START_DATE,
		srp.PLAN_END_DATE,
		-- date_add(srp.PLAN_END_DATE, interval 61 day),
		rid.REPAY_DATE,
		rid.PAID_PRIN_AMT
	FROM
		SETT_REPAYMENT_PLAN srp ,
		REPAY_INSTMNT_DETAIL rid
	WHERE
		srp.PROJECT_ID = rid.APPLY_NO
		and srp.PERIOD = rid.TERM_NO
		and rid.APPLY_NO in ( SELECT DISTINCT PROJECT_ID FROM overdue_projects )
 		and date_add(srp.PLAN_END_DATE, interval 60 day) <= @export_date --  NOW()
		and rid.REPAY_DATE between srp.PLAN_START_DATE and date_add(srp.PLAN_END_DATE, interval 60 day)
		) paid_during
GROUP BY
	PROJECT_ID,
	PERIOD
) ;
SELECT COUNT(1) from paid_prin_amount_61day;

-- test
SELECT * from (
SELECT 
p30.*, p60.paid_prin_during as p60_paid
FROM 
paid_prin_amount_31day p30
left join
paid_prin_amount_61day p60
on p30.PROJECT_ID = p60.PROJECT_ID
and p30.PERIOD = p60.PERIOD
) pps WHERE isnull(PROJECT_ID)


### 逾期91天内已还本金 < 91
DROP table paid_prin_amount_91day;
CREATE TEMPORARY TABLE paid_prin_amount_91day
(
SELECT
	PROJECT_ID ,
	PERIOD ,
	sum(PAID_PRIN_AMT) as paid_prin_during
FROM
	(
	SELECT
		srp.PROJECT_ID,
		srp.PERIOD,
		srp.PLAN_START_DATE,
		srp.PLAN_END_DATE,
		-- date_add(srp.PLAN_END_DATE, interval 91 day),
		rid.REPAY_DATE,
		rid.PAID_PRIN_AMT
	FROM
		SETT_REPAYMENT_PLAN srp ,
		REPAY_INSTMNT_DETAIL rid
	WHERE
		srp.PROJECT_ID = rid.APPLY_NO
		and srp.PERIOD = rid.TERM_NO
		and rid.APPLY_NO in ( SELECT DISTINCT PROJECT_ID FROM overdue_projects )
		and date_add(srp.PLAN_END_DATE, interval 90 day) <= @export_date --  NOW()
		and rid.REPAY_DATE between srp.PLAN_START_DATE and date_add(srp.PLAN_END_DATE, interval 90 day)
		) paid_during
GROUP BY
	PROJECT_ID,
	PERIOD
) ;
SELECT COUNT(1) from paid_prin_amount_91day;

### 逾期120天内已还本金 < 121，给后面5级分类用的
DROP table paid_prin_amount_121day;
CREATE TEMPORARY TABLE paid_prin_amount_121day
(
SELECT
	PROJECT_ID ,
	PERIOD ,
	sum(PAID_PRIN_AMT) as paid_prin_during
FROM
	(
	SELECT
		srp.PROJECT_ID,
		srp.PERIOD,
		srp.PLAN_START_DATE,
		srp.PLAN_END_DATE,
		-- date_add(srp.PLAN_END_DATE, interval 121 day),
		rid.REPAY_DATE,
		rid.PAID_PRIN_AMT
	FROM
		SETT_REPAYMENT_PLAN srp ,
		REPAY_INSTMNT_DETAIL rid
	WHERE
		srp.PROJECT_ID = rid.APPLY_NO
		and srp.PERIOD = rid.TERM_NO
		and rid.APPLY_NO in ( SELECT DISTINCT PROJECT_ID FROM overdue_projects )
		and date_add(srp.PLAN_END_DATE, interval 120 day) <= @export_date --  NOW()
		and rid.REPAY_DATE between srp.PLAN_START_DATE and date_add(srp.PLAN_END_DATE, interval 120 day)
		) paid_during
GROUP BY
	PROJECT_ID,
	PERIOD
) ;
SELECT COUNT(1) from paid_prin_amount_121day;



### 逾期181天内已还本金 < 181
DROP table paid_prin_amount_181day;
CREATE TEMPORARY TABLE paid_prin_amount_181day
(
SELECT
	PROJECT_ID ,
	PERIOD ,
	sum(PAID_PRIN_AMT) as paid_prin_during
FROM
	(
	SELECT
		srp.PROJECT_ID,
		srp.PERIOD,
		srp.PLAN_START_DATE,
		srp.PLAN_END_DATE,
		-- date_add(srp.PLAN_END_DATE, interval 181 day),
		rid.REPAY_DATE,
		rid.PAID_PRIN_AMT
	FROM
		SETT_REPAYMENT_PLAN srp ,
		REPAY_INSTMNT_DETAIL rid
	WHERE
		srp.PROJECT_ID = rid.APPLY_NO
		and srp.PERIOD = rid.TERM_NO
		and rid.APPLY_NO in ( SELECT DISTINCT PROJECT_ID FROM overdue_projects )
		and date_add(srp.PLAN_END_DATE, interval 180 day) <= @export_date --  NOW()
		and rid.REPAY_DATE between srp.PLAN_START_DATE and date_add(srp.PLAN_END_DATE, interval 180 day)
		ORDER by PLAN_END_DATE desc
		) paid_during
GROUP BY
	PROJECT_ID,
	PERIOD
) ;
SELECT COUNT(1) FROM paid_prin_amount_181day;


-- x天未还清的
-- select 
-- ppp.PROJECT_ID, ppp.PERIOD, (ppp.RECEIPT_AMOUNT_IT - ppxday.paid_prin_during)  as overdue180
-- FROM 
-- project_period_prin ppp, 
-- paid_prin_amount_181day ppxday
-- WHERE 
-- ppp.PROJECT_ID = ppxday.PROJECT_ID
-- and ppp.PROJECT_ID = '201911200801893229A'
-- AND ppp.PERIOD = ppxday.PERIOD
-- AND (ppp.RECEIPT_AMOUNT_IT > ppxday.paid_prin_during) 
-- order by ppp.PROJECT_ID, ppp.PERIOD
select  * FROM project_period_prin  
WHERE PROJECT_ID = '201912160774052500A' 
order by PROJECT_ID, PERIOD;


select  * FROM paid_prin_amount_31day  
WHERE PROJECT_ID = '201903060527650806A' 
order by PROJECT_ID, PERIOD;

select  * FROM paid_prin_amount_61day  
WHERE PROJECT_ID = '201903060527650806A' 
order by PROJECT_ID, PERIOD;

select  * FROM paid_prin_amount_91day  
WHERE PROJECT_ID = '201903060527650806A' 
order by PROJECT_ID, PERIOD;


SELECT * 
FROM project_period_prin ppp 
WHERE 
PROJECT_ID = '201903060527650806A' 
AND RECEIPT_PLAN_DATE < @export_date

### -- 1 - 30 -- 逾期30天内还清的，给5级分类用的
DROP TABLE overdue_1to30
CREATE TEMPORARY TABLE overdue_1to30
select
    *
from
    (
    select
        ppp.PROJECT_ID,
        ppp.PERIOD,
        ppxday.paid_prin_during,
        (ppp. RECEIPT_AMOUNT_IT - IFNULL( ppxday.paid_prin_during,
        0)) as overdue_amt,
        (ppp. RECEIPT_AMOUNT_IT - IFNULL( ppxxday.paid_prin_during,
        0)) as overdue_amt_xx
    FROM
        project_period_prin ppp
    LEFT JOIN paid_prin_amount_31day ppxday on
        ppp.PROJECT_ID = ppxday.PROJECT_ID
        AND ppp.PERIOD = ppxday.PERIOD
    LEFT JOIN paid_prin_amount_61day ppxxday on
        ppp.PROJECT_ID = ppxxday.PROJECT_ID
        AND ppp.PERIOD = ppxxday.PERIOD
    WHERE
        ppp.PROJECT_ID in (
        SELECT
            DISTINCT PROJECT_ID
        FROM
            overdue_projects )
        AND ppp.RECEIPT_PLAN_DATE < @export_date
        and date_add(ppp.RECEIPT_PLAN_DATE,
        interval 30 day)<= @export_date
        and (ppp.RECEIPT_AMOUNT_IT > IFNULL(ppxday.paid_prin_during,
        0))
    order by
        ppp.PROJECT_ID,
        ppp.PERIOD ) as tt
WHERE
    overdue_amt_xx = 0

### -- 30 - 60  --- 还要加 60 天已还清的条件
DROP TABLE overdue_30to60
CREATE TEMPORARY TABLE overdue_30to60
select
    *
from
    (
    select
        ppp.PROJECT_ID,
        ppp.PERIOD,
        ppxday.paid_prin_during,
        (ppp. RECEIPT_AMOUNT_IT - IFNULL( ppxday.paid_prin_during,
        0)) as overdue_amt,
        (ppp. RECEIPT_AMOUNT_IT - IFNULL( ppxxday.paid_prin_during,
        0)) as overdue_amt_xx
    FROM
        project_period_prin ppp
    LEFT JOIN paid_prin_amount_31day ppxday on
        ppp.PROJECT_ID = ppxday.PROJECT_ID
        AND ppp.PERIOD = ppxday.PERIOD
    LEFT JOIN paid_prin_amount_61day ppxxday on
        ppp.PROJECT_ID = ppxxday.PROJECT_ID
        AND ppp.PERIOD = ppxxday.PERIOD
    WHERE
        ppp.PROJECT_ID in (
        SELECT
            DISTINCT PROJECT_ID
        FROM
            overdue_projects )
        AND ppp.RECEIPT_PLAN_DATE < @export_date
        and date_add(ppp.RECEIPT_PLAN_DATE,
        interval 30 day)<= @export_date
        and (ppp.RECEIPT_AMOUNT_IT > IFNULL(ppxday.paid_prin_during,
        0))
    order by
        ppp.PROJECT_ID,
        ppp.PERIOD ) as tt
WHERE
    overdue_amt_xx = 0

UPDATE
	tmp_overdue
INNER JOIN (
	select
		PROJECT_ID,
		PERIOD,
		overdue_amt
	FROM
		overdue_30to60
	GROUP by
		PROJECT_ID,
		PERIOD ) as up_tab ON
	tmp_overdue.ProjectID = up_tab.PROJECT_ID
	AND tmp_overdue.Peroid = up_tab.PERIOD 
	SET
	OVERDUE31_60DAYS_AMT = up_tab.overdue_amt;
	
### -- 60 -90
DROP TABLE overdue_60to90
CREATE TEMPORARY TABLE overdue_60to90 (
select
    *
from
    (
    select
        ppp.PROJECT_ID,
        ppp.PERIOD,
        ppxday.paid_prin_during,
        (ppp. RECEIPT_AMOUNT_IT - IFNULL( ppxday.paid_prin_during,
        0)) as overdue_amt,
        (ppp. RECEIPT_AMOUNT_IT - IFNULL( ppxxday.paid_prin_during,
        0)) as overdue_amt_xx
    FROM
        project_period_prin ppp
    LEFT JOIN paid_prin_amount_61day ppxday on
        ppp.PROJECT_ID = ppxday.PROJECT_ID
        AND ppp.PERIOD = ppxday.PERIOD
    LEFT JOIN paid_prin_amount_91day ppxxday on
        ppp.PROJECT_ID = ppxxday.PROJECT_ID
        AND ppp.PERIOD = ppxxday.PERIOD
    WHERE
        ppp.PROJECT_ID in (
        SELECT
            DISTINCT PROJECT_ID
        FROM
            overdue_projects )
        AND ppp.RECEIPT_PLAN_DATE < @export_date
        and date_add(ppp.RECEIPT_PLAN_DATE,
        interval 60 day)<= @export_date
        and (ppp.RECEIPT_AMOUNT_IT > IFNULL(ppxday.paid_prin_during,
        0))
    order by
        ppp.PROJECT_ID,
        ppp.PERIOD ) as tt
WHERE
    overdue_amt_xx = 0 )

UPDATE
	tmp_overdue
inner JOIN (
	select
		PROJECT_ID,
		PERIOD,
		overdue_amt
	FROM
		overdue_60to90
	GROUP by
		PROJECT_ID,
		PERIOD ) as up_tab ON
	tmp_overdue.ProjectID = up_tab.PROJECT_ID
	AND tmp_overdue.Peroid = up_tab.PERIOD 
	SET
	OVERDUE61_90DAYS_AMT = up_tab.overdue_amt;


### -- 90 - 120 天，给5级分类用的
### -- 120 - 180 天，给5级分类用的


### -- 90 -180 天
DROP TABLE overdue_90to180
CREATE TEMPORARY TABLE overdue_90to180
select
    *
from
    (
    select
        ppp.PROJECT_ID,
        ppp.PERIOD,
        ppxday.paid_prin_during,
        (ppp. RECEIPT_AMOUNT_IT - IFNULL( ppxday.paid_prin_during, 0)) as overdue_amt,
        (ppp. RECEIPT_AMOUNT_IT - IFNULL( ppxxday.paid_prin_during, 0)) as overdue_amt_xx
    FROM
        project_period_prin ppp
    LEFT JOIN paid_prin_amount_91day ppxday on
        ppp.PROJECT_ID = ppxday.PROJECT_ID
        AND ppp.PERIOD = ppxday.PERIOD
    LEFT JOIN paid_prin_amount_181day ppxxday on
        ppp.PROJECT_ID = ppxxday.PROJECT_ID
        AND ppp.PERIOD = ppxxday.PERIOD
    WHERE
        ppp.PROJECT_ID in ( SELECT DISTINCT PROJECT_ID FROM overdue_projects )
        AND ppp.RECEIPT_PLAN_DATE < @export_date
        and date_add(ppp.RECEIPT_PLAN_DATE, interval 90 day)<= @export_date
        and (ppp.RECEIPT_AMOUNT_IT > IFNULL(ppxday.paid_prin_during, 0))
    order by
        ppp.PROJECT_ID, ppp.PERIOD ) as tt
WHERE
    overdue_amt_xx = 0 

 UPDATE
	tmp_overdue
inner JOIN (
	select
		PROJECT_ID,
		PERIOD,
		overdue_amt
	FROM
		overdue_90to180
	GROUP by
		PROJECT_ID,
		PERIOD ) as up_tab ON
	tmp_overdue.ProjectID = up_tab.PROJECT_ID
	AND tmp_overdue.Peroid = up_tab.PERIOD 
	SET
	tmp_overdue.OVERDUE91_180DAYS_AMT = up_tab.overdue_amt;


## -- == 累计逾期期数
UPDATE
	tmp_overdue
inner JOIN (
	SELECT
		a.PROJECT_ID,
		a.PERIOD ,
		sum(b.OVERDUE_DAYS) as total_overdue
	FROM
		SETT_REPAYMENT_PLAN a
	JOIN SETT_REPAYMENT_PLAN b
	WHERE
		a.PROJECT_ID = b.PROJECT_ID
		AND a.PROJECT_ID in (
		SELECT
			DISTINCT PROJECT_ID
		FROM
			overdue_projects )
		and b.PERIOD <= a.PERIOD
	group by
		a.PROJECT_ID ,
		a.PERIOD )as up_tab ON
	tmp_overdue.ProjectID = up_tab.PROJECT_ID
	AND tmp_overdue.Peroid = up_tab.PERIOD 
SET
	tmp_overdue.SUM_OVERDUE_INT = up_tab.total_overdue;


##  -- 最高逾期期数
DELIMITER ;;
drop procedure if exists MAX_OVERDUE; 
CREATE DEFINER=`root`@`%` PROCEDURE `small_core_like_prod`.`MAX_OVERDUE`(
)
BEGIN 
    DECLARE v_PROJECT_ID varchar(64); 
    DECLARE v_PERIOD INT(11); 
    DECLARE v_OVERDUE_DAYS INT(11); 

    DECLARE cur_prj varchar(64) DEFAULT ''; 
    DECLARE succ_over INT DEFAULT 0; 
    DECLARE done INT DEFAULT 0; 

    

    DECLARE cur CURSOR FOR (
    SELECT
        PROJECT_ID,
        PERIOD,
        -- REPAYMENT_DATE,
        -- EXPECTED_AMT,
        -- PLAN_STATUS ,
        OVERDUE_DAYS
    FROM
        -- SETT_REPAYMENT_PLAN
        tmp_repay_plan_till_now
        order by PROJECT_ID , PERIOD );
-- tmp_repay_plan_till_now)
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1; 

    OPEN cur;
    read_loop:LOOP 
        FETCH cur INTO v_PROJECT_ID, v_PERIOD, v_OVERDUE_DAYS; 
        IF done = 1 THEN 
            LEAVE read_loop; 
        END IF; 
    
        IF cur_prj <> v_PROJECT_ID THEN 
            SET succ_over = 0;
            SET cur_prj = v_PROJECT_ID;
        ELSEIF v_OVERDUE_DAYS = 0 THEN 
            SET succ_over = 0;
        ELSE 
            SET succ_over = succ_over + 1; 
        END IF; 

        -- SELECT v_PROJECT_ID, v_PERIOD, succ_over; --  as log into outfile '/tmp/result.txt';
        -- 更新状态   
        UPDATE tmp_overdue SET MAX_OVERDUE_INT = succ_over WHERE ProjectID = v_PROJECT_ID AND Peroid = v_PERIOD;
    END LOOP read_loop;
    CLOSE cur; 
END
DELIMITER ;            

call MAX_OVERDUE();

	
## -- 五级分类状态，从低级开始更新
-- 1-正常；到目前为止，即使历史记录出现过逾期，但是客户已经偿还逾期款，目前没有逾期未还的租金，则当期征信上报五级分类为1-正常
UPDATE
	tmp_overdue
	set CLASSIFY5 = 1
	where CUR_OVERDUE_TOTAL_AMT = 0
	
-- 2-关注；到目前为止，有逾期未还的租金，且其中所有逾期未还租金中对应的逾期天数最高的在1-90天（含1天和90天），则当期征信上报五级分类为2-关注
UPDATE
    tmp_overdue
    set CLASSIFY5 = 2
    where overdue_1to30 + overdue_30to60 + overdue_60to90 > 0
-- 3-次级；到目前为止，有逾期未还的租金，且其中所有逾期未还租金中对应的逾期天数最高的在91-120天（含91天和120天），则当期征信上报五级分类为3-次级
UPDATE
    tmp_overdue
    set CLASSIFY5 = 3
    where overdue_90to120 > 0
-- 4-可疑；到目前为止，有逾期未还的租金，且其中所有逾期未还租金中对应的逾期天数最高的在121-180天（含121天和180天），则当期征信上报五级分类为4-可疑---改为 121 – 150 天
UPDATE
    tmp_overdue
    set CLASSIFY5 = 4
    where overdue_120to180 > 0
-- 5-损失；到目前为止，有逾期未还的租金，且其中所有逾期未还租金中对应的逾期天数最高的在181天（含181天）以上，则当期征信上报五级分类为5-损失--- 改为151天以上
UPDATE
    tmp_overdue
    set CLASSIFY5 = 5
    where overdue_180plus > 0
-- 9-未知.
 
## 24个月状态
算法：计算每一期的逾期天数，向后面各期更新对应字符  
PLAN_STATUS 只有 0，1，2，3 这三种状态

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
    PERIOD )as up_tab ON
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
    PROJECT_ID ,
    PERIOD )as up_tab ON
    tmp_overdue.ProjectID = up_tab.PROJECT_ID
    AND tmp_overdue.Peroid = up_tab.PERIOD 
SET
    tmp_overdue.over_day_count = up_tab.over_day_count;

### 3. 逾期且未结清
UPDATE
    tmp_overdue
inner JOIN (
SELECT PROJECT_ID, PERIOD,  datediff( NOW() , REPAYMENT_DATE ) as over_day_count -- TO_DAYS(PLAN_SETTLE_DATE) - TO_DAYS(REPAYMENT_DATE) -- datediff( PLAN_SETTLE_DATE , REPAYMENT_DATE )
FROM tmp_repay_plan_till_now trptn 
WHERE 
OVERDUE_DAYS = 1 and PLAN_STATUS=2
group by
    PROJECT_ID ,
    PERIOD )as up_tab ON
    tmp_overdue.ProjectID = up_tab.PROJECT_ID
    AND tmp_overdue.Peroid = up_tab.PERIOD 
SET
    tmp_overdue.over_day_count = up_tab.over_day_count;


未逾期的：N
逾期且已还清的，用 当期最后一次还款 - 应还日期，算出逾期的天数
逾期且未还清的，用 当前日期  - 应还日期，算出逾期的天数
prj1 p1 15
prj1 p2 50
prj1 p3 60


## 在这里插入每个人的第一条

## 最后手动更新没有最近一次还款日期的为前期日期。
	
	
	
# -- 身份证
 SELECT
	-- aob.CONTRACT_NO  as 合同号,
	-- aob.CUST_NAME   as  客户姓名,
 '' as ID,
	cbi.CARD_NO as 客户号码,
	'M10154210H0001' as 金融机构代码,
	cpi.SEX as 性别,
	cpi.BIRTH_DATE as 出生日期,
	cpi.MAR_STATUS as 婚姻状况,
	cpi.HIGHEST_EDU as 最高学历,
	'' as 最高学位,
	cpi.FIXED_PHONE as 住宅电话,
	cpi.EMAIL as 电子邮箱,
	cpi.WORK_PHONE as 单位电话,
	cpi.PHONE_NO as 手机号码,
	cpi.HOME_ADDR as 通讯地址,
	cpi.HOME_POSTCODE as 通讯地址邮政编码,
	cpi.DOMICILE_ADDR as 户籍地址,
	cpi.MATE_NAME as 配偶姓名,
	cpi.MATE_ID_TYPE as 配偶证件类型,
	cpi.MATE_ID_CARD as 配偶证件号码,
	cpi.MATE_WORK as 配偶工作单位,
	cpi.MATE_PHONE as 配偶联系电话
FROM
	CUST_PERSON_INFO cpi ,
	CUST_BASE_INFO cbi ,
	APPLY_ORDER_BASE aob
WHERE
	aob.CONTRACT_NO in( 'JXFLMY2019111100110',
	'JXFLMY2019111100041')
	AND aob.APPLY_NO = cbi.APPLY_NO
	AND cbi.ID = cpi.CUST_BASE_INFO_ID
	
# -- 居住
 SELECT
	cbi.CARD_NO as 客户号码,
	'M10154210H0001' as 金融机构代码,
	cpi.HOME_ADDR as 居住地址,
	cpi.HOME_POSTCODE as 居住地址邮政编码,
	cpi.RESIDENT_STATUS as 居住状况
FROM
	CUST_PERSON_INFO cpi ,
	CUST_BASE_INFO cbi ,
	APPLY_ORDER_BASE aob
WHERE
	aob.CONTRACT_NO in( 'JXFLMY2019111100110',
	'JXFLMY2019111100041')
	AND aob.APPLY_NO = cbi.APPLY_NO
	AND cbi.ID = cpi.CUST_BASE_INFO_ID ;


# -- 职业
 SELECT
	cbi.CARD_NO as 客户号码,
	cpi.OCCUPATION as 职业,
	cpi.WORK_COMPANY as 单位名称,
	cpi.CO_TRADE as 单位所属行业,
	cpi.WORK_ADDRESS as 单位地址,
	cpi.WORK_POSTCODE as 单位地址邮政编码,
	cpi.WORK_START_YEAR as 本单位工作起始年份,
	cpi.DUTY as 职务,
	cpi.JOB_TITLE as 职称,
	'' as 年收入,
	'' as 工资账号,
	'' as 工资账户开户银行,
	'M10154210H0001' as 金融机构代码
FROM
	CUST_PERSON_INFO cpi ,
	CUST_BASE_INFO cbi ,
	APPLY_ORDER_BASE aob
WHERE
	aob.CONTRACT_NO in( 'JXFLMY2019111100110',
	'JXFLMY2019111100041')
	AND aob.APPLY_NO = cbi.APPLY_NO
	AND cbi.ID = cpi.CUST_BASE_INFO_ID
	