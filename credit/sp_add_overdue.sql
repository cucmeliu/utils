CREATE DEFINER=`root`@`%` PROCEDURE `small_core_leo`.`add_overdue`()
BEGIN
	
	
	DECLARE v_PROJECT_ID varchar(64); 
    DECLARE v_PERIOD INT(11); 
    DECLARE v_ENDDATE varchar(10); 
	
	DECLARE v_month_diff INT(11);
	DECLARE done INT DEFAULT 0; 
    

	-- 1. 找出最后一期已经逾期的
	DECLARE cur CURSOR FOR (
		SELECT PROJECT_ID, MAX(PERIOD) as mp, REPAYMENT_DATE FROM 
		tmp_overdue_rpt to2 
		WHERE 
		REPAYMENT_DATE < NOW() 
		GROUP by PROJECT_ID 
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
		set @i = 1;
		-- 超过的第1期，起始时间为最后一期的enddate，后续的为自然月的第一天
		
 		set @total_rent = (SELECT sum(RECEIPT_AMOUNT_IT) FROM tmp_SETT_RENT_RECEIPT_PLAN WHERE PROJECT_ID= v_PROJECT_ID);	
		
		if (@i >= 1) then 
			-- PLAN_REPAY_AMT到期后，为所欠全部金额
 			set @t_PLAN_END_DATE  = last_day(date_add(v_ENDDATE,interval @i month));
			
			set @paid_rent = ifnull(( SELECT sum(PAID_PRIN_AMT+PAID_INT_AMT)  FROM tmp_repay_instmnt WHERE PROJECT_ID= v_PROJECT_ID and REPAY_DATE<=@t_PLAN_END_DATE), 0);
			set @except_amt = @total_rent - @paid_rent;	-- 本次期望
		
		
			INSERT INTO tmp_repay_plan_till_now
				(PROJECT_ID, PERIOD, REPAYMENT_DATE, PLAN_START_DATE, PLAN_END_DATE,
				EXPECTED_AMT,  PLAN_STATUS, OVERDUE_DAYS)
				(SELECT PROJECT_ID, (PERIOD+@i) as PERIOD, 
				last_day(date_add(v_ENDDATE,interval @i month)) as REPAYMENT_DATE,
				v_ENDDATE as PLAN_START_DATE, 
				@t_PLAN_END_DATE, -- last_day(date_add(v_ENDDATE,interval @i month)) as PLAN_END_DATE,
				@except_amt, PLAN_STATUS, 0 
				FROM tmp_repay_plan_till_now 
				WHERE PROJECT_ID= v_PROJECT_ID AND  PERIOD = v_PERIOD);
			
-- 			UPDATE tmp_overdue set PLAN_REPAY_AMT = @except_amt where ProjectID= v_PROJECT_ID and Peroid= (v_PERIOD+@i);
			
-- 			INSERT INTO tmp_repay_plan_till_now_1
-- 				(PROJECT_ID, PERIOD, REPAYMENT_DATE, PLAN_START_DATE, PLAN_END_DATE,
-- 				EXPECTED_AMT,  PLAN_STATUS, OVERDUE_DAYS)
-- 				(SELECT PROJECT_ID, (PERIOD+@i) as PERIOD, 
-- 				last_day(date_add(v_ENDDATE,interval @i month)) as REPAYMENT_DATE, 
-- 				v_ENDDATE, 0, PLAN_STATUS, OVERDUE_DAYS 
-- 				FROM tmp_repay_plan_till_now 
-- 				WHERE PROJECT_ID= v_PROJECT_ID AND  PERIOD = v_PERIOD);
			set @i=@i+1;
		end if;
	
	 	while (@i <= v_month_diff) Do -- 循环开始
	 		set @next_date = date_add(v_ENDDATE,interval @i month);
	 	
	 		set @t_PLAN_END_DATE  = last_day(date_add(v_ENDDATE,interval @i month));
			
			set @paid_rent = ifnull(( SELECT sum(PAID_PRIN_AMT+PAID_INT_AMT)  FROM tmp_repay_instmnt WHERE PROJECT_ID= v_PROJECT_ID and REPAY_DATE<=@t_PLAN_END_DATE), 0);
			set @except_amt = @total_rent - @paid_rent;	-- 本次期望
	 	
	 		INSERT INTO tmp_repay_plan_till_now
			(PROJECT_ID, PERIOD, REPAYMENT_DATE, PLAN_START_DATE, PLAN_END_DATE,
			EXPECTED_AMT,  PLAN_STATUS, OVERDUE_DAYS)
			(SELECT PROJECT_ID, (PERIOD+@i) as PERIOD, 
			last_day(date_add(v_ENDDATE,interval @i month)) as REPAYMENT_DATE, 
			date_add(@next_date, interval - day(@next_date) + 1 day) as PLAN_START_DATE,
			last_day(date_add(v_ENDDATE,interval @i month)) as PLAN_END_DATE,			
			@except_amt, PLAN_STATUS, 0 
			FROM tmp_repay_plan_till_now 
			WHERE PROJECT_ID= v_PROJECT_ID AND  PERIOD = v_PERIOD);
		
-- 			UPDATE tmp_overdue set PLAN_REPAY_AMT = @except_amt where ProjectID= v_PROJECT_ID and Peroid= (v_PERIOD+@i);
		
-- 			INSERT INTO tmp_repay_plan_till_now_1
-- 			(PROJECT_ID, PERIOD, REPAYMENT_DATE, PLAN_START_DATE,
-- 			EXPECTED_AMT,  PLAN_STATUS, OVERDUE_DAYS)
-- 			(SELECT PROJECT_ID, (PERIOD+@i) as PERIOD, 
-- 			last_day(date_add(v_ENDDATE,interval @i month)) as REPAYMENT_DATE, 
-- 			date_add(@next_date, interval - day(@next_date) + 1 day),
-- 			0, PLAN_STATUS, OVERDUE_DAYS 
-- 			FROM tmp_repay_plan_till_now 
-- 			WHERE PROJECT_ID= v_PROJECT_ID AND  PERIOD = v_PERIOD);

	 	
	       set @i=@i+1;
    	end while; -- 循环结束


	END LOOP read_loop;
    CLOSE cur; 

END