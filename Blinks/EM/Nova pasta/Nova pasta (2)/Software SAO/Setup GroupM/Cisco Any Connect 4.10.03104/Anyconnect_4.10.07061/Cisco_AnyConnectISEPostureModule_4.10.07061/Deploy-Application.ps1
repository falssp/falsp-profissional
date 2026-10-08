# Last modified: 2023/02/08 11:20:04

<#
.SYNOPSIS
	This script performs the installation or uninstallation of an application(s).
	# LICENSE #
	PowerShell App Deployment Toolkit - Provides a set of functions to perform common application deployment tasks on Windows. 
	Copyright (C) 2017 - Sean Lillis, Dan Cunningham, Muhammad Mashwani, Aman Motazedian.
	This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details. 
	You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.
.DESCRIPTION
	The script is provided as a template to perform an install or uninstall of an application(s).
	The script either performs an "Install" deployment type or an "Uninstall" deployment type.
	The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.
	The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.
.PARAMETER DeploymentType
	The type of deployment to perform. Default is: Install.
.PARAMETER DeployMode
	Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.
.PARAMETER AllowRebootPassThru
	Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.
.PARAMETER TerminalServerMode
	Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Destkop Session Hosts/Citrix servers.
.PARAMETER DisableLogging
	Disables logging to file for the script. Default is: $false.
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"
.EXAMPLE
    Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"
.NOTES
	Toolkit Exit Code Ranges:
	60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
	69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
	70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1
.LINK
	http://psappdeploytoolkit.com
#>
[CmdletBinding()]
Param (
	[Parameter(Mandatory=$false)]
	[ValidateSet('Install','Uninstall')]
	[string]$DeploymentType = 'Install',
	[Parameter(Mandatory=$false)]
	[ValidateSet('Interactive','Silent','NonInteractive')]
	[string]$DeployMode = 'null',
	[Parameter(Mandatory=$false)]
	[switch]$AllowRebootPassThru = $false,
	[Parameter(Mandatory=$false)]
	[switch]$TerminalServerMode = $false,
	[Parameter(Mandatory=$false)]
	[switch]$DisableLogging = $false,
	[Parameter(Mandatory=$false)]
	[ValidateSet('none','user','machine')]
	[string]$UserContext = 'none',
	[Parameter(Mandatory=$false)]
	[string]$CustomData = 'none',
	[Parameter(Mandatory=$false)]
	[switch]$BypassErrors = $false,
	[Parameter(Mandatory=$false)]
	[switch]$isDebug = $false
)

$Global:UserContextVar = $UserContext
$Global:isDebugScript = $isDebug

If ($UserContext -eq 'user') { $DisableLogging = $true }
if ($BypassErrors) { $ErrorActionPreference = "Continue" }

Try {
	## Set the script execution policy for this process
	Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}

	If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
	[string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

	## Dot source the required App Deploy Toolkit Functions
	. "$scriptDirectory\AppDeployToolkit\AppDeployToolkitCustoms.ps1"
	. "$scriptDirectory\AppDeployToolkit\ProgressBarPowerShell.ps1"
	. "$scriptDirectory\AppDeployToolkit\StrikesMSGBoxesPowerShell.ps1"

	##*===============================================
	##* VARIABLE DECLARATION
	##*===============================================
	## Variables: Application

  [string]$Global:installPhase = 'Initialization'
	[string]$Global:ClientName = Set-ProjSetting -actionName "PROPERTY" -PropertyName 'ClientName'
	[string]$Global:PKGName = Set-ProjSetting -actionName "PROPERTY" -PropertyName 'PKGName'
	[string]$Global:TmpDeployMode = 'null'

	[string]$Global:mainPKGGUID = Set-ProjSetting -actionName "PROPERTY" -PropertyName "PKGGUID"
  [string]$Global:PKGGUID = [string]$Global:mainPKGGUID

	[string]$Global:killProcessesInstall = Set-ProjSetting -actionName "PROPERTY" -PropertyName "killProcessesInstall"
	[string]$Global:killProcessesUninstall = Set-ProjSetting -actionName "PROPERTY" -PropertyName "killProcessesUninstall"
	[string]$Global:FriendlyProcessName = Set-ProjSetting -actionName "PROPERTY" -PropertyName "FriendlyProcessName"

	[string]$blnRebootNeeded = Set-ProjSetting -actionName "PROPERTY" -PropertyName "blnRebootNeeded"
	[string]$LanguagesToUse = Set-ProjSetting -actionName "PROPERTY" -PropertyName "LanguagesToUse"
	[string]$Global:appArch = Set-ProjSetting -actionName "PROPERTY" -PropertyName "AppArch"
	[string]$Global:appLang = Set-ProjSetting -actionName "PROPERTY" -PropertyName "AppLang"
	[string]$Global:appScriptVersion = Set-ProjSetting -actionName "PROPERTY" -PropertyName "appScriptVersion"
	[string]$Global:appScriptDate = Set-ProjSetting -actionName "PROPERTY" -PropertyName "appScriptDate"
	
  [string]$InstDir = Set-ProjSetting -actionName "PROPERTY" -PropertyName "AppInstallDir"
  [string]$Global:AppInstallDir = $InstDir
  [string]$UninstDir = Set-ProjSetting -actionName "PROPERTY" -PropertyName "AppUninstallDir"
  [string]$Global:AppUninstallDir = $UninstDir
	[string]$appVendor = Set-ProjSetting -actionName "PROPERTY" -PropertyName "Manufacturer"
	[string]$Global:Manufacturer = $appVendor
	[string]$appNameA = Set-ProjSetting -actionName "PROPERTY" -PropertyName "ProductName"
	[string]$Global:ProductName = $appNameA
	[string]$appNameVar = Set-ProjSetting -actionName "PROPERTY" -PropertyName "AppName"
	[string]$Global:AppName = $appNameVar
	[string]$appVersion = Set-ProjSetting -actionName "PROPERTY" -PropertyName "ProductVersion"
	[string]$Global:ProductVersion = $appVersion
	[string]$appRevision = Set-ProjSetting -actionName "PROPERTY" -PropertyName "PKGBuild"
	[int]$Global:PKGBuild = $appRevision
	[string]$appScriptAuthor = Set-ProjSetting -actionName "PROPERTY" -PropertyName "PackagerName"
	[string]$Global:PackagerName = $appScriptAuthor

	##*===============================================
	## Variables: Install Titles (Only set here to override defaults set by the toolkit)
	[string]$installName = Set-ProjSetting -actionName "PROPERTY" -PropertyName "installName"
	[string]$installTitle = Set-ProjSetting -actionName "PROPERTY" -PropertyName "installTitle"

	##* Do not modify section below
	#region DoNotModify
	## Variables: Exit Code
	[int32]$mainExitCode = 0

	## Variables: Script
	[string]$Global:deployAppScriptFriendlyName = Set-ProjSetting -actionName "PROPERTY" -PropertyName "FriendlyPKGName"
	[string]$deployAppScriptPKGFriendlyName = $Global:PKGName
	[string]$Global:FriendlyPKGName = $Global:deployAppScriptFriendlyName
	[version]$deployAppScriptVersion = [version](Set-ProjSetting -actionName "PROPERTY" -PropertyName "ProductVersion")
	[string]$deployAppScriptDate = Set-ProjSetting -actionName "PROPERTY" -PropertyName "appScriptDate"
	[hashtable]$deployAppScriptParameters = $psBoundParameters

  if ([string]::IsNullOrWhitespace($ClientName) -or ($ClientName -eq "") -or ($null -eq $ClientName)) {
    $Global:clientBasedBP = $False
    if ($DeployMode -eq 'null') { $DeployMode = 'Silent' }
  } else { 
    If ($DeployMode -eq 'null') {
      $Global:TmpDeployMode = 'Interactive'
      $DeployMode = 'Silent'
    } else { $Global:TmpDeployMode = $DeployMode }

    $Global:clientBasedBP = $True
    Set-AccountBP -CN $ClientName
  }

  if (($CustomData -ne 'none') -and ($CustomData -like '*:*')) { 
    Write-Host "CustomData set is available = $CustomData. Will parse."
    if ($CustomData -like "*;*") { $DataSet = $CustomData.Split(";") }
    else { $DataSet = @($CustomData) }

    foreach ($Data in $DataSet) {
      $Var = $Data.Split(":")
      $VarName = $Var[0]
      $VarValue = $Var[1]
      $tmpName = (Get-Variable $VarName -Scope Global -ErrorAction 'Ignore').Name
      if ($tmpName -eq $VarName) { Remove-Variable -Name $VarName -Scope "Global" -ErrorAction SilentlyContinue }
      Write-Host "Adding variable $VarName = $VarValue."
      New-Variable -Name $VarName -Value $VarValue -Scope "Global"
    }
  } else { Write-Host "CustomData set is not available. Will proceed to next step." }

	## Variables: Environment
	## Dot source the required App Deploy Toolkit Functions
	Try {
		[string]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
		If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }
		If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }
	} Catch {
		If ($mainExitCode -eq 0){ [int32]$mainExitCode = 60008 }
		Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
		## Exit the script, returning the exit code to SCCM
		If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
	}

	If ($DeploymentType -eq "Uninstall") { $Global:ThisInstall = $False } 
  Else { $Global:ThisInstall = $True }

	#endregion
	##* Do not modify section above
	##*===============================================
	##* END VARIABLE DECLARATION
	##*===============================================

  Get-isAServer
  Get-DiscSpace -drive "C"
  if (($($PSVersionTable.PSVersion.Major) -le 4) -and ($($PSVersionTable.PSVersion.Minor) -eq 0)) { 
    Write-Error -Message "PSVersion is to obsolete ($($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor))." -ErrorAction 'Continue'
    Write-Error -Message "Multiple functionalities of WRAPPER can cause problems on PS < 4.1." -ErrorAction 'Continue'
    Write-Error -Message "Please update PS version to recomended 5.1." -ErrorAction 'Continue'
    #Write-Error -Message "Will exit script. Please update PS Version and rerun wrapper. `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
    #Exit 17031
  }

	If ($deploymentType -ine 'Uninstall') {
    Get-PSVersion
		##*===============================================
		##* PRE-INSTALLATION
		##*===============================================
		[string]$Global:installPhase = 'Pre-Installation'

    Write-Log -Message "killProcessesInstall - $Global:killProcessesInstall"
    Write-Log -Message "clientBasedBP - $Global:clientBasedBP"
    Write-Log -Message "TmpDeployMode - $TmpDeployMode"

    $ATest = [string]::IsNullOrEmpty($Global:killProcessesInstall)
    $BTest = [string]::IsNullOrWhitespace($Global:killProcessesInstall)

    Write-Log -Message "IsNullOrEmpty - $ATest"
    Write-Log -Message "IsNullOrWhitespace - $BTest"

		## Show Welcome Message, close Internet Explorer if required, allow up to 3 deferrals, verify there is enough disk space to complete the install, and persist the prompt
		if (((($ATest -eq $False) -and ($BTest -eq $False)) -and (($Global:killProcessesInstall -ne "") -and ($null -ne $Global:killProcessesInstall)))) {
			If ($Global:clientBasedBP -ne $True) {
				Write-Log -Message "Will show Installation Welcome"
				Show-InstallationWelcome -CloseApps $killProcessesInstall -AllowDefer -DeferTimes 3 -CheckDiskSpace -PersistPrompt
			} Else {
				If ($TmpDeployMode -ne 'NonInteractive') { 
					Write-Log -Message "Will show Client Based Windows"
					Show-ClientBasedWindow -CloseApps $killProcessesInstall
				} else { Write-Log -Message "Deploy Mode NonInteractive, skipping windows." }
			}
		} else { Write-Log -Message "killProcessesInstall - is empty or null." }

		## Show Progress Message (with the default message)
		If ($TmpDeployMode -ne 'Silent') { Set-ProgressBar }
		else { Show-InstallationProgress }
		## <Perform Pre-Installation tasks here>

		Set-ProjSetting -actionName "PREREQSINSTALL"
		Set-ProjSetting -actionName "PREINSTALL"

		##*===============================================
		##* INSTALLATION
		##*===============================================
		[string]$Global:installPhase = 'Installation'

		## Handle Zero-Config MSI Installations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Install'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat; If ($defaultMspFiles) { $defaultMspFiles | ForEach-Object { Execute-MSI -Action 'Patch' -Path $_ } }
		}

		## <Perform Installation tasks here>
		Set-ProjSetting -actionName "INSTALL"

		##*===============================================
		##* POST-INSTALLATION
		##*===============================================
		[string]$Global:installPhase = 'Post-Installation'

		## <Perform Post-Installation tasks here>
		Set-ProjSetting -actionName "POSTINSTALL"
		Set-ProjSetting -actionName "USERINSTALL"

		## Display a message at the end of the install

		If ((-not $useDefaultMsi) -and ($IsSuccessFinalizeMsg.toLower() -eq 'false')) { Show-InstallationPrompt -Message 'You can customize text to appear at the end of an install or remove it completely for unattended installations.' -ButtonRightText 'OK' -Icon Information -NoWait }
	}
	ElseIf ($deploymentType -ieq 'Uninstall') {
    Get-PSVersion
		##*===============================================
		##* PRE-UNINSTALLATION
		##*===============================================
		[string]$Global:installPhase = 'Pre-Uninstallation'

    Write-Log -Message "killProcessesUninstall - $Global:killProcessesUninstall"
    Write-Log -Message "clientBasedBP - $Global:clientBasedBP"
    Write-Log -Message "TmpDeployMode - $TmpDeployMode"

    $ATest = [string]::IsNullOrEmpty($Global:killProcessesUninstall)
    $BTest = [string]::IsNullOrWhitespace($Global:killProcessesUninstall)

    Write-Log -Message "IsNullOrEmpty - $ATest"
    Write-Log -Message "IsNullOrWhitespace - $BTest"

		## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
		if (((($ATest -eq $False) -and ($BTest -eq $False)) -and (($Global:killProcessesUninstall -ne "") -and ($null -ne $Global:killProcessesUninstall)))) {
			If ($Global:clientBasedBP -ne $True) {
				Write-Log -Message "Will show Installation Welcome"
				Show-InstallationWelcome -CloseApps $killProcessesUninstall -CloseAppsCountdown 60
			} Else {
				If ($TmpDeployMode -ne 'NonInteractive') { 
					Write-Log -Message "Will show Client Based Windows"
					Show-ClientBasedWindow -CloseApps $killProcessesUninstall
				} else { Write-Log -Message "Deploy Mode NonInteractive, skipping windows." }
			}
		} else { Write-Log -Message "killProcessesUninstall - is empty or null." }

		## Show Progress Message (with the default message)

		If ($TmpDeployMode -ne 'Silent') { Set-ProgressBar }
		else { Show-InstallationProgress }

		## <Perform Pre-Uninstallation tasks here>
		Set-ProjSetting -actionName "PREUNINSTALL"

		##*===============================================
		##* UNINSTALLATION
		##*===============================================
		[string]$Global:installPhase = 'Uninstallation'

		## Handle Zero-Config MSI Uninstallations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Uninstall'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat
		}

		# <Perform Uninstallation tasks here>
		Set-ProjSetting -actionName "UNINSTALL"

		##*===============================================
		##* POST-UNINSTALLATION
		##*===============================================
		[string]$Global:installPhase = 'Post-Uninstallation'

		## <Perform Post-Uninstallation tasks here>

		Set-ProjSetting -actionName "POSTUNINSTALL"
		Set-ProjSetting -actionName "USERUNINSTALL"
	}

	##*===============================================
	##* END SCRIPT BODY
	##*===============================================

	## Call the Exit-Script function to perform final cleanup operations
  [string]$Global:installPhase = 'Finalization'
	Write-Verbose "-------------------------------------------------------------------------mainExitCode: $mainExitCode" -Verbose
	Set-Finalize -ExitCode $mainExitCode
} Catch {
  if ($BypassErrors -eq $False) {
    [string]$Global:installPhase = 'Finalization'
    [int32]$mainExitCode = 60001
    [string]$mainErrorMessage = "$(Resolve-Error)"
    Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
    Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'

    Write-Verbose "-------------------------------------------------------------------------mainExitCode: $mainExitCode" -Verbose
    Set-Finalize -ExitCode $mainExitCode
  }
}