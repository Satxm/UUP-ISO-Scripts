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
set "Dir2=Apps\Apps"

echo.
echo %line%
echo ���ڼ��� UUPID ��Ӧ��ϵͳ�汾����
echo %line%
echo.
for /f "delims=" %%a in ('%psc% "$f=[io.file]::ReadAllText('%_batp%',[Text.Encoding]::Default) -split ':getuupbuild\:.*';$id = \"%id%\";iex ($f[1]);"') do (set build=%%a)
echo �� UUPID ��Ӧ��ϵͳ�汾Ϊ��%build%

:START_PROCESS
set "files=files.%random%.txt"
set "Dir1=UUPs.%random%"
if not defined build goto :DOWNLOAD_APPS
set "files=files.%build%.txt"
set "Dir1=UUPs.%build%"
set "SecHealthUI=Microsoft.SecHealthUI_1000."%build%".0_x64__8wekyb3d8bbwe.Appx"

:DOWNLOAD_APPS
echo.
echo %line%
echo ���ڼ��� SecHealthUI �� aria2 �ű�����
echo %line%
echo.
"%aria2%" --no-conf --log-level=info --log="aria2_download.log" -o"%files%" --allow-overwrite=true --auto-file-renaming=false "https://uupdump.net/getfile.php?id=%id%&file=IPA_WindowsSecurity_Microsoft.SecHealthUI_8wekyb3d8bbwe.appx&aria2=2"
if not exist %files% "%aria2%" --no-conf --log-level=info --log="aria2_download.log" -o"%files%" --allow-overwrite=true --auto-file-renaming=false "https://uupdump.net/getfile.php?id=%id%&file=Microsoft.SecHealthUI_8wekyb3d8bbwe.appx&aria2=2"
if not exist %files% goto :DOWNLOAD_APPS
if exist %files% %psc% "(gc %files%) -creplace 'IPA_WindowsSecurity_Microsoft.SecHealthUI_8wekyb3d8bbwe.appx', '%SecHealthUI%' | Out-File %files% -Encoding ASCII"
if exist %files% %psc% "(gc %files%) -creplace 'Microsoft.SecHealthUI_8wekyb3d8bbwe.appx', '%SecHealthUI%' | Out-File %files% -Encoding ASCII"
if exist %files% "%aria2%" --no-conf --log-level=info --log="aria2_download.log" -x10 -s16 -j5 -c -R -d"%Dir2%" -i"%files%"
if %ERRORLEVEL% GTR 0 goto :DOWNLOAD_ERROR

:DOWNLOAD_UUPS
echo.
echo %line%
echo ���ڼ������� UUPs �� aria2 �ű�����
echo %line%
echo.
"%aria2%" --no-conf --log-level=info --log="aria2_download.log" -o"%files%" --allow-overwrite=true --auto-file-renaming=false "https://uupdump.net/get.php?id=%id%&pack=zh-cn&edition=professional;core&aria2=2"
if not exist %files% goto :DOWNLOAD_UUPS
if exist %files% %psc% "(gc %files%) -creplace 'cabs_', '' | Out-File %files%"
if exist %files% %psc% "(gc %files%) -creplace 'MetadataESD_', '' | Out-File %files% -Encoding ASCII"
if exist %files% %psc% "(gc %files%) -creplace '.ESD', '.esd' | Out-File %files% -Encoding ASCII"
if exist %files% %psc% "(gc %files%) -creplace '-kb', '-KB' | Out-File %files% -Encoding ASCII"
if exist %files% %psc% "(gc %files%) -creplace 'windows1', 'Windows1' | Out-File %files% -Encoding ASCII"
if exist %files% %psc% "(gc %files%) -creplace '-ndp', '-NDP' | Out-File %files% -Encoding ASCII"
if exist %files% "%aria2%" --no-conf --log-level=info --log="aria2_download.log" -x16 -s16 -j5 -c -R -d"%Dir1%" -i"%files%"
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


:getuupbuild:
$url = "https://api.uupdump.net/get.php?id="+$id+"&pack=zh-cn&edition=updateOnly&noLinks=1"
((Invoke-WebRequest $url).content | ConvertFrom-Json).response.build
:getuupbuild:
