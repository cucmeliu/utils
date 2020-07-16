CREATE OR REPLACE
ALGORITHM = UNDEFINED VIEW `small_core`.`V_CREDIT_LOAN_DETAIL` AS
select
    `small_core`.`tmp_overdue`.`FINORGCODE` AS `FINORGCODE`,
    `small_core`.`tmp_overdue`.`LOANTYPE` AS `LOANTYPE`,
    `small_core`.`tmp_overdue`.`LOANBIZTYPE` AS `LOANBIZTYPE`,
    `small_core`.`tmp_overdue`.`BUSINESS_NO` AS `BUSINESS_NO`,
    `small_core`.`tmp_overdue`.`AREACODE` AS `AREACODE`,
    `small_core`.`tmp_overdue`.`STARTDATE` AS `STARTDATE`,
    `small_core`.`tmp_overdue`.`ENDDATE` AS `ENDDATE`,
    `small_core`.`tmp_overdue`.`CURRENCY` AS `CURRENCY`,
    `small_core`.`tmp_overdue`.`CREDIT_TOTAL_AMT` AS `CREDIT_TOTAL_AMT`,
    `small_core`.`tmp_overdue`.`SHARE_CREDIT_TOTAL_AMT` AS `SHARE_CREDIT_TOTAL_AMT`,
    `small_core`.`tmp_overdue`.`MAX_DEBT_AMT` AS `MAX_DEBT_AMT`,
    `small_core`.`tmp_overdue`.`GUARANTEEFORM` AS `GUARANTEEFORM`,
    `small_core`.`tmp_overdue`.`PAYMENT_RATE` AS `PAYMENT_RATE`,
    `small_core`.`tmp_overdue`.`PAYMENT_MONTHS` AS `PAYMENT_MONTHS`,
    `small_core`.`tmp_overdue`.`NO_PAYMENT_MONTHS` AS `NO_PAYMENT_MONTHS`,
    `small_core`.`tmp_overdue`.`PLAN_REPAY_DT` AS `PLAN_REPAY_DT`,
    `small_core`.`tmp_overdue`.`LAST_REPAY_DT` AS `LAST_REPAY_DT`,
    `small_core`.`tmp_overdue`.`PLAN_REPAY_AMT` AS `PLAN_REPAY_AMT`,
    `small_core`.`tmp_overdue`.`LAST_REPAY_AMT` AS `LAST_REPAY_AMT`,
    `small_core`.`tmp_overdue`.`BALANCE` AS `BALANCE`,
    `small_core`.`tmp_overdue`.`CUR_OVERDUE_TOTAL_INT` AS `CUR_OVERDUE_TOTAL_INT`,
    `small_core`.`tmp_overdue`.`CUR_OVERDUE_TOTAL_AMT` AS `CUR_OVERDUE_TOTAL_AMT`,
    `small_core`.`tmp_overdue`.`OVERDUE31_60DAYS_AMT` AS `OVERDUE31_60DAYS_AMT`,
    `small_core`.`tmp_overdue`.`OVERDUE61_90DAYS_AMT` AS `OVERDUE61_90DAYS_AMT`,
    `small_core`.`tmp_overdue`.`OVERDUE91_180DAYS_AMT` AS `OVERDUE91_180DAYS_AMT`,
    `small_core`.`tmp_overdue`.`OVERDUE_180DAYS_AMT` AS `OVERDUE_180DAYS_AMT`,
    `small_core`.`tmp_overdue`.`SUM_OVERDUE_INT` AS `SUM_OVERDUE_INT`,
    `small_core`.`tmp_overdue`.`MAX_OVERDUE_INT` AS `MAX_OVERDUE_INT`,
    `small_core`.`tmp_overdue`.`CLASSIFY5` AS `CLASSIFY5`,
    `small_core`.`tmp_overdue`.`LOAN_STAT` AS `LOAN_STAT`,
    `small_core`.`tmp_overdue`.`REPAY_MONTH_24_STAT` AS `REPAY_MONTH_24_STAT`,
    `small_core`.`tmp_overdue`.`OVERDRAFT_180DAYS_BAL` AS `OVERDRAFT_180DAYS_BAL`,
    `small_core`.`tmp_overdue`.`LOAN_ACCOUNT_STAT` AS `LOAN_ACCOUNT_STAT`,
    `small_core`.`tmp_overdue`.`CUSTNAME` AS `CUSTNAME`,
    `small_core`.`tmp_overdue`.`CERTTYPE` AS `CERTTYPE`,
    `small_core`.`tmp_overdue`.`CERTNO` AS `CERTNO`,
    `small_core`.`tmp_overdue`.`CUSTID` AS `CUSTID`,
    `small_core`.`tmp_overdue`.`BAKE` AS `BAKE`
from
    `small_core`.`tmp_overdue`
where
    (((`small_core`.`tmp_overdue`.`ProjectID`, `small_core`.`tmp_overdue`.`PLAN_REPAY_DT`) not in (
    select
        `x`.`ProjectID`, `x`.`PLAN_REPAY_DT`
    from
        `small_core`.`t_his_credit` `x`
    group by
        `x`.`ProjectID`)))
order by
    `small_core`.`tmp_overdue`.`ProjectID`,
    `small_core`.`tmp_overdue`.`Peroid`