CREATE DEFINER=`root`@`%` PROCEDURE `small_core`.`sp_return_project`(IN EXEC_DATE datetime)
BEGIN

-- 处理回购项目和提前结清的征信
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
-- select @EXPORT_START_DATE,  @EXPORT_DATE, @OVERDUE_DAYS; 

-- 回购更新的字段 
-- DROP table IF EXISTS tmp_RETURN;
-- CREATE TABLE tmp_RETURN 
truncate table tmp_RETURN;
insert into tmp_RETURN
(
	select ProjectID, max(Peroid) as max_p from t_his_credit thc 
	where ProjectID in (
		SELECT DISTINCT PROJECT_ID 
		FROM tmp_overdue_repo tor
		WHERE 
			tor.settle_flag in (0, 1)
			AND PROJECT_ID IN  
			(SELECT APPLY_NO FROM APPLY_ORDER 
				WHERE APPLY_STATUS = 13 and END_DATE > @EXPORT_START_DATE AND END_DATE <= @EXPORT_DATE )	
	)
	GROUP by ProjectID
);
-- SELECT * from tmp_RETURN


INSERT INTO tmp_overdue
	(ProjectID, Peroid, over_day_count, 
	FINORGCODE, LOANTYPE, LOANBIZTYPE, BUSINESS_NO, AREACODE, 
	STARTDATE, ENDDATE, CURRENCY, CREDIT_TOTAL_AMT, SHARE_CREDIT_TOTAL_AMT, 
	MAX_DEBT_AMT, GUARANTEEFORM, PAYMENT_RATE, PAYMENT_MONTHS, 
	
	NO_PAYMENT_MONTHS, PLAN_REPAY_DT, LAST_REPAY_DT, PLAN_REPAY_AMT, LAST_REPAY_AMT, BALANCE, 
	CUR_OVERDUE_TOTAL_INT, CUR_OVERDUE_TOTAL_AMT, 
	OVERDUE31_60DAYS_AMT, OVERDUE61_90DAYS_AMT, OVERDUE91_180DAYS_AMT, OVERDUE_180DAYS_AMT, 
	SUM_OVERDUE_INT, MAX_OVERDUE_INT, CLASSIFY5, LOAN_STAT, REPAY_MONTH_24_STAT, OVERDRAFT_180DAYS_BAL, 
	LOAN_ACCOUNT_STAT, CUSTNAME, CERTTYPE, CERTNO, CUSTID, BAKE)
	select 
		ProjectID, Peroid+1, 1,
		FINORGCODE, LOANTYPE, LOANBIZTYPE, BUSINESS_NO, AREACODE, 
		STARTDATE, ENDDATE, CURRENCY, CREDIT_TOTAL_AMT, SHARE_CREDIT_TOTAL_AMT, 
		MAX_DEBT_AMT, GUARANTEEFORM, PAYMENT_RATE, PAYMENT_MONTHS, 
		
		IF(NO_PAYMENT_MONTHS>1,NO_PAYMENT_MONTHS-1, 0) , PLAN_REPAY_DT, LAST_REPAY_DT, PLAN_REPAY_AMT, LAST_REPAY_AMT, 0, 
		0, 0, 
		0, 0, 0, 0, 
		SUM_OVERDUE_INT, MAX_OVERDUE_INT, 1, 3, CONCAT(substr(REPAY_MONTH_24_STAT, 2, 23), 'C'), OVERDRAFT_180DAYS_BAL, 
		LOAN_ACCOUNT_STAT, CUSTNAME, CERTTYPE, CERTNO, CUSTID, BAKE
		
		FROM t_his_credit
		where (ProjectID, Peroid) in (select ProjectID, max_p from tmp_RETURN);

	
-- 
UPDATE
    tmp_overdue
