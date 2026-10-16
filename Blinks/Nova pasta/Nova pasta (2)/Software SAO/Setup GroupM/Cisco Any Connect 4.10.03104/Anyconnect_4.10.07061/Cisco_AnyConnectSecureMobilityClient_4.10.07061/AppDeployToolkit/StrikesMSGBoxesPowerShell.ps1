

$HTAPath = "$PSScriptRoot\HTA"

#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function Select-LanguageWindow {
  [CmdletBinding()]
  param (
    [String]$windowFile = "LanguageWindow.hta"
  )

	$LanguagesToUse = $LanguagesToUse.replace(";",",")
	$HTAFile = $windowFile

	$SApp = $HTAPath + "\" + $HTAFile
	$HTACommand = '"' + $LanguagesToUse + '" "' + $AccountNameVar + '" "' + $FriendlyPKGName + '"'

  if (($TmpDeployMode -ne 'NonInteractive') -and ($TmpDeployMode -ne 'Silent')) {
    If ($isForUDP -eq "False") {
      Do { 
        $rVal = Start-Process -FilePath $SApp -ArgumentList $HTACommand -ErrorAction 'SilentlyContinue' -Wait
      } while($rVal -eq 0) 
    } else {
      Do { 
        Send-UDPData -data "$env:computername|languagewindow|start|$HTACommand"
        $rVal = Get-UDPData
      } while($rVal -eq 0) 
    }
  }
	
	Return $rVal
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

  
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function Show-ProcessWindowHTA {
	[CmdletBinding()]
	param (
		[String]$HTASFile = "Processes.hta",
		[String]$HTAPersist = "ProcessesPersistent.hta",
    $IsPersistent = $StrikeWindowIsPersistent,
    $IsInstall = $ThisInstall
	)

  if ($ProcessWindowType -eq 2) { $HTASFile = "ProcessesType2.hta" }

  If ($IsPersistent -eq "True") { $HTAFile = $HTAPersist } 
  Else { $HTAFile = $HTASFile }

	If (($FriendlyPKGName -eq "") -OR ($FriendlyPKGName -eq "FriendlyPKGName")) { $FriendlyPKGName = $PKGName }
	If (($FriendlyProcessName -eq "") -OR ($FriendlyProcessName -eq "FriendlyProcessName")) { $FriendlyProcessName = $ProcessesToKill }

	If ($IsInstall -eq $True) {
		$HTAText = "install"
		$IsRebootRequired = $IsInstallRebootRequired
		$ProcessesToKill = $killProcessesInstall
  } Else {
		$HTAText = "uninstall"
		$IsRebootRequired = $IsUninstallRebootRequired
		$ProcessesToKill = $killProcessesUninstall
	}

  if ($ProcessesToKill -eq 'False') { $ProcessesToKill = $FriendlyPKGName }

  $SApp = $HTAPath + "\" + $HTAFile

	$HTACommand = 'Time="'+$TimeVar+'" AccountName="'+$AccountNameVar+'" FriendlyName="'+$FriendlyPKGName+'" ProcessName="'+$FriendlyProcessName+'" IsProcessSentenceInRed="'+$IsProcessSentenceInRed+'" IsNetworkDisconnect="'+$IsNetworkDisconnect+'" IsRebootRequired="'+$IsRebootRequired+'" Procedure="'+$HTAText+'" killProcess="'+$ProcessesToKill+'"'

	If (((Get-IsProcessRunning -processes $ProcessesToKill) -eq 1) -AND ($IsKillingWindowAlwaysON -eq "False")) { $rVal = 0 } 
  Else {
		If ($isForUDP -eq "False") {
			Do {
				$rVal = Start-Process -FilePath $SApp -ArgumentList $HTACommand -ErrorAction 'SilentlyContinue' -Wait

				If ($IsPersistent -eq "True") {
					If ((Get-IsProcessRunning -processes $ProcessesToKill) -eq 1) { $rVal = 0 <#Set-ProgressBar#> } 
          ElseIf ((Get-TimerCheck -fromDate $FromDateH -toDate $Now) -gt 11) { Exit-Script -ExitCode $Global:Const_RetryInstallEC } 
          Else { $rVal = 0 }
				}
			} while($rVal -eq 0)
		} else {
      if (($TmpDeployMode -ne 'NonInteractive') -and ($TmpDeployMode -ne 'Silent')) {
        Write-Host "---------------------------------------------------------"
        Write-Host "---------------------------------------------------------"
        Write-Host 'Time="'$TimeVar'" AccountName="'$AccountNameVar'" FriendlyName="'$FriendlyPKGName'" ProcessName="'$FriendlyProcessName'" IsProcessSentenceInRed="'$IsProcessSentenceInRed'" IsNetworkDisconnect="'$IsNetworkDisconnect'" IsRebootRequired="'$IsRebootRequired'" Procedure="'$HTAText'"'
        Write-Host "$env:computername|processwindow|start|$HTACommand|$ProcessesToKill|$IsKillingWindowAlwaysON|$IsForceKillingVar|$HTAFile"
        Write-Host "---------------------------------------------------------"
        Write-Host "---------------------------------------------------------"
        Do { 
          Send-UDPData -data "$env:computername|processwindow|start|$HTACommand|$ProcessesToKill|$IsKillingWindowAlwaysON|$IsForceKillingVar|$HTAFile"
          $rVal = Get-UDPData
        } while($rVal -eq 0) 
      }
		}
    #Set-ProgressBar
		If ($IsForceKillingVar -eq $True) { $rVal = Set-KillProcesses($ProcessesToKill) }
  }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function Show-CompletionDialogHTA { 
	[CmdletBinding()]
	param (
		[ValidateSet("SUCCESS", "SUCCESS REBOOT", "FAILURE")]
		[String]$Mode,
		[String]$HTAFile = "CompletionDialog.hta"
	)

	#If (($IsFailFinalizeMsg -eq $True) -and ($Mode -eq "FAILURE")) -or (($IsSuccessFinalizeMsg -eq $True) -and ($Mode -eq "SUCCESS")) -or ((($IsInstallRebootRequired -eq $True) -or ($IsUninstallRebootRequired -eq $True)) -and ($Mode -eq "SUCCESS REBOOT")){
		If (($FriendlyPKGName -eq "") -OR ($FriendlyPKGName -eq "FriendlyPKGName")) { $FriendlyPKGName = $PKGName }

		If ($deploymentType -ine 'Uninstall') { $HTAText = "install" } 
		Else { $HTAText = "uninstall" }

		$SApp = $HTAPath + "\" + $HTAFile
		$HTACommand =	'Time="120" AccountName="' + $AccountNameVar + '" FriendlyName="' + $FriendlyPKGName + '" Procedure="' + $HTAText + '" Status="' + $Mode.ToUpper() + '"'
    
    if (($TmpDeployMode -ne 'NonInteractive') -and ($TmpDeployMode -ne 'Silent')) {
      If ($isForUDP -eq "False") {
        Write-Log -Message "Executing HTA command: $HTACommand" -Source $deployAppScriptFriendlyName
        Start-Process -FilePath $SApp -ArgumentList $HTACommand -ErrorAction 'SilentlyContinue'
      } else {
        Send-UDPData -data "$env:computername|completiondialog|start|$HTACommand|$deploymentType"
      }
    }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function Show-FthStrikeWindowHTA {
  [CmdletBinding()]
  param (
    [String]$windowFile = "5thStrikeWindow.hta"
  )

	If ($envOSArchitecture -eq "64-bit") { 
		$strBitness = "\Wow6432Node"
		$strVarBit = "64"
    } Else {
		$strBitness = ""
		$strVarBit = "32"
  }

  $strRegStrikePath = "HKEY_LOCAL_MACHINE\SOFTWARE" + $strBitness + "\IBM\Packages\" + $PKGName
	$strRegStrikeCountPath = $strRegStrikePath + "\strikecount"
	$strRegTimer = $PKGName

	If (Test-RegistryValue -Key $strRegStrikePath -Value 'strikecount') {
		$strikesNumberREG = Get-RegistryKey -Key $strRegStrikePath -Value 'strikecount'
  } Else { 
		$strikesNumberREG = 0
		$rVal = Set-RegistryKey -Key $strRegStrikePath -Name 'strikecount' -Type 'String' -Value '0'
  }

	$strikesNumber = $Global:HowManyStrikesVar - $strikesNumberREG
	$timerVar = $TimeVar*60

	$rebootWarning = $blnRebootNeeded
	$logoffWarning = $blnLogOffNeeded

    if (($TmpDeployMode -ne 'NonInteractive') -and ($TmpDeployMode -ne 'Silent')) {
    If ($strikesNumber -eq 0) {
      $windowType = 7 
      Write-Log -Message "FUNCTION INFO: last 5th strike window." -Source $deployAppScriptFriendlyName
      $timerVar = "600"
    } Else {
      If ($ProcessesToKill -ne "") {
        $rVal = (Get-IsProcessRunning -processes $ProcessesToKill)
            
        If ($rebootWarning -eq "True") { 
          If ($rVal -eq 0) {
            $windowType = 4
            Write-Log -Message "FUNCTION INFO: standard 5th strike with reboot info and with process info." -Source $deployAppScriptFriendlyName
          } Else {
            $windowType = 3
                Write-Log -Message "FUNCTION INFO: standard 5th strike with reboot info." -Source $deployAppScriptFriendlyName
          }
        } ElseIf ($logoffWarning -eq "True") {
          If ($rVal -eq 0) {
            $windowType = 6
            Write-Log -Message "FUNCTION INFO: standard 5th strike with log off info and with process info." -Source $deployAppScriptFriendlyName
          } Else { 
            $windowType = 5
            Write-Log -Message "FUNCTION INFO: standard 5th strike with log off." -Source $deployAppScriptFriendlyName
          }
        } Else {
          If ($rVal -eq 0) {
            $windowType = 2
            Write-Log -Message "FUNCTION INFO: standard 5th strike with process info." -Source $deployAppScriptFriendlyName
          } Else { 
            $windowType = 1
            Write-Log -Message "FUNCTION INFO: standard 5th strike." -Source $deployAppScriptFriendlyName
          }
        }
      } Else {
        If ($rebootWarning -eq "True") { 
          $windowType = 3 
          Write-Log -Message "FUNCTION INFO: standard 5th strike with reboot info." -Source $deployAppScriptFriendlyName
        } ElseIf ($logoffWarning -eq "True") {
          $windowType = 5
          Write-Log -Message "FUNCTION INFO: standard 5th strike with log off." -Source $deployAppScriptFriendlyName
        } Else {
          $windowType = 1 
          Write-Log -Message "FUNCTION INFO: standard 5th strike." -Source $deployAppScriptFriendlyName
        }
      }
    }

      $regTimePath = "HKEY_LOCAL_MACHINE\SOFTWARE" + $strBitness + "\IBM\Packages\" + $strRegTimer
      Set-RegistryKey -Key $regTimePath -Name 'remaningTime' -Type 'String' -Value $timerVar

    Do {
      $strTmpValue = Get-RegistryKey -Key $regTimePath -Value 'remaningTime'
          
      if (($timerVar -lt $strTmpValue) -OR [string]::IsNullOrEmpty($strTmpValue)) {
        if ($windowType -eq 7) {
          $timerVar = "600"
        } Else { 
          $timerVar = $TimeVar*60
        }
      } Else { $timerVar = $strTmpValue }

      $SApp = $HTAPath + "\" + $windowFile
      $strCommandHTA = '"' + $AccountNameVar + '" "' + $FriendlyPKGName + '" "' + $AppVersion + '" "' + $strikesNumber + '" "' + $windowType + '" "' + $FriendlyProcessName + '" "' + $timerVar + '" "' + $strRegTimer + '" "' + $strVarBit + '"'

      Write-Log -Message "FUNCTION INFO:  starting: $strCommandHTA ." -Source $deployAppScriptFriendlyName
      $rVal = Start-Process -FilePath $SApp -ArgumentList $strCommandHTA -ErrorAction 'SilentlyContinue' -Wait

      If ($rVal -eq -11) {
        Write-Log -Message "FUNCTION INFO: ending FthStrikeWindowHTA, RC: $rVal ." -Source $deployAppScriptFriendlyName			
        If (Test-RegistryValue -Key $strRegStrikePath -Value 'strikecount') {
          $strikesNumberREG =  Get-RegistryKey -Key $strRegStrikePath -Value 'strikecount'
          $newCount = $strikesNumberREG + 1
          Set-RegistryKey -Key $strRegStrikePath -Name 'strikecount' -Type 'String' -Value $newCount
        }

        Remove-RegistryKey -Key $regTimePath + "remaningTime"
        Return $rVal
      } ElseIf ($rVal -ne 0) {
        Write-Log -Message "FUNCTION INFO: ending FthStrikeWindowHTA, RC: $rVal." -Source $deployAppScriptFriendlyName		
        Remove-RegistryKey -Key $regTimePath + "remaningTime"
        Return $rVal
      }
    } while(($rVal -eq 0) -or ((Get-RegistryKey -Key $regTimePath -Value 'remaningTime') -ne 0))       
  }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function Clean-FthStrikeHTA { # Cleans 5th strike registry after installation.
  [CmdletBinding()]
  param ()

  If ($envOSArchitecture -eq "64-bit") { $remKey = "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\IBM\Packages\" + $PKGName + "\" } 
  Else { $remKey = "HKEY_LOCAL_MACHINE\SOFTWARE\IBM\Packages\" + $PKGName + "\" }

  Remove-RegistryKey -Key $remKey + "remaningTime" -Recurse
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function Check-Timer { # Compares start and end time provided as parameters
  [CmdletBinding()]
  param (
    [String]$fromDate,
    [String]$toDate
  )

    $VTime = Get-TimerCheck fromDate $fromDate toDate $toDate
    Return $VTime
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function PopUp-Windows {
# Simple information window, can be configured in many ways to catch specific input from users.
#
# @param  Time             Receives an integer containing the number of seconds that the box will display for until dismissed. If zero or omitted, the message box stays until the user dismisses it. Default value: 0
# @param  Title            Receives a string containing the title that will appear as the title of the message box. Default value - empty string
# @param  Message          Receives a string containing the message that will be displayed to the user in the message box. Default value- empty string
# @param  Button           Receives an integer that corresponds to displayed buttons, Default value - 0 Values that can be used: 0 (OK), 1 (OK, Cancel), 2 (Abort, Ignore, Retry), 3 (Yes, No, Cancel), 4 (Yes, No), 5 (Retry, Cancel)
# @param  Icon             Receives an integer that corresponds to a look. Default value - NULL. Values that can be used: 16 (Critical), 32 (Question), 48 (Exclamation), 64 (Information)
#
# @return Return the button which the user clicked to dismiss the pop-up message box. ReturnValue: 1 (OK), 2 (Cancel), 3 (Abort), 4 (Retry), 5 (Ignore), 6 (Yes), 7 (No), -1 (None, message box was dismissed automatically (timeout))        
  [CmdletBinding()]
  param (
    [String]$Time,
    [String]$Title,
    [String]$Message,
    [String]$Button,
    [String]$Icon
  )

  if (($TmpDeployMode -ne 'NonInteractive') -and ($TmpDeployMode -ne 'Silent')) {
    if ($SilentInstall -eq $false) {
      $ButtonSelect = $False
			$IconSelect = $False

      If (($Button -eq 0) -or ($Button -eq 1) -or ($Button -eq 2) -or ($Button -eq 3) -or ($Button -eq 4) -or ($Button -eq 5)) { $ButtonSelect = $True } 
      Else {
				$ButtonSelect = $False
				If ([string]::IsNullOrEmpty($Button) -or ($Button -ne "")) { Write-Log -Message "FUNCTION INFO: variable Button is wrong." -Source $deployAppScriptFriendlyName }
      }
      If (($Icon -eq 16) -or ($Icon -eq 32) -or ($Icon -eq 48) -or ($Icon -eq 64)) { $IconSelect = $True } 
      Else {
				$IconSelect = $False
				If ([string]::IsNullOrEmpty($Icon) -or ($Icon -ne "")) { Write-Log -Message "FUNCTION INFO: variable Icon is wrong." -Source $deployAppScriptFriendlyName }
      }

      $wshell = New-Object -ComObject Wscript.Shell

      If (($IconSelect -eq $True) -And ($ButtonSelect -eq $True)) { $ShowMessage = $wshell.Popup($Message,$Time,$Title,$Button + $Icon)	} 
      Elseif ($IconSelect -eq $True) { $ShowMessage = $wshell.Popup($Message,$Time,$Title,$Icon) } 
      Elseif ($ButtonSelect -eq $True) { $ShowMessage = $wshell.Popup($Message,$Time,$Title,$Button) } 
      Else { $ShowMessage = $wshell.Popup($Message,$Time,$Title) }
      
      Write-Log -Message "FUNCTION INFO: Display Message." -Source $deployAppScriptFriendlyName
			
      If ($ShowMessage -eq 1) {	Write-Log -Message "FUNCTION INFO: The user has chosen the OK button." -Source $deployAppScriptFriendlyName } 
      Elseif ($ShowMessage -eq 2) { Write-Log -Message "FUNCTION INFO: The user has chosen the Cancel button." -Source $deployAppScriptFriendlyName } 
      Elseif ($ShowMessage -eq 3) {	Write-Log -Message "FUNCTION INFO: The user has chosen the Abort button." -Source $deployAppScriptFriendlyName } 
      Elseif ($ShowMessage -eq 4) {	Write-Log -Message "FUNCTION INFO: The user has chosen the Retry button." -Source $deployAppScriptFriendlyName } 
      Elseif ($ShowMessage -eq 5) {	Write-Log -Message "FUNCTION INFO: The user has chosen the Ignore button." -Source $deployAppScriptFriendlyName } 
      Elseif ($ShowMessage -eq 6) {	Write-Log -Message "FUNCTION INFO: The user has chosen the Yes button." -Source $deployAppScriptFriendlyName } 
      Elseif ($ShowMessage -eq 7) {	Write-Log -Message "FUNCTION INFO: The user has chosen the No button." -Source $deployAppScriptFriendlyName } 
      Elseif ($ShowMessage -eq -1) {	Write-Log -Message "FUNCTION INFO: The time for a user response has been expired." -Source $deployAppScriptFriendlyName } 

			Return ShowMessage
    } Else 	{
      Write-Log -Message "FUNCTION INFO: ending PopupWindows - silent installation." -Source $deployAppScriptFriendlyName
			Return 0
    }
  }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function Show-ProcessesWindow {
# N-strike window.
#
# @param  HowManyStrikes   Receives an integer containing the number of strikes. Default value: 3 - it means that client can choose to postpone installation a maximum of 2 times. 
# @param  AccountName      Receives a string containing the account name which will be displayed in message: "AcountName IT is attempting to install...."
# @param  Title            Receives a string containing the title that will appear as the title of the message box. Default value - empty string
# @param  TimeTmp          Receives an integer containing the number of seconds that the box will display for until dismissed. If zero or omitted, the message box stays until the user dismisses it. Default value: 0
# @param  WhatInstalls     Receives a string containing the name of application which will be displayed in the message. It could be Friendly names. Default value: PKGname
# @param  IsForceKilling   Receives a value: True or False. Default value: False. True - should be display message about killing process. False - should not display message about kill process.
# @param  ProcessesToCloseVar   Receives a string containing the name of application which will be killed during installation. It should be friendly message. example: "Internet Browser and Java"
# @param  IsRestartMessage      Receives a value: True or False. Default value: False. True - should be display message that reboot will be required. False - should not display message about reboot. Reboot is not required. 
#
# @return ReturnValue: 0 (The installation could be started), -1000 (Installation postponed)   
  [CmdletBinding()]
  param (
      [String]$HowManyStrikes,
      [String]$AccountName,
      [String]$Title,
      [String]$TimeTmp,
      [String]$WhatInstalls,
      [String]$IsForceKilling,
      [String]$ProcessesToCloseVar,
      [String]$IsRestartMessage
  )

      $returnCode = 1603
			$StrikeRC = -1000

          if ($WhatInstalls -eq "FriendlyPKGName") {
            Write-Log -Message "FUNCTION INFO: variable WhatInstalls is string FriendlyPKGName. Setting to FriendlyPKGName." -Source $deployAppScriptFriendlyName
						$WhatInstalls = $FriendlyPKGName
          } Elseif ($WhatInstalls -eq "PKGName") {
            Write-Log -Message "FUNCTION INFO: variable WhatInstalls is string PKGName. Setting to PKGname." -Source $deployAppScriptFriendlyName
						$WhatInstalls = $PKGName
          }

			If ((-Not(($IsForceKilling -eq $True)) -or ($IsForceKilling -eq $False))) {
        Write-Log -Message "FUNCTION INFO: variable IsForceKilling is wrong. Setting to False." -Source $deployAppScriptFriendlyName
				$IsForceKilling = $False 
      }

			If ((-Not($IsRestartMessage -eq "True")) -or ($IsRestartMessage -eq "False")) {
        Write-Log -Message "FUNCTION INFO: variable IsRestartMessage is wrong. Setting to False." -Source $deployAppScriptFriendlyName
				$IsRestartMessage = $False 
			}

      $reminingTime = $TimeTmp/60
			$Number_Postponed = @("once","twice","three times","four times","five times","six times","seven times","eight times","nine times","ten times")

      If ($G_MessageInstallOptional1 -ne "N/A" -AND (-not ([string]::IsNullOrEmpty($G_MessageInstallOptional1)))) {
        $MessageInstallOptional1 = $G_MessageInstallOptional1

        If ((Get-InstResult -testString $MessageInstallOptional1 -testValue "<AccountName>") -eq 0) { $MessageInstallOptional1 = $MessageInstallOptional1.replace("<AccountName>",$AccountName) }
        If ((Get-InstResult -testString $MessageInstallOptional1 -testValue "<FriendlyPKGName>") -eq 0) { $MessageInstallOptional1 = $MessageInstallOptional1.replace("<FriendlyPKGName>",$FriendlyPKGName) }
        If ((Get-InstResult -testString $MessageInstallOptional1 -testValue "<instTime>") -eq 0) { $MessageInstallOptional1 = $MessageInstallOptional1.replace("<instTime>",$InstallationTime) }
      } Else { $MessageInstallOptional1	= $AccountName + " IT is attempting to install the " + $WhatInstalls + " application." }

      If ($G_MessageInstallOptional2 -ne "N/A" -AND (-not ([string]::IsNullOrEmpty($MessageInstallOptional2)))) {
        $MessageInstallOptional2 = $G_MessageInstallOptional2

        If ((Get-InstResult -testString $MessageInstallOptional2 -testValue "<FriendlyProcessName>") -eq 0) { $MessageInstallOptional2 = $MessageInstallOptional2.replace("<FriendlyProcessName>",$FriendlyProcessName) }
      } Else { $MessageInstallOptional2 = "Please close all " + $ProcessesToCloseVar + " windows, saving any work." }

      If ($G_MessageInstallOptional3 -ne "N/A" -AND (-not ([string]::IsNullOrEmpty($G_MessageInstallOptional3)))) {
        $MessageInstallOptional3 = $G_MessageInstallOptional3

      If ((Get-InstResult -testString $MessageInstallOptional3 -testValue "<FriendlyProcessName>") -eq 0) { $MessageInstallOptional3 = $MessageInstallOptional3.replace("<FriendlyProcessName>",$FriendlyProcessName) }
      } Else { $MessageInstallOptional3	= "When you click OK, any remaining " + $ProcessesToCloseVar + " sessions will be closed automatically." }

      If ($G_MessageInstallOptional4 -ne "N/A" -AND (-not ([string]::IsNullOrEmpty($G_MessageInstallOptional4)))) {
        $MessageInstallOptional4 = $G_MessageInstallOptional4

        If ((Get-InstResult -testString $MessageInstallOptional4 -testValue "<reminingTime>") -eq 0) { $MessageInstallOptional4 = $MessageInstallOptional4.replace("<reminingTime>",$reminingTime) }
      } Else { $MessageInstallOptional4	= "You can choose to postpone this installation a maximum of " + $HowManyStrikes-1 + " times, after which it will be become mandatory. You currently have " }

      If ($G_MessageInstallOptional5 -ne "N/A" -AND (-not ([string]::IsNullOrEmpty($G_MessageInstallOptional5)))) { $MessageInstallOptional5 = $G_MessageInstallOptional5 } 
      Else { $MessageInstallOptional5	= " remaining opportunities to postpone." }

      If ($G_MessageInstallOptional6 -ne "N/A" -AND (-not ([string]::IsNullOrEmpty($G_MessageInstallOptional6)))) { $MessageInstallOptional6 = $G_MessageInstallOptional6 } 
      Else { $MessageInstallOptional6	= "Please click OK to proceed with the installation, or CANCEL to postpone the installation at this time." }

      If ($G_MessageInstallOptional7 -ne "N/A" -AND (-not ([string]::IsNullOrEmpty($G_MessageInstallOptional7)))) { $MessageInstallOptional7 = $G_MessageInstallOptional7 }

      If ($G_MessageInstallOptional8 -ne "N/A" -AND (-not ([string]::IsNullOrEmpty($G_MessageInstallOptional8)))) { $MessageInstallOptional8 = $G_MessageInstallOptional8 }

			If ($G_MessageInstallRequired1 -ne "N/A" -AND (-not ([string]::IsNullOrEmpty($G_MessageInstallRequired1)))) {
        $MessageInstallRequired1 = $G_MessageInstallRequired1
        If ((Get-InstResult -testString $MessageInstallRequired1 -testValue "<AccountName>") -eq 0) { $MessageInstallRequired1 = $MessageInstallRequired1.replace("<AccountName>",$AccountName) }
        If ((Get-InstResult -testString $MessageInstallRequired1 -testValue "<FriendlyPKGName>") -eq 0) { $MessageInstallRequired1 = $MessageInstallRequired1.replace("<FriendlyPKGName>",$FriendlyPKGName) }
        If ((Get-InstResult -testString $MessageInstallRequired1 -testValue "<instTime>") -eq 0) { $MessageInstallRequired1 = $MessageInstallRequired1.replace("<instTime>",$InstallationTime) }
      } Else { $MessageInstallRequired1	= $AccountName + " IT is attempting to install the " + $WhatInstalls + " application." }

      If ($G_MessageInstallRequired2 -ne "N/A" -AND (-not ([string]::IsNullOrEmpty($G_MessageInstallRequired2)))) {
        $MessageInstallRequired2 = $G_MessageInstallRequired2
        If ((Get-InstResult -testString $MessageInstallRequired2 -testValue "<FriendlyProcessName>") -eq 0) { $MessageInstallRequired2 = $MessageInstallRequired1.replace("<instTime>",$InstallationTime) }
      } Else { $MessageInstallRequired2 = "Please close all " + $ProcessesToCloseVar + " windows, saving any work." }

      If ($G_MessageInstallRequired3 -ne "N/A" -AND (-not ([string]::IsNullOrEmpty($G_MessageInstallRequired3)))) {
        $MessageInstallRequired3 = $G_MessageInstallRequired3
        If ((Get-InstResult -testString $MessageInstallRequired3 -testValue "<FriendlyProcessName>") -eq 0) { $MessageInstallRequired3 = $MessageInstallRequired3.replace("<FriendlyProcessName>",$FriendlyProcessName) }
      } Else { $MessageInstallRequired3 = "When you click OK, any remaining " + $ProcessesToCloseVar + " sessions will be closed automatically." }

      If ($G_MessageInstallRequired4 -ne "N/A" -AND (-not ([string]::IsNullOrEmpty($G_MessageInstallRequired4)))) {
        $MessageInstallRequired4 = $G_MessageInstallRequired4
        If ((Get-InstResult -testString $MessageInstallRequired4 -testValue "<Number_Postponed((HowManyStrikes-2))>") -eq 0) { $MessageInstallRequired4 = $MessageInstallRequired4.replace("<Number_Postponed((HowManyStrikes-2))>",$HowManyStrikes-1) }
      } Else { 
        $tmpNPost = Get-NumberPostponed -number $HowManyStrikes-2
        $MessageInstallRequired4 = "The installation is now mandatory, as it has already been postponed " + $tmpNPost + "." 
      }

      If ($G_MessageInstallRequired5 -ne "N/A" -AND (-not ([string]::IsNullOrEmpty($G_MessageInstallRequired5)))) { $MessageInstallRequired5 = $G_MessageInstallRequired5
      } Else { $MessageInstallRequired5 = "Please click OK to proceed with the installation at this time." }

      If ($G_MessageInstallRequired6 -ne "N/A" -AND (-not ([string]::IsNullOrEmpty($G_MessageInstallRequired6)))) { $MessageInstallRequired6 = $G_MessageInstallRequired6 }
      If ($G_MessageInstallRequired7 -ne "N/A" -AND (-not ([string]::IsNullOrEmpty($G_MessageInstallRequired7)))) { $MessageInstallRequired7 = $G_MessageInstallRequired7 }

			If ($G_MessageInstallIfRebootRequired -ne "N/A" -AND (-not ([string]::IsNullOrEmpty($G_MessageInstallIfRebootRequired)))) { $MessageInstallIfRebootRequired = $G_MessageInstallIfRebootRequired
      } Else { $MessageInstallIfRebootRequired = "It will be necessary to restart your machine following this installation." }          

			If ($envOSArchitecture -eq "64-bit") {
				$strKeyPath		  = "SOFTWARE\Wow6432Node\IBM\Packages\"
				$strKeyPath1		= "HKLM\SOFTWARE\Wow6432Node\IBM\Packages\" + $PKGname
				$strKeyPath2		= $strKeyPath1 + "\StrikeCount"
			} Else {
				$strKeyPath		  = "SOFTWARE\IBM\Packages\"
				$strKeyPath1		= "HKLM\SOFTWARE\IBM\Packages\" + $PKGname
				$strKeyPath2		= $strKeyPath1 + "\StrikeCount"
			}

        If (-not (Test-RegistryValue -Key $strKeyPath1 -Value 'StrikeCount')) {
					$value = 0
          Set-RegistryKey -Key $strKeyPath1 -Name 'StrikeCount' -Type 'String' -Value $value
          Write-Log -Message "FUNCTION INFO: The Three Strike registry: HKEY_LOCAL_MACHINE\ $strKeyPath $PKGname \StrikeCount has been added with value: $value." -Source $deployAppScriptFriendlyName
        } else { $value = Get-RegistryKey -Key $strKeyPath1 -Value 'StrikeCount' }
	
	
			If ($value -eq ($HowManyStrikes-1)) {
        $DisplayMessage = $MessageInstallRequired1
        
				If (($IsForceKilling -eq "True") -AND (-NOT ($ProcessesToCloseVar -eq ""))) { $DisplayMessage = $DisplayMessage + '"' + $MessageInstallRequired2 + [Environment]::NewLine + [Environment]::NewLine + $MessageInstallRequired3 }
        $DisplayMessage = $DisplayMessage + [Environment]::NewLine + [Environment]::NewLine + $MessageInstallRequired4
				If ($IsRestartMessage -eq "True") { $DisplayMessage = $DisplayMessage + [Environment]::NewLine + [Environment]::NewLine + $MessageInstallIfRebootRequired }
				$DisplayMessage = $DisplayMessage + [Environment]::NewLine + [Environment]::NewLine + $MessageInstallRequired5
      
        $wshell = New-Object -ComObject Wscript.Shell
        $InstallMessage = $wshell.Popup($DisplayMessage,$TimeTmp,$Title,0 + 48)
			
        If ($InstallMessage -eq -1) { Write-Log -Message "FUNCTION INFO: The time for a user response has been expired. The installation could be started." -Source $deployAppScriptFriendlyName } 
        Elseif ($InstallMessage -eq 1) { Write-Log -Message "FUNCTION INFO: The user has chosen the OK button. The installation could be started." -Source $deployAppScriptFriendlyName } 
        Else { Write-Log -Message "FUNCTION INFO: The user closed the msgbox button. The installation could be started." -Source $deployAppScriptFriendlyName }
        Write-Log -Message "FUNCTION INFO: Installation can be started." -Source $deployAppScriptFriendlyName
				$returnCode = 0 
			} Else {
				$Cancel_Info = (($HowManyStrikes-1)-$value)
        $DisplayMessage = $MessageInstallOptional1 
        
				If (($IsForceKilling -eq "True") -AND (-NOT ($ProcessesToCloseVar -eq ""))) { $DisplayMessage = $DisplayMessage + ' ' + $MessageInstallOptional2 + [Environment]::NewLine + [Environment]::NewLine + $MessageInstallOptional3 }
				$DisplayMessage = $DisplayMessage + [Environment]::NewLine + [Environment]::NewLine  + $MessageInstallOptional4 + ' ' + $Cancel_Info + ' ' + $MessageInstallOptional5 + [Environment]::NewLine + [Environment]::NewLine
				If ($IsRestartMessage -eq "True") { $DisplayMessage = $DisplayMessage + $MessageInstallIfRebootRequired + [Environment]::NewLine + [Environment]::NewLine } 
				$DisplayMessage = $DisplayMessage + $MessageInstallOptional6 
				
          $wshell = New-Object -ComObject Wscript.Shell
          $InstallMessage = $wshell.Popup($DisplayMessage,$TimeTmp,$Title,1 + 48)	
			
				If ($InstallMessage -eq 1) {
            Write-Log -Message "FUNCTION INFO: The user has chosen the OK button. The installation could be started." -Source $deployAppScriptFriendlyName
            Write-Log -Message "FUNCTION INFO: Installation can be started." -Source $deployAppScriptFriendlyName
						$returnCode = 0 
        } Elseif ($InstallMessage -eq -1) {
            $value = $value + 1
            Set-RegistryKey -Key $strKeyPath1 -Name 'StrikeCount' -Type 'String' -Value $value
            Write-Log -Message "FUNCTION INFO: The time for a user response has been expired. The new value count is now: $value ." -Source $deployAppScriptFriendlyName
            Write-Log -Message "FUNCTION INFO: Installation can be started." -Source $deployAppScriptFriendlyName
						$returnCode = $StrikeRC
          } Else {
						$value = $value + 1
            Set-RegistryKey -Key $strKeyPath1 -Name 'StrikeCount' -Type 'String' -Value $value
            Write-Log -Message "FUNCTION INFO: The user closed the msgbox button or choose the Cancel option. The new value count is now: $value ." -Source $deployAppScriptFriendlyName
            Write-Log -Message "FUNCTION INFO: Installation cannot be started." -Source $deployAppScriptFriendlyName
						$returnCode = $StrikeRC
				} 
      }
      Write-Log -Message "FUNCTION INFO: ending ProcessesWindow." -Source $deployAppScriptFriendlyName
			Return $returnCode
      Write-Log -Message "FUNCTION INFO: going to ProgressBarSet." -Source $deployAppScriptFriendlyName

      If (-Not ($returnCode -eq -1000)) { ProgressBarSet } 
      Else { 	
				Write-Log -Message "FUNCTION INFO: ending ProcessesWindow - silent installation." -Source $deployAppScriptFriendlyName
				Return 0
			}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function Clean-ProcessesWindowReg { # Cleans registry from n-strike window counter
  [CmdletBinding()]
  param (
      [String]$PKGNameV
  )		
		
	If ($envOSArchitecture -eq "64-bit") { $strKeyPath	= "HKLM\SOFTWARE\Wow6432Node\IBM\" } 
	Else { $strKeyPath	= "HKLM\SOFTWARE\IBM\" }

  $strRegPath = $strKeyPath + "Packages\" + $PKGnameV
  $strRegCountPath = $strRegPath + "\strikecount"

  If (-not (Test-RegistryValue -Key $strRegCountPath -Value 'strikecount')) {
    Write-Log -Message "FUNCTION INFO: The Three Strike registry: $strKeyPath Packages\$PKGnameV\StrikeCount not present. Exiting." -Source $deployAppScriptFriendlyName
		Return 0
  } 

	if (Test-RegistryValue -Key $strRegCountPath -Value 'strikecount') { Remove-RegistryKey -Key $strRegCountPath -Recurse }
	Return 0
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function Get-InstResult {
  # Cleans registry from n-strike window counter
  [CmdletBinding()]
  param (
    [String]$testString,
    [String]$testValue
  )

  If (($testString -like $testValue) -or ($testString -like "*$testValue") -or ($testString -like "$testValue*") -or ($testString -like "*$testValue*")) { Return 0 } 
  Else { Return 1 }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function Get-IsProcessRunning {
  # Cleans registry from n-strike window counter
  [CmdletBinding()]
  param (
      [String]$processes
  )

  $procRunning = 1

  $allProcesses = Get-Process
  $procToCheck = $processes.Split(";")

	Write-Log -Message "FUNCTION INFO: processes to check: $processes ." -Source $deployAppScriptFriendlyName
	Write-Log -Message "FUNCTION INFO: processes to check against: $allProcesses ." -Source $deployAppScriptFriendlyName

  ForEach ($process in $procToCheck) {
    ForEach ($proc in $allProcesses) {
      if (($proc.Name -like "$process") -or ($proc.Name -like "*$process") -or ($proc.Name -like "*$process*") -or ($proc.Name -like "$process*")) { $procRunning = 0 }
    }
  }

  Return $procRunning
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function Get-TimerCheck {
  # Cleans registry from n-strike window counter
  [CmdletBinding()]
  param (
    [String]$fromDate,
    [String]$toDate
  )

  $VTime = $fromDate - $toDate

  Return $VTime
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function Get-NumberPostponed {
  # Cleans registry from n-strike window counter
  [CmdletBinding()]
  param (
    [String]$number
  )

}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function Set-KillProcesses {
  [CmdletBinding()]
  param (
    [String]$ProcessesToKill
  )
  
  $procToKill = $ProcessesToKill.Split(";")
  ForEach ($process in $procToKill) { Stop-Process -Name $process -Force -ErrorAction 'SilentlyContinue' }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function Set-InfoWindow {
	[CmdletBinding()]
	param (
		[ValidateSet("SUCCESS", "SUCCESS REBOOT", "FAILURE")]
		[String]$Mode,
		[String]$HTAFile = "InfoDialog.hta"
	)

	If (($FriendlyPKGName -eq "") -OR ($FriendlyPKGName -eq "FriendlyPKGName")) { $FriendlyPKGName = $PKGName }

	If ($deploymentType -ine 'Uninstall') { $HTAText = "install" } 
	Else { $HTAText = "uninstall" }

	$SApp = $HTAPath + "\" + $HTAFile
	$HTACommand =	'Time="120" AccountName="' + $AccountNameVar + '" FriendlyName="' + $FriendlyPKGName + '" Procedure="' + $HTAText + '" Status="' + $Mode.ToUpper() + '"'

  Write-Log -Message "Executing HTA command: $HTACommand" -Source $deployAppScriptFriendlyName
  Start-Process -FilePath $SApp -ArgumentList $HTACommand -ErrorAction 'SilentlyContinue'
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

