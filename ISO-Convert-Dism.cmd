@echo off
setlocal EnableDelayedExpansion
title Windows ISO ת�� ESD
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
echo �������ճ�� ISO �����ļ�������·��
echo �� �ļ�·����������ڿո񣬲�����������""��
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
echo �ڵ�ǰ��Ŀ¼���ҵ��� ISO �ļ���������һ��
echo �������ʹ�á�Tab����������ѡ��
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
echo ���ڽ�ѹ ISO �ļ�����
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
echo ���ڲ���װ���񲼾֡���
echo ============================================================
echo.
Dism /Capture-Image /ImageFile:"temp\ESDFILE.esd" /CaptureDir:"temp\ISOFOLDER" /Name:"Windows Setup Media" /Description:"Windows Setup Media" /ConfigFile:"temp\wimscript.ini" /Compress:max
SET ERRORTEMP=%ERRORLEVEL%
IF %ERRORTEMP% NEQ 0 (echo.&echo �ڲ���ӳ���ʱ����ִ���&PAUSE&GOTO :QUIT)
Dism /Export-Image /SourceImageFile:"temp\ESDFILE.esd" /SourceIndex:1 /DestinationImageFile:"ESDFILE.esd" /Compress:recovery
SET ERRORTEMP=%ERRORLEVEL%
IF %ERRORTEMP% NEQ 0 (echo.&echo �ڵ���ӳ���ʱ����ִ���&PAUSE&GOTO :QUIT)
echo.
echo ============================================================
echo ���ڵ��� boot.wim �ļ�����
echo ============================================================
echo.
for /f "tokens=2 delims=: " %%# in ('Dism /English /Get-ImageInfo /ImageFile:"temp\ISOFOLDER\sources\boot.wim" ^| findstr /c:"Index"') do set imgs=%%#
for /L %%# in (1,1,%imgs%) do Dism /Export-Image /SourceImageFile:"temp\ISOFOLDER\sources\boot.wim" /SourceIndex:%%# /DestinationImageFile:"ESDFILE.esd" /Compress:recovery
SET ERRORTEMP=%ERRORLEVEL%
IF %ERRORTEMP% NEQ 0 (echo.&echo �ڵ���ӳ���ʱ����ִ���&PAUSE&GOTO :QUIT)
echo.
echo ============================================================
echo ���ڵ��� %WIMFILE% �ļ�����
echo ============================================================
echo.
for /f "tokens=2 delims=: " %%# in ('Dism /English /Get-ImageInfo /ImageFile:"temp\ISOFOLDER\sources\%WIMFILE%" ^| findstr /c:"Index"') do set imgs=%%#
for /L %%# in (1,1,%imgs%) do Dism /Export-Image /SourceImageFile:"temp\ISOFOLDER\sources\%WIMFILE%" /SourceIndex:%%# /DestinationImageFile:"ESDFILE.esd" /Compress:recovery
SET ERRORTEMP=%ERRORLEVEL%
IF %ERRORTEMP% NEQ 0 (echo.&echo �ڵ���ӳ���ʱ����ִ���&PAUSE&GOTO :QUIT)
echo.
echo ============================================================
echo �����Ҫ��Ĳ�����
echo ============================================================
ren ESDFILE.esd %ESDFILE%
rmdir /s /q temp\
echo.
echo �밴������˳��ű���
pause >nul
GOTO :QUIT

:E_Admin
echo ========== ���� =========
echo �˽ű���Ҫ�Թ���ԱȨ�����С�
echo ��Ҫ����ִ�У����ڽű����Ҽ�������ѡ���Թ���ԱȨ�����С���
echo.
echo �밴������˳��ű���
pause >nul
exit /b

:QUIT
IF EXIST temp\ rmdir /s /q temp\
exit