inner JOIN (
	SELECT
		tr.ProjectID,
		tr.max_p,
	    REPAY_DATE,
	    REPAY_AMT
	FROM
	    RETURN_PROJECT_DETAIL rpd,
	    tmp_RETURN tr
	WHERE
	    tr.ProjectID = rpd.APPLY_NO
	    and rpd.REPAY_AMT_TYPE = '07'
) as up_tab ON
    tmp_overdue.ProjectID = up_tab.ProjectID
    AND tmp_overdue.Peroid = up_tab.max_p + 1 
SET
	tmp_overdue.PLAN_REPAY_DT = up_tab.REPAY_DATE, 
    tmp_overdue.LAST_REPAY_DT = up_tab.REPAY_DATE, 
    tmp_overdue.PLAN_REPAY_AMT = up_tab.REPAY_AMT,
    tmp_overdue.LAST_REPAY_AMT = up_tab.REPAY_AMT;

-- 处理回购 结束 


--  提前结清
   
UPDATE
    tmp_overdue
inner JOIN (
	select 
		hc.ProjectID,
		max(hc.Peroid+1 ) as cur_p,
		max(hc.PLAN_REPAY_AMT) as PLAN_REPAY_AMT,
		hc.PAYMENT_MONTHS,
		min(hc.NO_PAYMENT_MONTHS+0)-1 as NO_PAYMENT_MONTHS,
		max(hc.ENDDATE) as ENDDATE
	from 
		t_his_credit hc,
		tmp_overdue oo
	where 
		oo.BALANCE=0 
		AND oo.ProjectID IN (SELECT PROJECT_ID FROM tmp_overdue_projects where `type` = 12)
		AND oo.ProjectID = hc.ProjectID
	GROUP by oo.ProjectID 

) as up_tab ON
    tmp_overdue.ProjectID = up_tab.ProjectID
    AND tmp_overdue.Peroid >= up_tab.cur_p 
SET
	tmp_overdue.ENDDATE = up_tab.ENDDATE,
	tmp_overdue.PLAN_REPAY_AMT = up_tab.PLAN_REPAY_AMT,
	tmp_overdue.PAYMENT_MONTHS = up_tab.PAYMENT_MONTHS, 
    tmp_overdue.NO_PAYMENT_MONTHS = up_tab.NO_PAYMENT_MONTHS;

-- 当月报送后，再提前结清，24个月状态位数不能增加
-- 当月有两条！！！！(同月/不同月）
DROP TABLE if exists tmp_same_month;
CREATE TEMPORARY TABLE tmp_same_month 
	SELECT ProjectID, COUNT( (DATE_FORMAT(PLAN_REPAY_DT, '%Y-%m'))) as same_month  
	FROM tmp_overdue 
	where
		ProjectID IN (SELECT PROJECT_ID FROM tmp_overdue_projects where `type` = 12)
	Group by ProjectID, DATE_FORMAT(PLAN_REPAY_DT, '%Y-%m')
	HAVING COUNT( (DATE_FORMAT(PLAN_REPAY_DT, '%Y-%m'))) > 1
;
-- -- SELECT * FROM tmp_same_month;



UPDATE
    tmp_overdue
inner JOIN (
	select 
		thc.ProjectID,  thc.PLAN_REPAY_DT, 
		CONCAT(substr(REPAY_MONTH_24_STAT, 2, 23), 'C')	as new_REPAY_MONTH_24_STAT
	FROM t_his_credit thc, tmp_same_month tsm
	where 
		-- ProjectID IN (SELECT PROJECT_ID FROM tmp_overdue_projects where `type` = 12)
		tsm.ProjectID = thc.ProjectID 
		AND (thc.ProjectID , thc.PLAN_REPAY_DT) IN (select ProjectID, MAX(PLAN_REPAY_DT) FROM t_his_credit group by ProjectID)
		
) as up_tab ON
    tmp_overdue.ProjectID = up_tab.ProjectID
    AND tmp_overdue.LOAN_STAT = 3
    -- HAVING COUNT(DATE_FORMAT(PLAN_REPAY_DT, '%Y-%m')>2) 
SET
	tmp_overdue.REPAY_MONTH_24_STAT = up_tab.new_REPAY_MONTH_24_STAT;

--  提前结清：结束   


END