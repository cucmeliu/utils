REM run credit.bat

echo "执行存储过程中... "
REM start "01CALL_PROC\call_process.exe"

echo "生成24个月状态中..."
start "02BUILD24STATE\MONTH_24_STAT.exe"

echo "copy逾期项目..."
start "03PRJ2APPLY\mysql2mysql.exe"
echo "居住地址段..."
start "04ADDRESS\mysql2mssql.exe"
echo "身份信息段..."
start "04IDENTITY\mysql2mssql.exe"
echo "基础信息段..."
start "04LOAN_DETAIL\mysql2mssql.exe"
echo "职业信息段..."
start "04OCCUPATION\mysql2mssql.exe"
echo "特殊交易段..."
REM start "04SPEC_EVENT\mysql2mssql.exe"
echo "完成"




