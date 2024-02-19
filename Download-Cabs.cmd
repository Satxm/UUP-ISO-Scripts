@echo off

set "_err========== 错误 ========="
set "line============================================================="

:: 请输入代理地址，留空为不使用代理
:: 代理地址示例 127.0.0.1:29758
:: set all_proxy=

cd /d "%~dp0"
if NOT "%cd%"=="%cd: =%" (
    echo %_err%
    echo 当前目录的路径中含有空格或者括号。
    echo 请将此目录移动到或重命名为不含空格或括号的目录。
    echo.
    pause
    goto :EOF
)

:setid
echo.
echo %line%
echo 请输入UUPID （可以在 https://uupdump.net/ 中找到）
echo %line%
echo.

set /p id=

if not defined id goto :setid

set "_batf=%~f0"
set "_batp=%_batf:'=''%"

set psc=powershell.exe
set "aria2=bin\aria2c.exe"

echo.
echo %line%
echo 正在检索 UUPID 对应的系统版本……
echo %line%
echo.
for /f "delims=' tokens=*" %%a in ('%psc% "$f=[io.file]::ReadAllText('%_batp%',[Text.Encoding]::Default) -split ':getuup\:.*';$id = \"%id%\";iex ($f[1]);"') do set info=%%a
set info=%info:(=%
set info=%info:)=%
for /f "tokens=1 delims= " %%b in ('echo %info%') do set build=%%b
echo 此 UUPID 对应的系统版本为：%build%

:START_PROCESS
set "files=files.%random%.txt"
set "Dir=Cabs.%random%"
if not defined build goto :DOWNLOAD_CABS
set "files=files.%build%.txt"
if %build% gtr 19041 set "Dir=Win10.22H2"
if %build% gtr 22621 set "Dir=Win11.23H2"
if %build% gtr 26000 set "Dir=Win11.24H2"

:DOWNLOAD_CABS
echo.
echo %line%
echo 正在检索 Cabs 更新包的 aria2 脚本……
echo %line%
echo.
"%aria2%" --no-conf --log-level=info --log="aria2_download.log" -o"%files%" --allow-overwrite=true --auto-file-renaming=false "https://uupdump.net/get.php?id=%id%&pack=zh-cn&edition=updateOnly&aria2=2"
if not exist %files% goto :DOWNLOAD_CABS
if exist %files% %psc% "(gc %files%) -creplace '-kb', '-KB' | Out-File %files% -Encoding ASCII"
if exist %files% %psc% "(gc %files%) -creplace 'windows1', 'Windows1' | Out-File %files% -Encoding ASCII"
if exist %files% %psc% "(gc %files%) -creplace '-ndp', '-NDP' | Out-File %files% -Encoding ASCII"
if exist %files% "%aria2%" --no-conf --log-level=info --log="aria2_download.log" -x16 -s16 -j5 -c -R -d"%Dir%" -i"%files%"
if %ERRORLEVEL% GTR 0 goto :DOWNLOAD_ERROR

:DOWNLOAD_DONE
del %files%
del aria2_download.log
echo.
echo 下载完成。
pause
goto :EOF

:DOWNLOAD_ERROR
del %files%
echo.
echo 在下载文件时遇到错误。正在重试
goto :DOWNLOAD_FILES
pause
goto :EOF

:getuup:
$url = "https://api.uupdump.net/get.php?id="+$id+"&pack=zh-cn&edition=updateOnly&noLinks=1"
$json = (Invoke-WebRequest $url).content | ConvertFrom-Json
$build = $json.response.build
$name = $json.response.updateName
Write-Host $build $name
:getuup:
