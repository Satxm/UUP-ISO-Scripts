@echo off

set "_err========== ���� ========="
set "line============================================================="

:: ����������ַ������Ϊ��ʹ�ô���
:: �����ַʾ�� 127.0.0.1:29758
:: set all_proxy=

cd /d "%~dp0"
if NOT "%cd%"=="%cd: =%" (
echo %_err%
echo ��ǰĿ¼��·���к��пո�������š�
echo �뽫��Ŀ¼�ƶ�����������Ϊ�����ո�����ŵ�Ŀ¼��
echo.
pause
goto :EOF
)

:setid
echo.
echo %line%
echo ������UUPID �������� https://uupdump.net/ ���ҵ���
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
echo ���ڼ��� UUPID ��Ӧ��ϵͳ�汾����
echo %line%
echo.
for /f "delims=' tokens=*" %%a in ('%psc% "$f=[io.file]::ReadAllText('%_batp%',[Text.Encoding]::Default) -split ':getuup\:.*';$id = \"%id%\";iex ($f[1]);"') do set info=%%a
for /f "tokens=1 delims=. " %%b in ("%info%") do set build=%%b
echo %info% | find /i "Server" 1>nul 2>nul && set server=1
echo �� UUPID ��Ӧ��ϵͳ�汾Ϊ��%build%

:START_PROCESS
set "files=files.%random%.txt"
set "Dir=Cabs.%random%"
if not defined build goto :DOWNLOAD_CABS
set "files=files.%build%.txt"
if defined server set "files=%files%.Server.txt"
if %build% lss 22000 set "Dir=Win10.%build%"
if %build% gtr 22000 set "Dir=Win11.%build%"
if defined server set "Dir=WinServer.%build%"

:DOWNLOAD_CABS
echo.
echo %line%
echo ���ڼ��� Cabs ���°��� aria2 �ű�����
echo %line%
echo.
"%aria2%" --no-conf --console-log-level=warn --log-level=info --log="aria2_download.log" -o"%files%" --allow-overwrite=true --auto-file-renaming=false "https://uupdump.net/get.php?id=%id%&pack=zh-cn&edition=updateOnly&aria2=2"
if not exist %files% goto :DOWNLOAD_CABS
if exist %files% %psc% "(Get-Content %files%).Replace('-kb','-KB').Replace('windows1','Windows1').Replace('-ndp','-NDP') | Out-File %files% -Encoding ASCII"
if exist %files% "%aria2%" --no-conf --console-log-level=warn --log-level=info --log="aria2_download.log" --allow-overwrite=true --auto-file-renaming=true -x16 -s16 -j5 -c -R -d"%Dir%" -i"%files%"
if %ERRORLEVEL% GTR 0 goto :DOWNLOAD_ERROR

:DOWNLOAD_DONE
del %files%
del aria2_download.log
echo.
echo ������ɡ�
pause
goto :EOF

:DOWNLOAD_ERROR
del %files%
echo.
echo �������ļ�ʱ����������������
goto :DOWNLOAD_FILES
pause
goto :EOF

:getuup:
$url = "https://api.uupdump.net/listlangs.php?id="+$id
$json = (Invoke-WebRequest $url).content | ConvertFrom-Json
$build = $json.response.updateInfo.build
$name = $json.response.updateInfo.title
Write-Host $build $name
:getuup:
