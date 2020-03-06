rem 当我们需要删除test目录的时候，就这么执行 "deltree.bat d:\test"（不包含引号）。

attrib -s -h -r %1\*.* && del %1\*.* /q
dir %1 /ad /b /s >del.txt 
for /f %%i in (del.txt) do rd %%i /s /q 
