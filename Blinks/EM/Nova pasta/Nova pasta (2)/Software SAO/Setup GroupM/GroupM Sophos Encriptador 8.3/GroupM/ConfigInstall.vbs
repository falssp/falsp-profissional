Option Explicit
'On Error Resume Next

Dim wshShell, objFSO, colOSes, opSystem, osCaption, objWMIService, strComputer, objOS
Dim strWinDir, currentDir, sSrcFullPath, strFolder, progFiles, pkgVersion, version
Dim logPath, logFile, logs
Dim pkgName, installParam, xSelf, guid, uninstallParam, retCode

strComputer =  "." 
Set wshShell = CreateObject("WScript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")
Set objWMIService = GetObject("winmgmts:" & "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2") 
Set colOSes = objWMIService.ExecQuery("Select * from Win32_OperatingSystem") 

strWinDir = wshShell.ExpandEnvironmentStrings("%WINDIR%")
currentDir = objFSO.GetParentFolderName(WScript.ScriptFullName) & "\"
strFolder = strWinDir & "\Sysnative"
progFiles = wshShell.ExpandEnvironmentStrings("%PROGRAMFILES(x86)%")
sSrcFullPath = Wscript.ScriptFullName
xSelf = False
'=================================================================================================
'Main information:
'=================================================================================================
pkgName = "Sophos_SafeGuardClientConfiguration-GroupM_8.30.0.78_WPP_W10_EN_B1"
guid ="{5DE9370A-D37E-449E-AAA9-8BAE88A62EBD}"
pkgVersion = "8.30.0.78" ' version from registry

'=================================================================================================
'Section for msi only
'=================================================================================================
Dim msiName
msiName = "GroupM_SGNv8.3_06082020.msi" 
'=================================================================================================
'Section for exe only
'=================================================================================================
Dim exeForInstall, installExeParam, exeForUninstall, uninstallExeParam
exeForInstall = "..." 'exe name for installation
installExeParam = chr(34) & currentDir & exeForInstall & chr(34) & "..." 'complete installation commandline
exeForUninstall = "..." 'exe for uninstallation with full path - to check if exe file exists (without chr(34))
uninstallExeParam = chr(34) & exeForUninstall & chr(34) & "..." 'complete uninstallation commandline
'=================================================================================================
'Log section 
'=================================================================================================
logs = strWindir & "\Logs\"
logPath = logs & pkgName & "\"
logFile = pkgName & "_Install_WRAP.log"
'=================================================================================================
'Start installation
'=================================================================================================
Dim mainResult : mainResult = 100
If objFSO.FolderExists(strFolder) Then
	Dim strCMD : strCMD = strWinDir & "\Sysnative\wscript.exe"
	Dim strArgument : strArgument = ""
	If wscript.arguments.count > 0 Then
		Dim arrArgs : Set arrArgs = Wscript.Arguments
		Dim arg
		For Each arg In arrArgs
			strArgument = strArgument & chr(32) & arg
		Next
	End If
	mainResult = wshShell.Run(strCMD & chr(32) & chr(34) & sSrcFullPath & chr(34) & strArgument, 0 ,true)	
	WScript.Quit mainResult
End If

'Create folder for logs
If (objFSO.FolderExists(logs) = false) Then
	objFSO.CreateFolder(logs)	
End If

If (objFSO.FolderExists(logPath) = false) Then
	objFSO.CreateFolder(logPath)
	CreateLog "____________"& pkgName &"_Installation__STARTED____________"
	CreateLog "INFO: Folder " & logPath & " was not found so was created."
Else
	CreateLog "____________"& pkgName &"_Installation__STARTED____________"
	CreateLog "INFO: Folder " & logPath & " was found."
End If	

'Check server
OsProductType

'Add data and time and check operating system
CreateLog "INFO: Date and time: " & Year(Date) & "-" & Right("0" & Month(Date),2) & "-" & Right("0" & Day(Date),2) & " " & Time
For Each objOS In colOSes
	opSystem = UCase(objOS.OSArchitecture)
    osCaption = objOS.Caption
    CreateLog "INFO: OS: " & osCaption
	CreateLog "INFO: OS architecture: " & opSystem
Next 

