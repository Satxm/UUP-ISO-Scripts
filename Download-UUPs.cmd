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
set info=%info:(=%
set info=%info:)=%
for /f "tokens=1 delims= " %%b in ('echo %info%') do set build=%%b
echo %info% | find /i "Server" 1>nul 2>nul && set server=1
echo �� UUPID ��Ӧ��ϵͳ�汾Ϊ��%build%

:START_PROCESS
set "files=files.%random%.txt"
set "Dir=UUPs.%random%"
if not defined build goto :DOWNLOAD_APPS
set "files=files.%build%.txt"
if defined server set "files=files.%build%.Server.txt"
set "Dir=UUPs.%build%"
if defined server set "Dir=UUPs.%build%.Server"

:DOWNLOAD_UUPS
echo.
echo %line%
echo ���ڼ������� UUPs �� aria2 �ű�����
echo %line%
echo.
if exist %files% del /f /q %files%
"%aria2%" --no-conf --console-log-level=warn --log-level=info --log="aria2_download.log" -o"%files%" --allow-overwrite=true --auto-file-renaming=false "https://uupdump.net/get.php?id=%id%&pack=zh-cn&edition=professional;core&aria2=2"
if defined server "%aria2%" --no-conf --console-log-level=warn --log-level=info --log="aria2_download.log" -o"%files%" --allow-overwrite=true --auto-file-renaming=false "https://uupdump.net/get.php?id=%id%&pack=zh-cn&edition=serverdatacenter;serverdatacentercore;serverstandard;serverstandardcore&aria2=2"
if not exist %files% goto :DOWNLOAD_UUPS
if exist %files% %psc% "(gc %files%) -creplace 'cabs_', '' | Out-File %files%"
if exist %files% %psc% "(gc %files%) -creplace 'MetadataESD_', '' | Out-File %files% -Encoding ASCII"
if exist %files% %psc% "(gc %files%) -creplace 'Wim_', '' | Out-File %files% -Encoding ASCII"
if exist %files% %psc% "(gc %files%) -creplace '\.ESD', '\.esd' | Out-File %files% -Encoding ASCII"
if exist %files% %psc% "(gc %files%) -creplace '-kb', '-KB' | Out-File %files% -Encoding ASCII"
if exist %files% %psc% "(gc %files%) -creplace 'windows1', 'Windows1' | Out-File %files% -Encoding ASCII"
if exist %files% %psc% "(gc %files%) -creplace '-ndp', '-NDP' | Out-File %files% -Encoding ASCII"
if exist %files% "%aria2%" --no-conf --console-log-level=warn --log-level=info --log="aria2_download.log" -x16 -s16 -j5 -c -R -d"%Dir%" -i"%files%"
if %ERRORLEVEL% GTR 0 goto :DOWNLOAD_ERROR

:DOWNLOAD_APPS
echo.
echo %line%
echo ���ڼ������� Apps �� aria2 �ű�����
echo %line%
echo.
if exist %files% del /f /q %files%
"%aria2%" --no-conf --console-log-level=warn --log-level=info --log="aria2_download.log" -o"%files%" --allow-overwrite=true --auto-file-renaming=false "https://uupdump.net/get.php?id=%id%&pack=neutral&edition=app&aria2=2"
if exist %files% %psc% "(gc %files%) -creplace 'IPA_', '' | Out-File %files% -Encoding ASCII"
if exist %files% "%aria2%" --no-conf --console-log-level=warn --log-level=info --log="aria2_download.log" -x16 -s16 -j5 -c -R -d"%Dir%" -i"%files%"
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
$url = "https://api.uupdump.net/get.php?id="+$id+"&pack=zh-cn&edition=updateOnly&noLinks=1"
$json = (Invoke-WebRequest $url).content | ConvertFrom-Json
$build = $json.response.build
$name = $json.response.updateName
Write-Host $build $name
:getuup:
