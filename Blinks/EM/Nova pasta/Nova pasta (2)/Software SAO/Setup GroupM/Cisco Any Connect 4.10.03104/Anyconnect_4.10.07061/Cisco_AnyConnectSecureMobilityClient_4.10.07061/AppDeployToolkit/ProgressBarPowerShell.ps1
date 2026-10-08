
  $PBPath = "$PSScriptRoot\EXE"


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Hide-ProgressBar {
	[CmdletBinding()]
	param (
		[String]$TitleHPB,
		[String]$processName = "ProgressBar.exe"
	)

  $TitleHPB = Set-StringFromVar -VarToCheck $TitleHPB

	$TitleHPB = $TitleHPB.replace("<PKGName>", $Global:PKGName)
	$TitleHPB = $TitleHPB.replace("<installName>", $Global:installName)
	$TitleHPB = $TitleHPB.replace("<FriendlyPKGName>", $Global:FriendlyPKGName)

	If ($isForUDP -eq "False") {
		$Processes = Get-WmiObject win32_process -Filter "name like '$processName'" | Select-Object id, name, commandline 

		Foreach ($process in $Processes) {
			$proc = $process.name
			$cmd = $process.commandline
			   
			if($cmd -like "*$TitleHPB*") {
				$proc = $proc.Split(".")
				$killProc = $proc[0]
				Stop-Process -name $killProc -force
			}
		}
	} else { Send-UDPData -data "$env:computername|progressbar|stop|$TitleHPB" }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Displays EXE progress bar
Function Show-ProgressBar {
  [CmdletBinding()]
  param (
      [String]$TitleSPB,
      [String]$Caption,
      [String]$PBFile = "ProgressBar.exe"
  )

  $TitleSPB = Set-StringFromVar -VarToCheck $TitleSPB
  $Caption = Set-StringFromVar -VarToCheck $Caption

  $TitleSPB = $TitleSPB.replace("<PKGName>", $Global:PKGName)
  $TitleSPB = $TitleSPB.replace("<installName>", $Global:installName)
  $TitleSPB = $TitleSPB.replace("<FriendlyPKGName>", $Global:FriendlyPKGName)

  $Caption = $Caption.replace("<PKGName>", $Global:PKGName)
  $Caption = $Caption.replace("<installName>", $Global:installName)
  $Caption = $Caption.replace("<FriendlyPKGName>", $Global:FriendlyPKGName)
  $Caption = $Caption.replace("<FriendlyProcessName>", $Global:FriendlyProcessName)

	If ($isForUDP -eq "False") {
		$PBArgs	=	" /" + '"' + $Caption + '"' + "/" +	'"' + $AccountNameVar	+ '"' + "/" +	'"' + $TitleSPB + '"' + "/" + '"' + $PBMode + '"'
		$PBApp  = $PBPath + "\" + $PBFile

		Start-Process -FilePath $PBApp -ArgumentList $PBArgs -ErrorAction 'SilentlyContinue'
	} else { 	Send-UDPData -data "$env:computername|progressbar|start|$TitleSPB|$Caption" }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Sets title and text displayed in progress bar
Function Set-ProgressBar {
  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  $defaultProcesses = "ProcessName00,ProcessName01,ProcessName02"

  Write-Log -Message "Will set progress bar." -Source ${CmdletName}

	If ($Global:ThisInstall -eq $True) {
		If ($Global:ProgressBarActive.ToLower() -eq "true") {
			If (($Global:ProcessesToKill -ne "") -and ($Global:ProcessesToKill -ne $defaultProcesses) -and ([string]::IsNullOrWhitespace($Global:ProcessesToKill))) { Show-ProgressBar -TitleSPB $Global:InstallProgressBarTitle -Caption $Global:InstallProgressBarCaption	} 
      Else {	Show-ProgressBar -TitleSPB $Global:InstallProgressBarTitle -Caption $Global:InstallProgressBarCaption	}
		} Else {	Write-Log -Message "This account doesn't display progress bar during package installation." -Severity 1 -Source $deployAppScriptFriendlyName }
  } Else {
		If ($Global:UninstallProgressBarActive.ToLower() -eq "true") {
			If (($Global:ProcessesToKill -ne "") -and ($Global:ProcessesToKill -ne $defaultProcesses) -and ([string]::IsNullOrWhitespace($Global:ProcessesToKill))) { Show-ProgressBar -TitleSPB $Global:UninstallProgressBarTitle -Caption $Global:UninstallProgressBarCaption	} 
      Else { Show-ProgressBar -TitleSPB $Global:UninstallProgressBarTitle -Caption $Global:UninstallProgressBarCaption	}
		} Else { 	Write-Log -Message "This account doesn't display progress bar during package uninstallation." -Severity 1 -Source $deployAppScriptFriendlyName }
  }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Disables/enables simple banner for installed package
Function Set-BannerWindowHTA {
  [CmdletBinding()]
  param (
      [String]$windowFile = "Banner.exe"
  )
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
