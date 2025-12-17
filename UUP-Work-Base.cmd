@setlocal DisableDelayedExpansion
@set "uivr=v25.12.17-120"
@echo off

:: 若要启用调试模式，请将此参数更改为 1
set _Debug=0

:: 若要清理映像以增量压缩已取代的组件，请将此参数更改为 1（警告：在 18362 及以上版本中，这将会删除基础 RTM 版本程序包）
set Cleanup=1

:: 若要重置操作系统映像（ResetBase），请将此参数更改为 1（快于默认的增量压缩）
:: 需要前置参数  Cleanup 为 1
:: 在 26052 及更高版本每个累积更新后重置操作系统映像，请将此参数更改为 2
set ResetBase=1

:: 若不需要创建 ISO 文件，保留原始文件夹，请将此参数更改为 1
set SkipISO=0

:: 若要保留关联 ESD 文件，请将此参数更改为 1
set RefESD=1

:: 若仅更新选定镜像，请将此参数更改为所需更新的镜像标志（Edition ID）
:: 例如: Core,Professional,ServerDatacenter 等
set ChoiceEdition=

:: 若使用现有镜像升级 Windows 版本并保存（不适用于 Windows Server），请将此参数更改为 1
set UpgradeEdition=0

:: 若对更新后的镜像进行排序，请将此参数更改为镜像标志（Edition ID）顺序
:: 不适用于 Windows Server，需要前置参数 UpgradeEdition 为 1
:: 例如: Core,CoreSingleLanguage,Education,Professional,ProfessionalEducation,ProfessionalWorkstation
set SortEditions=Core,CoreSingleLanguage,Education,Professional,ProfessionalEducation,ProfessionalWorkstation

:: 若在完成时退出进程而不提示，请将此参数更改为 1
set AutoExit=1

set "_Null=1>nul 2>nul"
set "FullExit=exit /b"

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
set "_err=echo: &echo ==== 出现错误 ===="
set "_psc=powershell -nop -c"
set winbuild=1
for /f "tokens=6 delims=[]. " %%# in ('ver') do set winbuild=%%#
set _cwmi=0
for %%# in (wmic.exe) do @if not "%%~$PATH:#"=="" (
  cmd /c "wmic path Win32_ComputerSystem get CreationClassName /value" 2>nul | find /i "ComputerSystem" 1>nul && set _cwmi=1
)
set _pwsh=1
for %%# in (powershell.exe) do @if "%%~$PATH:#"=="" set _pwsh=0
cmd /c "%_psc% "$ExecutionContext.SessionState.LanguageMode"" | find /i "FullLanguage" 1>nul || (set _pwsh=0)
call :pr_color
if %_cwmi% equ 0 if %_pwsh% equ 0 goto :E_PowerShell

set _uac=-elevated
%_Null% reg.exe query HKU\S-1-5-19 && goto :Passed || if defined _elev goto :E_Admin

set _PSarg="""%~f0""" %_uac%
if defined _args set _PSarg="""%~f0""" %_args:"="""% %_uac%
set _PSarg=%_PSarg:'=''%

call setlocal EnableDelayedExpansion
for %%# in (wt.exe) do @if "%%~$PATH:#"=="" %_Null% %_psc% "start cmd.exe -arg '/c !_PSarg!' -verb runas" && exit /b || goto :E_Admin
%_Null% %_psc% "start wt -arg '!_PSarg!' -verb runas" && exit /b || goto :E_Admin

:Passed
@cls
set "_log=%~dpn0"
set "_work=%~dp0"
set "_work=%_work:~0,-1%"
set _drv=%~d0
set "_cabdir=%_drv%\Updates"
if "%_work:~0,2%"=="\\" set "_cabdir=%~dp0temp\Updates"
for /f "skip=2 tokens=2*" %%a in ('reg.exe query "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" /v Desktop') do call set "_dsk=%%b"
if exist "%PUBLIC%\Desktop\desktop.ini" set "_dsk=%PUBLIC%\Desktop"
call :preVars
setlocal EnableDelayedExpansion

if %_Debug% equ 0 (
  set "_Nul1=1>nul"
  set "_Nul2=2>nul"
  set "_Nul6=2^>nul"
  set "_Nul3=1>nul 2>nul"
  goto :Begin
)
set "_Nul1="
set "_Nul2="
set "_Nul6="
set "_Nul3="
copy /y nul "!_work!\#.rw" %_Null% && (if exist "!_work!\#.rw" del /f /q "!_work!\#.rw") || (set "_log=!_dsk!\%~n0")
echo.
echo 正在调试模式下运行...
echo 当完成之后，此窗口将会关闭
@echo on
@prompt $G
@call :Begin %_args% >"!_log!_tmp.log" 2>&1 &cmd /u /c type "!_log!_tmp.log">"!_log!_Debug.log"&del /f /q "!_log!_tmp.log"
@exit /b

:Begin
@cls
title UUP 生成 / ISO 更新
set "_dLog=%SystemRoot%\Logs\DISM"
set "_Dism=Dism.exe /ScratchDir:"!_cabdir!""
set W10UI=0
if %winbuild% geq 10240 (
  set W10UI=1
)
call :postVars

:check
pushd "!_work!"
set _fils=(7z.dll,7z.exe,bootmui.txt,bootwim.txt,oscdimg.exe,imagex.exe,libwim-15.dll,offlinereg.exe,offreg64.dll,wimlib-imagex.exe,PSFExtractor.exe)
for %%# in %_fils% do (
  if not exist "bin\%%#" (set _bin=%%#&goto :E_BinMiss)
)
if exist ISOFOLDER\ rmdir /s /q ISOFOLDER\
if exist temp\ rmdir /s /q temp\
mkdir temp

