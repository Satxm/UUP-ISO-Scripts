@setlocal DisableDelayedExpansion
@echo off
title 清理临时文件

for %%# in (powershell.exe) do @if "%%~$PATH:#"=="" echo 未找到 PowerShell，请右键点击“以管理员身份运行”
1>nul 2>nul reg.exe query HKU\S-1-5-19 || (
  for %%# in (wt.exe) do @if "%%~$PATH:#"=="" powershell "start cmd -arg '/c """%~f0"""' -verb runas" && exit /b || echo 请右键点击“以管理员身份运行”！
  powershell "start wt 'new-tab """%~f0"""' -verb runas" && exit /b || echo 请右键点击“以管理员身份运行”！
)

set "_work=%~dp0"
set "_work=%_work:~0,-1%"
set _drv=%~d0
set "_cabdir=%_drv%\Updates"
if "%_work:~0,2%"=="\\" set "_cabdir=%~dp0temp\Updates"

set "_Null=1>nul 2>nul"
reg.exe query HKU\S-1-5-19 %_Null% || (echo.&echo 此脚本需要以管理员权限运行。&goto :TheEnd)
set "_cmdf=%~f0"
if exist "%SystemRoot%\Sysnative\cmd.exe" (
setlocal EnableDelayedExpansion
start %SystemRoot%\Sysnative\cmd.exe /c ""!_cmdf!" "
exit /b
)
if exist "%SystemRoot%\SysArm32\cmd.exe" if /i %PROCESSOR_ARCHITECTURE%==AMD64 (
setlocal EnableDelayedExpansion
start %SystemRoot%\SysArm32\cmd.exe /c ""!_cmdf!" "
exit /b
)
set "SysPath=%SystemRoot%\System32"
if exist "%SystemRoot%\Sysnative\reg.exe" (set "SysPath=%SystemRoot%\Sysnative")
set "Path=%SysPath%;%SystemRoot%;%SysPath%\Wbem;%SysPath%\WindowsPowerShell\v1.0\"
set "xOS=%PROCESSOR_ARCHITECTURE%"
if /i %PROCESSOR_ARCHITECTURE%==x86 (if defined PROCESSOR_ARCHITEW6432 set "xOS=%PROCESSOR_ARCHITEW6432%")
set "_key=HKLM\SOFTWARE\Microsoft\WIMMount\Mounted Images"
set regKeyPathFound=1
set wowRegKeyPathFound=1
reg.exe query "HKLM\Software\Wow6432Node\Microsoft\Windows Kits\Installed Roots" /v KitsRoot10 %_Null% || set wowRegKeyPathFound=0
reg.exe query "HKLM\Software\Microsoft\Windows Kits\Installed Roots" /v KitsRoot10 %_Null% || set regKeyPathFound=0
if %wowRegKeyPathFound% equ 0 (
  if %regKeyPathFound% equ 0 (
    goto :ALL
  ) else (
    set regKeyPath=HKLM\Software\Microsoft\Windows Kits\Installed Roots
  )
) else (
    set regKeyPath=HKLM\Software\Wow6432Node\Microsoft\Windows Kits\Installed Roots
)
for /f "skip=2 tokens=2*" %%i in ('reg.exe query "%regKeyPath%" /v KitsRoot10') do set "KitsRoot=%%j"
set "DandIRoot=%KitsRoot%Assessment and Deployment Kit\Deployment Tools"
if exist "%DandIRoot%\%xOS%\DISM\dism.exe" (
set "Path=%DandIRoot%\%xOS%\DISM;%SysPath%;%SystemRoot%;%SysPath%\Wbem;%SysPath%\WindowsPowerShell\v1.0\"
cd \
)

:ALL
for /f "tokens=3*" %%a in ('reg.exe query "%_key%" /s /v "Mount Path" 2^>nul ^| findstr /i /c:"Mount Path"') do (set "_mount=%%b"&call :CLN)
dism.exe /Cleanup-Wim
dism.exe /Cleanup-Mountpoints
goto :TheEnd

:CLN
dism.exe /Image:"%_mount%" /Get-Packages %_Null%
dism.exe /Unmount-Wim /MountDir:"%_mount%" /Discard
if exist "%_mount%\" rmdir /s /q "%_mount%\" %_Null%
if exist "%_mount%" (
mkdir %_drv%\_del286 %_Null%
robocopy %_drv%\_del286 "%_mount%" /MIR /R:1 /W:1 /NFL /NDL /NP /NJH /NJS %_Null%
rmdir /s /q %_drv%\_del286\ %_Null%
rmdir /s /q "%_mount%" %_Null%
)
exit /b

:TheEnd
if exist "%_cabdir%\" (
  echo.
  echo 正在移除临时文件……
  echo.
  rmdir /s /q "%_cabdir%\" %_Null%
)
if exist "%_cabdir%\" (
  mkdir %_drv%\_del286 %_Null%
  robocopy %_drv%\_del286 "%_cabdir%" /MIR /R:1 /W:1 /NFL /NDL /NP /NJH /NJS %_Null%
  rmdir /s /q %_drv%\_del286\ %_Null%
  rmdir /s /q "%_cabdir%\" %_Null%
)
echo.
echo 请按任意键退出脚本。
pause >nul
goto :eof
