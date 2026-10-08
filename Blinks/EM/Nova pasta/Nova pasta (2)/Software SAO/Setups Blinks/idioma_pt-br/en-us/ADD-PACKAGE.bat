@echo off
color 1F
@echo on
DISM /ONLINE /ADD-Package /PACKAGEPATH:"%~dp0microsoft-windows-client-languagepack-package_en-us-amd64-en-us.cab"
cls
DISM /ONLINE /ADD-Package /PACKAGEPATH:"%~dp0microsoft-windows-languagefeatures-basic-en-us-package-amd64.cab"
cls
DISM /ONLINE /ADD-Package /PACKAGEPATH:"%~dp0microsoft-windows-languagefeatures-handwriting-en-us-package-amd64.cab"
cls
DISM /ONLINE /ADD-Package /PACKAGEPATH:"%~dp0microsoft-windows-languagefeatures-ocr-en-us-package-amd64.cab"
cls
DISM /ONLINE /ADD-Package /PACKAGEPATH:"%~dp0microsoft-windows-languagefeatures-speech-en-us-package-amd64.cab"
cls
DISM /ONLINE /ADD-Package /PACKAGEPATH:"%~dp0microsoft-windows-languagefeatures-texttospeech-en-us-package-amd64.cab"
cls
@echo off
echo.
echo.
echo.
echo. 1- Presione as teclas Windows+R, digite regedit e clique em Ok;
echo.
echo. 2- Navegue entre as chaves de registro HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\MUI\UILanguages;
echo.
echo. 3- Apague todos os idiomas, deixe apenas en-us e reinicie o sistema para concluir...
echo.
echo.
pause
exit




