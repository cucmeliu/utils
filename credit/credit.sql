
-- =====================================
# 说明：只导出应还款日之后一天，处于逾期状态的

## -- 累积代码
-- SELECT
--  a.APPLY_NO,
--  a.TERM_NO,
--  sum(b.paid_prin) AS p_paid_prin
-- FROM
--  tmp_paid_prin a
-- JOIN tmp_paid_prin b
-- WHERE
--  a.APPLY_NO = b.APPLY_NO
--  AND b.TERM_NO <= a.TERM_NO
-- GROUP BY
--  a.APPLY_NO,
--  a.TERM_NO 


# 通用的
## -- 1. 设置导出时间
set @export_date=DATE_FORMAT(NOW() , '%Y-%m-%d');

## -- 2. 逾期报表 as overdue_rpt
-- DROP TABLE tmp_overdue_rpt;
-- CREATE TABLE `tmp_overdue` (
--   `id` int(11) NOT NULL AUTO_INCREMENT,
--   `ProjectID` varchar(64) DEFAULT NULL,
--   `Peroid` int(11) DEFAULT NULL,
--   `over_day_count` int(11) DEFAULT NULL,
--   `FINORGCODE` varchar(14) DEFAULT NULL,
--   `LOANTYPE` varchar(1) DEFAULT NULL,
--   `LOANBIZTYPE` varchar(2) DEFAULT NULL,
--   `BUSINESS_NO` varchar(40) DEFAULT NULL,
--   `AREACODE` int(6) DEFAULT NULL,
--   `STARTDATE` varchar(10) DEFAULT NULL,
--   `ENDDATE` varchar(10) DEFAULT NULL,
--   `CURRENCY` varchar(3) DEFAULT NULL,
--   `CREDIT_TOTAL_AMT` int(10) DEFAULT NULL,
--   `SHARE_CREDIT_TOTAL_AMT` int(10) DEFAULT NULL,
--   `MAX_DEBT_AMT` int(10) DEFAULT NULL,
--   `GUARANTEEFORM` int(1) DEFAULT NULL,
--   `PAYMENT_RATE` varchar(2) DEFAULT NULL,
--   `PAYMENT_MONTHS` varchar(3) DEFAULT NULL,
--   `NO_PAYMENT_MONTHS` varchar(3) DEFAULT NULL,
--   `PLAN_REPAY_DT` varchar(10) DEFAULT NULL,
--   `LAST_REPAY_DT` varchar(10) DEFAULT NULL,
--   `PLAN_REPAY_AMT` int(10) DEFAULT NULL,
--   `LAST_REPAY_AMT` int(10) DEFAULT NULL,
--   `BALANCE` int(10) DEFAULT NULL,
--   `CUR_OVERDUE_TOTAL_INT` int(2) DEFAULT NULL,
--   `CUR_OVERDUE_TOTAL_AMT` int(10) DEFAULT NULL,
--   `OVERDUE31_60DAYS_AMT` int(10) DEFAULT NULL,
--   `OVERDUE61_90DAYS_AMT` int(10) DEFAULT NULL,
--   `OVERDUE91_180DAYS_AMT` int(10) DEFAULT NULL,
--   `OVERDUE_180DAYS_AMT` int(10) DEFAULT NULL,
--   `SUM_OVERDUE_INT` int(3) DEFAULT NULL,
--   `MAX_OVERDUE_INT` int(2) DEFAULT NULL,
--   `CLASSIFY5` int(1) DEFAULT NULL,
--   `LOAN_STAT` int(1) DEFAULT NULL,
--   `REPAY_MONTH_24_STAT` varchar(24) DEFAULT NULL,
--   `OVERDRAFT_180DAYS_BAL` int(10) DEFAULT NULL,
--   `LOAN_ACCOUNT_STAT` varchar(1) DEFAULT NULL,
--   `CUSTNAME` varchar(30) DEFAULT NULL,
--   `CERTTYPE` varchar(1) DEFAULT NULL,
--   `CERTNO` varchar(18) DEFAULT NULL,
--   `CUSTID` varchar(50) DEFAULT NULL,
--   `BAKE` varchar(30) DEFAULT NULL,
--   PRIMARY KEY (`id`),
--   KEY `tmp_overdue_ProjectID_IDX` (`ProjectID`,`Peroid`) USING BTREE
-- ) ENGINE=InnoDB AUTO_INCREMENT=9215 DEFAULT CHARSET=utf8mb4;

TRUNCATE table tmp_overdue_rpt ;
TRUNCATE table tmp_overdue ;

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
    --  AND rrp.WRITE_STATUS=2
    ORDER BY overdue_days DESC ;
-- 

## -- 所有当前逾期的项目
DROP table IF EXISTS tmp_overdue_projects;
CREATE TABLE tmp_overdue_projects 
( SELECT DISTINCT PROJECT_ID FROM tmp_repay_plan_till_now );

## -- 当前逾期项目的查询字段
-- AND PROJECT_ID in ( SELECT DISTINCT PROJECT_ID FROM tmp_overdue_projects )


