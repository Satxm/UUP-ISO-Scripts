@echo off
setlocal EnableDelayedExpansion
title Windows ISO 转换 ESD
if not exist "%~dp0bin\wimlib-imagex.exe" goto :eof
SET "wimlib=%~dp0bin\wimlib-imagex.exe"
set "_psc=powershell -nop -c"
cd /d "%~dp0"

set _uac=-elevated
1>nul 2>nul reg.exe query HKU\S-1-5-19 && goto :Passed

set _PSarg="""%~f0""" %_uac%
set _PSarg=%_PSarg:'=''%

for %%# in (wt.exe) do @if "%%~$PATH:#"=="" 1>nul 2>nul %_psc% "start cmd.exe -arg '/c \"!_PSarg!\"' -verb runas" && exit /b
1>nul 2>nul %_psc% "start wt -arg 'new-tab cmd /c \"!_PSarg!\"' -verb runas" && exit /b

:Passed
SET ISOFILE=
SET ESDFILE=
SET ERRORTEMP=

for %%# in (%*) do if exist "%%#" (echo %%#&set "ISOFILE=%~1"&set "ISOFILEN=%~nx1"&goto :check)
set _iso=0
if exist "*.iso" (for /f "delims=" %%i in ('dir /b "*.iso"') do (call set /a _iso+=1))
if !_iso! equ 0 goto :prompt1
if !_iso! gtr 1 goto :prompt2
for /f "delims=" %%i in ('dir /b "*.iso"') do (echo %%i&set "ISOFILE=%%i"&set "ISOFILEN=%%i"&goto :check)

:prompt1
echo.
echo ============================================================
echo 请输入或粘贴 ISO 镜像文件的完整路径
echo （ 文件路径中允许存在空格，不允许含有引号""）
echo ============================================================
echo.
set /p ISOFILE=
if [%ISOFILE%]==[] goto :QUIT
call :setvar "%ISOFILE%"
goto :check

:setvar
SET "ISOFILEN=%~nx1"
goto :eof

:prompt2
for /f "delims=" %%i in ('dir /b "*.iso"') do echo %%i
echo.
echo ============================================================
echo 在当前的目录下找到的 ISO 文件数量多于一个
echo 请输入或使用“Tab”键来进行选择
echo ============================================================
echo.
set /p ISOFILE=
if [%ISOFILE%]==[] goto :QUIT
SET "ISOFILEN=%ISOFILE%"
goto :check

:check
SET "ESDFILE=%ISOFILEN:~0,-4%.esd"

:ISO
%_psc% "Set-Date (Get-Item %ISOFILEN%).LastWriteTime" 1>nul 2>nul
echo.
echo ============================================================
echo 正在解压 ISO 文件……
echo ============================================================
echo.
IF EXIST .\temp\ rmdir /s /q .\temp\
bin\7z.exe x "%ISOFILE%" -o.\temp\ISOFOLDER * -r >nul
if not exist .\temp\ISOFOLDER\sources\boot.wim goto :QUIT
if exist .\temp\ISOFOLDER\sources\install.esd (set WIMFILE=install.esd) else (set WIMFILE=install.wim)
move /y .\temp\ISOFOLDER\sources\boot.wim .\temp >nul
move /y .\temp\ISOFOLDER\sources\%WIMFILE% .\temp >nul
echo.
echo ============================================================
echo 正在捕获安装镜像布局……
echo ============================================================
echo.
"%wimlib%" capture .\temp\ISOFOLDER ESDFILE.esd "Windows Setup Media" "Windows Setup Media" --compress=LZMS --solid --no-acls
SET ERRORTEMP=%ERRORLEVEL%
IF %ERRORTEMP% NEQ 0 (echo.&echo 在捕获映像的时候出现错误。&PAUSE&GOTO :QUIT)
echo.
echo ============================================================
echo 正在导出 boot.wim 文件……
echo ============================================================
echo.
"%wimlib%" export .\temp\boot.wim all ESDFILE.esd --compress=LZMS --solid
SET ERRORTEMP=%ERRORLEVEL%
IF %ERRORTEMP% NEQ 0 (echo.&echo 在导出映像的时候出现错误。&PAUSE&GOTO :QUIT)
echo.
echo ============================================================
echo 正在导出 %WIMFILE% 文件……
echo ============================================================
echo.
"%wimlib%" export .\temp\%WIMFILE% all ESDFILE.esd --compress=LZMS --solid
SET ERRORTEMP=%ERRORLEVEL%
IF %ERRORTEMP% NEQ 0 (echo.&echo 在导出映像的时候出现错误。&PAUSE&GOTO :QUIT)
echo.
echo ============================================================
echo 已完成要求的操作。
echo ============================================================
ren ESDFILE.esd %ESDFILE%
rmdir /s /q .\temp\
echo.
echo 请按任意键退出脚本。
pause >nul
GOTO :QUIT

:QUIT
IF EXIST .\temp\ rmdir /s /q .\temp\
exit