CREATE DEFINER=`root`@`%` PROCEDURE `small_core`.`sp_over_30_180`()
BEGIN
	
	
	DECLARE v_PROJECT_ID varchar(64); 
    DECLARE v_PERIOD INT(11); 
    DECLARE v_day_count INT(11); 
    DECLARE v_PLAN_REPAY_DT varchar(10); 
    DECLARE v_CUR_OVERDUE_TOTAL_INT INT(11); 
   	DECLARE v_PRI INT(11); 
   	DECLARE v_START_DT varchar(10); 
  	DECLARE v_END_DT varchar(10); 
  
   	DECLARE v_PAID_30 INT(11);  
   	DECLARE v_PAID_60 INT(11);  
  	DECLARE v_PAID_90 INT(11);  
 	DECLARE v_PAID_180 INT(11); 
 	DECLARE v_PAID_all INT(11); 
 	
 
	DECLARE v_month_diff INT(11);
	DECLARE done INT DEFAULT 0; 
    

	-- 1. 找出逾期天数已经超过31天的项目和期（实际上，最后一期之后的因为当期本金为0，无实际意义，但不好挑出来，不一并计算
	DECLARE cur CURSOR FOR (
		SELECT aa.ProjectID, aa.Peroid, aa.over_day_count, aa.PLAN_REPAY_DT, aa.CUR_OVERDUE_TOTAL_INT, bb.RECEIPT_AMOUNT_IT FROM 
			tmp_overdue aa, tmp_project_period_prin bb
		WHERE 
			aa.ProjectID = bb.PROJECT_ID
			and aa.Peroid = bb.PERIOD
			and aa.CUR_OVERDUE_TOTAL_INT > 1 -- aa.over_day_count >= 31
		GROUP by ProjectID , Peroid
	);

	DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1; 

    OPEN cur;
    read_loop:LOOP 
        FETCH cur INTO v_PROJECT_ID, v_PERIOD, v_day_count, v_PLAN_REPAY_DT, v_CUR_OVERDUE_TOTAL_INT, v_PRI; 
        IF done = 1 THEN 
            LEAVE read_loop; 
        END IF; 

   	-- 计算期间还本金
   	-- 逾期 30天内还的
-- 	set v_PAID_30 = ifnull( (SELECT sum(PAID_PRIN_AMT) 
-- 	       					from tmp_repay_instmnt 
-- 	       					WHERE PROJECT_ID = v_PROJECT_ID  and PERIOD = v_PERIOD
-- 	       					AND REPAY_DATE < DATE_FORMAT(date_add(v_PLAN_REPAY_DT, interval 31 DAY ),'%Y%m%d')), 0);
	       	-- 逾期60天内还的
	set v_PAID_60 = ifnull( (SELECT sum(PAID_PRIN_AMT) 
   					from tmp_repay_instmnt 
   					WHERE PROJECT_ID = v_PROJECT_ID  and PERIOD = v_PERIOD-1
   					AND REPAY_DATE < DATE_FORMAT( v_PLAN_REPAY_DT, '%Y%m%d')),  --  date_add(v_PLAN_REPAY_DT, interval 61 DAY ),'%Y%m%d')), 
   				0);
   	set v_PAID_90 = ifnull( (SELECT sum(PAID_PRIN_AMT) 
   					from tmp_repay_instmnt 
   					WHERE PROJECT_ID = v_PROJECT_ID  and PERIOD = v_PERIOD-2
   					AND REPAY_DATE < DATE_FORMAT( v_PLAN_REPAY_DT, '%Y%m%d')),  -- DATE_FORMAT(date_add(v_PLAN_REPAY_DT, interval 91 DAY ),'%Y%m%d')), 0);
   				0);
   	set v_PAID_180 = ifnull( (SELECT sum(PAID_PRIN_AMT) 
   					from tmp_repay_instmnt 
   					WHERE PROJECT_ID = v_PROJECT_ID  and PERIOD in( v_PERIOD-5, v_PERIOD-3, v_PERIOD-4)
   					AND REPAY_DATE < DATE_FORMAT( v_PLAN_REPAY_DT, '%Y%m%d')),  --  DATE_FORMAT(date_add(v_PLAN_REPAY_DT, interval 181 DAY ),'%Y%m%d')), 0);
   				0);
   	set v_PAID_all = ifnull( (SELECT sum(PAID_PRIN_AMT) 
   					from tmp_repay_instmnt 
   					WHERE PROJECT_ID = v_PROJECT_ID  and PERIOD < v_PERIOD-5
   					AND REPAY_DATE < DATE_FORMAT( v_PLAN_REPAY_DT, '%Y%m%d')),
   					 0);
   					
   					
     set @v_2_PRI = (SELECT SUM( RECEIPT_AMOUNT_IT ) FROM 
			tmp_project_period_prin 
			WHERE 
				v_PROJECT_ID = PROJECT_ID
				and PERIOD = v_PERIOD-1);
     set @v_3_PRI = (SELECT SUM( RECEIPT_AMOUNT_IT ) FROM 
			tmp_project_period_prin 
			WHERE 
				v_PROJECT_ID = PROJECT_ID
				and PERIOD = v_PERIOD-2);
	-- 超90天的，本金是90-180 
     set @v_456_PRI = (SELECT SUM( RECEIPT_AMOUNT_IT ) FROM 
			tmp_project_period_prin 
			WHERE 
				v_PROJECT_ID = PROJECT_ID
				and PERIOD in( v_PERIOD-5, v_PERIOD-3, v_PERIOD-4));
     set @v_7_PRI = (SELECT SUM( RECEIPT_AMOUNT_IT ) FROM 
			tmp_project_period_prin 
			WHERE 
				v_PROJECT_ID = PROJECT_ID
				and PERIOD < v_PERIOD-5);

	       				
   	if v_CUR_OVERDUE_TOTAL_INT = 2 then
   		-- [31, 60]
   		
   		UPDATE tmp_overdue SET
   			OVERDUE31_60DAYS_AMT 	= @v_2_PRI - v_PAID_60
   			-- OVERDUE61_90DAYS_AMT 	= v_PRI - v_PAID_90,
   			-- OVERDUE91_180DAYS_AMT 	= v_PRI - v_PAID_180,
   			-- OVERDUE_180DAYS_AMT  	= v_PRI - v_PAID_all
		where ProjectID = v_PROJECT_ID and Peroid = v_PERIOD;
	elseif v_CUR_OVERDUE_TOTAL_INT = 3 then
		-- [61, 90]
		UPDATE tmp_overdue SET
   			OVERDUE31_60DAYS_AMT 	= @v_2_PRI - v_PAID_60,
			OVERDUE61_90DAYS_AMT 	= @v_3_PRI - v_PAID_90
   			-- OVERDUE91_180DAYS_AMT 	= v_PRI - v_PAID_180,
   			-- OVERDUE_180DAYS_AMT  	= v_PRI - v_PAID_all
		where ProjectID = v_PROJECT_ID and Peroid = v_PERIOD;
		
	elseif (v_CUR_OVERDUE_TOTAL_INT = 4) or  (v_CUR_OVERDUE_TOTAL_INT = 5) or  (v_CUR_OVERDUE_TOTAL_INT = 6)  then
		-- [91, 120][121, 150][151, 180]
		
		-- 超90天的，本金是90-180   	
