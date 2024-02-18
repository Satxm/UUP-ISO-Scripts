@echo off
title OneDrive

if exist OneDriveSetup.exe del /q /f OneDriveSetup.exe

..\bin\aria2c --no-conf -x16 -s16 -j5 -c -R --allow-overwrite=true --auto-file-renaming=false  -d. "https://g.live.com/1rewlive5skydrive/WinProdLatestBinary"
