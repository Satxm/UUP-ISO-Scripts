@setlocal DisableDelayedExpansion
@set "uivr=v24.5-105"
@echo off

:: 若要启用调试模式，请将此参数更改为 1
set _Debug=0

:: 若要清理映像以增量压缩已取代的组件，请将此参数更改为 1（警告：在 18362 及以上版本中，这将会删除基础 RTM 版本程序包）
set Cleanup=1

:: 若要重置操作系统映像并移除已被更新取代的组件，请将此参数更改为 1（快于默认的增量压缩，需要首先设置参数 Cleanup=1）
set ResetBase=1

:: 若不需要创建 ISO 文件，保留原始文件夹，请将此参数更改为 1
set SkipISO=0

:: 若要保留关联 ESD 文件，请将此参数更改为 1
set RefESD=1

:: 使用现有镜像升级 Windows 版本并保存，请将此参数更改为 1
set AddEdition=1

:: 升级或整合 Appx 软件，请将此参数更改为 1
set AddAppxs=0

:: 生成并使用 .msu 更新包（Windows 11），请将此参数更改为 1
set UseMSU=0

:: 若在完成时退出进程而不提示，请将此参数更改为 1
set AutoExit=1

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
set "Path=%~dp0bin;%~dp0temp;%SysPath%;%SystemRoot%;%SysPath%\Wbem;%SysPath%\WindowsPowerShell\v1.0\;%LocalAppData%\Microsoft\WindowsApps\"
if exist "%SystemRoot%\Sysnative\reg.exe" (
    set "SysPath=%SystemRoot%\Sysnative"
    set "Path=%~dp0bin;%~dp0temp;%SystemRoot%\Sysnative;%SystemRoot%\Sysnative\Wbem;%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\;%LocalAppData%\Microsoft\WindowsApps\;%Path%"
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
if %_cwmi% equ 0 for /f "tokens=1 delims=:" %%# in ('%_psc% "(([WMISEARCHER]'Select * from Win32_Volume where DriveLetter is not NULL').Get()).DriveLetter; (([WMISEARCHER]'Select * from Win32_LogicalDisk where DeviceID is not NULL').Get()).DeviceID"') do (
    if defined _adr%%# set "_adr%%#="
)
for %%# in (E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if not defined _sdr (if defined _adr%%# set "_sdr=%%#:")
)
if not defined _sdr set psfnet=0
set "_Pkt=31bf3856ad364e35"
set "_OurVer=25.10.0.0"
set "_SupCmp=microsoft-client-li..pplementalservicing"
set "_EdgCmp=microsoft-windows-e..-firsttimeinstaller"
set "_CedCmp=microsoft-windows-edgechromium"
set "_EsuCmp=microsoft-windows-s..edsecurityupdatesai"
set "_SupIdn=Microsoft-Client-Licensing-SupplementalServicing"
set "_EdgIdn=Microsoft-Windows-EdgeChromium-FirstTimeInstaller"
set "_CedIdn=Microsoft-Windows-EdgeChromium"
set "_EsuIdn=Microsoft-Windows-SLC-Component-ExtendedSecurityUpdatesAI"
set "_SxsCfg=Microsoft\Windows\CurrentVersion\SideBySide\Configuration"
set "_IFEO=HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\dismhost.exe"
set _MOifeo=0
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
if /i not "%_drv%"=="%SystemDrive%" if %_cwmi% equ 0 for /f %%# in ('%_psc% "(([WMISEARCHER]'Select * from Win32_Volume where DriveLetter=\"%_drv%\"').Get()).FileSystem"') do set "_ntf=%%#"
if /i not "%_ntf%"=="NTFS" (
    set "_mount=%SystemDrive%\Mount"
)
set "line============================================================="

:check
pushd "!_work!"
set _fils=(7z.dll,7z.exe,bootmui.txt,bootwim.txt,oscdimg.exe,imagex.exe,libwim-15.dll,offlinereg.exe,offreg64.dll,wimlib-imagex.exe,PSFExtractor.exe)
for %%# in %_fils% do (
    if not exist "bin\%%#" (set _bin=%%#&goto :E_BinMiss)
)
if exist ISOFOLDER\ rmdir /s /q ISOFOLDER\
if exist temp\ rmdir /s /q temp\
mkdir temp

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
    Core,CoreSingleLanguage,CoreCountrySpecific,Professional,ProfessionalSingleLanguage,ProfessionalCountrySpecific,Education,ProfessionalEducation,ProfessionalWorkstation
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
if exist "!_DIR!\*.*xbundle" set _appexist=1
if exist "!_DIR!\Apps\*_8wekyb3d8bbwe" set _appexist=1
if %_appexist% equ 0 set AddAppxs=0
if %Cleanup% equ 0 set ResetBase=0
if %_SrvESD% equ 1 set AddEdition=0
if %AddAppxs% equ 1 set _DismHost=1
if defined _DismHost call :DismHostON

echo.
echo %line%
echo 正在列出已配置选项……
echo %line%
echo.
if %_appexist% neq 0 echo 存在 Appxs
if %_wimEdge% equ 1 echo 存在 Edge.wim
if %Cleanup% neq 0 echo 增量压缩已取代的组件
if %ResetBase% neq 0 echo 移除已被更新取代的组件
if %AddAppxs% neq 0 echo 添加 Appxs
if %AddEdition% neq 0 echo 转换 Windows 版本

if exist "!_cabdir!\" rmdir /s /q "!_cabdir!\"
if not exist "!_cabdir!\" mkdir "!_cabdir!" %_Nul3%
if exist "%_dLog%\*" del /f /q %_dLog%\* %_Nul3%
if not exist "%_dLog%\" mkdir "%_dLog%" %_Nul3%

if exist "!_DIR!\Apps\*_8wekyb3d8bbwe" if %_SrvESD% neq 1 if not exist "!_DIR!\Apps\Custom_Appxs.txt" if not exist "!_DIR!\Apps\Apps_*.txt" call :appx_sort
if exist "!_DIR!\*.*xbundle" (call :appx_sort) else if exist "!_DIR!\*.appx" (call :appx_sort) else if exist "!_DIR!\*.msix" (call :appx_sort)

call :uups_ref
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
set _rtrn=WinreRet
goto :WinreWim
:WinreRet
set _rtrn=BootRet
goto :BootWim
:BootRet
set _rtrn=InstallRet
goto :InstallWim
:InstallRet
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
for /f %%a in ('%_psc% "(dir %wimfile%).LastWriteTime.ToString('MM/dd/yyyy,HH:mm:ss')"') do set isotime=%%a
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
    %_Dism% /LogPath:"%_dLog%\DismExport.log" /Export-Image /SourceImageFile:"!_DIR!\!uups_esd%%#!" /SourceIndex:3 /DestinationImageFile:"ISOFOLDER\sources\install.wim" /Compress:max
    call set ERRORTEMP=!ERRORLEVEL!
    if !ERRORTEMP! neq 0 goto :E_Export
    set nedition=!edition%%#! && call :setname
    wimlib-imagex.exe info "ISOFOLDER\sources\install.wim" %%# "!_namea!" "!_namea!" --image-property DISPLAYNAME="!_nameb!" --image-property DISPLAYDESCRIPTION="!_nameb!" --image-property FLAGS=!edition%%#! %_Nul3%
    if !_ESDSrv%%#! equ 1 wimlib-imagex.exe info "ISOFOLDER\sources\install.wim" %%# "!_namea!" "!_namea!" --image-property DISPLAYNAME="!_nameb!" --image-property DISPLAYDESCRIPTION="!_namec!" --image-property FLAGS=!edition%%#! %_Nul3%
)
if %AddEdition% equ 1 for /L %%# in (%_nsum%,-1,1) do (
    imagex /info "ISOFOLDER\sources\install.wim" %%# | findstr /i "<EDITIONID>Core</EDITIONID> <EDITIONID>Professional</EDITIONID>" %_Nul3% || (
        %_Dism% /LogPath:"%_dLog%\DismDelete.log" /Delete-Image /ImageFile:"ISOFOLDER\sources\install.wim" /Index:%%# %_Nul3%
    )
)
call :update
for /f "tokens=3 delims=: " %%# in ('wimlib-imagex.exe info "ISOFOLDER\sources\install.wim" ^| findstr /c:"Image Count"') do set imgs=%%#
for /L %%# in (1,1,%imgs%) do (
    for /f "tokens=3 delims=<>" %%A in ('imagex /info "ISOFOLDER\sources\install.wim" %%# ^| find /i "<HIGHPART>"') do call set "HIGHPART%%#=%%A"
    for /f "tokens=3 delims=<>" %%A in ('imagex /info "ISOFOLDER\sources\install.wim" %%# ^| find /i "<LOWPART>"') do call set "LOWPART%%#=%%A"
    wimlib-imagex.exe info "ISOFOLDER\sources\install.wim" %%# --image-property CREATIONTIME/HIGHPART=!HIGHPART%%#! --image-property CREATIONTIME/LOWPART=!LOWPART%%#! %_Nul1%
)
if %AddEdition% equ 1 goto :ExportWim
for /f "tokens=3 delims=: " %%# in ('wimlib-imagex.exe info "ISOFOLDER\sources\install.wim" ^| findstr /c:"Image Count"') do set imgs=%%#
for /l %%# in (1,1,%imgs%) do (
    %_Dism% /LogPath:"%_dLog%\DismExport.log" /Export-Image /SourceImageFile:"ISOFOLDER\sources\install.wim" /SourceIndex:%%# /DestinationImageFile:"ISOFOLDER\sources\installnew.wim" %_Nul3%
    set ERRORTEMP=%ERRORLEVEL%
    if %ERRORTEMP% neq 0 goto :E_Export
)
if exist "ISOFOLDER\sources\installnew.wim" del /f /q "ISOFOLDER\sources\install.wim"&ren "ISOFOLDER\sources\installnew.wim" install.wim %_Nul3%
goto :%_rtrn%

:ExportWim
for /f "tokens=3 delims=: " %%# in ('wimlib-imagex.exe info "ISOFOLDER\sources\install.wim" ^| findstr /c:"Image Count"') do set imgs=%%#
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
    %_Dism% /LogPath:"%_dLog%\DismExport.log" /Export-Image /SourceImageFile:"ISOFOLDER\sources\install.wim" /SourceIndex:%%# /DestinationImageFile:"ISOFOLDER\sources\installnew.wim" %_Nul3%
    set ERRORTEMP=%ERRORLEVEL%
    if %ERRORTEMP% neq 0 goto :E_Export
)
if exist "ISOFOLDER\sources\installnew.wim" del /f /q "ISOFOLDER\sources\install.wim"&ren "ISOFOLDER\sources\installnew.wim" install.wim %_Nul3%
goto :%_rtrn%

:WinreWim
echo.
echo %line%
echo 正在创建 Winre.wim 文件……
echo %line%
echo.
%_psc% "Set-Date '2022/5/7 17:30:20'"
%_Dism% /LogPath:"%_dLog%\DismExport.log" /Export-Image /SourceImageFile:"!_DIR!\%uups_esd1%" /SourceIndex:2 /DestinationImageFile:temp\Winre.wim /Compress:max /Bootable
set ERRORTEMP=%ERRORLEVEL%
if %ERRORTEMP% neq 0 goto :E_Export
goto :%_rtrn%