'!!!!!!! Check if installed -  here could be necessary adding Wow6432Node !!!!!!!
If KeyExists ("HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\" & guid & "\DisplayVersion") Then
		version = wshShell.RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\" & guid & "\DisplayVersion")
		createLog "INFO: Version of application which is currently installed: " & version
		If version = pkgVersion Then 
			If (objFSO.FileExists(progFiles & "\Logs\" & pkgName & ".tag")) Then
				CreateLog "INFO: " & pkgName & " is installed, nothing to do."
				retCode = 0
				CreateLog "INFO: Result code from last operation: " & retCode & "."
				CreateLog "____________ END OF THE LOG ____________"
				WScript.Quit(retCode)
			Else
				CreateLog "INFO: " & guid & " is installed, but this is not proper package."	
					retCode = 9
					CreateLog "INFO: Result code from last operation: " & retCode & "."
					CreateLog "____________ END OF THE LOG ____________"
					WScript.Quit(retCode)
			End If
		End If 
End If

'KillProcess "..."

REM If xSelf = True Then 
	REM retCode = UninstallApplicationMSI(guid)
	REM 'retCode = UninstallApplicationEXE(guid, exeForUninstall, uninstallExeParam)
REM End If

'Installation
retCode = InstallApplicationMSI(pkgName, msiName)
'retcode = InstallApplicationEXE(pkgName, installExeParam)

CreateLog "INFO: Result code from last operation: " & retCode & "."
CreateLog "____________ END OF THE LOG ____________"
WScript.Quit(retCode)

'==================================================================================================
'FUNCTION FOR MSI 
'==================================================================================================
Function InstallApplicationMSI(name, msi)
	CreateLog "INFO: Installation of "& name &" is started."
	installParam = "msiexec /i " & chr(34) & currentDir & msi & chr(34) & " TRANSFORMS=" & chr(34) & currentDir & name & ".mst" & chr(34) & " /qn /l*v+ " & chr(34) & logPath & name & "_Install_MSI.log" & chr(34)
	CreateLog "INFO: Installation parameters: " & installParam
	retCode = wshShell.Run(installParam, 0, True)
	CreateLog  "INFO: Installation of " & name & " was ended with result code: " & retCode
	If retCode = 0 Then
		CreateLog "INFO: Installation was completed successfully."
	ElseIf retCode = 3010 Then
		CreateLog "INFO: Installation was completed successfully. Reboot is required!"
		retCode = 0 
	Else
		CreateLog "INFO: Installation was failed!"
		CreateLog "INFO: Result code from last operation: " & retCode & "."
		CreateLog "____________ END OF THE LOG ____________"
		WScript.Quit(retCode)
	End If
	InstallApplicationMSI = retCode
End Function

Function UninstallApplicationMSI(sGuid)   
    CreateLog "INFO: Uninstallation of " & sGuid & " is started."
    uninstallParam = "msiexec /x" & sGuid & " /qn REBOOT=ReallySuppress /l*v+ " & chr(34) & logPath & sGuid & "_Uninstall_MSI.log" & chr(34)
    CreateLog "INFO: Uninstallation parameters: " & uninstallParam
    retCode = wshShell.Run(uninstallParam, 0, True)
    CreateLog "INFO: Uninstallation of " & sGuid & " was ended with result code: " & retCode
	If retCode = 0 or retCode = 1605 Then
		CreateLog "INFO: Uninstallation was completed successfully."
		retCode = 0 
	ElseIf retCode = 3010 Then
		CreateLog "INFO: Uninstallation was completed successfully. Reboot is required!"
		retCode = 0 
	Else
		CreateLog "INFO: Uninstallation was failed! The installation has been stopped."
		CreateLog "INFO: Result code from last operation: " & retCode & "."
		CreateLog "____________ END OF THE LOG ____________"
		WScript.Quit(retCode)
	End If 
	UninstallApplicationMSI = retCode	
End Function 
'==================================================================================================
'FUNCTION FOR EXE
'==================================================================================================
Function InstallApplicationEXE(name, installExePar)
	CreateLog "INFO: Installation of "& name &" is started."
	CreateLog "INFO: Installation parameters: " &  installExePar
	retCode = wshShell.Run(installExePar, 0, True)
	CreateLog "INFO: Installation of " & name & " was ended with result code: " & retCode
	If retCode = 0 Then '!!!!!!! add properly retCode here !!!!!!!
		CreateLog "INFO: Installation was completed successfully."
	'elseif retCode = X then  'X = restart retCode after successfully installation
		'CreateLog "INFO: Installation was completed successfully. Reboot is required!"
		'retCode = 0 		
	Else
		CreateLog "INFO: Installation was failed!"
		'!!!!!!! here copy all log files if necessary !!!!!!!
		CreateLog "INFO: Result code from last operation: " & retCode & "."
		CreateLog "____________ END OF THE LOG ____________"
		WScript.Quit(retCode)
	End If
	
	'!!!!!!! Check if installed -  here could be necessary adding Wow6432Node !!!!!!!
	If KeyExists ("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\" & guid & "\DisplayVersion") Then
		version = wshShell.RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\" & guid & "\DisplayVersion")
		createLog "INFO: Version of application which is currently installed: " & version
		If version = pkgVersion Then 
		
			'!!!!!!! Here add additional required settings after installation exe !!!!!!!
			'!!!!!!! here copy all log files if necessary !!!!!!!
			'..................
			CreateTag(name)
		Else
			retCode = 1
			CreateLog "INFO: Installation was failed! Wrong version of application."
			'!!!!!!! here copy all log files if necessary !!!!!!!
			CreateLog "INFO: Result code from last operation: " & retCode & "."
			CreateLog "____________ END OF THE LOG ____________"
			WScript.Quit(retCode)
		End If 
	Else
		retCode = 1
		CreateLog "INFO: Installation was failed! Entry in registry does not exist."
		'!!!!!!! here copy all log files if necessary !!!!!!!
		CreateLog "INFO: Result code from last operation: " & retCode & "."
		CreateLog "____________ END OF THE LOG ____________"
		WScript.Quit(retCode)	
	End If

	InstallApplicationEXE = retCode
End Function

Function UninstallApplicationEXE(sGuid, exeForUninst, uninstallExePar)
	If Not (objFSO.FileExists(exeForUninst)) Then
		CreateLog "INFO: File " & exeForUninst & " was not found. Uninstallation is impossible."
		retCode = 1
		CreateLog "INFO: Result code from last operation: " & retCode & "."
		CreateLog "____________ END OF THE LOG ____________"
		WScript.Quit(retCode) 
	End If
	CreateLog "INFO: Uninstallation of "& sGuid &" is started."
	CreateLog "INFO: Uninstallation parameters: " &  uninstallExePar
	retCode = wshShell.Run(uninstallExePar, 0, True)
	CreateLog  "INFO: Uninstallation of " & sGuid & " was ended with result code: " & retCode
	If retCode = 0 Then '!!!!!!! add properly retCode here !!!!!!!
		CreateLog "INFO: Uninstallation was completed successfully."
		'!!!!!!! copy all log files if necessary !!!!!!!
	'elseif retCode = X then  'X = restart retCode after successfully uninstallation
		'CreateLog "INFO: Uninstallation was completed successfully. Reboot is required!"
		'retCode = 0 
		'!!!!!!! copy all log files if necessary !!!!!!!
	Else
		CreateLog "INFO: Uninstallation was failed! The installation has been stopped."
		'!!!!!!! copy all log files if necessary !!!!!!!
		CreateLog "INFO: Result code from last operation: " & retCode & "."
		CreateLog "____________ END OF THE LOG ____________"
		WScript.Quit(retCode)
	End If
	
	'!!!!!!! Check if installed -  here could be necessary adding Wow6432Node !!!!!!!
	If KeyExists ("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\" & guid & "\DisplayName") Then
			createLog "INFO: Uninstallation was failed! Application is still installed."
			'!!!!!!! copy all log files if necessary !!!!!!!
			retCode = 1
			createLog "INFO: Result code from last operation: " & retCode & "."
			createLog "____________ END OF THE LOG _____________"
			WScript.Quit(retCode)
	End If
	
	
	UninstallApplicationEXE = retCode
End Function
'==================================================================================================
'OTHER FUNCTIONS
'==================================================================================================
' Create log file from VBS
Sub CreateLog(strMessage)	
	Const forAppending = 8	
	If Not objFSO.FileExists(logPath & logFile) Then 
		objFSO.CreateTextFile(logPath & logFile)
	End If
	Dim objOutputFile : Set objOutputFile = objFSO.OpenTextFile(logPath & logFile, forAppending)
    objOutputFile.WriteLine Date() & " " & Time() & " " & strMessage
	objOutputFile.Close
	Set objOutputFile = Nothing
End Sub

'Process kill
Sub KillProcess(process)
	Dim kill
    kill = "taskkill /t /f /im " & process
    CreateLog "INFO: Executing: " & kill
    wshShell.Run kill, 0, True
End Sub

'Check if key exist
Function KeyExists(key)
    On Error Resume Next
	Err.Clear
	wshShell.RegRead(key)
    If Err = 0 Then KeyExists = True
End Function
    
' Detect if the script is running on a Server or a workstation
Function OsProductType
    On Error Resume Next
    Dim objWMI, objItem, colItems, productType
    Set objWMI = GetObject("winmgmts:\\.\root\cimv2")
    Set colItems = objWMI.ExecQuery("Select * from Win32_OperatingSystem",,48)
	For Each objItem in colItems
        productType = objItem.ProductType
    Next
	If productType = 1 Then 'workstation
		CreateLog "INFO: OS Not identified as a Server. Installation will Continue."
    Else 'server
		CreateLog "INFO: OS Identified as a Server. Installation halted."
		CreateLog "INFO: This Package is not intended for server installation."
		retCode = 1002
		CreateLog "INFO: Result code from last operation: " & retCode & "."
		CreateLog "____________ The installation has been STOPPED ____________"
		WScript.Quit(retCode)
    End If
End Function

' Create tag file
Function CreateTag(name)
    Dim tagFolder, tagName
    tagFolder = progFiles & "\Logs\"
    tagName = name & ".tag"
    If (objFSO.FolderExists(tagFolder) = false) Then
        objFSO.CreateFolder(tagFolder)	
        CreateLog "INFO: Logs folder " & tagFolder & " was not found so was created."
    Else
        CreateLog "INFO: Logs folder " & tagFolder & " was found."
	End if
    If Not objFSO.FileExists(tagFolder & tagName) Then 
        objFSO.CreateTextFile(tagFolder & tagName)
        CreateLog "INFO: Tag file " & tagName & " was created."
	End If
End Function