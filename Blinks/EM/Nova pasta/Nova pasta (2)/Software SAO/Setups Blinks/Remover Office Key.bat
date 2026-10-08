:loop2
@echo PROCURANDO LICENCAS DO OFFICE...
@echo                                       .;'';.                              
@echo                                    `;''''''''':`                          
@echo                                  ,''''''''''''''';                        
@echo                               `'''''''''''''''''''                        
@echo                            `;''''''''''';'''''''''                        
@echo                          ,'''''''''''.   '''''''''                        
@echo                         '''''''':.       '''''''''                        
@echo                         ''''',           '''''''''                        
@echo                         ''''',           '''''''''                        
@echo                         ''''',           '''''''''                        
@echo                         ''''',           '''''''''                        
@echo                         ''''',           '''''''''                        
@echo                         ''':             '''''''''                        
@echo                         '.               '''''''''                        
@echo                         .;.`             '''''''''                        
@echo                            ,''';:,`      '''''''''                        
@echo                               ;'''''''';:'''''''''                        
@echo                                 `;''''''''''''''''                        
@echo                                    .''''''''''',                          
@echo                                       :'''':`                             
@echo                                         `                                 
@echo off                                                                           
@echo off                                                                           
@echo                    `   `                                                  
@echo       .;';`      '';  ';'`'`                    .;',      `;';   ,,,,,,   
@echo     `'':,;''    ,'   ':   '                    .;..''    :':.,`  ';;;;;   
@echo     ':     ''   ;;   '.                             ',  .'       '`       
@echo    ;;       '.  ;;   '.                             ',  ',       '        
@echo    '`       '' '''''''''. '   ,''''  `''''          '`  '        '        
@echo   `'        ,'  ;;   '.   '  ,'`  `  '.  ,'       `':  `' ''',   ';':     
@echo   .'        .'  ;;   '.   '  '`     ;'    '.    ''':`  .''` .',  ...''.   
@echo   `'        ,'  ;;   '.   ' `'      ':,,,,',       `', ,'    ,'      :'   
@echo    '        ;'  ;;   '.   ' .'      '::::::.        .' .'     '       '   
@echo    ';       '`  ;;   '.   ' `'      ',              `' `'     '       '   
@echo    `',     ''   ;;   '.   '  ':     :'              ;'  ',   :'      :'   
@echo     .'',,:''    ;;   '.   '  .';..;  ''.`,'    ':`.;'   .':`:'  ,:..;'`   
@echo       :;;:`     ::   :.   :    :;;.   :;;:     `;;;,      ;;:    :;;:     
@echo							 by Infra Team Blinks!
@echo off
@ECHO OFF
cd C:\Program Files\Microsoft Office\Office16
cscript OSPP.VBS /dstatus > %temp%/key_office.txt
FIND /C "Last"  C:\Users\%username%\AppData\Local\Temp/key_office.txt 
@echo==========================CHAVES ATIVADAS==========================
@echo==========================INICIAR REMOCAO==========================
pause
@echo off
TYPE C:\Users\%username%\AppData\Local\Temp\key_office.txt 
:loop1
@echo DIGITE A CHAVE:
set /p teste=
cd C:\Program Files\Microsoft Office\Office16
cscript OSPP.VBS /unpkey:%teste%
@echo DIGITE: [1 REMOVER OUTRA CHAVE] [2 LER CHAVES NOVAMENTE] [3 SAIR]
set /p opc=
IF %opc% EQU 1 (goto loop1) 
IF %opc% EQU 2 (goto loop2) 