:findargs
echo.
if defined _args for %%# in (%*) do (
  if exist "%%~#\*.esd" ( set "_DIR=%%~f#" & echo %%~# & goto :checkuup)
  if exist "%%~#\*Windows1*-KB*" ( set "_DIR=%%~f#" & echo %%~# )
)
if not defined _DIR goto :selectdir

:selectdir
echo.
for /f "tokens=* delims=" %%# in ('dir /b /ad "!_work!"') do (
  if exist "%%~#\*.esd" ( set /a _nesd+=1 & set "_DIR=%%~f#" & echo %%~# )
  if exist "%%~#\*Windows1*-KB*" if not exist "%%~#\*.esd" ( set /a _nupd+=1 & set "_DIR=%%~f#"&echo %%~# )
)
if !_nesd! equ 1 if !_nupd! equ 0 if defined _DIR goto :checkuup
if !_nesd! equ 0 if !_nupd! equ 1 if defined _DIR goto :selectiso
set _DIR=
echo.
echo 使用 Tab 键选择或输入 UUP 文件夹或更新文件夹
echo %line%
echo.
set /p _DIR=
if not defined _DIR (
  echo.
  %_err%
  call :dk_color1 %Red% "未指定文件（夹）"
  echo.
  goto :selectdir
)
set "_DIR=%_DIR:"=%"
for %%# in ("!_DIR!") do set "_DIR=%%~f#"
if "%_DIR:~-1%"=="\" set "_DIR=%_DIR:~0,-1%"
if not exist "%_DIR%\*.esd" if not exist "%_DIR%\*Windows1*-KB*" (
  echo.
  %_err%
  call :dk_color1 %Red% "指定的文件夹内无 UUP 文件或更新文件"
  echo.
  goto :selectdir
)
if exist "%_DIR%\*.esd" goto :checkuup

:checkuup
@cls
if "%_DIR:~-1%"=="\" set "_DIR=%_DIR:~0,-1%"
call :dk_color1 %_Green% "UUPs 文件夹： !_DIR!" 4
call :dk_color1 %Gray% "正在检查 ESD 文件信息..." 4
dir /b /ad "!_DIR!\*Package*" %_Nul3% && set EXPRESS=1
for %%# in (
  Core,CoreN,CoreSingleLanguage,CoreCountrySpecific
  Professional,ProfessionalN,ProfessionalEducation,ProfessionalEducationN,ProfessionalWorkstation,ProfessionalWorkstationN
  Education,EducationN,Enterprise,EnterpriseN,EnterpriseG,EnterpriseGN,EnterpriseS,EnterpriseSN,ServerRdsh
  PPIPro,IoTEnterprise,IoTEnterpriseK,IoTEnterpriseS,IoTEnterpriseSK
  Cloud,CloudN,CloudE,CloudEN,CloudEdition,CloudEditionN,CloudEditionL,CloudEditionLN
  Starter,StarterN,ProfessionalCountrySpecific,ProfessionalSingleLanguage
  ServerStandardCore,ServerStandard,ServerDatacenterCore,ServerDatacenter,ServerTurbineCore,ServerTurbine,ServerAzureStackHCICor
  WNC
) do (
  if exist "!_DIR!\%%#_*.esd" (dir /b /a:-d "!_DIR!\%%#_*.esd">>temp\uups_esd.txt %_Nul2%)
  else if exist "!_DIR!\MetadataESD_%%#_*.esd" (dir /b /a:-d "!_DIR!\MetadataESD_%%#_*.esd">>temp\uups_esd.txt %_Nul2%)
)
for /f "tokens=3 delims=: " %%# in ('find /v /c "" temp\uups_esd.txt %_Nul6%') do set _nsum=%%#
if %_nsum% equ 0 goto :E_NotFind
for /l %%# in (1,1,%_nsum%) do call :mediacheck %%#
set "wimindex="!_DIR!\%uups_esd1%" 3"
if defined eWIMLIB goto :QUIT
goto :ISO

:ISO
if %PREPARED% equ 0 call :PREPARE
if %Cleanup% equ 0 set ResetBase=0
if defined ChoiceEdition set UpgradeEdition=0
if %_Srvr% equ 1 set UpgradeEdition=0
if defined _DismHost call :DismHostON

if exist "!_cabdir!\" rmdir /s /q "!_cabdir!\" %_Nul3%
if not exist "!_cabdir!\" mkdir "!_cabdir!" %_Nul3%
if exist "%_dLog%\*" del /f /q %_dLog%\* %_Nul3%
if not exist "%_dLog%\" mkdir "%_dLog%" %_Nul3%
if not exist "%SystemRoot%\temp\" mkdir "%SystemRoot%\temp" %_Nul3%
del /f /q %SystemRoot%\temp\*.mum %_Nul3%

if not exist "!_DIR!\*.esd" goto :notuups
call :uups_ref
call :dk_color1 %Blue% "=== 正在部署 ISO 安装文件..." 4
if exist ISOFOLDER\ rmdir /s /q ISOFOLDER\
mkdir ISOFOLDER
wimlib-imagex.exe apply "!_DIR!\%uups_esd1%" 1 ISOFOLDER\ --no-acls --no-attributes %_Nul3%
set ERRTEMP=%ERRORLEVEL%
if %ERRTEMP% neq 0 goto :E_Apply

:notuups
if exist ISOFOLDER\MediaMeta.xml del /f /q ISOFOLDER\MediaMeta.xml %_Nul3%
if exist ISOFOLDER\__chunk_data del /f /q ISOFOLDER\__chunk_data %_Nul3%
if exist ISOFOLDER\sources\product.ini del /f /q ISOFOLDER\sources\product.ini %_Nul3%
if exist ISOFOLDER\_manifest rmdir /s /q ISOFOLDER\_manifest %_Nul3%
if exist ISOFOLDER\sources\_manifest rmdir /s /q ISOFOLDER\sources\_manifest %_Nul3%

set _rtrn=WinreRet
goto :WinreWim
:WinreRet
set _rtrn=BootRet
goto :BootWim
:BootRet
set _rtrn=InstallRet
goto :InstallWim
:InstallRet
call :dk_color1 %Blue% "=== 正在创建 ISO ..." 4
for /f %%a in ('%_psc% "(Get-item "ISOFOLDER\sources\install.wim").LastWriteTime.ToString('MM/dd/yyyy,HH:mm:ss')"') do set isotime=%%a
if /i not %arch%==arm64 (
  oscdimg.exe -bootdata:2#p0,e,b"ISOFOLDER\boot\etfsboot.com"#pEF,e,b"ISOFOLDER\efi\Microsoft\boot\efisys.bin" -o -m -u2 -udfver102 -t%isotime% -l%DVDLABEL% ISOFOLDER %DVDISO%.iso
) else (
  oscdimg.exe -bootdata:1#pEF,e,b"ISOFOLDER\efi\Microsoft\boot\efisys.bin" -o -m -u2 -udfver102 -t%isotime% -l%DVDLABEL% ISOFOLDER %DVDISO%.iso
)
set ERRTEMP=%ERRORLEVEL%
if %ERRTEMP% neq 0 goto :E_ISOC
call :dk_color1 %Green% "完成。" 4
goto :QUIT

:InstallWim
if not exist "ISOFOLDER\sources\install.wim" call :CreateInstallWim
if defined ChoiceEdition call :ChoiceEdition
if %_Srvr% neq 1 if %UpgradeEdition% equ 1 call :UpgradeEdition
call :AddWinre
if %_wimEdge% neq 1 if %Cleanup% neq 1 goto :%_rtrn%
call :update "ISOFOLDER\sources\install.wim"
if %UpgradeEdition% equ 1 call :SortEditions
goto :InstallDone

:CreateInstallWim
set "_www=!_DIR!\!uups_esd%_nsum%!" & set _inx=%_nsum% & call :WimDate
call :dk_color1 %Blue% "=== 正在创建 install.wim 文件..." 4 5
if exist "temp\*.esd" (set _rrr=--ref="temp\*.esd") else (set "_rrr=")
for /l %%# in (1, 1,%_nsum%) do (
  wimlib-imagex.exe export "!_DIR!\!uups_esd%%#!" 3 "ISOFOLDER\sources\install.wim" --ref="!_DIR!\*.esd" %_rrr% --compress=LZX
  call set ERRTEMP=!ERRORLEVEL!
  if !ERRTEMP! neq 0 goto :E_Export
  set nedition=!edition%%#! && call :setname
  wimlib-imagex.exe info "ISOFOLDER\sources\install.wim" %%# "!_namea!" "!_namea!" --image-property DISPLAYNAME="!_nameb!" --image-property DISPLAYDESCRIPTION="!_nameb!" --image-property FLAGS=!edition%%#! %_Nul3%
  if !_ESDSrv%%#! equ 1 wimlib-imagex.exe info "ISOFOLDER\sources\install.wim" %%# "!_namea!" "!_namea!" --image-property DISPLAYNAME="!_nameb!" --image-property DISPLAYDESCRIPTION="!_namec!" --image-property FLAGS=!edition%%#! %_Nul3%
)
goto :eof

:ChoiceEdition
set _choice=
for %%A in (%ChoiceEdition%) do for /l %%# in (1,1,%_nsum%) do if "!edition%%#!"=="%%A" set _choice=!_choice!,%%#
if defined _choice for /l %%# in (%_nsum%,-1,1) do echo !_choice! | findstr /i "%%#" %_Nul3% || (
  %_Dism% /LogPath:"%_dLog%\DismDelete.log" /Delete-Image /ImageFile:"ISOFOLDER\sources\install.wim" /Index:%%# %_Nul3%
)
goto :eof

:UpgradeEdition
for /l %%# in (%_nsum%,-1,1) do imagex.exe /info "ISOFOLDER\sources\install.wim" %%# | findstr /i "<EDITIONID>Core</EDITIONID> <EDITIONID>Professional</EDITIONID> <EDITIONID>EnterpriseS</EDITIONID>" %_Nul3% || (
  %_Dism% /LogPath:"%_dLog%\DismDelete.log" /Delete-Image /ImageFile:"ISOFOLDER\sources\install.wim" /Index:%%# %_Nul3%
)
goto :eof

:SortEditions
for /f "tokens=3 delims=: " %%# in ('wimlib-imagex.exe info "ISOFOLDER\sources\install.wim" ^| findstr /c:"Image Count"') do set imgs=%%#
if %imgs% equ 1 goto :eof
call :dk_color1 %Blue% "=== 正在排序 install.wim 文件的 SKU 版本……" 4 5
set tcount=0
for %%A in (%SortEditions%) do for /l %%# in (1,1,%imgs%) do imagex.exe /info "ISOFOLDER\sources\install.wim" %%# | findstr /i "<EDITIONID>%%A</EDITIONID>" %_Nul3% && (
  set /a tcount+=1
  echo !tcount!. %%A
  wimlib-imagex.exe export "ISOFOLDER\sources\install.wim" %%# "ISOFOLDER\sources\installnew.wim" %_Nul3%
  set ERRTEMP=!ERRORLEVEL!
  if !ERRTEMP! neq 0 goto :E_Export
)
if exist "ISOFOLDER\sources\installnew.wim" del /f /q "ISOFOLDER\sources\install.wim"&ren "ISOFOLDER\sources\installnew.wim" install.wim %_Nul3%
goto :eof

:InstallDone
echo.
wimlib-imagex.exe optimize "ISOFOLDER\sources\install.wim"
goto :%_rtrn%

:AddWinre
if not exist "temp\Winre.wim" goto :eof
%_Nul3% %_psc% "Set-Date (Get-Item 'temp\Winre.wim').LastWriteTime"
call :dk_color1 %Blue% "=== 正在将 Winre.wim 添加到 install.wim 中..." 4
for /f "tokens=3 delims=: " %%# in ('wimlib-imagex.exe info "ISOFOLDER\sources\install.wim" ^| findstr /c:"Image Count"') do set imgcount=%%#
for /l %%# in (1,1,%imgcount%) do wimlib-imagex.exe update "ISOFOLDER\sources\install.wim" %%# --command="add 'temp\Winre.wim' '\Windows\System32\Recovery\Winre.wim'" %_Nul3%
goto :eof

:WinreWim
if not exist "temp\Winre.wim" if exist "!_DIR!\Winre.wim" copy /y "!_DIR!\Winre.wim" "temp\Winre.wim" %_Nul3%
if not exist "temp\Winre.wim" call :CreateWinreWim
if %Cleanup% neq 1 goto :%_rtrn%
call :update "temp\Winre.wim"
goto :WinreDone

:CreateWinreWim
set "_www=!_DIR!\%uups_esd1%" & set _inx=2 & call :WimDate
call :dk_color1 %Blue% "=== 正在导出 Winre.wim 文件..." 4 5
wimlib-imagex.exe export "!_DIR!\%uups_esd1%" 2 "temp\Winre.wim" --compress=LZX --boot
set ERRTEMP=%ERRORLEVEL%
if %ERRTEMP% neq 0 goto :E_Export
goto:eof

:WinreDone
echo.
wimlib-imagex.exe optimize "temp\Winre.wim"
goto :%_rtrn%

:BootWim
if not exist "ISOFOLDER\sources\boot.wim" if exist "!_DIR!\boot.wim" copy /y "!_DIR!\boot.wim" "ISOFOLDER\sources\boot.wim" %_Nul3%
if not exist "ISOFOLDER\sources\boot.wim" goto :CreateBootWim
if %Cleanup% neq 1 goto :%_rtrn%
call :update "ISOFOLDER\sources\boot.wim"
goto :BootDone

:CreateBootWim
call :dk_color1 %Blue% "=== 正在创建 boot.wim 文件..." 4 5
wimlib-imagex.exe export "!_DIR!\%uups_esd1%" 2 "ISOFOLDER\sources\boot.wim" "Microsoft Windows PE (%_ss%)" "Microsoft Windows PE (%_ss%)" --compress=LZX
if %_build% lss 22000 wimlib-imagex.exe info "ISOFOLDER\sources\boot.wim" 1 "Microsoft Windows PE (%arch%)" "Microsoft Windows PE (%arch%)" %_Nul3%
wimlib-imagex.exe info "ISOFOLDER\sources\boot.wim" 1 --image-property FLAGS=9 %_Nul3%
wimlib-imagex.exe export "!_DIR!\%uups_esd1%" 2 "ISOFOLDER\sources\boot.wim" "Microsoft Windows Setup (%_ss%)" "Microsoft Windows Setup (%_ss%)" --compress=LZX --boot
if %_build% lss 22000 wimlib-imagex.exe info "ISOFOLDER\sources\boot.wim" 2 "Microsoft Windows Setup (%arch%)" "Microsoft Windows Setup (%arch%)" %_Nul3%
wimlib-imagex.exe info "ISOFOLDER\sources\boot.wim" 2 --image-property FLAGS=2 --boot %_Nul3%
for /f "tokens=3 delims=: " %%# in ('wimlib-imagex.exe info "ISOFOLDER\sources\boot.wim" ^| findstr /c:"Image Count"') do set imgcount=%%#
if exist "%_mount%\" rmdir /s /q "%_mount%\" %_Nul3%
if not exist "%_mount%\" mkdir "%_mount%" %_Nul3%
set "_inx=1"&call :DoMount "ISOFOLDER\sources\boot.wim"
call :BootRemove
%_Dism% /LogPath:"%_dLog%\DismBoot.log" /Image:"%_mount%" /Set-TargetPath:X:\$Windows.~bt\ %_Nul3%
del /f /q %_mount%\Windows\system32\winpeshl.ini %_Nul3%
call :Cleanup
call :DoWork
call :DoUnmount
set "_inx=2"&call :DoMount "ISOFOLDER\sources\boot.wim"
call :BootRemove
if exist "!_DIR!\WinPE-Setup\*WinPE-Setup*.cab" (call :BootCabsAdd) else (call :BootFileAdd)
del /f /q %_mount%\Windows\system32\winpeshl.ini %_Nul3%
copy ISOFOLDER\sources\lang.ini %_mount%\sources\lang.ini %_Nul3%
call :Cleanup
call :DoWork
call :DoUnmount
if exist "%_mount%\" rmdir /s /q "%_mount%\" %_Nul3%
goto :BootDone

:BootDone
for /f "tokens=3 delims=: " %%# in ('wimlib-imagex.exe info "ISOFOLDER\sources\boot.wim" ^| findstr /c:"Image Count"') do set imgs=%%#
for /l %%# in (1,1,%imgs%) do (
  for /f "tokens=3 delims=<>" %%A in ('imagex.exe /info "ISOFOLDER\sources\boot.wim" %%# ^| find /i "<HIGHPART>"') do call set "HIGHPART%%#=%%A"
  for /f "tokens=3 delims=<>" %%A in ('imagex.exe /info "ISOFOLDER\sources\boot.wim" %%# ^| find /i "<LOWPART>"') do call set "LOWPART%%#=%%A"
  wimlib-imagex.exe info "ISOFOLDER\sources\boot.wim" %%# --image-property CREATIONTIME/HIGHPART=!HIGHPART%%#! --image-property CREATIONTIME/LOWPART=!LOWPART%%#! %_Nul1%
)
echo.
wimlib-imagex.exe optimize "ISOFOLDER\sources\boot.wim"
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
if not exist "%_mount%\Windows\Globalization\Sorting\SortDefault.nls" (
  wimlib-imagex.exe extract "!_DIR!\%uups_esd1%" 2 Windows\Globalization\Sorting --dest-dir="%_mount%\Windows\Globalization" %_Nul3%
  wimlib-imagex.exe extract "!_DIR!\%uups_esd1%" 2 Windows\WinSxS\FileMaps\$$_globalization_sorting_04883de290c6ef1b.cdf-ms --dest-dir="%_mount%\Windows\WinSxS\FileMaps" %_Nul3%
)
goto :eof

:BootCabsAdd
set "cabadd="
for /f "delims=" %%# in ('dir /b /a:-d "!_DIR!\WinPE-Setup\*WinPE-Setup.cab"') do set "cabadd=!cabadd! /PackagePath:!_DIR!\WinPE-Setup\%%#"
for /f "delims=" %%# in ('dir /b /a:-d "!_DIR!\WinPE-Setup\*WinPE-Setup_*.cab"') do set "cabadd=!cabadd! /PackagePath:!_DIR!\WinPE-Setup\%%#"
for /f "delims=" %%# in ('dir /b /a:-d "!_DIR!\WinPE-Setup\*WinPE-Setup-*.cab"') do set "cabadd=!cabadd! /PackagePath:!_DIR!\WinPE-Setup\%%#"
%_Dism% /LogPath:"%_dLog%\DismBoot.log" /Image:"%_mount%" /Add-Package !cabadd!
goto :eof

:BootFileAdd
wimlib-imagex.exe extract "!_DIR!\%uups_esd1%" 3 Windows\system32\xmllite.dll --dest-dir=ISOFOLDER\sources --no-acls --no-attributes %_Nul3%
copy /y ISOFOLDER\setup.exe %_mount%\setup.exe %_Nul3%
copy /y ISOFOLDER\sources\inf\setup.cfg %_mount%\sources\inf\setup.cfg %_Nul3%
set "_bkimg="
wimlib-imagex.exe extract "ISOFOLDER\sources\boot.wim" 1 Windows\System32\winpe.jpg --dest-dir=ISOFOLDER\sources --no-acls --no-attributes --nullglob %_Nul3%
for %%# in (background_cli.bmp, background_svr.bmp, background_cli.png, background_svr.png) do if exist "ISOFOLDER\sources\%%#" set "_bkimg=%%#"
for %%# in (background_cli.bmp, background_svr.bmp, background_cli.png, background_svr.png, winpe.jpg) do (if exist "ISOFOLDER\sources\%%#" if not defined _bkimg set "_bkimg=%%#")
if defined _bkimg (
  copy /y ISOFOLDER\sources\%_bkimg% %_mount%\sources\background.bmp %_Nul3%
  copy /y ISOFOLDER\sources\%_bkimg% %_mount%\Windows\system32\setup.bmp %_Nul3%
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
call :dk_color1 %Gray% "正在检查镜像信息..." 4
set PREPARED=1
imagex.exe /info %wimindex% >temp\info.txt 2>&1
for /f "tokens=3 delims=<>" %%# in ('find /i "<DEFAULT>" temp\info.txt') do set "langid=%%#"
for /f "tokens=3 delims=<>" %%# in ('find /i "<ARCH>" temp\info.txt') do (if %%# equ 0 (set "arch=x86") else if %%# equ 9 (set "arch=x64") else (set "arch=arm64"))
for /f "tokens=3 delims=<>" %%# in ('find /i "<BUILD>" temp\info.txt') do set _build=%%#
if %_build% geq 21382 if %_build% lss 26052 if exist "!_DIR!\*.AggregatedMetadata*.cab" (
  if exist "!_DIR!\*Windows1*-KB*.cab" if exist "!_DIR!\*Windows1*-KB*.psf" set _reMSU=1
  if exist "!_DIR!\*Windows1*-KB*.wim" if exist "!_DIR!\*Windows1*-KB*.psf" set _reMSU=1
)
if %_build% geq 22621 if exist "!_DIR!\*Edge*.wim" (
  set _wimEdge=1
  if not exist "!_DIR!\Edge.wim" for /f %%# in ('dir /b /a:-d "!_DIR!\*Edge*.wim"') do rename "!_DIR!\%%#" Edge.wim %_Nul3%
)
set _dpx=0
if %_build% geq 22000 if exist "%SysPath%\ucrtbase.dll" if exist "!_DIR!\*DesktopDeployment*.cab" (
  if /i %arch%==%xOS% set _dpx=1
  if /i %arch%==x64 if /i %xOS%==amd64 set _dpx=1
)
if %_dpx% equ 1 (
  for /f "delims=" %%# in ('dir /b /a:-d "!_DIR!\*DesktopDeployment*.cab"') do expand.exe -f:dpx.dll "!_DIR!\%%#" temp %_Nul3%
  copy /y %SysPath%\expand.exe temp\ %_Nul3%
)
if not exist "ISOFOLDER\sources\setuphost.exe" (
  wimlib-imagex.exe extract "!_DIR!\%uups_esd1%" 1 sources\setuphost.exe --dest-dir=temp --no-acls --no-attributes %_Nul3%
  7z.exe l temp\setuphost.exe >temp\version.txt 2>&1
)
if exist "ISOFOLDER\sources\setuphost.exe" 7z.exe l ISOFOLDER\sources\setuphost.exe >temp\version.txt 2>&1
if %_build% geq 22478 (
  wimlib-imagex.exe extract %wimindex% Windows\System32\UpdateAgent.dll --dest-dir=temp --no-acls --no-attributes --ref="!_DIR!\*.esd" %_Nul3%
  if exist "temp\UpdateAgent.dll" 7z.exe l temp\UpdateAgent.dll >temp\version.txt 2>&1
)
for /f "tokens=4-7 delims=.() " %%i in ('"findstr /i /b "FileVersion" temp\version.txt" %_Nul6%') do (set verver=%%i.%%j&set vermaj=%%i&set vermin=%%j)
set revver=%verver%&set revmaj=%vermaj%&set revmin=%vermin%
set "tok=6,7"&set "toe=5,6,7"
if /i %arch%==x86 (set _ss=x86) else if /i %arch%==x64 (set _ss=amd64) else (set _ss=arm64)
wimlib-imagex.exe extract %wimindex% Windows\WinSxS\Manifests\%_ss%_microsoft-windows-coreos-revision*.manifest --dest-dir=temp --no-acls --no-attributes --ref="!_DIR!\*.esd" %_Nul3%
if exist "temp\*_microsoft-windows-coreos-revision*.manifest" for /f "tokens=%tok% delims=_." %%i in ('dir /b /a:-d /od temp\*_microsoft-windows-coreos-revision*.manifest') do (set revver=%%i.%%j&set revmaj=%%i&set revmin=%%j)
if %_build% geq 15063 (
  wimlib-imagex.exe extract %wimindex% Windows\System32\config\SOFTWARE --dest-dir=temp --no-acls --no-attributes %_Nul3%
  set "isokey=Microsoft\Windows NT\CurrentVersion\Update\TargetingInfo\Installed"
  for /f %%i in ('"offlinereg.exe temp\SOFTWARE "!isokey!" enumkeys %_Nul6% ^| findstr /i /r "Client\.OS Server\.OS""') do if not errorlevel 1 (
    for /f "tokens=5,6 delims==:." %%A in ('"offlinereg.exe temp\SOFTWARE "!isokey!\%%i" getvalue Version %_Nul6%"') do if %%A gtr !revmaj! (
      set "revver=%%~A.%%B
      set revmaj=%%~A
      set "revmin=%%B
    )
  )
)
if %vermin% lss %revmin% set verver=%revver%
if %vermaj% lss %revmaj% set verver=%revver%
set _label=%verver%
set _bit=%arch%
if /i %arch%==arm64 set _bit=arm
set c_ver=0
set c_num=0
set s_pkg=
set ssvr_aa=0
set ssvr_bl=0
set ssvr_mj=0
set ssvr_mn=0
set savc=0&set savr=1&set rbvr=0
if %_build% geq 18362 (set savc=3&set savr=3)
if %_build% geq 25380 (set rbvr=1)
call :setlabel
exit /b

:setlabel
set DVDISO=%_label%.%arch%
if %_LTSC% equ 1 set DVDISO=%_label%.%arch%.LTSC
if %_Srvr% equ 1 set DVDISO=%_label%.%arch%.Server
for %%# in (A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z) do set langid=!langid:%%#=%%#!
if /i %arch%==x86 set archl=X86
if /i %arch%==x64 set archl=X64
if /i %arch%==arm64 set archl=A64
set DVDLABEL=CCSA_%archl%FRE_%langid%_DV9
if %_LTSC% equ 1 set DVDLABEL=CES_%archl%FRE_%langid%_DV9
if %_Srvr% equ 1 set DVDLABEL=SSS_%archl%FRE_%langid%_DV9
if not exist "ISOFOLDER\sources\install.wim" exit /b
set images=0
for /f "tokens=3 delims=: " %%# in ('wimlib-imagex.exe info "ISOFOLDER\sources\install.wim" ^| findstr /c:"Image Count"') do set images=%%#
if %images% geq 4 if %_Srvr% equ 1 (set DVDLABEL=SSS_%archl%FRE_%langid%_DV9&exit /b) else (set DVDLABEL=CCCOMA_%archl%FRE_%langid%_DV9&exit /b)
if %images% equ 1 call :isosingle
exit /b

:isosingle
for /f "tokens=3 delims=<>" %%# in ('imagex.exe /info "ISOFOLDER\sources\install.wim" 1 ^| find /i "<EDITIONID>"') do set "editionid=%%#"
if %_Srvr% equ 1 imagex.exe /info "ISOFOLDER\sources\install.wim" 1 | findstr /i /c:"Server Core" %_Nul3% && (
  if /i "%editionid%"=="ServerStandard" set "editionid=ServerStandardCore"
  if /i "%editionid%"=="ServerDatacenter" set "editionid=ServerDatacenterCore"
  if /i "%editionid%"=="ServerTurbine" set "editionid=ServerTurbineCore"
)
if /i %editionid%==Core set DVDLABEL=CCRA_%archl%FRE_%langid%_DV9&set DVDISO=%_label%.%arch%.Home&exit /b
if /i %editionid%==CoreN set DVDLABEL=CCRNA_%archl%FRE_%langid%_DV9&set DVDISO=%_label%.%arch%.HomeN&exit /b
if /i %editionid%==CoreSingleLanguage set DVDLABEL=CSLA_%archl%FREO_%langid%_DV9&set DVDISO=%_label%.%arch%.HomeSingle&exit /b
if /i %editionid%==CoreCountrySpecific set DVDLABEL=CCHA_%archl%FREO_%langid%_DV9&set DVDISO=%_label%.%arch%.HomeChina&exit /b
if /i %editionid%==Professional set DVDLABEL=CPRA_%archl%FRE_%langid%_DV9&set DVDISO=%_label%.%arch%.Pro&exit /b
if /i %editionid%==ProfessionalN set DVDLABEL=CPRNA_%archl%FRE_%langid%_DV9&set DVDISO=%_label%.%arch%.ProN&exit /b
if /i %editionid%==Education set DVDLABEL=CEDA_%archl%FRE_%langid%_DV9&set DVDISO=%_label%.%arch%.Edu&exit /b
if /i %editionid%==EducationN set DVDLABEL=CEDNA_%archl%FRE_%langid%_DV9&set DVDISO=%_label%.%arch%.EduN&exit /b
if /i %editionid%==Enterprise set DVDLABEL=CENA_%archl%FREV_%langid%_DV9&set DVDISO=%_label%.%arch%.Ent&exit /b
if /i %editionid%==EnterpriseN set DVDLABEL=CENNA_%archl%FREV_%langid%_DV9&set DVDISO=%_label%.%arch%.EntN&exit /b
if /i %editionid%==Cloud set DVDLABEL=CWCA_%archl%FREO_%langid%_DV9&set DVDISO=%_label%.%arch%.Cloud&exit /b
if /i %editionid%==CloudN set DVDLABEL=CWCNNA_%archl%FREO_%langid%_DV9&set DVDISO=%_label%.%arch%.CloudN&exit /b
if /i %editionid%==PPIPro set DVDLABEL=CPPIA_%archl%FREO_%langid%_DV9&set DVDISO=%_label%.%arch%.PPIPro&exit /b
if /i %editionid%==EnterpriseG set DVDLABEL=CENG_%archl%FREV_%langid%_DV9&set DVDISO=%_label%.%arch%.EntG&exit /b
if /i %editionid%==EnterpriseGN set DVDLABEL=CENGN_%archl%FREV_%langid%_DV9&set DVDISO=%_label%.%arch%.EntGN&exit /b
if /i %editionid%==EnterpriseS set DVDLABEL=CES_%archl%FREV_%langid%_DV9&set DVDISO=%_label%.%arch%.EntS&exit /b
if /i %editionid%==EnterpriseSN set DVDLABEL=CESNN_%archl%FREV_%langid%_DV9&set DVDISO=%_label%.%arch%.EntSN&exit /b
if /i %editionid%==ProfessionalEducation set DVDLABEL=CPREA_%archl%FRE_%langid%_DV9&set DVDISO=%_label%.%arch%.ProEdu&exit /b
if /i %editionid%==ProfessionalEducationN set DVDLABEL=CPRENA_%archl%FRE_%langid%_DV9&set DVDISO=%_label%.%arch%.ProEduN&exit /b
if /i %editionid%==ProfessionalWorkstation set DVDLABEL=CPRWA_%archl%FRE_%langid%_DV9&set DVDISO=%_label%.%arch%.ProWork&exit /b
if /i %editionid%==ProfessionalWorkstationN set DVDLABEL=CPRWNA_%archl%FRE_%langid%_DV9&set DVDISO=%_label%.%arch%.ProWorkN&exit /b
if /i %editionid%==ProfessionalSingleLanguage set DVDLABEL=CPRSLA_%archl%FREO_%langid%_DV9&set DVDISO=%_label%.%arch%.ProSingle&exit /b
if /i %editionid%==ProfessionalCountrySpecific set DVDLABEL=CPRCHA_%archl%FREO_%langid%_DV9&set DVDISO=%_label%.%arch%.ProChina&exit /b
if /i %editionid%==CloudEdition set DVDLABEL=CWCA_%archl%FRE_%langid%_DV9&set DVDISO=%_label%.%arch%.Cloud&exit /b
if /i %editionid%==CloudEditionN set DVDLABEL=CWCNNA_%archl%FRE_%langid%_DV9&set DVDISO=%_label%.%arch%.CloudN&exit /b
if /i %editionid%==ServerStandard set DVDLABEL=SSS_%archl%FRE_%langid%_DV9&set DVDISO=%_label%.%arch%.ServerStandard&exit /b
if /i %editionid%==ServerStandardCore set DVDLABEL=SSS_%archl%FRE_%langid%_DV9&set DVDISO=%_label%.%arch%.ServerStandardCore&exit /b
if /i %editionid%==ServerDatacenter set DVDLABEL=SSS_%archl%FRE_%langid%_DV9&set DVDISO=%_label%.%arch%.ServerDatacenter&exit /b
if /i %editionid%==ServerDatacenterCore set DVDLABEL=SSS_%archl%FRE_%langid%_DV9&set DVDISO=%_label%.%arch%.ServerDatacenterCore&exit /b
if /i %editionid%==ServerTurbine set DVDLABEL=SADC_%archl%FRE_%langid%_DV9&set DVDISO=%_label%.%arch%.ServerTurbine&exit /b
if /i %editionid%==ServerTurbineCore set DVDLABEL=SADC_%archl%FRE_%langid%_DV9&set DVDISO=%_label%.%arch%.ServerTurbineCore&exit /b
if /i %editionid%==ServerAzureStackHCICor set DVDLABEL=SASH_%archl%FRE_%langid%_DV9&set DVDISO=%_label%.%arch%.ServerAzure&exit /b
exit /b

:uups_ref
if not exist "!_DIR!\*Package*.esd" exit /b
if not exist "!_DIR!\*Package*.cab" exit /b
call :dk_color1 %Gray% "正在将 .cab 转换为 .esd 文件..." 4 5
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
exit /b

:uups_dir
set cbsp=%~1
if exist "temp\%cbsp%.esd" exit /b
echo %cbsp% | findstr /i /r "Windows.*-KB SSU-.* RCU-.* RetailDemo Holographic-Desktop-FOD" %_Nul1% && exit /b
if /i "%cbsp%"=="Metadata" exit /b
echo 转换为 ESD 文件：%cbsp%.cab
rmdir /s /q "!_DIR!\%~1\$dpx$.tmp\" %_Nul3%
wimlib-imagex.exe capture "!_DIR!\%~1" "temp\%cbsp%.esd" --compress=%_level% --check --no-acls --norpfix "Edition Package" "Edition Package" %_Nul3%
exit /b

:uups_cab
set cbsp=%~n1
if exist "temp\%cbsp%.esd" exit /b
echo %cbsp% | findstr /i /r "Windows.*-KB SSU-.* RCU-.* RetailDemo Holographic-Desktop-FOD" %_Nul1% && exit /b
echo %cbsp%
set /a _ref+=1
set /a _rnd=%random%
set _dst=temp\_tmp%_ref%
if exist "%_dst%" (set _dst=temp\_tmp%_rnd%)
mkdir %_dst% %_Nul3%
expand.exe -f:* "!_DIR!\%cbsp%.cab" %_dst%\ %_Nul3%
wimlib-imagex.exe capture "%_dst%" "temp\%cbsp%.esd" --compress=%_level% --check --no-acls --norpfix "Edition Package" "Edition Package" %_Nul3%
rmdir /s /q %_dst%\ %_Nul3%
if exist "%_dst%\" (
  mkdir temp\_del %_Nul3%
  robocopy temp\_del %_dst% /MIR /R:1 /W:1 /NFL /NDL /NP /NJH /NJS %_Nul3%
  rmdir /s /q temp\_del\ %_Nul3%
  rmdir /s /q %_dst%\ %_Nul3%
)
exit /b

