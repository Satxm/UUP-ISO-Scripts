@echo off
setlocal EnableDelayedExpansion
title Windows ISO 转换 ESD
set "SysPath=%SystemRoot%\System32"
set "Path=%~dp0bin;%~dp0temp;%SysPath%;%SystemRoot%;%SysPath%\Wbem;%SysPath%\WindowsPowerShell\v1.0\;%LocalAppData%\Microsoft\WindowsApps\"
if exist "%SystemRoot%\Sysnative\reg.exe" (
    set "SysPath=%SystemRoot%\Sysnative"
    set "Path=%~dp0bin;%~dp0temp;%SystemRoot%\Sysnative;%SystemRoot%\Sysnative\Wbem;%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\;%LocalAppData%\Microsoft\WindowsApps\;%Path%"
)
set "_psc=powershell -nop -c"
set "_args="
set "_args=%~1"
cd /d "%~dp0"

set _uac=-elevated
1>nul 2>nul reg.exe query HKU\S-1-5-19 && goto :Passed

set _PSarg="""%~f0""" %_uac%
if defined _args set _PSarg="""%~f0""" %_args:"="""% %_uac%
set _PSarg=%_PSarg:'=''%

call setlocal EnableDelayedExpansion
for %%# in (wt.exe) do @if "%%~$PATH:#"=="" %_Null% %_psc% "start cmd.exe -arg '/c !_PSarg!' -verb runas" && exit /b || goto :E_Admin
%_Null% %_psc% "start wt -arg '!_PSarg!' -verb runas" && exit /b || goto :E_Admin


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
IF EXIST temp\ rmdir /s /q temp\
bin\7z.exe x "%ISOFILE%" -otemp\ISOFOLDER * -r >nul
if not exist temp\ISOFOLDER\sources\boot.wim goto :QUIT
if exist temp\ISOFOLDER\sources\install.esd (set WIMFILE=install.esd) else (set WIMFILE=install.wim)
type nul>temp\wimscript.ini
>>temp\wimscript.ini echo [ExclusionList]
>>temp\wimscript.ini echo ^\sources^\boot.wim
>>temp\wimscript.ini echo ^\sources^\%WIMFILE%
echo.
echo ============================================================
echo 正在捕获安装镜像布局……
echo ============================================================
echo.
Dism /Capture-Image /ImageFile:"temp\ESDFILE.esd" /CaptureDir:"temp\ISOFOLDER" /Name:"Windows Setup Media" /Description:"Windows Setup Media" /ConfigFile:"temp\wimscript.ini" /Compress:max
SET ERRORTEMP=%ERRORLEVEL%
IF %ERRORTEMP% NEQ 0 (echo.&echo 在捕获映像的时候出现错误。&PAUSE&GOTO :QUIT)
Dism /Export-Image /SourceImageFile:"temp\ESDFILE.esd" /SourceIndex:1 /DestinationImageFile:"ESDFILE.esd" /Compress:recovery
SET ERRORTEMP=%ERRORLEVEL%
IF %ERRORTEMP% NEQ 0 (echo.&echo 在导出映像的时候出现错误。&PAUSE&GOTO :QUIT)
echo.
echo ============================================================
echo 正在导出 boot.wim 文件……
echo ============================================================
echo.
for /f "tokens=2 delims=: " %%# in ('Dism /English /Get-ImageInfo /ImageFile:"temp\ISOFOLDER\sources\boot.wim" ^| findstr /c:"Index"') do set imgs=%%#
for /L %%# in (1,1,%imgs%) do Dism /Export-Image /SourceImageFile:"temp\ISOFOLDER\sources\boot.wim" /SourceIndex:%%# /DestinationImageFile:"ESDFILE.esd" /Compress:recovery
SET ERRORTEMP=%ERRORLEVEL%
IF %ERRORTEMP% NEQ 0 (echo.&echo 在导出映像的时候出现错误。&PAUSE&GOTO :QUIT)
echo.
echo ============================================================
echo 正在导出 %WIMFILE% 文件……
echo ============================================================
echo.
for /f "tokens=2 delims=: " %%# in ('Dism /English /Get-ImageInfo /ImageFile:"temp\ISOFOLDER\sources\%WIMFILE%" ^| findstr /c:"Index"') do set imgs=%%#
for /L %%# in (1,1,%imgs%) do Dism /Export-Image /SourceImageFile:"temp\ISOFOLDER\sources\%WIMFILE%" /SourceIndex:%%# /DestinationImageFile:"ESDFILE.esd" /Compress:recovery
SET ERRORTEMP=%ERRORLEVEL%
IF %ERRORTEMP% NEQ 0 (echo.&echo 在导出映像的时候出现错误。&PAUSE&GOTO :QUIT)
echo.
echo ============================================================
echo 已完成要求的操作。
echo ============================================================
ren ESDFILE.esd %ESDFILE%
rmdir /s /q temp\
echo.
echo 请按任意键退出脚本。
pause >nul
GOTO :QUIT

:E_Admin
echo ========== 错误 =========
echo 此脚本需要以管理员权限运行。
echo 若要继续执行，请在脚本上右键单击并选择“以管理员权限运行”。
echo.
echo 请按任意键退出脚本。
pause >nul
exit /b

:QUIT
IF EXIST temp\ rmdir /s /q temp\
exit