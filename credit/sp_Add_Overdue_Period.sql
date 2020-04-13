CREATE DEFINER=`root`@`%` PROCEDURE `small_core_leo`.`Add_Overdue_Period`()
BEGIN
	
	
	DECLARE v_PROJECT_ID varchar(64); 
    DECLARE v_PERIOD INT(11); 
    DECLARE v_ENDDATE varchar(10); 
	
	DECLARE v_month_diff INT(11);
	DECLARE done INT DEFAULT 0; 
    

	-- 1. 找出最后一期已经逾期的
	DECLARE cur CURSOR FOR (
		SELECT ProjectID, MAX(Peroid) as mp, ENDDATE FROM 
		tmp_overdue to2 
		WHERE 
		ENDDATE < NOW() 
		GROUP by ProjectID 
	);

	DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1; 

    OPEN cur;
    read_loop:LOOP 
        FETCH cur INTO v_PROJECT_ID, v_PERIOD, v_ENDDATE; 
        IF done = 1 THEN 
            LEAVE read_loop; 
        END IF; 
		
		-- 最终还款日期距离上个月最后一天的月数
		set v_month_diff = TIMESTAMPDIFF(MONTH,v_ENDDATE,last_day(date_add(now(),interval -1 month)));
	
		set @total_rent = (SELECT sum(RECEIPT_AMOUNT_IT) FROM tmp_SETT_RENT_RECEIPT_PLAN WHERE PROJECT_ID= v_PROJECT_ID);	
	
		set @i = 1;
	 	while (@i <= v_month_diff) Do -- 循环开始
	 	
	 		set @t_PLAN_END_DATE  = last_day(date_add(v_ENDDATE,interval @i month));			
			set @paid_rent = ifnull(( SELECT sum(PAID_PRIN_AMT+PAID_INT_AMT)  FROM tmp_repay_instmnt WHERE PROJECT_ID= v_PROJECT_ID and REPAY_DATE<=@t_PLAN_END_DATE), 0);
			set @except_amt = @total_rent - @paid_rent;	-- 本次期望 	
	 	
	 	
	 		INSERT INTO tmp_overdue
			(ProjectID, Peroid, over_day_count, FINORGCODE, LOANTYPE, 
			LOANBIZTYPE, BUSINESS_NO, AREACODE, STARTDATE, ENDDATE, 
			CURRENCY, CREDIT_TOTAL_AMT, SHARE_CREDIT_TOTAL_AMT, MAX_DEBT_AMT, GUARANTEEFORM, 
			PAYMENT_RATE, PAYMENT_MONTHS, NO_PAYMENT_MONTHS, PLAN_REPAY_DT, LAST_REPAY_DT, 
			PLAN_REPAY_AMT, LAST_REPAY_AMT, BALANCE, CUR_OVERDUE_TOTAL_INT, CUR_OVERDUE_TOTAL_AMT, 
			OVERDUE31_60DAYS_AMT, OVERDUE61_90DAYS_AMT, OVERDUE91_180DAYS_AMT, OVERDUE_180DAYS_AMT, 
			SUM_OVERDUE_INT, MAX_OVERDUE_INT, CLASSIFY5, LOAN_STAT, REPAY_MONTH_24_STAT, 
			OVERDRAFT_180DAYS_BAL, LOAN_ACCOUNT_STAT, CUSTNAME, CERTTYPE, CERTNO, CUSTID, BAKE)
			(
			select ProjectID, Peroid+@i,
			TIMESTAMPDIFF(DAY , last_day(date_add(PLAN_REPAY_DT,interval @i month)), now()), 
			FINORGCODE, LOANTYPE, 
			LOANBIZTYPE, BUSINESS_NO, AREACODE, STARTDATE, ENDDATE, 
			CURRENCY, CREDIT_TOTAL_AMT, SHARE_CREDIT_TOTAL_AMT, MAX_DEBT_AMT, GUARANTEEFORM, 
			PAYMENT_RATE, PAYMENT_MONTHS, NO_PAYMENT_MONTHS, 
			DATE_FORMAT(last_day(date_add(PLAN_REPAY_DT,interval @i month)), '%Y%m%d'), 
			LAST_REPAY_DT, @except_amt, LAST_REPAY_AMT, BALANCE, CUR_OVERDUE_TOTAL_INT, CUR_OVERDUE_TOTAL_AMT, 
			OVERDUE31_60DAYS_AMT, OVERDUE61_90DAYS_AMT, OVERDUE91_180DAYS_AMT, OVERDUE_180DAYS_AMT, 
			SUM_OVERDUE_INT, MAX_OVERDUE_INT, CLASSIFY5, LOAN_STAT, REPAY_MONTH_24_STAT, 
			OVERDRAFT_180DAYS_BAL, LOAN_ACCOUNT_STAT, CUSTNAME, CERTTYPE, CERTNO, CUSTID, BAKE
			FROM tmp_overdue
			WHERE ProjectID= v_PROJECT_ID AND  Peroid = v_PERIOD
			);
	       -- INSERT into tmp_overdue(ProjectID, Peroid, PLAN_REPAY_DT) values (v_PROJECT_ID, v_PERIOD+@i, last_day(date_add(v_ENDDATE,interval @i month)));  
	      -- select ProjectID, (Peroid+@i) as period, last_day(date_add(PLAN_REPAY_DT,interval @i month)) PLAN_REPAY_DT  from tmp_overdue;
	       set @i=@i+1;
    	end while; -- 循环结束


	END LOOP read_loop;
    CLOSE cur; 

END