## -- 项目本金表
DROP TABLE IF EXISTS tmp_project_period_prin;
CREATE TEMPORARY TABLE tmp_project_period_prin 
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
    and srrpd.PROJECT_ID in ( SELECT DISTINCT PROJECT_ID FROM tmp_overdue_projects )
order by
    srrp.PROJECT_ID,
    srrp.PERIOD );
    
### 每期还款时间内还款本金
-- (
-- SELECT
--     PROJECT_ID ,
--     PERIOD ,
--     sum(PAID_PRIN_AMT) as paid_prin_during
-- FROM
--     (
--     SELECT
--         srp.PROJECT_ID,
--         srp.PERIOD,
--         srp.PLAN_START_DATE,
--         srp.PLAN_END_DATE,
--         rid.REPAY_DATE,
--         rid.PAID_PRIN_AMT
--     FROM
--         SETT_REPAYMENT_PLAN srp ,
--         REPAY_INSTMNT_DETAIL rid
--     WHERE
--         srp.PROJECT_ID = rid.APPLY_NO
--         and srp.PERIOD = rid.TERM_NO
--         and rid.REPAY_DATE between srp.PLAN_START_DATE and srp.PLAN_END_DATE 
--         ) paid_during
-- GROUP BY
--     PROJECT_ID,
--     PERIOD
-- ) paid_prin_amount_druing


# -- 基础信息
-- 逾期的人从第一期到今的还款计划，即所有需要计算的 project + period
DROP table if exists tmp_repay_plan_till_now;
CREATE TABLE tmp_repay_plan_till_now(
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
    PROJECT_ID in ( SELECT DISTINCT PROJECT_ID FROM tmp_overdue_projects )
    and REPAYMENT_DATE < NOW()
ORDER BY
    PROJECT_ID,
    PERIOD );


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
    ao.PERIOD - trptn.PERIOD AS NO_PAYMENT_MONTHS,
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
    APPLY_ORDER ao,
    tmp_repay_plan_till_now trptn
WHERE
    ao.APPLY_NO = trptn.PROJECT_ID
    and trptn.PERIOD <= ao.PERIOD 
ORDER BY
    ao.APPLY_NO,
    ao.PERIOD
    );
        


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
            tmp_overdue_projects )
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
        PROJECT_ID, PERIOD, SUM(rid.REPAY_AMT)  as LAST_REPAY_AMT , max(rid.REPAY_DATE) as LAST_REPAY_DT
    FROM 
        SETT_REPAYMENT_PLAN srp ,
    -- left join 
        REPAY_INSTMNT_DETAIL rid 
    -- on srp.PROJECT_ID = rid.APPLY_NO
    WHERE srp.PROJECT_ID = rid.APPLY_NO
        and rid.APPLY_NO in ( SELECT DISTINCT PROJECT_ID FROM tmp_overdue_projects ) 
        and srp.PROJECT_ID in ( SELECT DISTINCT PROJECT_ID FROM tmp_overdue_projects ) 
        AND rid.REPAY_DATE > srp.PLAN_START_DATE  
        AND rid.REPAY_DATE <= srp.PLAN_END_DATE
    GROUP by PROJECT_ID, PERIOD
) as up_tab 
ON
    tmp_overdue.ProjectID = up_tab.PROJECT_ID
    AND tmp_overdue.Peroid = up_tab.PERIOD 
SET 
    tmp_overdue.LAST_REPAY_DT = up_tab.LAST_REPAY_DT,
    tmp_overdue.LAST_REPAY_AMT = up_tab.LAST_REPAY_AMT;
        
## -- 最近一次实际还款日期；本期有，则用本期最新；本期无，则用历史最新 {下一个步骤}
-- 改正为本还款期内的还款时间，还款额
-- v 1.0
-- UPDATE
--     tmp_overdue
-- inner JOIN (
--     SELECT
--         APPLY_NO,
--         TERM_NO,
--         max(REPAY_DATE) as LAST_REPAY_DT -- ,
--         -- SUM(REPAY_INSTMNT_DETAIL.REPAY_AMT) as LAST_REPAY_AMT
--     FROM
--         REPAY_INSTMNT_DETAIL
--     WHERE
--         APPLY_NO in (
--         SELECT
--             DISTINCT PROJECT_ID
--         FROM
--             tmp_overdue_projects )
--     group by
--         APPLY_NO,
--         TERM_NO ) as up_tab ON
--     tmp_overdue.ProjectID = up_tab.APPLY_NO
--     AND tmp_overdue.Peroid = up_tab.TERM_NO 
--     SET
--     tmp_overdue.LAST_REPAY_DT = up_tab.LAST_REPAY_DT -- ,
    -- tmp_overdue.LAST_REPAY_AMT = up_tab.LAST_REPAY_AMT
    


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



    
# --   ======  以下为需要汇总的字段 
## -- ==余额 
-- 此数据项是指贷款本金余额。 用总贷款本金ao.ACTUAL_AMOUNT - 已还本金
-- 先计算已还本金
### -- 每期最终还款本金
-- (
-- SELECT
--     PROJECT_ID ,
--     PERIOD ,
--     sum(PAID_PRIN_AMT) as paid_prin_during
-- FROM
--     (
--     SELECT
--         srp.PROJECT_ID,
--         srp.PERIOD,
--         srp.PLAN_START_DATE,
--         srp.PLAN_END_DATE,
--         rid.REPAY_DATE,
--         rid.PAID_PRIN_AMT
--     FROM
--         SETT_REPAYMENT_PLAN srp ,
--         REPAY_INSTMNT_DETAIL rid
--     WHERE
--         srp.PROJECT_ID = rid.APPLY_NO
--         and srp.PERIOD = rid.TERM_NO
--         -- and rid.REPAY_DATE between srp.PLAN_START_DATE and srp.PLAN_END_DATE 
--         ) paid_during
-- GROUP BY
--     PROJECT_ID,
--     PERIOD
-- ) paid_prin_amount_period;



### 每期实际还本金
-- DROP TABLE if exists tmp_paid_prin;
-- CREATE TABLE tmp_paid_prin (
-- SELECT
--     APPLY_NO ,
--     TERM_NO ,
--     SUM(PAID_PRIN_AMT) as paid_prin
-- FROM
--     REPAY_INSTMNT_DETAIL
-- WHERE
--     APPLY_NO in (
--     SELECT
--         DISTINCT PROJECT_ID
--     FROM
--         tmp_overdue_projects )
-- Group by
--     APPLY_NO ,
--     TERM_NO );

-- 改为截止当期还款时间，即在每一期还款时间内的还款本金
DROP TABLE if exists tmp_paid_prin;
CREATE TABLE tmp_paid_prin (
SELECT
    srp.PROJECT_ID ,
    srp.PERIOD ,
    SUM(rid.PAID_PRIN_AMT) as paid_prin
FROM
	SETT_REPAYMENT_PLAN srp
left join
    REPAY_INSTMNT_DETAIL rid
on
	srp.PROJECT_ID = rid.APPLY_NO 
WHERE
   -- APPLY_NO in ( SELECT DISTINCT PROJECT_ID FROM tmp_overdue_projects )
-- and 
PROJECT_ID in ( SELECT DISTINCT PROJECT_ID FROM tmp_overdue_projects )
and (rid.REPAY_DATE <= srp.PLAN_END_DATE OR rid.REPAY_DATE is NULL )
Group by PROJECT_ID , PERIOD 
-- ORDER by  PROJECT_ID , PERIOD 
    );
   
-- SELECT * from tmp_paid_prin tpp where PROJECT_ID = '201912160774052500A'

### 截止每一期时，实际总共已还款本金
-- DROP TABLE if exists tmp_paid;
-- CREATE TEMPORARY TABLE tmp_paid (
-- SELECT
--     a.APPLY_NO,
--     a.TERM_NO,
--     sum(b.paid_prin) as p_paid_prin
-- FROM
--     tmp_paid_prin a
-- JOIN tmp_paid_prin b
-- WHERE
--     a.APPLY_NO = b.APPLY_NO
--     and b.TERM_NO <= a.TERM_NO
-- group by
--     a.APPLY_NO,
--     a.TERM_NO );

   
### -- 余额 = 总本金 - 已还本金
UPDATE
    tmp_overdue
inner JOIN (
    SELECT
        ao.APPLY_NO,
        tmp_paid_prin.PERIOD,
        (ao.ACTUAL_AMOUNT - IFNULL(tmp_paid_prin.paid_prin, 0)) as BALANCE
    FROM
        APPLY_ORDER ao,
        tmp_paid_prin
    WHERE 
        ao.APPLY_NO = tmp_paid_prin.PROJECT_ID
    GROUP BY
        ao.APPLY_NO,
        tmp_paid_prin.PERIOD ) as up_tab 
        ON
    tmp_overdue.ProjectID = up_tab.APPLY_NO
    AND tmp_overdue.Peroid = up_tab.PERIOD 
SET
    tmp_overdue.BALANCE = up_tab.BALANCE;
   
   
## -- == 当前逾期期数
-- UPDATE
--     tmp_overdue
-- inner JOIN ( 
--  SELECT ProjectID , Peroid ,IF(over_day_count=0, 0, 1) as is_cur_overdue
--  FROM tmp_overdue
--  group by ProjectID , Peroid 
--  
-- ) as up_tab ON
--     tmp_overdue.ProjectID = up_tab.ProjectID
--     AND tmp_overdue.Peroid = up_tab.Peroid 
-- SET
--     tmp_overdue.CUR_OVERDUE_TOTAL_INT = up_tab.CUR_OVERDUE_TOTAL_INT;

### -- 目前还处于逾期执行中的，进行汇总
DROP table if exists tmp_CUR_OVERDUE_TOTAL_INT; 
CREATE table tmp_CUR_OVERDUE_TOTAL_INT (
SELECT 
    PROJECT_ID , PERIOD ,REPAYMENT_DATE, IFNULL(PLAN_SETTLE_DATE, curdate() ) as SETTLE_DATE
FROM 
    SETT_REPAYMENT_PLAN
WHERE 
    PROJECT_ID in ( SELECT DISTINCT PROJECT_ID FROM tmp_overdue_projects )
    and REPAYMENT_DATE < IFNULL(PLAN_SETTLE_DATE, curdate() )
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
        and b.SETTLE_DATE >= a.REPAYMENT_DATE
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
            tmp_overdue_projects )
        and b.PERIOD <= a.PERIOD
    group by
        a.PROJECT_ID ,
        a.PERIOD )as up_tab ON
    tmp_overdue.ProjectID = up_tab.PROJECT_ID
    AND tmp_overdue.Peroid = up_tab.PERIOD 
SET
    tmp_overdue.SUM_OVERDUE_INT = up_tab.total_overdue;   
   

## -- 当前逾期总额
-- 租金计划 - 记录还款分期流水
-- SETT_REPAYMENT_PLAN - REPAY_INSTMNT_DETAIL
-- 如果当期没有实际还款，要考虑罚息
### 每一期的逾期总额
DROP TABLE if exists tmp_CUR_OVERDUE_AMT;
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
            tmp_overdue_projects)
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

    
-- 向前累积求和，截止当前所有逾期的总额
-- 每期租金
DROP table if exists tmp_period_EXPECTED_AMT;
-- CREATE  table tmp_period_EXPECTED_AMT
-- SELECT PROJECT_ID, PERIOD, REPAYMENT_DATE , EXPECTED_AMT
-- FROM 
--     SETT_REPAYMENT_PLAN
-- WHERE 
--     PROJECT_ID in ( SELECT DISTINCT PROJECT_ID FROM tmp_overdue_projects ) 
--     and REPAYMENT_DATE < NOW() 
CREATE  table tmp_period_EXPECTED_AMT(
SELECT 
    PROJECT_ID, PERIOD, RECEIPT_PLAN_DATE, RECEIPT_AMOUNT_IT
FROM 
    SETT_RENT_RECEIPT_PLAN
WHERE 
    PROJECT_ID in ( SELECT DISTINCT PROJECT_ID FROM tmp_overdue_projects ) 
    and RECEIPT_PLAN_DATE < NOW() 
    );
    
-- 截止每期时间的总租金
DROP TABLE if exists tmp_EXPECTED_AMT;
CREATE TEMPORARY TABLE tmp_EXPECTED_AMT
SELECT
    a.PROJECT_ID,
    a.PERIOD,
    a.RECEIPT_PLAN_DATE,
    sum(b.RECEIPT_AMOUNT_IT) AS p_EXPECTED_AMT
FROM
    tmp_period_EXPECTED_AMT a
JOIN tmp_period_EXPECTED_AMT b
WHERE
    a.PROJECT_ID = b.PROJECT_ID
    AND b.PERIOD <= a.PERIOD
GROUP BY
    a.PROJECT_ID,
    a.PERIOD;
        
    
-- 截止每期时间的总罚息
DROP TABLE if exists tmp_fine_AMT;
CREATE TEMPORARY TABLE tmp_fine_AMT
SELECT tea.PROJECT_ID, tea.PERIOD,  sum(sfrp.RECEIPT_AMOUNT_IT) as p_fine_AMT
FROM 
    tmp_EXPECTED_AMT tea
left join 
    SETT_FINE_RECEIPT_PLAN sfrp
on 
    tea.PROJECT_ID = sfrp.PROJECT_ID 
WHERE sfrp.RECEIPT_PLAN_DATE <= tea.RECEIPT_PLAN_DATE
GROUP by tea.PROJECT_ID, tea.PERIOD;


-- 截止每期时间的总还款       
DROP TABLE IF EXISTS tmp_REPAY_AMT;
CREATE TEMPORARY TABLE tmp_REPAY_AMT
SELECT tea.PROJECT_ID, tea.PERIOD,  sum(rid.REPAY_AMT) as p_repay_AMT
FROM 
    tmp_EXPECTED_AMT tea
left join 
    REPAY_INSTMNT_DETAIL rid
on 
    tea.PROJECT_ID = rid.APPLY_NO 
WHERE rid.REPAY_DATE <= tea.RECEIPT_PLAN_DATE
GROUP by tea.PROJECT_ID, tea.PERIOD;


-- 当前逾期总额
UPDATE
    tmp_overdue
inner JOIN (
SELECT
    te.PROJECT_ID, te.PERIOD, (te.p_EXPECTED_AMT+IFNULL(tf.p_fine_AMT,0)-IFNULL(tr.p_repay_AMT,0)) as CUR_OVERDUE_TOTAL_AMT
FROM tmp_EXPECTED_AMT te
left join tmp_fine_AMT tf
on
    te.PROJECT_ID = tf.PROJECT_ID
    and te.PERIOD = tf.PERIOD
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

    
    
## -- 逾期31-60天未归还贷款本金 -- 逾期31天未还清 > 0，但60天已还清 = 0
    -- 逾期61-90天未归还贷款本金  -- 逾期61天未还清，但90天已还清
    -- 逾期91-180天未归还贷款本金
    -- 逾期180天以上未归还贷款本金
    
### 逾期31天内已还本金 < 31
DROP table if exists paid_prin_amount_31day;
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
        and rid.APPLY_NO in ( SELECT DISTINCT PROJECT_ID FROM tmp_overdue_projects )
        and date_add(srp.PLAN_END_DATE, interval 30 day) <= @export_date --  NOW()
        and rid.REPAY_DATE between srp.PLAN_START_DATE and date_add(srp.PLAN_END_DATE, interval 30 day)
        ORDER by PLAN_END_DATE desc
        ) paid_during
GROUP BY
    PROJECT_ID,
    PERIOD
) ;


### 逾期61天内已还本金 < 61
DROP table if exists paid_prin_amount_61day;
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
        and rid.APPLY_NO in ( SELECT DISTINCT PROJECT_ID FROM tmp_overdue_projects )
        and date_add(srp.PLAN_END_DATE, interval 60 day) <= @export_date --  NOW()
        and rid.REPAY_DATE between srp.PLAN_START_DATE and date_add(srp.PLAN_END_DATE, interval 60 day)
        ) paid_during
GROUP BY
    PROJECT_ID,
    PERIOD
) ;


-- test
-- SELECT * from (
-- SELECT 
-- p30.*, p60.paid_prin_during as p60_paid
-- FROM 
-- paid_prin_amount_31day p30
-- left join
-- paid_prin_amount_61day p60
-- on p30.PROJECT_ID = p60.PROJECT_ID
-- and p30.PERIOD = p60.PERIOD
-- ) pps WHERE isnull(PROJECT_ID)


### 逾期91天内已还本金 < 91
DROP table if exists paid_prin_amount_91day;
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
        and rid.APPLY_NO in ( SELECT DISTINCT PROJECT_ID FROM tmp_overdue_projects )
        and date_add(srp.PLAN_END_DATE, interval 90 day) <= @export_date --  NOW()
        and rid.REPAY_DATE between srp.PLAN_START_DATE and date_add(srp.PLAN_END_DATE, interval 90 day)
        ) paid_during
GROUP BY
    PROJECT_ID,
    PERIOD
) ;


### 逾期120天内已还本金 < 121，给后面5级分类用的
DROP table if exists paid_prin_amount_121day;
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
        and rid.APPLY_NO in ( SELECT DISTINCT PROJECT_ID FROM tmp_overdue_projects )
        and date_add(srp.PLAN_END_DATE, interval 120 day) <= @export_date --  NOW()
        and rid.REPAY_DATE between srp.PLAN_START_DATE and date_add(srp.PLAN_END_DATE, interval 120 day)
        ) paid_during
GROUP BY
    PROJECT_ID,
    PERIOD
) ;



### 逾期181天内已还本金 < 181
DROP table if exists paid_prin_amount_181day;
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
        and rid.APPLY_NO in ( SELECT DISTINCT PROJECT_ID FROM tmp_overdue_projects )
        and date_add(srp.PLAN_END_DATE, interval 180 day) <= @export_date --  NOW()
        and rid.REPAY_DATE between srp.PLAN_START_DATE and date_add(srp.PLAN_END_DATE, interval 180 day)
        ORDER by PLAN_END_DATE desc
        ) paid_during
GROUP BY
    PROJECT_ID,
    PERIOD
) ;



-- x天未还清的
-- select 
-- ppp.PROJECT_ID, ppp.PERIOD, (ppp.RECEIPT_AMOUNT_IT - ppxday.paid_prin_during)  as overdue180
-- FROM 
-- tmp_project_period_prin ppp, 
-- paid_prin_amount_181day ppxday
-- WHERE 
-- ppp.PROJECT_ID = ppxday.PROJECT_ID
-- and ppp.PROJECT_ID = '201911200801893229A'
-- AND ppp.PERIOD = ppxday.PERIOD
-- AND (ppp.RECEIPT_AMOUNT_IT > ppxday.paid_prin_during) 
-- order by ppp.PROJECT_ID, ppp.PERIOD



### -- 1 - 30 -- 逾期30天内还清的，给5级分类用的
DROP TABLE if exists overdue_1to30;
CREATE TEMPORARY TABLE overdue_1to30
(
select * from
    (
    select
        ppp.PROJECT_ID,
        ppp.PERIOD,
        ppp.RECEIPT_AMOUNT_IT,
        ppxday.paid_prin_during,
        (ppp.RECEIPT_AMOUNT_IT - IFNULL( ppxday.paid_prin_during, 0)) as overdue_amt
    FROM
        tmp_project_period_prin ppp
    LEFT JOIN paid_prin_amount_31day ppxday on
        ppp.PROJECT_ID = ppxday.PROJECT_ID
        AND ppp.PERIOD = ppxday.PERIOD
    WHERE
        ppp.PROJECT_ID in ( SELECT DISTINCT PROJECT_ID FROM tmp_overdue_projects )
        AND ppp.RECEIPT_PLAN_DATE < @export_date
        -- and date_add(ppp.RECEIPT_PLAN_DATE, interval 30 day)<= @export_date
        and (ppp.RECEIPT_AMOUNT_IT > IFNULL(ppxday.paid_prin_during,
        0))
    order by
        ppp.PROJECT_ID,
        ppp.PERIOD ) as tt
WHERE
    overdue_amt = 0
);

### -- 30 - 60  --- 还要加 60 天已还清的条件
DROP TABLE if exists overdue_30to60;
CREATE TEMPORARY TABLE overdue_30to60
(
select
    *
from
    (
    select
        ppp.PROJECT_ID,
        ppp.PERIOD,
        ppp.RECEIPT_AMOUNT_IT,
        ppxday.paid_prin_during,
        (ppp. RECEIPT_AMOUNT_IT - IFNULL( ppxday.paid_prin_during,
        0)) as overdue_amt,
        (ppp. RECEIPT_AMOUNT_IT - IFNULL( ppxxday.paid_prin_during,
        0)) as overdue_amt_xx
    FROM
        tmp_project_period_prin ppp
    LEFT JOIN paid_prin_amount_31day ppxday on
        ppp.PROJECT_ID = ppxday.PROJECT_ID
        AND ppp.PERIOD = ppxday.PERIOD
    LEFT JOIN paid_prin_amount_61day ppxxday on
        ppp.PROJECT_ID = ppxxday.PROJECT_ID
        AND ppp.PERIOD = ppxxday.PERIOD
    WHERE
        ppp.PROJECT_ID in ( SELECT DISTINCT PROJECT_ID FROM tmp_overdue_projects ) # = '201901260489950721A' # 
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
);

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
DROP TABLE if exists overdue_60to90;
CREATE TEMPORARY TABLE overdue_60to90 (
select
    *
from
    (
    select
        ppp.PROJECT_ID,
        ppp.PERIOD,
        ppxday.paid_prin_during,
        ppp.RECEIPT_AMOUNT_IT,
        (ppp. RECEIPT_AMOUNT_IT - IFNULL( ppxday.paid_prin_during,
        0)) as overdue_amt,
        (ppp. RECEIPT_AMOUNT_IT - IFNULL( ppxxday.paid_prin_during,
        0)) as overdue_amt_xx
    FROM
        tmp_project_period_prin ppp
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
            tmp_overdue_projects )
        AND ppp.RECEIPT_PLAN_DATE < @export_date
        and date_add(ppp.RECEIPT_PLAN_DATE,
        interval 60 day)<= @export_date
        and (ppp.RECEIPT_AMOUNT_IT > IFNULL(ppxday.paid_prin_during,
        0))
    order by
        ppp.PROJECT_ID,
        ppp.PERIOD ) as tt
WHERE
    overdue_amt_xx = 0 );

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
DROP TABLE if exists overdue_90to180;
CREATE TEMPORARY TABLE overdue_90to180
(
select
    *
from
    (
    select
        ppp.PROJECT_ID,
        ppp.PERIOD,
        ppp.RECEIPT_AMOUNT_IT,
        ppxday.paid_prin_during,
        (ppp. RECEIPT_AMOUNT_IT - IFNULL( ppxday.paid_prin_during, 0)) as overdue_amt,
        (ppp. RECEIPT_AMOUNT_IT - IFNULL( ppxxday.paid_prin_during, 0)) as overdue_amt_xx
    FROM
        tmp_project_period_prin ppp
    LEFT JOIN paid_prin_amount_91day ppxday on
        ppp.PROJECT_ID = ppxday.PROJECT_ID
        AND ppp.PERIOD = ppxday.PERIOD
    LEFT JOIN paid_prin_amount_181day ppxxday on
        ppp.PROJECT_ID = ppxxday.PROJECT_ID
        AND ppp.PERIOD = ppxxday.PERIOD
    WHERE
        ppp.PROJECT_ID in ( SELECT DISTINCT PROJECT_ID FROM tmp_overdue_projects )
        AND ppp.RECEIPT_PLAN_DATE < @export_date
        and date_add(ppp.RECEIPT_PLAN_DATE, interval 90 day)<= @export_date
        and (ppp.RECEIPT_AMOUNT_IT > IFNULL(ppxday.paid_prin_during, 0))
    order by
        ppp.PROJECT_ID, ppp.PERIOD ) as tt
WHERE
    overdue_amt_xx = 0 
);

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

### > 180 天
DROP TABLE if exists overdue_over180;
CREATE TEMPORARY TABLE overdue_over180
(
select
    *
from
    (
    select
        ppp.PROJECT_ID,
        ppp.PERIOD,
        ppp.RECEIPT_AMOUNT_IT,
        ppxday.paid_prin_during,
        (ppp. RECEIPT_AMOUNT_IT - IFNULL( ppxday.paid_prin_during, 0)) as overdue_amt
    FROM
        tmp_project_period_prin ppp
    LEFT JOIN paid_prin_amount_181day ppxday on
        ppp.PROJECT_ID = ppxday.PROJECT_ID
        AND ppp.PERIOD = ppxday.PERIOD
    WHERE
        ppp.PROJECT_ID in ( SELECT DISTINCT PROJECT_ID FROM tmp_overdue_projects )
        AND ppp.RECEIPT_PLAN_DATE < @export_date
        and date_add(ppp.RECEIPT_PLAN_DATE, interval 180 day)<= @export_date
        and (ppp.RECEIPT_AMOUNT_IT > IFNULL(ppxday.paid_prin_during, 0))
    order by
        ppp.PROJECT_ID, ppp.PERIOD ) as tt
WHERE
    overdue_amt = 0 
);
    
