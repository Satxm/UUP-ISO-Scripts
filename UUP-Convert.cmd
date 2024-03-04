@setlocal DisableDelayedExpansion
@set "uivr=v24.2-101"
@echo off

:: 若要启用调试模式，请将此参数更改为 1
set _Debug=0

:: 若将更新（如果检测到）集成到 install.wim/winre.wim 中，请将此参数更改为 1
set AddUpdates=0

:: 若要清理映像以增量压缩已取代的组件，请将此参数更改为 1（警告：在 18362 及以上版本中，这将会删除基础 RTM 版本程序包）
set Cleanup=0

:: 若要重置操作系统映像并移除已被更新取代的组件，请将此参数更改为 1（快于默认的增量压缩，需要首先设置参数 Cleanup=1）
set ResetBase=0

:: 若将 install.wim 转换为 install.esd，请将此参数更改为 1
set WIM2ESD=0

:: 若将 install.wim 拆分为 install.swm，请将此参数更改为 1
:: 注：如果两个选项均为 1，install.esd 将优先执行
set WIM2SWM=0

:: 若不需要创建 ISO 文件，保留原始文件夹，请将此参数更改为 1
set SkipISO=0

:: 若不添加 Winre.wim 到 install.wim，请将此参数更改为 1
set SkipWinRE=0

:: 若在即使检测到 SafeOS 更新的情况下，也强制使用累积更新来更新 winre.wim，请将此参数更改为 1
set LCUWinRE=0

:: 若不更新 ISO 引导文件 bootmgr/bootmgr.efi/efisys.bin，请将此参数更改为 1
set UpdtBootFiles=0

:: 更新OneDrive，请将此参数更改为 1
set UpdtOneDrive=0

:: 使用现有镜像升级 Windows 版本并保存，请将此参数更改为 1
set AddEdition=0

:: 升级或整合 Appx 软件，请将此参数更改为 1
set AddAppxs=0

:: 生成并使用 .msu 更新包（Windows 11），请将此参数更改为 1
set UseMSU=0

set "_Null=1>nul 2>nul"
set "FullExit=exit /b"

set "param=%~f0"
cmd /v:on /c echo(^^!param^^!| findstr /R "[| ` ~ ! @ %% \^ & ( ) \[ \] { } + = ; ' , |]*^"
if %errorlevel% EQU 0 (
echo.
echo ==== 出现错误 ====
echo 不允许在文件路径名中检测到特殊字符。
echo 请确保在路径中不包含以下所示的特殊字符
echo ^` ^~ ^! ^@ %% ^^ ^& ^( ^) [ ] { } ^+ ^= ^; ^' ^,
echo.
echo 请按任意键退出脚本。
pause >nul
goto :eof
)

set _elev=
set "_args="
set "_args=%~1"
if not defined _args goto :NoProgArgs
if "%~1"=="" set "_args="&goto :NoProgArgs
for %%# in (%*) do (
if /i "%%~#"=="-elevated" (set _elev=1
) else if /i not "%%~#"=="%~1" (set "_args=%_args% %%~#")
)

:NoProgArgs
set "xOS=amd64"
if /i "%PROCESSOR_ARCHITECTURE%"=="arm64" set "xOS=arm64"
if /i "%PROCESSOR_ARCHITECTURE%"=="x86" if "%PROCESSOR_ARCHITEW6432%"=="" set "xOS=x86"
if /i "%PROCESSOR_ARCHITEW6432%"=="amd64" set "xOS=amd64"
if /i "%PROCESSOR_ARCHITEW6432%"=="arm64" set "xOS=arm64"
set "SysPath=%SystemRoot%\System32"
set "Path=temp;bin;%SysPath%;%SystemRoot%;%SysPath%\Wbem;%SysPath%\WindowsPowerShell\v1.0\;%LocalAppData%\Microsoft\WindowsApps\"
if exist "%SystemRoot%\Sysnative\reg.exe" (
    set "SysPath=%SystemRoot%\Sysnative"
    set "Path=temp;bin;%SystemRoot%\Sysnative;%SystemRoot%\Sysnative\Wbem;%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\;%LocalAppData%\Microsoft\WindowsApps\;%Path%"
)
set "_err========== 错误 ========="
set "_psc=powershell -nop -c"
set winbuild=1
for /f "tokens=6 delims=[]. " %%# in ('ver') do set winbuild=%%#
set _cwmi=0
for %%# in (wmic.exe) do @if not "%%~$PATH:#"=="" (
    wmic path Win32_ComputerSystem get CreationClassName /value 2>nul | find /i "ComputerSystem" 1>nul && set _cwmi=1
)
set _pwsh=1
for %%# in (powershell.exe) do @if "%%~$PATH:#"=="" set _pwsh=0
if not exist "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" set _pwsh=0
2>nul %_psc% $ExecutionContext.SessionState.LanguageMode | find /i "Full" 1>nul || set _pwsh=0
if %_cwmi% equ 0 if %_pwsh% EQU 0 goto :E_PowerShell

set _uac=-elevated
%_Null% reg.exe query HKU\S-1-5-19 && goto :Passed || if defined _elev goto :E_Admin

set _PSarg="""%~f0""" %_uac%
if defined _args set _PSarg="""%~f0""" %_args:"="""% %_uac%
set _PSarg=%_PSarg:'=''%

call setlocal EnableDelayedExpansion
for %%# in (wt.exe) do @if "%%~$PATH:#"=="" %_Null% %_psc% "start cmd.exe -arg '/c \"!_PSarg!\"' -verb runas" && exit /b || goto :E_Admin
%_Null% %_psc% "start wt -arg 'new-tab cmd /c \"!_PSarg!\"' -verb runas" && exit /b || goto :E_Admin

:Passed
set "_log=%~dpn0"
set "_work=%~dp0"
set "_work=%_work:~0,-1%"
set _drv=%~d0
set "_cabdir=%_drv%\Updates"
if "%_work:~0,2%"=="\\" set "_cabdir=%~dp0temp\Updates"
for /f "skip=2 tokens=2*" %%a in ('reg.exe query "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" /v Desktop') do call set "_dsk=%%b"
if exist "%PUBLIC%\Desktop\desktop.ini" set "_dsk=%PUBLIC%\Desktop"
set psfnet=0
if exist "%SystemRoot%\Microsoft.NET\Framework\v4.0.30319\ngen.exe" set psfnet=1
if exist "%SystemRoot%\Microsoft.NET\Framework\v2.0.50727\ngen.exe" set psfnet=1
for %%# in (E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    set "_adr%%#=%%#"
)
if %_cwmi% equ 1 for /f "tokens=2 delims==:" %%# in ('"wmic path Win32_Volume where (DriveLetter is not NULL) get DriveLetter /value" ^| findstr ^=') do (
    if defined _adr%%# set "_adr%%#="
)
if %_cwmi% equ 1 for /f "tokens=2 delims==:" %%# in ('"wmic path Win32_LogicalDisk where (DeviceID is not NULL) get DeviceID /value" ^| findstr ^=') do (
    if defined _adr%%# set "_adr%%#="
)
if %_cwmi% equ 0 for /f "tokens=1 delims=:" %%# in ('powershell -nop -c "(([WMISEARCHER]'Select * from Win32_Volume where DriveLetter is not NULL').Get()).DriveLetter; (([WMISEARCHER]'Select * from Win32_LogicalDisk where DeviceID is not NULL').Get()).DeviceID"') do (
    if defined _adr%%# set "_adr%%#="
)
for %%# in (E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if not defined _sdr (if defined _adr%%# set "_sdr=%%#:")
)
if not defined _sdr set psfnet=0
set "_Pkt=31bf3856ad364e35"
set "_EsuCmp=microsoft-client-li..pplementalservicing"
set "_EdgCmp=microsoft-windows-e..-firsttimeinstaller"
set "_CedCmp=microsoft-windows-edgechromium"
set "_EsuIdn=Microsoft-Client-Licensing-SupplementalServicing"
set "_EdgIdn=Microsoft-Windows-EdgeChromium-FirstTimeInstaller"
set "_CedIdn=Microsoft-Windows-EdgeChromium"
set "_SxsCfg=Microsoft\Windows\CurrentVersion\SideBySide\Configuration"
set _MOifeo=0
set _IFEO="HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\dismhost.exe"
setlocal EnableDelayedExpansion

if %_Debug% equ 0 (
    set "_Nul1=1>nul"
    set "_Nul2=2>nul"
    set "_Nul6=2^>nul"
    set "_Nul3=1>nul 2>nul"
    set "_Pause=pause >nul"
    goto :Begin
)
set "_Nul1="
set "_Nul2="
set "_Nul6="
set "_Nul3="
copy /y nul "!_work!\#.rw" %_Null% && (if exist "!_work!\#.rw" del /f /q "!_work!\#.rw") || (set "_log=!_dsk!\%~n0")
echo.
echo 正在调试模式下运行……
echo 当完成之后，此窗口将会关闭
@echo on
@prompt $G
@call :Begin >"!_log!.Debug.log" 2>&1
@exit /b

:Begin
@cls
title Windows ISO UUP 生成
set "_dLog=%SystemRoot%\Logs\DISM"
set "_Dism=Dism.exe /ScratchDir:"!_cabdir!""

:precheck
set W10UI=0
if %winbuild% geq 10240 (
    set W10UI=1
)
set ksub=SOFTWIM
set ERRORTEMP=
set PREPARED=0
set EXPRESS=0
set uwinpe=0
set _skpd=0
set _skpp=0
set _ndir=0
set _nsum=0
set _reMSU=0
set _wimEdge=0
set _SrvESD=0
set _Srvr=0
set _updexist=0
set _appexist=0
set "_mount=%_drv%\Mount"
set "_ntf=NTFS"
if /i not "%_drv%"=="%SystemDrive%" if %_cwmi% equ 1 for /f "tokens=2 delims==" %%# in ('"wmic volume where DriveLetter='%_drv%' get FileSystem /value"') do set "_ntf=%%#"
if /i not "%_drv%"=="%SystemDrive%" if %_cwmi% equ 0 for /f %%# in ('powershell -nop -c "(([WMISEARCHER]'Select * from Win32_Volume where DriveLetter=\"%_drv%\"').Get()).FileSystem"') do set "_ntf=%%#"
if /i not "%_ntf%"=="NTFS" (
    set "_mount=%SystemDrive%\Mount"
)
set "line============================================================="

:check
pushd "!_work!"
set _fils=(7z.dll,7z.exe,bootmui.txt,bootwim.txt,oscdimg.exe,imagex.exe,libwim-15.dll,offlinereg.exe,offreg*.dll,wimlib-imagex.exe,PSFExtractor.exe)
for %%# in %_fils% do (
    if not exist "bin\%%#" (set _bin=%%#&goto :E_BinMiss)
)
if exist ISOFOLDER\ rmdir /s /q ISOFOLDER\
if exist temp\ rmdir /s /q temp\
mkdir temp

:ReadConfig
if not exist "Config.ini" goto :checkdone
findstr /i \[Config\] Config.ini %_Nul1% || goto :checkdone
for %%# in (
AddUpdates
Cleanup
ResetBase
WIM2ESD
WIM2SWM
SkipISO
LCUWinRE
SkipWinRE
UpdtBootFiles
UpdtOneDrive
AddEdition
AddAppxs
UseMSU
) do (
call :Readini %%#
)
goto :checkdone

:Readini
findstr /b /i %1 Config.ini %_Nul1% && for /f "tokens=2 delims==" %%# in ('findstr /b /i %1 Config.ini') do set "%1=%%#"
goto :eof

:checkdone
echo.
if defined _args for %%# in (%*) do if exist "%%~#\*.esd" (set "_DIR=%%~#"&echo %%~#&goto :checkesd)
for /f "tokens=* delims=" %%# in ('dir /b /ad "!_work!"') do if exist "%%~#\*.esd" (set /a _ndir+=1&set "_DIR=%%~#"&echo %%~#)
if !_ndir! equ 1 if defined _DIR goto :checkesd

:selectuup
set _DIR=
echo.
echo %line%
echo 使用 Tab 键选择或输入包含 .esd 文件的文件夹
echo %line%
echo.
set /p _DIR=
if not defined _DIR (
    echo.
    echo %_err%
    echo 未指定文件夹
    echo.
    goto :selectuup
)
set "_DIR=%_DIR:"=%"
if "%_DIR:~-1%"=="\" set "_DIR=%_DIR:~0,-1%"
if not exist "%_DIR%\*.esd" (
    echo.
    echo %_err%
    echo 指定的文件夹内无 .esd 文件
    echo.
    goto :selectuup
)

:checkesd
echo.
echo %line%
echo 正在检查 ESD 文件信息……
echo %line%
echo.
dir /b /ad "!_DIR!\*Package*" %_Nul3% && set EXPRESS=1
for %%# in (
    Core,CoreSingleLanguage,CoreCountrySpecific,Education,Professional,ProfessionalEducation,ProfessionalWorkstation
    ServerStandardCore,ServerStandard,ServerDatacenterCore,ServerDatacenter,ServerTurbineCore,ServerTurbine,ServerAzureStackHCICor
) do (
    if exist "!_DIR!\%%#_*.esd" (dir /b /a:-d "!_DIR!\%%#_*.esd">>temp\uups_esd.txt %_Nul2%
    ) else if exist "!_DIR!\MetadataESD_%%#_*.esd" (dir /b /a:-d "!_DIR!\MetadataESD_%%#_*.esd">>temp\uups_esd.txt %_Nul2%
    )
)
for /f "tokens=3 delims=: " %%# in ('find /v /c "" temp\uups_esd.txt %_Nul6%') do set _nsum=%%#
if %_nsum% equ 0 goto :E_NotFind
for /l %%# in (1,1,%_nsum%) do call :mediacheck %%#
if defined eWIMLIB goto :QUIT
goto :ISO

:ISO
if %PREPARED% equ 0 call :PREPARE
if exist "!_DIR!\*Windows1*-KB*" set _updexist=1
if exist "Apps\Apps\*.*x*" set _appexist=1
if %_updexist% equ 0 set AddUpdates=0
if %_appexist% equ 0 set AddAppxs=0
if /i %arch%==arm64 if %winbuild% lss 9600 if %AddUpdates% equ 1 if %_build% geq 17763 set AddUpdates=0
if %AddUpdates% equ 1 if %W10UI% equ 0 set AddUpdates=0
if %Cleanup% equ 0 set ResetBase=0
if %_build% lss 17763 if %AddUpdates% equ 1 set Cleanup=1
if %_build% geq 22000 set LCUWinRE=1
if %_SrvESD% equ 1 set AddEdition=0 && set UpdtOneDrive=0
if %AddUpdates% equ 1 call :DismHostON
if %AddAppxs% equ 1 call :DismHostON

echo.
echo %line%
echo 正在列出已配置选项……
echo %line%
echo.
if %_updexist% neq 0 echo Updates Exist
if %_appexist% neq 0 echo Appxs Exist
if %AddUpdates% neq 0 echo AddUpdates
if %Cleanup% neq 0 echo Cleanup
if %ResetBase% neq 0 echo ResetBase
if %SkipWinRE% neq 0 echo SkipWinRE
if %LCUWinRE% neq 0 echo LCUWinRE
if %UpdtOneDrive% neq 0  echo UpdtOneDrive
if %AddEdition% neq 0 echo AddEdition
if %AddAppxs% neq 0 echo AddAppxs

call :uup_ref
echo.
echo %line%
echo 正在部署 ISO 安装文件……
echo %line%
echo.
if exist ISOFOLDER\ rmdir /s /q ISOFOLDER\
mkdir ISOFOLDER
wimlib-imagex.exe apply "!_DIR!\%uups_esd1%" 1 ISOFOLDER\ --no-acls --no-attributes %_Nul3%
set ERRORTEMP=%ERRORLEVEL%
if %ERRORTEMP% neq 0 goto :E_Apply
if exist ISOFOLDER\MediaMeta.xml del /f /q ISOFOLDER\MediaMeta.xml %_Nul3%
if exist ISOFOLDER\__chunk_data del /f /q ISOFOLDER\__chunk_data %_Nul3%
if %_build% geq 18890 (
    wimlib-imagex.exe extract "!_DIR!\%uups_esd1%" 3 Windows\Boot\Fonts\* --dest-dir=ISOFOLDER\boot\fonts --no-acls --no-attributes %_Nul3%
    xcopy /CRY ISOFOLDER\boot\fonts\* ISOFOLDER\efi\microsoft\boot\fonts\ %_Nul3%
)
if exist "!_cabdir!\" rmdir /s /q "!_cabdir!\"
if not exist "!_cabdir!\" mkdir "!_cabdir!"

if %AddUpdates% neq 1 goto :NoUpdate
echo.
echo %line%
echo 正在检查更新文件……
echo %line%
echo.
if %_build% lss 21382 if exist "!_DIR!\*.msu" for /f "tokens=* delims=" %%# in ('dir /b /on "!_DIR!\*.msu"') do (set "pkgn=%%~n#"&set "package=%%#"&call :exd_msu)
if %_build% geq 21382 if %UseMSU% neq 1 if exist "!_DIR!\*.msu" for /f "tokens=* delims=" %%# in ('dir /b /on "!_DIR!\*.msu"') do (set "pkgn=%%~n#"&set "package=%%#"&call :exd_msu)
if %_build% geq 21382 if exist "!_DIR!\*.AggregatedMetadata*.cab" if exist "!_DIR!\*Windows1*-KB*.cab" if exist "!_DIR!\*Windows1*-KB*.psf" set _reMSU=1
del /f /q %_dLog%\* %_Nul3%
if not exist "%_dLog%\" mkdir "%_dLog%" %_Nul3%
if %_updexist% equ 1 if %_build% geq 22000 if exist "%SysPath%\ucrtbase.dll" if not exist "bin\dpx.dll" if not exist "temp\dpx.dll" call :uups_dpx
if %_reMSU% equ 1 if %UseMSU% equ 1 call :upd_msu
set directcab=0
call :extract

:NoUpdate
if %_appexist% equ 1 if not exist "!_cabdir!\" mkdir "!_cabdir!"
if exist bin\ei.cfg copy /y bin\ei.cfg ISOFOLDER\sources\ei.cfg %_Nul3%
if not defined isoupdate goto :NoSetupDU
echo.
echo %line%
echo 正在应用 ISO 安装文件更新……
echo %line%
echo.
mkdir "%_cabdir%\du" %_Nul3%
for %%# in (!isoupdate!) do (
    echo %%~#
    expand.exe -r -f:* "!_DIR!\%%~#" "%_cabdir%\du" %_Nul1%
)
xcopy /CDRUY "%_cabdir%\du" "ISOFOLDER\sources\" %_Nul3%
if exist "%_cabdir%\du\*.ini" xcopy /CDRY "%_cabdir%\du\*.ini" "ISOFOLDER\sources\" %_Nul3%
for /f %%# in ('dir /b /ad "%_cabdir%\du\*-*" %_Nul6%') do if exist "ISOFOLDER\sources\%%#\*.mui" copy /y "%_cabdir%\du\%%#\*" "ISOFOLDER\sources\%%#\" %_Nul3%
if exist "%_cabdir%\du\replacementmanifests\" xcopy /CERY "%_cabdir%\du\replacementmanifests" "ISOFOLDER\sources\replacementmanifests\" %_Nul3%
rmdir /s /q "%_cabdir%\du\" %_Nul3%
:NoSetupDU
set _rtrn=WinreRet
goto :WinreWim
:WinreRet
set _rtrn=BootRet
goto :BootWim
:BootRet
set _rtrn=InstallRet
goto :InstallWim
:InstallRet
for /f "delims=" %%i in ('dir /s /b /tc "ISOFOLDER\sources\install.wim"') do set "_size=000000%%~z#"
if "%_size%" lss "0000004194304000" set WIM2SWM=0
if %WIM2ESD% equ 0 if %WIM2SWM% equ 0 goto :doiso
if %WIM2ESD% equ 0 if %WIM2SWM% equ 1 goto :doswm
:doesd
echo.
echo %line%
echo 正在将 install.wim 转换为 install.esd……
echo %line%
echo.
wimlib-imagex.exe export ISOFOLDER\sources\install.wim all ISOFOLDER\sources\install.esd --compress=LZMS --solid
call set ERRORTEMP=!ERRORLEVEL!
if !ERRORTEMP! neq 0 (echo.&echo 在导出映像的时候出现错误。正在丢弃 install.esd&del /f /q ISOFOLDER\sources\install.esd %_Nul3%)
if exist ISOFOLDER\sources\install.esd del /f /q ISOFOLDER\sources\install.wim
goto :doiso
:doswm
echo.
echo %line%
echo 正在将 install.wim 拆分为多个 install*.swm……
echo %line%
echo.
wimlib-imagex.exe split ISOFOLDER\sources\install.wim ISOFOLDER\sources\install.swm 3500
call set ERRORTEMP=!ERRORLEVEL!
if !ERRORTEMP! neq 0 (echo.&echo 在拆分映像的时候出现错误。正在丢弃 install.swm&del /f /q ISOFOLDER\sources\install*.swm %_Nul3%)
if exist ISOFOLDER\sources\install*.swm del /f /q ISOFOLDER\sources\install.wim
goto :doiso
:doiso
if %SkipISO% neq 0 (
    ren ISOFOLDER %DVDISO%
    echo.
    echo %line%
    echo 已完成要求的操作。你已选择不创建 .iso 文件。
    echo %line%
    echo.
    goto :QUIT
)
echo.
echo %line%
echo 正在创建 ISO ……
echo %line%
for /f "delims=" %%i in ('dir /s /b /tc "ISOFOLDER\sources\install.*"') do set wimfile=%%~fi
for /f %%a in ('powershell -nop -c "(dir %wimfile%).LastWriteTime.ToString('MM/dd/yyyy,HH:mm:ss')"') do set isotime=%%a
if /i not %arch%==arm64 (
    oscdimg.exe -bootdata:2#p0,e,b"ISOFOLDER\boot\etfsboot.com"#pEF,e,b"ISOFOLDER\efi\Microsoft\boot\efisys.bin" -o -m -u2 -udfver102 -t%isotime% -l%DVDLABEL% ISOFOLDER %DVDISO%.iso
) else (
    oscdimg.exe -bootdata:1#pEF,e,b"ISOFOLDER\efi\Microsoft\boot\efisys.bin" -o -m -u2 -udfver102 -t%isotime% -l%DVDLABEL% ISOFOLDER %DVDISO%.iso
)
set ERRORTEMP=%ERRORLEVEL%
if %ERRORTEMP% neq 0 goto :E_ISOC
echo.
echo %line%
echo 完成。
echo %line%
echo.
goto :QUIT

:InstallWim
echo.
echo %line%
echo 正在创建 install.wim 文件……
echo %line%
echo.
if exist "temp\*.esd" (set _rrr=--ref="temp\*.esd") else (set "_rrr=")
for /L %%# in (1, 1,%_nsum%) do (
    wimlib-imagex.exe export "!_DIR!\!uups_esd%%#!" 3 "ISOFOLDER\sources\install.wim" --ref="!_DIR!\*.esd" %_rrr% --compress=LZX
    call set ERRORTEMP=!ERRORLEVEL!
    if !ERRORTEMP! neq 0 goto :E_Export
    set nedition=!edition%%#! && call :setname
    wimlib-imagex.exe info "ISOFOLDER\sources\install.wim" %%# "!_namea!" "!_namea!" --image-property DISPLAYNAME="!_nameb!" --image-property DISPLAYDESCRIPTION="!_nameb!" --image-property FLAGS=!edition%%#! %_Nul3%
    if !_ESDSrv%%#! equ 1 wimlib-imagex.exe info "ISOFOLDER\sources\install.wim" %%# "!_namea!" "!_namea!" --image-property DISPLAYNAME="!_nameb!" --image-property DISPLAYDESCRIPTION="!_namec!" --image-property FLAGS=!edition%%#! %_Nul3%
)
if not exist temp\Winre.wim goto :SkipWinre
if %SkipWinRE% equ 1 goto :SkipWinre
echo.
echo %line%
echo 正在将 Winre.wim 添加到 install.wim 中……
echo %line%
echo.
for /f "tokens=3 delims=: " %%# in ('wimlib-imagex.exe info "ISOFOLDER\sources\install.wim" ^| findstr /c:"Image Count"') do set imgcount=%%#
for /L %%# in (1,1,%imgcount%) do wimlib-imagex.exe update "ISOFOLDER\sources\install.wim" %%# --command="add 'temp\Winre.wim' '\Windows\System32\Recovery\Winre.wim'" %_Nul3%
:SkipWinre
if %UpdtOneDrive% equ 1 if exist "Apps\OneDriveSetup.exe" call :OneDrive
if %AddUpdates% neq 1 if %AddAppxs% neq 1 if %AddEdition% neq 1 goto :SkipUpdate
if %_SrvESD% equ 1 if %AddUpdates% neq 1 if not exist "Apps\app*Server.txt" goto :SkipUpdate
call :update
:SkipUpdate
for /f "tokens=3 delims=: " %%# in ('wimlib-imagex.exe info "ISOFOLDER\sources\install.wim" ^| findstr /c:"Image Count"') do set imgs=%%#
for /L %%# in (1,1,%imgs%) do (
    for /f "tokens=3 delims=<>" %%A in ('imagex /info "ISOFOLDER\sources\install.wim" %%# ^| find /i "<HIGHPART>"') do call set "HIGHPART%%#=%%A"
    for /f "tokens=3 delims=<>" %%A in ('imagex /info "ISOFOLDER\sources\install.wim" %%# ^| find /i "<LOWPART>"') do call set "LOWPART%%#=%%A"
    wimlib-imagex.exe info "ISOFOLDER\sources\install.wim" %%# --image-property CREATIONTIME/HIGHPART=!HIGHPART%%#! --image-property CREATIONTIME/LOWPART=!LOWPART%%#! %_Nul1%
)
if %AddEdition% neq 1 goto :SkipExport
for /l %%# in (1,1,%imgs%) do (
    imagex /info "ISOFOLDER\sources\install.wim" %%# >temp\newinfo.txt 2>&1
    findstr /i "<EDITIONID>Core</EDITIONID>" temp\newinfo.txt %_Nul3% && set i1=%%#
    findstr /i "<EDITIONID>CoreSingleLanguage</EDITIONID>" temp\newinfo.txt %_Nul3% && set i2=%%#
    findstr /i "<EDITIONID>Education</EDITIONID>" temp\newinfo.txt %_Nul3% && set i3=%%#
    findstr /i "<EDITIONID>Professional</EDITIONID>" temp\newinfo.txt %_Nul3% && set i4=%%#
    findstr /i "<EDITIONID>ProfessionalEducation</EDITIONID>" temp\newinfo.txt %_Nul3% && set i5=%%#
    findstr /i "<EDITIONID>ProfessionalWorkstation</EDITIONID>" temp\newinfo.txt %_Nul3% && set i6=%%#
)
for %%# in (%i1%,%i2%,%i3%,%i4%,%i5%,%i6%) do (
    wimlib-imagex.exe export "ISOFOLDER\sources\install.wim" %%# "ISOFOLDER\sources\installnew.wim" %_Nul3%
    set ERRORTEMP=%ERRORLEVEL%
    if %ERRORTEMP% neq 0 goto :E_Export
)
if exist "ISOFOLDER\sources\installnew.wim" del /f /q "ISOFOLDER\sources\install.wim"&ren "ISOFOLDER\sources\installnew.wim" install.wim %_Nul3%
:SkipExport
wimlib-imagex.exe optimize "ISOFOLDER\sources\install.wim"
goto :%_rtrn%

:OneDrive
echo.
echo %line%
echo 正在更新 OneDrive 安装文件……
echo %line%
echo.
type nul>temp\OneDrive.txt
for /f "tokens=3 delims=: " %%# in ('wimlib-imagex.exe info ISOFOLDER\sources\install.wim ^| findstr /c:"Image Count"') do set imgcount=%%#
set sysdir=System32
if %_build% lss 22563 set sysdir=SysWOW64
if exist "Apps\OneDriveSetup.exe" >>temp\OneDrive.txt echo add 'Apps\OneDriveSetup.exe' '^\Windows^\%sysdir%^\OneDriveSetup.exe'
if exist "Apps\OneDrive.ico" >>temp\OneDrive.txt echo add 'Apps\OneDrive.ico' '^\Windows^\%sysdir%^\OneDrive.ico'
for /L %%# in (1,1,%imgcount%) do wimlib-imagex.exe update ISOFOLDER\sources\install.wim %%# < temp\OneDrive.txt %_Nul3%
goto :eof

:WinreWim
if %SkipWinRE% equ 1 goto :%_rtrn%
echo.
echo %line%
echo 正在创建 Winre.wim 文件……
echo %line%
echo.
wimlib-imagex.exe export "!_DIR!\%uups_esd1%" 2 temp\Winre.wim --compress=LZX --boot
set ERRORTEMP=%ERRORLEVEL%
if %ERRORTEMP% neq 0 goto :E_Export
if %uwinpe% equ 1 call :update temp\Winre.wim
wimlib-imagex.exe optimize temp\Winre.wim
goto :%_rtrn%

:BootWim
echo.
echo %line%
echo 正在创建 boot.wim 文件……
echo %line%
echo.
wimlib-imagex.exe export "!_DIR!\%uups_esd1%" 2 temp\boot.wim --compress=LZX --boot
if exist "!_DIR!\WinPE-Setup\*WinPE-Setup*.cab" goto :BootDism
goto :BootNoDism

:BootDone
for /f "tokens=3 delims=: " %%# in ('wimlib-imagex.exe info ISOFOLDER\sources\boot.wim ^| findstr /c:"Image Count"') do set imgs=%%#
for /L %%# in (1,1,%imgs%) do (
    for /f "tokens=3 delims=<>" %%A in ('imagex /info ISOFOLDER\sources\boot.wim %%# ^| find /i "<HIGHPART>"') do call set "HIGHPART%%#=%%A"
    for /f "tokens=3 delims=<>" %%A in ('imagex /info ISOFOLDER\sources\boot.wim %%# ^| find /i "<LOWPART>"') do call set "LOWPART%%#=%%A"
    wimlib-imagex.exe info ISOFOLDER\sources\boot.wim %%# --image-property CREATIONTIME/HIGHPART=!HIGHPART%%#! --image-property CREATIONTIME/LOWPART=!LOWPART%%#! %_Nul1%
)
wimlib-imagex.exe optimize ISOFOLDER\sources\boot.wim
goto :%_rtrn%

:BootNoDism
if exist "%_mount%\" rmdir /s /q "%_mount%\"
if not exist "%_mount%\" mkdir "%_mount%"
%_Dism% /LogPath:"%_dLog%\DismMount.log" /Mount-Wim /Wimfile:"temp\boot.wim" /Index:1 /MountDir:"%_mount%"
set ERRORTEMP=%ERRORLEVEL%
if %ERRORTEMP% neq 0 (
    %_Dism% /LogPath:"%_dLog%\DismUnMount.log" /Unmount-Wim /MountDir:"%_mount%" /Discard %_Nul3%
    Dism.exe /Cleanup-Wim %_Nul3%
    rmdir /s /q "%_mount%\"
)
call :BootRemove
call :cleanup
%_Dism% /LogPath:"%_dLog%\DismUnMount.log" /Unmount-Wim /MountDir:"%_mount%" /Commit
if %uwinpe% equ 1 call :update temp\boot.wim

wimlib-imagex.exe export temp\boot.wim 1 ISOFOLDER\sources\boot.wim "Microsoft Windows PE (%_ss%)" "Microsoft Windows PE (%_ss%)" %_Nul3%
if %_build% lss 22000 wimlib-imagex.exe info ISOFOLDER\sources\boot.wim 1 "Microsoft Windows PE (%arch%)" "Microsoft Windows PE (%arch%)" %_Nul3%
wimlib-imagex.exe info ISOFOLDER\sources\boot.wim 1 --image-property FLAGS=9 %_Nul3%
wimlib-imagex.exe update ISOFOLDER\sources\boot.wim 1 --command="delete '\Windows\system32\winpeshl.ini'" %_Nul3%
wimlib-imagex.exe extract ISOFOLDER\sources\boot.wim 1 Windows\System32\config\SOFTWARE --dest-dir=temp --no-acls --no-attributes %_Nul3%
offlinereg.exe temp\SOFTWARE "Microsoft\Windows NT\CurrentVersion\WinPE" setvalue InstRoot X:\$Windows.~bt\ %_Nul3%
offlinereg.exe temp\SOFTWARE "Microsoft\Windows NT\CurrentVersion" setvalue SystemRoot X:\$Windows.~bt\Windows %_Nul3%
type nul>temp\boot.txt
>>temp\boot.txt echo add 'temp^\SOFTWARE' '^\Windows^\System32^\config^\SOFTWARE'
wimlib-imagex.exe update ISOFOLDER\sources\boot.wim 1 < temp\boot.txt %_Nul3%

wimlib-imagex.exe export temp\boot.wim 1 ISOFOLDER\sources\boot.wim "Microsoft Windows Setup (%_ss%)" "Microsoft Windows Setup (%_ss%)" --boot %_Nul3%
if %_build% lss 22000 wimlib-imagex.exe info ISOFOLDER\sources\boot.wim 2 "Microsoft Windows Setup (%arch%)" "Microsoft Windows Setup PE (%arch%)" %_Nul3%
wimlib-imagex.exe info ISOFOLDER\sources\boot.wim 2 --image-property FLAGS=2 --boot %_Nul3%
wimlib-imagex.exe extract "!_DIR!\%uups_esd1%" 3 Windows\system32\xmllite.dll --dest-dir=ISOFOLDER\sources --no-acls --no-attributes %_Nul3%
type nul>temp\boot.txt
>>temp\boot.txt echo delete '^\Windows^\system32^\winpeshl.ini'
>>temp\boot.txt echo add 'ISOFOLDER^\setup.exe' '^\setup.exe'
>>temp\boot.txt echo add 'ISOFOLDER^\sources^\inf^\setup.cfg' '^\sources^\inf^\setup.cfg'
set "_bkimg="
wimlib-imagex.exe extract ISOFOLDER\sources\boot.wim 1 Windows\System32\winpe.jpg --dest-dir=ISOFOLDER\sources --no-acls --no-attributes --nullglob %_Nul3%
for %%# in (background_cli.bmp, background_svr.bmp, background_cli.png, background_svr.png, winpe.jpg) do if exist "ISOFOLDER\sources\%%#" set "_bkimg=%%#"
if defined _bkimg (
    >>temp\boot.txt echo add 'ISOFOLDER^\sources^\%_bkimg%' '^\sources^\background.bmp'
    >>temp\boot.txt echo add 'ISOFOLDER^\sources^\%_bkimg%' '^\Windows^\system32^\setup.bmp'
)
for /f %%# in (bin\bootwim.txt) do if exist "ISOFOLDER\sources\%%#" (
    >>temp\boot.txt echo add 'ISOFOLDER^\sources^\%%#' '^\sources^\%%#'
)
for /f %%# in (bin\bootmui.txt) do if exist "ISOFOLDER\sources\%langid%\%%#" (
    >>temp\boot.txt echo add 'ISOFOLDER^\sources^\%langid%^\%%#' '^\sources^\%langid%^\%%#'
)
wimlib-imagex.exe update ISOFOLDER\sources\boot.wim 2 < temp\boot.txt %_Nul3%
del /f /q ISOFOLDER\sources\xmllite.dll %_Nul3%
del /f /q ISOFOLDER\sources\winpe.jpg %_Nul3%
goto :BootDone

:BootDism
wimlib-imagex.exe export temp\boot.wim 1 ISOFOLDER\sources\boot.wim "Microsoft Windows PE (%_ss%)" "Microsoft Windows PE (%_ss%)" %_Nul3%
if %_build% lss 22000 wimlib-imagex.exe info ISOFOLDER\sources\boot.wim 1 "Microsoft Windows PE (%arch%)" "Microsoft Windows PE (%arch%)" %_Nul3%
wimlib-imagex.exe info ISOFOLDER\sources\boot.wim 1 --image-property FLAGS=9 %_Nul3%
if exist "%_mount%\" rmdir /s /q "%_mount%\"
if not exist "%_mount%\" mkdir "%_mount%"
%_Dism% /LogPath:"%_dLog%\DismMount.log" /Mount-Wim /Wimfile:ISOFOLDER\sources\boot.wim /Index:1 /MountDir:"%_mount%"
set ERRORTEMP=%ERRORLEVEL%
if %ERRORTEMP% neq 0 (
    %_Dism% /LogPath:"%_dLog%\DismUnMount.log" /Unmount-Wim /MountDir:"%_mount%" /Discard %_Nul3%
    Dism.exe /Cleanup-Wim %_Nul3%
    rmdir /s /q "%_mount%\" %_Nul3%
    del /f /q ISOFOLDER\sources\boot.wim %_Nul3%
    goto :BootNoDism
)
call :BootRemove
%_Dism% /LogPath:"%_dLog%\DismBoot.log" /Image:"%_mount%" /Set-TargetPath:X:\$Windows.~bt\
del /f /q %_mount%\Windows\system32\winpeshl.ini %_Nul3%
call :cleanup
%_Dism% /LogPath:"%_dLog%\DismUnMount.log" /Unmount-Wim /MountDir:"%_mount%" /Commit

wimlib-imagex.exe export temp\boot.wim 1 ISOFOLDER\sources\boot.wim "Microsoft Windows Setup (%_ss%)" "Microsoft Windows Setup (%_ss%)" --boot %_Nul3%
if %_build% lss 22000 wimlib-imagex.exe info ISOFOLDER\sources\boot.wim 2 "Microsoft Windows Setup (%arch%)" "Microsoft Windows Setup (%arch%)" %_Nul3%
wimlib-imagex.exe info ISOFOLDER\sources\boot.wim 2 --image-property FLAGS=2 --boot %_Nul3%
if exist "%_mount%\" rmdir /s /q "%_mount%\"
if not exist "%_mount%\" mkdir "%_mount%"
%_Dism% /LogPath:"%_dLog%\DismMount.log" /Mount-Wim /Wimfile:ISOFOLDER\sources\boot.wim /Index:2 /MountDir:"%_mount%"
set ERRORTEMP=%ERRORLEVEL%
if %ERRORTEMP% neq 0 (
    %_Dism% /LogPath:"%_dLog%\DismUnMount.log" /Unmount-Wim /MountDir:"%_mount%" /Discard %_Nul3%
    Dism.exe /Cleanup-Wim %_Nul3%
    rmdir /s /q "%_mount%\" %_Nul3%
    del /f /q ISOFOLDER\sources\boot.wim %_Nul3%
    goto :BootNoDism
)
call :BootRemove
set "cabadd="
for /f "delims=" %%# in ('dir /b /a:-d "!_DIR!\WinPE-Setup\*WinPE-Setup.cab"') do set "cabadd=!cabadd! /PackagePath:!_DIR!\WinPE-Setup\%%#"
for /f "delims=" %%# in ('dir /b /a:-d "!_DIR!\WinPE-Setup\*WinPE-Setup_*.cab"') do set "cabadd=!cabadd! /PackagePath:!_DIR!\WinPE-Setup\%%#"
for /f "delims=" %%# in ('dir /b /a:-d "!_DIR!\WinPE-Setup\*WinPE-Setup-*.cab"') do set "cabadd=!cabadd! /PackagePath:!_DIR!\WinPE-Setup\%%#"
%_Dism% /LogPath:"%_dLog%\DismBoot.log" /Image:"%_mount%" /Add-Package !cabadd!
del /f /q %_mount%\Windows\system32\winpeshl.ini %_Nul3%
copy ISOFOLDER\sources\lang.ini %_mount%\sources\lang.ini %_Nul3%
call :cleanup
%_Dism% /LogPath:"%_dLog%\DismUnMount.log" /Unmount-Wim /MountDir:"%_mount%" /Commit
if %uwinpe% equ 1 call :update ISOFOLDER\sources\boot.wim
goto :BootDone

:BootRemove
type nul>temp\winre.txt
type nul>temp\winpe.txt
set "remove="
for /f "tokens=3 delims=: " %%i in ('%_Dism% /LogPath:"%_dLog%\DismBoot.log" /English /Image:"%_mount%" /Get-Packages ^| findstr /c:"Package Identity"') do echo %%i>>temp\winre.txt
for /f "eol=W tokens=* delims=" %%# in (bin\winpe.txt) do for /f "tokens=* delims=" %%i in ('type temp\winre.txt ^| findstr /c:"%%#"') do echo %%i>>temp\winpe.txt
for /f "tokens=* delims=" %%# in (bin\winpe.txt) do for /f "eol=M tokens=* delims=" %%i in ('type temp\winre.txt ^| findstr /c:"%%#"') do echo %%i>>temp\winpe.txt
for /f "tokens=* delims=" %%i in (temp\winpe.txt) do set "remove=!remove! /PackageName:%%i"
%_Dism% /LogPath:"%_dLog%\DismBoot.log" /Image:"%_mount%" /Remove-Package !remove!
goto :eof

:PREPARE
echo.
echo %line%
echo 正在检查镜像信息……
echo %line%
set PREPARED=1
imagex /info "!_DIR!\%uups_esd1%" 3 >temp\info.txt 2>&1
for /f "tokens=3 delims=<>" %%# in ('find /i "<DEFAULT>" temp\info.txt') do set "langid=%%#"
for /f "tokens=3 delims=<>" %%# in ('find /i "<ARCH>" temp\info.txt') do (if %%# equ 0 (set "arch=x86") else if %%# equ 9 (set "arch=x64") else (set "arch=arm64"))
for /f "tokens=3 delims=<>" %%# in ('find /i "<BUILD>" temp\info.txt') do set _build=%%#
if %_build% geq 22621 if exist "!_DIR!\*Edge*.wim" (
    set _wimEdge=1
    if not exist "!_DIR!\Edge.wim" for /f %%# in ('dir /b /a:-d "!_DIR!\*Edge*.wim"') do rename "!_DIR!\%%#" Edge.wim %_Nul3%
)
set _dpx=0
if %_updexist% equ 1 if %_build% geq 22000 if exist "%SysPath%\ucrtbase.dll" if exist "!_DIR!\*DesktopDeployment*.cab" (
    if /i %arch%==%xOS% set _dpx=1
    if /i %arch%==x64 if /i %xOS%==amd64 set _dpx=1
)
if %_dpx% equ 1 (
    for /f "delims=" %%# in ('dir /b /a:-d "!_DIR!\*DesktopDeployment*.cab"') do expand.exe -f:dpx.dll "!_DIR!\%%#" .\temp %_Nul3%
    copy /y %SysPath%\expand.exe temp\ %_Nul3%
)
wimlib-imagex.exe extract "!_DIR!\%uups_esd1%" 1 sources\setuphost.exe --dest-dir=temp --no-acls --no-attributes %_Nul3%
7z.exe l temp\setuphost.exe >temp\version.txt 2>&1
if %_build% geq 22478 (
    wimlib-imagex.exe extract "!_DIR!\%uups_esd1%" 3 Windows\System32\UpdateAgent.dll --dest-dir=temp --no-acls --no-attributes --ref="!_DIR!\*.esd" %_Nul3%
    if exist "temp\UpdateAgent.dll" 7z.exe l temp\UpdateAgent.dll >temp\version.txt 2>&1
)
for /f "tokens=4-7 delims=.() " %%i in ('"findstr /i /b "FileVersion" temp\version.txt" %_Nul6%') do (set uupver=%%i.%%j&set uupmaj=%%i&set uupmin=%%j)
set revver=%uupver%&set revmaj=%uupmaj%&set revmin=%uupmin%
set "tok=6,7"&set "toe=5,6,7"
if /i %arch%==x86 (set _ss=x86) else if /i %arch%==x64 (set _ss=amd64) else (set _ss=arm64)
wimlib-imagex.exe extract "!_DIR!\%uups_esd1%" 3 Windows\WinSxS\Manifests\%_ss%_microsoft-windows-coreos-revision*.manifest --dest-dir=temp --no-acls --no-attributes --ref="!_DIR!\*.esd" %_Nul3%
if exist "temp\*_microsoft-windows-coreos-revision*.manifest" for /f "tokens=%tok% delims=_." %%i in ('dir /b /a:-d /od temp\*_microsoft-windows-coreos-revision*.manifest') do (set revver=%%i.%%j&set revmaj=%%i&set revmin=%%j)
if %_build% geq 15063 (
    wimlib-imagex.exe extract "!_DIR!\%uups_esd1%" 3 Windows\System32\config\SOFTWARE --dest-dir=temp --no-acls --no-attributes %_Nul3%
    set "isokey=Microsoft\Windows NT\CurrentVersion\Update\TargetingInfo\Installed"
    for /f %%i in ('"offlinereg.exe temp\SOFTWARE "!isokey!" enumkeys %_Nul6% ^| findstr /i /r ".*\.OS""') do if not errorlevel 1 (
        for /f "tokens=5,6 delims==:." %%A in ('"offlinereg.exe temp\SOFTWARE "!isokey!\%%i" getvalue Version %_Nul6%"') do if %%A gtr !revmaj! (
            set "revver=%%~A.%%B
            set revmaj=%%~A
            set "revmin=%%B
        )
    )
)
if %uupmin% lss %revmin% set uupver=%revver%
if %uupmaj% lss %revmaj% set uupver=%revver%
set _label=%uupver%
call :setlabel

:setlabel
set DVDISO=%_label%.%arch%
if %_SrvESD% equ 1 set DVDISO=%_label%.%arch%.Server
for %%# in (A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z) do set langid=!langid:%%#=%%#!
if /i %arch%==x86 set archl=X86
if /i %arch%==x64 set archl=X64
if /i %arch%==arm64 set archl=A64
set DVDLABEL=CCSA_%archl%FRE_%langid%_DV9
if %_SrvESD% equ 1 set DVDLABEL=SSS_%archl%FRE_%langid%_DV9&exit /b
if not exist "ISOFOLDER\sources\install.wim" exit /b
set images=0
for /f "tokens=3 delims=: " %%# in ('wimlib-imagex.exe info "ISOFOLDER\sources\install.wim" ^| findstr /c:"Image Count"') do set images=%%#
if %images% equ 1 call :isosingle
if %images% geq 4 set DVDLABEL=CCCOMA_%archl%FRE_%langid%_DV9
exit /b

:isosingle
for /f "tokens=3 delims=<>" %%# in ('imagex /info "ISOFOLDER\sources\install.wim" 1 ^| find /i "<EDITIONID>"') do set "editionid=%%#"
if /i %editionid%==Core set DVDLABEL=CCRA_%archl%FRE_%langid%_DV9%&exit /b
if /i %editionid%==CoreSingleLanguage set DVDLABEL=CSLA_%archl%FREO_%langid%_DV9&exit /b
if /i %editionid%==Education set DVDLABEL=CEDA_%archl%FRE_%langid%_DV9&exit /b
if /i %editionid%==Professional set DVDLABEL=CPRA_%archl%FRE_%langid%_DV9&exit /b
if /i %editionid%==ProfessionalEducation set DVDLABEL=CPREA_%archl%FRE_%langid%_DV9&exit /b
if /i %editionid%==ProfessionalWorkstation set DVDLABEL=CPRWA_%archl%FRE_%langid%_DV9&exit /b

:uup_ref
echo.
echo %line%
echo 正在将 .cab 转换为 .esd 文件……
echo %line%
echo.
set _level=XPRESS
if exist "!_DIR!\*.xml.cab" if exist "!_DIR!\Metadata\*" move /y "!_DIR!\*.xml.cab" "!_DIR!\Metadata\" %_Nul3%
if exist "!_DIR!\*.cab" (
    for /f "tokens=* delims=" %%# in ('dir /b /a:-d "!_DIR!\*.cab"') do (
        del /f /q temp\update.mum %_Nul3%
        expand.exe -f:update.mum "!_DIR!\%%#" temp %_Nul3%
        if exist "temp\update.mum" call :uup_cab "%%#"
    )
)
if %EXPRESS% equ 1 (
    for /f "tokens=* delims=" %%# in ('dir /b /a:d /o:-n "!_DIR!\"') do call :uup_dir "%%#"
)
if exist "!_DIR!\Metadata\*.xml.cab" copy /y "!_DIR!\Metadata\*.xml.cab" "!_DIR!\" %_Nul3%
exit /b

:uup_dir
if /i "%~1"=="Metadata" exit /b
echo %~1 | find /i "RetailDemo" %_Nul1% && exit /b
echo %~1 | find /i "Holographic-Desktop-FOD" %_Nul1% && exit /b
echo %~1 | find /i "Windows10.0-KB" %_Nul1% && exit /b
echo %~1 | find /i "Windows11.0-KB" %_Nul1% && exit /b
echo %~1 | find /i "SSU-" %_Nul1% && exit /b
set cbsp=%~1
if exist "temp\%cbsp%.esd" exit /b
echo 转换为 ESD 文件：%cbsp%.cab
rmdir /s /q "!_DIR!\%~1\$dpx$.tmp\" %_Nul3%
wimlib-imagex.exe capture "!_DIR!\%~1" "temp\%cbsp%.esd" --compress=%_level% --check --no-acls --norpfix "Edition Package" "Edition Package" %_Nul3%
exit /b

:uup_cab
echo %~1 | find /i "RetailDemo" %_Nul1% && exit /b
echo %~1 | find /i "Holographic-Desktop-FOD" %_Nul1% && exit /b
echo %~1 | find /i "Windows10.0-KB" %_Nul1% && exit /b
echo %~1 | find /i "Windows11.0-KB" %_Nul1% && exit /b
echo %~1 | find /i "SSU-" %_Nul1% && exit /b
set cbsp=%~n1
if exist "temp\%cbsp%.esd" exit /b
echo %cbsp%.cab
set /a _ref+=1
set /a _rnd=%random%
set _dst=%_drv%\_tmp%_ref%
if exist "%_dst%" (set _dst=%_drv%\_tmp%_rnd%)
mkdir %_dst% %_Nul3%
expand.exe -f:* "!_DIR!\%cbsp%.cab" %_dst%\ %_Nul3%
wimlib-imagex.exe capture "%_dst%" "temp\%cbsp%.esd" --compress=%_level% --check --no-acls --norpfix "Edition Package" "Edition Package" %_Nul3%
rmdir /s /q %_dst%\ %_Nul3%
if exist "%_dst%\" (
    mkdir %_drv%\_del %_Nul3%
    robocopy %_drv%\_del %_dst% /MIR /R:1 /W:1 /NFL /NDL /NP /NJH /NJS %_Nul3%
    rmdir /s /q %_drv%\_del\ %_Nul3%
    rmdir /s /q %_dst%\ %_Nul3%
)
exit /b

:mediacheck
set _ESDSrv%1=0
for /f "tokens=2 delims=]" %%# in ('find /v /n "" temp\uups_esd.txt ^| find "[%1]"') do set uups_esd=%%#
set "uups_esd%1=%uups_esd%"
wimlib-imagex.exe info "!_DIR!\%uups_esd%" 3 %_Nul3%
set ERRORTEMP=%ERRORLEVEL%
if %ERRORTEMP% equ 73 (
    echo %_err%
    echo %uups_esd% 文件已损坏
    echo.
    set eWIMLIB=1
    exit /b
)
if %ERRORTEMP% neq 0 (
    echo %_err%
    echo 无法解析来自文件 %uups_esd% 的信息
    echo.
    set eWIMLIB=1
    exit /b
)
imagex /info "!_DIR!\%uups_esd%" 3 >temp\info.txt 2>&1
for /f "tokens=3 delims=<>" %%# in ('find /i "<DEFAULT>" temp\info.txt') do set "langid%1=%%#"
for /f "tokens=3 delims=<>" %%# in ('find /i "<EDITIONID>" temp\info.txt') do set "edition%1=%%#"
for /f "tokens=3 delims=<>" %%# in ('find /i "<ARCH>" temp\info.txt') do (if %%# equ 0 (set "arch%1=x86") else if %%# equ 9 (set "arch%1=x64") else (set "arch%1=arm64"))
for /f "tokens=3 delims=<>" %%# in ('find /i "<BUILD>" temp\info.txt') do set _obuild%1=%%#
set "_wtx=Windows 10"
find /i "<NAME>" temp\info.txt %_Nul2% | find /i "Windows 11" %_Nul1% && (set "_wtx=Windows 11")
find /i "<NAME>" temp\info.txt %_Nul2% | find /i "Windows 12" %_Nul1% && (set "_wtx=Windows 12")
echo !edition%1! | findstr /i /b "Server" %_Nul3% && (set _SrvESD=1&set _ESDSrv%1=1)
set "_wsr=Windows Server 2022"
if !_ESDSrv%1! equ 1 (
find /i "<NAME>" temp\info.txt %_Nul2% | find /i " 2025" %_Nul1% && (set "_wsr=Windows Server 2025")
if !_obuild%1! geq 26010 (set "_wsr=Windows Server 2025")
)
if !_ESDSrv%1! equ 1 findstr /i /c:"Server Core" temp\info.txt %_Nul3% && (
if /i "!edition%1!"=="ServerStandard" set "edition%1=ServerStandardCore"
if /i "!edition%1!"=="ServerDatacenter" set "edition%1=ServerDatacenterCore"
if /i "!edition%1!"=="ServerTurbine" set "edition%1=ServerTurbineCore"
)
exit /b

:exd_msu
echo %line%
echo 解包更新 %package% 文件
echo %line%
echo.
mkdir "!_DIR!\%pkgn%" %_Nul3%
7z.exe e "!_DIR!\%package%" -o"!_DIR!\%pkgn%" *Windows1*.cab -aoa %_Nul3%
if exist "!_DIR!\%pkgn%\*Windows*.cab" for /f "tokens=* delims=" %%i in ('dir /b /on "!_DIR!\%pkgn%\*Windows*.cab"') do if not exist "!_DIR!\%%i" copy /y "!_DIR!\%pkgn%\%%i" "!_DIR!\%%i" %_Nul3%
7z.exe e "!_DIR!\%package%" -o"!_DIR!\%pkgn%" *Windows1*.wim -aoa %_Nul3%
if exist "!_DIR!\%pkgn%\*Windows*.wim" for /f "tokens=* delims=" %%i in ('dir /b /on "!_DIR!\%pkgn%\*Windows*.wim"') do if not exist "!_DIR!\%%i" copy /y "!_DIR!\%pkgn%\%%i" "!_DIR!\%%i" %_Nul3%
7z.exe e "!_DIR!\%package%" -o"!_DIR!\%pkgn%" *Windows1*.psf -aoa %_Nul3%
if exist "!_DIR!\%pkgn%\*Windows*.psf" for /f "tokens=* delims=" %%i in ('dir /b /on "!_DIR!\%pkgn%\*Windows*.psf"') do if not exist "!_DIR!\%%i" copy /y "!_DIR!\%pkgn%\%%i" "!_DIR!\%%i" %_Nul3%
7z.exe e "!_DIR!\%package%" -o"!_DIR!\%pkgn%" *SSU-*.cab -aoa %_Nul3%
if exist "!_DIR!\%pkgn%\*SSU-*.cab" for /f "tokens=* delims=" %%i in ('dir /b /on "!_DIR!\%pkgn%\*SSU-*.cab"') do if not exist "!_DIR!\%%i" copy /y "!_DIR!\%pkgn%\%%i" "!_DIR!\%%i" %_Nul3%
rmdir /s /q "!_DIR!\%pkgn%\" %_Nul3%
exit /b

:upd_msu
echo %line%
echo 创建累积更新的 MSU 文件
echo %line%
pushd "!_DIR!"
set "_MSUdll=dpx.dll ReserveManager.dll TurboStack.dll UpdateAgent.dll UpdateCompression.dll wcp.dll"
set "_MSUonf=onepackage.AggregatedMetadata.cab"
set "_MSUssu="
set IncludeSSU=1
set _mcfail=0
for /f "delims=" %%# in ('dir /b /a:-d "*.AggregatedMetadata*.cab"') do set "_MSUmeta=%%#"
if exist "_tMSU\" rmdir /s /q "_tMSU\" %_Nul3%
mkdir "_tMSU"
expand.exe -f:LCUCompDB*.xml.cab "%_MSUmeta%" "_tMSU" %_Nul3%
if not exist "_tMSU\LCUCompDB*.xml.cab" (
echo.
echo AggregatedMetadata 文件中 LCUCompDB 文件丢失，跳过操作。
goto :msu_dirs
)
for /f %%# in ('dir /b /a:-d "_tMSU\LCUCompDB*.xml.cab"') do set "_MSUcdb=%%#"
for /f "tokens=2 delims=_." %%# in ('echo %_MSUcdb%') do set "_MSUkbn=%%#"
if exist "*Windows1*%_MSUkbn%*%arch%*.msu" (
echo.
echo 累积更新 %_MSUkbn% 的 msu 文件已经存在，跳过操作。
goto :msu_dirs
)
if not exist "*Windows1*%_MSUkbn%*%arch%*.cab" (
echo.
echo 累积更新 %_MSUkbn% 的 cab 文件丢失，跳过操作。
goto :msu_dirs
)
if not exist "*Windows1*%_MSUkbn%*%arch%*.psf" (
echo.
echo 累积更新 %_MSUkbn% 的 psf 文件丢失，跳过操作。
goto :msu_dirs
)
for /f "delims=" %%# in ('dir /b /a:-d "*Windows1*%_MSUkbn%*%arch%*.cab"') do set "_MSUcab=%%#"
for /f "delims=" %%# in ('dir /b /a:-d "*Windows1*%_MSUkbn%*%arch%*.psf"') do set "_MSUpsf=%%#"
set "_MSUkbf=Windows10.0-%_MSUkbn%-%arch%"
echo %_MSUcab% | findstr /i "Windows11\." %_Nul1% && set "_MSUkbf=Windows11.0-%_MSUkbn%-%arch%"
echo %_MSUcab% | findstr /i "Windows12\." %_Nul1% && set "_MSUkbf=Windows12.0-%_MSUkbn%-%arch%"
if exist "SSU-*%arch%*.cab" (
for /f "tokens=2 delims=-" %%# in ('dir /b /a:-d "SSU-*%arch%*.cab"') do set "_MSUtsu=SSU-%%#-%arch%.cab"
for /f "delims=" %%# in ('dir /b /a:-d "SSU-*%arch%*.cab"') do set "_MSUssu=%%#"
expand.exe -f:SSUCompDB*.xml.cab "%_MSUmeta%" "_tMSU" %_Nul3%
if exist "_tMSU\SSU*-express.xml.cab" del /f /q "_tMSU\SSU*-express.xml.cab"
if not exist "_tMSU\SSUCompDB*.xml.cab" set IncludeSSU=0
) else (
set IncludeSSU=0
)
if %IncludeSSU% equ 1 for /f %%# in ('dir /b /a:-d "_tMSU\SSUCompDB*.xml.cab"') do set "_MSUsdb=%%#"
set "_MSUddd=DesktopDeployment_x86.cab"
if exist "*DesktopDeployment*.cab" (
for /f "delims=" %%# in ('dir /b /a:-d "*DesktopDeployment*.cab" ^|find /i /v "%_MSUddd%"') do set "_MSUddc=%%#"
) else (
call set "_MSUddc=_tMSU\DesktopDeployment.cab"
call set "_MSUddd=_tMSU\DesktopDeployment_x86.cab"
call :DDCAB
)
if %_mcfail% equ 1 goto :msu_dirs
if /i not %arch%==x86 if not exist "DesktopDeployment_x86.cab" if not exist "_tMSU\DesktopDeployment_x86.cab" (
call set "_MSUddd=_tMSU\DesktopDeployment_x86.cab"
call :DDC86
)
if %_mcfail% equ 1 goto :msu_dirs
call :crDDF _tMSU\%_MSUonf%
(echo "_tMSU\%_MSUcdb%" "%_MSUcdb%"
if %IncludeSSU% equ 1 echo "_tMSU\%_MSUsdb%" "%_MSUsdb%"
)>>zzz.ddf
%_Nul3% makecab.exe /F zzz.ddf /D Compress=ON /D CompressionType=MSZIP
if %ERRORLEVEL% neq 0 (
    echo makecab.exe %_MSUonf% 操作失败，跳过该操作。
    goto :msu_dirs
)
call :crDDF %_MSUkbf%.msu
(echo "%_MSUddc%" "DesktopDeployment.cab"
if /i not %arch%==x86 echo "%_MSUddd%" "DesktopDeployment_x86.cab"
echo "_tMSU\%_MSUonf%" "%_MSUonf%"
if %IncludeSSU% equ 1 echo "%_MSUssu%" "%_MSUtsu%"
echo "%_MSUcab%" "%_MSUkbf%.cab"
echo "%_MSUpsf%" "%_MSUkbf%.psf"
)>>zzz.ddf
%_Nul3% makecab.exe /F zzz.ddf /D Compress=OFF
if %ERRORLEVEL% neq 0 (
    echo makecab.exe %_MSUkbf%.msu  操作失败，跳过该操作。
    goto :msu_dirs
)

:msu_dirs
if exist "zzz.ddf" del /f /q "zzz.ddf"
if exist "_tSSU\" rmdir /s /q "_tSSU\" %_Nul3%
rmdir /s /q "_tMSU\" %_Nul3%
popd
exit /b

:DDCAB
echo.
echo 正在解压所需文件……
if exist "_tSSU\" rmdir /s /q "_tSSU\" %_Nul3%
mkdir "_tSSU\000"
if not defined _MSUssu goto :ssuinner64
expand.exe -f:* "%_MSUssu%" "_tSSU" %_Nul3% || goto :ssuinner64
goto :ssuouter64
:ssuinner64
popd
for /f %%# in ('wimlib-imagex.exe dir "!_DIR!\%uups_esd1%" 3 --path=Windows\WinSxS\Manifests ^| find /i "_microsoft-windows-servicingstack_"') do (
wimlib-imagex.exe extract "!_DIR!\%uups_esd1%" 3 Windows\WinSxS\%%~n# --dest-dir="!_DIR!\_tSSU" --no-acls --no-attributes %_Nul3%
)
pushd "!_DIR!"
:ssuouter64
set btx=%arch%
if /i %arch%==x64 set btx=amd64
for /f %%# in ('dir /b /ad "_tSSU\%btx%_microsoft-windows-servicingstack_*"') do set "src=%%#"
for %%# in (%_MSUdll%) do if exist "_tSSU\%src%\%%#" (move /y "_tSSU\%src%\%%#" "_tSSU\000\%%#" %_Nul1%)
call :crDDF %_MSUddc%
call :apDDF _tSSU\000
%_Nul3% makecab.exe /F zzz.ddf /D Compress=ON /D CompressionType=MSZIP
if %ERRORLEVEL% neq 0 (
    echo makecab.exe %_MSUddc% 操作失败，跳过该操作。
    set _mcfail=1
    exit /b
)
mkdir "_tSSU\111"
if /i not %arch%==x86 if not exist "DesktopDeployment_x86.cab" goto :DDCdual
rmdir /s /q "_tSSU\" %_Nul3%
exit /b

:DDC86
echo.
echo 正在解压所需文件……
if exist "_tSSU\" rmdir /s /q "_tSSU\" %_Nul3%
mkdir "_tSSU\111"
if not defined _MSUssu goto :ssuinner86
expand.exe -f:* "%_MSUssu%" "_tSSU" %_Nul3% || goto :ssuinner86
goto :ssuouter86
:ssuinner86
popd
for /f %%# in ('wimlib-imagex.exe dir "!_DIR!\%uups_esd1%" 3 --path=Windows\WinSxS\Manifests ^| find /i "x86_microsoft-windows-servicingstack_"') do (
wimlib-imagex.exe extract "!_DIR!\%uups_esd1%" 3 Windows\WinSxS\%%~n# --dest-dir="!_DIR!\_tSSU" --no-acls --no-attributes %_Nul3%
)
pushd "!_DIR!"
:ssuouter86
:DDCdual
for /f %%# in ('dir /b /ad "_tSSU\x86_microsoft-windows-servicingstack_*"') do set "src=%%#"
for %%# in (%_MSUdll%) do if exist "_tSSU\%src%\%%#" (move /y "_tSSU\%src%\%%#" "_tSSU\111\%%#" %_Nul1%)
call :crDDF %_MSUddd%
call :apDDF _tSSU\111
%_Nul3% makecab.exe /F zzz.ddf /D Compress=ON /D CompressionType=MSZIP
if %ERRORLEVEL% neq 0 (
    echo makecab.exe %_MSUddd% 操作失败，跳过该操作。
    set _mcfail=1
    exit /b
)
rmdir /s /q "_tSSU\" %_Nul3%
exit /b

:crDDF
echo.
echo 正在生成：%~nx1
(echo .Set DiskDirectoryTemplate="."
echo .Set CabinetNameTemplate="%1"
echo .Set MaxCabinetSize=0
echo .Set MaxDiskSize=0
echo .Set FolderSizeThreshold=0
echo .Set RptFileName=nul
echo .Set InfFileName=nul
echo .Set Cabinet=ON
)>zzz.ddf
exit /b

:apDDF
(echo .Set SourceDir="%1"
echo "dpx.dll"
echo "ReserveManager.dll"
echo "TurboStack.dll"
echo "UpdateAgent.dll"
echo "wcp.dll"
if exist "%1\UpdateCompression.dll" echo "UpdateCompression.dll"
)>>zzz.ddf
exit /b

:extract
if not exist "!_cabdir!\" mkdir "!_cabdir!"
set _cab=0
if %_build% geq 21382 if %UseMSU% equ 1 if exist "!_DIR!\*Windows1*-KB*.msu" for /f "tokens=* delims=" %%# in ('dir /b /on "!_DIR!\*Windows1*-KB*.msu"') do (set "package=%%#"&call :sum2msu)
if exist "!_DIR!\*defender-dism*%arch%*.cab" for /f "tokens=* delims=" %%# in ('dir /b "!_DIR!\*defender-dism*%arch%*.cab"') do (call set /a _cab+=1)
if exist "!_DIR!\SSU-*-*.cab" for /f "tokens=* delims=" %%# in ('dir /b /on "!_DIR!\SSU-*-*.cab"') do (call set /a _cab+=1)
if exist "!_DIR!\*Windows1*-KB*.wim" for /f "tokens=* delims=" %%# in ('dir /b /on "!_DIR!\*Windows1*-KB*.wim"') do (set "pkgn=%%~n#"&call :sum2cab)
if exist "!_DIR!\*Windows1*-KB*.cab" for /f "tokens=* delims=" %%# in ('dir /b /on "!_DIR!\*Windows1*-KB*.cab"') do (set "pkgn=%%~n#"&call :sum2cab)
set count=0&set isoupdate=
if %_build% geq 21382 if %UseMSU% equ 1 if exist "!_DIR!\*Windows1*-KB*.msu" for /f "tokens=* delims=" %%# in ('dir /b /on "!_DIR!\*Windows1*-KB*.msu"') do (set "pkgn=%%~n#"&set "package=%%#"&set "dest=!_cabdir!\%%~n#"&call :msu2)
if exist "!_DIR!\*defender-dism*%arch%*.cab" for /f "tokens=* delims=" %%# in ('dir /b "!_DIR!\*defender-dism*%arch%*.cab"') do (set "pkgn=%%~n#"&set "package=%%#"&set "dest=!_cabdir!\%%~n#"&call :cab2)
if exist "!_DIR!\SSU-*-*.cab" for /f "tokens=* delims=" %%# in ('dir /b /on "!_DIR!\SSU-*-*.cab"') do (set "pkgn=%%~n#"&set "package=%%#"&set "dest=!_cabdir!\%%~n#"&call :cab2)
if exist "!_DIR!\*Windows1*-KB*.wim" for /f "tokens=* delims=" %%# in ('dir /b /on "!_DIR!\*Windows1*-KB*.wim"') do (set "pkgn=%%~n#"&set "package=%%#"&set "dest=!_cabdir!\%%~n#"&call :cab2)
if exist "!_DIR!\*Windows1*-KB*.cab" for /f "tokens=* delims=" %%# in ('dir /b /on "!_DIR!\*Windows1*-KB*.cab"') do (set "pkgn=%%~n#"&set "package=%%#"&set "dest=!_cabdir!\%%~n#"&call :cab2)
goto :eof

:sum2msu
expand.exe -d -f:*Windows*.psf "!_DIR!\%package%" %_Nul2% | findstr /i %arch%\.psf %_Nul3% || (
    wimlib-imagex.exe dir "!_DIR!\%package%" %_Nul2% | findstr /i %arch%\.psf %_Nul3% || (
        for /f "tokens=* delims=" %%# in ('dir /b /on "!_DIR!\%package%"') do (set "pkgn=%%~n#"&set "package=%%#"&call :exd_msu&goto :eof)
    )
)
call set /a _cab+=1
goto :eof

:sum2cab
for /f "tokens=2 delims=-" %%V in ('echo %pkgn%') do set pkgid=%%V
set "uupmsu="
if %_build% geq 21382 if %UseMSU% equ 1 if exist "!_DIR!\*Windows1*%pkgid%*%arch%*.msu" for /f "tokens=* delims=" %%# in ('dir /b /on "!_DIR!\*Windows1*%pkgid%*%arch%*.msu"') do set "uupmsu=%%#"
if defined uupmsu (
    expand.exe -d -f:*Windows*.psf "!_DIR!\%uupmsu%" %_Nul2% | findstr /i %arch%\.psf %_Nul3% && goto :eof
    wimlib-imagex.exe dir "!_DIR!\%uupmsu%" %_Nul2% | findstr /i %arch%\.psf %_Nul3% && goto :eof
)
if exist "!_DIR!\*Windows1*%pkgid%*%arch%*.wim" set wim_%pkgn%=1
call set /a _cab+=1
goto :eof

:cab2
for /f "tokens=2 delims=-" %%V in ('echo %pkgn%') do set pkgid=%%V
set "uupmsu="
if %_build% geq 21382 if %UseMSU% equ 1 if exist "!_DIR!\*Windows1*%pkgid%*%arch%*.msu" for /f "tokens=* delims=" %%# in ('dir /b /on "!_DIR!\*Windows1*%pkgid%*%arch%*.msu"') do set "uupmsu=%%#"
if defined uupmsu (
    expand.exe -d -f:*Windows*.psf "!_DIR!\%uupmsu%" %_Nul2% | findstr /i %arch%\.psf %_Nul3% && goto :eof
    wimlib-imagex.exe dir "!_DIR!\%uupmsu%" %_Nul2% | findstr /i %arch%\.psf %_Nul3% && goto :eof
)
if defined cab_%pkgn% goto :eof
if exist "!dest!\" rmdir /s /q "!dest!\"
mkdir "!dest!"
set /a count+=1
if %count% equ 1 echo.
7z.exe e "!_DIR!\%package%" -o"!dest!" update.mum -aoa %_Nul3%
if not exist "!dest!\update.mum" (
    expand.exe -f:*defender*.xml "!_DIR!\%package%" "!dest!" %_Nul3%
    if exist "!dest!\*defender*.xml" (
        echo [%count%/%_cab%] %package%
        expand.exe -f:* "!_DIR!\%package%" "!dest!" %_Nul3%
    ) else (
        if not defined cab_%pkgn% echo [%count%/%_cab%] %package% [安装文件更新]
        set isoupdate=!isoupdate! "%package%"
        set cab_%pkgn%=1
        rmdir /s /q "!dest!\" %_Nul3%
    )
    goto :eof
)
7z.exe e "!_DIR!\%package%" -o"!dest!" *.psf.cix.xml -aoa %_Nul3%
if exist "!dest!\*.psf.cix.xml" (
    if not exist "!_DIR!\%pkgn%.psf" if not exist "!_DIR!\*%pkgid%*%arch%*.psf" (
        echo [%count%/%_cab%] %package% / PSF 文件丢失
        goto :eof
    )
    if %psfnet% equ 0 (
        echo [%count%/%_cab%] %package% / PSFExtractor 不可用
        goto :eof
    )
    set psf_%pkgn%=1
    set _psf=0
    if %_build% geq 25330 if exist "!_DIR!\*DesktopDeployment*.cab" (
        if /i %arch%==%xOS% set _psf=1
        if /i %arch%==x64 if /i %xOS%==amd64 set _psf=1
    )
    if !_psf! equ 1 (
        for /f "delims=" %%# in ('dir /b /a:-d "!_DIR!\*DesktopDeployment*.cab"') do expand.exe -f:UpdateCompression.dll "!_DIR!\%%#" .\temp %_Nul3%
        if exist "temp\UpdateCompression.dll" copy /y "bin\PSFExtractor.exe" "temp\" %_Nul3%&ren "temp\UpdateCompression.dll" "MSDelta.dll" %_Nul3%
    )
    if %_build% geq 25330 if not exist "bin\MSDelta.dll" if not exist "temp\MSDelta.dll" call :uups_psf
)
7z.exe e "!_DIR!\%package%" -o"!dest!" toc.xml -aoa %_Nul3%
if exist "!dest!\toc.xml" (
    echo [%count%/%_cab%] %package% [组合更新包]
    mkdir "!_cabdir!\lcu" %_Nul3%
    expand.exe -f:* "!_DIR!\%package%" "!_cabdir!\lcu" %_Nul3%
    if exist "!_cabdir!\lcu\SSU-*%arch%*.cab" for /f "tokens=* delims=" %%# in ('dir /b /on "!_cabdir!\lcu\SSU-*%arch%*.cab"') do (set "compkg=%%#"&call :inrenssu)
    if exist "!_cabdir!\lcu\*Windows1*-KB*.cab" for /f "tokens=* delims=" %%# in ('dir /b /on "!_cabdir!\lcu\*Windows1*-KB*.cab"') do (set "compkg=%%#"&call :inrenupd)
    rmdir /s /q "!_cabdir!\lcu\" %_Nul3%
    rmdir /s /q "!dest!\" %_Nul3%
    goto :eof
)
set _extsafe=0
set "_type="
if %_build% geq 17763 findstr /i /m "WinPE" "!dest!\update.mum" %_Nul3% && (
    %_Nul3% findstr /i /m "Edition\"" "!dest!\update.mum"
    if errorlevel 1 (set "_type=[WinPE]"&set _extsafe=1&set uwinpe=1)
)
if not defined _type set _extsafe=1
if %_extsafe% equ 1 (
7z.exe e "!_DIR!\%package%" -o"!dest!" *_microsoft-windows-sysreset_*.manifest -aoa %_Nul3%
if exist "!dest!\*_microsoft-windows-sysreset_*.manifest" findstr /i /m "Package_for_RollupFix" "!dest!\update.mum" %_Nul3% || (set "_type=[SafeOS 动态更新]"&set uwinpe=1)
)
if %_extsafe% equ 1 if not defined _type (
7z.exe e "!_DIR!\%package%" -o"!dest!" *_microsoft-windows-winpe_tools_*.manifest -aoa %_Nul3%
if exist "!dest!\*_microsoft-windows-winpe_tools_*.manifest" findstr /i /m "Package_for_RollupFix" "!dest!\update.mum" %_Nul3% || (set "_type=[SafeOS 动态更新]"&set uwinpe=1)
)
if %_extsafe% equ 1 if not defined _type (
7z.exe e "!_DIR!\%package%" -o"!dest!" *_microsoft-windows-winre-tools_*.manifest -aoa %_Nul3%
if exist "!dest!\*_microsoft-windows-winre-tools_*.manifest" findstr /i /m "Package_for_RollupFix" "!dest!\update.mum" %_Nul3% || (set "_type=[SafeOS 动态更新]"&set uwinpe=1)
)
if %_extsafe% equ 1 if not defined _type (
7z.exe e "!_DIR!\%package%" -o"!dest!" *_microsoft-windows-i..dsetup-rejuvenation_*.manifest -aoa %_Nul3%
if exist "!dest!\*_microsoft-windows-i..dsetup-rejuvenation_*.manifest" findstr /i /m "Package_for_RollupFix" "!dest!\update.mum" %_Nul3% || (set "_type=[SafeOS 动态更新]"&set uwinpe=1)
)
if not defined _type (
    findstr /i /m "Package_for_RollupFix" "!dest!\update.mum" %_Nul3% && (set "_type=[累积更新]"&set uwinpe=1)
)
if not defined _type (
    findstr /i /m "Package_for_WindowsExperienceFeaturePack" "!dest!\update.mum" %_Nul3% && set "_type=[功能体验包]"
)
if not defined _type (
    7z.exe e "!_DIR!\%package%" -o"!dest!" *_microsoft-windows-servicingstack_*.manifest -aoa %_Nul3%
    if exist "!dest!\*_microsoft-windows-servicingstack_*.manifest" set "_type=[服务堆栈更新]"&set uwinpe=1
)
if not defined _type (
    7z.exe e "!_DIR!\%package%" -o"!dest!" *_netfx4*.manifest -aoa %_Nul3%
    if exist "!dest!\*_netfx4*.manifest" findstr /i /m "Package_for_RollupFix" "!dest!\update.mum" %_Nul3% || set "_type=[NetFx]"
)
if not defined _type (
    7z.exe e "!_DIR!\%package%" -o"!dest!" *_microsoft-windows-s..boot-firmwareupdate_*.manifest -aoa %_Nul3%
    if exist "!dest!\*_microsoft-windows-s..boot-firmwareupdate_*.manifest" findstr /i /m "Package_for_RollupFix" "!dest!\update.mum" %_Nul3% || set "_type=[安全启动]"
)
if not defined _type if %_build% geq 18362 (
    7z.exe e "!_DIR!\%package%" -o"!dest!" microsoft-windows-*enablement-package~*.mum -aoa %_Nul3%
    if exist "!dest!\microsoft-windows-*enablement-package~*.mum" set "_type=[功能启用]"
)
if %_build% geq 18362 if exist "!dest!\*enablement-package*.mum" (
    7z.exe e "!_DIR!\%package%" -o"!dest!" *_microsoft-windows-e..-firsttimeinstaller_*.manifest -aoa %_Nul3%
    if exist "!dest!\*_microsoft-windows-e..-firsttimeinstaller_*.manifest" set "_type=[功能启用 / EdgeChromium]"
)
if not defined _type (
    7z.exe e "!_DIR!\%package%" -o"!dest!" *_microsoft-windows-e..-firsttimeinstaller_*.manifest -aoa %_Nul3%
    if exist "!dest!\*_microsoft-windows-e..-firsttimeinstaller_*.manifest" set "_type=[EdgeChromium]"
)
if not defined _type (
    7z.exe e "!_DIR!\%package%" -o"!dest!" *_adobe-flash-for-windows_*.manifest -aoa %_Nul3%
    if exist "!dest!\*_adobe-flash-for-windows_*.manifest" findstr /i /m "Package_for_RollupFix" "!dest!\update.mum" %_Nul3% || set "_type=[Flash]"
)
echo [%count%/%_cab%] %package% %_type%
set cab_%pkgn%=1
if not defined wim_%pkgn% expand.exe -f:* "!_DIR!\%package%" "!dest!" %_Nul3% || (
    rmdir /s /q "!dest!\" %_Nul3%
    set directcab=!directcab! %package%
    goto :eof
)
if defined wim_%pkgn% (
    wimlib-imagex.exe apply "!_DIR!\%package%" 1 "!dest!" --no-acls --no-attributes %_Nul3%
    if !errorlevel! neq 0 (
        echo 出现错误：解压 WIM 更新包失败
        rmdir /s /q "!dest!\" %_Nul3%
        set wim_%pkgn%=
        goto :eof
    )
)
7z.exe e "!_DIR!\%package%" -o"!dest!" update.mum -aoa %_Nul3%
if exist "!dest!\*cablist.ini" expand.exe -f:* "!dest!\*.cab" "!dest!" %_Nul3% || (
    rmdir /s /q "!dest!\" %_Nul3%
    set directcab=!directcab! %package%
    goto :eof
)
if exist "!dest!\*cablist.ini" (
    del /f /q "!dest!\*cablist.ini" %_Nul3%
    del /f /q "!dest!\*.cab" %_Nul3%
)
if defined psf_%pkgn% (
    if not exist "!dest!\express.psf.cix.xml" for /f %%# in ('dir /b /a:-d "!dest!\*.psf.cix.xml"') do rename "!dest!\%%#" express.psf.cix.xml %_Nul3%
    PSFExtractor.exe -v2 "!_DIR!\%pkgn%.psf" "!dest!\express.psf.cix.xml" "!dest!" %_Nul3%
    if !errorlevel! neq 0 (
        echo 出现错误：解压 PSF 更新包失败
        rmdir /s /q "!dest!\" %_Nul3%
        set psf_%pkgn%=
        goto :eof
    )
)
goto :eof

:msu2
if defined msu_%pkgn% goto :eof
if exist "!dest!\" rmdir /s /q "!dest!\"
mkdir "!dest!"
set msuwim=0
expand.exe -d -f:*Windows*.psf "!_DIR!\%package%" %_Nul2% | findstr /i %arch%\.psf %_Nul3% || (
wimlib-imagex.exe dir "!_DIR!\%package%" %_Nul2% | findstr /i %arch%\.psf %_Nul3% && (set msuwim=1) || (goto :eof)
)
set /a count+=1
if %count% equ 1 echo.
echo [%count%/%_cab%] %package% [组合累积更新]
mkdir "!_cabdir!\lcu" %_Nul3%
if %msuwim% equ 0 (
expand.exe -f:*Windows*.cab "!_DIR!\%package%" "!_cabdir!\lcu" %_Nul3%
expand.exe -f:SSU-*%arch%*.cab "!_DIR!\%package%" "!_cabdir!\lcu" %_Nul3%
) else (
wimlib-imagex.exe extract "!_DIR!\%package%" 1 *Windows*.wim --dest-dir="!_cabdir!\lcu" %_Nul3%
wimlib-imagex.exe extract "!_DIR!\%package%" 1 SSU-*%arch%*.cab --dest-dir="!_cabdir!\lcu" %_Nul3%
)
for /f "tokens=* delims=" %%# in ('dir /b /on "!_cabdir!\lcu\*Windows1*-KB*.*"') do set "compkg=%%#"
7z.exe e "!_cabdir!\lcu\%compkg%" -o"!dest!" update.mum -aoa %_Nul3%
if exist "!_cabdir!\lcu\SSU-*%arch%*.cab" for /f "tokens=* delims=" %%# in ('dir /b /on "!_cabdir!\lcu\SSU-*%arch%*.cab"') do (set "compkg=%%#"&call :inrenssu)
rmdir /s /q "!_cabdir!\lcu\" %_Nul3%
set msu_%pkgn%=1
goto :eof

:inrenupd
call set /a _cab+=1
if exist "!_DIR!\%compkg%" move /y "!_DIR!\%compkg%" "!_DIR!\%compkg%.bak"
move /y "!_cabdir!\lcu\%compkg%" "!_DIR!\%compkg%" %_Nul3%
for /f "tokens=* delims=" %%# in ('dir /b /on "!_DIR!\%compkg%"') do (set "pkgn=%%~n#"&set "package=%%#"&set "dest=!_cabdir!\%%~n#"&call :cab2)
goto :eof

:inrenssu
if exist "!_DIR!\%compkg:~0,-4%*.cab" goto :eof
call set /a _cab+=1
move /y "!_cabdir!\lcu\%compkg%" "!_DIR!\%compkg%" %_Nul3%
for /f "tokens=* delims=" %%# in ('dir /b /on "!_DIR!\%compkg%"') do (set "pkgn=%%~n#"&set "package=%%#"&set "dest=!_cabdir!\%%~n#"&call :cab2)
goto :eof

:uups_dpx
set _nat=0
set _wow=0
if /i %arch%==%xOS% set _nat=1
if /i %arch%==x64 if /i %xOS%==amd64 set _nat=1
if %_nat% equ 0 set _wow=1
set msuwim=0
set "uupmsu="
if exist "!_DIR!\*Windows1*-KB*.msu" for /f "tokens=* delims=" %%# in ('dir /b /on "!_DIR!\*Windows1*-KB*.msu"') do (
expand.exe -d -f:*Windows*.psf "!_DIR!\%%#" %_Nul2% | findstr /i %arch%\.psf %_Nul3% && (set "uupmsu=%%#")
wimlib-imagex.exe dir "!_DIR!\%%#" %_Nul2% | findstr /i %arch%\.psf %_Nul3% && (set "uupmsu=%%#"&set msuwim=1)
)
if defined uupmsu if %msuwim% equ 0 (
if %_wow% equ 1 expand.exe -f:DesktopDeployment_x86.cab "!_DIR!\%uupmsu%" .\temp %_Nul3%
if %_nat% equ 1 expand.exe -f:DesktopDeployment.cab "!_DIR!\%uupmsu%" .\temp %_Nul3%
)
if defined uupmsu if %msuwim% equ 1 (
if %_wow% equ 1 wimlib-imagex.exe extract "!_DIR!\%uupmsu%" 1 DesktopDeployment_x86.cab --dest-dir=.\temp %_Nul3%
if %_nat% equ 1 wimlib-imagex.exe extract "!_DIR!\%uupmsu%" 1 DesktopDeployment.cab --dest-dir=.\temp %_Nul3%
)
if %_wow% equ 1 (
if exist "temp\DesktopDeployment_x86.cab" (expand.exe -f:dpx.dll "temp\DesktopDeployment_x86.cab" .\temp %_Nul3%) else (wimlib-imagex.exe extract "!_DIR!\%uups_esd1%" 3 Windows\SysWOW64\dpx.dll --dest-dir=.\temp --no-acls --no-attributes %_Nul3%)
if exist "temp\dpx.dll" copy /y %SystemRoot%\SysWOW64\expand.exe temp\ %_Nul3%
)
if %_nat% equ 1 (
if exist "temp\DesktopDeployment.cab" (expand.exe -f:dpx.dll "temp\DesktopDeployment.cab" .\temp %_Nul3%) else (wimlib-imagex.exe extract "!_DIR!\%uups_esd1%" 3 Windows\System32\dpx.dll --dest-dir=.\temp --no-acls --no-attributes %_Nul3%)
if exist "temp\dpx.dll" copy /y %SysPath%\expand.exe temp\ %_Nul3%
)
exit /b

:uups_psf
set _nat=0
set _wow=0
if /i %arch%==%xOS% set _nat=1
if /i %arch%==x64 if /i %xOS%==amd64 set _nat=1
if %_nat% equ 0 set _wow=1
set msuwim=0
set "uupmsu="
if exist "!_DIR!\*Windows1*-KB*.msu" for /f "tokens=* delims=" %%# in ('dir /b /on "!_DIR!\*Windows1*-KB*.msu"') do (
expand.exe -d -f:*Windows*.psf "!_DIR!\%%#" %_Nul2% | findstr /i %arch%\.psf %_Nul3% && (set "uupmsu=%%#")
wimlib-imagex.exe dir "!_DIR!\%%#" %_Nul2% | findstr /i %arch%\.psf %_Nul3% && (set "uupmsu=%%#"&set msuwim=1)
)
if defined uupmsu if %msuwim% equ 0 (
if %_wow% equ 1 expand.exe -f:DesktopDeployment_x86.cab "!_DIR!\%uupmsu%" .\temp %_Nul3%
if %_nat% equ 1 expand.exe -f:DesktopDeployment.cab "!_DIR!\%uupmsu%" .\temp %_Nul3%
)
if defined uupmsu if %msuwim% equ 1 (
if %_wow% equ 1 wimlib-imagex.exe extract "!_DIR!\%uupmsu%" 1 DesktopDeployment_x86.cab --dest-dir=.\temp %_Nul3%
if %_nat% equ 1 wimlib-imagex.exe extract "!_DIR!\%uupmsu%" 1 DesktopDeployment.cab --dest-dir=.\temp %_Nul3%
)
if %_wow% equ 1 (
if exist "temp\DesktopDeployment_x86.cab" (expand.exe -f:UpdateCompression.dll "temp\DesktopDeployment_x86.cab" .\temp %_Nul3%) else (wimlib-imagex.exe extract "!_DIR!\%uups_esd1%" 3 Windows\SysWOW64\UpdateCompression.dll --dest-dir=.\temp --no-acls --no-attributes %_Nul3%)
    if exist "temp\UpdateCompression.dll" copy /y "bin\PSFExtractor.*" "temp\" %_Nul3%&ren "temp\UpdateCompression.dll" "MSDelta.dll" %_Nul3%
)
if %_nat% equ 1 (
if exist "temp\DesktopDeployment.cab" (expand.exe -f:UpdateCompression.dll "temp\DesktopDeployment.cab" .\temp %_Nul3%) else (wimlib-imagex.exe extract "!_DIR!\%uups_esd1%" 3 Windows\System32\UpdateCompression.dll --dest-dir=.\temp --no-acls --no-attributes %_Nul3%)
    if exist "temp\UpdateCompression.dll" copy /y "bin\PSFExtractor.*" "temp\" %_Nul3%&ren "temp\UpdateCompression.dll" "MSDelta.dll" %_Nul3%
)
exit /b

:updatewim
set SOFTWARE=uiSOFTWARE
set COMPONENTS=uiCOMPONENTS
set "_Wnn=HKLM\%SOFTWARE%\Microsoft\Windows\CurrentVersion\SideBySide\Winners"
set "_Cmp=HKLM\%COMPONENTS%\DerivedData\Components"
if exist "%_mount%\Windows\Servicing\Packages\*~arm64~~*.mum" (
set "xBT=arm64"
set "_EsuKey=%_Wnn%\arm64_%_EsuCmp%_%_Pkt%_none_0a035f900ca87ee9"
set "_EdgKey=%_Wnn%\arm64_%_EdgCmp%_%_Pkt%_none_1e5e2b2c8adcf701"
set "_CedKey=%_Wnn%\arm64_%_CedCmp%_%_Pkt%_none_df3eefecc502346d"
) else if exist "%_mount%\Windows\Servicing\Packages\*~amd64~~*.mum" (
set "xBT=amd64"
set "_EsuKey=%_Wnn%\amd64_%_EsuCmp%_%_Pkt%_none_0a0357560ca88a4d"
set "_EdgKey=%_Wnn%\amd64_%_EdgCmp%_%_Pkt%_none_1e5e22f28add0265"
set "_CedKey=%_Wnn%\amd64_%_CedCmp%_%_Pkt%_none_df3ee7b2c5023fd1"
) else (
set "xBT=x86"
set "_EsuKey=%_Wnn%\x86_%_EsuCmp%_%_Pkt%_none_ade4bbd2544b1917"
set "_EdgKey=%_Wnn%\x86_%_EdgCmp%_%_Pkt%_none_c23f876ed27f912f"
set "_CedKey=%_Wnn%\x86_%_CedCmp%_%_Pkt%_none_83204c2f0ca4ce9b"
)
for /f "tokens=4,5,6 delims=_" %%H in ('dir /b "%_mount%\Windows\WinSxS\Manifests\%xBT%_microsoft-windows-foundation_*.manifest"') do set "_Fnd=microsoft-w..-foundation_%_Pkt%_%%H_%%~nJ"
set lcumsu=
set mpamfe=
set servicingstack=
set cumulative=
set netupdt=
set netpack=
set netroll=
set netlcu=
set netmsu=
set secureboot=
set edge=
set safeos=
set callclean=
set fupdt=
set supdt=
set cupdt=
set dupdt=
set overall=
set lcupkg=
set ldr=
set mounterr=
if exist "!_DIR!\SSU-*-*.cab" for /f "tokens=* delims=" %%# in ('dir /b /on "!_DIR!\SSU-*-*.cab"') do (set "pckn=%%~n#"&set "packx=%%~x#"&set "package=%%#"&set "dest=!_cabdir!\%%~n#"&call :procmum)
if exist "!_DIR!\*Windows1*-KB*.wim" for /f "tokens=* delims=" %%# in ('dir /b /on "!_DIR!\*Windows1*-KB*.wim"') do (set "pckn=%%~n#"&set "packx=%%~x#"&set "package=%%#"&set "dest=!_cabdir!\%%~n#"&call :procmum)
if exist "!_DIR!\*Windows1*-KB*.cab" for /f "tokens=* delims=" %%# in ('dir /b /on "!_DIR!\*Windows1*-KB*.cab"') do (set "pckn=%%~n#"&set "packx=%%~x#"&set "package=%%#"&set "dest=!_cabdir!\%%~n#"&call :procmum)
if %_build% geq 21382 if %UseMSU% equ 1 if exist "!_DIR!\*Windows1*-KB*.msu" (for /f "tokens=* delims=" %%# in ('dir /b /on "!_DIR!\*Windows1*-KB*.msu"') do if defined msu_%%~n# (set "pckn=%%~n#"&set "packx=%%~x#"&set "package=%%#"&set "dest=!_cabdir!\%%~n#"&call :procmum))
if not exist "%_mount%\Windows\Servicing\Packages\*WinPE-LanguagePack*.mum" if exist "!_DIR!\*defender-dism*%arch%*.cab" (for /f "tokens=* delims=" %%# in ('dir /b "!_DIR!\*defender-dism*%arch%*.cab"') do (set "pckn=%%~n#"&set "packx=%%~x#"&set "package=%%#"&set "dest=!_cabdir!\%%~n#"&call :procmum))
if %_build% geq 19041 if %winbuild% lss 17133 if not exist "%SysPath%\ext-ms-win-security-slc-l1-1-0.dll" (
    copy /y %SysPath%\slc.dll %SysPath%\ext-ms-win-security-slc-l1-1-0.dll %_Nul1%
    if /i not %xOS%==x86 copy /y %SystemRoot%\SysWOW64\slc.dll %SystemRoot%\SysWOW64\ext-ms-win-security-slc-l1-1-0.dll %_Nul1%
)
if not exist "%_mount%\Windows\Servicing\Packages\*WinPE-LanguagePack*.mum" (
    reg.exe load HKLM\%SOFTWARE% "%_mount%\Windows\System32\Config\SOFTWARE" %_Nul1%
    if %winbuild% lss 15063 if /i %arch%==arm64 reg.exe add HKLM\%SOFTWARE%\Microsoft\Windows\CurrentVersion\SideBySide /v AllowImproperDeploymentProcessorArchitecture /t REG_DWORD /d 1 /f %_Nul1%
    if %winbuild% lss 9600 reg.exe add HKLM\%SOFTWARE%\Microsoft\Windows\CurrentVersion\SideBySide /v AllowImproperDeploymentProcessorArchitecture /t REG_DWORD /d 1 /f %_Nul
    reg.exe save HKLM\%SOFTWARE% "%_mount%\Windows\System32\Config\SOFTWARE2" %_Nul1%
    reg.exe unload HKLM\%SOFTWARE% %_Nul1%
    move /y "%_mount%\Windows\System32\Config\SOFTWARE2" "%_mount%\Windows\System32\Config\SOFTWARE" %_Nul1%
)
if exist "%_mount%\Windows\Servicing\Packages\*WinPE-LanguagePack*.mum" if /i not %arch%==arm64 (
    reg.exe load HKLM\%SOFTWARE% "%_mount%\Windows\System32\Config\SOFTWARE" %_Nul1%
    reg.exe add HKLM\%SOFTWARE%\%_SxsCfg% /v DisableComponentBackups /t REG_DWORD /d 1 /f %_Nul1%
    reg.exe unload HKLM\%SOFTWARE% %_Nul1%
)
if defined netpack set "ldr=!netpack! !ldr!"
for %%# in (dupdt,cupdt,supdt,fupdt,safeos,secureboot,edge,ldr,cumulative,lcumsu) do if defined %%# set overall=1
if not defined overall if not defined mpamfe if not defined servicingstack goto :eof
if defined servicingstack (
    set idpkg=ServicingStack
    set callclean=1
    %_Dism% /LogPath:"%_dLog%\DismSSU.log" /Image:"%_mount%" /Add-Package %servicingstack%
    cmd /c exit /b !errorlevel!
    call :chkEC "!=ExitCode!"
    if !_ec!==1 goto :errmount
    if not defined overall call :cleanup
)
if not defined overall if not defined mpamfe goto :eof
if not exist "%_mount%\Windows\Servicing\Packages\*WinRE-Package*.mum" goto :skipsafeos
if not defined safeos if %LCUWinRE% equ 0 (
    %_Dism% /LogPath:"%_dLog%\DismUnMount.log" /Unmount-Wim /MountDir:"%_mount%" /Discard
    goto :%_rtrn%
)
if defined safeos (
    set idpkg=SafeOS
    set callclean=1
    %_Dism% /LogPath:"%_dLog%\DismWinRE.log" /Image:"%_mount%" /Add-Package %safeos%
    cmd /c exit /b !errorlevel!
    call :chkEC "!=ExitCode!"
    if !_ec!==1 goto :errmount
    if not defined lcumsu call :cleanup
    if not defined lcumsu if %ResetBase% neq 0 %_Dism% /LogPath:"%_dLog%\DismClean.log" /Image:"%_mount%" /Cleanup-Image /StartComponentCleanup /ResetBase %_Nul3%
    if %LCUWinRE% equ 0 goto :eof
)
:skipsafeos
if not defined cumulative if not defined lcumsu goto :scbt
set _gobk=scbt
if exist "%_mount%\Windows\Servicing\Packages\*WinPE-LanguagePack*.mum" goto :updtlcu
:scbt
if defined secureboot (
    set idpkg=SecureBoot
    set callclean=1
    %_Dism% /LogPath:"%_dLog%\DismSecureBoot.log" /Image:"%_mount%" /Add-Package %secureboot%
    cmd /c exit /b !errorlevel!
    call :chkEC "!=ExitCode!"
    if !_ec!==1 goto :errmount
)
if defined ldr (
    set idpkg=General
    set callclean=1
    %_Dism% /LogPath:"%_dLog%\DismUpdt.log" /Image:"%_mount%" /Add-Package %ldr%
    cmd /c exit /b !errorlevel!
    call :chkEC "!=ExitCode!"
    if !_ec!==1 if not exist "%_mount%\Windows\Servicing\Packages\*WinPE-LanguagePack*.mum" goto :errmount
)
if defined fupdt (
    set "_SxsKey=%_EdgKey%"
    set "_SxsCmp=%_EdgCmp%"
    set "_SxsIdn=%_EdgIdn%"
    set "_SxsCF=256"
    set "_DsmLog=DismEdge.log"
    for %%# in (%fupdt%) do (set "cbsn=%%~n#"&set "dest=!_cabdir!\%%~n#"&call :pXML)
)
if defined supdt (
    set "_SxsKey=%_EsuKey%"
    set "_SxsCmp=%_EsuCmp%"
    set "_SxsIdn=%_EsuIdn%"
    set "_SxsCF=64"
    set "_DsmLog=DismLCUs.log"
    for %%# in (%supdt%) do (set "cbsn=%%~n#"&set "dest=!_cabdir!\%%~n#"&call :pXML)
)
if defined cupdt (
    set "_SxsKey=%_CedKey%"
    set "_SxsCmp=%_CedCmp%"
    set "_SxsIdn=%_CedIdn%"
    set "_SxsCF=256"
    set "_DsmLog=DismLCUs.log"
    for %%# in (%cupdt%) do (set "cbsn=%%~n#"&set "dest=!_cabdir!\%%~n#"&call :pXML)
)
set _dualSxS=
if defined dupdt (
    set _dualSxS=1
    set "_SxsKey=%_EsuKey%"
    set "_SxsCmp=%_EsuCmp%"
    set "_SxsIdn=%_EsuIdn%"
    set "_SxsCF=64"
    set "_DsmLog=DismLCUs.log"
    for %%# in (%dupdt%) do (set "cbsn=%%~n#"&set "dest=!_cabdir!\%%~n#"&call :pXML)
)
if not defined cumulative if not defined lcumsu goto :cuwd
set _gobk=cuwd
if not exist "%_mount%\Windows\Servicing\Packages\*WinPE-LanguagePack*.mum" goto :updtlcu
:cuwd
if defined lcupkg call :ReLCU
if defined callclean call :cleanup
if defined mpamfe (
    echo.
    echo 正在添加 Defender 更新……
    call :defender_update
)
if not defined edge goto :eof
if defined edge (
    set idpkg=Edge
    %_Dism% /LogPath:"%_dLog%\DismEdge.log" /Image:"%_mount%" /Add-Package %edge%
    cmd /c exit /b !errorlevel!
    call :chkEC "!=ExitCode!"
    if !_ec!==1 goto :errmount
)
goto :eof

:updtlcu
set "_DsmLog=DismLCU.log"
if exist "%_mount%\Windows\Servicing\Packages\*WinPE-LanguagePack*.mum" set "_DsmLog=DismLCUBoot.log"
if exist "%_mount%\Windows\Servicing\Packages\*WinRE-Package*.mum" set "_DsmLog=DismLCUWinRE.log"
set idpkg=LCU
set callclean=1
if defined cumulative %_Dism% /LogPath:"%_dLog%\%_DsmLog%" /Image:"%_mount%" /Add-Package %cumulative%
if defined lcumsu for %%# in (%lcumsu%) do (
    echo.&echo %%#
    %_Dism% /LogPath:"%_dLog%\%_DsmLog%" /Image:"%_mount%" /Add-Package /PackagePath:"!_DIR!\%%#
)
cmd /c exit /b !errorlevel!
call :chkEC "!=ExitCode!"
if !_ec!==1 if not exist "%_mount%\Windows\Servicing\Packages\*WinPE-LanguagePack*.mum" goto :errmount
if exist "%_mount%\Windows\Servicing\Packages\*WinPE-LanguagePack*.mum" if %LCUWinRE% equ 1 call :cleanup
if exist "%_mount%\Windows\Servicing\Packages\*WinPE-LanguagePack*.mum" goto :%_gobk%
if not exist "%_mount%\Windows\Servicing\Packages\Package_for_RollupFix*.mum" goto :%_gobk%
for /f %%# in ('dir /b /a:-d /od "%_mount%\Windows\Servicing\Packages\Package_for_RollupFix*.mum"') do set "lcumum=%%#"
if defined lcumsu if %_build% geq 22621 if exist "!_cabdir!\LCU.mum" (
    %_Nul3% icacls "%_mount%\Windows\Servicing\Packages\%lcumum%" /save "!_cabdir!\acl.txt"
    %_Nul3% takeown /f "%_mount%\Windows\Servicing\Packages\%lcumum%" /A
    %_Nul3% icacls "%_mount%\Windows\Servicing\Packages\%lcumum%" /grant *S-1-5-32-544:F
    %_Nul3% copy /y "!_cabdir!\LCU.mum" "%_mount%\Windows\Servicing\Packages\%lcumum%"
    %_Nul3% icacls "%_mount%\Windows\Servicing\Packages\%lcumum%" /setowner *S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464
    %_Nul3% icacls "%_mount%\Windows\Servicing\Packages" /restore "!_cabdir!\acl.txt"
    %_Nul3% del /f /q "!_cabdir!\acl.txt"
)
goto :%_gobk%

:chkEC
set _ec=0
set "_ic=%~1"
if /i not "!_ic!"=="00000000" if /i not "!_ic!"=="800f081e" if /i not "!_ic!"=="800706be" if /i not "!_ic!"=="800706ba" set _ec=1
if /i not "!_ic!"=="00000000" if /i not "!_ic!"=="800f081e" if !_ec!==0 %_Dism% /LogPath:"%_dLog%\DismNUL.log" /Image:"%_mount%" /Get-Packages %_Nul3%
goto :eof

:errmount
set mounterr=1
set "msgerr=Dism.exe 操作失败"
if defined idpkg set "msgerr=Dism.exe 添加 %idpkg% 更新失败"
echo %msgerr%。正在丢弃当前挂载镜像……
%_Dism% /LogPath:"%_dLog%\DismNUL.log" /Image:"%_mount%" /Get-Packages %_Nul3%
%_Dism% /LogPath:"%_dLog%\DismUnMount.log" /Unmount-Wim /MountDir:"%_mount%" /Discard
Dism.exe /Cleanup-Wim %_Nul3%
goto :eof
rmdir /s /q "%_mount%\" %_Nul3%
set AddUpdates=0
set FullExit=exit
goto :%_rtrn%

:ReLCU
if exist "!lcudir!\update.mum" if exist "!lcudir!\*.manifest" goto :eof
if not exist "!lcudir!\" mkdir "!lcudir!"
expand.exe -f:* "!_DIR!\%lcupkg%" "!lcudir!" %_Nul3%
7z.exe e "!_DIR!\%lcupkg%" -o"!lcudir!" update.mum -aoa %_Nul3%
if exist "!lcudir!\*cablist.ini" (
    expand.exe -f:* "!lcudir!\*.cab" "!lcudir!" %_Nul3%
    del /f /q "!lcudir!\*cablist.ini" %_Nul3%
    del /f /q "!lcudir!\*.cab" %_Nul3%
)
if exist "!lcudir!\*.psf.cix.xml" (
    if not exist "!lcudir!\express.psf.cix.xml" for /f %%# in ('dir /b /a:-d "!lcudir!\*.psf.cix.xml"') do rename "!lcudir!\%%#" express.psf.cix.xml %_Nul3%
    PSFExtractor.exe -v2 "!_DIR!\%pkgn%.psf" "!dest!\express.psf.cix.xml" "!lcudir!" %_Nul3%
    if !errorlevel! neq 0 (
        echo 出现错误：解压 PSF 更新包失败
        rmdir /s /q "!dest!\" %_Nul3%
        set psf_%pkgn%=
        goto :eof
    )
)
goto :eof

:procmum
if exist "!dest!\*.psf.cix.xml" if not defined psf_%pckn% goto :eof
if exist "!dest!\*defender*.xml" (
    if exist "%_mount%\Windows\Servicing\Packages\*WinPE-LanguagePack*.mum" goto :eof
    call :defender_check
    goto :eof
)
if not exist "!dest!\update.mum" (
    if /i "!lcupkg!"=="%package%" call :ReLCU
)
set _dcu=0
if not exist "!dest!\update.mum" (
    for %%# in (%directcab%) do if /i "%package%"=="%%~#" set _dcu=1
    if "!_dcu!"=="0" goto :eof
)
set xmsu=0
if /i "%packx%"==".msu" set xmsu=1
for /f "tokens=2 delims=-" %%V in ('echo %pckn%') do set pckid=%%V
set "uupmsu="
if %xmsu% equ 0 if %_build% geq 21382 if %UseMSU% equ 1 if exist "!_DIR!\*Windows1*%pckid%*%arch%*.msu" for /f "tokens=* delims=" %%# in ('dir /b /on "!_DIR!\*Windows1*%pckid%*%arch%*.msu"') do (
set "uupmsu=%%#"
)
if defined uupmsu (
    expand.exe -d -f:*Windows*.psf "!_DIR!\%uupmsu%" %_Nul2% | findstr /i %arch%\.psf %_Nul3% && goto :eof
    wimlib-imagex.exe dir "!_DIR!\%uupmsu%" %_Nul2% | findstr /i %arch%\.psf %_Nul3% && goto :eof
)
if %_build% geq 20348 if exist "!dest!\update.mum" if not exist "%_mount%\Windows\Servicing\Packages\*WinPE-LanguagePack*.mum" (
findstr /i /m "Package_for_RollupFix" "!dest!\update.mum" %_Nul3% || (findstr /i /m "Microsoft-Windows-NetFx" "!dest!\package_1_for*.mum" %_Nul3% && (
        if exist "!dest!\*_microsoft-windows-n..35wpfcomp.resources*.manifest" (set "netupdt=!netupdt! /PackagePath:!dest!\update.mum"&goto :eof)
    ))
)
if %_build% geq 17763 if exist "!dest!\update.mum" if not exist "%_mount%\Windows\Servicing\Packages\*WinPE-LanguagePack*.mum" (
    findstr /i /m "Package_for_RollupFix" "!dest!\update.mum" %_Nul3% || (findstr /i /m "Microsoft-Windows-NetFx" "!dest!\*.mum" %_Nul3% && (
        if not exist "!dest!\*_netfx4clientcorecomp.resources*.manifest" if not exist "!dest!\*_netfx4-netfx_detectionkeys_extended*.manifest" if not exist "!dest!\*_microsoft-windows-n..35wpfcomp.resources*.manifest" (if exist "!dest!\*_*10.0.*.manifest" (set "netroll=!netroll! /PackagePath:!dest!\update.mum") else (if exist "!dest!\*_*11.0.*.manifest" set "netroll=!netroll! /PackagePath:!dest!\update.mum"))
        ))
    findstr /i /m "Package_for_OasisAsset" "!dest!\update.mum" %_Nul3% && (if not exist "%_mount%\Windows\Servicing\packages\*OasisAssets-Package*.mum" goto :eof)
    findstr /i /m "WinPE" "!dest!\update.mum" %_Nul3% && (
        %_Nul3% findstr /i /m "Edition\"" "!dest!\update.mum"
    if errorlevel 1 goto :eof
    )
)
if %_build% geq 19041 if exist "!dest!\update.mum" if not exist "%_mount%\Windows\Servicing\Packages\*WinPE-LanguagePack*.mum" (
    findstr /i /m "Package_for_WindowsExperienceFeaturePack" "!dest!\update.mum" %_Nul3% && (
        if not exist "%_mount%\Windows\Servicing\packages\Microsoft-Windows-UserExperience-Desktop*.mum" goto :eof
        set fxupd=0
        for /f "tokens=3 delims== " %%# in ('findstr /i "Edition" "!dest!\update.mum" %_Nul6%') do if exist "%_mount%\Windows\Servicing\packages\%%~#*.mum" set fxupd=1
        if "!fxupd!"=="0" goto :eof
    )
)
if exist "!dest!\*_microsoft-windows-servicingstack_*.manifest" (
    set "servicingstack=!servicingstack! /PackagePath:!dest!\update.mum"
    goto :eof
)
if exist "!dest!\*_netfx4-netfx_detectionkeys_extended*.manifest" (
    if exist "%_mount%\Windows\Servicing\Packages\*WinPE-LanguagePack*.mum" goto :eof
    set "netpack=!netpack! /PackagePath:!dest!\update.mum"
    goto :eof
)
if exist "!dest!\*_%_EdgCmp%_*.manifest" findstr /i /m "Package_for_RollupFix" "!dest!\update.mum" %_Nul3% || (
    if exist "%_mount%\Windows\Servicing\Packages\*WinPE-LanguagePack*.mum" goto :eof
    if exist "!dest!\*enablement-package*.mum" (
        for /f %%# in ('dir /b /a:-d "!dest!\*enablement-package~*.mum"') do set "ldr=!ldr! /PackagePath:!dest!\%%#"
        set "edge=!edge! /PackagePath:!dest!\update.mum"
    )
    if not exist "!dest!\*enablement-package*.mum" set "edge=!edge! /PackagePath:!dest!\update.mum"
    goto :eof
)
if exist "!dest!\*_microsoft-windows-sysreset_*.manifest" findstr /i /m "Package_for_RollupFix" "!dest!\update.mum" %_Nul3% || (
    if not exist "%_mount%\Windows\Servicing\Packages\WinPE-SRT-Package~*.mum" goto :eof
    set "safeos=!safeos! /PackagePath:!dest!\update.mum"
    goto :eof
)
if exist "!dest!\*_microsoft-windows-winre-tools_*.manifest" if not exist "!dest!\*_microsoft-windows-sysreset_*.manifest" findstr /i /m "Package_for_RollupFix" "!dest!\update.mum" %_Nul3% || (
    if not exist "!mumtarget!\Windows\Servicing\Packages\WinPE-SRT-Package~*.mum" goto :eof
    set "safeos=!safeos! /PackagePath:!dest!\update.mum"
    goto :eof
)
if exist "!dest!\*_microsoft-windows-i..dsetup-rejuvenation_*.manifest" if not exist "!dest!\*_microsoft-windows-sysreset_*.manifest" if not exist "!dest!\*_microsoft-windows-winre-tools_*.manifest" findstr /i /m "Package_for_RollupFix" "!dest!\update.mum" %_Nul3% || (
    if not exist "%_mount%\Windows\Servicing\Packages\WinPE-Rejuv-Package~*.mum" goto :eof
    set "safeos=!safeos! /PackagePath:!dest!\update.mum"
    goto :eof
)
if exist "!dest!\*_microsoft-windows-s..boot-firmwareupdate_*.manifest" findstr /i /m "Package_for_RollupFix" "!dest!\update.mum" %_Nul3% || (
    if exist "%_mount%\Windows\Servicing\Packages\*WinPE-LanguagePack*.mum" goto :eof
    if %winbuild% lss 9600 goto :eof
    set secureboot=!secureboot! /PackagePath:"!_DIR!\%package%"
    goto :eof
)
if exist "!dest!\update.mum" if exist "%_mount%\Windows\Servicing\Packages\*WinPE-LanguagePack*.mum" (
    findstr /i /m "WinPE" "!dest!\update.mum" %_Nul3% || (findstr /i /m "Package_for_RollupFix" "!dest!\update.mum" %_Nul3% || (goto :eof))
    findstr /i /m "WinPE-NetFx-Package" "!dest!\update.mum" %_Nul3% && (findstr /i /m "Package_for_RollupFix" "!dest!\update.mum" %_Nul3% || (goto :eof))
)
if exist "!dest!\*_adobe-flash-for-windows_*.manifest" if not exist "!dest!\*enablement-package*.mum" findstr /i /m "Package_for_RollupFix" "!dest!\update.mum" %_Nul3% || (
    if not exist "%_mount%\Windows\Servicing\packages\Adobe-Flash-For-Windows-Package*.mum" if not exist "%_mount%\Windows\Servicing\packages\Microsoft-Windows-Client-Desktop-Required-Package*.mum" goto :eof
    if %_build% geq 16299 (
        set flash=0
        for /f "tokens=3 delims== " %%# in ('findstr /i "Edition" "!dest!\update.mum" %_Nul6%') do if exist "%_mount%\Windows\Servicing\packages\%%~#*.mum" set flash=1
        if "!flash!"=="0" goto :eof
    )
)
if exist "!dest!\*enablement-package*.mum" (
    set epkb=0
    for /f "tokens=3 delims== " %%# in ('findstr /i "Edition" "!dest!\update.mum" %_Nul6%') do if exist "%_mount%\Windows\Servicing\packages\%%~#*.mum" set epkb=1
    if exist "%_mount%\Windows\Servicing\Packages\*WinPE-LanguagePack*.mum" findstr /i /m "WinPE" "!dest!\update.mum" %_Nul3% && set epkb=1
    if "!epkb!"=="0" goto :eof
)
for %%# in (%directcab%) do (
    if /i "%package%"=="%%~#" (
        set "cumulative=!cumulative! /PackagePath:"!_DIR!\%package%""
        goto :eof
    )
)
if exist "!dest!\update.mum" findstr /i /m "Package_for_RollupFix" "!dest!\update.mum" %_Nul3% && (
    if %_build% geq 20231 if %xmsu% equ 0 (
        set "lcudir=!dest!"
        set "lcupkg=%package%"
    )
    if exist "%_mount%\Windows\Servicing\Packages\*WinPE-LanguagePack*.mum" (
        if %xmsu% equ 1 (set "lcumsu=!lcumsu! %package%") else (set "cumulative=!cumulative! /PackagePath:!dest!\update.mum")
        goto :eof
    )
    if %xmsu% equ 1 (
        set "lcumsu=!lcumsu! %package%"
        set "netmsu=!netmsu! %package%"
        goto :eof
    ) else (
        set "netlcu=!netlcu! /PackagePath:!dest!\update.mum"
    )
    if exist "!dest!\*_%_EsuCmp%_*.manifest" if not exist "!dest!\*_%_CedCmp%_*.manifest" set "supdt=!supdt! %package%"&goto :eof
    if exist "!dest!\*_%_EsuCmp%_*.manifest" if exist "!dest!\*_%_CedCmp%_*.manifest" set "supdt=!supdt! %package%"&goto :eof
    set "cumulative=!cumulative! /PackagePath:!dest!\update.mum"
    goto :eof
)
if exist "%_mount%\Windows\Servicing\Packages\*WinPE-LanguagePack*.mum" (
    set "ldr=!ldr! /PackagePath:!dest!\update.mum"
    goto :eof
)
if exist "!dest!\*_%_EsuCmp%_*.manifest" set "supdt=!supdt! %package%"&goto :eof
set "ldr=!ldr! /PackagePath:!dest!\update.mum"
goto :eof

:defender_check
if %_skpp% equ 1 if %_skpd% equ 1 (set /a _sum-=1&goto :eof)
set "_MWD=ProgramData\Microsoft\Windows Defender"
if not exist "%_mount%\%_MWD%\Definition Updates\Updates\*.vdm" (set "mpamfe=!dest!"&goto :eof)
if %_skpp% equ 0 dir /b /ad "%_mount%\%_MWD%\Platform\*.*.*.*" %_Nul3% && (
    if not exist "!_cabdir!\*defender*.xml" expand.exe -f:*defender*.xml "!_DIR!\%package%" "!_cabdir!" %_Nul3%
    for /f %%i in ('dir /b /a:-d "!_cabdir!\*defender*.xml"') do for /f "tokens=3 delims=<> " %%# in ('type "!_cabdir!\%%i" ^| find /i "platform"') do (
        dir /b /ad "%_mount%\%_MWD%\Platform\%%#*" %_Nul3% && set _skpp=1
    )
)
set "_ver1j=0"&set "_ver1n=0"
set "_ver2j=0"&set "_ver2n=0"
set "_fil1=%_mount%\%_MWD%\Definition Updates\Updates\mpavdlta.vdm"
set "_fil2=!_cabdir!\mpavdlta.vdm"
set "cfil1=!_fil1:\=\\!"
set "cfil2=!_fil2:\=\\!"
if %_skpd% equ 0 if exist "!_fil1!" (
    if %_cwmi% equ 1 for /f "tokens=3,4 delims==." %%a in ('wmic datafile where "name='!cfil1!'" get Version /value ^| find "="') do set "_ver1j=%%a"&set "_ver1n=%%b"
    if %_cwmi% equ 0 for /f "tokens=2,3 delims=." %%a in ('powershell -nop -c "([WMI]'CIM_DataFile.Name=''!cfil1!\''').Version"') do set "_ver1j=%%a"&set "_ver1n=%%b"
    expand.exe -i -f:mpavdlta.vdm "!_DIR!\%package%" "!_cabdir!" %_Nul3%
)
if exist "!_fil2!" (
    if %_cwmi% equ 1 for /f "tokens=3,4 delims==." %%a in ('wmic datafile where "name='!cfil2!'" get Version /value ^| find "="') do set "_ver2j=%%a"&set "_ver2n=%%b"
    if %_cwmi% equ 0 for /f "tokens=2,3 delims=." %%a in ('powershell -nop -c "([WMI]'CIM_DataFile.Name=''!cfil2!''').Version"') do set "_ver2j=%%a"&set "_ver2n=%%b"
)
if %_ver1j% gtr %_ver2j% set _skpd=1
if %_ver1j% equ %_ver2j% if %_ver1n% geq %_ver2n% set _skpd=1
if %_skpp% equ 1 if %_skpd% equ 1 (set /a _sum-=1&goto :eof)
set "mpamfe=!dest!"
goto :eof

:defender_update
xcopy /CIRY "!mpamfe!\Definition Updates\Updates" "%_mount%\%_MWD%\Definition Updates\Updates\" %_Nul3%
if exist "%_mount%\%_MWD%\Definition Updates\Updates\MpSigStub.exe" del /f /q "%_mount%\%_MWD%\Definition Updates\Updates\MpSigStub.exe" %_Nul3%
xcopy /ECIRY "!mpamfe!\Platform" "%_mount%\%_MWD%\Platform\" %_Nul3%
for /f %%# in ('dir /b /ad "!mpamfe!\Platform\*.*.*.*"') do set "_wdplat=%%#"
if exist "%_mount%\%_MWD%\Platform\%_wdplat%\MpSigStub.exe" del /f /q "%_mount%\%_MWD%\Platform\%_wdplat%\MpSigStub.exe" %_Nul3%
if not exist "!mpamfe!\Platform\%_wdplat%\ConfigSecurityPolicy.exe" copy /y "%_mount%\Program Files\Windows Defender\ConfigSecurityPolicy.exe" "%_mount%\%_MWD%\Platform\%_wdplat%\" %_Nul3%
if not exist "!mpamfe!\Platform\%_wdplat%\MpAsDesc.dll" copy /y "%_mount%\Program Files\Windows Defender\MpAsDesc.dll" "%_mount%\%_MWD%\Platform\%_wdplat%\" %_Nul3%
if not exist "!mpamfe!\Platform\%_wdplat%\MpEvMsg.dll" copy /y "%_mount%\Program Files\Windows Defender\MpEvMsg.dll" "%_mount%\%_MWD%\Platform\%_wdplat%\" %_Nul3%
if not exist "!mpamfe!\Platform\%_wdplat%\ProtectionManagement.dll" copy /y "%_mount%\Program Files\Windows Defender\ProtectionManagement.dll" "%_mount%\%_MWD%\Platform\%_wdplat%\" %_Nul3%
for /f %%A in ('dir /b /ad "%_mount%\Program Files\Windows Defender\*-*"') do (
    if not exist "%_mount%\%_MWD%\Platform\%_wdplat%\%%A\" mkdir "%_mount%\%_MWD%\Platform\%_wdplat%\%%A" %_Nul3%
    if not exist "!mpamfe!\Platform\%_wdplat%\%%A\MpAsDesc.dll.mui" copy /y "%_mount%\Program Files\Windows Defender\%%A\MpAsDesc.dll.mui" "%_mount%\%_MWD%\Platform\%_wdplat%\%%A\" %_Nul3%
    if not exist "!mpamfe!\Platform\%_wdplat%\%%A\MpEvMsg.dll.mui" copy /y "%_mount%\Program Files\Windows Defender\%%A\MpEvMsg.dll.mui" "%_mount%\%_MWD%\Platform\%_wdplat%\%%A\" %_Nul3%
    if not exist "!mpamfe!\Platform\%_wdplat%\%%A\ProtectionManagement.dll.mui" copy /y "%_mount%\Program Files\Windows Defender\%%A\ProtectionManagement.dll.mui" "%_mount%\%_MWD%\Platform\%_wdplat%\%%A\" %_Nul3%
)
if /i %arch%==x86 goto :eof
if not exist "!mpamfe!\Platform\%_wdplat%\x86\MpAsDesc.dll" copy /y "%_mount%\Program Files (x86)\Windows Defender\MpAsDesc.dll" "%_mount%\%_MWD%\Platform\%_wdplat%\x86\" %_Nul3%
for /f %%A in ('dir /b /ad "%_mount%\Program Files (x86)\Windows Defender\*-*"') do (
    if not exist "%_mount%\%_MWD%\Platform\%_wdplat%\x86\%%A\" mkdir "%_mount%\%_MWD%\Platform\%_wdplat%\x86\%%A" %_Nul3%
    if not exist "!mpamfe!\Platform\%_wdplat%\x86\%%A\MpAsDesc.dll.mui" copy /y "%_mount%\Program Files (x86)\Windows Defender\%%A\MpAsDesc.dll.mui" "%_mount%\%_MWD%\Platform\%_wdplat%\x86\%%A\" %_Nul3%
)
goto :eof

:pXML
if %_build% neq 18362 (
    call :cXML stage
    echo.
    echo 正在处理 [1/1] - 正在暂存 %cbsn%
    %_Dism% /LogPath:"%_dLog%\%_DsmLog%" /Apply-Unattend:"!_cabdir!\stage.xml /Image:"%_mount%"
    if !errorlevel! neq 0 if !errorlevel! neq 3010 (
        echo 暂存 %cbsn% 失败
        goto :eof
    )
)
if %_build% neq 18362 (call :Winner) else (call :Suppress)
if defined _dualSxS (
    set "_SxsKey=%_CedKey%"
    set "_SxsCmp=%_CedCmp%"
    set "_SxsIdn=%_CedIdn%"
    set "_SxsCF=256"
    if %_build% neq 18362 (call :Winner) else (call :Suppress)
)
%_Dism% /LogPath:"%_dLog%\%_DsmLog%" /Add-Package /PackagePath:"!dest!\update.mum /Image:"%_mount%"
if !errorlevel! neq 0 echo 安装 %cbsn% 失败
if %_build% neq 18362 (del /f /q "!_cabdir!\stage.xml" %_Nul3%)
goto :eof

:cXML
(
    echo.^<?xml version="1.0" encoding="utf-8"?^>
    echo.^<unattend xmlns="urn:schemas-microsoft-com:unattend"^>
    echo.    ^<servicing^>
    echo.        ^<package action="%1"^>
)>"!_cabdir!\%1.xml"
findstr /i Package_for_RollupFix "!dest!\update.mum" %_Nul3% && (
    findstr /i Package_for_RollupFix "!dest!\update.mum" >>"!_cabdir!\%1.xml"
)
findstr /i Package_for_RollupFix "!dest!\update.mum" %_Nul3% || (
    findstr /i Package_for_KB "!dest!\update.mum" | findstr /i /v _RTM >>"!_cabdir!\%1.xml"
)
(
    echo.            ^<source location="!dest!\update.mum" /^>
    echo.        ^</package^>
    echo.     ^</servicing^>
    echo.^</unattend^>
)>>"!_cabdir!\%1.xml"
goto :eof

:Suppress
for /f %%# in ('dir /b /a:-d "!dest!\%xBT%_%_SxsCmp%_*.manifest"') do set "_SxsCom=%%~n#"
for /f "tokens=4 delims=_" %%# in ('echo %_SxsCom%') do set "_SxsVer=%%#"
if not exist "%_mount%\Windows\WinSxS\Manifests\%_SxsCom%.manifest" (
    %_Nul3% icacls "%_mount%\Windows\WinSxS\Manifests" /save "!_cabdir!\acl.txt"
    %_Nul3% takeown /f "%_mount%\Windows\WinSxS\Manifests" /A
    %_Nul3% icacls "%_mount%\Windows\WinSxS\Manifests" /grant:r "*S-1-5-32-544:(OI)(CI)(F)"
    %_Nul3% copy /y "!dest!\%_SxsCom%.manifest" "%_mount%\Windows\WinSxS\Manifests\"
    %_Nul3% icacls "%_mount%\Windows\WinSxS\Manifests" /setowner *S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464
    %_Nul3% icacls "%_mount%\Windows\WinSxS" /restore "!_cabdir!\acl.txt"
    %_Nul3% del /f /q "!_cabdir!\acl.txt"
)
reg.exe query HKLM\%COMPONENTS% %_Nul3% || reg.exe load HKLM\%COMPONENTS% "%_mount%\Windows\System32\Config\COMPONENTS" %_Nul3%
reg.exe query "%_Cmp%\%_SxsCom%" %_Nul3% && goto :Winner
for /f "skip=1 tokens=* delims=" %%# in ('certutil -hashfile "!dest!\%_SxsCom%.manifest" SHA256^|findstr /i /v CertUtil') do set "_SxsSha=%%#"
set "_SxsSha=%_SxsSha: =%"
set "_psin=%_SxsIdn%, Culture=neutral, Version=%_SxsVer%, PublicKeyToken=%_Pkt%, ProcessorArchitecture=%xBT%, versionScope=NonSxS"
for /f "tokens=* delims=" %%# in ('powershell -nop -c "$str = '%_psin%'; [BitConverter]::ToString([Text.Encoding]::ASCII.GetBytes($str))-replace'-'" %_Nul6%') do set "_SxsHsh=%%#"
%_Nul3% reg.exe add "%_Cmp%\%_SxsCom%" /f /v "c^!%_Fnd%" /t REG_BINARY /d ""
%_Nul3% reg.exe add "%_Cmp%\%_SxsCom%" /f /v identity /t REG_BINARY /d "%_SxsHsh%"
%_Nul3% reg.exe add "%_Cmp%\%_SxsCom%" /f /v S256H /t REG_BINARY /d "%_SxsSha%"
%_Nul3% reg.exe add "%_Cmp%\%_SxsCom%" /f /v CF /t REG_DWORD /d "%_SxsCF%"
for /f "tokens=* delims=" %%# in ('reg.exe query HKLM\%COMPONENTS%\DerivedData\VersionedIndex %_Nul6% ^| findstr /i VersionedIndex') do reg.exe delete "%%#" /f %_Nul3%

:Winner
for /f "tokens=4 delims=_" %%# in ('dir /b /a:-d "!dest!\%xBT%_%_SxsCmp%_*.manifest"') do (
    set "pv_al=%%#"
)
for /f "tokens=1-4 delims=." %%G in ('echo %pv_al%') do (
    set "pv_os=%%G.%%H"
    set "pv_mj=%%G"&set "pv_mn=%%H"&set "pv_bl=%%I"&set "pv_dl=%%J"
)
set kv_al=
reg.exe load HKLM\%SOFTWARE% "%_mount%\Windows\System32\Config\SOFTWARE" %_Nul3%
if not exist "%_mount%\Windows\WinSxS\Manifests\%xBT%_%_SxsCmp%_*.manifest" goto :SkipChk
reg.exe query "%_SxsKey%" %_Nul3% || goto :SkipChk
reg.exe query HKLM\%COMPONENTS% %_Nul3% || reg.exe load HKLM\%COMPONENTS% "%_mount%\Windows\System32\Config\COMPONENTS" %_Nul3%
reg.exe query "%_Cmp%" /f "%xBT%_%_SxsCmp%_*" /k %_Nul2% | find /i "HKEY_LOCAL_MACHINE" %_Nul1% || goto :SkipChk
call :ChkESUver %_Nul3%
set "wv_bl=0"&set "wv_dl=0"
reg.exe query "%_SxsKey%\%pv_os%" /ve %_Nul2% | findstr \( | findstr \. %_Nul1% || goto :SkipChk
for /f "tokens=2*" %%a in ('reg.exe query "%_SxsKey%\%pv_os%" /ve ^| findstr \(') do set "wv_al=%%b"
for /f "tokens=1-4 delims=." %%G in ('echo %wv_al%') do (
    set "wv_mj=%%G"&set "wv_mn=%%H"&set "wv_bl=%%I"&set "wv_dl=%%J"
)

:SkipChk
reg.exe add "%_SxsKey%\%pv_os%" /f /v %pv_al% /t REG_BINARY /d 01 %_Nul3%
set skip_pv=0
if "%kv_al%"=="" (
    reg.exe add "%_SxsKey%\%pv_os%" /f /ve /d %pv_al% %_Nul3%
    reg.exe add "%_SxsKey%" /f /ve /d %pv_os% %_Nul3%
    goto :EndChk
)
if %pv_mj% lss %kv_mj% (
    set skip_pv=1
    if %pv_bl% geq %wv_bl% if %pv_dl% geq %wv_dl% reg.exe add "%_SxsKey%\%pv_os%" /f /ve /d %pv_al% %_Nul3%
)
if %pv_mj% equ %kv_mj% if %pv_mn% lss %kv_mn% (
    set skip_pv=1
    if %pv_bl% geq %wv_bl% if %pv_dl% geq %wv_dl% reg.exe add "%_SxsKey%\%pv_os%" /f /ve /d %pv_al% %_Nul3%
)
if %pv_mj% equ %kv_mj% if %pv_mn% equ %kv_mn% if %pv_bl% lss %kv_bl% (
    set skip_pv=1
)
if %pv_mj% equ %kv_mj% if %pv_mn% equ %kv_mn% if %pv_bl% equ %kv_bl% if %pv_dl% lss %kv_dl% (
    set skip_pv=1
)
if %skip_pv% equ 0 (
    reg.exe add "%_SxsKey%\%pv_os%" /f /ve /d %pv_al% %_Nul3%
    reg.exe add "%_SxsKey%" /f /ve /d %pv_os% %_Nul3%
)

:EndChk
if /i %xOS%==x86 if /i not %arch%==x86 (
    reg.exe save HKLM\%SOFTWARE% "%_mount%\Windows\System32\Config\SOFTWARE2" %_Nul1%
    reg.exe query HKLM\%COMPONENTS% %_Nul3% && reg.exe save HKLM\%COMPONENTS% "%_mount%\Windows\System32\Config\COMPONENTS2" %_Nul1%
)
reg.exe unload HKLM\%SOFTWARE% %_Nul3%
reg.exe unload HKLM\%COMPONENTS% %_Nul3%
if /i %xOS%==x86 if /i not %arch%==x86 (
    move /y "%_mount%\Windows\System32\Config\SOFTWARE2" "%_mount%\Windows\System32\Config\SOFTWARE" %_Nul1%
    if exist "%_mount%\Windows\System32\Config\COMPONENTS2" move /y "%_mount%\Windows\System32\Config\COMPONENTS2" "%_mount%\Windows\System32\Config\COMPONENTS" %_Nul1%
)
goto :eof

:ChkESUver
set kv_os=
reg.exe query "%_SxsKey%" /ve | findstr \( | findstr \. || goto :eof
for /f "tokens=2*" %%a in ('reg.exe query "%_SxsKey%" /ve ^| findstr \(') do set "kv_os=%%b"
if "%kv_os%"=="" goto :eof
set kv_al=
reg.exe query "%_SxsKey%\%kv_os%" /ve | findstr \( | findstr \. || goto :eof
for /f "tokens=2*" %%a in ('reg.exe query "%_SxsKey%\%kv_os%" /ve ^| findstr \(') do set "kv_al=%%b"
if "%kv_al%"=="" goto :eof
reg.exe query "%_Cmp%" /f "%xBT%_%_SxsCmp%_%_Pkt%_%kv_al%_*" /k %_Nul2% | find /i "%kv_al%" %_Nul1% || (
    set kv_al=
    goto :eof
)
for /f "tokens=1-4 delims=." %%G in ('echo %kv_al%') do (
    set "kv_mj=%%G"&set "kv_mn=%%H"&set "kv_bl=%%I"&set "kv_dl=%%J"
)
goto :eof

:update
if %W10UI% equ 0 exit /b
set directcab=0
set wim=0
set dvd=0
set _tgt=
set _tgt=%1
if defined _tgt (
    set wim=1
    set _target=%1
) else (
    set dvd=1
    set _target=ISOFOLDER\sources\install.wim
)
for /f "tokens=3 delims=: " %%# in ('wimlib-imagex.exe info "%_target%" ^| findstr /c:"Image Count"') do set imgcount=%%#
if not exist "%SystemRoot%\temp\" mkdir "%SystemRoot%\temp" %_Nul3%
if exist "%SystemRoot%\temp\UpdateAgent.dll" del /f /q "%SystemRoot%\temp\UpdateAgent.dll" %_Nul3%
if exist "%SystemRoot%\temp\Facilitator.dll" del /f /q "%SystemRoot%\temp\Facilitator.dll" %_Nul3%
if exist "%_mount%\" rmdir /s /q "%_mount%\"
if not exist "%_mount%\" mkdir "%_mount%"
for %%# in (handle1,handle2) do set %%#=0
for /L %%# in (1,1,%imgcount%) do set "_inx=%%#"&call :mount "%_target%"
if exist "%_mount%\" rmdir /s /q "%_mount%\"
if %_build% geq 19041 if %winbuild% lss 17133 if exist "%SysPath%\ext-ms-win-security-slc-l1-1-0.dll" (
    del /f /q %SysPath%\ext-ms-win-security-slc-l1-1-0.dll %_Nul3%
    if /i not %xOS%==x86 del /f /q %SystemRoot%\SysWOW64\ext-ms-win-security-slc-l1-1-0.dll %_Nul3%
)
echo.
if %wim% equ 1 exit /b
if %isomin% lss %revmin% set isover=%revver%
if %isomaj% lss %revmaj% set isover=%revver%
set _label=%isover%
call :setlabel
exit /b

:mount
set _www=%~1
set _nnn=%~nx1
echo.
echo %line%
echo 正在更新 %_nnn% [%_inx%/%imgcount%]
echo %line%
%_Dism% /LogPath:"%_dLog%\DismMount.log" /Mount-Wim /Wimfile:"%_www%" /Index:%_inx% /MountDir:"%_mount%"
if !errorlevel! neq 0 (
    %_Dism% /LogPath:"%_dLog%\DismNUL.log" /Image:"%_mount%" /Get-Packages %_Nul3%
    %_Dism% /LogPath:"%_dLog%\DismUnMount.log" /Unmount-Wim /MountDir:"%_mount%" /Discard
    Dism.exe /Cleanup-Wim %_Nul3%
    goto :eof
)
call :dowork
goto :eof

:dowork
if not exist "%_mount%\Windows\Servicing\Packages\*WinPE-LanguagePack*.mum" if %_wimEdge% equ 1 call :addedge
call :updatewim
if defined mounterr goto :eof
if exist "%_mount%\Windows\Servicing\Packages\*WinPE-Setup-Package*.mum" (
    set isoupdate=
    xcopy /CDRUY "%_mount%\sources" "ISOFOLDER\sources\" %_Nul3%
    for /f %%# in ('dir /b /ad "%_mount%\sources\*-*" %_Nul6%') do if exist "ISOFOLDER\sources\%%#\*.mui" copy /y "%_mount%\sources\%%#\*" "ISOFOLDER\sources\%%#\" %_Nul3%
)
if exist "%_mount%\Windows\Servicing\Packages\*WinPE-LanguagePack*.mum" goto :Done
if %_build% geq 22621 offlinereg.exe "%_mount%\Windows\System32\config\SYSTEM" "CurrentControlSet\Control\CI\Policy" setvalue VerifiedAndReputablePolicyState 0 4 %_Nul3%
if exist "%_mount%\Windows\Servicing\Packages\Microsoft-Windows-Server*CorEdition~*.mum" goto :SkipApps
if %AddAppxs% equ 1 call :doappx
:SkipApps
if !handle1! equ 0 (
    set handle1=1
    if %UpdtBootFiles% equ 1 (
        for %%i in (efisys.bin,efisys_noprompt.bin) do if exist "%_mount%\Windows\Boot\DVD\EFI\en-US\%%i" ( xcopy /CIDRY "%_mount%\Windows\Boot\DVD\EFI\en-US\%%i" "ISOFOLDER\efi\microsoft\boot\" %_Nul3%)
        if /i not %arch%==arm64 (
            xcopy /CIDRY "%_mount%\Windows\Boot\PCAT\bootmgr" "ISOFOLDER\" %_Nul3%
            xcopy /CIDRY "%_mount%\Windows\Boot\PCAT\memtest.exe" "ISOFOLDER\boot\" %_Nul3%
            xcopy /CIDRY "%_mount%\Windows\Boot\EFI\memtest.efi" "ISOFOLDER\efi\microsoft\boot\" %_Nul3%
        )
        if exist "%_mount%\Windows\Boot\EFI\winsipolicy.p7b" if exist "ISOFOLDER\efi\microsoft\boot\winsipolicy.p7b" xcopy /CIDRY "%_mount%\Windows\Boot\EFI\winsipolicy.p7b" "ISOFOLDER\efi\microsoft\boot\" %_Nul3%
        if exist "%_mount%\Windows\Boot\EFI\CIPolicies\" if exist "ISOFOLDER\efi\microsoft\boot\cipolicies\" xcopy /CEDRY "%_mount%\Windows\Boot\EFI\CIPolicies" "ISOFOLDER\efi\microsoft\boot\cipolicies\" %_Nul3%
    )
    if /i %arch%==x86 (set efifile=bootia32.efi) else if /i %arch%==x64 (set efifile=bootx64.efi) else ( set efifile=bootaa64.efi)
    if exist "ISOFOLDER\efi\boot\bootmgfw.efi" xcopy /CIDRY "%_mount%\Windows\Boot\EFI\bootmgfw.efi" "ISOFOLDER\efi\boot\bootmgfw.efi" %_Nul3%
    xcopy /CIDRY "%_mount%\Windows\Boot\EFI\bootmgfw.efi" "ISOFOLDER\efi\boot\!efifile!" %_Nul3%
    xcopy /CIDRY "%_mount%\Windows\Boot\EFI\bootmgr.efi" "ISOFOLDER\" %_Nul3%
)
if !handle2! equ 0 (
    set handle2=1
    set isomin=0
    for /f "tokens=%tok% delims=_." %%i in ('dir /b /a:-d /od "%_mount%\Windows\WinSxS\Manifests\%_ss%_microsoft-windows-coreos-revision*.manifest"') do (set isover=%%i.%%j&set isomaj=%%i&set isomin=%%j)
    set "isokey=Microsoft\Windows NT\CurrentVersion\Update\TargetingInfo\Installed"
    for /f %%i in ('"offlinereg.exe "%_mount%\Windows\System32\config\SOFTWARE" "!isokey!" enumkeys %_Nul6% ^| findstr /i /r ".*\.OS""') do if not errorlevel 1 (
        for /f "tokens=5,6 delims==:." %%A in ('"offlinereg.exe "%_mount%\Windows\System32\config\SOFTWARE" "!isokey!\%%i" getvalue Version %_Nul6%"') do if %%A gtr !isomaj! (
            set "revver=%%~A.%%B
            set revmaj=%%~A
            set "revmin=%%B
        )
    )
)
if exist "%_mount%\Windows\System32\UpdateAgent.dll" if not exist "%SystemRoot%\temp\UpdateAgent.dll" copy /y "%_mount%\Windows\System32\UpdateAgent.dll" %SystemRoot%\temp\ %_Nul1%
if exist "%_mount%\Windows\System32\Facilitator.dll" if not exist "%SystemRoot%\temp\Facilitator.dll" copy /y "%_mount%\Windows\System32\Facilitator.dll" %SystemRoot%\temp\ %_Nul1%
if %AddEdition% neq 1 goto :Done
echo.
echo %line%
echo 正在转换 Windows 版本……
echo %line%
echo.
for /f "tokens=3 delims=: " %%# in ('%_Dism% /LogPath:"%_dLog%\DismEdition.log" /English /Image:"%_mount%" /Get-CurrentEdition ^| findstr /c:"Current Edition"') do set editionid=%%#
if /i %editionid%==Core for %%i in (Core, CoreSingleLanguage) do ( set nedition=%%i && call :setedition)
if /i %editionid%==Professional for %%i in (Professional, Education, ProfessionalEducation, ProfessionalWorkstation) do ( set nedition=%%i && call :setedition)
%_Dism% /LogPath:"%_dLog%\DismUnMount.log" /Unmount-Wim /MountDir:"%_mount%" /Discard
goto :eof
:Done
%_Dism% /LogPath:"%_dLog%\DismUnMount.log" /Unmount-Wim /MountDir:"%_mount%" /Commit
goto :eof

:addedge
echo.
echo 正在添加 Microsoft Edge……
%_Dism% /LogPath:"%_dLog%\DismEdge.log" /Image:"%_mount%" /Add-Edge /SupportPath:"!_DIR!"
if !errorlevel! neq 0 echo 添加 Edge.wim 失败
goto :eof

:doappx
if %_build% geq 19041 set "mountver=19041"
if %_build% geq 22000 set "mountver=22000"
if %_build% geq 22621 set "mountver=22621"
if %_build% gtr 23403 set "mountver=Dev"
if %_build% geq 26063 set "mountver=Can"
if %_SrvESD% equ 1 set "mountver=!mountver!.Server"
if not exist "%_mount%\Program Files\WindowsApps\Microsoft.*" goto :donedel
if not exist Apps\appxdel.!mountver!.MS.txt goto :donedel
echo.
echo %line%
echo 正在卸载 Appxs 软件包……
echo %line%
echo.
for /f "eol=# tokens=* delims=" %%i in (Apps\appxdel.!mountver!.MS.txt) do (
    %_Dism% /LogPath:"%_dLog%\DismAppx.log" /English /Image:"%_mount%" /Remove-ProvisionedAppxPackage /PackageName:%%i | findstr /i /c:"successfully" %_Nul3% && echo %%i
)
:donedel
if not exist Apps\appxdel.!mountver!.txt goto :donereg
reg.exe load HKLM\%SOFTWARE% "%_mount%\Windows\System32\Config\SOFTWARE" %_Nul3%
if %_build% equ 22000 reg.exe delete "HKLM\%SOFTWARE%\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned\Microsoft.ZuneMusic_8wekyb3d8bbwe" /f %_Nul3%
if %_build% geq 22000 (
    reg.exe query "HKLM\%SOFTWARE%\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned" %_Nul3% || reg.exe add "HKLM\%SOFTWARE%\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned" /f %_Nul3%
    for /f "eol=# tokens=* delims=" %%i in (Apps\appxdel.!mountver!.txt) do (
        reg.exe add "HKLM\%SOFTWARE%\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned\%%i" /f %_Nul3%
    )
)
if exist "%_mount%\Program Files\WindowsApps\Microsoft.*" for /f "tokens=8 delims=\" %%# in ('reg.exe query "HKLM\%SOFTWARE%\Microsoft\Windows\CurrentVersion\AppModel\StubPreference"') do (
    reg.exe delete "HKLM\%SOFTWARE%\Microsoft\Windows\CurrentVersion\AppModel\StubPreference\%%#" /f %_Nul3%
)
reg.exe unload HKLM\%SOFTWARE% %_Nul3%
:donereg
if not exist Apps\appxadd.!mountver!.txt goto :doneadd
echo.
echo %line%
echo 正在安装 Appxs 软件包……
echo %line%
echo.
for /f "eol=# tokens=* delims=" %%i in (Apps\appxadd.!mountver!.txt) do (
    set "license=/SkipLicense"
    for /f "delims=_" %%j in ("%%i") do if exist Apps\Licenses\%%j*.xml for /f "delims=" %%k in ('dir /a /b Apps\Licenses\%%j*.xml') do set "license=/LicensePath:"Apps\Licenses\%%k""
    %_Dism% /LogPath:"%_dLog%\DismAppx.log" /English /Image:"%_mount%" /Add-ProvisionedAppxPackage /PackagePath:"Apps\Apps\%%i" !license! /Region=all | findstr /i /c:"successfully" %_Nul3% && echo %%i
)
:doneadd
goto :eof

:setedition
call :setname
echo.
echo 正在处理 !_nameb!
if exist "%_mount%\Windows\Core.xml" del /f /q "%_mount%\Windows\Core.xml" %_Nul3%
if exist "%_mount%\Windows\CoreSingleLanguage.xml" del /f /q "%_mount%\Windows\CoreSingleLanguage.xml" %_Nul3%
if exist "%_mount%\Windows\Education.xml" del /f /q "%_mount%\Windows\Education.xml" %_Nul3%
if exist "%_mount%\Windows\Professional.xml" del /f /q "%_mount%\Windows\Professional.xml" %_Nul3%
if exist "%_mount%\Windows\ProfessionalEducation.xml" del /f /q "%_mount%\Windows\ProfessionalEducation.xml" %_Nul3%
if exist "%_mount%\Windows\ProfessionalWorkstation.xml" del /f /q "%_mount%\Windows\ProfessionalWorkstation.xml" %_Nul3%
%_Dism% /LogPath:"%_dLog%\DismEdition.log" /Image:"%_mount%" /Set-Edition:%nedition% /Channel:Retail %_Nul3%
if /i not %editionid%==%nedition% goto :dochange
Dism.exe /Commit-Image /MountDir:"%_mount%"
wimlib-imagex.exe info "%_www%" %_inx% "!_namea!" "!_namea!" --image-property DISPLAYNAME="!_nameb!" --image-property DISPLAYDESCRIPTION="!_nameb!" --image-property FLAGS=%nedition% %_Nul3%
echo.
goto :eof

:dochange
Dism.exe /Commit-Image /MountDir:"%_mount%" /Append
for /f "tokens=3 delims=: " %%# in ('wimlib-imagex.exe info "%_www%" ^| findstr /c:"Image Count"') do set nimg=%%# %_Nul3%
wimlib-imagex.exe info "%_www%" %nimg% "!_namea!" "!_namea!" --image-property DISPLAYNAME="!_nameb!" --image-property DISPLAYDESCRIPTION="!_nameb!" --image-property FLAGS=%nedition% %_Nul3%
echo.
goto :eof

:setname
for %%# in (
    "Core:%_wtx% Home:%_wtx% 家庭版"
    "CoreSingleLanguage:%_wtx% Home Single Language:%_wtx% 家庭单语言版"
    "Education:%_wtx% Education:%_wtx% 教育版"
    "Professional:%_wtx% Pro:%_wtx% 专业版"
    "ProfessionalEducation:%_wtx% Pro Education:%_wtx% 专业教育版"
    "ProfessionalWorkstation:%_wtx% Pro for Workstations:%_wtx% 专业工作站版"
    "ServerStandardCore:%_wsr% SERVERSTANDARDCORE:%_wsr% Standard:（推荐）此选项忽略大部分 Windows 图形环境。通过命令提示符和 PowerShell，或者远程使用 Windows Admin Center 或其他工具进行管理。"
    "ServerStandard:%_wsr% SERVERSTANDARD:%_wsr% Standard (桌面体验):此选项将安装的完整的 Windows 图形环境，占用额外的驱动器空间。如果你想要使用 Windows 桌面或需要桌面的应用，则它会很有用。"
    "ServerDatacenterCore:%_wsr% SERVERDATACENTERCORE:%_wsr% Datacenter:（推荐）此选项忽略大部分 Windows 图形环境。通过命令提示符和 PowerShell，或者远程使用 Windows Admin Center 或其他工具进行管理。"
    "ServerDatacenter:%_wsr% SERVERDATACENTER:%_wsr% Datacenter (桌面体验):此选项将安装的完整的 Windows 图形环境，占用额外的驱动器空间。如果你想要使用 Windows 桌面或需要桌面的应用，则它会很有用。"
    "ServerTurbineCore:%_wsr% SERVERTURBINECORE:%_wsr% Datacenter Azure Edition:（推荐）此选项忽略大部分 Windows 图形环境。通过命令提示符和 PowerShell，或者远程使用 Windows Admin Center 或其他工具进行管理。"
    "ServerTurbine:%_wsr% SERVERTURBINE:%_wsr% Datacenter Azure Edition (桌面体验):此选项将安装的完整的 Windows 图形环境，占用额外的驱动器空间。如果你想要使用 Windows 桌面或需要桌面的应用，则它会很有用。"
) do for /f "tokens=1,2,3,4 delims=:" %%A in ("%%~#") do (
    if /i %nedition%==%%A set "_namea=%%B"&set "_nameb=%%C"&set "_namec=%%D"
)
goto :eof

:cleanup
set savc=0&set savr=1
if %_build% geq 18362 (set savc=3&set savr=3)
if exist "%_mount%\Windows\Servicing\Packages\*WinPE-LanguagePack*.mum" (
    if /i not %arch%==arm64 (
        reg.exe load HKLM\%ksub% "%_mount%\Windows\System32\Config\SOFTWARE" %_Nul1%
        reg.exe add HKLM\%ksub%\%_SxsCfg% /v SupersededActions /t REG_DWORD /d %savr% /f %_Nul1%
        reg.exe add HKLM\%ksub%\%_SxsCfg% /v DisableComponentBackups /t REG_DWORD /d 1 /f %_Nul1%
        reg.exe unload HKLM\%ksub% %_Nul1%
    )
    %_Dism% /LogPath:"%_dLog%\DismClean.log" /Image:"%_mount%" /Cleanup-Image /StartComponentCleanup
    if %Cleanup% neq 0 (
        if %ResetBase% neq 0 %_Dism% /LogPath:"%_dLog%\DismClean.log" /Image:"%_mount%" /Cleanup-Image /StartComponentCleanup /ResetBase %_Nul3%
    )
    call :cleanmanual&goto :eof
)
if %Cleanup% equ 0 call :cleanmanual&goto :eof
if exist "%_mount%\Windows\WinSxS\pending.xml" call :cleanmanual&goto :eof
if /i not %arch%==arm64 (
    reg.exe load HKLM\%ksub% "%_mount%\Windows\System32\Config\SOFTWARE" %_Nul1%
    if %ResetBase% equ 1 (
        reg.exe add HKLM\%ksub%\%_SxsCfg% /v DisableResetbase /t REG_DWORD /d 0 /f %_Nul1%
        reg.exe add HKLM\%ksub%\%_SxsCfg% /v SupersededActions /t REG_DWORD /d %savr% /f %_Nul1%
    ) else (
        reg.exe add HKLM\%ksub%\%_SxsCfg% /v DisableResetbase /t REG_DWORD /d 1 /f %_Nul1%
        reg.exe add HKLM\%ksub%\%_SxsCfg% /v SupersededActions /t REG_DWORD /d %savc% /f %_Nul1%
    )
    if /i %xOS%==x86 if /i not %arch%==x86 reg.exe save HKLM\%ksub% "%_mount%\Windows\System32\Config\SOFTWARE2" %_Nul1%
    reg.exe unload HKLM\%ksub% %_Nul1%
    if /i %xOS%==x86 if /i not %arch%==x86 move /y "%_mount%\Windows\System32\Config\SOFTWARE2" "%_mount%\Windows\System32\Config\SOFTWARE" %_Nul1%
) else (
    %_Nul3% offlinereg.exe "%_mount%\Windows\System32\Config\SOFTWARE" %_SxsCfg% setvalue SupersededActions 3 4
)
%_Dism% /LogPath:"%_dLog%\DismClean.log" /Image:"%_mount%" /Cleanup-Image /StartComponentCleanup
if %ResetBase% neq 0 %_Dism% /LogPath:"%_dLog%\DismClean.log" /Image:"%_mount%" /Cleanup-Image /StartComponentCleanup /ResetBase %_Nul3%
call :cleanmanual&goto :eof

:cleanmanual
if exist "%_mount%\Windows\WinSxS\ManifestCache\*.bin" (
    takeown /f "%_mount%\Windows\WinSxS\ManifestCache\*.bin" /A %_Nul3%
    icacls "%_mount%\Windows\WinSxS\ManifestCache\*.bin" /grant *S-1-5-32-544:F %_Nul3%
    del /f /q "%_mount%\Windows\WinSxS\ManifestCache\*.bin" %_Nul3%
)
if exist "%_mount%\Windows\WinSxS\Temp\*" (
    takeown /f "%_mount%\Windows\WinSxS\Temp\*" /A %_Nul3%
    icacls "%_mount%\Windows\WinSxS\Temp\*" /grant *S-1-5-32-544:F %_Nul3%
    del /f /q "%_mount%\Windows\WinSxS\Temp\*" %_Nul3%
)
if exist "%_mount%\Windows\WinSxS\Backup\*" (
    takeown /f "%_mount%\Windows\WinSxS\Backup\*" /R /A %_Nul3%
    icacls "%_mount%\Windows\WinSxS\Backup\*" /grant *S-1-5-32-544:F /T %_Nul3%
    del /s /f /q "%_mount%\Windows\WinSxS\Backup\*" %_Nul3%
)
if exist "%_mount%\Windows\inf\*.log" (
    del /f /q "%_mount%\Windows\inf\*.log" %_Nul3%
)
for /f "tokens=* delims=" %%# in ('dir /b /ad "%_mount%\Windows\assembly\*NativeImages*" %_Nul6%') do rmdir /s /q "%_mount%\Windows\assembly\%%#" %_Nul3%
for /f "tokens=* delims=" %%# in ('dir /b /ad "%_mount%\Windows\CbsTemp\" %_Nul6%') do rmdir /s /q "%_mount%\Windows\CbsTemp\%%#\" %_Nul3%
del /s /f /q "%_mount%\Windows\CbsTemp\*" %_Nul3%
goto :eof

:DismHostON
if %winbuild% lss 9200 exit /b
if %_MOifeo% neq 0 exit /b
set _MOifeo=1
reg.exe query %_IFEO% /v MitigationOptions %_Nul3%
if %errorlevel% neq 0 (
%_Nul1% reg.exe add %_IFEO% /f /v MitigationOptions /t REG_QWORD /d 0x220000
exit /b
)
for /f "skip=2 tokens=2*" %%a in ('reg.exe query %_IFEO% /v MitigationOptions') do (
    if /i "%%a"=="REG_QWORD" (
        %_Nul1% reg.exe add %_IFEO% /f /v MitigationUUP /t REG_QWORD /d %%b
    ) else (
        %_Nul1% reg.exe add %_IFEO% /f /v MitigationUUP /t REG_BINARY /d %%b
    )
)
%_Nul1% reg.exe add %_IFEO% /f /v MitigationOptions /t REG_QWORD /d 0x220000
exit /b

:DismHostOFF
if %winbuild% lss 9200 exit /b
reg.exe query %_IFEO% /v MitigationUUP %_Nul3%
if %errorlevel% neq 0 (
%_Nul3% reg.exe delete %_IFEO% /f
exit /b
)
for /f "skip=2 tokens=2*" %%a in ('reg.exe query %_IFEO% /v MitigationUUP') do (
    if /i "%%a"=="REG_QWORD" (
        %_Nul1% reg.exe add %_IFEO% /f /v MitigationOptions /t REG_QWORD /d %%b
    ) else (
        %_Nul1% reg.exe add %_IFEO% /f /v MitigationOptions /t REG_BINARY /d %%b
    )
)
%_Nul3% reg.exe delete %_IFEO% /f /v MitigationUUP
exit /b

:E_NotFind
echo %_err%
echo 在指定的路径中未找到所需文件（夹）。
echo.
goto :QUIT

:E_Admin
echo %_err%
echo 此脚本需要以管理员权限运行。
echo 若要继续执行，请在脚本上右键单击并选择“以管理员权限运行”。
echo.
echo 请按任意键退出脚本。
pause >nul
exit /b

:E_PowerShell
echo %_err%
echo 此脚本的工作需要 Windows PowerShell。
echo.
echo 请按任意键退出脚本。
pause >nul
exit /b

:E_BinMiss
echo %_err%
echo 所需的文件 %_bin% 丢失。
echo.
goto :QUIT

:E_Apply
echo.
echo 在应用映像的时候出现错误。
echo.
goto :QUIT

:E_Export
echo.
echo 在导出映像的时候出现错误。
echo.
goto :QUIT

:E_ISOC
ren ISOFOLDER %DVDISO%
echo.
echo 在创建ISO映像的时候出现错误。
echo.
goto :QUIT

:QUIT
if %_MOifeo% neq 0 (
call :DismHostOFF
)
if exist ISOFOLDER\ rmdir /s /q ISOFOLDER\
if exist temp\ rmdir /s /q temp\
popd
if exist "!_cabdir!\" (
    if %AddUpdates% equ 1 (
        echo.
        echo %line%
        echo 正在移除临时文件……
        echo %line%
        echo.
    )
    rmdir /s /q "!_cabdir!\" %_Nul3%
)
if exist "!_cabdir!\" (
    mkdir %_drv%\_del286 %_Nul3%
    robocopy %_drv%\_del286 "!_cabdir!" /MIR /R:1 /W:1 /NFL /NDL /NP /NJH /NJS %_Nul3%
    rmdir /s /q %_drv%\_del286\ %_Nul3%
    rmdir /s /q "!_cabdir!\" %_Nul3%
)
if %_Debug% neq 0 %FullExit%
echo 请按数字 0 键退出脚本。
choice /c 0 /n
if errorlevel 1 (%FullExit%) else (rem.)
