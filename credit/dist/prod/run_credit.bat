echo off

01CALL_PROC.exe && 02BUILD24STATE.exe && 03RETURN_PROJECT && 06LOAN_DETAIL.exe && 08SPEC_EVENT.exe

REM 01CALL_PROC.exe && 02BUILD24STATE.exe && 03PRJ2APPLY.exe && 04ADDRESS.exe && 04IDENTITY.exe && 04LOAN_DETAIL.exe && 04OCCUPATION.exe && 04SPEC_EVENT.exe

REM echo "执行存储过程中... "
REM start "01CALL_PROC\call_process.exe"

REM echo "生成24个月状态中..."
REM start "02BUILD24STATE\MONTH_24_STAT.exe"

REM echo "copy逾期项目..."
REM start "03PRJ2APPLY\mysql2mysql.exe"
REM echo "居住地址段..."
REM start "04ADDRESS\mysql2mssql.exe"
REM echo "身份信息段..."
REM start "04IDENTITY\mysql2mssql.exe"
REM echo "基础信息段..."
REM start "04LOAN_DETAIL\mysql2mssql.exe"
REM echo "职业信息段..."
REM start "04OCCUPATION\mysql2mssql.exe"
REM echo "特殊交易段..."
REM start "04SPEC_EVENT\mysql2mssql.exe"
REM echo "完成"