-- update
UPDATE
    tmp_overdue
inner JOIN (
    select
        PROJECT_ID,
        PERIOD,
        overdue_amt
    FROM
        overdue_over180
    GROUP by
        PROJECT_ID,
        PERIOD ) as up_tab ON
    tmp_overdue.ProjectID = up_tab.PROJECT_ID
    AND tmp_overdue.Peroid = up_tab.PERIOD 
    SET
    tmp_overdue.OVERDUE_180DAYS_AMT = up_tab.overdue_amt;




UPDATE tmp_overdue set OVERDUE31_60DAYS_AMT=0 WHERE OVERDUE31_60DAYS_AMT is NULL;
UPDATE tmp_overdue set OVERDUE61_90DAYS_AMT=0 WHERE OVERDUE61_90DAYS_AMT is NULL;
UPDATE tmp_overdue set OVERDUE91_180DAYS_AMT=0 WHERE OVERDUE91_180DAYS_AMT is NULL;
UPDATE tmp_overdue set OVERDUE_180DAYS_AMT=0 WHERE OVERDUE_180DAYS_AMT is NULL;

##  -- 最高逾期期数
-- DELIMITER ;;
-- drop procedure if exists MAX_OVERDUE; 
-- CREATE DEFINER=`root`@`%` PROCEDURE `small_core_like_prod`.`MAX_OVERDUE`(
-- )
-- BEGIN 
--     DECLARE v_PROJECT_ID varchar(64); 
--     DECLARE v_PERIOD INT(11); 
--     DECLARE v_OVERDUE_DAYS INT(11); 
-- 
--     DECLARE cur_prj varchar(64) DEFAULT ''; 
--     DECLARE succ_over INT DEFAULT 0; 
--     DECLARE done INT DEFAULT 0; 
-- 
--     
-- 
--     DECLARE cur CURSOR FOR (
--     SELECT
--         PROJECT_ID,
--         PERIOD,
--         -- REPAYMENT_DATE,
--         -- EXPECTED_AMT,
--         -- PLAN_STATUS ,
--         OVERDUE_DAYS
--     FROM
--         -- SETT_REPAYMENT_PLAN
--         tmp_repay_plan_till_now
--         order by PROJECT_ID , PERIOD );
-- -- tmp_repay_plan_till_now)
--     DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1; 
-- 
--     OPEN cur;
--     read_loop:LOOP 
--         FETCH cur INTO v_PROJECT_ID, v_PERIOD, v_OVERDUE_DAYS; 
--         IF done = 1 THEN 
--             LEAVE read_loop; 
--         END IF; 
--     
--         IF cur_prj <> v_PROJECT_ID THEN 
--             SET succ_over = 0;
--             SET cur_prj = v_PROJECT_ID;
--         ELSEIF v_OVERDUE_DAYS = 0 THEN 
--             SET succ_over = 0;
--         ELSE 
--             SET succ_over = succ_over + 1; 
--         END IF; 
-- 
--         -- SELECT v_PROJECT_ID, v_PERIOD, succ_over; --  as log into outfile '/tmp/result.txt';
--         -- 更新状态   
--         UPDATE tmp_overdue SET MAX_OVERDUE_INT = succ_over WHERE ProjectID = v_PROJECT_ID AND Peroid = v_PERIOD;
--     END LOOP read_loop;
--     CLOSE cur; 
-- END
-- DELIMITER ;            
-- 
-- call MAX_OVERDUE();

    
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
   


## -- 账户状态
-- PLAN_STATUS  
--     当期还款计划状态（0：等待执行；1：正常执行中；2：逾期执行中；3：已结清；4：已终止；5：已核销）
-- LOAN_STAT
--     "1-正常：目前所有应还租金都已经还清
--     2-逾期：目前还有应还未还的租金未结清
--     3-结清：整个合同结清时上报的的最后一条数据"

UPDATE
    tmp_overdue
set LOAN_STAT = 1 
WHERE 
    CUR_OVERDUE_TOTAL_INT = 0;
    
UPDATE
    tmp_overdue
set LOAN_STAT = 2 
WHERE 
    CUR_OVERDUE_TOTAL_INT > 0;

-- 1-正常：目前所有应还租金都已经还清
-- UPDATE
--     tmp_overdue
-- inner JOIN (
--     SELECT
--         PROJECT_ID,
--         PERIOD,
--         PLAN_STATUS
--     FROM
--         SETT_REPAYMENT_PLAN
--     WHERE
--         PROJECT_ID in ( SELECT DISTINCT PROJECT_ID FROM tmp_overdue_projects )
--         and SETT_REPAYMENT_PLAN.PLAN_STATUS = 3
--     group by
--         PROJECT_ID,
--         PERIOD ) as up_tab ON
--     tmp_overdue.ProjectID = up_tab.PROJECT_ID
--     AND tmp_overdue.Peroid = up_tab.PERIOD 
-- SET
--     tmp_overdue.LOAN_STAT = 1;
-- 
-- 
-- -- 2-逾期：目前还有应还未还的租金未结清
-- UPDATE tmp_overdue
-- set LOAN_STAT = 2
-- WHERE CUR_OVERDUE_TOTAL_AMT > 0


