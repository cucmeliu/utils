echo off
echo "------------------------"
echo "build start"

echo "------------------------"
echo "del *.exe *.bat *.yaml under dist"
del dist\*.exe
del dist\*.bat
del dist\*.yaml

echo "copy *.exe *.bat *.yaml to dist"
copy run_credit.bat dist\
copy *.yaml dist\

echo 
echo "------------------------"
echo "building call_process..."
pyinstaller -F call_process.py
REM sp_gen_credit
copy dist\call_process.exe dist\01GEN_CREDIT.exe
REM sp_return_project
copy dist\call_process.exe dist\03RETURN_PROJECT.exe
REM sp_credit_wind_up
ren dist\call_process.exe 10CREDIT_WIND_UP.exe

echo " "
echo "------------------------"
echo "building MONTH_24_STAT..."
pyinstaller -F MONTH_24_STAT.py
ren dist\MONTH_24_STAT.exe 02BUILD24STATE.exe

echo " "
echo "------------------------"
echo "building mysql2mysql..."
pyinstaller -F mysql2mysql.py
ren dist\mysql2mysql.exe 03PRJ2APPLY.exe

echo " "
echo "------------------------"
echo "building mysql2mssql..."
pyinstaller -F mysql2mssql.py

copy dist\mysql2mssql.exe dist\04ADDRESS.exe
copy dist\mysql2mssql.exe dist\05IDENTITY.exe
copy dist\mysql2mssql.exe dist\06LOAN_DETAIL.exe
copy dist\mysql2mssql.exe dist\07OCCUPATION.exe
ren dist\mysql2mssql.exe 08SPEC_EVENT.exe


echo " "
echo "------------------------"
echo "build done!"
echo "------------------------"
echo " "

