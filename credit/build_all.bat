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
echo "building c01call_process..."
pyinstaller -F c01call_process.py
REM sp_gen_credit
copy dist\c01call_process.exe dist\01GEN_CREDIT.exe
REM sp_return_project
copy dist\c01call_process.exe dist\03RETURN_PROJECT.exe
REM sp_credit_wind_up
ren dist\c01call_process.exe 10CREDIT_WIND_UP.exe

echo " "
echo "------------------------"
echo "building c02build_24_state..."
pyinstaller -F c02build_24_state.py
ren dist\c02build_24_state.exe 02BUILD24STATE.exe

echo " "
echo "------------------------"
echo "building c03mysql2mysql..."
pyinstaller -F c03mysql2mysql.py
ren dist\c03mysql2mysql.exe 04PRJ2APPLY.exe

echo " "
echo "------------------------"
echo "building c04mysql2mssql..."
pyinstaller -F c04mysql2mssql.py

copy dist\c04mysql2mssql.exe dist\05ADDRESS.exe
copy dist\c04mysql2mssql.exe dist\06IDENTITY.exe
copy dist\c04mysql2mssql.exe dist\07OCCUPATION.exe
copy dist\c04mysql2mssql.exe dist\08LOAN_DETAIL.exe
ren dist\c04mysql2mssql.exe 09SPEC_EVENT.exe


echo " "
echo "------------------------"
echo "build done!"
echo "------------------------"
echo " "

