Option Explicit
'On Error Resume Next

Dim wshShell, objFSO, strComputer, objWMIService, opSystem, osCaption, colOSes, objOS
Dim progFiles, strWinDir, currentDir, sSrcFullPath, strFolder
Dim logPath, logFile, logs
Dim pkgName, guid, retCode, uninstallParam, pkgVersion, version, ProgData, switchUninstall

strComputer = "." 
Set wshShell = CreateObject("WScript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")
Set objWMIService = GetObject("winmgmts:" & "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2") 
Set colOSes = objWMIService.ExecQuery("Select * from Win32_OperatingSystem") 

strWinDir = wshShell.ExpandEnvironmentStrings("%WINDIR%")
currentDir = objFSO.GetParentFolderName(WScript.ScriptFullName) & "\"
strFolder = strWinDir & "\Sysnative"
progFiles = wshShell.ExpandEnvironmentStrings("%PROGRAMFILES(x86)%")
sSrcFullPath = Wscript.ScriptFullName
ProgData = wshShell.ExpandEnvironmentStrings("%ProgramData%")
'=================================================================================================
'Main information (for msi- additional variable are not required)
'=================================================================================================
pkgName = "Cisco_AnyConnectSecureMobilityClientAndISEProfiles_1.0_WPP_W7W10_EN_B1"
guid ="...."
pkgVersion = "..." ' version from registry

'=================================================================================================
'Section for exe only
'=================================================================================================
Dim exeForUninstall, uninstallExeParam
exeForUninstall = "..." 'exe for uninstallation with full path - to check if exe file exists (without chr(34))
uninstallExeParam = chr(34) & exeForUninstall & chr(34) & "..." 'complete uninstallation commandline
'=================================================================================================
'Log section 
'=================================================================================================
logs = strWindir & "\Logs\"
logPath = logs & pkgName & "\"
logFile = pkgName & "_Uninstall_WRAP.log"
'=================================================================================================
'start uninstallation
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
	CreateLog "____________"& pkgName &"_Uninstallation__STARTED____________"
	CreateLog "INFO: Folder " & logPath & " was not found so was created."
Else
	CreateLog "____________"& pkgName &"_Uninstallation__STARTED____________"
	CreateLog "INFO: Folder " & logPath & " was found."
End If		

'Add data and time and check operating system
CreateLog "INFO: Date and time: " & Year(Date) & "-" & Right("0" & Month(Date),2) & "-" & Right("0" & Day(Date),2) & " " & Time
For Each objOS In colOSes
	opSystem = objOS.OSArchitecture
    osCaption = objOS.Caption
    CreateLog "INFO: OS: " & osCaption
	CreateLog "INFO: OS architecture: " & opSystem
Next 

'!!!!!!! Check if installed -  here could be necessary adding Wow6432Node !!!!!!!
' If Not (KeyExists("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\" & guid & "\DisplayName")) Then
	' CreateLog "INFO: " & guid & " is not installed. Nothing to uninstall."
	' retCode = 0
	' CreateLog "INFO: Result code from last operation: " & retCode & "."
	' CreateLog "____________ END OF THE LOG ____________"
	' WScript.Quit(retCode)
' Else
	' If KeyExists ("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\" & guid & "\DisplayVersion") Then
		' version = wshShell.RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\" & guid & "\DisplayVersion")
		' createLog "INFO: Version of application which is currently installed: " & version
		' If version =  pkgVersion Then
			' createLog "INFO: Uninstallation will be continued."
			' If (objFSO.FileExists(progFiles & "\Logs\" & pkgName & ".tag")) Then
				' CreateLog "INFO: " & guid & " is installed and tag file exists."
			' Else
				' CreateLog "INFO: " & guid & " is installed but tag file does not exist."
			' End If
		' Else
			' createLog "INFO: Another version of application is installed. Nothing to uninstall."
			' retCode = 0
			' createLog "INFO: Result code from last operation: " & retCode & "."
			' createLog "____________ END OF THE LOG _____________"
			' WScript.Quit(retCode)
		' End If
	' End If
' End If

KillProcess "vpnui.exe"
KillProcess "acwebhelper.exe"
KillProcess "vpnmgmttun.exe"
KillProcess "vpncli.exe"
KillProcess "vpnagent.exe"
KillProcess "VACon64.exe"
KillProcess "vpndownloader.exe"
KillProcess "manifesttool.exe"
KillProcess "aciseagent.exe"
KillProcess "aciseposture.exe"
KillProcess "aciseuac.exe"

' retCode = UninstallApplicationMSI(pkgName, guid)	
'retCode = UninstallApplicationEXE(pkgName, exeForUninstall, uninstallExeParam)