:uups_backup
if not exist "!_work!\temp\*.esd" exit /b
call :dk_color1 %Gray% "正在备份 .esd 文件..." 4 5
if %EXPRESS% equ 1 (
mkdir "!_work!\CanonicalUUP" %_Nul3%
move /y "!_work!\temp\*.esd" "!_work!\CanonicalUUP\" %_Nul3%
for /l %%# in (1,1,%uups_esd_num%) do copy /y "!_DIR!\!uups_esd%%#!" "!_work!\CanonicalUUP\" %_Nul3%
for /f %%# in ('dir /b /a:-d "!_DIR!\*Package*.esd" %_Nul6%') do if not exist "!_work!\CanonicalUUP\%%#" (copy /y "!_DIR!\%%#" "!_work!\CanonicalUUP\" %_Nul3%)
exit /b
)
mkdir "!_DIR!\Original" %_Nul3%
move /y "!_work!\temp\*.esd" "!_DIR!\" %_Nul3%
for /f %%# in ('dir /b /a:-d "!_DIR!\*.cab"') do (
echo %%#| findstr /i /r "Windows.*-KB SSU-.* RCU-.* DesktopDeployment AggregatedMetadata defender-dism" %_Nul1% || move /y "!_DIR!\%%#" "!_DIR!\Original\" %_Nul3%
)
exit /b

:mediacheck
set _ESDSrv%1=0
if exist temp\uups_esd.txt for /f "tokens=2 delims=]" %%# in ('find /v /n "" temp\uups_esd.txt ^| find "[%1]"') do set uups_esd=%%#
set "uups_esd%1=%uups_esd%"
set "wimshow=%uups_esd%" & set "wimindex="!_DIR!\%uups_esd%" 3"
wimlib-imagex.exe info %wimindex% %_Nul3%
set ERRTEMP=%ERRORLEVEL%
if %ERRTEMP% equ 73 (
  %_err%
  call :dk_color1 %Red% "%wimshow% 文件已损坏"
  set eWIMLIB=1
  exit /b
)
if %ERRTEMP% neq 0 (
  %_err%
  call :dk_color1 %Red% "无法解析来自文件 %wimshow% 的信息"
  set eWIMLIB=1
  exit /b
)
imagex.exe /info %wimindex% >temp\info.txt 2>&1
for /f "tokens=3 delims=<>" %%# in ('find /i "<DEFAULT>" temp\info.txt') do set "langid%1=%%#"
for /f "tokens=3 delims=<>" %%# in ('find /i "<EDITIONID>" temp\info.txt') do set "edition%1=%%#"
for /f "tokens=3 delims=<>" %%# in ('find /i "<ARCH>" temp\info.txt') do (if %%# equ 0 (set "arch%1=x86") else if %%# equ 9 (set "arch%1=x64") else (set "arch%1=arm64"))
for /f "tokens=3 delims=<>" %%# in ('find /i "<BUILD>" temp\info.txt') do set _obuild%1=%%#
set "_wtx=Windows 10"
find /i "<NAME>" temp\info.txt %_Nul2% | find /i "Windows 11" %_Nul3% && (set "_wtx=Windows 11")
find /i "<NAME>" temp\info.txt %_Nul2% | find /i "Windows 12" %_Nul3% && (set "_wtx=Windows 12")
echo !edition%1! | findstr /i /b "EnterpriseS" %_Nul3% && (set _LTSC=1)
echo !edition%1! | findstr /i /b "Server" %_Nul3% && (set _Srvr=1&set _ESDSrv%1=1)
set "_wsr=Windows Server 2022"
if !_ESDSrv%1! equ 1 (
  find /i "<NAME>" temp\info.txt %_Nul2% | find /i " 2025" %_Nul3% && (set "_wsr=Windows Server 2025")
  if !_obuild%1! geq 26010 (set "_wsr=Windows Server 2025")
)
if !_ESDSrv%1! equ 1 findstr /i /c:"Server Core" temp\info.txt %_Nul3% && (
if /i "!edition%1!"=="ServerStandard" set "edition%1=ServerStandardCore"
if /i "!edition%1!"=="ServerDatacenter" set "edition%1=ServerDatacenterCore"
if /i "!edition%1!"=="ServerTurbine" set "edition%1=ServerTurbineCore"
)
exit /b
:SBSConfig
if exist "temp\Reg-*.*" del /f /q "temp\Reg-*.*" %_Nul3%
call :RegLoad
if %1 neq 9 if %_build% geq 26052 reg.exe delete "HKLM\%SOFTWARE%\Microsoft\Windows\CurrentVersion\SideBySide" /v DecompressOverride /f %_Nul3%
if %1 neq 9 reg.exe add "HKLM\%SOFTWARE%\%_SxsCfg%" /v SupersededActions /t REG_DWORD /d %1 /f %_Nul3%
if %2 neq 9 reg.exe add "HKLM\%SOFTWARE%\%_SxsCfg%" /v DisableResetbase /t REG_DWORD /d %2 /f %_Nul3%
if %3 neq 9 reg.exe add "HKLM\%SOFTWARE%\%_SxsCfg%" /v DisableComponentBackups /t REG_DWORD /d %3 /f %_Nul3%
call :RggUnload
goto :eof

:RegLoad
reg.exe load HKLM\%SOFTWARE% "%_mount%\Windows\System32\Config\SOFTWARE" %_Nul1%
goto :eof

:RggUnload
if exist "%_mount%\Windows\Servicing\Packages\*WinPE-LanguagePack*.mum" (
  reg.exe unload HKLM\%SOFTWARE% %_Nul1%
  goto :eof
)
if /i %xOS%==x86 if /i not %arch%==x86 reg.exe save HKLM\%SOFTWARE% "%_mount%\Windows\System32\Config\SOFTWARE2" /y %_Nul1%
reg.exe unload HKLM\%SOFTWARE% %_Nul1%
if /i %xOS%==x86 if /i not %arch%==x86 move /y "%_mount%\Windows\System32\Config\SOFTWARE2" "%_mount%\Windows\System32\Config\SOFTWARE" %_Nul1%
goto :eof

