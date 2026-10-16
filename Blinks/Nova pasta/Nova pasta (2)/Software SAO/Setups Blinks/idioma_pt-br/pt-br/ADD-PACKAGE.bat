@echo off
color 1F
@echo on
DISM /ONLINE /ADD-Package /PACKAGEPATH:"%~dp0microsoft-windows-client-languagepack-package_pt-br-amd64-pt-br.cab"
cls
DISM /ONLINE /ADD-Package /PACKAGEPATH:"%~dp0microsoft-windows-languagefeatures-basic-pt-br-package-amd64.cab"
cls
DISM /ONLINE /ADD-Package /PACKAGEPATH:"%~dp0microsoft-windows-languagefeatures-handwriting-pt-br-package-amd64.cab"
cls
DISM /ONLINE /ADD-Package /PACKAGEPATH:"%~dp0microsoft-windows-languagefeatures-ocr-pt-br-package-amd64.cab"
cls
DISM /ONLINE /ADD-Package /PACKAGEPATH:"%~dp0microsoft-windows-languagefeatures-speech-pt-br-package-amd64.cab"
cls
DISM /ONLINE /ADD-Package /PACKAGEPATH:"%~dp0microsoft-windows-languagefeatures-texttospeech-pt-br-package-amd64.cab"
cls
@echo off
powershell -command "Set-Culture 'pt-br'"
powershell -command "Set-WinSystemLocale -SystemLocale 'pt-br'"
powershell -command "Set-Culture 'pt-br'"
powershell -command "Set-WinUserLanguageList -Force 'pt-br'"
powershell -command "Set-WinHomeLocation -GeoId '32'"
echo.
echo.
echo.
echo. 1- Presione as teclas Windows+R, digite regedit e clique em Ok;
echo.
echo. 2- Navegue entre as chaves de registro HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\MUI\UILanguages;
echo.
echo. 3- Apague todos os idiomas, deixe apenas pt-br e reinicie o sistema para concluir...
echo.
echo.
pause
exit