-- 3-结清：整个合同结清时上报的的最后一条数据
UPDATE
    tmp_overdue
inner JOIN (
SELECT APPLY_NO, PERIOD as max_period 
FROM
APPLY_ORDER
WHERE APPLY_NO in ( SELECT DISTINCT PROJECT_ID FROM tmp_overdue_projects )

-- SELECT PROJECT_ID, max(PERIOD)  as max_period 
-- FROM
--         SETT_REPAYMENT_PLAN
--     WHERE
--         PROJECT_ID in ( SELECT DISTINCT PROJECT_ID FROM tmp_overdue_projects )
-- group by PROJECT_ID
) as up_tab 
ON
    tmp_overdue.ProjectID = up_tab.APPLY_NO
    AND tmp_overdue.Peroid = up_tab.max_period 
AND (tmp_overdue.LOAN_STAT = 1 or tmp_overdue.BALANCE = 0)
SET
    tmp_overdue.LOAN_STAT = 3;
  
   




## 在这里插入每个人的第一条
## -- -- 第一条记录是新开户相关信息
-- 为减少影响，这条放在所有数据处理完后，最后再执行
INSERT
    INTO
    small_core_like_prod.tmp_overdue (ProjectID,
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
        APPLY_ORDER ao
    WHERE
        ao.APPLY_NO in ( SELECT DISTINCT PROJECT_ID FROM tmp_overdue_projects ) );

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




# 执行Python 代码 
python MONTH_24_STAT.py




    
# 转成中文
SELECT 
FINORGCODE      as      金融机构代码（业务发生机构代码）    ,
LOANTYPE        as      业务种类    ,
LOANBIZTYPE     as      业务种类细分  ,
BUSINESS_NO     as      业务号 ,
AREACODE        as      发生地点    ,
STARTDATE       as      开户日期    ,
ENDDATE     as      到期日期    ,
CURRENCY        as      币种  ,
CREDIT_TOTAL_AMT        as      授信额度    ,
SHARE_CREDIT_TOTAL_AMT      as      共享授信额度  ,
MAX_DEBT_AMT        as      最大负债额   ,
GUARANTEEFORM       as      担保方式    ,
PAYMENT_RATE        as      还款频率    ,
PAYMENT_MONTHS      as      还款月数    ,
NO_PAYMENT_MONTHS       as      剩余还款月数  ,
PLAN_REPAY_DT       as      结算、应还款日期    ,
LAST_REPAY_DT       as      最近一次实际还款日期  ,
PLAN_REPAY_AMT      as      本月应还款金额 ,
LAST_REPAY_AMT      as      本月实际还款金额    ,
BALANCE     as      余额  ,
CUR_OVERDUE_TOTAL_INT       as      当前逾期期数  ,
CUR_OVERDUE_TOTAL_AMT       as      当前逾期总额  ,
OVERDUE31_60DAYS_AMT        as      逾期31、60天未归还贷款本金 ,
OVERDUE61_90DAYS_AMT        as      逾期61、90天未归还贷款本金 ,
OVERDUE91_180DAYS_AMT       as      逾期91、180天未归还贷款本金    ,
OVERDUE_180DAYS_AMT     as      逾期180天以上未归还贷款本金 ,
SUM_OVERDUE_INT     as      累计逾期期数  ,
MAX_OVERDUE_INT     as      最高逾期期数  ,
CLASSIFY5       as      五级分类状态  ,
LOAN_STAT       as      账户状态    ,
REPAY_MONTH_24_STAT     as      24个月（账户）还款状态    ,
OVERDRAFT_180DAYS_BAL       as      透支180天以上未付余额    ,
LOAN_ACCOUNT_STAT       as      账户拥有者信息提示   ,
CUSTNAME        as      姓名  ,
CERTTYPE        as      证件类型    ,
CERTNO      as      证件号码    ,
CUSTID      as      客户号码    ,
BAKE        as      预留字段    
FROM tmp_overdue 
order by ProjectID, Peroid;
    


-- DELETE FROM tmp_overdue  WHERE ProjectID <> '201908190739259304A'




    
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
    aob.CONTRACT_NO in (SELECT CONCAT('"' , JXFL_CONTRACT_NO, '",' FROM tmp_overdue_rpt )
    AND aob.APPLY_NO = cbi.APPLY_NO
    AND cbi.ID = cpi.CUST_BASE_INFO_ID
    
    
    
# 手机号码
    SELECT CONCAT( JXFL_CONTRACT_NO, ',') FROM  
    ( select DISTINCT JXFL_CONTRACT_NO  FROM tmp_overdue_rpt ) tt
    
    SELECT
    cbi.CUST_NAME as 姓名,
    cpi.PHONE_NO as 手机号码
FROM
    CUST_PERSON_INFO cpi ,
    CUST_BASE_INFO cbi ,
    APPLY_ORDER_BASE aob
WHERE
    aob.CONTRACT_NO in ()
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
    