:update
if %W10UI% equ 0 exit /b
set directcab=0
set _target=%~1
for /f "tokens=3 delims=: " %%# in ('wimlib-imagex.exe info "%_target%" ^| findstr /c:"Image Count"') do set imgcount=%%#
if not exist "%SystemRoot%\temp\" mkdir "%SystemRoot%\temp" %_Nul3%
if exist "%_mount%\" rmdir /s /q "%_mount%\" %_Nul3%
if not exist "%_mount%\" mkdir "%_mount%" %_Nul3%
for %%# in (handle1,handle2) do set %%#=0
for %%# in (iCore,iCorN,iProf,iProN,iEntS,iEnSN,iTeam,iSSC,iSSD,iSDC,iSDD) do set "%%#="
for /L %%# in (1,1,%imgcount%) do (
  if not defined iCore (imagex /info "%_target%" %%# | findstr /i "Core</EDITIONID>"%_Nul3% && set iCore=%%#)
  if not defined iCorN (imagex /info "%_target%" %%# | findstr /i "CoreN</EDITIONID>"%_Nul3% && set iCorN=%%#)
  if not defined iProf (imagex /info "%_target%" %%# | findstr /i "Professional</EDITIONID>"%_Nul3% && set iProf=%%#)
  if not defined iProN (imagex /info "%_target%" %%# | findstr /i "ProfessionalN</EDITIONID>"%_Nul3% && set iProN=%%#)
  if not defined iEntS (imagex /info "%_target%" %%# | findstr /i "EnterpriseS</EDITIONID>" %_Nul3% && set iEntS=%%#)
  if not defined iEnSN (imagex /info "%_target%" %%# | findstr /i "EnterpriseSN</EDITIONID>" %_Nul3% && set iEnSN=%%#)
  if not defined iTeam (imagex /info "%_target%" %%# | findstr /i "PPIPro</EDITIONID>"%_Nul3% && set iTeam=%%#)
  if not defined iSSC (imagex /info "%_target%" %%# | findstr /i "ServerStandard</EDITIONID>"%_Nul3% && (imagex /info "%_target%" %%# | findstr /i /c:"Server Core" %_Nul3% && set iSSC=%%#))
  if not defined iSSD (imagex /info "%_target%" %%# | findstr /i "ServerStandard</EDITIONID>"%_Nul3% && (imagex /info "%_target%" %%# | findstr /i /c:"Server Core" %_Nul3% || set iSSD=%%#))
  if not defined iSDC (imagex /info "%_target%" %%# | findstr /i "ServerDatacenter</EDITIONID>"%_Nul3% && (imagex /info "%_target%" %%# | findstr /i /c:"Server Core" %_Nul3% && set iSDC=%%#))
  if not defined iSDD (imagex /info "%_target%" %%# | findstr /i "ServerDatacenter</EDITIONID>"%_Nul3% && (imagex /info "%_target%" %%# | findstr /i /c:"Server Core" %_Nul3% || set iSDD=%%#))
)
for /l %%# in (1,1,%imgcount%) do set "_inx=%%#"&call :DoMount "%_target%"&call :DoWork&call :DoUnmount
if exist "%_mount%\" rmdir /s /q "%_mount%\" %_Nul3%
if %_build% geq 19041 if %winbuild% lss 17133 if exist "%SysPath%\ext-ms-win-security-slc-l1-1-0.dll" (
  del /f /q %SysPath%\ext-ms-win-security-slc-l1-1-0.dll %_Nul3%
  if /i not %xOS%==x86 del /f /q %SystemRoot%\SysWOW64\ext-ms-win-security-slc-l1-1-0.dll %_Nul3%
)
echo %_target% | findstr "install" %_Nul3% || exit /b
if %vermin% lss %revmin% set verver=%revver%
if %vermaj% lss %revmaj% set verver=%revver%
set _label=%verver%
call :setlabel
exit /b

:DoMount
set _www=%~1
set _nnn=%~nx1
call :dk_color1 %Blue% "=== 正在更新 %_nnn% [%_inx%/%imgcount%]" 4
call :WimDate
%_Dism% /LogPath:"%_dLog%\DismMount.log" /Mount-Wim /Wimfile:"%_www%" /Index:%_inx% /MountDir:"%_mount%"
set ERRTEMP=%ERRORLEVEL%
if %ERRTEMP% neq 0 call :Discard
goto :eof

:WimDate
set "HIGHPART%_inx%=" & set "LOWPART%_inx%="
for /f "tokens=3 delims=<>" %%A in ('imagex.exe /info %_www% %_inx% ^| find /i "<HIGHPART>"') do if not defined HIGHPART%_inx% call set "HIGHPART%_inx%=%%A"
for /f "tokens=3 delims=<>" %%A in ('imagex.exe /info %_www% %_inx% ^| find /i "<LOWPART>"') do if not defined LOWPART%_inx% call set "LOWPART%_inx%=%%A"
%_Nul3% %_psc% "Set-Date $([DateTime]::FromFileTime([Convert]::ToInt64('!HIGHPART%_inx%!'.Substring(2, 8) + '!LOWPART%_inx%!'.Substring(2, 8),16)))"
goto :eof

:DoCommit
set "_apd="
if "%~1"=="Append" set "_apd=/Append"
if %Cleanup% equ 1 call :CleanReg
%_Dism% /LogPath:"%_dLog%\DismCommit.log" /Commit-Image /MountDir:"%_mount%" %_apd%
goto :eof

:DoUnmount
%_Dism% /LogPath:"%_dLog%\DismUnMount.log" /Unmount-Wim /MountDir:"%_mount%" /Discard
set ERRTEMP=%ERRORLEVEL%
if %ERRTEMP% neq 0 call :Discard
goto :eof

:Discard
%_Dism% /LogPath:"%_dLog%\DismNUL.log" /Image:"%_mount%" /Get-Packages %_Nul3%
%_Dism% /LogPath:"%_dLog%\DismUnMount.log" /Unmount-Wim /MountDir:"%_mount%" /Discard
%_Dism% /LogPath:"%_dLog%\DismNUL.log" /Cleanup-Mountpoints %_Nul3%
%_Dism% /LogPath:"%_dLog%\DismNUL.log" /Cleanup-Wim %_Nul3%
if exist "%_mount%\" rmdir /s /q "%_mount%\"
goto :eof

:DoWork
if not exist "%_mount%\Windows\Servicing\Packages\*WinPE-LanguagePack*.mum" if %_wimEdge% equ 1 call :AddEdge
if %Cleanup% equ 1 call :Cleanup
if exist "%_mount%\Windows\Servicing\Packages\*WinPE-LanguagePack*.mum" goto :DoCommit
if !handle2! equ 1 goto :Skiphand2
set handle2=1
set vermin=0
for /f "tokens=%tok% delims=_." %%i in ('dir /b /a:-d /od "%_mount%\Windows\WinSxS\Manifests\%_ss%_microsoft-windows-coreos-revision*.manifest"') do (set verver=%%i.%%j&set vermaj=%%i&set vermin=%%j)
set "isokey=Microsoft\Windows NT\CurrentVersion\Update\TargetingInfo\Installed"
for /f %%i in ('"offlinereg.exe "%_mount%\Windows\System32\config\SOFTWARE" "!isokey!" enumkeys %_Nul6% ^| findstr /i /r "Client\.OS Server\.OS""') do if not errorlevel 1 (
  for /f "tokens=5,6 delims==:." %%A in ('"offlinereg.exe "%_mount%\Windows\System32\config\SOFTWARE" "!isokey!\%%i" getvalue Version %_Nul6%"') do if %%A gtr !vermaj! (
    set "revver=%%~A.%%B
    set revmaj=%%~A
    set "revmin=%%B
  )
)
:Skiphand2
if exist "%_mount%\inetpub" attrib +h "%_mount%\inetpub" %_Nul3%
call :DoCommit
if %UpgradeEdition% neq 1 goto :eof
call :dk_color1 %Blue% "=== 正在转换 Windows 版本..." 4
if defined iCore if %_inx%==%iCore% for %%i in (CoreSingleLanguage) do ( set nedition=%%i & call :setedition)
if defined iProf if %_inx%==%iProf% for %%i in (Education, ProfessionalEducation, ProfessionalWorkstation) do ( set nedition=%%i & call :setedition)
if defined iProN if %_inx%==%iProN% for %%i in (EducationN, ProfessionalEducationN, ProfessionalWorkstationN) do ( set nedition=%%i & call :setedition)
if defined iEntS if %_inx%==%iEntS% for %%i in (IoTEnterpriseS, IoTEnterpriseSK) do ( set nedition=%%i & call :setedition)
goto :eof

:AddEdge
if exist "%_mount%\Program Files (x86)\Microsoft\Edge" goto :eof
call :dk_color1 %Blue% "=== 正在添加 Microsoft Edge..." 4
%_Dism% /LogPath:"%_dLog%\DismEdge.log" /Image:"%_mount%" /Add-Edge /SupportPath:"!_DIR!"
if !errorlevel! neq 0 call :dk_color1 %Red% "添加 Edge.wim 失败" 4
goto :eof

:setedition
call :setname
call :dk_color1 %_Green% "正在处理 !_nameb!" 4
if exist "%_mount%\Windows\*.xml" del /f /q "%_mount%\Windows\*.xml" %_Nul3%
set "channel="
for %%# in (
  "CloudEdition:Retail"
  "CloudEditionN:Retail"
  "Core:Retail"
  "CoreN:Retail"
  "CoreSingleLanguage:Retail"
  "Professional:Retail"
  "ProfessionalN:Retail"
  "ProfessionalEducation:Retail"
  "ProfessionalEducationN:Retail"
  "ProfessionalWorkstation:Retail"
  "ProfessionalWorkstationN:Retail"
  "Education:Retail"
  "EducationN:Retail"
  "Enterprise:Volume"
  "EnterpriseN:Volume"
  "EnterpriseS:Volume"
  "EnterpriseSN:Volume"
  "IoTEnterprise:OEM"
  "IoTEnterpriseK:OEM"
  "IoTEnterpriseS:OEM"
  "IoTEnterpriseSK:OEM"
  "ServerRdsh:Volume"
) do for /f "tokens=1,2 delims=:" %%A in ("%%~#") do (
  if /i %nedition%==%%A set "channel=%%B"
)
set "_chn=/Channel:%channel%"
if /i "%channel%"=="OEM" if %_build% neq 18362 set "_chn="
%_Dism% /LogPath:"%_dLog%\DismEdition.log" /Image:"%_mount%" /Set-Edition:%nedition% %_chn% %_Nul3%
call :DoCommit Append
for /f "tokens=3 delims=: " %%# in ('wimlib-imagex.exe info "%_www%" ^| findstr /c:"Image Count"') do set nimg=%%# %_Nul3%
wimlib-imagex.exe info "%_www%" %nimg% "!_namea!" "!_namea!" --image-property DISPLAYNAME="!_nameb!" --image-property DISPLAYDESCRIPTION="!_nameb!" --image-property FLAGS=%nedition% %_Nul3%
if %_Srvr% equ 1 wimlib-imagex.exe info "%_www%" %nimg% "!_namea!" "!_namea!" --image-property DISPLAYNAME="!_nameb!" --image-property DISPLAYDESCRIPTION="!_namec!" --image-property FLAGS=!edition%%#! %_Nul3%
goto :eof

:setname
for %%# in (
  "Cloud:%_wtx% S:%_wtx% S"
  "CloudN:%_wtx% S N:%_wtx% S N"
  "CloudE:%_wtx% Lean:%_wtx% Lean"
  "CloudEN:%_wtx% Lean N:%_wtx% Lean N"
  "CloudEdition:%_wtx% SE:%_wtx% SE"
  "CloudEditionN:%_wtx% SE N:%_wtx% SE N"
  "CloudEditionL:%_wtx% LE:%_wtx% LE"
  "CloudEditionLN:%_wtx% LE N:%_wtx% LE N"
  "Core:%_wtx% Home:%_wtx% 家庭版"
  "CoreN:%_wtx% Home N:%_wtx% 家庭版 N"
  "CoreSingleLanguage:%_wtx% Home Single Language:%_wtx% 家庭单语言版"
  "CoreCountrySpecific:%_wtx% Home China:%_wtx% 家庭中文版"
  "Professional:%_wtx% Pro:%_wtx% 专业版"
  "ProfessionalN:%_wtx% Pro N:%_wtx% 专业版 N"
  "ProfessionalEducation:%_wtx% Pro Education:%_wtx% 专业教育版"
  "ProfessionalEducationN:%_wtx% Pro Education N:%_wtx% 专业教育版 N"
  "ProfessionalWorkstation:%_wtx% Pro for Workstations:%_wtx% 专业工作站版"
  "ProfessionalWorkstationN:%_wtx% Pro N for Workstations:%_wtx% 专业工作站版 N"
  "ProfessionalSingleLanguage:%_wtx% Pro Single Language:%_wtx% 专业单语言版"
  "ProfessionalCountrySpecific:%_wtx% Pro China:%_wtx% 专业中文版"
  "PPIPro:%_wtx% Team:%_wtx% 协同版"
  "Education:%_wtx% Education:%_wtx% 教育版"
  "EducationN:%_wtx% Education N:%_wtx% 教育版 N"
  "Enterprise:%_wtx% Enterprise:%_wtx% 企业版"
  "EnterpriseN:%_wtx% Enterprise N:%_wtx% 企业版 N"
  "EnterpriseG:%_wtx% Enterprise G:%_wtx% 企业版 G"
  "EnterpriseGN:%_wtx% Enterprise G N:%_wtx% 企业版 G N"
  "EnterpriseS:%_wtx% Enterprise LTSC:%_wtx% 企业版 LTSC"
  "EnterpriseSN:%_wtx% Enterprise N LTSC:%_wtx% 企业版 N LTSC"
  "IoTEnterprise:%_wtx% IoT Enterprise:%_wtx% IoT 企业版"
  "IoTEnterpriseS:%_wtx% IoT Enterprise LTSC:%_wtx% IoT 企业版 LTSC"
  "IoTEnterpriseK:%_wtx% IoT Enterprise Subscription:%_wtx% IoT 企业版订阅"
  "IoTEnterpriseSK:%_wtx% IoT Enterprise LTSC Subscription:%_wtx% IoT 企业版订阅 LTSC"
  "ServerRdsh:%_wtx% Enterprise Multi-Session:%_wtx% 企业版多会话"
  "Starter:%_wtx% Starter:%_wtx% 入门版"
  "StarterN:%_wtx% Starter N:%_wtx% 入门版 N"
  "WNC:%_wtx% Cloud PC:%_wtx% Cloud PC"
  "ServerStandardCore:%_wsr% SERVERSTANDARDCORE:%_wsr% Standard:（推荐）此选项忽略大部分 Windows 图形环境。通过命令提示符和 PowerShell，或者远程使用 Windows Admin Center 或其他工具进行管理。"
  "ServerStandard:%_wsr% SERVERSTANDARD:%_wsr% Standard (桌面体验):此选项将安装的完整的 Windows 图形环境，占用额外的驱动器空间。如果你想要使用 Windows 桌面或需要桌面的应用，则它会很有用。"
  "ServerDatacenterCore:%_wsr% SERVERDATACENTERCORE:%_wsr% Datacenter:（推荐）此选项忽略大部分 Windows 图形环境。通过命令提示符和 PowerShell，或者远程使用 Windows Admin Center 或其他工具进行管理。"
  "ServerDatacenter:%_wsr% SERVERDATACENTER:%_wsr% Datacenter (桌面体验):此选项将安装的完整的 Windows 图形环境，占用额外的驱动器空间。如果你想要使用 Windows 桌面或需要桌面的应用，则它会很有用。"
  "ServerTurbineCore:%_wsr% SERVERTURBINECORE:%_wsr% Datacenter Azure Edition:（推荐）此选项忽略大部分 Windows 图形环境。通过命令提示符和 PowerShell，或者远程使用 Windows Admin Center 或其他工具进行管理。"
  "ServerTurbine:%_wsr% SERVERTURBINE:%_wsr% Datacenter Azure Edition (桌面体验):此选项将安装的完整的 Windows 图形环境，占用额外的驱动器空间。如果你想要使用 Windows 桌面或需要桌面的应用，则它会很有用。"
  "ServerAzureStackHCICor:Azure Stack HCI:此选项安装 Azure Stack HCI。"
) do for /f "tokens=1,2,3,4 delims=:" %%A in ("%%~#") do (
  if /i %nedition%==%%A set "_namea=%%B"&set "_nameb=%%C"&set "_namec=%%D"
)
goto :eof

:Cleanup
if exist "%_mount%\Windows\Servicing\Packages\*WinPE-LanguagePack*.mum" (
  call :SBSConfig %savr% 9 1
  %_Dism% /LogPath:"%_dLog%\DismClean_PE.log" /Image:"%_mount%" /Cleanup-Image /StartComponentCleanup
  if %Cleanup% neq 0 (
    if %ResetBase% neq 0 %_Dism% /LogPath:"%_dLog%\DismClean_PE.log" /Image:"%_mount%" /Cleanup-Image /StartComponentCleanup /ResetBase %_Nul3%
  )
  call :CleanManual&goto :eof
)
if %Cleanup% equ 0 call :CleanManual&goto :eof
if exist "%_mount%\Windows\WinSxS\pending.xml" call :CleanManual&goto :eof
set "_Nul8="
if %_build% geq 25380 if %_build% lss 26000 (
  set "_Nul8=1>nul 2>nul"
  call :dk_color1 %Gray% "正在运行 Dism 清理..." 4 5
)
if %ResetBase% equ 0 (
  call :SBSConfig %savc% 1 9
  %_Dism% /LogPath:"%_dLog%\DismClean.log" /Image:"%_mount%" /Cleanup-Image /StartComponentCleanup %_Nul8%
  goto :FinalClean
)
:ResetBase
call :SBSConfig %savr% %rbvr% 9
%_Dism% /LogPath:"%_dLog%\DismClean.log" /Image:"%_mount%" /Cleanup-Image /StartComponentCleanup
if %ResetBase% neq 0 %_Dism% /LogPath:"%_dLog%\DismClean.log" /Image:"%_mount%" /Cleanup-Image /StartComponentCleanup /ResetBase %_Nul3%
:FinalClean
call :CleanManual&goto :eof

:CleanManual
if exist "%_mount%\Windows\WinSxS\ManifestCache\*.bin" (
  takeown /f "%_mount%\Windows\WinSxS\ManifestCache\*.bin" /A %_Nul3%
  icacls "%_mount%\Windows\WinSxS\ManifestCache\*.bin" /grant *S-1-5-32-544:F %_Nul3%
  del /f /q "%_mount%\Windows\WinSxS\ManifestCache\*.bin" %_Nul3%
)
if exist "%_mount%\Windows\WinSxS\Temp\PendingDeletes\*" (
  takeown /f "%_mount%\Windows\WinSxS\Temp\PendingDeletes\*" /A %_Nul3%
  icacls "%_mount%\Windows\WinSxS\Temp\PendingDeletes\*" /grant *S-1-5-32-544:F %_Nul3%
  del /f /q "%_mount%\Windows\WinSxS\Temp\PendingDeletes\*" %_Nul3%
)
if exist "%_mount%\Windows\WinSxS\Temp\TransformerRollbackData\*" (
  takeown /f "%_mount%\Windows\WinSxS\Temp\TransformerRollbackData\*" /R /A %_Nul3%
  icacls "%_mount%\Windows\WinSxS\Temp\TransformerRollbackData\*" /grant *S-1-5-32-544:F /T %_Nul3%
  del /s /f /q "%_mount%\Windows\WinSxS\Temp\TransformerRollbackData\*" %_Nul3%
)
if exist "%_mount%\Windows\WinSxS\Backup\*" (
  takeown /f "%_mount%\Windows\WinSxS\Backup\*" /A %_Nul3%
  icacls "%_mount%\Windows\WinSxS\Backup\*" /grant *S-1-5-32-544:F %_Nul3%
  del /s /f /q "%_mount%\Windows\WinSxS\Backup\*" %_Nul3%
)
if exist "%_mount%\Windows\inf\*.log" (
  del /f /q "%_mount%\Windows\inf\*.log" %_Nul3%
)
if exist "%_mount%\Windows\DtcInstall.log" (
  del /f /q "%_mount%\Windows\DtcInstall.log" %_Nul3%
)
for /f "tokens=* delims=" %%# in ('dir /b /ad "%_mount%\Windows\assembly\*NativeImages*" %_Nul6%') do rmdir /s /q "%_mount%\Windows\assembly\%%#" %_Nul3%
for /f "tokens=* delims=" %%# in ('dir /b /ad "%_mount%\Windows\CbsTemp\" %_Nul6%') do rmdir /s /q "%_mount%\Windows\CbsTemp\%%#\" %_Nul3%
del /s /f /q "%_mount%\Windows\CbsTemp\*" %_Nul3%
for /f "tokens=* delims=" %%# in ('dir /b /ad "%_mount%\Windows\Temp\" %_Nul6%') do rmdir /s /q "%_mount%\Windows\Temp\%%#\" %_Nul3%
del /s /f /q "%_mount%\Windows\Temp\*" %_Nul3%
if exist "%_mount%\Windows\WinSxS\pending.xml" goto :eof
for /f "tokens=* delims=" %%# in ('dir /b /ad "%_mount%\Windows\WinSxS\Temp\InFlight\" %_Nul6%') do (
  takeown /f "%_mount%\Windows\WinSxS\Temp\InFlight\%%#" /A %_Null%
  icacls "%_mount%\Windows\WinSxS\Temp\InFlight\%%#" /grant:r "*S-1-5-32-544:(OI)(CI)(F)" %_Null%
  rmdir /s /q "%_mount%\Windows\WinSxS\Temp\InFlight\%%#\" %_Nul3%
)
if exist "%_mount%\Windows\WinSxS\Temp\PendingRenames\*" (
  takeown /f "%_mount%\Windows\WinSxS\Temp\PendingRenames\*" /A %_Nul3%
  icacls "%_mount%\Windows\WinSxS\Temp\PendingRenames\*" /grant *S-1-5-32-544:F %_Nul3%
  del /f /q "%_mount%\Windows\WinSxS\Temp\PendingRenames\*" %_Nul3%
)
if exist "%_mount%\Windows\System32\*.tmp" (
  takeown /f "%_mount%\Windows\System32\*.tmp" /A %_Nul3%
  icacls "%_mount%\Windows\System32\*.tmp" /grant *S-1-5-32-544:F %_Nul3%
  del /f /q "%_mount%\Windows\System32\*.tmp" %_Nul3%
)
goto :eof

:CleanReg
if exist "%_mount%\Windows\System32\config\*.TM.blf" (
  takeown /f "%_mount%\Windows\System32\config\*.TM.blf" /A %_Nul3%
  icacls "%_mount%\Windows\System32\config\*.TM.blf" /grant *S-1-5-32-544:F %_Nul3%
  del /a /s /f /q "%_mount%\Windows\System32\config\*.TM.blf" %_Nul3%
)
if exist "%_mount%\Windows\System32\config\*.regtrans-ms" (
  takeown /f "%_mount%\Windows\System32\config\*.regtrans-ms" /A %_Nul3%
  icacls "%_mount%\Windows\System32\config\*.regtrans-ms" /grant *S-1-5-32-544:F %_Nul3%
  del /a /s /f /q "%_mount%\Windows\System32\config\*.regtrans-ms" %_Nul3%
)
if exist "%_mount%\Users\Default\*.TM.blf" (
  takeown /f "%_mount%\Users\Default\*.TM.blf" /A %_Nul3%
  icacls "%_mount%\Users\Default\*.TM.blf" /grant *S-1-5-32-544:F %_Nul3%
  del /a /s /f /q "%_mount%\Users\Default\*.TM.blf" %_Nul3%
)
if exist "%_mount%\Users\Default\*.regtrans-ms" (
  takeown /f "%_mount%\Users\Default\*.regtrans-ms" /A %_Nul3%
  icacls "%_mount%\Users\Default\*.regtrans-ms" /grant *S-1-5-32-544:F %_Nul3%
  del /a /s /f /q "%_mount%\Users\Default\*.regtrans-ms" %_Nul3%
)
if exist "%_mount%\Windows\System32\SMI\Store\Machine\*.TM.blf" (
  takeown /f "%_mount%\Windows\System32\SMI\Store\Machine\*.TM.blf" /A %_Nul3%
  icacls "%_mount%\Windows\System32\SMI\Store\Machine\*.TM.blf" /grant *S-1-5-32-544:F %_Nul3%
  del /a /s /f /q "%_mount%\Windows\System32\SMI\Store\Machine\*.TM.blf" %_Nul3%
)
if exist "%_mount%\Windows\System32\SMI\Store\Machine\*.regtrans-ms" (
  takeown /f "%_mount%\Windows\System32\SMI\Store\Machine\*.regtrans-ms" /A %_Nul3%
  icacls "%_mount%\Windows\System32\SMI\Store\Machine\*.regtrans-ms" /grant *S-1-5-32-544:F %_Nul3%
  del /a /s /f /q "%_mount%\Windows\System32\SMI\Store\Machine\*.regtrans-ms" %_Nul3%
)
goto :eof

:preVars
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
set "_EsuIdn=Microsoft-Windows-Security-SPP-Component-ExtendedSecurityUpdatesAI"
set "_SxsCfg=Microsoft\Windows\CurrentVersion\SideBySide\Configuration"
set "_CBS=Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages"
set "_IFEO=HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\dismhost.exe"
set _MOifeo=0
goto :eof

:postVars
set USER=uiUSER
set SYSTEM=uiSYSTEM
set SOFTWARE=uiSOFTWARE
set COMPONENTS=uiCOMPONENTS
set ERRTEMP=
set PREPARED=0
set EXPRESS=0
set uwinpe=0
set _skpd=0
set _skpp=0
set _nesd=0
set _ndir=0
set _nsum=0
set _nupd=0
set _niso=0
set _reMSU=0
set _wimEdge=0
set _Srvr=0
set _LTSC=0
set "_mount=%_drv%\Mount"
set "_ntf=NTFS"
if /i not "%_drv%"=="%SystemDrive%" if %_cwmi% equ 1 for /f "tokens=2 delims==" %%# in ('"wmic volume where DriveLetter='%_drv%' get FileSystem /value"') do set "_ntf=%%#"
if /i not "%_drv%"=="%SystemDrive%" if %_cwmi% equ 0 for /f %%# in ('%_psc% "(([WMISEARCHER]'Select * from Win32_Volume where DriveLetter=\"%_drv%\"').Get()).FileSystem"') do set "_ntf=%%#"
if /i not "%_ntf%"=="NTFS" (
  set "_mount=%SystemDrive%\Mount"
)
set "line============================================================="
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

:pr_color
set _NCS=1
if %winbuild% LSS 10586 set _NCS=0
if %winbuild% GEQ 10586 reg.exe query HKCU\Console /v ForceV2 2>nul | find /i "0x0" %_Null% && (set _NCS=0)

if %_NCS% equ 1 (
for /F %%a in ('echo prompt $E ^| cmd.exe') do set "_esc=%%a"
set     "Red="41;97m" "pad""
set    "Gray="100;97m" "pad""
set   "Green="42;97m" "pad""
set    "Blue="104;97m" "pad""
set  "_White="40;37m" "pad""
set  "_Green="40;92m" "pad""
set "_Yellow="40;93m" "pad""
) else (
set     "Red="DarkRed" "white""
set    "Gray="DarkGray" "white""
set   "Green="DarkGreen" "white""
set    "Blue="Blue" "white""
set  "_White="Black" "Gray""
set  "_Green="Black" "Green""
set "_Yellow="Black" "Yellow""
)

set "_err=echo: &call :dk_color1 %Red% "==== 出现错误 ====" &echo:"
exit /b

:dk_color1
if not "%4"=="" if "%4"=="4" echo:
if %_NCS% equ 1 (
echo %_esc%[%~1%~3%_esc%[0m
) else if %_pwsh% equ 1 (
%_psc% write-host -back '%1' -fore '%2' '%3'
) else (
echo %~3
)
if not "%5"=="" echo:
exit /b

:dk_color2
if not "%7"=="" if "%7"=="7" echo:
if %_NCS% equ 1 (
echo %_esc%[%~1%~3%_esc%[%~4%~6%_esc%[0m
) else if %_pwsh% equ 1 (
%_psc% write-host -back '%1' -fore '%2' '%3' -NoNewline; write-host -back '%4' -fore '%5' '%6'
) else (
echo %~3 %~6
)
if not "%8"=="" echo:
exit /b

:E_NotFind
%_err%
call :dk_color1 %Red% "在指定的路径中未找到所需文件（夹）。" 4 5
goto :QUIT

:E_Admin
%_err%
call :dk_color1 %_Yellow% "此脚本需要以管理员权限运行。" 4
call :dk_color1 %_Yellow% "若要继续执行，请在脚本上右键单击并选择“以管理员权限运行”。"
call :dk_color1 %_Yellow% "请按任意键退出脚本。" 4 5
pause >nul
exit /b

:E_PowerShell
%_err%
call :dk_color1 %_Yellow% "此脚本的工作需要 Windows PowerShell。" 4
call :dk_color1 %_Yellow% "请按任意键退出脚本。" 4 5
pause >nul
exit /b

:E_BinMiss
%_err%
call :dk_color1 %Red% "所需的文件 %_bin% 丢失。" 4 5
goto :QUIT

:E_Apply
call :dk_color1 %Red% "在应用映像的时候出现错误。" 4 5
goto :QUIT

:E_Export
call :dk_color1 %Red% "在导出映像的时候出现错误。" 4 5
goto :QUIT

:E_ISOC
ren ISOFOLDER %DVDISO%
call :dk_color1 %Red% "在创建ISO映像的时候出现错误。" 4 5
goto :QUIT

:QUIT
if %_MOifeo% neq 0 (
call :DismHostOFF
)
if exist ISOFOLDER\ rmdir /s /q ISOFOLDER\
if exist temp\ rmdir /s /q temp\
popd
call :dk_color1 %Blue% "=== 正在清理临时文件..." 4 5
if exist "!_cabdir!\" rmdir /s /q "!_cabdir!\" %_Nul3%
if exist "bin\MSDelta.dll" del /f /q "bin\MSDelta.dll" %_Nul3%
if exist "!_cabdir!\" (
  mkdir %_drv%\_del286 %_Nul3%
  robocopy %_drv%\_del286 "!_cabdir!" /MIR /R:1 /W:1 /NFL /NDL /NP /NJH /NJS %_Nul3%
  rmdir /s /q %_drv%\_del286\ %_Nul3%
  rmdir /s /q "!_cabdir!\" %_Nul3%
)
if %AutoExit% neq 0 exit /b
if %_Debug% neq 0 %FullExit%
call :dk_color1 %_Yellow% "请按数字 0 键退出脚本。"
choice /c 0 /n
if errorlevel 1 (%FullExit%) else (rem.)
