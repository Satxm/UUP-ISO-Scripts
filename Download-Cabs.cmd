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
for /f "delims=" %%a in ('%psc% "$f=[io.file]::ReadAllText('%_batp%',[Text.Encoding]::Default) -split ':getuupbuild\:.*';$id = \"%id%\";iex ($f[1]);"') do (set build=%%a)
echo �� UUPID ��Ӧ��ϵͳ�汾Ϊ��%build%

:START_PROCESS
set "files=files.%random%.txt"
set "Dir=Cabs.%random%"
if not defined build goto :DOWNLOAD_CABS
set "files=files.%build%.txt"
if %build% gtr 22621 (set "Dir=Win11.23H2") else (set "Dir=Win10.22H2")


:DOWNLOAD_CABS
echo.
echo %line%
echo ���ڼ��� Cabs ���°��� aria2 �ű�����
echo %line%
echo.
"%aria2%" --no-conf --log-level=info --log="aria2_download.log" -o"%files%" --allow-overwrite=true --auto-file-renaming=false "https://uupdump.net/get.php?id=%id%&pack=zh-cn&edition=updateOnly&aria2=2"
if not exist %files% goto :DOWNLOAD_CABS
if exist %files% %psc% "(gc %files%) -creplace '-kb', '-KB' | Out-File %files% -Encoding ASCII"
if exist %files% %psc% "(gc %files%) -creplace 'windows1', 'Windows1' | Out-File %files% -Encoding ASCII"
if exist %files% %psc% "(gc %files%) -creplace '-ndp', '-NDP' | Out-File %files% -Encoding ASCII"


:DOWNLOAD_FILES
echo.
echo %line%
echo ���ڳ��������ļ�����
echo %line%
echo.
if exist %files% "%aria2%" --no-conf --log-level=info --log="aria2_download.log" -x16 -s16 -j5 -c -R -d"%Dir%" -i"%files%"
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