:BootWim
echo.
echo %line%
echo 正在创建 boot.wim 文件……
echo %line%
echo.
%_Dism% /LogPath:"%_dLog%\DismExport.log" /Export-Image /SourceImageFile:"!_DIR!\%uups_esd1%" /SourceIndex:2 /DestinationImageFile:"ISOFOLDER\sources\boot.wim" /Compress:max
wimlib-imagex.exe info "ISOFOLDER\sources\boot.wim" 1 "Microsoft Windows PE (%_ss%)" "Microsoft Windows PE (%_ss%)" %_Nul3%
if %_build% lss 22000 wimlib-imagex.exe info "ISOFOLDER\sources\boot.wim" 1 "Microsoft Windows PE (%arch%)" "Microsoft Windows PE (%arch%)" %_Nul3%
wimlib-imagex.exe info "ISOFOLDER\sources\boot.wim" 1 --image-property FLAGS=9 %_Nul3%
%_Dism% /LogPath:"%_dLog%\DismExport.log" /Export-Image /SourceImageFile:"!_DIR!\%uups_esd1%" /SourceIndex:2 /DestinationImageFile:"ISOFOLDER\sources\boot.wim" /Compress:max /Bootable
wimlib-imagex.exe info "ISOFOLDER\sources\boot.wim" 2 "Microsoft Windows Setup (%arch%)" "Microsoft Windows Setup (%arch%)" %_Nul3%
if %_build% lss 22000 wimlib-imagex.exe info "ISOFOLDER\sources\boot.wim" 2 "Microsoft Windows Setup (%arch%)" "Microsoft Windows Setup (%arch%)" %_Nul3%
wimlib-imagex.exe info "ISOFOLDER\sources\boot.wim" 2 --image-property FLAGS=2 --boot %_Nul3%
if exist "%_mount%\" rmdir /s /q "%_mount%\"
if not exist "%_mount%\" mkdir "%_mount%"
%_Dism% /LogPath:"%_dLog%\DismMount.log" /Mount-Wim /Wimfile:"ISOFOLDER\sources\boot.wim" /Index:1 /MountDir:"%_mount%"
set ERRORTEMP=%ERRORLEVEL%
if %ERRORTEMP% neq 0 (
    %_Dism% /LogPath:"%_dLog%\DismUnMount.log" /Unmount-Wim /MountDir:"%_mount%" /Discard %_Nul3%
    Dism.exe /Cleanup-Wim %_Nul3%
    rmdir /s /q "%_mount%\" %_Nul3%
    del /f /q "ISOFOLDER\sources\boot.wim" %_Nul3%
    goto :BootDism
)
call :BootRemove
%_Dism% /LogPath:"%_dLog%\DismBoot.log" /Image:"%_mount%" /Set-TargetPath:X:\$Windows.~bt\
del /f /q %_mount%\Windows\system32\winpeshl.ini %_Nul3%
call :cleanup
%_Dism% /LogPath:"%_dLog%\DismUnMount.log" /Unmount-Wim /MountDir:"%_mount%" /Commit
if exist "%_mount%\" rmdir /s /q "%_mount%\"
if not exist "%_mount%\" mkdir "%_mount%"
%_Dism% /LogPath:"%_dLog%\DismMount.log" /Mount-Wim /Wimfile:"ISOFOLDER\sources\boot.wim" /Index:2 /MountDir:"%_mount%"
set ERRORTEMP=%ERRORLEVEL%
if %ERRORTEMP% neq 0 (
    %_Dism% /LogPath:"%_dLog%\DismUnMount.log" /Unmount-Wim /MountDir:"%_mount%" /Discard %_Nul3%
    Dism.exe /Cleanup-Wim %_Nul3%
    rmdir /s /q "%_mount%\" %_Nul3%
    del /f /q "ISOFOLDER\sources\boot.wim" %_Nul3%
    goto :BootDism
)
call :BootRemove
if exist "!_DIR!\WinPE-Setup\*WinPE-Setup*.cab" (call :BootAddCab) else (call :BootFileCopy)
del /f /q %_mount%\Windows\system32\winpeshl.ini %_Nul3%
copy ISOFOLDER\sources\lang.ini %_mount%\sources\lang.ini %_Nul3%
call :cleanup
%_Dism% /LogPath:"%_dLog%\DismUnMount.log" /Unmount-Wim /MountDir:"%_mount%" /Commit
for /f "tokens=3 delims=: " %%# in ('wimlib-imagex.exe info "ISOFOLDER\sources\boot.wim" ^| findstr /c:"Image Count"') do set imgs=%%#
for /L %%# in (1,1,%imgs%) do (
    for /f "tokens=3 delims=<>" %%A in ('imagex /info "ISOFOLDER\sources\boot.wim" %%# ^| find /i "<HIGHPART>"') do call set "HIGHPART%%#=%%A"
    for /f "tokens=3 delims=<>" %%A in ('imagex /info "ISOFOLDER\sources\boot.wim" %%# ^| find /i "<LOWPART>"') do call set "LOWPART%%#=%%A"
    wimlib-imagex.exe info "ISOFOLDER\sources\boot.wim" %%# --image-property CREATIONTIME/HIGHPART=!HIGHPART%%#! --image-property CREATIONTIME/LOWPART=!LOWPART%%#! %_Nul1%
)
for /f "tokens=3 delims=: " %%# in ('wimlib-imagex.exe info "ISOFOLDER\sources\boot.wim" ^| findstr /c:"Image Count"') do set imgs=%%#
for /l %%# in (1,1,%imgs%) do (
    %_Dism% /LogPath:"%_dLog%\DismExport.log" /Export-Image /SourceImageFile:"ISOFOLDER\sources\boot.wim" /SourceIndex:%%# /DestinationImageFile:"ISOFOLDER\sources\bootnew.wim" %_Nul3%
    set ERRORTEMP=%ERRORLEVEL%
    if %ERRORTEMP% neq 0 goto :E_Export
)
if exist "ISOFOLDER\sources\bootnew.wim" del /f /q "ISOFOLDER\sources\boot.wim"&ren "ISOFOLDER\sources\bootnew.wim" boot.wim %_Nul3%
goto :%_rtrn%

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

:BootAddCab
set "cabadd="
for /f "delims=" %%# in ('dir /b /a:-d "!_DIR!\WinPE-Setup\*WinPE-Setup.cab"') do set "cabadd=!cabadd! /PackagePath:!_DIR!\WinPE-Setup\%%#"
for /f "delims=" %%# in ('dir /b /a:-d "!_DIR!\WinPE-Setup\*WinPE-Setup_*.cab"') do set "cabadd=!cabadd! /PackagePath:!_DIR!\WinPE-Setup\%%#"
for /f "delims=" %%# in ('dir /b /a:-d "!_DIR!\WinPE-Setup\*WinPE-Setup-*.cab"') do set "cabadd=!cabadd! /PackagePath:!_DIR!\WinPE-Setup\%%#"
%_Dism% /LogPath:"%_dLog%\DismBoot.log" /Image:"%_mount%" /Add-Package !cabadd!
goto :eof

:BootFileCopy
wimlib-imagex.exe extract "!_DIR!\%uups_esd1%" 3 Windows\system32\xmllite.dll --dest-dir=ISOFOLDER\sources --no-acls --no-attributes %_Nul3%
copy /y ISOFOLDER\setup.exe %_mount%\setup.exe %_Nul3%
copy /y ISOFOLDER\sources\inf\setup.cfg %_mount%\sources\inf\setup.cfg %_Nul3%
set "_bkimg="
wimlib-imagex.exe extract "ISOFOLDER\sources\boot.wim" 1 Windows\System32\winpe.jpg --dest-dir=ISOFOLDER\sources --no-acls --no-attributes --nullglob %_Nul3%
for %%# in (background_cli.bmp, background_svr.bmp, background_cli.png, background_svr.png) do if exist "ISOFOLDER\sources\%%#" set "_bkimg=%%#"
if defined _bkimg (
    copy /y ISOFOLDER\sources\%_bkimg% %_mount%\sources\background.bmp %_Nul3%
    copy /y ISOFOLDER\sources\%_bkimg% %_mount%\Windows\system32\setup.bmp %_Nul3%
)
if not defined _bkimg (
    copy /y ISOFOLDER\sources\winpe.jpg %_mount%\sources\background.bmp %_Nul3%
    copy /y ISOFOLDER\sources\winpe.jpg %_mount%\Windows\system32\setup.bmp %_Nul3%
)
for /f %%# in (bin\bootwim.txt) do if exist "ISOFOLDER\sources\%%#" (
    copy /y ISOFOLDER\sources\%%# %_mount%\sources\%%# %_Nul3%
)
for /f %%# in (bin\bootmui.txt) do if exist "ISOFOLDER\sources\%langid%\%%#" (
    copy /y ISOFOLDER\sources\%langid%\%%# %_mount%\sources\%langid%\%%# %_Nul3%
)
del /f /q ISOFOLDER\sources\xmllite.dll %_Nul3%
del /f /q ISOFOLDER\sources\winpe.jpg %_Nul3%
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
if %_build% geq 21382 if exist "!_DIR!\*.AggregatedMetadata*.cab" if exist "!_DIR!\*Windows1*-KB*.cab" if exist "!_DIR!\*Windows1*-KB*.psf" set _reMSU=1
if %_build% geq 25336 if exist "!_DIR!\*.AggregatedMetadata*.cab" if exist "!_DIR!\*Windows1*-KB*.wim" if exist "!_DIR!\*Windows1*-KB*.psf" set _reMSU=1
if %_build% geq 22563 if exist "!_DIR!\*.AggregatedMetadata*.cab" (
if exist "!_DIR!\*.*xbundle" set _IPA=1
if exist "!_DIR!\*.appx" set _IPA=1
if exist "!_DIR!\Apps\*_8wekyb3d8bbwe" set _IPA=1
)
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
exit /b

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

:uups_ref
echo.
echo %line%
echo 正在将 .cab 转换为 .esd 文件……
echo %line%
echo.
if %RefESD% neq 0 (set _level=LZMS) else (set _level=XPRESS)
if exist "!_DIR!\*.xml.cab" if exist "!_DIR!\Metadata\*" move /y "!_DIR!\*.xml.cab" "!_DIR!\Metadata\" %_Nul3%
if exist "!_DIR!\*.cab" (
    for /f "tokens=* delims=" %%# in ('dir /b /a:-d "!_DIR!\*.cab"') do (
        del /f /q temp\update.mum %_Nul3%
        expand.exe -f:update.mum "!_DIR!\%%#" temp %_Nul3%
        if exist "temp\update.mum" call :uups_cab "%%#"
    )
)
if %EXPRESS% equ 1 (
    for /f "tokens=* delims=" %%# in ('dir /b /a:d /o:-n "!_DIR!\"') do call :uups_dir "%%#"
)
if exist "!_DIR!\Metadata\*.xml.cab" copy /y "!_DIR!\Metadata\*.xml.cab" "!_DIR!\" %_Nul3%
if %RefESD% neq 0 call :uups_backup
if not exist "!_DIR!\*Package*.esd" exit /b
mkdir "!_DIR!\CanonicalUUP" %_Nul3%
mkdir "!_DIR!\Original" %_Nul3%
for /f %%# in ('dir /b /a:-d "!_DIR!\*.esd" %_Nul6%') do if not exist "!_DIR!\CanonicalUUP\%%#" (move /y "!_DIR!\%%#" "!_DIR!\CanonicalUUP\" %_Nul3%)
for /f %%# in ('dir /b /a:-d "!_DIR!\*.cab"') do (
echo %%# | findstr /i /r "Windows.*-KB SSU-.* DesktopDeployment AggregatedMetadata" %_Nul1% || move /y "!_DIR!\%%#" "!_DIR!\Original\" %_Nul3%
)
if exist "temp\*.esd" (set _rrr=--ref="temp\*.esd") else (set "_rrr=")
for /L %%# in (1, 1,%_nsum%) do (
    wimlib-imagex.exe export "!_DIR!\CanonicalUUP\!uups_esd%%#!" all "!_DIR!\!uups_esd%%#!" --ref="!_DIR!\CanonicalUUP\*.esd" %_rrr% --compress=LZMS --solid
)
exit /b

:uups_dir
set cbsp=%~1
if exist "temp\%cbsp%.esd" exit /b
echo %cbsp% | findstr /i /r "Windows.*-KB SSU-.* RetailDemo Holographic-Desktop-FOD" %_Nul1% && exit /b
if /i "%cbsp%"=="Metadata" exit /b
echo 转换为 ESD 文件：%cbsp%.cab
rmdir /s /q "!_DIR!\%~1\$dpx$.tmp\" %_Nul3%
wimlib-imagex.exe capture "!_DIR!\%~1" "temp\%cbsp%.esd" --compress=%_level% --check --no-acls --norpfix "Edition Package" "Edition Package" %_Nul3%
exit /b

:uups_cab
set cbsp=%~n1
if exist "temp\%cbsp%.esd" exit /b
echo %cbsp% | findstr /i /r "Windows.*-KB SSU-.* RetailDemo Holographic-Desktop-FOD" %_Nul1% && exit /b
echo %cbsp%
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

:uups_backup
if not exist "!_work!\temp\*.esd" exit /b
echo.
echo %line%
echo 正在备份 .esd 文件……
echo %line%
echo.
if %EXPRESS% equ 1 (
mkdir "!_work!\CanonicalUUP" %_Nul3%
move /y "!_work!\temp\*.esd" "!_work!\CanonicalUUP\" %_Nul3%
for /L %%# in (1,1,%uups_esd_num%) do copy /y "!_DIR!\!uups_esd%%#!" "!_work!\CanonicalUUP\" %_Nul3%
for /f %%# in ('dir /b /a:-d "!_DIR!\*Package*.esd" %_Nul6%') do if not exist "!_work!\CanonicalUUP\%%#" (copy /y "!_DIR!\%%#" "!_work!\CanonicalUUP\" %_Nul3%)
exit /b
)
mkdir "!_DIR!\Original" %_Nul3%
move /y "!_work!\temp\*.esd" "!_DIR!\" %_Nul3%
for /f %%# in ('dir /b /a:-d "!_DIR!\*.cab"') do (
echo %%#| findstr /i /r "Windows.*-KB SSU-.* DesktopDeployment AggregatedMetadata" %_Nul1% || move /y "!_DIR!\%%#" "!_DIR!\Original\" %_Nul3%
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
if %_inx% equ 1 %_psc% "Set-Date '2022/5/7 19:10:16'"
if %_inx% equ 2 %_psc% "Set-Date '2022/5/7 20:05:08'"
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
if not exist "%_mount%\Windows\Servicing\Packages\*WinPE-LanguagePack*.mum" if %_wimEdge% equ 1 call :AddEdge
if exist "%_mount%\Windows\Servicing\Packages\*WinPE-LanguagePack*.mum" goto :Done
call :AddWinre
if exist "%_mount%\Windows\Servicing\Packages\Microsoft-Windows-Server*CorEdition~*.mum" goto :DoneApps
if %AddAppxs% equ 1 if exist "!_DIR!\Apps\*_8wekyb3d8bbwe" call :AddAppx
:DoneApps
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

:AddEdge
if exist "%_mount%\Program Files (x86)\Microsoft\Edge" goto :eof
echo.
echo 正在添加 Microsoft Edge……
%_Dism% /LogPath:"%_dLog%\DismEdge.log" /Image:"%_mount%" /Add-Edge /SupportPath:"!_DIR!"
if !errorlevel! neq 0 echo 添加 Edge.wim 失败
goto :eof

