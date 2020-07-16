
set @EXPORT_DATE=DATE_FORMAT('2020-06-10' , '%Y-%m-%d');
set @EXPORT_START_DATE=DATE_FORMAT('2020-06-01' , '%Y-%m-%d');
set @OVERDUE_DAYS = 10;

TRUNCATE table tmp_overdue_projects;

-- 应还日在 6.1 - today() 期间还款的（正常还清本期，回购，提前结清）
INSERT INTO tmp_overdue_projects
( 
	SELECT DISTINCT tor.PROJECT_ID
	FROM tmp_overdue_repo tor,
		SETT_REPAYMENT_PLAN srp				
	WHERE 
		tor.settle_flag in (0, 1)	
		AND tor.PROJECT_ID 			= 	srp.PROJECT_ID
 		AND srp.PLAN_END_DATE 		>= 	@EXPORT_START_DATE
		AND srp.PLAN_SETTLE_DATE 	>= 	@EXPORT_START_DATE
		AND srp.PLAN_SETTLE_DATE	<= 	@EXPORT_DATE
		-- AND srp.PLAN_SETTLE_DATE 	> 	tor.last_date 		
		AND tor.PROJECT_ID NOT IN ( SELECT PROJECT_ID FROM tmp_overdue_projects )
);

-- 6.1 - (today-10)报到本次上报期间的逾期10天的项目
INSERT INTO tmp_overdue_projects
( 
	SELECT DISTINCT tor.PROJECT_ID 	
	FROM tmp_overdue_repo tor,
		SETT_REPAYMENT_PLAN srp	
	WHERE 
		tor.settle_flag in (0, 1)
		AND tor.PROJECT_ID = srp.PROJECT_ID 
		AND srp.PLAN_END_DATE 		>= 	@EXPORT_START_DATE
		AND srp.PLAN_END_DATE 		<=	date_add(@EXPORT_DATE, interval 0-@OVERDUE_DAYS day) 
		AND srp.PLAN_SETTLE_DATE IS NULL 
		AND tor.PROJECT_ID NOT IN ( SELECT PROJECT_ID FROM tmp_overdue_projects )
);


-- 期间 回购和提前结清的，同时报送特殊交易
INSERT INTO tmp_overdue_projects
( 
	SELECT DISTINCT PROJECT_ID 
	FROM tmp_overdue_repo tor
	WHERE 
		tor.settle_flag in (0, 1)
		AND PROJECT_ID IN 
		(SELECT APPLY_NO FROM APPLY_ORDER WHERE APPLY_STATUS in (12, 13) and END_DATE > "2020-05-31")
);


