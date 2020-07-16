CREATE OR REPLACE
ALGORITHM = UNDEFINED VIEW `small_core`.`V_CREDIT_SPEC_EVENT` AS
select
    `ao`.`LEASE_CONTRACT_NO` AS `BUSINESS_NO`,
    'M10154210H0001' AS `FINORGCODE`,
    5 AS `SPEC_EVENT_CD`,
    `rid`.`REPAY_DATE` AS `OCCURDATE`,
    0 AS `EXTENT_MONTHS`,
    `rld`.`FEE_AMT` AS `EVENT_AMT`,
    '' AS `EVENT_DTL`
from
    ((`small_core`.`APPLY_ORDER` `ao`
join `small_core`.`REPAY_INSTMNT_DETAIL` `rid`)
join `small_core`.`REPAY_LOAN_DETAIL` `rld`)
where
    ((`ao`.`APPLY_STATUS` = 12)
    and (`ao`.`APPLY_NO` = `rid`.`APPLY_NO`)
    and (`rid`.`REPAY_AMT_TYPE` = '02')
    and (`rid`.`SEQ_NO` = `rld`.`SEQ_NO`)
    and `rid`.`APPLY_NO` in (
    select
        `small_core`.`tmp_overdue_projects`.`PROJECT_ID`
    from
        `small_core`.`tmp_overdue_projects`))
union
select
    `small_core`.`RETURN_PROJECT_DETAIL`.`JXFL_CONTRACT_NO` AS `BUSINESS_NO`,
    'M10154210H0001' AS `FINORGCODE`,
    2 AS `SPEC_EVENT_CD`,
    `small_core`.`RETURN_PROJECT_DETAIL`.`REPAY_DATE` AS `OCCURDATE`,
    0 AS `EXTENT_MONTHS`,
    `small_core`.`RETURN_PROJECT_DETAIL`.`REPAY_AMT` AS `EVENT_AMT`,
    '' AS `EVENT_DTL`
from
    `small_core`.`RETURN_PROJECT_DETAIL`
where
    ((`small_core`.`RETURN_PROJECT_DETAIL`.`REPAY_AMT_TYPE` = '07')
    and `small_core`.`RETURN_PROJECT_DETAIL`.`APPLY_NO` in (
    select
        `small_core`.`tmp_RETURN`.`ProjectID`
    from
        `small_core`.`tmp_RETURN`))