DeleteFile ProgData & "\Cisco\Cisco AnyConnect Secure Mobility Client\Profile\GroupM-AnyConnect-Profile.xml"
DeleteFile ProgData & "\Cisco\Cisco AnyConnect Secure Mobility Client\ISE Posture\ISEPostureCFG.xml"
DeleteFile(progFiles & "\Logs\" & pkgName & ".tag")
DeleteFolder(progFiles & "\Logs")

DeleteFolder ProgData & "\Cisco\Cisco AnyConnect Secure Mobility Client\Profile"
DeleteFolder ProgData & "\Cisco\Cisco AnyConnect Secure Mobility Client\ISE Posture"
DeleteFolder ProgData & "\Cisco\Cisco AnyConnect Secure Mobility Client"
DeleteFolder ProgData & "\Cisco"
retCode = 0
CreateLog "INFO: Result code from last operation: " & retCode & "."
CreateLog "____________ END OF THE LOG ____________"
WScript.Quit(retCode)

'==================================================================================================
'FUNCTION FOR MSI
'==================================================================================================
Function UninstallApplicationMSI(name, sGuid)   
    CreateLog "INFO: Uninstallation of " & name & " is started."
    uninstallParam = "msiexec /x" & sGuid & " /qn REBOOT=ReallySuppress /l*v+ " & chr(34) & logPath & name & "_Uninstall_MSI.log" & chr(34)
    CreateLog "INFO: Uninstallation parameters: " &  uninstallParam
    retCode = wshShell.Run (uninstallParam, 0, True)
    CreateLog "INFO: Uninstallation of " & name & " was ended with result code: " & retCode
	If retCode = 0 or retCode = 1605 Then
		CreateLog "INFO: Uninstallation was completed successfully."
		retCode = 0 
	ElseIf retCode = 3010 Then
		CreateLog "INFO: Uninstallation was completed successfully. Reboot is required!"
		retCode = 0 
	Else
		CreateLog "INFO: Uninstallation was failed!"
		CreateLog "INFO: Result code from last operation: " & retCode & "."
		CreateLog "____________ END OF THE LOG ____________"
		WScript.Quit(retCode)
	End If 
	UninstallApplicationMSI = retCode	
End Function 

'==================================================================================================
'FUNCTION FOR EXE
'==================================================================================================
Function UninstallApplicationEXE(name, exeForUninst, uninstallExePar)
	If Not (objFSO.FileExists(exeForUninst)) Then
		CreateLog "INFO: File " & exeForUninst & " was not found. Uninstallation is impossible."
		retCode = 1
		CreateLog "INFO: Result code from last operation: " & retCode & "."
		CreateLog "____________ END OF THE LOG ____________"
		WScript.Quit(retCode) 
	End If
	CreateLog "INFO: Uninstallation of "& name &" is started."
	CreateLog "INFO: Uninstallation parameters: " &  uninstallExePar
	retCode = wshShell.Run (uninstallExePar, 0, True)
	CreateLog  "INFO: Uninstallation of " & name & " was ended with result code: " & retCode
	If retCode = 0 Then '!!!!!!! add properly retCode here !!!!!!!
		CreateLog "INFO: Uninstallation was completed successfully."
	Else
		CreateLog "INFO: Uninstallation was failed!"
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
	
	'!!!!!!! Here add additional action after uninstallation exe !!!!!!!
	'!!!!!!! copy all log files if necessary !!!!!!!
	'..................
	DeleteFile(progFiles & "\Logs\" & name & ".tag")
	DeleteFolder(progFiles & "\Logs")
	UninstallApplicationEXE = retCode
End Function
'==================================================================================================
'OTHER FUNCTION
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

'Delete file
Function DeleteFile(delFile)
	If (objFSO.FileExists(delFile)) Then
		Err.Clear
		objFSO.DeleteFile delFile, True
        If Err.number <> 0 Then 
			CreateLog "INFO: File: " & delFile & " was not deleted."
		Else
            CreateLog "INFO: File: " & delFile & " was deleted successfully."
		End If	
    Else
        CreateLog "INFO: File: " & delFile & " does not exist."
	End If 
End Function
    
'Delete folder if empty
Function DeleteFolder(delFolder)
	On Error Resume Next
	Dim objFolder
	If objFSO.FolderExists(delFolder) Then
		Set objFolder = objFSO.GetFolder(delFolder)
		If objFolder.Files.Count = 0 AND objFolder.SubFolders.Count = 0 Then
			Err.Clear
			objFSO.DeleteFolder(delFolder)
            If Err.number <> 0 Then 
				CreateLog "INFO: Folder " & delFolder & " was not deleted."
			Else
                CreateLog "INFO: Folder " & delFolder & " was deleted successfully."
			End If	
		Else
			CreateLog "INFO: Folder " & delFolder & " is not empty and was not deleted."
		End If
	Else
        CreateLog "INFO: Folder " & delFolder & " does not exist."
	End If 
End Function 