:appx_sort
echo.
echo %line%
echo 正在解析应用 CompDB 信息……
echo %line%
echo.
if %_pwsh% equ 0 (
echo.
echo 未检测到 Windows PowerShell，将跳过操作。
goto :eof
)
pushd "!_DIR!"
for /f "delims=" %%# in ('dir /b /a:-d "*.AggregatedMetadata*.cab"') do set "_mdf=%%#"
if exist "_tmpMD\" rmdir /s /q "_tmpMD\" %_Nul3%
mkdir "_tmpMD"
expand.exe -f:*TargetCompDB_* "%_mdf%" _tmpMD %_Null%
expand.exe -r -f:*.xml "_tmpMD\*%langid%*.cab" _tmpMD %_Null%
expand.exe -r -f:*.xml "_tmpMD\*TargetCompDB_App_*.cab" _tmpMD %_Null%
if not exist "_tmpMD\*TargetCompDB_App_*.xml" (
echo.
echo 由于 CompDB_App.xml 文件没有找到，将跳过操作。
rmdir /s /q "_tmpMD\" %_Nul3%
popd
goto :eof
)
copy /y "!_work!\bin\CompDB_App.txt" . %_Nul3%
for %%# in (CoreCountrySpecific, Core, PPIPro, ProfessionalCountrySpecific, Professional) do (
    if exist _tmpMD\*CompDB_%%#_*%langid%*.xml for /f %%i in ('dir /b /a:-d "_tmpMD\*CompDB_%%#_*%langid%*.xml"') do (
        copy /y _tmpMD\%%i .\CompDB_App.xml %_Nul1%
        %_Nul3% %_psc% "Set-Location -LiteralPath '!_DIR!'; $f=[IO.File]::ReadAllText('.\CompDB_App.txt') -split ':embed\:.*'; $id='%%#'; $lang='%langid%'; iex ($f[2])"
    )
    if exist _tmpMD\*TargetCompDB_App_Moment_*.xml for /f %%i in ('dir /b /a:-d "_tmpMD\*TargetCompDB_App_Moment_*.xml"') do (
        copy /y _tmpMD\%%i .\CompDB_App.xml %_Nul1%
        %_Nul3% %_psc% "Set-Location -LiteralPath '!_DIR!'; $f=[IO.File]::ReadAllText('.\CompDB_App.txt') -split ':embed\:.*'; $id='%%#'; $lang='%langid%'; iex ($f[2])"
    )
)
for /f "delims=" %%# in ('dir /b /a:-d "_tmpMD\*TargetCompDB_App_*.xml" %_Nul6%') do (
copy /y _tmpMD\%%# .\CompDB_App.xml %_Nul1%
%_Nul3% %_psc% "Set-Location -LiteralPath '!_DIR!'; $f=[IO.File]::ReadAllText('.\CompDB_App.txt') -split ':embed\:.*'; iex ($f[1])"
)
if exist Apps_*.txt if exist "Apps\*_8wekyb3d8bbwe" move /y Apps_*.txt Apps\ %_Nul1%
del /f /q CompDB_App.* %_Nul3%
rmdir /s /q "_tmpMD\" %_Nul3%
popd
goto :eof

:AddWinre
if not exist temp\Winre.wim goto :eof
echo.
echo %line%
echo 正在将 Winre.wim 添加到 install.wim 中……
echo %line%
echo.
if exist "%_mount%\Windows\System32\Recovery\Winre.wim" (
    takeown /f "%_mount%\Windows\System32\Recovery\Winre.wim" /A %_Nul3%
    icacls "%_mount%\Windows\System32\Recovery\Winre.wim" /grant *S-1-5-32-544:F %_Nul3%
    del /f /q "%_mount%\Windows\System32\Recovery\Winre.wim" %_Nul3%
)
copy /y "temp\Winre.wim" "%_mount%\Windows\System32\Recovery\Winre.wim" %_Nul3%
goto :eof

:AddAppx
echo.
echo %line%
echo 正在安装 Appxs 软件包……
echo %line%
echo.
pushd "!_DIR!\Apps"
call :AddFramework
if exist Custom_Appxs.txt for /f "eol=# tokens=* delims=" %%i in (Custom_Appxs.txt) do call :AddAppxs "%%i"
for /f "tokens=3 delims=: " %%# in ('%_Dism% /English /Image:"%_mount%" /Get-CurrentEdition ^| findstr /c:"Current Edition"') do set editionid=%%#
if not exist Custom_Appxs.txt if exist Apps_%editionid%.txt for /f "eol=# tokens=* delims=" %%i in (Apps_%editionid%.txt) do call :AddAppxs "%%i"
if not exist Custom_Appxs.txt if not exist Apps_*.txt for /f %%i in ('dir /b *') do if /i not "%%i"=="MSIXFramework" call :AddAppxs "%%i"
popd
goto :eof

:AddFramework
if exist "MSIXFramework\*" for /f "tokens=* delims=" %%# in ('dir /b /a:-d "MSIXFramework\*.*x"') do %_Dism% /LogPath:"%_dLog%\DismAppx.log" /English /Image:"%_mount%" /Add-ProvisionedAppxPackage /PackagePath:"MSIXFramework\%%#" /SkipLicense | findstr /i /c:"successfully" %_Nul3% && echo %%~n#
goto :eof

:AddAppxs
set "_pfn=%~1"
if not exist "%_pfn%\License.xml" goto :eof
if not exist "%_pfn%\*.appx*" if not exist "%_pfn%\*.msix*" goto :eof
set "_main=" & set "_mainn=" 
if not defined _main if exist "%_pfn%\*.msixbundle" for /f "tokens=* delims=" %%# in ('dir /b /a:-d "%_pfn%\*.msixbundle"') do set "_main=%%#" & set "_mainn=%%~n#"
if not defined _main if exist "%_pfn%\*.appxbundle" for /f "tokens=* delims=" %%# in ('dir /b /a:-d "%_pfn%\*.appxbundle"') do set "_main=%%#" & set "_mainn=%%~n#"
if not defined _main if exist "%_pfn%\*.appx" for /f "tokens=* delims=" %%# in ('dir /b /a:-d "%_pfn%\*.appx"') do set "_main=%%#" & set "_mainn=%%~n#"
if not defined _main if exist "%_pfn%\*.msix" for /f "tokens=* delims=" %%# in ('dir /b /a:-d "%_pfn%\*.msix"') do set "_main=%%#" & set "_mainn=%%~n#"
if not defined _main goto :eof
set "_stub="
if exist "%_pfn%\AppxMetadata\Stub\*.*x" if %_SrvESD% neq 1 set "_stub=/StubPackageOption:InstallStub"
%_Dism% /LogPath:"%_dLog%\DismAppx.log" /English /Image:"%_mount%" /Add-ProvisionedAppxPackage /PackagePath:"%_pfn%\%_main%" /LicensePath:"%_pfn%\License.xml" /Region:all %_stub% | findstr /i /c:"successfully" %_Nul3% && echo %_mainn%
goto :eof

:RemoveAppx
echo.
echo %line%
echo 正在卸载 Appxs 软件包……
echo %line%
echo.
for /f "eol=# tokens=* delims=" %%i in ('type "!_DIR!\Apps\Remove_Appxs.txt"') do (
    %_Dism% /LogPath:"%_dLog%\DismAppx.log" /English /Image:"%_mount%" /Remove-ProvisionedAppxPackage /PackageName:%%i | findstr /i /c:"successfully" %_Nul3% && echo %%i
)
goto :eof

:setedition
call :setname
echo.
echo 正在处理 !_nameb!
if exist "%_mount%\Windows\Core.xml" del /f /q "%_mount%\Windows\Core.xml" %_Nul3%
if exist "%_mount%\Windows\CoreSingleLanguage.xml" del /f /q "%_mount%\Windows\CoreSingleLanguage.xml" %_Nul3%
if exist "%_mount%\Windows\CoreCountrySpecific.xml" del /f /q "%_mount%\Windows\CoreCountrySpecific.xml" %_Nul3%
if exist "%_mount%\Windows\Education.xml" del /f /q "%_mount%\Windows\Education.xml" %_Nul3%
if exist "%_mount%\Windows\Professional.xml" del /f /q "%_mount%\Windows\Professional.xml" %_Nul3%
if exist "%_mount%\Windows\ProfessionalSingleLanguage.xml" del /f /q "%_mount%\Windows\ProfessionalSingleLanguage.xml" %_Nul3%
if exist "%_mount%\Windows\ProfessionalCountrySpecific.xml" del /f /q "%_mount%\Windows\ProfessionalCountrySpecific.xml" %_Nul3%
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
if %_SrvESD% equ 1 wimlib-imagex.exe info "%_www%" %%# "!_namea!" "!_namea!" --image-property DISPLAYNAME="!_nameb!" --image-property DISPLAYDESCRIPTION="!_namec!" --image-property FLAGS=!edition%%#! %_Nul3%
echo.
goto :eof

:setname
for %%# in (
    "Core:%_wtx% Home:%_wtx% 家庭版"
    "CoreSingleLanguage:%_wtx% Home Single Language:%_wtx% 家庭单语言版"
    "CoreCountrySpecific:%_wtx% Home China:%_wtx% 家庭中文版"
    "Education:%_wtx% Education:%_wtx% 教育版"
    "Professional:%_wtx% Pro:%_wtx% 专业版"
    "ProfessionalSingleLanguage:%_wtx% Pro Single Language:%_wtx% 专业单语言版"
    "ProfessionalCountrySpecific:%_wtx% Pro China:%_wtx% 专业中文版"
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
(
    echo Windows Registry Editor Version 5.00
    echo.
    echo [%_IFEO%]
    echo "MitigationOptions"=hex^(b^):00,00,22,00,00,00,00,00
)>temp\DismAdd.reg
reg.exe query "%_IFEO%" /v MitigationOptions %_Nul3%
if %errorlevel% equ 0 (
    reg.exe export "%_IFEO%" temp\DismOrg.reg %_Nul3%
)
reg.exe import temp\DismAdd.reg %_Nul3%
exit /b

:DismHostOFF
if %winbuild% lss 9200 exit /b
if %_MOifeo% equ 0 exit /b
(
    echo Windows Registry Editor Version 5.00
    echo.
    echo [-%_IFEO%]
)>temp\DismRem.reg
if exist "temp\DismOrg.reg" (
    reg.exe import temp\DismOrg.reg %_Nul3%
) else (
    reg.exe import temp\DismRem.reg %_Nul3%
)
del /f /q temp\Dism*.reg %_Nul3%
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
if exist "!_cabdir!\" rmdir /s /q "!_cabdir!\" %_Nul3%
if exist "bin\MSDelta.dll" del /f /q "bin\MSDelta.dll" %_Nul3%
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
