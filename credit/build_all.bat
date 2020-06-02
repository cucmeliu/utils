echo off
echo "------------------------"
echo "build start"

echo "------------------------"
echo "del *.exe under dist"
del dist\*.exe
del dist\*.bat
copy run_credit.bat dist\

echo 
echo "------------------------"
echo "building call_process..."
pyinstaller -F call_process.py
ren dist\call_process.exe 01CALL_PROC.exe

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
copy dist\mysql2mssql.exe dist\04IDENTITY.exe
copy dist\mysql2mssql.exe dist\04LOAN_DETAIL.exe
copy dist\mysql2mssql.exe dist\04OCCUPATION.exe
ren dist\mysql2mssql.exe 04SPEC_EVENT.exe


echo " "
echo "------------------------"
echo "build done!"
echo "------------------------"
echo " "