-- 		set @v_v_PRI = (SELECT SUM( RECEIPT_AMOUNT_IT ) FROM 
-- 			tmp_project_period_prin 
-- 			WHERE 
-- 				v_PROJECT_ID = PROJECT_ID
-- 				and PERIOD in( v_PERIOD-5, v_PERIOD-3, v_PERIOD-4));
			
			UPDATE tmp_overdue SET
	   			OVERDUE31_60DAYS_AMT 	= @v_2_PRI - v_PAID_60,
				OVERDUE61_90DAYS_AMT 	= @v_3_PRI - v_PAID_90,
				OVERDUE91_180DAYS_AMT 	= @v_456_PRI - v_PAID_180
	   			-- OVERDUE_180DAYS_AMT  	= v_PRI - v_PAID_all
			where ProjectID = v_PROJECT_ID and Peroid = v_PERIOD;

	elseif v_CUR_OVERDUE_TOTAL_INT >= 7 then
	   	-- [181, s)
-- 	   	set @v_v_PRI = (SELECT SUM( RECEIPT_AMOUNT_IT ) FROM 
-- 			tmp_project_period_prin 
-- 			WHERE 
-- 				v_PROJECT_ID = PROJECT_ID
-- 				and PERIOD in( v_PERIOD-5, v_PERIOD-3, v_PERIOD-4));
-- 			
-- 		set @v_v_v_PRI = (SELECT SUM( RECEIPT_AMOUNT_IT ) FROM 
-- 			tmp_project_period_prin 
-- 			WHERE 
-- 				v_PROJECT_ID = PROJECT_ID
-- 				and PERIOD < v_PERIOD-5);
		
   		UPDATE tmp_overdue SET
   			OVERDUE31_60DAYS_AMT 	= @v_2_PRI - v_PAID_60,
			OVERDUE61_90DAYS_AMT 	= @v_3_PRI - v_PAID_90,
			OVERDUE91_180DAYS_AMT 	= @v_456_PRI - v_PAID_180,
			OVERDUE_180DAYS_AMT  	= @v_7_PRI - v_PAID_all
		where ProjectID = v_PROJECT_ID and Peroid  < v_PERIOD-5;
   	end if;
	       				

	END LOOP read_loop;
    CLOSE cur; 
END