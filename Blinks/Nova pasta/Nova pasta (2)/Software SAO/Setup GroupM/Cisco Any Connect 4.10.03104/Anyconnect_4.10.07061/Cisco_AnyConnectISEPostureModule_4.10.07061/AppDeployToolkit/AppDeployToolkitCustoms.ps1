# Last modified: 2023/05/19 15:32:11

#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Get-OSBitness {
  
  <# $IntPtrSize = [System.IntPtr]::Size

  if ($IntPtrSize -eq 4) { $Bitness = "x86" }
  else { $Bitness = "x64" } #>

  $bitTest = (Get-WmiObject Win32_Processor).AddressWidth

  if ($bitTest -eq "64") { $Bitness = "x64" }
  else { $Bitness = "x86" }

  Write-Host "Bitness $Bitness"

  Return $Bitness
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

$OSBitness = Get-OSBitness

$Global:MSIVersionVal           = ""

$Global:PSScriptRoot            = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
$Script:ParentScriptRoot        = Split-Path $PSScriptRoot -Parent
$Script:confFile                = $Script:ParentScriptRoot + "\ADTConf.wamp" 

if ((Test-Path -Path "$Script:confFile" -PathType Leaf) -eq $False) { $Script:confFile = $Script:ParentScriptRoot + "\ADTConf.conf" }

$Global:ConfigFilesPath         = $ParentScriptRoot + "\_ConfigFiles"
$Global:PrerequisitesPath       = $ParentScriptRoot + "\_Prerequisites"
$Global:SourcePath              = $ParentScriptRoot + "\_Source"
$Global:ProgramData             = $env:ProgramData
$Global:ProgramFiles64          = $env:ProgramFiles
$Global:ProgramFiles32          = ${env:ProgramFiles(x86)}

Write-Verbose "=====================================================================" -Verbose
Write-Verbose "OSBitness = $OSBitness" -Verbose
$disc = $env:systemdrive
if ($OSBitness -eq "x64") {
  $Global:ProgramFiles = ${env:ProgramFiles(x86)}
  $Global:ProgramFiles64 = "$env:systemdrive\Program Files"
  $Global:ProgramFiles32 = ${env:ProgramFiles(x86)}

  Write-Verbose "Global:ProgramFiles64 = `"$env:systemdrive\Program Files`" because OSBitness = $OSBitness." -Verbose
  Write-Verbose "Global:ProgramFiles = `"${env:ProgramFiles(x86)}`" because OSBitness = $OSBitness." -Verbose
  Write-Verbose "Global:ProgramFiles32 = `"${env:ProgramFiles(x86)}`" because OSBitness = $OSBitness." -Verbose
} else {
  $Global:ProgramFiles = $env:ProgramFiles
  $Global:ProgramFiles64 = $env:ProgramFiles
  $Global:ProgramFiles32 = $env:ProgramFiles

  Write-Verbose "Global:ProgramFiles64 = `"$env:ProgramFiles`" because OSBitness = $OSBitness." -Verbose
  Write-Verbose "Global:ProgramFiles = `"$env:ProgramFiles`" because OSBitness = $OSBitness." -Verbose
  Write-Verbose "Global:ProgramFiles32 = `"$env:ProgramFiles`" because OSBitness = $OSBitness." -Verbose
}
Write-Verbose "=====================================================================" -Verbose

$Global:windir                  = $env:windir
$Global:Temp                    = $env:Temp
$Global:PUBLIC                  = $env:PUBLIC
#$Global:PROGRAMDATA             = $env:PROGRAMDATA
$Global:COMMONPROGRAMFILES64    = $env:COMMONPROGRAMFILES

$Global:IBMSRC                  = $Global:ProgramData + "\IBMSRC\"
$Global:KyndrylSRC              = $Global:ProgramData + "\KyndrylSRC\"
$Global:IBMSRCPkg               = " "
$Global:KyndrylSRCPkg           = " "
$Global:PreLogDir               = " "
$Global:configToolkitLogDir     = " "
$Global:rootDrive               = $PSScriptRoot.SubString(0,2)

$Global:TagsDir = Join-Path -Path "$($Global:ProgramFiles)" -ChildPath Logs

$Global:clientBasedBP           = $False
$Global:SilentInstall           = $False
$Global:selectedLang           	= ""

Write-Verbose "ConfigFilesPath = $Global:ConfigFilesPath" -Verbose
Write-Verbose "PrerequisitesPath = $PrerequisitesPath" -Verbose
Write-Verbose "SourcePath = $Global:SourcePath" -Verbose

$Global:Const_StandardRC        = 0		    # Standard success RC.
$Global:Const_StrikeEC          = -1000		# 3-Strike or 5-Strike postponed.
$Global:Const_IsServerEC        = -1001		# Operating system identified as a server.
$Global:Const_NewerVersionEC    = -1002		# Application's newer version is already installed.
$Global:Const_NoDependencyEC    = -1003		# Application's dependency is not installed.
$Global:Const_AppInstalledEC    = -1004		# Current application is already installed.
$Global:Const_ProcessRunningEC  = -1005		# Process is running and it cannot be terminated.
$Global:Const_RebootPendingEC   = -1006		# The machine is in REBOOT PENDING state.
$Global:Const_NoDiskSpaceEC     = -1007		# Not enough free disk space.
$Global:Const_NoPortalFileEC    = -1008		# Missing essential file for Request Portal.
$Global:Const_ParamFailEC       = -1009		# Function parameter is empty (where it cannot be) or incorrect.
$Global:Const_VendorPresent     = -1400		# Vendor present.
$Global:Const_RetryInstallEC    = -1618		# Info for SCCM to retry installation (another installation is already in progress).
$Global:Const_StartedReboot     = 1641		# The installer has started a reboot.
$Global:Const_RebootRequred     = 3010		# Reboot required RC.

$Global:SuccessRC         = @($Global:Const_StandardRC,$Global:Const_RebootRequred,$Global:Const_VendorPresent,$Global:Const_StrikeEC,$Global:Const_NewerVersionEC,$Global:Const_AppInstalledEC,$Global:Const_StartedReboot)
$Global:SkipVindowsRC     = @($Global:Const_VendorPresent,$Global:Const_StrikeEC,$Global:Const_NewerVersionEC,$Global:Const_AppInstalledEC)
$Global:SkipTagRC         = @($Global:Const_VendorPresent,$Global:Const_StrikeEC,$Global:Const_NewerVersionEC,$Global:Const_AppInstalledEC)

#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-ProjSetting {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $False)]
    [String]$actionName = "All",
    [Parameter(Mandatory = $False)]
    [String]$PropertyName = " "
  )

  if ((Test-Path -Path "$Script:confFile" -PathType Leaf) -eq $False) { $Script:confFile = $Script:ParentScriptRoot + "\ADTConf.conf" }

  If (Test-Path -Path "$Script:confFile") {
    #$config = [System.IO.File]::ReadLines("$Script:confFile") $is not working in ConstrainedLanguage ps mode
    $config = Get-Content "$Script:confFile"

    foreach ($line in $config) {
      if ([string]::IsNullOrWhitespace($line)) { <#Write-Log -Message "Skip all empty lines from $confPKGFile"#> }
      else {
        $arr = $line.ToCharArray()
        if ($arr[0] -like "#*") { <#Write-Log -Message "Line: $line skipped (it's commented) from $confPKGFile"#> }
        else {
          #$line = $line.Replace("\,","{comma}").Replace("{,}","{comma}").Replace("\=","{equal}").Replace("{=}","{equal}").Replace("{#}","{comment}")
          $line = $line.Replace("{,}","{comma}").Replace("{=}","{equal}").Replace("{#}","{comment}").Replace("\\,","{comma}").Replace("\\=","{comma}").Replace("\\#","{comma}").Replace("{|}","{wall}")
          $line = $line.Replace("{%}","%").Replace("{{}","{").Replace("{}}","}").Replace("{;}",";")
          #Semicolon
          $vars = $Line.Split(",")
          $ModuleName = $Vars[0]
          $Action = $Vars[1]
          $Name = $Vars[2]
          $Data = $Vars[3]
          $DataType = $Vars[4]

          if (-not([string]::IsNullOrEmpty($Name))) {
            if ($Name.ToUpper() -eq 'SVAR') {
              $Data = $Line.Replace("$ModuleName,","")
              [regex]$pattern = "$Action,"
              $Data = $pattern.replace($Data, "", 1)
              $Data = $Data.Replace("$Name,","")
              $Data = $Data.Replace(",null","")
              if ([string]::IsNullOrEmpty($DataType)) { $DataType = "null" }
            }

            if ($Name.ToUpper() -ne 'SVAR') {
              if ([string]::IsNullOrEmpty($Data)) { Set-Finalize -ExitCode -1999 }
              $arr = $Data.Split("=")
            } elseif  ($Name.ToUpper() -eq 'SVAR') { $arr = @($Data, "") }
          }

          $NameV = $arr[0]
          $valueV = $arr[1]

          If ($PropertyName -like "PropertyName*") { $PropertyName = $PropertyName.Replace("PropertyName","") }

          if ($actionName.ToLower() -eq "all"){
            if (($ModuleName.ToUpper() -eq "PROPERTY") -and ($Name.ToUpper() -like "WRAPPER")){
              if (($PropertyName -ne " ") -and (-not([string]::IsNullOrEmpty($PropertyName)))) {
                If ($PropertyName -like $NameV) {
                  If ($PropertyName.ToLower() -eq "appscriptdate") { Return Get-Date -Format "dddd MM/dd/yyyy" }
                  else { Return $valueV }
                }
              }
            } else  { Get-ScriptAction -actionName $ModuleName -Data $arr -Action $Action -Name $Name -line $line }
          } elseif ($actionName.ToUpper() -eq "PROPERTY") {
            if (-not([string]::IsNullOrEmpty($Name))) {
              if ($Name.ToUpper() -like "WRAPPER"){
                if (($PropertyName -ne " ") -and (-not([string]::IsNullOrEmpty($PropertyName)))) {
                  If ($PropertyName -like $NameV) {
                    If ($PropertyName.ToLower() -eq "appscriptdate") { Return Get-Date -Format "dddd MM/dd/yyyy" }
                    else { Write-Verbose "--------------------------------- $PropertyName = $valueV -----------------------------------------------" -Verbose; Return $valueV }
                  }
                }
              }
            }
          } else { if ($ModuleName -eq $actionName) { Get-ScriptAction -actionName $actionName -Data $arr -Action $Action -Name $Name -DataType $DataType -line $line }}
        }
      }
    }
  }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Get-ScriptAction {
  param(
    [Parameter(Mandatory = $False)]
    [String]$actionName = "All",
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$Action = " ",
    [Parameter(Mandatory = $False)]
    [String]$Name = " ",
    [Parameter(Mandatory = $False)]
    [String]$DataType = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  $contextType = $Global:UserContextVar
  Write-Verbose "$contextType -> $actionName" -Verbose

  if (($contextType.ToLower() -eq 'none') -or ($contextType.ToLower() -eq 'machine')) {
    switch ($actionName.ToUpper()) {
      "PROPERTY"        { Set-ScriptActions -actionName $actionName -Data $Data -Action $Action -Name $Name -DataType $DataType -line $line }
      "INSTALL"         { Set-ScriptActions -actionName $actionName -Data $Data -Action $Action -Name $Name -DataType $DataType -line $line }
      "UNINSTALL"       { Set-ScriptActions -actionName $actionName -Data $Data -Action $Action -Name $Name -DataType $DataType -line $line }
      "PREINSTALL"      { Set-ScriptActions -actionName $actionName -Data $Data -Action $Action -Name $Name -DataType $DataType -line $line }
      "POSTINSTALL"     { Set-ScriptActions -actionName $actionName -Data $Data -Action $Action -Name $Name -DataType $DataType -line $line }
      "PREUNINSTALL"    { Set-ScriptActions -actionName $actionName -Data $Data -Action $Action -Name $Name -DataType $DataType -line $line }
      "POSTUNINSTALL"   { Set-ScriptActions -actionName $actionName -Data $Data -Action $Action -Name $Name -DataType $DataType -line $line }
      "PREREQSINSTALL"  { Set-ScriptActions -actionName $actionName -Data $Data -Action $Action -Name $Name -DataType $DataType -line $line }
      "ROLLBACK"        { Set-ScriptActions -actionName $actionName -Data $Data -Action $Action -Name $Name -DataType $DataType -line $line }
    }
  } elseif ($contextType.ToLower() -eq 'user') {
    switch ($actionName.ToUpper()) {
      "USERINSTALL"   { Set-ScriptActions -actionName $actionName -Data $Data -Action $Action -Name $Name -DataType $DataType -line $line }
      "USERUNINSTALL" { Set-ScriptActions -actionName $actionName -Data $Data -Action $Action -Name $Name -DataType $DataType -line $line }
    }
  }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-ScriptActions {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $False)]
    [String]$actionName = "All",
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$Action = " ",
    [Parameter(Mandatory = $False)]
    [String]$Name = " ",
    [Parameter(Mandatory = $False)]
    [String]$DataType = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  if ($Global:isDebugScript -eq $True) {
    Write-Log -Message " " -Source ${CmdletName} -Severity 1
    Write-Log -Message " " -Source ${CmdletName} -Severity 1
    Write-Log -Message " " -Source ${CmdletName} -Severity 1
    Write-Log -Message "Starting line processing: $Action,$Data,$DataType." -Source ${CmdletName} -Severity 1
  }

  switch ($Name.ToUpper()) {
    "DETECTIONMETHOD"   { $RC = Set-DetectionMethod -actionName $Action -Data $Data -DataType $DataType -line $line }
    "DM"                { $RC = Set-DetectionMethod -actionName $Action -Data $Data -DataType $DataType -line $line }
    "SHORTCUT"          { $RC = Set-Lnk -actionName $Action -Data $Data -line $line }
    "LNK"               { $RC = Set-Lnk -actionName $Action -Data $Data -line $line }
    "MSI"               { $RC = Set-MsiAction -actionName $Action -Data $Data -DataType $DataType -line $line }
    "MSIINTUNE"         { $RC = Set-MSIInTune -actionName $Action -Data $Data -DataType $DataType -line $line }
    "MSIINTUNEMA"       { $RC = Set-MSIInTuneMA -actionName $Action -Data $Data -DataType $DataType -line $line }
    "APPV"              { $RC = Set-AppVAction -actionName $Action -Data $Data -line $line }
    "APPVCG"            { $RC = Set-AppVCGAction -actionName $Action -Data $Data -line $line }
    "XMLAPPVCG"         { $RC = Create-AppVCGXML -actionName $Action -Data $Data -line $line }
    "EXE"               { $RC = Set-ExeAction -actionName $Action -Data $Data -DataType $DataType -line $line }
    "EXEASUSER"         { $RC = Set-ExeAsUserAction -actionName $Action -Data $Data -DataType $DataType -line $line }
    "DIR"               { $RC = Set-DirAction -actionName $Action -Data $Data -DataType $DataType -line $line }
    "FILE"              { $RC = Set-FileAction -actionName $Action -Data $Data -DataType $DataType -line $line }
    "SERVICE"           { $RC = Set-Services -actionName $Action -Data $Data -line $line }
    "REG"               { $RC = Set-Registry -actionName $Action -Data $Data -DataType $DataType -line $line }
    "REGITERATIVE"      { $RC = Set-RegistryIterative -actionName $Action -Data $Data -DataType $DataType -line $line }
    "DISPLAYWINDOW"     { $RC = Set-DisplayWindow -actionName $Action -Data $Data -line $line }
    "PROCESS"           { $RC = Set-Process -actionName $Action -Data $Data -DataType $DataType -line $line }
    "TAG"               { $RC = Set-Tag -actionName $Action -Data $Data -line $line }
    "AS"                { $RC = Set-ActiveSetupVal -actionName $Action -Data $Data -line $line }
    "SELFUSERTMP"       { $RC = Set-SelfUserTmp -actionName $Action -Data $Data -line $line }
    "SELFAS"            { $RC = Set-SelfAS -actionName $Action -Data $Data -line $line }
    "WAIT"              { $RC = Set-Wait -actionName $Action -Data $Data -line $line }
    "VAR"               { $RC = Set-Vars -actionName $Action -Data $Data -line $line }
    "SVAR"              { $RC = Set-ScriptVars -actionName $Action -Data $Data -line $line }
    "IF"                { $RC = Set-If -actionName $Action -Data $Data -actionState $actionName -line $line }
    "MSIX"              { $RC = Set-MSIX -actionName $Action -Data $Data -line $line }
    "APPX"              { $RC = Set-APPX -actionName $Action -Data $Data -line $line }
    "VBS"               { $RC = Set-RunVBS -actionName $Action -Data $Data -DataType $DataType -line $line }
    "PS"                { $RC = Set-RunPS -actionName $Action -Data $Data -DataType $DataType -line $line }
    "CMD"               { $RC = Set-RunCMD -actionName $Action -Data $Data -DataType $DataType -line $line }
    "PERMISSIONS"       { $RC = Set-Permissions -actionName $Action -Data $Data -DataType $DataType -line $line }
    "COMBINEDPERMS"     { $RC = Set-CombPermissions -actionName $Action -Data $Data -line $line }
    "WINFEATURE"        { $RC = Set-WinFeature -actionName $Action -Data $Data -line $line }
    "OFFICE"            { $RC = Set-Office -actionName $Action -Data $Data -DataType $DataType -line $line }
    "OFFICEADDIN"       { $RC = Set-OfficeAddin -actionName $Action -Data $Data -line $line }
    "DLL"               { $RC = Set-Dll -actionName $Action -Data $Data -line $line }
    "PLUGIN"            { $RC = Set-Plugin -actionName $Action -Data $Data -line $line }
    "ARCHIVE"           { $RC = Set-Archive -actionName $Action -Data $Data -line $line }
    "SETTINGS"          { $RC = Set-Settings -actionName $Action -Data $Data -line $line }
    "UNBLOCKFILE"       { $RC = Set-UnblockFiles -actionName $Action -Data $Data -line $line }
    "SCHEDULEDTASK"     { $RC = Set-ScheduledTaskWrap -actionName $Action -Data $Data -line $line }
    "PINNEDAPPS"        { $RC = Set-PinnedApp -actionName $Action -Data $Data -line $line }
    "TEXTCONTENT"       { $RC = Set-TextContent -actionName $Action -Data $Data -line $line }
    "FONT"              { $RC = Set-FontAction -actionName $Action -Data $Data -line $line }
    "SYMLINK"           { $RC = Set-SymLink -actionName $Action -Data $Data -line $line }
    "REBOOTANDCONTINUE" { $RC = Set-RebootAndContinue -actionName $Action -Data $Data -line $line }
    "SELFSCHEDULEDTASK" { $RC = Set-SelfScheduledTask -actionName $Action -Data $Data -line $line }
    "CERT"              { $RC = Set-Certyficate -actionName $Action -Data $Data -DataType $DataType -line $line }
    "POLICY"            { $RC = Set-Policy -actionName $Action -Data $Data -line $line }
    "FIREWALL"          { $RC = Set-FireWall -actionName $Action -Data $Data -line $line }
    "DRIVER"            { $RC = Set-Driver -actionName $Action -Data $Data -line $line }
    "WAITFOR"           { $RC = Set-WaitFor -actionName $Action -Data $Data -line $line }
    "ARP"               { $RC = Set-ARPAction -actionName $Action -Data $Data -line $line }
    "NUGET"             { $RC = Set-DotNetTools -actionName $Action -Data $Data -DataType $DataType -line $line } #TODO
    "MSIVERSION"        { $RC = Get-MSIVersion -actionName $Action -Data $Data -line $line }
    "GETREG"            { $RC = Get-Registry -actionName $Action -Data $Data -line $line }
    "REMOVEJAVA"        { $RC = Get-JavaCleanup -actionName $Action -Data $Data -line $line }
    "REMOVEVDA"         { $RC = Get-VDACleanup -actionName $Action -Data $Data -line $line }
    "BACKUP"            { $RC = Set-Backup -actionName $Action -Data $Data -line $line }
    "STRING"            { $RC = Get-String -actionName $Action -Data $Data -line $line }
    "RC"                { $RC = Get-ReturnData -actionName $Action -Data $Data -line $line }
    "DOWNLOAD"          { $RC = Get-Download -actionName $Action -Data $Data -line $line }
    "WAMP"              { $RC = Set-WAMP -actionName $Action -Data $Data -line $line }
  }

  if ($Global:isDebugScript -eq $True) {
    Write-Log -Message "Processing line. $Action,$Data,$DataType, finished." -Source ${CmdletName} -Severity 1
    Write-Host -NoNewLine 'Press any key to continue...';
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
  }

  return $RC
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Get-FullPath {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$path
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "Will check path: $path." -Source ${CmdletName} -Severity 1

  if ($path.ToLower() -ne "null") { 
    if ((($path.ToLower() -like "*:\*") -or ($path.ToLower() -like "*%*")) -or (($path -like "\\*") -or ($path -like "file:\*"))) { $path = $path.replace("file:","") }
    elseif (($path.ToLower() -like "\*") -and (-not ($path -like "\\*"))) { $path = "$($Global:SourcePath)$path" }
    else { $path = "$($Global:SourcePath)\$path" }
  }

  Write-Log -Message "Will return path: $path." -Source ${CmdletName} -Severity 1

  Return $path
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Get-PSVersion {
  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  if (($($PSVersionTable.PSVersion.Major) -le 4) -and ($($PSVersionTable.PSVersion.Minor) -eq 0)) { 
    Write-Log -Message "PSVersion is to obsolete ($($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor))." -Source ${CmdletName} -Severity 3
    Write-Log -Message "Multiple functionalities of WRAPPER can cause problems on PS < 4.1." -Source ${CmdletName}-Severity 3
    Write-Log -Message "Please update PS version to recomended 5.1." -Source ${CmdletName}-Severity 3
  } else { Write-Log -Message "Acctual PSVersion: ($($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor))." -Source ${CmdletName} -Severity 1 }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-SpecialCharacters {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$string,
    [Parameter(Mandatory = $False)]
    [String]$type = "full"
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  Write-Log -Message "Will handle: $string." -Source ${CmdletName}

  $string = $string.Replace("{comma}",",")
  $string = $string.Replace("{equal}","=")
  $string = $string.Replace("{wall}","|")
  $string = $string.Replace("{comment}","#")

  if ($type -eq "full") { $string = $string.Replace("><","=") }

  Write-Log -Message "Got: $string." -Source ${CmdletName}
  
  Return $string
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Get-isAServer {  
  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  $isServer = $False

  Write-Log -Message "Will check if target machine is a server." -Source ${CmdletName}

  $osInfo = Get-WmiObject -Class Win32_OperatingSystem
  $ProductType = $osInfo.ProductType

  if ($ProductType -ne 1) { $isServer = $True }
  
  if ($isServer) {
    if ($Global:forServer -eq "false") { 
      Write-Log -Message "Target machine is a server and setting for this account are: do not install on server. Will exit." -Source ${CmdletName} 
      Set-Finalize -ExitCode $Global:Const_IsServerEC
    } else { Write-Log -Message "Target machine is a server but setting for this account allow to install. Will continue execution." -Source ${CmdletName} }
  } else { Write-Log -Message "Target machine is not a server, contiune execution." -Source ${CmdletName} }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Get-DiscSpace {
	param(
		$drive="C"
	)

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  $toGB =  (1024*1024*1024)
  $toMB =  (1024*1024)

  $space = Get-PSDrive $drive | Select-Object Used,Free

  $freeMB = $space.Free / $toMB
  $freeGB = $space.Free / $toGB
  $usedMB = $space.Used / $toMB
  $usedGB = $space.Used / $toGB
  $Total = $freeGB + $usedGB

  Write-Log -Message "Drive $drive space statistics:" -Source ${CmdletName}
  Write-Log -Message "Free space in MB: $freeMB." -Source ${CmdletName}
  Write-Log -Message "Free space in GB: $freeGB." -Source ${CmdletName}
  Write-Log -Message "Used space in MB: $usedMB." -Source ${CmdletName}
  Write-Log -Message "Used space in MB: $usedGB." -Source ${CmdletName}
  Write-Log -Message "Total space in GB: $Total." -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-PinnedAction {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $True)]
    [String]$Action,
    [Parameter(Mandatory = $True)]
    [String]$FilePath
  )
  
  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "Will $actionName $Action -> $FilePath." -Source ${CmdletName}

  If ($actionName.ToUpper() -eq "ADD") {
    if ($Action.ToLower() -eq "taskbar") { Set-PinnedApplication -Action "PintoTaskbar" -FilePath $FilePath }
    elseif ($Action.ToLower() -eq "startmenu") { Set-PinnedApplication -Action "PintoStartMenu" -FilePath $FilePath }
    else { Write-Log -Message "$actionName -> $Action -> $FilePath is not supported." -Source ${CmdletName} }
  }
  If ($actionName.ToUpper() -eq "REMOVE") {
    if ($Action.ToLower() -eq "taskbar") { Set-PinnedApplication -Action "UnpinfromTaskbar" -FilePath $FilePath }
    elseif ($Action.ToLower() -eq "startmenu") { Set-PinnedApplication -Action "UnpinfromStartMenu" -FilePath $FilePath }
    else { Write-Log -Message "$actionName -> $Action -> $FilePath is not supported." -Source ${CmdletName} }
  }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-PinnedApp {
  <#
    .SYNOPSIS
      Can add or remove custom pinned shortcut or Windows 10 Start Menu tile button. 
    .DESCRIPTION
      Can add or remove custom pinned shortcut or Windows 10 Start Menu tile button based on conf file parameters. To do such change only a few parameters are needed.
    .PARAMETER actionName
      The name action type you want to trigger: ADD or REMOVE can be used for PINNEDAPPS.
    .PARAMETER Data
      Data variable withh all information to execute function like:
      DataTargetName=Where shortcut should be created: startmenu, taskbar.
      DataTargetFile=Target file to which shortcut should be created. 
    .PARAMETER DataType
      As default is a null for PINNEDAPPS.
    .EXAMPLE
      Conf line: INSTALL,ADD,PINNEDAPPS,taskbar=%ProgramFilesX86%\IBM\Lotus\Notes\notes.exe,null - will create taskbar shortcut for Notes.exe
    .EXAMPLE
      Conf line: UNINSTALL,REMOVE,PINNEDAPPS,startmenu="%desktop%\app.lnk",null - will remove schortcut from Windows 10 start menu.
    .NOTES
      This is an internal script function and should typically not be called directly, it will be triggered by main script if proper conf line will be found.
    .LINK
      https://github.kyndryl.net/wms-global/WMSAutomationTool/
  #>
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$DataType = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #INSTALL,ADD,PINNEDAPPS,taskbar=%ProgramFilesX86%\IBM\Lotus\Notes\notes.exe,null
  #UNINSTALL,REMOVE,PINNEDAPPS,startmenu="desktop%\app.lnk",null

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  $Action = $Data[0]
  $FilePath = Set-StringFromVarLayered -VarToCheck $Data[1]
  $forAllUsers = $False

  Write-Log -Message "Starting setting pinned item actions ." -Source ${CmdletName}

  if ($FilePath -like "*%allusers%*") { $forAllUsers = $True }

  if ($forAllUsers) {
    if ($Global:userActions.ToLower() -eq 'false') { 
      Write-Log -Message "Will skipp ${CmdletName} execution. userActions = $($Global:userActions)." -Source ${CmdletName} -Severity 3
      Write-Log -Message "For your account use an other method for actions in user context/manipulation of user profiles." -Source ${CmdletName} -Severity 3 
    } else {
      ForEach ($User In (Get-WmiObject Win32_UserProfile -F "Special != True" | Select-Object -Expand LocalPath)) {
        $FilePath = $FilePath.Replace("%allusers%\","")
        $FilePath = "$($User)$FilePath"
        $FilePath = $FilePath.Replace(" \","\").Replace("\\","\")
        Write-Log -Message "FilePath - $FilePath " -Source ${CmdletName}
        Set-PinnedAction -actionName $actionName -Action $Action -FilePath $FilePath
      }
    }
  } else { Set-PinnedAction -actionName $actionName -Action $Action -FilePath $FilePath }
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-ARPAction {
  <#
    .SYNOPSIS
      Can edit ARP settings regarding ARP visibility or ARP functions realted to action buttons.
    .DESCRIPTION
      Can show or hide ARP entry or actions buttons like remove, change etc only by providing an GUID. 
    .PARAMETER actionName
      The name action type you want to trigger: ADD or EDIT can be used for ARP.
    .PARAMETER Data
      Data variable withh all information to execute function like:
      GUID=Where shortcut should be created: startmenu, taskbar.
      type=Target file to which shortcut should be created. 
      bitness=Target file to which shortcut should be created. 
    .PARAMETER DataType
      As default is a null for PINNEDAPPS.
    .EXAMPLE
      Conf line: INSTALL,ADD,ARP,Notepad_is=norepair=x64,null - will add no repair setting to application ARP entry in 64bit hive.
    .EXAMPLE
      Conf line: INSTALL,EDIT,ARP,Notepad_is=all,null - will add NoModify,NoRemove,NoRepair to 32 and/or 64 bit ARP entry for application.
    .NOTES
      This is an internal script function and should typically not be called directly, it will be triggered by main script if proper conf line will be found.
    .LINK
      https://github.kyndryl.net/wms-global/WMSAutomationTool/
  #>
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #INSTALL,ADD,ARP,GUID=type=bitness,null
  #INSTALL,EDIT,ARP,GUID=type,null
  #INSTALL,EDIT,ARP,GUID=SystemComponent,null
  #INSTALL,REMOVE,ARP,GUID=null,null
  #INSTALL,CLEANUP,ARP,GUID=null,null
  #INSTALL,CUSTOMIZE,ARP,GUID=null,null
  #type = SystemComponent,NoModify,NoRemove,NoRepair,all


  #TODO: add change state of type in arp

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  if ($line -ne " ") { Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName} }

  $GUID = Set-StringFromVarLayered -VarToCheck $Data[0]
  $type = $Data[1]

  Write-Log -Message "Starting ${CmdletName}." -Source ${CmdletName}

  $Keyx86 = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$GUID"
  $Keyx64 = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$GUID"
  $x86 = Test-Path -Path $Keyx86
  $x64 = Test-Path -Path $Keyx64

  Write-Log -Message "x86 - $x86." -Source ${CmdletName}
  Write-Log -Message "x64 - $x64." -Source ${CmdletName}

  if (-not([string]::IsNullOrEmpty($type))) {
    if (($type -like "*;*") -or ($type -like "*;")) { $actTypes = $type.Split(";") } 
    else { $actTypes = @($type) }
    if ($type.ToLower() -eq "all") { $actTypes = @("NoModify","NoRemove","NoRepair") }
  } else { $actTypes = @("NoModify","NoRemove","NoRepair") }

  Write-Log -Message "For: $GUID, will set:" -Source ${CmdletName}
  foreach ($aT in $actTypes) { Write-Log -Message "$aT" -Source ${CmdletName} }

  If ($actionName.ToUpper() -eq "EDIT") {
    Write-Log -Message "Will try to edit:" -Source ${CmdletName}

    if (($x86 -eq $true) -and ($x64 -eq $true)) { $bit = @($Keyx86,$Keyx64); Write-Log -Message "$Keyx86 and $Keyx64" -Source ${CmdletName} }
    if (($x86 -eq $true) -and ($x64 -eq $false)) { $bit = @($Keyx86); Write-Log -Message "$Keyx86" -Source ${CmdletName} } 
    if (($x86 -eq $false) -and ($x64 -eq $true)) { $bit = @($Keyx64); Write-Log -Message "$Keyx64" -Source ${CmdletName} } 

    foreach ($b in $bit) {
      foreach ($t in $actTypes) { 
        Write-Log -Message "Set-RegistryKey -Key $b -Name $t -Type 'DWord' -Value 1" -Source ${CmdletName}; 
        Set-RegistryKey -Key $b -Name $t -Type 'DWord' -Value 1 
      }
    }
  }
  If ($actionName.ToUpper() -eq "ADD") {
    Write-Log -Message "Will try to ADD to:" -Source ${CmdletName}
    $bitness = $Data[2]

    if (($bitness -eq "null") -or ($bitness -eq "all") -or ($bitness -eq "both")) { $bit = @($Keyx86,$Keyx64); Write-Log -Message "$Keyx86 and $Keyx64" -Source ${CmdletName} }
    if ($bitness -eq 'x86') { $bit = @($Keyx86); Write-Log -Message "Keyx86: $Keyx86" -Source ${CmdletName} }
    if ($bitness -eq 'x64') { $bit = @($Keyx64); Write-Log -Message "Keyx64: $Keyx64" -Source ${CmdletName} }

    foreach ($b in $bit) { foreach ($t in $actTypes) { Write-Log -Message "Set-RegistryKey -Key $b -Name $t -Type 'DWord' -Value 1" -Source ${CmdletName}; Set-RegistryKey -Key $b -Name $t -Type 'DWord' -Value 1 } }
  }
  If ($actionName.ToUpper() -eq "REMOVE") {
    Write-Log -Message "Set to remove ARP entry: $GUID." -Source ${CmdletName}; 
    if ($x86 -eq $true) { 
      Write-Log -Message "Will remove $Keyx86" -Source ${CmdletName}; 
      Remove-RegistryKey -Key $Keyx86 -Recurse 
    }
    if ($x64 -eq $true) { 
      Write-Log -Message "Will remove $Keyx64" -Source ${CmdletName}; 
      Remove-RegistryKey -Key $Keyx64 -Recurse 
    }
  }
  If ($actionName.ToUpper() -eq "CLEANUP") {
		Write-Log -Message "Set to CLEANUP ARP entry: $GUID." -Source ${CmdletName};
		$actTypes = @("Comments","Contact","HelpLink","HelpTelephone","URLInfoAbout")
    if ($x86 -eq $true) { 
      Write-Log -Message "Will remove ARPCOMMENTS, ARPCONTACT, ARPHELPLINK, ARPHELPTELEPHONE, ARPURLINFOABOUT in $Keyx86" -Source ${CmdletName};
			foreach ($type in $actTypes) { Remove-ARPProperty -KeyPath $Keyx86 -Property $type }
    }
    if ($x64 -eq $true) { 
      Write-Log -Message "Will remove ARPCOMMENTS, ARPCONTACT, ARPHELPLINK, ARPHELPTELEPHONE, ARPURLINFOABOUT in $Keyx64." -Source ${CmdletName}; 
			foreach ($type in $actTypes) { Remove-ARPProperty -KeyPath $Keyx64 -Property $type }
    }
  }
  If ($actionName.ToUpper() -eq "CUSTOMIZE") {
		Write-Log -Message "Set to CUSTOMIZE ARP entry: $GUID." -Source ${CmdletName};
    if ($x86 -eq $true) { <#ARPNOMODIFY#> }
    if ($x64 -eq $true) { }
  }
  If ($actionName.ToUpper() -eq "HIDE") {
		Write-Log -Message "Will hide ARP entry of $GUID." -Source ${CmdletName};
    if ($x86 -eq $true) { }
    if ($x64 -eq $true) { }
  }
  if ($line -ne " ") { Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName} }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Remove-ARPProperty {
	[CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$KeyPath,
    [Parameter(Mandatory = $True)]
    [String]$Property
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
	Write-Log -Message "Will remove $Property in $KeyPath" -Source ${CmdletName};
	if(Get-Member -InputObject (Get-ItemProperty -Path $KeyPath) -Name $Property) {
		Remove-ItemProperty -Path $KeyPath -Name $Property
	} else {
		Write-Log -Message "Nothing to remove, $Property was not found, going to next action." -Source ${CmdletName};
	}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Edit-ARPProperty {
	[CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$KeyPath,
    [Parameter(Mandatory = $True)]
    [String]$Property,
    [Parameter(Mandatory = $True)]
    [String]$Value,
    [Parameter(Mandatory = $True)]
    [String]$Type
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
	Write-Log -Message "Will remove $Property=$Value in $KeyPath" -Source ${CmdletName};
	if(Get-Member -InputObject (Get-ItemProperty -Path $KeyPath) -Name $Property) {
		Remove-ItemProperty -Path $KeyPath -Name $Property
		New-ItemProperty -Path $KeyPath -Name $Property -Value $Value -PropertyType $Type -Force
	} else {
		New-ItemProperty -Path $KeyPath -Name $Property -Value $Value -PropertyType $Type -Force
	}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-ARPCustoms {
	[CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$GUID
  )

  $Keyx86 = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$GUID"
  $Keyx64 = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$GUID"
  $NewKeyx86 = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\WAMP_$($GUID)"
  $NewKeyx64 = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\WAMP_$($GUID)"

  $x86 = Test-Path -Path $Keyx86
  $x64 = Test-Path -Path $Keyx64

  Set-SelfUserTmp -actionName "ADD" -Data "wrapper"

	if ($x86 -eq $true) {
		Copy-Item -Path "$Keyx86" -Destination "$NewKeyx86"
		$TargetKey = $NewKeyx86
		Edit-ARPProperty -KeyPath $Keyx86 -Property "SystemComponent" -Value "1" -Type "DWORD"
		
	}
	if ($x64 -eq $true) {
		Copy-Item -Path "$Keyx64" -Destination "$NewKeyx64"
		$TargetKey = $NewKeyx64 
		Edit-ARPProperty -KeyPath $Keyx64 -Property "SystemComponent" -Value "1" -Type "DWORD"
	}

	if (($x86 -eq $true) -or ($x64 -eq $true)) {
		$version = $($Global:PKGName).Split("-")[-1]
		#$ProductName = "$(Get-ItemPropertyValue $TargetKey -Name DisplayName) $(Get-ItemPropertyValue $TargetKey -Name DisplayVersion)"
		$ProductName = "$($($Global:PKGName).Split("-")[0])"

		if ($version -match "^\d+.\d+.\d+$") { $ProductVersion = "$version" } 
		else { $ProductVersion = "1.0.0" }

		$tmpName = (Get-Variable "UserTempDirPath" -Scope Global -ErrorAction 'Ignore').Name
		
		if ($tmpName -eq "UserTempDirPath") { 
			Write-Log -Message "UserTempDirPath = $($Global:UserTempDirPath)." -Source ${CmdletName} 
			$tmpPath = $Global:UserTempDirPath
		} else {
			Write-Log -Message "UserTempDirPath is missing." -Source ${CmdletName}
			Set-Finalize -ExitCode 1
		}

		if ((Test-Path variable:global:AppName) -eq $True) { 
			Write-Log -Message "AppName exist, will use it." -Source ${CmdletName}
			$tmpPath = $tmpPath.replace("<AppName>", $Global:AppName) 
		} else { 
			Write-Log -Message "AppName do not exist, will use ProductName." -Source ${CmdletName}
			$tmpPath = $tmpPath.replace("<AppName>", $Global:ProductName)
		}

		$tmpPath = $tmpPath.Replace("<Manufacturer>", $Global:Manufacturer)
		$tmpPath = $tmpPath.Replace("<ProductName>", $Global:ProductName)

		Set-ARPAction -actionName "CLEANUP" -Data "$TargetKey"
    
		Remove-ARPProperty -KeyPath $TargetKey -Property "QuietUninstallString"
		Remove-ARPProperty -KeyPath $TargetKey -Property "WindowsInstaller"
		Remove-ARPProperty -KeyPath $TargetKey -Property "AuthorizedCDFPrefix"
		Remove-ARPProperty -KeyPath $TargetKey -Property "ModifyPath"
		Remove-ARPProperty -KeyPath $TargetKey -Property "HelpLink"
    Remove-ARPProperty -KeyPath $TargetKey -Property "Comments"
    Remove-ARPProperty -KeyPath $TargetKey -Property "Contact"
    Remove-ARPProperty -KeyPath $TargetKey -Property "HelpTelephone"
    Remove-ARPProperty -KeyPath $TargetKey -Property "Readme"
    Remove-ARPProperty -KeyPath $TargetKey -Property "URLInfoAbout"
    Remove-ARPProperty -KeyPath $TargetKey -Property "URLUpdateInfo"
    Remove-ARPProperty -KeyPath $TargetKey -Property "SYSTEMCOMPONENT"

    Edit-ARPProperty -KeyPath $TargetKey -Property "Publisher" -Value "$Global:arpSubstitiutePublisher" -Type "String"
		Edit-ARPProperty -KeyPath $TargetKey -Property "NoRepair" -Value "0" -Type "DWORD"
		Edit-ARPProperty -KeyPath $TargetKey -Property "NoModify" -Value "1" -Type "DWORD"

    if ($Global:arpSubstitiuteMode.ToLower() -eq "full") {
      Edit-ARPProperty -KeyPath $TargetKey -Property "DisplayName" -Value "$ProductName" -Type "String"
      Edit-ARPProperty -KeyPath $TargetKey -Property "DisplayVersion" -Value "$ProductVersion" -Type "String"
    }
    if ($Global:arpSubstitiuteMode.ToLower() -eq "partial") {
      Edit-ARPProperty -KeyPath $TargetKey -Property "Comments" -Value "$ProductName" -Type "String"
    }

		Edit-ARPProperty -KeyPath $TargetKey -Property "UninstallString" -Value "`"$tmpPath\Deploy-Application_4.exe`" uninstall" -Type "String"
	} else {
		Write-Log -Message "$x86 and " -Source ${CmdletName}
		Write-Log -Message "$x64 are " -Source ${CmdletName}
		Write-Log -Message "missing. Cannot  ARPsubstitute on non existing entry." -Source ${CmdletName}
		Set-Finalize 1
	}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Remove-ARPsubstitute {
	[CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$GUID
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
	Write-Log -Message "Will remove customized WAMP GUID entry: WAMP_$($GUID)" -Source ${CmdletName};

	$TargetKey = "null"
  $Keyx86 = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\WAMP_$($GUID)"
  $Keyx64 = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\WAMP_$($GUID)"

	Write-Log -Message "x86 = Test-Path -Path $Keyx86" -Source ${CmdletName};
  $x86 = Test-Path -Path $Keyx86
	Write-Log -Message "x64 = Test-Path -Path $Keyx64" -Source ${CmdletName};
  $x64 = Test-Path -Path $Keyx64

	if ($x86 -eq $true) {
		Write-Log -Message "Sets $TargetKey as TargetKey(Keyx86)." -Source ${CmdletName}; 
		$TargetKey = $Keyx86
	}
	if ($x64 -eq $true) {
		Write-Log -Message "Sets $TargetKey as TargetKey(Keyx64)." -Source ${CmdletName}; 
		$TargetKey = $Keyx64
	}

	if ($TargetKey -ne "null") { 
		Write-Log -Message "Remove-Item -Path `"$TargetKey`" -Recurse  -Force -Verbose" -Source ${CmdletName}; 
		Remove-Item -Path "$TargetKey" -Recurse  -Force -Verbose
	}
	
	Set-SelfUserTmp -actionName "REMOVE" -Data "wrapper"
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-ARPsubstitute {
	[CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$GUID
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
	Write-Log -Message "Will prepare customized WAMP GUID entry for $GUID as WAMP_$($GUID)" -Source ${CmdletName};

	Set-ARPAction -actionName "REPLACE" -Data $GUID
	Set-ARPAction -actionName "HIDE" -Data $GUID
	Set-ARPCustoms -GUID $GUID
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-WaitFor {
  <#
    .SYNOPSIS
      Will pause script execution and wait for specific action.  
    .DESCRIPTION
      Will pause script execution and wait for action related with: file, process and registry. Can wait to time when action will be created or removed.
    .PARAMETER actionName
      The name action type you want to trigger: ADD.
    .PARAMETER Data
      Data variable withh all information to execute function like:
      NameOrPath=Process name or path to registry or file.
      Type=file, process reg can be set to perform a proper action check. 
      Value=If reg was set, then can wait for a value set. 
      Timeout=Time when script will fail if condition is not meet.
    .PARAMETER DataType
      As default is a null for WAITFOR.
    .EXAMPLE
      Conf line: INSTALL,ADD,WAITFOR,c:\plik.txt=file=null=160,null - will wait for plik.txt file creation. If file will not be created befor 160secount timeot will be reached, script will fail.
    .EXAMPLE
      Conf line: INSTALL,ADD,WAITFOR,-chrome=process=null=160,null - will wait for process kill.
    .NOTES
      This is an internal script function and should typically not be called directly, it will be triggered by main script if proper conf line will be found.
    .LINK
      https://github.kyndryl.net/wms-global/WMSAutomationTool/
  #>
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #INSTALL,ADD,WAITFOR,NameOrPath=Type=Value=Timeout,null
  #INSTALL,ADD,WAITFOR,c:\test.txt=file=null=120,null

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  $NameOrPath = Set-StringFromVarLayered -VarToCheck $Data[0]
  $Type = $Data[1]  #file, reg, process, directory
  $Value = $Data[2]   #optional; if registry can be validated
  $Timeout = $Data[3]   #when script will have timeout (in secounds) default 90s

  Write-Log -Message "Timeout = $Timeout." -Source ${CmdletName}
  $waitTime = 1

  #if ($Timeout -gt 30) {
    $RC = $(get-properdivisor $Timeout)
    foreach ($t in $RC) { 
      Write-Log -Message "Possible waittimes: $t." -Source ${CmdletName} 
      $test = $Timeout/$t 
      if ($test -lt 11) { 
        Write-Log -Message "Will use: $t." -Source ${CmdletName}
        $waitTime = $t
        Break
      }
    }
  #}

  Write-Log -Message "waitTime = $waitTime." -Source ${CmdletName}
  Write-Log -Message "Starting ${CmdletName} for: NameOrPath - $NameOrPath, Type - $Type, Value - $Value, Timeout - $Timeout." -Source ${CmdletName}
  $NameOrPath = Set-StringFromVarLayered -VarToCheck $NameOrPath
  Write-Log -Message "Translated NameOrPath - $NameOrPath." -Source ${CmdletName}

  if ($Timeout.toLower() -eq 'null') { $Timeout = 90 }
  if ($NameOrPath -like "-*") { $waitForCreation = $False; $NameOrPath = $NameOrPath.substring(1) } 
  elseif ($NameOrPath -like "+*") { $waitForCreation = $True; $NameOrPath = $NameOrPath.substring(1) } 
  else { $waitForCreation = $True }

  Write-Log -Message "Set waitForCreation - $waitForCreation." -Source ${CmdletName}
  Start-Sleep -Seconds 2

  while($i -lt $Timeout) {
    Write-Log -Message "i = $i (-ls)? Timeout = $Timeout" -Source ${CmdletName}
    $run = $false

    if ($Type.ToLower() -eq "process") {
      $NameOrPath = $NameOrPath.Replace(".exe","")
      $Process = Get-Process -Name $NameOrPath -ErrorAction SilentlyContinue
      if ((($null -ne $Process) -and (-not($Process.Responding))) -or ($null -ne $Process)) { 
        if ($run -eq $false) { Write-Log -Message "$NameOrPath is active. Next check after: $waitTime s." -Source ${CmdletName}; }
        else { $run = $true }
        $RC = 0 
      } else { 
        if ($run -eq $false) { Write-Log -Message "No active $NameOrPath. Next check after: $waitTime s." -Source ${CmdletName}; }
        else { $run = $true }
        $RC = 1
      }
    }
    
    if (($Type.ToLower() -eq "file") -or ($Type.ToLower() -eq "dir") -or ($Type.ToLower() -eq "path")) {
      if ($Type.ToLower() -eq "file") { $path = Test-Path -Path $NameOrPath -PathType leaf }
      if ($Type.ToLower() -eq "dir") { $path = Test-Path -Path $NameOrPath -PathType container }
      if ($Type.ToLower() -eq "path") { $path = Test-Path -Path $NameOrPath -PathType any }
      if ($path -eq $true) { Write-Log -Message "$NameOrPath exist."; $RC = 0 } 
      else { Write-Log -Message "$NameOrPath is not exist." -Source ${CmdletName}; $RC = 1 }
    }

    if ($Type.ToLower() -eq "reg") {
      $NameOrPath = Convert-RegistryPath -Key $NameOrPath
      $tmp = $NameOrPath.Split("\")
      $name = $tmp[$tmp.Count - 1]
      $NameOrPathShort = $NameOrPath.Replace("\$name","")
      $RC = Test-Path -Path $NameOrPathShort
      $isKeyExist = Test-RegValExist -Path $NameOrPathShort -Name $name

      if ($Value.ToLower() -eq 'null') {
        if ($isKeyExist -eq $True) { Write-Log -Message "Registry entry exist."; $RC = 0 } 
        else { Write-Log -Message "Registry entry do not exist." -Source ${CmdletName}; $RC = 1 }
      } else { 
        if ($isKeyExist -eq $True) { 
          $RegValue = (Get-ItemProperty -Path $NameOrPathShort).$name
          if ($RegValue -eq $Value) { Write-Log -Message "Registry values are the same."; $RC = 0 } 
          else { Write-Log -Message "Registry values are different." -Source ${CmdletName}; $RC = 1 }
        } else { Write-Log -Message "Registry entry do not exist." -Source ${CmdletName}; $RC = 1 }
      }
    }

    Write-Log -Message "waitForCreation = $waitForCreation, RC = $RC." -Source ${CmdletName}

    if ((($waitForCreation -eq $True) -and ($RC -eq 0)) -or (($waitForCreation -eq $False) -and ($RC -eq 1))) { 
			Write-Log -Message "Success." -Source ${CmdletName};
			Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
			Return 0
		} 
    Start-Sleep -Seconds $waitTime 
    $i = $i + $waitTime 
  }

  Write-Log -Message "${CmdletName} - failed (missing parameters or timeout)." -Source ${CmdletName}
	Write-Log -Message "============================ Failing: $line ============================" -Source ${CmdletName}
  Set-Finalize -ExitCode 1
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-Lnk {
  <#
    .SYNOPSIS
      Will create,edit or remove .lnk files.  
    .DESCRIPTION
      Will add, remove and change MSI shortcuts.
    .PARAMETER actionName
      The name action type you want to trigger: ADD, EDIT or REMOVE can be used for LNK.
    .PARAMETER Data
      Data variable withh all information to execute function like:
      $SourceExe=Target exe path to which shortcut will lead.
      $DestinationPath=Where lnk schoul be created.
      $ArgumentsToSourceExe=Additional parameters for exe file execution.
      $lnkName=Shortcut name.
    .PARAMETER DataType
      As default is a null for LNK.
    .EXAMPLE
      Conf line: INSTALL,ADD,LNK,NotepadPP=C:\ProgramData\Microsoft\Windows\Start Menu\Programs=c:\localapps\notepad\bin\npp.exe=null=null,null - create a new shortcut to exe file.
    .EXAMPLE
      Conf line: INSTALL,REMOVE,LNK,NotepadPP=C:\ProgramData\Microsoft\Windows\Start Menu\Programs=null=null=null,null - will remove target .lnk.
    .NOTES
      This is an internal script function and should typically not be called directly, it will be triggered by main script if proper conf line will be found.
    .LINK
      https://github.kyndryl.net/wms-global/WMSAutomationTool/
  #>
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$DataType = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #INSTALL,ADD,LNK,lnkName=lnkPath=exePath=ArgumentsToSourceExe=StartInPath=IconLocation,null
  #INSTALL,REMOVE,LNK,lnkName=lnkPath=null=null=null,null
  #INSTALL,EDIT,LNK,lnkName=lnkPath=propertyName=PropertyValue=PropertyValue,null
  #"ModuleName,ActionName,MainName,DataShortcutName=DataDestLnkPath=DataPropertyName=DataPropertyValue,null"

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  If ($actionName.ToUpper() -eq "ADD") { 
    $lnkName = Set-StringFromVarLayered -VarToCheck $Data[0]
    $SourceExe = Set-StringFromVarLayered -VarToCheck $Data[2]
    $DestinationPath = Set-StringFromVarLayered -VarToCheck $Data[1]
    $ArgumentsToSourceExe = Set-StringFromVarLayered -VarToCheck $Data[3]
    $StartInPath = Set-StringFromVarLayered -VarToCheck $Data[4]
    $IconLocation = Set-StringFromVarLayered -VarToCheck $Data[5]
    
    if($lnkName.ToLower() -like "*.lnk") { $ext = "" }
    else { $ext = ".lnk" }

    $LnkPath = "$DestinationPath\$lnkName$ext"

    if (-not(Test-Path -Path $DestinationPath)) { New-Item -ItemType Directory -Path $DestinationPath }

    Write-Log -Message "Will try to create shortcut: $LnkPath to $SourceExe with arguments: $ArgumentsToSourceExe." -Source ${CmdletName}

    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($LnkPath)
    $Shortcut.TargetPath = $SourceExe
    if ($ArgumentsToSourceExe.ToLower() -ne "null") { $Shortcut.Arguments = $ArgumentsToSourceExe }
    if ($StartInPath.ToLower() -ne "null") { $Shortcut.WorkingDirectory = $StartInPath; Write-Log -Message "And:StartInPath = $StartInPath." -Source ${CmdletName} }
    if ($IconLocation.ToLower() -ne "null") { 
      if (-not(($IconLocation.toLower() -like "*:\*") -or ($IconLocation.toLower() -like "%*") -or ($IconLocation.toLower() -like "\\*"))) {
        $targetDir = "$($Global:KyndrylSRC)\$($Global:PKGName)"
        $newPath = "$targetDir\$IconLocation"
        If ((Test-Path -Path $targetDir) -eq $False) { New-Item -ItemType "directory" -Path "$targetDir" }
        If ((Test-Path -Path $newPath) -eq $True) { Remove-Item -Path "$newPath" -Force }
        Copy-Item "$($Global:SourcePath)\$IconLocation" -Destination "$targetDir"
        $IconLocation = $newPath
      }
      Write-Log -Message "And:IconLocation = $IconLocation." -Source ${CmdletName}
      $Shortcut.IconLocation = $IconLocation 
    }
    $Shortcut.Save()
  } elseIf ($actionName.ToUpper() -eq "REMOVE") { 
    $lnkName = $Data[0]
    $DestinationPath = $Data[1]
    
    Write-Log -Message "Will remove lnk using data: lnkName - $lnkName, DestinationPath - $DestinationPath."

    if($DestinationPath.toLower() -like "*%allusers%*") { $forAllUsers = $True }

    $DestinationPath = Set-StringFromVarLayered -VarToCheck $DestinationPath

    if($lnkName.ToLower() -like "*.lnk") { $ext = "" }
    else { $ext = ".lnk" }

    if (($lnkName.ToLower() -ne "null") -and ($DestinationPath.ToLower() -ne "null")) {
      $fileToRemove = "$DestinationPath\$lnkName$ext"
      if (Test-Path -Path $fileToRemove) { 
        Write-Log -Message "Will remove $fileToRemove." -Source ${CmdletName}
        Remove-Item -Path $DestinationPath -Force 
      } else { Write-Log -Message "$fileToRemove is missing, do not need to be removed. Going next." }
    } elseif (($lnkName.ToLower() -ne "null") -and ($DestinationPath.ToLower() -eq "null")) { 
      $lnkName = "$lnkName$ext"
      Write-Log -Message "Will search for $lnkName."

      $preDir = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"
      Write-Log -Message "Get-ChildItem -Path $preDir -Recurse" -Source ${CmdletName}
      $toremove = Get-ChildItem -Path "$preDir" -Recurse
      foreach ($file in $toremove) { 
        $filePath = $file.fullname
        $fileName = $file.name
        if (((Test-Path -Path $filePath -PathType "Leaf") -eq $True) -and ($fileName -eq $lnkName)) {
          Write-Log -Message "Removing $($file.fullname)" -Source ${CmdletName}
          Remove-item -Path $file.fullname -Force 
        }
      }
      
      ForEach ($User In (Get-WmiObject Win32_UserProfile -F "Special != True" | Select-Object -Expand LocalPath)) {
        #C:\Users\GrzegorzGorol\AppData\Roaming\Microsoft\Windows\Start Menu\Programs
        $preDirA = "\AppData\Roaming\Microsoft\Windows\Start Menu\Programs"
        $preDirB = "\Desktop"
        $targetA = "$($User)$preDirA"
        $targetA = $targetA.Replace(" \","\").Replace("\\","\")
        $targetB = "$($User)$preDirB"
        $targetB = $targetB.Replace(" \","\").Replace("\\","\")

        Write-Log -Message "Get-ChildItem -Path $targetA -Recurse" -Source ${CmdletName}
        Write-Log -Message "Get-ChildItem -Path $targetB" -Source ${CmdletName}

        $toremoveA = Get-ChildItem -Path "$targetA" -Recurse
        $toremoveB = Get-ChildItem -Path "$targetB"

        foreach ($file in $toremoveA) { 
          $filePath = $file.fullname
          $fileName = $file.name
          if (((Test-Path -Path $filePath -PathType "Leaf") -eq $True) -and ($fileName -eq $lnkName)) {
            Write-Log -Message "Removing $filePath" -Source ${CmdletName}
            Remove-item -Path $filePath -Force 
          }
        }
        foreach ($file in $toremoveB) { 
          $filePath = $file.fullname
          $fileName = $file.name
          if (((Test-Path -Path $filePath -PathType "Leaf") -eq $True) -and ($fileName -eq $lnkName)) {
            Write-Log -Message "Removing $filePath" -Source ${CmdletName}
            Remove-item -Path $filePath -Force 
          }
        }
      }
    } elseif (($lnkName.ToLower() -eq "null") -and ($DestinationPath.ToLower() -ne "null")) {
      if ($forAllUsers) {
        if ($Global:userActions.ToLower() -eq 'false') { 
          Write-Log -Message "Will skipp ${CmdletName} execution. userActions = $($Global:userActions)." -Source ${CmdletName} -Severity 3
          Write-Log -Message "For your account use an other method for actions in user context/manipulation of user profiles." -Source ${CmdletName} -Severity 3 
        } else {
          ForEach ($User In (Get-WmiObject Win32_UserProfile -F "Special != True" | Select-Object -Expand LocalPath)) {
            #C:\Users\GrzegorzGorol\AppData\Roaming\Microsoft\Windows\Start Menu\Programs
            $preDirA = "\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\"
            $target = "$($User)$preDirA$DestinationPath"
            $target = $target.Replace(" \","\").Replace("\\","\")
            Write-Log -Message "\User\$preDirA\DestinationPath - $target" -Source ${CmdletName}
            if (Test-Path -Path "$target") { 
              Write-Log -Message "Will remove $target." -Source ${CmdletName}
              Remove-Item "$target" -recurse -force 
            } else { Write-Log -Message "$target is missing, do not need to be removed. Going next." -Source ${CmdletName} }
          }
        }
      } else {
        #%ProgramData%\Microsoft\Windows\Start Menu\Programs
        #C:\ProgramData\Microsoft\Windows\Start Menu\Programs
        if ($DestinationPath -ne "*:\*") { $preDirA = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs" }
        else { $preDirA = "" }
        $target = "$preDirA$DestinationPath"
        if (Test-Path -Path "$target") { 
          Write-Log -Message "Will remove $target." -Source ${CmdletName}
          Remove-Item "$target" -recurse -force 
        } else { Write-Log -Message "$target is missing, do not need to be removed. Going next." -Source ${CmdletName} }
      }
    } else { Write-Log -Message "Params are missing, exiting script with RC = -1." -Source ${CmdletName}; Set-Finalize -ExitCode -1 }
  } elseIf ($actionName.ToUpper() -eq "EDIT") { 
    <# $LnkName = $Data[0]
    $LnkPath = $Data[1]
    $PropertyName = $Data[2]
    $PropertyValue = $Data[3]

    $fileName = $LnkName
    $folder = $LnkPath
    [string]$from = "\\uncpath1\shares\"
    [string]$to = $PropertyValue

    $list = Get-ChildItem -Path $folder -Filter $fileName -Recurse | Where-Object { $_.Attributes -ne "Directory" } | Select-Object -ExpandProperty FullName
    $obj = New-Object -ComObject WScript.Shell

    ForEach($lnk in $list) {
      $obj = New-Object -ComObject WScript.Shell
      $link = $obj.CreateShortcut($lnk)

      [string]$tmp = $link.TargetPath
      [string]$tmp = [string]$tmp.Replace($from.tostring(),$to.ToString())

      #If you need workingdirectory change please uncomment the below line.
      #$link.WorkingDirectory = [string]$WorkingDirectory.Replace($from.tostring(),$to.ToString())
      #$link.Arguments = "-arguments"

      $link.TargetPath = [string]$tmp
      $link.Save()
    } #>
  }
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-DetectionMethod {
  <#
    .SYNOPSIS
      Can check if action was successfully performed. 
    .DESCRIPTION
      Can test for negative or positive result. If - (minus sign) is added as first character on GUID, PKGName, File or Registry then script will end. If - not will be as result, if + or simply - will be missing test will be done for positive. Only one Data value is mandatory, but all of them can be used. 
      Function that can be used as Detection Method - it will exit script when conditions will be meet. If not, script will continue. For exit code -1 is a default value, but custom one can be set.
    .PARAMETER actionName
      The name action type you want to trigger: ADD can be used for DetectionMethod .
    .PARAMETER Data
      Data variable withh all information to execute function like:
      DataGUID=GUID or item in HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall or HKEY_LOCAL_MACHINE\SOFTWARE \Microsoft\Windows\CurrentVersion\Uninstall.
      DataPKGName=Defined PKGName for this application or package. 
      DataFilePath=Path to file to check. 
      DataREGPath=Path to registry item to check.
      DataREGVarValue=Registry item value to validate (if we are checking for value and not only for existing item). 
      ExitCodeValue=Custom exit code to exit with.
    .PARAMETER DataType
      As default is a null for DetectionMethod . 
      TestForAllNegative=True if you want to test for packages to use as Detection Method style like in SCCM. available: allNegative, allPositive, oneNegative, onePositive
    .EXAMPLE
      Conf line: PREINSTALL,ADD,DetectionMethod,-{AC76BA86-1033-FFFF-7760-0E1108756300}=null=null=null;null,-1400;true - will check if application was uninstalled, if not will exit with -1400.
    .EXAMPLE
      Conf line: UNINSTALL,ADD,DetectionMethod,null=null=-c:\windows\tmp\app.xml=null;null,null - will check if app.xml was removed.
    .NOTES
      This is an internal script function and should typically not be called directly, it will be triggered by main script if proper conf line will be found.
    .LINK
      https://github.kyndryl.net/wms-global/WMSAutomationTool/
  #>
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$DataType = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #INSTALL,ADD,DetectionMethod,GUID=PKGName=file=registry;regvalue,ExitCodeValue;allNegative
  #can test for negative or positive. If - is added as first sign on GUID, PKGName,File orRegistry then script will end if -not will be as result,
  #if + or simply - will be missing test will be done for positive.

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  $GUIDResult     = 0
  $TAGResult      = 0
  $FileResult     = 0
  $RegResult      = 0

  $ExitScript     = $False

  if($DataType -like "*;*") {
    $ExitCodeVars = $DataType.Split(";")
    $ExitCodeVarName = $ExitCodeVars[0]
    if($ExitCodeVars[1] -eq "null") { $allNegative = 'false' }
    else { $allNegative = $ExitCodeVars[1] }
  } else {
    $ExitCodeVarName = $DataType
    $allNegative = 'false'
  }

  Write-Log -Message "Test for allNegative - $allNegative" -Source ${CmdletName}
  Write-Log -Message "ExitCodeVarName - $ExitCodeVarName" -Source ${CmdletName}

  $AppGUID = Set-StringFromVarLayered -VarToCheck $Data[0]
  $AppPKGName = Set-StringFromVarLayered -VarToCheck $Data[1]
  $File = Set-StringFromVarLayered -VarToCheck $Data[2]
  $AppReg = $Data[3]
    $AppReg = $AppReg.Split(";")
    $RegPath = Set-StringFromVarLayered -VarToCheck $AppReg[0]
    $RegValue = Set-StringFromVarLayered -VarToCheck $AppReg[1]

  if ($AppGUID -like "-*") { $GUIDForNegative = $True; $AppGUID = $AppGUID.substring(1) } 
  else { 
    $GUIDForNegative = $False 
    if ($AppGUID -like "+*") { $AppGUID = $AppGUID.substring(1) }
  }

  if ($AppPKGName -like "-*") { $TAGForNegative = $True; $AppPKGName = $AppPKGName.substring(1) } 
  else { 
    $TAGForNegative = $False
    if ($AppPKGName -like "+*") { $AppPKGName = $AppPKGName.substring(1) } 
  }

  if ($File -like "-*") { $FILEForNegative = $True; $File = $File.substring(1) } 
  else { 
    $FILEForNegative = $False
    if ($File -like "+*") { $File = $File.substring(1) }  
  }

  Write-Log -Message "RegPath - $RegPath" -Source ${CmdletName}
  if ($RegPath -like "-*") {
    $REGForNegative = $True
    $RegPath = $RegPath.substring(1)
    Write-Log -Message "RegPath - $RegPath" -Source ${CmdletName}
  } else { 
    $REGForNegative = $False
    if ($RegPath -like "+*") { $RegPath = $RegPath.substring(1) } 
  }

  if ($AppGUID.ToLower() -ne "null") {
    $isInstalled = (Get-InstalledApplication -ProductCode $AppGUID).DisplayName
		Write-Log -Message "isInstalled - $isInstalled" -Source ${CmdletName}

		If ([string]::IsNullOrEmpty($isInstalled) -or ($isInstalled -eq "") -or $isInstalled -eq " ") {
			$ProdCode = (Get-InstalledApplication -Name $AppGUID).ProductCode

      If ([string]::IsNullOrEmpty($ProdCode) -or ($ProdCode -eq "") -or $ProdCode -eq " ") { $GUIDResult = 1 }
      else { $GUIDResult = 0 }
		} else { $GUIDResult = 0 }
  } else { $GUIDResult = 2 }

  if ($AppPKGName.ToLower() -ne "null") {
    $TAGFile = "$TagsDir\$AppPKGName.tag"
    Write-Log -Message "Testing: - $TAGFile" -Source ${CmdletName}

    if (Test-Path $TAGFile) { $TAGResult = 0 }
    else { $TAGResult = 1 }
  } else { $TAGResult = 2 }

  if ($File.ToLower() -ne "null") {
    if (Test-Path $File) { $FileResult = 0 }
    else { $FileResult = 1 }
  } else { $FileResult = 2 }

  if ($RegPath.ToLower() -ne "null") {
    $RegPathArr = $RegPath.split('\')
    $TMPRegPath = ""
    $TMPRegVar = $RegPathArr[-1]
    $x = 0
    foreach ($arrItem in $RegPathArr) {
      If ($arrItem -ne $TMPRegVar) {
        If ($x -eq 0) { $TMPRegPath = $arrItem }
        else { $TMPRegPath = "$TMPRegPath\$arrItem" }
      }
      $x++
    }

    $TestConstainer = Test-Path $RegPath -PathType 'Container'
    if ($RegValue.ToLower() -eq "null") {
      Write-Log -Message "No regValue option." -Source ${CmdletName}
      if ($TestConstainer) { $RegResult = 0 } 
      else {
        $TestRegVal = Test-RegistryValue -Key $TMPRegPath -Value $TMPRegVar
        if ($TestRegVal) { $RegResult = 0 }
        else { $RegResult = 1 }
      }
    } else {
      Write-Log -Message "RegValue option." -Source ${CmdletName}
      If (Test-RegistryValue -Key $TMPRegPath -Value $TMPRegVar) {
        #$ReadReg = Get-ItemPropertyValue $TMPRegPath -Name $TMPRegVar
        $ReadReg = Get-RegValue -KeyPath $TMPRegPath -ValueName $TMPRegVar
        Write-Log -Message "ReadReg - $ReadReg" -Source ${CmdletName}
        if (($ReadReg -like "*$RegValue") -or ($ReadReg -like "*$RegValue*") -or ($ReadReg -like "$RegValue") -or ($ReadReg -like "$RegValue*")) { $RegResult = 0 }
        else { $RegResult = 1 }
      } else { $RegResult = 1 }
    }
  } else { $RegResult = 2 }

  <# if ((($GUIDResult -eq 0) -and ($GUIDForNegative -eq $True)) -or (($GUIDResult -eq 1) -and ($GUIDForNegative -eq $False))) { $GUIDResult = 1 }
  else { $GUIDResult = 0 }
  if ((($TAGResult -eq 0) -and ($TAGForNegative -eq $True)) -or (($TAGResult -eq 1) -and ($TAGForNegative -eq $False))) { $TAGResult = 1 }
  else { $TAGResult = 0 }
  if ((($FileResult -eq 0) -and ($FILEForNegative -eq $True)) -or (($FileResult -eq 1) -and ($FILEForNegative -eq $False))) { $FileResult = 1 }
  else { $FileResult = 0 }
  if ((($RegResult -eq 0) -and ($REGForNegative -eq $True)) -or (($RegResult -eq 1) -and ($REGForNegative -eq $False))) { $RegResult = 1 }
  else { $RegResult = 0 } #>

  Write-Log -Message "Detection method, testing results are:" -Source ${CmdletName}
  Write-Log -Message "Test for: $AppGUID -----------------------------------------------------------------" -Source ${CmdletName}
  Write-Log -Message "GUIDResult: $GUIDResult" -Source ${CmdletName}
  Write-Log -Message "GUIDForNegative: $GUIDForNegative" -Source ${CmdletName}
  Write-Log -Message "Test for: $AppPKGName -----------------------------------------------------------------" -Source ${CmdletName}
  Write-Log -Message "TAGResult: $TAGResult" -Source ${CmdletName}
  Write-Log -Message "TAGForNegative: $TAGForNegative" -Source ${CmdletName}
  Write-Log -Message "Test for: $File -----------------------------------------------------------------" -Source ${CmdletName}
  Write-Log -Message "FileResult: $FileResult" -Source ${CmdletName}
  Write-Log -Message "FILEForNegative: $FILEForNegative" -Source ${CmdletName}
  Write-Log -Message "Test for: $AppReg -----------------------------------------------------------------" -Source ${CmdletName}
  Write-Log -Message "RegResult: $RegResult" -Source ${CmdletName}
  Write-Log -Message "REGForNegative: $REGForNegative" -Source ${CmdletName}

  #allNegative, allPositive, oneNegative, onePositive
      
  if (($GUIDForNegative -eq $True) -and ($GUIDResult -ne 0)) { $ExitScriptA = $True }
  elseif (($GUIDForNegative -eq $False) -and ($GUIDResult -eq 0)) { $ExitScriptA = $True }
  else { $ExitScriptA = $False }

  if (($TAGForNegative -eq $True) -and ($TAGResult -ne 0)) { $ExitScriptB = $True }
  elseif (($TAGForNegative -eq $False) -and ($TAGResult -eq 0)) { $ExitScriptB = $True }
  else { $ExitScriptB = $False }

  if (($FILEForNegative -eq $True) -and ($FileResult -ne 0)) { $ExitScriptC = $True }
  elseif (($FILEForNegative -eq $False) -and ($FileResult -eq 0)) { $ExitScriptC = $True }
  else { $ExitScriptC = $False }

  if (($REGForNegative -eq $True) -and ($RegResult -ne 0)) { $ExitScriptD = $True }
  elseif (($REGForNegative -eq $False) -and ($RegResult -eq 0)) { $ExitScriptD = $True }
  else { $ExitScriptD = $False }

  Write-Log -Message "ExitScriptA (GUID): $ExitScriptA" -Source ${CmdletName}
  Write-Log -Message "ExitScriptB (TAG) : $ExitScriptB" -Source ${CmdletName}
  Write-Log -Message "ExitScriptC (FILE): $ExitScriptC" -Source ${CmdletName}
  Write-Log -Message "ExitScriptD (REG) : $ExitScriptD" -Source ${CmdletName}

  if ($allNegative -eq 'oneNegative') {
    if (($ExitScriptA -eq $False) -or ($ExitScriptB -eq $False) -or ($ExitScriptC -eq $False) -or ($ExitScriptD -eq $False)) { $ExitScript = $True }
    else { $ExitScript = $False }
  } elseif ($allNegative -eq 'onePositive') {
    if (($ExitScriptA -eq $True) -or ($ExitScriptB -eq $True) -or ($ExitScriptC -eq $True) -or ($ExitScriptD -eq $True)) { $ExitScript = $True }
    else { $ExitScript = $False }
  } elseif (($allNegative -eq 'allNegative') -or ($allNegative -eq 'true')) {
    if (($ExitScriptA -eq $False) -and ($ExitScriptB -eq $False) -and ($ExitScriptC -eq $False) -and ($ExitScriptD -eq $False)) { $ExitScript = $True }
    else { $ExitScript = $False }
  } elseif (($allNegative -eq 'allPositive') -or ($allNegative -eq 'false')) {
    if (($ExitScriptA -eq $True) -and ($ExitScriptB -eq $True) -and ($ExitScriptC -eq $True) -and ($ExitScriptD -eq $True)) { $ExitScript = $True }
    else { $ExitScript = $False }
  } 

  Write-Log -Message "Result for: $allNegative = $ExitScript." -Source ${CmdletName}

  $ExitCodeVarName = $ExitCodeVarName.replace(' ','')

  if (($ExitCodeVarName -like "NULL*") -or ($ExitCodeVarName -like "null*") -or ($ExitCodeVarName -like "NULL") -or ($ExitCodeVarName -like "null")) { $ExitCodeVarName = 0 }
  else {
    try {
      $null = Get-Variable -Scope Global -Name $ExitCodeVarName -ErrorAction Stop
      $variableExists = $true
    } catch { $variableExists = $false }

    if ($variableExists) { $ExitCodeVarName = Get-Variable -Scope Global $ExitCodeVarName -ValueOnly }
  }

  [int]$intNum = [convert]::ToInt32($ExitCodeVarName, 10)

  If ($ExitScript -eq $True) { 
		Write-Log -Message "Tests passed, going to next function, RC = 0." -Source ${CmdletName}
		Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
	} else {
    Write-Log -Message "Will Exit Script - ExitCodeVarName = $ExitCodeVarName." -Source ${CmdletName}
		Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
    Set-Finalize -ExitCode $intNum
  }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-MsiAction {
  <#
    .SYNOPSIS
      Can install or uninstall msi based applications in single mode or batch mode.  
    .DESCRIPTION
      For uninstall GUID can be replaced by application name, * can be also used. MSI, MST, MSP installation/uninstallation module. It can handle automated installation and upgrade of older, installed version. Only one Data value is mandatory, but all of them can be used. Only DataMSTFile cannot be used without DataMSIFile. 
    .PARAMETER actionName
      The name action type you want to trigger: ADD or REMOVE can be used for MSI.
    .PARAMETER Data
      Data variable withh all information to execute function like:
      DataGUID=GUID or item in HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall or HKEY_LOCAL_MACHINE\SOFTWARE \Microsoft\Windows\CurrentVersion\Uninstall.
      DataPKGName=Defined PKGName for this application or package. 
      DataFilePath=Path to file to check. 
      DataREGPath=Path to registry item to check.
      DataREGVarValue=Registry item value to validate (if we are checking for value and not only for existing item). 
      ExitCodeValue=Custom exit code to exit with.
    .PARAMETER DataType
      As default is a null for MSI . 
      DataProcessName=Process to check in case of packages when some installation processes work after main process is closed.
      DataMSIEXECParams=Additional MSIEXEC parameters to be passed to MSI.
    .EXAMPLE
      Conf line: UNINSTALL,REMOVE,MSI,CiscoMeeting*=null=Cisco_CiscoMeeting_1.9.19.0_W10_EN_B1,null - will uninstall all applications with name CiscoMeeting.
    .EXAMPLE
      Conf line: INSTALL,ADD,MSI,ciscoSetup.msi=Cisco_CiscoMeeting_1.9.10.0_W10_EN_B1.mst=null=Cisco_CiscoMeeting_1.9.10.0_W10_EN_B1,null;null - will install Cisco Meeting with a provided mst file.
    .NOTES
      This is an internal script function and should typically not be called directly, it will be triggered by main script if proper conf line will be found.
    .LINK
      https://github.kyndryl.net/wms-global/WMSAutomationTool/
  #>
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $True)]
    [String]$DataType,
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #INSTALL,ADD,MSI,MSIFile=MSTFile=MSPFile=Cisco_CiscoMeeting_1.9.10.0_SCH_W10_EN_B1,setup.exe;param=va param=var2
  #UNINSTALL,REMOVE,MSI,{5DD37F97-3F65-4C24-B80D-D12913A4D214}=version=Cisco_CiscoMeeting_1.9.19.0_SCH_W10_EN_B1,null

	if ($line -ne " ") {
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}
	}
	
  $MSIParams = 'null'
  $SuccessCode = '3010,0'
  $MSIFiles = $null

  $tempForValidation = Get-Variable "msiAdditionalSuccessCode" -ErrorAction SilentlyContinue
  If (-not([string]::IsNullOrEmpty($tempForValidation))) { $SuccessCode = "$SuccessCode,$($tempForValidation.Value)" }

  if (($DataType -like "*;*") -or ($DataType -like "*;")) {
    $TmpVar = $DataType.Split(";")
    $processName = $TmpVar[0]
    $x = 0

    foreach ($item in $TmpVar) {
      Write-Log -Message "item $x = $item" -Source ${CmdletName}
      if ($x -eq 0) { Write-Log -Message "Will skip item: $item" -Source ${CmdletName} }
      elseif ($x -eq 1) { $MSIParams = $item }
      else { $MSIParams = $MSIParams + ";" + $item }
      $x++
    }
    
    $iniMsiexecAdditionalParams = Set-SpecialCharacters -string $Global:msiexecAdditionalParams

    #$MSIParams = $TmpVar[1]
    Write-Log -Message "&&&&&&&&&&&&&&&&&&&&&&&" -Source ${CmdletName}
    Write-Log -Message "TmpVar.Length = $($TmpVar.Length)" -Source ${CmdletName}
    Write-Log -Message "MSIParams = $MSIParams" -Source ${CmdletName}
    Write-Log -Message "iniMsiexecAdditionalParams = $iniMsiexecAdditionalParams" -Source ${CmdletName}
    Write-Log -Message "SuccessCode = $SuccessCode" -Source ${CmdletName}
    Write-Log -Message "&&&&&&&&&&&&&&&&&&&&&&&" -Source ${CmdletName}
    
  } else { $processName = $DataType }

  Write-Log -Message "MSIParams - $MSIParams" -Source ${CmdletName}
  $MSIParams = Set-StringFromVarLayered -VarToCheck $MSIParams
  $MSIParams = Set-SpecialCharacters -string $MSIParams
  #$MSIParams = $MSIParams.Replace("|",",").Replace("><","=")

  if ((-not([string]::IsNullOrWhitespace($iniMsiexecAdditionalParams))) -and (-not([string]::IsNullOrEmpty($iniMsiexecAdditionalParams))) -and ($iniMsiexecAdditionalParams.ToUpper() -ne "N/A")) { 
    if ($MSIParams.ToLower() -ne "null") { $MSIParams = $MSIParams + " " + $iniMsiexecAdditionalParams }
    else { $MSIParams = $iniMsiexecAdditionalParams }
  }

  Write-Log -Message "MSIParams - $MSIParams" -Source ${CmdletName}

  If ($actionName.ToUpper() -eq "ADD") {
    $MSIFile = Set-StringFromVarLayered -VarToCheck $Data[0]
    $MSTFile = Set-StringFromVarLayered -VarToCheck $Data[1]
    $MSPFile = Set-StringFromVarLayered -VarToCheck $Data[2]
    $PKGName = Set-StringFromVarLayered -VarToCheck $Data[3]

    Write-Log -Message "${CmdletName} got Data: " -Source ${CmdletName}
    Write-Log -Message "MSIFile - $MSIFile" -Source ${CmdletName}
    Write-Log -Message "MSTFile - $MSTFile" -Source ${CmdletName}
    Write-Log -Message "MSPFile - $MSPFile" -Source ${CmdletName}

    $lastChar = $MSIFile.Substring($MSIFile.Length-1,1)
    Write-Log -Message "Testing $MSIFile last char = $lastChar" -Source ${CmdletName}
    if ($lastChar -eq "\") { 
      $MSIFile = $MSIFile.Substring(0,$MSIFile.Length-1)
      Write-Log -Message "MSIFile is a path, will gather all MSIs from it ($MSIFile)." -Source ${CmdletName}
      $MSIFiles = (Get-ChildItem -Path "$MSIFile" -Filter *.msi).FullName
    } else { $MSIFiles = $null }

    if ("null" -ne $MSIFile.ToLower()) { $MSIFile = Get-FullPath -path $MSIFile }
    if ("null" -ne $MSTFile.ToLower()) { $MSTFile = Get-FullPath -path $MSTFile }
    if ("null" -ne $MSPFile.ToLower()) { $MSPFile = Get-FullPath -path $MSPFile }

    #if (("null" -ne $MSIFile.ToLower()) -and (($MSIFile -like "\*") -or (((-not ($MSIFile -like "*:\*")) -and (-not ($MSIFile -like "*%*")))) -or (-not ($MSIFile -like "\\*")))) { $MSIFile = "$Global:SourcePath\$MSIFile"}
    #if (("null" -ne $MSTFile.ToLower()) -and (($MSTFile -like "\*") -or (((-not ($MSTFile -like "*:\*")) -and (-not ($MSTFile -like "*%*")))) -or (-not ($MSTFile -like "\\*")))) { $MSTFile = "$Global:SourcePath\$MSTFile"}
    #if (("null" -ne $MSPFile.ToLower()) -and (($MSPFile -like "\*") -or (((-not ($MSPFile -like "*:\*")) -and (-not ($MSPFile -like "*%*")))) -or (-not ($MSPFile -like "\\*")))) { $MSPFile = "$Global:SourcePath\$MSPFile"}
    If ('null' -eq $PKGName.ToLower()) { $PKGName = '' }

    if ([string]::IsNullOrWhitespace($MSIFiles)) { 
      Write-Log -Message "Adding MSIFile($MSIFile) to MSIFiles." -Source ${CmdletName}
      $MSIFiles = @($MSIFile) 
    }

    Write-Log -Message "-------------------------------------------------" -Source ${CmdletName}
    Write-Log -Message "MSIFile - $MSIFile" -Source ${CmdletName}
    Write-Log -Message "MSTFile - $MSTFile" -Source ${CmdletName}
    Write-Log -Message "MSPFile - $MSPFile" -Source ${CmdletName}
    Write-Log -Message "PKGName - $PKGName" -Source ${CmdletName}
    if (-not([string]::IsNullOrWhitespace($MSIFiles))) { 
      foreach ($msi in $MSIFiles) { Write-Log -Message "Bundle MSIfile - $msi" -Source ${CmdletName} }
    }
    Write-Log -Message "-------------------------------------------------" -Source ${CmdletName}

    $RC = Get-ParamCheck -ParamName "MSPFile" -Param $MSPFile

    foreach ($MSIFile in $MSIFiles) {
      If ($RC -eq $False) {
        if ((-not($MSIFile.ToLower() -like "*.msi")) -and ($MSIFile.ToLower() -ne 'null')) { $MSIFile = "$MSIFile.msi" }
        Write-Log -Message "Test-ParamFile -path $MSIFile." -Source ${CmdletName}
        Test-ParamFile -path $MSIFile

        If ((Get-ParamCheck -ParamName "MSTFile" -Param $MSTFile) -eq $False) { 
          $CurrentMSIGUID = Get-MsiTableProperty -Path "$MSIFile" -Table 'Property' | Select-Object -ExpandProperty 'ProductCode'
          $CurrentMSIAppName = Get-MsiTableProperty -Path "$MSIFile" -Table 'Property' | Select-Object -ExpandProperty 'ProductName'
          $CurrentMSIAppVer = Get-MsiTableProperty -Path "$MSIFile" -Table 'Property' | Select-Object -ExpandProperty 'ProductVersion'
          Write-Log -Message "CurrentMSIGUID - $CurrentMSIGUID for $MSIFile." -Source ${CmdletName}
          Write-Log -Message "CurrentMSIAppName - $CurrentMSIAppName for $MSIFile." -Source ${CmdletName}
          Write-Log -Message "CurrentMSIAppVer - $CurrentMSIAppVer for $MSIFile." -Source ${CmdletName}
        } Else { 
          Write-Log -Message "Test-ParamFile -path $MSTFile." -Source ${CmdletName}
          Test-ParamFile -path $MSTFile
          $CurrentMSIGUID = Get-MsiTableProperty -Path "$MSIFile" -TransformPath "$MSTFile" -Table 'Property' | Select-Object -ExpandProperty 'ProductCode'
          $CurrentMSIAppName = Get-MsiTableProperty -Path "$MSIFile" -TransformPath "$MSTFile" -Table 'Property' | Select-Object -ExpandProperty 'ProductName'
          $CurrentMSIAppVer = Get-MsiTableProperty -Path "$MSIFile" -TransformPath "$MSTFile" -Table 'Property' | Select-Object -ExpandProperty 'ProductVersion'
          Write-Log -Message "CurrentMSIGUID - $CurrentMSIGUID for $MSIFile." -Source ${CmdletName}
          Write-Log -Message "CurrentMSIAppName - $CurrentMSIAppName for $MSIFile." -Source ${CmdletName}
          Write-Log -Message "CurrentMSIAppVer - $CurrentMSIAppVer for $MSIFile." -Source ${CmdletName}
        }

        $regGUID = Get-InstalledApplication -ProductCode $CurrentMSIGUID
        $regName = Get-InstalledApplication -Name $CurrentMSIAppName

        if ($CurrentMSIGUID -eq $regGUID) {
          Write-Log -Message "Uninstalling $CurrentMSIGUID." -Source ${CmdletName}
          Remove-MSIApplications -Name $CurrentMSIGUID -LogNameV $PKGName
        } elseif ($CurrentMSIAppName -eq $regName) {
          Write-Log -Message "Uninstalling $CurrentMSIAppName." -Source ${CmdletName}
          Remove-MSIApplications -Name $CurrentMSIAppName -LogNameV $PKGName
        }
      }

      if (("null" -ne $MSIFile.ToLower())) {
        If (((Get-ParamCheck -ParamName "MSTFile" -Param $MSTFile) -eq $True) -and ((Get-ParamCheck -ParamName "MSIFile" -Param $MSIFile) -eq $True)) {
          if ((-not($MSIFile.ToLower() -like "*.msi")) -and ($MSIFile.ToLower() -ne 'null')) { $MSIFile = "$MSIFile.msi" }
          if ((-not($MSTFile.ToLower() -like "*.mst")) -and ($MSTFile.ToLower() -ne 'null')) { $MSTFile = "$MSTFile.mst" }
          Test-ParamFile -path $MSTFile
          Test-ParamFile -path $MSIFile

          if ($MSIParams -ne 'null') { Execute-MSI -Action 'Install' "$MSIFile" -Transform "$MSTFile" -LogNameV $PKGName -AddParameters "$MSIParams" }
          else { Execute-MSI -Action 'Install' "$MSIFile" -Transform "$MSTFile" -LogNameV $PKGName }

          if ($processName -ne 'null') { Test-InstState -procName $processName -PKGName $PKGName }
        } elseif (((Get-ParamCheck -ParamName "MSTFile" -Param $MSTFile) -eq $False) -and ((Get-ParamCheck -ParamName "MSIFile" -Param $MSIFile) -eq $True)) {
          if ((-not($MSIFile.ToLower() -like "*.msi")) -and ($MSIFile.ToLower() -ne 'null')) { $MSIFile = "$MSIFile.msi" }
          if ((-not($MSTFile.ToLower() -like "*.mst")) -and ($MSTFile.ToLower() -ne 'null')) { $MSTFile = "$MSTFile.mst" }
          Test-ParamFile -path $MSTFile
          Test-ParamFile -path $MSIFile

          if ($MSIParams -ne 'null') { Execute-MSI -Action 'Install' "$MSIFile" -LogNameV $PKGName -AddParameters "$MSIParams" }
          else { Execute-MSI -Action 'Install' "$MSIFile" -LogNameV $PKGName }
          if ($processName -ne 'null') { Test-InstState -procName $processName -PKGName $PKGName }
        }
      }

      if ((Get-ParamCheck -ParamName "MSPFile" -Param $MSPFile) -eq $True) {
        if ((-not($MSPFile.ToLower() -like "*.msp")) -and ($MSPFile.ToLower() -ne 'null')) { $MSPFile = "$MSPFile.msp" }
        Test-ParamFile -path $MSPFile; 
        Execute-MSP -Path "$MSPFile" 
      }

      If (($PKGName -ne '') -and ($TAGType -eq 'FILE')) {
        If (-not(Test-Path "$TagsDir")) { New-Item -ItemType Directory -Path $TagsDir }
        If (-not(Test-Path "$TagsDir\$PKGName.tag")) { New-Item -Path "$TagsDir\$PKGName.tag" -ItemType File }
      }
    }
  } elseif ($actionName.ToUpper() -eq "REMOVE") {
    $MSIGUID = Set-StringFromVarLayered -VarToCheck $Data[0]
    $MSIVer = Set-StringFromVarLayered -VarToCheck $Data[1]
    $PKGName = Set-StringFromVarLayered -VarToCheck $Data[2]

    If (($MSIGUID -like "*;*") -or ($MSIGUID -like ";*") -or ($MSIGUID -like "*;")) {
      $MSIGUIDs = $MSIGUID.Split(";")
      $multiUninstall = $True
      $x = 0
      foreach ($guid in $MSIGUIDs) {
        if ($guid.ToLower() -like "*.msi") {
          $TmpMSIFile = Set-StringFromVarLayered -VarToCheck $guid
          if ("null" -ne $TmpMSIFile) { $TmpMSIFile = Get-FullPath -path $TmpMSIFile }
          #if (("null" -ne $TmpMSIFile) -and (($TmpMSIFile -like "\*") -or (((-not ($TmpMSIFile -like "*:\*")) -and (-not ($TmpMSIFile -like "*%*")) -and (-not ($TmpMSIFile -like "\\*")))))) { $TmpMSIFile = "$Global:SourcePath\$TmpMSIFile"}
          
          $CurrentMSIGUID = Get-MsiTableProperty -Path "$TmpMSIFile" -Table 'Property' | Select-Object -ExpandProperty 'ProductCode' 
          $CurrentMSIAppName = Get-MsiTableProperty -Path "$TmpMSIFile" -Table 'Property' | Select-Object -ExpandProperty 'ProductName'
          $CurrentMSIAppVer = Get-MsiTableProperty -Path "$TmpMSIFile" -Table 'Property' | Select-Object -ExpandProperty 'ProductVersion'
          Write-Log -Message "CurrentMSIGUID - $CurrentMSIGUID for $TmpMSIFile." -Source ${CmdletName}
          Write-Log -Message "CurrentMSIAppName - $CurrentMSIAppName for $TmpMSIFile." -Source ${CmdletName}
          Write-Log -Message "CurrentMSIAppVer - $CurrentMSIAppVer for $TmpMSIFile." -Source ${CmdletName}
          Write-Log -Message "Owerriding msi file for GUID." -Source ${CmdletName}
          $MSIGUIDs[$x] = $CurrentMSIGUID
          $MSINames[$x] = $CurrentMSIAppName
          $MSIVers[$x] = $CurrentMSIAppVer
          $x++
        }
      }
    } else {
      $multiUninstall = $False
      if ($MSIGUID.ToLower() -like "*.msi") {
        $MSIGUID = Set-StringFromVarLayered -VarToCheck $MSIGUID
        Write-Log -Message "MSIGUID is a file: $MSIGUID." -Source ${CmdletName}
        #if (("null" -ne $MSIGUID) -and (($MSIGUID -like "\*") -or (((-not ($MSIGUID -like "*:\*")) -and (-not ($MSIGUID -like "*%*")) -and (-not ($MSIGUID -like "\\*")) )))) { 
        if ("null" -ne $MSIGUID) { 
          $MSIGUID = Get-FullPath -path $MSIGUID
          #$MSIGUID = "$Global:SourcePath\$MSIGUID"
          Write-Log -Message "MSI file full path: $MSIGUID." -Source ${CmdletName}
        }
        
        $CurrentMSIGUID = Get-MsiTableProperty -Path "$MSIGUID" -Table 'Property' | Select-Object -ExpandProperty 'ProductCode' 
        $CurrentMSIAppName = Get-MsiTableProperty -Path "$MSIGUID" -Table 'Property' | Select-Object -ExpandProperty 'ProductName'
        $CurrentMSIAppVer = Get-MsiTableProperty -Path "$MSIGUID" -Table 'Property' | Select-Object -ExpandProperty 'ProductVersion'
        Write-Log -Message "CurrentMSIGUID - $CurrentMSIGUID for $MSIGUID." -Source ${CmdletName}
        Write-Log -Message "CurrentMSIAppName - $CurrentMSIAppName for $TmpMSIFile." -Source ${CmdletName}
        Write-Log -Message "CurrentMSIAppVer - $CurrentMSIAppVer for $TmpMSIFile." -Source ${CmdletName}
        Write-Log -Message "Owerriding msi file for GUID." -Source ${CmdletName}
        $MSIGUID = $CurrentMSIGUID
        $MSINames = $CurrentMSIAppName
        $MSIVers = $CurrentMSIAppVer
        $x++
      }
    }

		If ($multiUninstall -eq $True) {
			If (($PKGName -like "*;*") -or ($PKGName -like ";*") -or ($PKGName -like "*;")) {
				$PKGNames = $PKGName.Split(";")
				$multiPKGName = $True
			} else { $multiPKGName = $False }

			$x = 0

			ForEach ($MSIName in $MSIGUIDs) {
				If ($multiPKGName -eq $True) { $PKGName = $PKGNames[$x] }
        else { If ($PKGName -eq 'null') { $PKGName = $MSIName } }
        $isinstalled = $False

        $appData = Get-InstalledApplication -ProductCode $MSIName

        If (-not([string]::IsNullOrWhiteSpace($appData.DisplayName))) { $isinstalled = $True }
        else { 
          $appData = Get-InstalledApplication -Name $MSIName 
          If (-not([string]::IsNullOrWhiteSpace($appData.DisplayName))) { $isinstalled = $True }
          else {
            $appData = Get-InstalledApplication -Name $MSIName -WildCard $True
            If (-not([string]::IsNullOrWhiteSpace($appData.DisplayName))) { $isinstalled = $True }
          }
        }

        If (($isinstalled -eq $True) -and (-not([string]::IsNullOrWhiteSpace($appData.DisplayName)))) { $ProdName = $appData.DisplayName }
        If (($isinstalled -eq $True) -and (-not([string]::IsNullOrWhiteSpace($appData.DisplayVersion)))) { $ProdVer = $appData.DisplayVersion }
        If (($isinstalled -eq $True) -and (-not([string]::IsNullOrWhiteSpace($appData.ProductCode)))) { $ProdCode = $appData.ProductCode }
        
        if ($PKGName.ToLower() -eq "null") { $PKGName = $ProdCode }

        if ($isinstalled -eq $True) {
					If ($ProdCode -is [array]) {
            if ($MSIParams.ToLower() -ne 'null') { Remove-MSIApplications -Name $ProdName -LogNameV $PKGName[0] -AddParameters "$MSIParams" }
            else { Remove-MSIApplications -Name $ProdName -LogNameV $PKGName[0] }
          } else {
            if ($MSIParams.ToLower() -ne 'null') { Remove-MSIApplications -Name $ProdName -LogNameV $PKGName -AddParameters "$MSIParams" }
            else { Remove-MSIApplications -Name $ProdName -LogNameV $PKGName }
            if ($processName.ToLower() -ne 'null') { Test-InstState -procName $processName -PKGName $PKGName }
          }
				}
				$x++
			}
		} else {
      $isInstalled = (Get-InstalledApplication -ProductCode $MSIGUID).DisplayName
      Write-Log -Message "isInstalled - $isInstalled" -Source ${CmdletName}
      
      $LastOne = $MSIGUID.Substring($MSIGUID.get_Length()-1)

      Write-Log -Message "Checking if AppName contains wildcard: WildCard - $WildCard." -Source ${CmdletName}

      if($LastOne -eq "*") { $WildCard = $True } 
      else { $WildCard = $False }

      $ProdCode = (Get-InstalledApplication -WildCard $WildCard -Name $MSIGUID).ProductCode
      $ProdVer = (Get-InstalledApplication  -WildCard $WildCard -Name $MSIGUID).DisplayVersion
      $ProdName = (Get-InstalledApplication -WildCard $WildCard -Name $MSIGUID).DisplayName

      if (([string]::IsNullOrEmpty($ProdCode) -or ($ProdCode -eq "") -or $ProdCode -eq " ") -and ([string]::IsNullOrEmpty($ProdVer) -or ($ProdVer -eq "") -or $ProdVer -eq " ") -and (-not([string]::IsNullOrEmpty($isInstalled)) -and ($isInstalled -ne "") -and $isInstalled -ne " ")) {
        #fo.*ly
        $ProdCode = (Get-InstalledApplication -Name $isInstalled -WildCard $WildCard).ProductCode
        $ProdVer = (Get-InstalledApplication -Name $isInstalled -WildCard $WildCard).DisplayVersion
        $ProdName = (Get-InstalledApplication -Name $isInstalled -WildCard $WildCard).DisplayName
      }

      if ($ProdCode -is [Object[]]) {  #new method to handle wildcard based names for multi uninstall
        #TODO: add params and logname chandling.
        $MSIGUID = $MSIGUID.Replace("*","")
        Remove-MSIApplications -Name $MSIGUID
      }

      
      if (-not([string]::IsNullOrEmpty($ProdCode)) -and ($ProdCode -ne "") -and ($ProdCode -ne " ")) { 
        if (-not([string]::IsNullOrEmpty($ProdName)) -and ($ProdName -ne "") -and ($ProdName -ne " ")) { 
          $isInstalled = $ProdName 
        }
        $MSIGUID = $ProdCode 
      }

      Write-Log -Message "Data from registry: $isInstalled with GUID = $ProdCode and version = $ProdVer." -Source ${CmdletName}
      Write-Log -Message "Data from .conf: $isInstalled with GUID/Name = $MSIGUID and version = $MSIVer." -Source ${CmdletName}

      if ($MSIVer.ToLower() -eq 'null') {
        If ([string]::IsNullOrEmpty($isInstalled) -or ($isInstalled -eq "") -or ($isInstalled -eq " ")) {
          Write-Log -Message "MSI not found by $MSIGUID. MSIGUID probabbly is a name, not a GUID. Will uninstall using application name" -Source ${CmdletName}
          if ($MSIParams.ToLower() -ne 'null') {
            If ($PKGName.ToLower() -ne 'null') { Remove-MSIApplications -Name $MSIGUID -LogNameV $PKGName -AddParameters "$MSIParams" }
            else { Remove-MSIApplications -Name $MSIGUID -AddParameters "$MSIParams" }
          } else {
            If ($PKGName.ToLower() -ne 'null') { Remove-MSIApplications -Name $MSIGUID -LogNameV $PKGName }
            else { Remove-MSIApplications -Name $MSIGUI }
          }
          if ($processName.ToLower() -ne 'null') { Test-InstState -procName $processName -PKGName $PKGName }
        } else {
          Write-Log -Message "MSI found by GUID with name: $isInstalled." -Source ${CmdletName}
          Write-Log -Message "Will uninstall without version checking: $MSIGUID." -Source ${CmdletName}
          if ($MSIGUID -is [array]) { Write-Log -Message "MSIGUID is an array, will handle it separetly." -Source ${CmdletName} }

          foreach ($guidItem in $MSIGUID) {
            if (-not([string]::IsNullOrWhitespace($guidItem))) {
              Write-Log -Message "Proceeding with: $guidItem." -Source ${CmdletName}
              $isInstalled2nd = (Get-InstalledApplication -ProductCode $guidItem).DisplayName
              if (-not([string]::IsNullOrEmpty($isInstalled2nd)) -and ($isInstalled2nd -ne "") -and ($isInstalled2nd -ne " ")) { 
                if ($MSIParams.ToLower() -ne 'null') {
                  If ($PKGName.ToLower() -ne 'null') { Execute-MSI -Action 'Uninstall' -Path "$guidItem" -AddParameters "$MSIParams" -LogName $PKGName }
                  else { Execute-MSI -Action 'Uninstall' -Path "$guidItem" -AddParameters "$MSIParams" }
                } else {
                  If ($PKGName.ToLower() -ne 'null') { Execute-MSI -Action 'Uninstall' -Path "$guidItem" -LogName $PKGName }
                  else { Execute-MSI -Action 'Uninstall' -Path "$guidItem" }
                }
              }
            }
          }
          
          if ($processName.ToLower() -ne 'null') { Test-InstState -procName $processName -PKGName $PKGName }
          if ($processName.ToLower() -ne 'null') { Test-InstState -procName $processName -PKGName $PKGName }
        }

        If (($PKGName.ToLower() -ne '') -and ($TAGType.ToUpper() -eq 'FILE')) {
          If (Test-Path "$TagsDir\$PKGName.tag") { Remove-Item -Path "$TagsDir\$PKGName.tag" }
          If (Test-Path "$TagsDir") { If ((Get-ChildItem -Path $TagsDir -force | Select-Object -First 1 | Measure-Object).Count -eq 0) { Remove-Item -Path $TagsDir -Force -Recurse } }
        }
      } elseif (($ProdVer -ne $MSIVer) -and ($MSIVer -ne 'null' -and (-not([string]::IsNullOrEmpty($MSIVer)) -and ($MSIVer -ne "") -and $MSIVer -ne " "))) {
        Write-Log -Message "Will not uninstall because ProdVer($ProdVer) != MSIVer($MSIVer)." -Source ${CmdletName}
      } elseif (($ProdVer -ne $MSIVer) -and ($MSIVer -ne 'null' -and (-not([string]::IsNullOrEmpty($MSIVer)) -and ($MSIVer -ne "") -and $MSIVer -ne " "))) {
        Write-Log -Message "Will uninstall using version because ProdVer($ProdVer) = MSIVer($MSIVer)." -Source ${CmdletName}

        If ([string]::IsNullOrEmpty($isInstalled) -or ($isInstalled -eq "") -or $isInstalled -eq " ") {
          Write-Log -Message "MSI not found by $MSIGUID. MSIGUID probabbly is a name, not a GUID. Will uninstall using application name" -Source ${CmdletName}
          if ($MSIParams.ToLower() -ne 'null') {
            If ($PKGName.ToLower() -ne 'null') { Remove-MSIApplications -Name $MSIGUID -LogNameV $PKGName -AddParameters "$MSIParams" -FilterApplication ('DisplayVersion', $MSIVer, 'Exact') }
            else { Remove-MSIApplications -Name $MSIGUID -AddParameters "$MSIParams" -FilterApplication ('DisplayVersion', $MSIVer, 'Exact') }
          } else {
            If ($PKGName.ToLower() -ne 'null') { Remove-MSIApplications -Name $MSIGUID -LogNameV $PKGName -FilterApplication ('DisplayVersion', $MSIVer, 'Exact') }
            else { Remove-MSIApplications -Name $MSIGUI -FilterApplication ('DisplayVersion', $MSIVer, 'Exact') }
          }
          if ($processName.ToLower() -ne 'null') { Test-InstState -procName $processName -PKGName $PKGName }
        } else {
          if ($MSIParams.ToLower() -ne 'null') {
            If ($PKGName.ToLower() -ne 'null') { Remove-MSIApplications -Name $isInstalled -LogNameV $PKGName -AddParameters "$MSIParams" -FilterApplication ('DisplayVersion', $MSIVer, 'Exact') }
            else { Remove-MSIApplications -Name $isInstalled -AddParameters "$MSIParams" -FilterApplication ('DisplayVersion', $MSIVer, 'Exact') }
          } else {
            If ($PKGName.ToLower() -ne 'null') { Remove-MSIApplications -Name $isInstalled -LogNameV $PKGName -FilterApplication ('DisplayVersion', $MSIVer, 'Exact') }
            else { Remove-MSIApplications -Name $isInstalled -FilterApplication ('DisplayVersion', $MSIVer, 'Exact') }
          }
          if ($processName.ToLower() -ne 'null') { Test-InstState -procName $processName -PKGName $PKGName }
        }

        If (($PKGName -ne '') -and ($TAGType.ToUpper() -eq 'FILE')) {
          If (Test-Path "$TagsDir\$PKGName.tag") { Remove-Item -Path "$TagsDir\$PKGName.tag" }
          If (Test-Path "$TagsDir") { If ((Get-ChildItem -Path $TagsDir -force | Select-Object -First 1 | Measure-Object).Count -eq 0) { Remove-Item -Path $TagsDir -Force -Recurse } }
        }
      }
    }
  }
  if ($line -ne " ") { Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName} }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-Driver {
  <#
    .SYNOPSIS
      Can install or uninstall inf based drivers.  
    .DESCRIPTION
      Functionality will install/uninstall all inf based drivers from pointed location. No need for any additional parameters. If installation fail, then other method for installation should be used, e.g.: exe action based.   
    .PARAMETER actionName
      The name action type you want to trigger: ADD or REMOVE can be used for DRIVER.
    .PARAMETER Data
      Data variable withh all information to execute function like:
      DataDriversDirectoryPath=folder where drivers (.inf files) are located. 
    .PARAMETER DataType
      As default is a null for DRIVER. 
    .EXAMPLE
      Conf line: PREINSTALL,REMOVE,DRIVER,c:\driver,null - will uninstall inf drivers from driver folder.
    .EXAMPLE
      Conf line: PREINSTALL,ADD,DRIVER,c:\driver,null - will install inf drivers from driver folder.
    .NOTES
      This is an internal script function and should typically not be called directly, it will be triggered by main script if proper conf line will be found.
    .LINK
      https://github.kyndryl.net/wms-global/WMSAutomationTool/
  #>
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$ActionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #PREINSTALL,REMOVE,DRIVER,$driverFolderDirectory,null  
  #PREINSTALL,ADD,DRIVER,$driverFolderDirectory,null  
  
  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  Write-Log -Message "Will $actionName Driver." -Source ${CmdletName}
  $driverFolderDirectory = Set-StringFromVarLayered -VarToCheck $Data[0]

  If ($actionName.ToUpper() -eq "REMOVE") { 
    if ($driverFolderDirectory.ToLower() -like "*.inf") {
      Write-Log -Message "Will uninstall $driverFolderDirectory driver." -Source ${CmdletName}
      PNPUtil.exe /delete-driver $driverFolderDirectory /uninstall /force
    } else {
      Write-Log -Message "Will search in $driverFolderDirectory for all drivers and uninstall them." -Source ${CmdletName}
      Get-ChildItem "$driverFolderDirectory" -Recurse -Filter "*inf" | ForEach-Object { PNPUtil.exe /delete-driver $_.FullName /uninstall /force }
    }
  } 
  If ($actionName.ToUpper() -eq "ADD") { 
    if ($driverFolderDirectory.ToLower() -like "*.inf") {
      Write-Log -Message "Will install $driverFolderDirectory driver." -Source ${CmdletName}
      PNPUtil.exe /add-driver $driverFolderDirectory /install
    } else {
      Write-Log -Message "Will search in $driverFolderDirectory for all drivers and install them." -Source ${CmdletName}
      Get-ChildItem "$driverFolderDirectory" -Recurse -Filter "*inf" | ForEach-Object { PNPUtil.exe /add-driver $_.FullName /install }
    }
  } 

  $Time = (Get-Date).tostring("dd-MM-yyyy-hh-mm-ss")  
  $Time = $Time.Replace("-","")   
  $drvLog = "$Env:windir\inf\setupapi.dev.log"
  $targetDrvLog = "$Global:PreLogDir\setupapi_$Time_.dev.log"

  If ((Test-Path -Path $drvLog) -eq $True) { Copy-Item "$drvLog" -Destination "$targetDrvLog" }

  $RC = $LastErrorCode
  Write-Log -Message "Task exited with RC = $RC." -Source ${CmdletName}

  if (($RC -eq 0) -or ($RC -eq 3010) -or ($RC -eq 1641)) {
    Write-Log -Message "Success." -Source ${CmdletName}
    if ($RC -eq 3010) { Write-Log -Message "Reboot is required after installation." -Source ${CmdletName}; $RC = 0 } 
    elseif ($RC -eq 1641) { Write-Log -Message "Reboot is onderway - is a problem, setup can be interrupted by reboot." -Source ${CmdletName} }
  } else { 
		Write-Log -Message "Failed, Will exit with $RC." -Source ${CmdletName}; 
		Write-Log -Message "============================ Failing: $line ============================" -Source ${CmdletName}
		Set-Finalize -ExitCode $RC
	}

  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
  Return $RC
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Get-ReturnData {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$ActionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #PREINSTALL,GET,RC,pathToReg=varName=null,null
  #PREINSTALL,GET,RC,pathToReg=varName=10_{,}_10,null

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  Write-Log -Message "Will get string from: $($Data[0]) and save into: $($Data[1])." -Source ${CmdletName}
  Write-Log -Message "also will check for string exluders: $($Data[2])." -Source ${CmdletName}

  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Get-String {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$ActionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #PREINSTALL,GET,STRING,pathToReg=varName=null,null
  #PREINSTALL,GET,STRING,pathToReg=varName=10_{,}_10,null

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  Write-Log -Message "Will get string from: $($Data[0]) and save into: $($Data[1])." -Source ${CmdletName}
  Write-Log -Message "also will check for string exluders: $($Data[2])." -Source ${CmdletName}

  $Key = Set-StringFromVarLayered -VarToCheck $Data[0]
  $varName = Set-StringFromVarLayered -VarToCheck $Data[1]
  $excludes = Set-StringFromVarLayered -VarToCheck $Data[2]
  
  $Key = Set-SpecialCharacters -string $Key
  $varName = Set-SpecialCharacters -string $varName
  $excludes = Set-SpecialCharacters -string $excludes

  $Key = Convert-RegistryPath -Key $Key

  $RegPathArr = $Key.split('\')
  $TMPRegPath = ""
  $TMPRegVar = $RegPathArr[-1]
  $x = 0
  foreach ($arrItem in $RegPathArr) {
    If ($arrItem -ne $TMPRegVar) {
      If ($x -eq 0) { $TMPRegPath = $arrItem }
      else { $TMPRegPath = "$TMPRegPath\$arrItem" }
    }
    $x++
  }

  Write-Log -Message "TestConstainer = Test-Path $TMPRegPath -PathType 'Container'" -Source ${CmdletName}
  $TestConstainer = Test-Path $TMPRegPath -PathType 'Container'
  Write-Log -Message "TestConstainer = $TestConstainer" -Source ${CmdletName}

  if ($TestConstainer -eq $False) {
    Write-Log -Message "$TMPRegPath is missing, cannot continue. Will exist script." -Source ${CmdletName}
		Write-Log -Message "============================ Failing: $line ============================" -Source ${CmdletName}
    Set-Finalize -ExitCode 1
  }

  $RegString = (Get-ItemProperty -LiteralPath $TMPRegPath -name $TMPRegVar).$TMPRegVar
  Write-Log -Message "Gathered $RegString value." -Source ${CmdletName}
  if ($excludes.ToLower() -ne "null") {
    if ($excludes -like "*,*") { $toExclude = $excludes.Split(",") }
    else { $toExclude = @("$excludes") }
    foreach ($excluder in $toExclude) {
      $RegString = $RegString -replace "$excluder", ""
      #$RegString = $RegString.Replace("$excluder","") 
    }
    Write-Log -Message "RegString after normalization = $RegString." -Source ${CmdletName}
  }

  $VarValue = $RegString

  Remove-Variable -Name $VarName -Scope "Global" -ErrorAction SilentlyContinue
  Write-Log -Message "====================================" -Source ${CmdletName}
  Write-Log -Message "Adding VAR: $VarName => $VarValue" -Source ${CmdletName}
  Write-Log -Message "====================================" -Source ${CmdletName}
  New-Variable -Name $VarName -Value $VarValue -Scope "Global"
    
  $tempForValidation = Get-Variable $VarName -ErrorAction SilentlyContinue
  If (-not([string]::IsNullOrEmpty($tempForValidation))) { 
    if ($tempForValidation.Value -eq $VarValue) { Set-Message -Msg "Name $VarName, Value $VarValue was added." -CmdletName ${CmdletName} -Severity 1 } 
    else { 
      Set-Message -Msg "Name $VarName, Value $VarValue is missing." -CmdletName ${CmdletName} -Severity 3
			Write-Log -Message "============================ Failing: $line ============================" -Source ${CmdletName}
      Set-Finalize -ExitCode 1
    } 
  } else {
    Set-Message -Msg "Name $VarName, Value $VarValue is missing." -CmdletName ${CmdletName} -Severity 3
		Write-Log -Message "============================ Failing: $line ============================" -Source ${CmdletName}
    Set-Finalize -ExitCode 1
  }
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-WAMP {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$ActionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #PREINSTALL,ADD,WAMP,PKGDirectory,null  
  #PREUNINSTALL,REMOVE,WAMP,PKGName,null
  
  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  If ($actionName.ToUpper() -eq "REMOVE") {
    $PKGNameToRemove = Set-StringFromVarLayered -VarToCheck $Data[0]
    $folders = Get-ChildItem -Path $Global:KyndrylSRC -Directory
    Write-Log -Message "Will search for $PKGNameToRemove in $($Global:UserTempDirPath)." -Source ${CmdletName}
    
    Foreach ($folder in $folders) {
      Write-Log -Message "Need to validate: $($folder.Name)." -Source ${CmdletName}
      
      if (($folder.Name -like "$PKGNameToRemove") -or ($folder.Name -like "$PKGNameToRemove*")) {
        Write-Log -Message "$($folder.Name) has proper name, will search for WAMP executable." -Source ${CmdletName}
        $WAMPExecutables = Get-ChildItem -Path $folder.FullName -Filter "*.exe"
        
        foreach ($WAMPExecutable in $WAMPExecutables) {
          Write-Log -Message "Got $($WAMPExecutable.Name) will try to validate." -Source ${CmdletName}
          if ($WAMPExecutable.Name -eq "Deploy-Application_4.exe") {
            If (Test-Path -path "$($folder.FullName)\Deploy-Application.ps1" -PathType Leaf) {
              Write-Log -Message "Found package to uninstall in $($folder.FullName)" -Source ${CmdletName}
              $proc = Start-Process -FilePath "$($WAMPExecutable.FullName)" -ArgumentList "uninstall" -Wait -WindowStyle Hidden
              Remove-Item -Path $folder.FullName -Recurse -Force -ErrorAction Ignore
            } else {
              Write-Log -Message "$($folder.FullName) is not containging sources for uninstallation, will go to next action." -Source ${CmdletName}
            }
          }
        }
      }
    }
  } 
  If ($actionName.ToUpper() -eq "ADD") { 
    $WAMPPKGDir = Set-StringFromVarLayered -VarToCheck $Data[0]

    If (Test-Path -path "$WAMPPKGDir" -PathType Container) {
      if ((Test-Path -path "$WAMPPKGDir\Deploy-Application_4.exe" -PathType Leaf) -and (Test-Path -path "$WAMPPKGDir\Deploy-Application,ps1" -PathType Leaf)) {
        Write-Log -Message "Will proceed installation with: `"$WAMPPKGDir\Deploy-Application_4.exe`"." -Source ${CmdletName}
        $proc = Start-Process -FilePath "$WAMPPKGDir\Deploy-Application_4.exe" -ArgumentList "install" -Wait -WindowStyle Hidden
      } else {
        Write-Log -Message "Package files in $WAMPPKGDir are missing. Cannot install WAMP package, installation failed." -Source ${CmdletName}
        Set-Finalize -ExitCode 1
      }
    } else {
      Write-Log -Message "Directory $WAMPPKGDir is missing. Cannot install WAMP package, installation failed." -Source ${CmdletName}
      Set-Finalize -ExitCode 1
    }
  } 

  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Get-Download {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$ActionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #PREINSTALL,ADD,DOWNLOAD,url=targetDirectory=filename=hash,null  

	$url = Set-StringFromVarLayered -VarToCheck $($Data[0])
	$targetDirectory = Set-StringFromVarLayered -VarToCheck $($Data[1])
	$FileName = Set-StringFromVarLayered -VarToCheck $($Data[2])
	$FileHash = Set-StringFromVarLayered -VarToCheck $($Data[3])

  $url = Set-SpecialCharacters -string $url
  $targetDirectory = Set-SpecialCharacters -string $targetDirectory
  $FileName = Set-SpecialCharacters -string $FileName
  $FileHash = Set-SpecialCharacters -string $FileHash

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}
  Write-Log -Message "Will download $FileName from $url to $targetDirectory." -Source ${CmdletName}

	If ((Test-Path -Path "$targetDirectory\$FileName" -PathType Leaf) -eq $True) {
		$FileMD5 = (Get-FileHash "$targetDirectory\$FileName" -Algorithm MD5).Hash
		if ($FileHash.ToLower() -ne "null") {
			If ($FileMD5.ToLower() -ne $FileHash.ToLower()) { 
				$Proceed = $True
				Remove-Item -Path "$targetDirectory\$FileName" -Force
			} else { $Proceed = $False }
		} else { 
			Remove-Item -Path "$targetDirectory\$FileName" -Force
			$Proceed = $True
		}
	} else { $Proceed = $True }

	if ($Proceed -eq $True) {
		$ProgressPreferenceBackup = $ProgressPreference
		$ProgressPreference = 'SilentlyContinue'

		$ContentType = "null"
		$RC = (Invoke-WebRequest "$url" -UseBasicParsing).Headers
		foreach ($item in $RC.GetEnumerator()) { if ($item.key -eq "Content-Type") { $ContentType = $item.value } }

		if (($ContentType -eq "text/html") -or ($ContentType -like "text/html*") -or ($ContentType -like "*text/html*")) {
			Write-Log -Message "$url is invalid or not accesible (ContentType = $ContentType)." -Source ${CmdletName}
			Write-Log -Message "Will exit script with RC = 1." -Source ${CmdletName}
			$ProgressPreference = $ProgressPreferenceBackup
			Write-Log -Message "============================ Failing: $line ============================" -Source ${CmdletName}
			Set-Finalize -ExitCode 1
		}

		Invoke-WebRequest -Uri "$url" -OutFile "$targetDirectory\$FileName" -PassThru -UseBasicParsing
		$FileMD5 = (Get-FileHash "$targetDirectory\$FileName" -Algorithm MD5).Hash

		$ProgressPreference = $ProgressPreferenceBackup

		if ($FileHash.ToLower() -ne "null") {
			If ($FileMD5.ToLower() -ne $FileHash.ToLower()) { 
				Write-Log -Message "download was faulty or file was missmached." -Source ${CmdletName}
				Write-Log -Message "Please validate checksum of file, because provided is not the same as downloaded." -Source ${CmdletName}
				Write-Log -Message "Will exit script with RC = 1." -Source ${CmdletName}
				Write-Log -Message "============================ Failing: $line ============================" -Source ${CmdletName}
				Set-Finalize -ExitCode 1
			}
		}
	}

  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-Backup {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$ActionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )
 
  #PREINSTALL,ADD,BACKUP,pathToBeBackuped=targetDirectory=isReplace,null  
  
  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  Write-Log -Message "Will $actionName backup of $($Data[0])." -Source ${CmdletName}
  
  $pathToBeBackuped = Set-StringFromVarLayered -VarToCheck $Data[0]
  $targetDirectory = Set-StringFromVarLayered -VarToCheck $Data[1]
  $isReplace = Set-StringFromVarLayered -VarToCheck $Data[2]
  $type = "null"
  $ext = "null"

  if (($isReplace.ToLower() -eq "null") -or ($isReplace.ToLower() -eq "true")) { $isReplace = "true" }
  else { $isReplace = "false" }

  if ($targetDirectory.ToLower() -eq "null") {
    if ((Get-Item $pathToBeBackuped) -is [System.IO.DirectoryInfo]) { #is a directory
      if ((Test-Path -Path $pathToBeBackuped -PathType Container) -eq $False) {
        Write-Log -Message "$pathToBeBackuped is missing. Will skip BACKUP action." -Source ${CmdletName}
				Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
        Return 0
      }
      $type = "dir"
      $targetDirectory = (get-item $pathToBeBackuped ).parent.FullName
    } else { #is a file
      if ((Test-Path -Path $pathToBeBackuped -PathType Leaf) -eq $False) {
        Write-Log -Message "$pathToBeBackuped is missing. Will skip BACKUP action." -Source ${CmdletName}
				Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
        Return 0
      }
      $type = "file"
      $file = Get-Item $pathToBeBackuped
      $ext = $file.Extension
      $targetDirectory = (get-item $pathToBeBackuped).Directory.Parent.FullName 
    }  
  }

  If ($actionName.ToUpper() -eq "ADD") {
    if ($ext -ne "null") { 
      $item = (get-item $pathToBeBackuped).Name.Replace("$ext","")
      $item = "$item-BACKUP$ext" 
    } else {
      $item = (get-item $pathToBeBackuped).Name
      $item = "$item-BACKUP" 
    }

    $targetItem = "$targetDirectory\$item"

    if (($isReplace -eq "false") -and (((test-path -path $targetItem -PathType Leaf) -eq $True) -or ((test-path -path $targetItem -PathType Container) -eq $True))) {
      Write-Log -Message "$targetItem already exist. Will skip BACKUP action." -Source ${CmdletName}
			Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
      Return 0
    } else {
      if ((test-path -path $targetItem -PathType Leaf) -eq $True) { Remove-Item $targetItem -Force -Verbose}
      if ((test-path -path $targetItem -PathType Container) -eq $True) { & cmd /c "rm -r '$targetItem'" }
    }

    if ($type -eq "file") { Copy-Item "$pathToBeBackuped" "$targetItem" } 
    elseif ($type -eq "dir") { 
      Xcopy /E /I /S /H /Y $pathToBeBackuped $targetItem
      #Copy-Item -Path "$pathToBeBackuped\*" -Destination "$targetItem\" -Recurse -Force -Verbose 
    }
  }
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-SymLink {
  <#
    .SYNOPSIS
      Will create or remove symbolic link.  
    .DESCRIPTION
      Will add or remove symbolic link of two types: SymbolicLink or Junction.
    .PARAMETER actionName
      The name action type you want to trigger: ADD or REMOVE can be used for SYMLINK.
    .PARAMETER Data
      Data variable withh all information to execute function like:
      DataPath =Symbolic link path.  
      DataTarget= Symbolic link target.  
      DataType =Type of symbolic link: SymbolicLink or Junction. 
    .PARAMETER DataType
      As default is a null for SYMLINK.
    .EXAMPLE
      Conf line: PREINSTALL,ADD,SYMLINK,c:\A=c:\sssddsaa\sdada=SymbolicLink,null - create a new SymbolicLink.
    .EXAMPLE
      Conf line: PREINSTALL,REMOVE,SYMLINK,c:\A,null - remove a SymbolicLink.
    .NOTES
      This is an internal script function and should typically not be called directly, it will be triggered by main script if proper conf line will be found.
    .LINK
      https://github.kyndryl.net/wms-global/WMSAutomationTool/
  #>
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$ActionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #PREINSTALL,REMOVE,SYMLINK,Path,null  
  #PREINSTALL,ADD,SYMLINK,Path=Target=Type,null   Type =  SymbolicLink or Junction
  #PREINSTALL,ADD,SYMLINK,c:\A=c:\sssddsaa\sdada=SymbolicLink,null

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}
  
  Write-Log -Message "Will $actionName Junction/symlik." -Source ${CmdletName}

  If ($actionName.ToUpper() -eq "REMOVE") { 
    $Path = Set-StringFromVarLayered -VarToCheck $Data[0]
    Write-Log -Message "Will remove Junction/symlik $Target." -Source ${CmdletName}
    & cmd /c "rmdir '$Path'"
  } 
  If ($actionName.ToUpper() -eq "ADD") { 
    $Path = Set-StringFromVarLayered -VarToCheck $Data[0]
    $Target = Set-StringFromVarLayered -VarToCheck $Data[1]
    $Type = $Data[2]

    If ($Type.ToLower() -eq 'null') { $Type = 'SymbolicLink' }
    Write-Log -Message "Will create Junction/symlik $Path from $Target." -Source ${CmdletName}
    if ($Type.ToLower() -eq 'symboliclink') { New-Item -ItemType SymbolicLink -Path $Path -Target $Target -Force }
    if ($Type.ToLower() -eq 'junction') { New-Item -ItemType Junction -Path $Path -Target $Target -Force }
  }
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function Ensure-FParamms {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$Name,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    $Value
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  Write-Log -Message "Will validate $Name - $Value." -Source ${CmdletName}

  switch ($Name) {
    "Name" { $RC = $Value.ToString() }
    "DisplayName" { $RC = $Value.ToString() }
    "Group" { $RC = $Value.ToString() }
    "Ensure" {
      if (($($Value.ToString()).ToLower() -eq 'present') -or ($($Value.ToString()).ToLower() -eq 'absent')) { $RC = $Value.ToString() }
      else { $RC = 'Present' }
    }
    "Enabled" { 
      if (($($Value.ToString()).ToLower() -eq 'false') -or ($Value -eq $false) -or ($($Value.ToString()).ToLower() -eq 'no')) { $RC = "false" }
      elseif (($($Value.ToString()).ToLower() -eq 'true') -or ($Value -eq $true) -or ($($Value.ToString()).ToLower() -eq 'yes')) { $RC = "true" }
    }
    "Action" { 
      if (($($Value.ToString()).ToLower() -eq 'notconfigured') -or ($($Value.ToString()).ToLower() -eq 'allow') -or ($($Value.ToString()).ToLower() -eq 'block')) { $RC = $Value.ToString() }
      else { $RC = 'notconfigured' }
    }
    "Profile" { $RC = $Value.ToString() }
    "Direction" { 
      if (($($Value.ToString()).ToLower() -eq 'inbound') -or ($($Value.ToString()).ToLower() -eq 'outbound')) { $RC = $Value.ToString() }
      else { $RC = 'outbound' }
    }
    "RemotePort" { $RC = $Value.ToString() }
    "LocalPort" { $RC = $Value.ToString() }
    "Protocol" { $RC = $Value.ToString() }
    "Description" { $RC = $Value.ToString() }
    "Program" { 
      $RC = $Value.ToString() 
      $RC = Set-StringFromVarLayered -VarToCheck $RC
    }
    "Service" { $RC = $Value.ToString() }
    "Authentication" { 
      if (($($Value.ToString()).ToLower() -eq 'notrequired') -or ($($Value.ToString()).ToLower() -eq 'required') -or ($($Value.ToString()).ToLower() -eq 'noencap')) { $RC = $Value.ToString() }
      else { $RC = 'notrequired' }
    }
    "Encryption" { 
      if (($($Value.ToString()).ToLower() -eq 'notrequired') -or ($($Value.ToString()).ToLower() -eq 'required') -or ($($Value.ToString()).ToLower() -eq 'dynamic')) { $RC = $Value.ToString() }
      else { $RC = 'notrequired' }
    }
    "InterfaceAlias" { $RC = $Value.ToString() }
    "InterfaceType" { 
      if (($($Value.ToString()).ToLower() -eq 'any') -or ($($Value.ToString()).ToLower() -eq 'wired') -or ($($Value.ToString()).ToLower() -eq 'wireless') -or ($($Value.ToString()).ToLower() -eq 'remoteaccess')) { $RC = $Value.ToString() }
      else { $RC = 'any' }
    }
    "LocalAddress" { $RC = $Value.ToString() }
    "LocalUser" { $RC = $Value.ToString() }
    "Package" { $RC = $Value.ToString() }
    "Platform" { $RC = $Value.ToString() }
    "RemoteAddress" { $RC = $Value.ToString() }
    "RemoteMachine" { $RC = $Value.ToString() }
    "RemoteUser" { $RC = $Value.ToString() }
    "DynamicTransport" { 
      if (($($Value.ToString()).ToLower() -eq 'any') -or ($($Value.ToString()).ToLower() -eq 'proximityapps') -or ($($Value.ToString()).ToLower() -eq 'proximitysharing') -or ($($Value.ToString()).ToLower() -eq 'wifidirectprinting') -or ($($Value.ToString()).ToLower() -eq 'wifidirectdisplay') -or ($($Value.ToString()).ToLower() -eq 'wifidirectdevices')) { $RC = $Value.ToString() }
      else { $RC = 'any' }
    }
    "EdgeTraversalPolicy" { 
      if (($($Value.ToString()).ToLower() -eq 'block') -or ($($Value.ToString()).ToLower() -eq 'allow') -or ($($Value.ToString()).ToLower() -eq 'defertouser') -or ($($Value.ToString()).ToLower() -eq 'defertoapp')) { $RC = $Value.ToString() }
      else { $RC = 'block' }
    }
    "IcmpType" { $RC = $Value.ToString() }
    "LocalOnlyMapping" { 
      if (($($Value.ToString()).ToLower() -eq 'false') -or ($Value -eq $false)) { $RC = $false }
      elseif (($($Value.ToString()).ToLower() -eq 'true') -or ($Value -eq $true)) { $RC = $true }
    }
    "LooseSourceMappin" { 
      if (($($Value.ToString()).ToLower() -eq 'false') -or ($Value -eq $false)) { $RC = $false }
      elseif (($($Value.ToString()).ToLower() -eq 'true') -or ($Value -eq $true)) { $RC = $true }
    }
    "OverrideBlockRules" { 
      if (($($Value.ToString()).ToLower() -eq 'false') -or ($Value -eq $false)) { $RC = $false }
      elseif (($($Value.ToString()).ToLower() -eq 'true') -or ($Value -eq $true)) { $RC = $true }
    }
    "Owner" { $RC = $Value.ToString() }
  }

  Write-Log -Message "Returning: $RC." -Source ${CmdletName}
  Return $RC

}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-FireWall {
  <#
    .SYNOPSIS
      Will create, disable or remove firewall rule.  
    .DESCRIPTION
      Will create, disable or remove firewall rule using a standard firewall set of parameters, can ease with firewall removal actions.
    .PARAMETER actionName
      The name action type you want to trigger: ADD or REMOVE can be used for FIREWALL.
    .PARAMETER Data
      Data variable withh all information to execute function like:
      DataRuleName=Firewall rule name (identity).
      DataNetshRule=Full set of firewall rule parameters that will be used to create a new rule.
    .PARAMETER DataType
      As default is a null for FIREWALL.
    .EXAMPLE
      Conf line: POSTINSTALL,ADD,FIREWALL,DisplayName-TIBCO Enterprise Message Service.;name-TIBCO Enterprise Message Service.;description-TIBCO Enterprise Message Service.;direction-Inbound;action-allow;program-%programfiles64%\tibco\ems\8.6\bin\tibemsd.exe;protocol-TCP;profile-private;enabled-yes,null - create a new firewall rule.
    .EXAMPLE
      Conf line: PREINSTALL,REMOVE,FIREWALL,TIBCO Enterprise Message Service,null - remove a firewall rule.
    .NOTES
      This is an internal script function and should typically not be called directly, it will be triggered by main script if proper conf line will be found.
    .LINK
      https://github.kyndryl.net/wms-global/WMSAutomationTool/
  #>
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$ActionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #PREINSTALL,REMOVE,FIREWALL,RuleName,null  RuleType  -  DisplayName /PolicyStore /Program 
  #PREINSTALL,ADD,FIREWALL,netshRule,null    change = to - in 
  #POSTINSTALL,ADD,FIREWALL,DisplayName-TIBCO Enterprise Message Service.;name-TIBCO Enterprise Message Service.;description-TIBCO Enterprise Message Service.;direction-Inbound;action-allow;program-%programfiles64%\tibco\ems\8.6\bin\tibemsd.exe;protocol-TCP;profile-private;enabled-yes,null
  #POSTINSTALL,ADD,FIREWALL,DisplayName-TIBCO Enterprise Message Service.;name-TIBCO Enterprise Message Service.;description-TIBCO Enterprise Message Service.;direction-Inbound;action-allow;program-%programfiles64%\tibco\ems\8.6\bin\tibemsd.exe;protocol-UDP;profile-private;enabled-yes,null

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  If ($actionName.ToUpper() -eq "REMOVE") { 
    $RuleName = $Data[0]
    Write-Log -Message "Will remove firewall  rule: $RuleName." -Source ${CmdletName}
    Write-Log -Message "Remove-NetFirewallRule -DisplayName $RuleName" -Source ${CmdletName}
    Remove-NetFirewallRule -DisplayName $RuleName
  } If ($actionName.ToUpper() -eq "DISABLE") { 
    $RuleName = $Data[0]
    Write-Log -Message "Will disable firewall  rule: $RuleName." -Source ${CmdletName}
    Write-Log -Message "Disable-NetFirewallRule -DisplayName $RuleName" -Source ${CmdletName} 
    Disable-NetFirewallRule -DisplayName $RuleName
  } elseif ($actionName.ToUpper() -eq "ADD") { 
    $netshRule = $Data[0]
    $Params = @{}
    #[System.Collections.ArrayList]$ArraayList = $Params
    $ArraayList = @{}
    Write-Log -Message "Will add firewall  rule: $netshRule." -Source ${CmdletName}
    $tmpVars = $netshRule.Split(";")
    Write-Log -Message "Splat params:" -Source ${CmdletName}

    foreach ($item in $tmpVars) {
      $ArrayItem = $item.Split("-")
      $Name = $($ArrayItem[0]).ToString() 
      $TmpVal = $ArrayItem[1] 
      $Value = Ensure-FParamms -Name $Name -Value $TmpVal
      #Write-Log -Message "$($ArrayItem[0]) = $($ArrayItem[1])" -Source ${CmdletName}
      $ArraayList.Add($Name, $Value)
      #$ArraayList += @{ $Name = $Value }
    }  

    Write-Log -Message "New-NetFirewallRule:"
    foreach ($rule in $ArraayList) { 
      $rule
      #Write-Log -Message "$($rule.Name) - $($rule.Value)" -Source ${CmdletName} 
    }
    
    Write-Log -Message "Remove-NetFirewallRule -DisplayName $($ArraayList.DisplayName)" -Source ${CmdletName} 
    Remove-NetFirewallRule -DisplayName $ArraayList.DisplayName

    Write-Log -Message "New-NetFirewallRule $ArraayList" -Source ${CmdletName}
    New-NetFirewallRule @ArraayList
  }
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-MSIInTune {
  <#
    .SYNOPSIS
      Can uninstall WAMP based msi packages for InTune. 
    .DESCRIPTION
      Can handle complete uninstall of all in one msi packages for Intune based on VBS Custom Action. 
    .PARAMETER actionName
      The name action type you want to trigger: REMOVE can be used for MSIINTUNE.
    .PARAMETER Data
      Data variable withh all information to execute function like:
      PkgGUID=MSI package GUID.
      PKGVersion=MSI package version.
      PkgName=Package name used for tmp dir naming and for tag creation.
    .PARAMETER DataType
      As default is a null for MSIINTUNE.
      ProcessToFallow=*script.exe is  default entry for VBS based MSI.
    .EXAMPLE
      Conf line: PREINSTALL,REMOVE,MSIINTUNE,{517B95BC-7231-45B4-A5C7-43D38C827770}=5.6.1.157=McAfee_McAfeeAgent_5.6.1.157_SCH_W10x64_EN_B1,*script.exe
    .NOTES
      This is an internal script function and should typically not be called directly, it will be triggered by main script if proper conf line will be found.
    .LINK
      https://github.kyndryl.net/wms-global/WMSAutomationTool/
  #>
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$ActionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $True)]
    [String]$DataType,
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #PREINSTALL,REMOVE,MSIINTUNE,PkgGUID=PKGVersion=PkgName,*script.exe
  #PREINSTALL,REMOVE,MSIINTUNE,{517B95BC-7231-45B4-A5C7-43D38C827770}=5.6.1.157=McAfee_McAfeeAgent_5.6.1.157_SCH_W10x64_EN_B1,*script.exe

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  If ($actionName.ToUpper() -eq "REMOVE") {
    $MSIGUID = Set-StringFromVarLayered -VarToCheck $Data[0]
    $MSIVer = Set-StringFromVarLayered -VarToCheck $Data[1]
    $PKGName = Set-StringFromVarLayered -VarToCheck $Data[2]

    $isInstalled = (Get-InstalledApplication -ProductCode $MSIGUID).DisplayName

    If ([string]::IsNullOrEmpty($isInstalled) -or ($isInstalled -eq "") -or $isInstalled -eq " ") {
      Write-Log -Message "MSI wrapper with GUID $MSIGUID is not installed. Going to check, if installation wrapper log file exists." -Source ${CmdletName}

      If (Get-LogStatus -PKGName $PKGName -LogPartName "Install") {
        Write-Log -Message "Previous package $PKGName installation ended with success. Going to check, if its uninstallation script exists." -Source ${CmdletName}

        If (Test-Path -Path "$Global:ProgramData\IBMSRC\$PKGName\Uninstall.vbs") {
          Write-Log -Message "Previous package $PKGName uninstallation script exist. Going to uninstall the package." -Source ${CmdletName}
          Execute-Process -Path "WScript.exe" -Parameters "$Global:ProgramData\IBMSRC\$PKGName\Uninstall.vbs" -WindowStyle 'Hidden' -IgnoreExitCodes '3010'
          Start-Sleep -s 15

          Remove-Folder -Path "$Global:ProgramData\IBMSRC\$PKGName"
        } Else { Write-Log -Message "Previous package $PKGName uninstallation script doesn't exist in IBMSRC. The package is not installed." -Source ${CmdletName} }
        
        If (Test-Path -Path "$Global:ProgramData\KyndrylSRC\$PKGName\Uninstall.vbs") {
          Write-Log -Message "Previous package $PKGName uninstallation script exist. Going to uninstall the package." -Source ${CmdletName}
          Execute-Process -Path "WScript.exe" -Parameters "$Global:ProgramData\KyndrylSRC\$PKGName\Uninstall.vbs" -WindowStyle 'Hidden' -IgnoreExitCodes '3010'
          Start-Sleep -s 15

          Remove-Folder -Path "$Global:ProgramData\KyndrylSRC\$PKGName"
        } Else { Write-Log -Message "Previous package $PKGName uninstallation script doesn't exist in KyndrylSRC. The package is not installed." -Source ${CmdletName} }
      } Else { Write-Log -Message "Previous package $PKGName has never been installed or installation ended with failure." -Source ${CmdletName} }
    } Else {
      Write-Log -Message "MSI wrapper with GUID $MSIGUID is installed. Going to uninstall the package." -Source ${CmdletName}
      Set-MSIAction -ActionName $ActionName -Data $Data -DataType $DataType

      If (Get-LogStatus -PKGName $PKGName -LogPartName "Uninstall") { 
        Remove-Folder -Path "$Global:ProgramData\IBMSRC\$PKGName" 
        Remove-Folder -Path "$Global:ProgramData\KyndrylSRC\$PKGName"
      } Else {
        Write-Log -Message "MSI wrapper with GUID $MSIGUID uninstallation ended with success, but the previous package $PKGName uninstallation ended with failure." -Source ${CmdletName}
				Write-Log -Message "============================ Failing: $line ============================" -Source ${CmdletName}
        Set-Finalize -ExitCode 1
      }
    }
  }
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-MSIInTuneMA {
  <#
    .SYNOPSIS
      Can uninstall WAMP based msi packages for InTune. 
    .DESCRIPTION
      Can handle complete uninstall of all in one msi packages for Intune based on VBS Custom Action. 
    .PARAMETER actionName
      The name action type you want to trigger: REMOVE can be used for MSIINTUNEMA.
    .PARAMETER Data
      Data variable withh all information to execute function like:
      PkgGUID=MSI package GUID.
      PKGVersion=MSI package version.
      PkgName=Package name used for tmp dir naming and for tag creation.
    .PARAMETER DataType
      As default is a null for MSIINTUNEMA.
      ProcessToFallow=*script.exe is  default entry for VBS based MSI.
    .EXAMPLE
      Conf line: PREINSTALL,REMOVE,MSIINTUNEMA,{517B95BC-7231-45B4-A5C7-43D38C827770}=5.6.1.157=McAfee_McAfeeAgent_5.6.1.157_SCH_W10x64_EN_B1,*script.exe
    .NOTES
      This is an internal script function and should typically not be called directly, it will be triggered by main script if proper conf line will be found.
    .LINK
      https://github.kyndryl.net/wms-global/WMSAutomationTool/
  #>
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$ActionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$DataType,
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #PREINSTALL,REMOVE,MSIINTUNEMA,PkgGUID=PKGVersion=PkgName,*script.exe
  #PREINSTALL,REMOVE,MSIINTUNEMA,{517B95BC-7231-45B4-A5C7-43D38C827770}=5.6.1.157=McAfee_McAfeeAgent_5.6.1.157_SCH_W10x64_EN_B1,*script.exe

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  If ($actionName.ToUpper() -eq "REMOVE") {
    $MSIGUID = Set-StringFromVarLayered -VarToCheck $Data[0]
    $MSIVer = Set-StringFromVarLayered -VarToCheck $Data[1]
    $PKGName = Set-StringFromVarLayered -VarToCheck $Data[2]

    $isInstalled = (Get-InstalledApplication -ProductCode $MSIGUID).DisplayName

    If ([string]::IsNullOrEmpty($isInstalled) -or ($isInstalled -eq "") -or $isInstalled -eq " ") {
      Write-Log -Message "MSI wrapper with GUID $MSIGUID is not installed." -Source ${CmdletName}
    } Else {
      Write-Log -Message "MSI wrapper with GUID $MSIGUID is installed." -Source ${CmdletName}

      If (Test-Path -Path "$Global:ProgramData\IBMSRC\$PKGName\Uninstall.vbs") {
        Write-Log -Message "File $Global:ProgramData\IBMSRC\$PKGName\Uninstall.vbs exists." -Source ${CmdletName}
        $Directory = "$Global:ConfigFilesPath\Uninstall.vbs"
        $NewDirectory = "$Global:ProgramData\IBMSRC\$PKGName\Uninstall.vbs"

        & cmd /C "copy  $Directory $NewDirectory"
        Write-Log -Message "Uninstall.vbs replaced." -Source ${CmdletName}
      }

      $MSIParam = "/x $MSIGUID /qn REBOOT=ReallySuppress /L*v+ $Global:configToolkitLogDir\$PKGName" + "_Uninstall.log"
      Execute-Process -Path "msiexec.exe" -Parameters $MSIParam -WindowStyle 'Hidden' -IgnoreExitCodes '3010'
      Remove-Folder -Path "$Global:ProgramData\IBMSRC\$PKGName"
    }
  }
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-Office {
  <#
    .SYNOPSIS
      Will add or remove MS Office and will set some custom settings. 
    .DESCRIPTION
      Can install and uninstall MS office based only on a few parameters. Also can setup an additional actions like: remove MS Teams.   
    .PARAMETER actionName
      The name action type you want to trigger: ADD, CHANGE or REMOVE can be used for	OFFICE.
    .PARAMETER Data
      Data variable withh all information to execute function like:
      DataEXEPath=Path to MS Office Setup.exe
      DataXmlPath=Path to MS Office xml settings file
      DataPkgName=Package name 
    .PARAMETER DataType
      As default is a null for OFFICE. 
    .EXAMPLE
      Conf line: POSTINSTALL,CHANGE,OFFICE,TEAMS,null - will remove MS Teams after MS Office installation.
    .EXAMPLE
      Conf line: INSTALL,ADD,OFFICE,setup.exe=configuration-Bil-Install.xml=PKG00001V02R007,null - will install MS Office.
    .EXAMPLE
      Conf line: UNINSTALL,REMOVE,OFFICE,O365ProPlusRetail - de-de=de-de=16=PKG00001V02R007,null - will uninstall DE version of MS Office.
    .NOTES
      This is an internal script function and should typically not be called directly, it will be triggered by main script if proper conf line will be found.
    .LINK
      https://github.kyndryl.net/wms-global/WMSAutomationTool/
  #>
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$ActionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$DataType,
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #PREINSTALL,ADD,OFFICE,EXEPath=xmlPath=PkgName,null
  #PREINSTALL,REMOVE,OFFICE,PkgGUID=LangCode=FamiliVer=PkgName,null
  #PREINSTALL,CHANGE,OFFICE,Module,null

  #POSTINSTALL,CHANGE,OFFICE,TEAMS,{guid}

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  If ($actionName.ToUpper() -eq "REMOVE") {
    $PkgGUID = Set-StringFromVarLayered -VarToCheck $Data[0]
    $LangCode = Set-StringFromVarLayered -VarToCheck $Data[1]
    $FamVer = Set-StringFromVarLayered -VarToCheck $Data[2]
    $PkgName = Set-StringFromVarLayered -VarToCheck $Data[3]
    $isKillProcess = Set-StringFromVarLayered -VarToCheck $DataType

    $EXEFile = "$env:programfiles\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe"
    $procList = @("PROFLWIZ","communicator","GroupChatConsole","AttendantConsole","DW20","LYNC","ONEDRIVE","GROOVE","MSPSCAN","MSPVIEW","OFFDIAG","EXCEL","INFOPATH","MSACCESS","MSOSYNC","MSOUC","MSPUB","MSTORE","MSTORDB","MSTRDB","OIS","ONENOTE","ONENOTEM","OUTLOOK","POWERPNT","SELFCERT","SETLANG","WINWORD","DATABASECOMPARE","SPREADSHEETCOMPARE","OCPUBMGR","VISIO","WINPROJ","SPDESIGN")

    Write-Log -Message "isKillProcess = $isKillProcess." -Source ${CmdletName}

    if ($isKillProcess.ToLower() -eq "true") {
      Write-Log -Message "Will kill Office related processes.." -Source ${CmdletName}
      foreach ($process in $procList) {
        stop-process -name $process -force -ErrorAction SilentlyContinue
        Write-Log -Message "Stopping: $process." -Source ${CmdletName}
      }
    }

    $regGUID = Get-InstalledApplication -ProductCode $PkgGUID

    if (-not([string]::IsNullOrEmpty($regGUID))) {
      Write-Log -Message "Office $regGUID is installed, going to uninstall." -Source ${CmdletName}

      if($PkgGUID -like "O365ProPlusRetail*") { $Params = "scenario=install scenariosubtype=ARP sourcetype=None productstoremove=O365ProPlusRetail."+$FamVer+"_"+$LangCode+"_x-none culture="+$LangCode+" version."+$FamVer+"="+$FamVer+".0 DisplayLevel=false" }
      if($PkgGUID -like "VisioProRetail*") { $Params = "scenario=install scenariosubtype=ARP sourcetype=None productstoremove=VisioProRetail."+$FamVer+"_"+$LangCode+"_x-none culture="+$LangCode+" version."+$FamVer+"="+$FamVer+".0 DisplayLevel=false" }

      Test-ParamFile -path $EXEFile
      Execute-Process -Path $EXEFile -Parameters $Params -WindowStyle 'Hidden'
    } else { Write-Log -Message "Office $regGUID is not installed, going to next step." -Source ${CmdletName} }
  } elseIf ($actionName.ToUpper() -eq "ADD") {
    $EXEFile = Set-StringFromVarLayered -VarToCheck $Data[0]
    $XMLFile = Set-StringFromVarLayered -VarToCheck $Data[1]
    $PKGName = Set-StringFromVarLayered -VarToCheck $Data[2]

    if (($EXEFile -like "%*") -or ($EXEFile -like "\\*")) { $EXEFile = Set-StringFromVarLayered -VarToCheck $EXEFile}
    else { $EXEFile = "$Global:SourcePath\$EXEFile" }

    if (($XMLFile -like "%*") -or ($XMLFile -like "\\*")) { $XMLFile = Set-StringFromVarLayered -VarToCheck $XMLFile}
    else { $XMLFile ="$Global:ConfigFilesPath\$XMLFile" }

    $Params = "/configure "+'"'+$XMLFile+'"'

    Test-ParamFile -path $EXEFile
    Test-ParamFile -path $XMLFile
    Execute-Process -Path "$EXEFile" -Parameters $Params -WindowStyle 'Hidden'
  } elseIf ($actionName.ToUpper() -eq "CHANGE") {
    $Module = Set-StringFromVarLayered -VarToCheck $Data[0]

    if ($Module.ToUpper() -eq "TEAMS") {
      $guid = Set-StringFromVarLayered -VarToCheck $DataType
      if ($guid.ToLower() -eq "null") { $guid = "{39AF0813-FA7B-4860-ADBE-93B9B214B914}" }

      Get-WmiObject -Class Win32_Product | Where-Object {$_.IdentifyingNumber -eq "$guid"} | Remove-WmiObject
      $TeamsUsers = Get-ChildItem -Path "$ENV:SystemDrive\Users"
      $TeamsUsers | ForEach-Object {
        Try {
          If ( Test-Path -Path "$ENV:SystemDrive\Users\$($_.Name)\AppData\Local\Microsoft\Teams" -PathType Container ) { $Item = "$ENV:SystemDrive\Users\$($_.Name)\AppData\Local\Microsoft\Teams" }
          Else { $Item = "$ENV:SystemDrive\Users\$($_.Name)\AppDataLocal\Microsoft\Teams" }

          Write-Log -Message $item -Source ${CmdletName}
            if (Test-Path $Item) {
              Start-Process -FilePath "$Item\Update.exe" -ArgumentList "-uninstall -s"
              Remove-Item -Path $Item -Recurse -Force -ErrorAction Ignore
            }
        } Catch { Out-Null }
      }
    }
  }
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Get-ProfileList {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    $PatternSID
  )
  
  $ProfileList = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*' | Where-Object {$_.PSChildName -match $PatternSID} |
    Select-Object  @{name="SID";expression={$_.PSChildName}},
    @{name="UserHive";expression={"$($_.ProfileImagePath)\ntuser.dat"}},
    @{name="Username";expression={$_.ProfileImagePath -replace '^(.*[\\\/])', ''}}

  Return $ProfileList
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  
  

#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-OfficeAddin {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$ActionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #PREINSTALL,REMOVE,OFFICEADDIN,OPENValue=RegPath,null
  #PREINSTALL,REMOVE,OFFICEADDIN,FDSXL32.XLL|FactSetLive.RTDFunction.1=Software\Microsoft\Office\16.0\Excel\Options,null
  #PREINSTALL,REMOVE,OFFICEADDIN,FDSXL32.XLL=Software\Microsoft\Office\16.0\Excel\Options,null

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  # Regex pattern for SIDs
  if ($Global:userActions.ToLower() -eq 'false') { 
    Write-Log -Message "Will skipp ${CmdletName} execution. userActions = $($Global:userActions)." -Source ${CmdletName} -Severity 3
    Write-Log -Message "For your account use an other method for actions in user context/manipulation of user profiles." -Source ${CmdletName} -Severity 3 
  } else {
    $LocalSID     = 'S-1-5-21-\d+-\d+\-\d+\-\d+$'
    $AdSID        = 'S-1-12-1-\d+-\d+-\d+-\d+$'
    $PatternsSID  = @($LocalSID, $AdSID)

    foreach ($PSID in $PatternsSID) {
      $RC = Get-ProfileList -PatternSID $PSID
      if (([string]::IsNullOrEmpty($RC)) -and ([string]::IsNullOrWhitespace($RC))) { Write-Log "$PSID missing on machine."  }
      else { 
        $ProfileList = $RC
        $PatternSID = $PSID
        Write-Log "$PSID found on machine, will be used."

        # Get all user SIDs found in HKEY_USERS (ntuder.dat files that are loaded)
        $LoadedHives = Get-ChildItem Registry::HKEY_USERS | Where-Object {$_.PSChildname -match $PatternSID} | Select-Object @{name="SID";expression={$_.PSChildName}}

        # Get all users that are not currently logged
        $UnloadedHives = Compare-Object $ProfileList.SID $LoadedHives.SID | Select-Object @{name="SID";expression={$_.InputObject}}, UserHive, Username

        Foreach ($item in $ProfileList) { 
          # Load User ntuser.dat if it's not already loaded
          If ($item.SID -in $UnloadedHives.SID) {
            Write-Log -Message "Loading: HKU\$($Item.SID) $($Item.UserHive)"
            reg load HKU\$($Item.SID) $($Item.UserHive) | Out-Null
          }

          #####################################################################
          # This is where you can read/modify a users portion of the registry
          $OpenValueArray = $Data[0].Split("|")

          If ($actionName.ToUpper() -eq "REMOVE") {
            $OPENValue = @($OpenValueArray)
            $Path = $Data[1]
            $RegPath = "Registry::HKEY_USERS\$($Item.SID)\$Path"

            For ($arr=0; $arr -lt $OPENValue.length; $arr++){
              $StrToFind = $OPENValue[$arr]
              Write-Log -Message "Remove Office add-in: String to find: $StrToFind."

              #Count OPEN values in registry
              $sCount = 0
              $EndLoop = 0
              $Value = "OPEN"

              DO {
                If ($sCount -eq 0) {
                  If (Test-RegistryValue -Key $RegPath -Value $Value) { $sCount = $sCount + 1 } 
                  Else { Break }
                }
                
                If (Test-RegistryValue -Key $RegPath -Value $Value$sCount) { $sCount = $sCount + 1 } 
                Else { $EndLoop = 1 }
              } While ($EndLoop -eq 0)

              If ($sCount -eq 0) { Write-Log -Message "Remove Office add-in: No OPEN values." }
              Else { Write-Log -Message "Remove Office add-in: Number of OPEN values: $sCount." }

              $sCountOPEN = $sCount - 1

              For ($i=0; $i -le $sCountOPEN; $i++) {
                If ($i -eq 0) {
                  $ValueToCheck = Get-RegistryKey -Key $RegPath -Value $Value

                  If (($ValueToCheck -like "*$StrToFind") -or ($ValueToCheck -like "*$StrToFind*") -or ($ValueToCheck -like "$StrToFind*")) {
                    Write-Log -Message "Remove Office add-in: The value includes the string $StrToFind."
                    #Remove OPEN value
                    Remove-RegistryKey -Key $RegPath -Name $Value
                    $j = $i + 1

                    #Change position of other OPEN values
                    For ($i=$j; $i -le $sCountOPEN; $i++) {
                      If (Test-RegistryValue -Key $RegPath -Value $Value$i){
                        $RegData = Get-RegistryKey -Key $RegPath -Value $Value$i
                        Write-Log -Message "Remove Office add-in: Next OPEN value exists: OPEN$i = $RegData."

                        If ($i -eq 1) {
                          Set-RegistryKey -Key $RegPath -Name $Value -Value $RegData -Type String
                          Write-Log "Remove Office add-in: $Value$i changed position to OPEN = $RegData."
                          Remove-RegistryKey -Key $RegPath -Name $Value$i
                        } Else {
                          $k = $i - 1
                          Set-RegistryKey -Key $RegPath -Name $Value$k -Value $RegData -Type String
                          Write-Log -Message "Remove Office add-in: $Value$i changed position to OPEN$k = $RegData."
                          Remove-RegistryKey -Key $RegPath -Name $Value$i
                        }
                      }
                    } Break

                  } Else { Write-Log -Message "Remove Office add-in: The value doesn't include the string $StrToFind." }
                } Else {
                  $ValueToCheck = Get-RegistryKey -Key $RegPath -Value $Value$i
                  If (($ValueToCheck -like "*$StrToFind") -or ($ValueToCheck -like "*$StrToFind*") -or ($ValueToCheck -like "$StrToFind*")) {
                    Write-Log -Message "Remove Office add-in: The value includes the string $StrToFind."
                    #Remove OPEN value
                    Remove-RegistryKey -Key $RegPath -Name $Value$i
                    $j = $i + 1

                    #Change position of other OPEN values
                    For ($i=$j; $i -le $sCountOPEN; $i++) {
                      If (Test-RegistryValue -Key $RegPath -Value $Value$i) {
                        $RegData = Get-RegistryKey -Key $RegPath -Value $Value$i
                        Write-Log -Message "Remove Office add-in: Next OPEN value exists: OPEN$i = $RegData."
                        If ($i -eq 1) {
                          Set-RegistryKey -Key $RegPath -Name $Value -Value $RegData -Type String
                          Write-Log "Remove Office add-in: $Value$i changed position to OPEN$k = $RegData."
                          Remove-RegistryKey -Key $RegPath -Name $Value$i
                        } Else {
                          $k = $i - 1
                          Set-RegistryKey -Key $RegPath -Name $Value$k -Value $RegData -Type String
                          Write-Log -Message "Remove Office add-in: $Value$i changed position to OPEN$k = $RegData."
                          Remove-RegistryKey -Key $RegPath -Name $Value$i
                        }
                      }
                    } Break
                  } Else { Write-Log -Message "Remove Office add-in: The value doesn't include the string $StrToFind." }
                }
              }
            }
          }

          #####################################################################
          # Unload ntuser.dat
          If ($item.SID -in $UnloadedHives.SID) {
            ### Garbage collection and closing of ntuser.dat ###
            Write-Log -Message "Uloading: HKU\$($Item.SID)"
            [gc]::Collect()
            reg unload HKU\$($Item.SID) | Out-Null
          }
        }
      }
    }
  }
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-Plugin {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$ActionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$DataType,
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #PREINSTALL,ADD,PLUGIN,PluginFile=PluginPath=InstallerBin=InstallerCMD,null
  #PREINSTALL,REMOVE,PLUGIN,PluginFile/Name=PluginPath=UninstallerBin=UninstallerCMD,null

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  $PluginFile = Set-StringFromVarLayered -VarToCheck $Data[0]
  $PluginPath = Set-StringFromVarLayered -VarToCheck $Data[1]
  $HandlerBinPath = Set-StringFromVarLayered -VarToCheck $Data[2]
  $HandlerCMD = Set-StringFromVarLayered -VarToCheck $Data[3]

  if ($PluginFile.ToLower() -ne 'null') {
    If ($PluginPath -ne 'null') { $PluginFilePath = "$PluginPath\$PluginFile" } 
    Else { $PluginFilePath = "$Global:SourcePath\$PluginFile" }
    $PluginsFilePath = @($PluginFilePath)
  } else {
    If ($PluginPath -ne 'null') { 
      $Plugins = Get-Childitem $PluginPath -Recurse -Filter "*.*"
      $PluginsFilePath = $Plugins.FullName
    } Else { 
      Write-Log -Message "Missing parameter, will exit script with RC 1." -Source ${CmdletName}
			Write-Log -Message "============================ Failing: $line ============================" -Source ${CmdletName}
      Set-Finalize -exitCode 1 
    }
  }

  foreach ($Plugin in $PluginsFilePath) {
    $Plugin = Set-StringFromVarLayered -VarToCheck $Plugin
    Write-Log -Message "Will $($actionName.ToUpper()) $Plugin." -Source ${CmdletName}
    $proc = Start-Process -NoNewWindow -Wait -PassThru "$HandlerBinPath" -ArgumentList "$HandlerCMD `"$Plugin`""
    $proc.WaitForExit()
  }
	
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-Dll {
  <#
    .SYNOPSIS
      Register and unregister .dll files.  
    .DESCRIPTION
      Can register and unregister .dll files individually or in batch.   
    .PARAMETER actionName
      The name action type you want to trigger: ADD or REMOVE can be used for	DLL.
    .PARAMETER Data
      Data variable withh all information to execute function like:
      DataDLLFile=DLL file name, can be null - then all files from directory will be used.
      DataDLLPath=Path to DLL file
    .PARAMETER DataType
      As default is a null for DLL. 
    .EXAMPLE
      Conf line: PREINSTALL,ADD,DLL,Microsoft.IdentityModel.Logging.dll=%srcfilepath%\DLLs,null - will register pointed .dll file.
    .EXAMPLE
      Conf line: PREINSTALL,REMOVE,DLL,Microsoft.IdentityModel.Logging.dll=%srcfilepath%\DLLs,null - will unregister pointed .dll file.
    .NOTES
      This is an internal script function and should typically not be called directly, it will be triggered by main script if proper conf line will be found.
    .LINK
      https://github.kyndryl.net/wms-global/WMSAutomationTool/
  #>
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$ActionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$DataType,
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #PREINSTALL,ADD,DLL,DllFile=DllPath,null
  #PREINSTALL,REMOVE,DLL,DllFile=DllPath,null

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  $DllFile = Set-StringFromVarLayered -VarToCheck $Data[0]
  $DllPath = Set-StringFromVarLayered -VarToCheck $Data[1]

  if($DllFile.toLower() -ne 'null') {
    If ($DllPath -ne 'null') { 
      $dllFilePath = "$DllPath\$DllFile"
      $TblFilePath = ("$DllPath\$DllFile").Replace(".dll",".tlb")
    } Else { 
      $dllFilePath = "$Global:SourcePath\$DllFile"
      $TblFilePath = ("$Global:SourcePath\$DllFile").Replace(".dll",".tlb")
    }
    $dllsFilePath = @($dllFilePath)
    $tblsFilePath = @($TblFilePath)
  } else {
    If ($DllPath -ne 'null') { 
      $DllFiles = Get-Childitem $DllPath -filter "*.dll"
      $TBLfiles = Get-Childitem $DllPath -filter "*.tlb"
      $dllsFilePath = $DllFiles.FullName
      $tblsFilePath = $TBLfiles.FullName
    } Else { 
      Write-Log -Message "Missing parameter, will exit script with RC 1." -Source ${CmdletName}
      Set-Finalize -exitCode 1 
    }
  }


  If ($actionName.ToUpper() -eq "REMOVE") {
    foreach ($dllFilePath in $dllsFilePath) {
      $dllFilePath = Set-StringFromVarLayered -VarToCheck $dllFilePath
      $tblFilePath = Set-StringFromVarLayered -VarToCheck $tblFilePath
      
      if ($DllFile -eq 'null') { Test-ParamFile -path $dllFilePath }
      else { 
        If ((Test-Path -Path $dllFilePath) -eq $True) {
          Write-Log -Message "Will unregister existing dll: $dllFilePath." -Source ${CmdletName}
        } else {
          Write-Log -Message "Will skipp unregister, because file is missing - there is nothing to unregister, Return 0." -Source ${CmdletName}
          Return 0 
        }
      } #we can assume that if file is missing we dont have nothing to unregister so it is success.
      
      if ((Test-Path -path $tblFilePath) -eq $True) {
        . "$Env:windir\Microsoft.NET\Framework64\v4.0.30319\regasm.exe" $dllFilePath -tlb -unregister
        Write-Log -Message "Unregistration $dllFilePath ended with. RC = $LastExitCode." -Source ${CmdletName}
      } else {
        $RetCode = regsvr32 /s /u $dllFilePath

        Switch ($LastExitCode) {
          0 {Write-Log -Message "Unregistration $dllFilePath succeeded. RC = 0." -Source ${CmdletName}}
          1 {Write-Log -Message "Unregistration $dllFilePath failed. Invalid argument.RC = 1." -Source ${CmdletName}}
          2 {Write-Log -Message "Unregistration $dllFilePath failed. OleInitialize failed. RC = 2." -Source ${CmdletName}}
          3 {Write-Log -Message "Unregistration $dllFilePath failed. LoadLibrary failed. RC = 3." -Source ${CmdletName}}
          4 {Write-Log -Message "Unregistration $dllFilePath failed. GetProcAdsress failed. RC = 4." -Source ${CmdletName}}
          5 {Write-Log -Message "Unregistration $dllFilePath failed. DllUnregisterServer function failed. RC = 5." -Source ${CmdletName}}
          Default { Write-Log -Message "Unregistration $dllFilePath status unknown." -Source ${CmdletName}}
        }
      }
    }
  } ElseIf ($actionName.ToUpper() -eq "ADD") {
    foreach ($dllFilePath in $dllsFilePath) {
      $dllFilePath = Set-StringFromVarLayered -VarToCheck $dllFilePath
      $tblFilePath = Set-StringFromVarLayered -VarToCheck $tblFilePath
      Test-ParamFile -path $dllFilePath
      
      if ((Test-Path -path $tblFilePath) -eq $True) {
        $file = Get-Item -Path "$tblFilePath"
        $tblFile = $file.Name
        . "$Env:windir\Microsoft.NET\Framework64\v4.0.30319\regasm.exe" $dllFilePath -codebase -tlb:$tblFile
        Write-Log -Message "Registration $tblFile & $dllFilePath ended with. RC = $LastExitCode." -Source ${CmdletName}
      } else {
        regsvr32 /s $dllFilePath

        Switch ($LastExitCode) {
          0 {Write-Log -Message "Registration $dllFilePath succeeded. RC = 0." -Source ${CmdletName}}
          1 {Write-Log -Message "Registration failed. Invalid argument. RC = 1." -Source ${CmdletName}}
          2 {Write-Log -Message "Registration failed. OleInitialize failed. RC = 2." -Source ${CmdletName}}
          3 {Write-Log -Message "Registration failed. LoadLibrary failed. RC = 3." -Source ${CmdletName}}
          4 {Write-Log -Message "Registration failed. GetProcAdsress failed. RC = 4." -Source ${CmdletName}}
          5 {Write-Log -Message "Registration failed. DllUnregisterServer function failed. RC = 5." -Source ${CmdletName}}
          Default { Write-Log -Message "Registration $dllFilePath status unknown." -Source ${CmdletName}}
        }
      }
    }
  }
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Get-ZipContent {
	PARAM (
    [Parameter(Mandatory = $True)]
    [string] $sourceFile
	)

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

	$file = Get-Item -Path "$sourceFile"
	$sourceFileName = $file.Name

	[Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem')
	$zip = [IO.Compression.ZipFile]::OpenRead($sourceFile); 
	$entries = $zip.Entries; 

	$zipLogPath = "$PreLogDir\ZipContent_$sourceFileName.log"
	if (Test-Path $zipLogPath -PathType Leaf) { Remove-Item $zipLogPath }

	Write-Log -Message "Will create: $zipLogPath." -Source ${CmdletName};
	New-Item $zipLogPath
	Write-Log -Message "Will walidate content of $sourceFile to $zipLogPath." -Source ${CmdletName};

	Foreach ($entrie in $entries) { Add-Content -Path $zipLogPath -Value $entrie -PassThru }

	$zip.Dispose()
}

#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-PSUnzipArchive {
	PARAM (
    [Parameter(Mandatory = $True)]
    [string] $ZipFilesPath,
    [Parameter(Mandatory = $True)]
    [string] $UnzipPath
	)

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

	$Shell = New-Object -com Shell.Application
	$progress = 1
	$tempDir =  "$($env:temp)\TmpUnpArch$progress"
	#$Location = $Shell.NameSpace($tempDir)

	if (-not($ZipFilesPath -like "*.zip")) { $ZipFiles = Get-Childitem $ZipFilesPath -Recurse -Include *.zip }
	else { $ZipFiles = $ZipFilesPath }

	foreach ($ZipFile in $ZipFiles) {
		$file = Get-Item -Path "$ZipFile"
		$sourceFileName = $file.Name
		$dirName = $sourceFileName.Replace(".zip","")
		$targetDirectory = "$UnzipPath\$dirName"

		if (Test-Path -Path $tempDir -PathType Container) { Set-RemoveDirectories -isForce "force" -Directory $tempDir }

		#Get-ZipContent -sourceFile "$ZipFile"
		Write-Log -Message "Will unpack: $ZipFile to $targetDirectory." -Source ${CmdletName};

		#Write-Progress -Activity "Unzipping to $($targetDirectory)" -PercentComplete (($progress / ($ZipFiles.Count + 1)) * 100) -CurrentOperation $ZipFile.FullName -Status "File $($Progress) of $($ZipFiles.Count)"

		#$ZipFolder = $Shell.NameSpace($ZipFile.fullname)
		#$Location.Copyhere($ZipFolder.items(), 1040)
		$tmpProgress = $progressPreference
		$Global:ProgressPreference = "SilentlyContinue"
		#$logUnpackPath = "$PreLogDir\ZipUnpackContent_$dirName.log"
		Write-Log -Message "Expand-Archive -LiteralPath `"$ZipFile`" -DestinationPath `"$tempDir`" -Force." -Source ${CmdletName};
		Expand-Archive -LiteralPath "$ZipFile" -DestinationPath "$tempDir" -Force
		$logPath = "$PreLogDir\ZipCopyContent_$dirName.log"
		Write-Log -Message "Xcopy /E /I /S /H /Y `"$tempDir`" `"$UnzipPath`" > `"$logPath`"." -Source ${CmdletName};
		Xcopy /E /I /S /H /Y "$tempDir" "$UnzipPath" > "$logPath"
		Set-RemoveDirectories -isForce "force" -Directory $tempDir
		$Global:ProgressPreference = $tmpProgress
		
		$progress++
	}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Get-7zipInfo {
	$RC = "null"
	$apps = Get-ChildItem HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall | ForEach-Object { Get-ItemProperty $_.PsPath } | Select-Object DisplayName,InstallLocation

	ForEach ($app in $apps) { if ($app.DisplayName -like "7-Zip*") { $RC = $app.InstallLocation } }

	if ($RC -eq "null") {
		$apps = Get-ChildItem HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall | ForEach-Object { Get-ItemProperty $_.PsPath } | Select-Object DisplayName,InstallLocation
		ForEach ($app in $apps) { if ($app.DisplayName -like "7-Zip*") { $RC = $app.InstallLocation } }
	}

	Return $RC
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-Archive {
  <#
    .SYNOPSIS
      Create archive or unpack existing one (.zip or 7z if accessible). 
    .DESCRIPTION
      Will handle creation or unpacking of archives using build in windows/PowerShell zip support or 3rth party 7zip (recommended).
    .PARAMETER actionName
      The name action type you want to trigger: ADD or REMOVE can be used for ARCHIVE.
    .PARAMETER Data
      Data variable withh all information to execute function like:
      DataTargePath =Source directory path (directory to be archived) or target directory path (directory where archive will be unpacked)
      DataArchivePath=Name for new archive 
      DataArchiveName =Directory to store new archive
      DataArchiveType=Archiver type. List: ps, system, 7zip.
    .PARAMETER DataType
      As default is a null for ARCHIVE.
    .EXAMPLE
      Conf line: PREINSTALL,ADD,ARCHIVE,c:\files\directory=directory=c:\backup=7zip,null - create a new 7zip archive.
    .EXAMPLE
      Conf line: PREINSTALL,UNPACK,ARCHIVE,directory=c:\backup=c:\files\directory=7zip,null - unpack a 7zip archive.
    .NOTES
      This is an internal script function and should typically not be called directly, it will be triggered by main script if proper conf line will be found.
    .LINK
      https://github.kyndryl.net/wms-global/WMSAutomationTool/
  #>
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$ActionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$DataType,
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #PREINSTALL,ADD,ARCHIVE,DirPath=DirName=TargetDir=Type,null
  #PREINSTALL,UNPACK,ARCHIVE,ArchFile=ArchDirPath=UnpackDir=Type,null

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}
	
  Get-DiscSpace -drive "C"
	#$7zipReg = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\7-Zip"
  $is7zip = $False

  $UnpackerType = $Data[3]

  <# if ((Test-RegValExist -Path $7zipReg -Name 'Path') -eq $True) {
    Write-Log -Message "$7zipReg exist." -Source ${CmdletName};
    $is7zip = $True
    $7zipHome = (Get-ItemProperty -Path "$7zipReg" -Name 'Path').Path
    $7zipPath = join-path -Path "$7zipHome" -ChildPath "7z.exe"
  } elseif ((Test-RegValExist -Path $7zipReg -Name 'Path64') -eq $True) {
    Write-Log -Message "$7zipReg is missing." -Source ${CmdletName};
    $is7zip = $True
    $7zipHome = (Get-ItemProperty -Path "$7zipReg" -Name 'Path64').Path
    $7zipPath = join-path -Path "$7zipHome" -ChildPath "7z.exe"
  } else { $is7zip = $False } #>

  #[string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent
  $7zipLocBin = "7z.exe"
  #$7zipPathLoc = "$scriptDirectory\AppDeployToolkit\$7zipLocBin"
	$7zipPathLoc = "$(Get-7zipInfo)$7zipLocBin"
	if ($(Get-7zipInfo) -ne "null") { $is7zip = $True }

  if ($UnpackerType.ToLower() -eq "7zip") {
    if ($is7zip -eq $False) {
			Write-Log -Message "7z app is missing on machine, will try to use ps zip support." -Source ${CmdletName};
			$UnpackerType = 'ps'
      <# if((Test-Path -Path $7zipPathLoc) -eq $False) {
        Write-Log -Message "7z was not found, will use native PS zip support." -Source ${CmdletName};
        $UnpackerType = 'system'
      } else { 
        $is7zip = $True
        $7zipPath = $7zipPathLoc
        Write-Log -Message "7z wrapper version was found in $7zipPath, will use 7z support." -Source ${CmdletName}; 
      } #>
    } else { Write-Log -Message "7z was found in $7zipPathLoc, will use 7z support." -Source ${CmdletName}; }
  }

  If ($actionName.ToUpper() -eq "UNPACK") {
    $ArchFile = Set-StringFromVarLayered -VarToCheck $Data[0]
    $UnpackDir = Set-StringFromVarLayered -VarToCheck $Data[2]
    $ArchDirPath = $Data[1]

    if (($ArchDirPath.ToLower() -eq "null") -or ([string]::IsNullOrEmpty($ArchDirPath))) { $Directory = $Global:SourcePath  }
    else { $Directory = Set-StringFromVarLayered -VarToCheck $ArchDirPath }

    $ArchDirPath = Set-StringFromVarLayered -VarToCheck $ArchDirPath
    Test-ParamFile -path "$Directory\$ArchFile"
    Write-Log -Message "ExtractToDirectory($Directory\$ArchFile ,$UnpackDir)" -Source ${CmdletName}

    if ($UnpackerType.ToLower() -eq 'system') {
      Add-Type -AssemblyName System.IO.Compression.FileSystem
      [System.IO.Compression.ZipFile]::ExtractToDirectory("$Directory\$ArchFile" ,"$UnpackDir")
    } elseif ($UnpackerType.ToLower() -eq "7zip") {
      if ($is7zip -eq $False) {
        Write-Log -Message "7zip is missing on machine. PKG failed." -Source ${CmdletName}
				Write-Log -Message "============================ Failing: $line ============================" -Source ${CmdletName}
        Set-Finalize -ExitCode -1
      } else {
        Test-ParamFile -path "$7zipPathLoc"
        & "$7zipPathLoc" x "$Directory\$ArchFile" -o"$UnpackDir" -y >> "$($Global:PreLogDir)\$($ArchFile)_Unpack.log" 2>&1
      }
    } elseif ($UnpackerType.ToLower() -eq 'ps') {
			Set-PSUnzipArchive -ZipFilesPath "$Directory\$ArchFile" -UnzipPath "$UnpackDir"
			#Expand-Archive -LiteralPath "$Directory\$ArchFile" -DestinationPath "$UnpackDir" -Force 
		}
  } ElseIf ($actionName.ToUpper() -eq "ADD") {
    $DirPath = Set-StringFromVarLayered -VarToCheck $Data[0]
    $DirName = Set-StringFromVarLayered -VarToCheck $Data[1]
    $TargetDir = Set-StringFromVarLayered -VarToCheck $Data[2]
    New-ZipFile -DestinationArchiveDirectoryPath "$TargetDir" -DestinationArchiveFileName "$DirName.zip" -SourceDirectory "$DirPath" -OverWriteArchive $True
  }
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-RegPath {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$KeyPath
  )

  if (-not($KeyPath -like "Registry::*")) {
    $KeyPath = $KeyPath.Replace("HKEY_LOCAL_MACHINE\","HKLM:\")
    $KeyPath = $KeyPath.Replace("HKEY_CURRENT_USER\","HKCU:\")
    $KeyPath = $KeyPath.Replace("HKEY_USERS\","HKU:\")
    $KeyPath = $KeyPath.Replace("HKEY_LOCAL_MACHINE:\","HKLM:\")
    $KeyPath = $KeyPath.Replace("HKEY_CURRENT_USER:\","HKCU:\")
    $KeyPath = $KeyPath.Replace("HKEY_USERS:\","HKU:\")
    $KeyPath = $KeyPath.Replace("HKLM\","HKLM:\")
    $KeyPath = $KeyPath.Replace("HKCU\","HKCU:\")
    $KeyPath = $KeyPath.Replace("HKU\","HKU:\")
    $KeyPath = $KeyPath.Replace("HKEY_CLASSES_ROOT\","Registry::HKEY_CLASSES_ROOT\")
    $KeyPath = $KeyPath.Replace("HKEY_CLASSES_ROOT:\","Registry::HKEY_CLASSES_ROOT\")
  }

  Return $KeyPath
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Test-ForReg {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$KeyPath
  )

  $RC = $False

  if (($KeyPath.ToUpper() -like "HKLM*") -or ($KeyPath.ToUpper() -like "HKCU*") -or ($KeyPath.ToUpper() -like "HKU*")) { $RC = $True }
  if (($KeyPath.ToUpper() -like "HKEY_LOCAL_MACHINE*") -or ($KeyPath.ToUpper() -like "HKEY_CURRENT_USER*") -or ($KeyPath.ToUpper() -like "HKEY_USERS*")) { $RC = $True }
  if ($KeyPath.ToUpper() -like "Registry::*") { $RC = $True }

  Return $RC
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Get-RegValue {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$KeyPath,
    [Parameter(Mandatory = $False)]
    [String]$ValueName
  )

  $KeyPath = Set-RegPath -KeyPath $KeyPath

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "Will gather $ValueName in $KeyPath." -Source ${CmdletName}
  $RC = (Get-ItemProperty -LiteralPath $KeyPath -name $ValueName).$ValueName
  Return $RC
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-Settings {
  <#
    .SYNOPSIS
      Custom OS based settings to be applied. 
    .DESCRIPTION
      Can handle a set of different OS based actions like: disable chrome updates, make an reboot etc. 
    .PARAMETER actionName
      The name action type you want to trigger: ADD can be used for SETTINGS.
    .PARAMETER Data
      Data variable withh all information to execute function like:
      DataSetName=Name of the settings to applied. List: Culture, NetUse, Reboot, chromeupdates.
      DataSetValue=Value for the applied setting. 
    .PARAMETER DataType
      As default is a null for SETTINGS.
    .EXAMPLE
      Conf line: PREINSTALL,REMOVE,SETTINGS,CHROMEUPDATES=null,null - disable chrome updates.
    .EXAMPLE
      Conf line: POSTINSTALL,ADD,SETTINGS,REBOOT=300,null - run OS reboot with a default UI messages.
    .NOTES
      This is an internal script function and should typically not be called directly, it will be triggered by main script if proper conf line will be found.
    .LINK
      https://github.kyndryl.net/wms-global/WMSAutomationTool/
  #>
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$ActionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$DataType,
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #PREINSTALL,ADD,SETTINGS,SetName=SetValue,null
  #PREINSTALL,REMOVE,SETTINGS,SetName=SetValue,null
  #PREINSTALL,CHANGE,SETTINGS,SetName=SetValue,null
  #PREINSTALL,ADD,SETTINGS,NETUSE=SetValue,null
  #PREINSTALL,REMOVE,SETTINGS,CHROMEUPDATES=null,null

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  $SetName = $Data[0]
  $SetValue = $Data[1]

  if ($SetName.ToLower() -eq "culture") {
    Write-Log -Message "Set new value for Culture: $SetValue" -Source ${CmdletName}
    Set-Culture -CultureInfo $SetValue
  }
  if ($SetName.ToLower() -eq "netuse") {
    Write-Log -Message "Set new value for NET USE: $SetValue" -Source ${CmdletName}
    NET USE $SetValue
  }
  if ($SetName.ToLower() -eq "reboot") {
    Write-Log -Message "Set shutdown /f /r /t $SetValue" -Source ${CmdletName}
    shutdown /f /r /t $SetValue
  }
  if ($SetName.ToLower() -eq "chromeupdates") {
    Set-RegistryKey -Key 'HKLM\SOFTWARE\Policies\Google\Update' -Name 'UpdateDefault' -Type 'Dword' -Value '0'
    Set-RegistryKey -Key 'HKLM\SOFTWARE\Policies\Google\Update' -Name 'DisableAutoUpdateChecksCheckboxValue' -Type 'Dword' -Value '1'
    Set-RegistryKey -Key 'HKLM\SOFTWARE\Policies\Google\Update' -Name 'AutoUpdateCheckPeriodMinutes' -Type 'Dword' -Value '0'
    Set-RegistryKey -Key 'HKLM\SOFTWARE\Wow6432Node\Google\Update' -Name 'UpdateDefault' -Type 'Dword' -Value '0'
    Set-RegistryKey -Key 'HKLM\SOFTWARE\Wow6432Node\Google\Update' -Name 'DisableAutoUpdateChecksCheckboxValue' -Type 'Dword' -Value '1'
    Set-RegistryKey -Key 'HKLM\SOFTWARE\Wow6432Node\Google\Update' -Name 'AutoUpdateCheckPeriodMinutes' -Type 'Dword' -Value '0'

    $chromePathReg = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe"
    $isChrome = $False

    if ((Test-RegValExist -Path $chromePathReg -Name 'Path') -eq $True) {
      $isChrome = $True
      $chromeAppPath = Get-RegValue -KeyPath $chromePathReg -ValueName 'Path'
      Write-Log -Message "Will edit: $chromeAppPath." -Source ${CmdletName}

      if ([string]::IsNullOrEmpty($chromeAppPath)) {
        Write-Log -Message "Variable is empty, exiting script." -Source ${CmdletName}
				Write-Log -Message "============================ Failing: $line ============================" -Source ${CmdletName}
        Set-Finalize -ExitCode  -1
      } else { 
        $chromeUpdatesPath = $chromeAppPath.Replace("\Chrome\Application","")
        Write-Log -Message "Result: $chromeUpdatesPath." -Source ${CmdletName}
      }
    } else { $isChrome = $False }

    if ($isChrome -eq $False) {
      Write-Log -Message "Google Chrome is missing on machine. PKG failed." -Source ${CmdletName}
			Write-Log -Message "============================ Failing: $line ============================" -Source ${CmdletName}
      Set-Finalize -ExitCode -1
    } else { Write-Log -Message "Google Chrome is present on machine. Going to next step." -Source ${CmdletName} }

    Write-Log -Message "Disabling Google Chrome Updates" -Source ${CmdletName}
    $proc1 = "googleupdate.exe=kill;block"
    $arr = $proc1.Split("=")
      Set-Process -actionName "STOP" -Data $arr
    $serv1 = "gupdate=null=null"
    $arr = $serv1.Split("=")
      Set-Services -actionName "STOP" -Data $arr
    $serv1 = "gupdate=null=null"
    $arr = $serv1.Split("=")
      Set-Services -actionName "REMOVE" -Data $arr
    $serv2 = "gupdatem=null=null"
    $arr = $serv2.Split("=")
      Set-Services -actionName "STOP" -Data $arr
    $serv2 = "gupdatem=null=null"
    $arr = $serv2.Split("=")
      Set-Services -actionName "REMOVE" -Data $arr
    #$task1 = "GoogleUpdateTaskMachineCore=null=null=null"
    #$arr = $task1.Split("=")
    #  Set-ScheduledTaskWrap -ActionName "REMOVE" -Data $arr
    #$task2 = "GoogleUpdateTaskMachineUA=null=null=null"
    #$arr = $task2.Split("=")
    #  Set-ScheduledTaskWrap -ActionName "REMOVE" -Data $arr
    $task = "GoogleUpdateTaskMachine*=null=null=null"
    $arr = $task.Split("=")
      Set-ScheduledTaskWrap -ActionName "REMOVE" -Data $arr
    
    if ((test-path -path "$chromeUpdatesPath\Update") -eq $False) {
      $is64B = [System.Environment]::Is64BitOperatingSystem
      if (($chromeUpdatesPath -like "*\Program Files\*") -and ($is64B -eq $True)) { $chromeUpdatesPath = $chromeUpdatesPath.Replace('Program Files','Program Files (x86)') }
    }
    
    if ((Test-path -path "$chromeUpdatesPath\Update1") -eq $True) { &cmd.exe /c rd /s /q "$chromeUpdatesPath\Update1" }

    $ufile = "$chromeUpdatesPath\Update"
    $arr = $ufile.Split("=")
      Set-UnblockFiles -actionName "ADD" -Data $arr
    $dir = "$chromeUpdatesPath\Update=$chromeUpdatesPath\Update1"
    $arr = $dir.Split("=")
      Set-DirAction -actionName "RENAME" -Data $arr

    if (((Test-path -path "$chromeUpdatesPath\Update") -eq $True) -and ((Test-path -path "$chromeUpdatesPath\Update1") -eq $True)) { &cmd.exe /c rd /s /q "$chromeUpdatesPath\Update" }
  }
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-ScheduledTaskWrap {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$ActionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$DataType,
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #PREINSTALL,REMOVE,SCHEDULEDTASK,GoogleUpdateTaskMachineUA=null=null=null,null
  #PREINSTALL,RUN,SCHEDULEDTASK,GoogleUpdateTaskMachineUA=null=null=null,null
  #PREINSTALL,ADD,SCHEDULEDTASK,GoogleUpdateTaskMachineUA=powershell.exe=-File C:\scripts\Get-LatestAppLog.ps1=Once@12:00,null

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  $TaskName = Set-StringFromVarLayered -VarToCheck $Data[0]
  $TaskExecute = Set-StringFromVarLayered -VarToCheck $Data[1]
  $TaskArguments = Set-StringFromVarLayered -VarToCheck $Data[2]
  $TaskTrigger = Set-StringFromVarLayered -VarToCheck $Data[3]

  $TaskArguments = Set-SpecialCharacters -string $TaskArguments

  If (($actionName.ToUpper() -eq "NEW") -or ($actionName.ToUpper() -eq "ADD")) {
    if ($Global:userActions.ToLower() -eq 'false') { 
      Write-Log -Message "Will skipp ${CmdletName} execution. userActions = $($Global:userActions)." -Source ${CmdletName} -Severity 3
      Write-Log -Message "For your account use an other method for actions in user context/manipulation of user profiles." -Source ${CmdletName} -Severity 3 
    } else {
      if ($TaskTrigger.ToLower() -ne 'null') { #todo: need to handle triggers
        #$Time = New-ScheduledTaskTrigger -Daily -DaysInterval 3 -At 3am
        #        New-ScheduledTaskTrigger -Weekly -WeeksInterval 2 -DaysOfWeek Sunday -At 3am
        #        New-ScheduledTaskTrigger -AtLogon/AtStartup
        #if ($TaskArguments -ne 'null') { $taskAction = New-ScheduledTaskAction -Execute $TaskExecute -Argument $TaskArguments -Trigger $Time }
        #else { $taskAction = New-ScheduledTaskAction -Execute $TaskExecute -Trigger $Time }
      } else {
        if ($TaskArguments.ToLower() -ne 'null') {
          $taskProperties = @{
            Execute  = $TaskExecute
            Argument = $TaskArguments
          }
        } else {
          $taskProperties = @{
            Execute  = $TaskExecute
          }
        }
        $newAction = New-ScheduledTaskAction @taskProperties -Verbose
      }

      Write-Log -Message "Creating scheduledtask: $TaskName." -Source ${CmdletName}
      Set-ScheduledTask $TaskName -Action $taskAction
    }
  } elseIf ($actionName.ToUpper() -eq "SET") {
  } elseIf ($actionName.ToUpper() -eq "RUN") {
    if ($Global:userActions.ToLower() -eq 'false') { 
      Write-Log -Message "Will skipp ${CmdletName} execution. userActions = $($Global:userActions)." -Source ${CmdletName} -Severity 3
      Write-Log -Message "For your account use an other method for actions in user context/manipulation of user profiles." -Source ${CmdletName} -Severity 3 
    } else {
      if(Get-ScheduledTask $TaskName -ErrorAction Ignore) {
        Write-Log -Message "Running Scheduled Task: $TaskName." -Source ${CmdletName}
        Start-ScheduledTask -TaskName $TaskName -Confirm:$false
      } else { Write-Log -Message "$TaskName is not present, nothink to start. Going to next step." -Source ${CmdletName} }
    }
  } elseIf ($actionName.ToUpper() -eq "REMOVE") {
    if(Get-ScheduledTask $TaskName -ErrorAction Ignore) {
      $LastOne = $TaskName.Substring($TaskName.get_Length()-1)
      Write-Log -Message "Checking if AppName contains wildcard: WildCard - $WildCard." -Source ${CmdletName}
      if($LastOne -eq "*") {
        $Tasks = Get-ScheduledTask $TaskName -ErrorAction Ignore
        foreach ($Task in $Tasks) {
          $name = ($Task.TaskName).Replace("\","") 
          Write-Log -Message "Removing Scheduled Task: $name." -Source ${CmdletName}
          Unregister-ScheduledTask -TaskName "$name" -Confirm:$false
        }
      } else {
        Write-Log -Message "Removing Scheduled Task: $TaskName." -Source ${CmdletName}
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
      }
    } else { Write-Log -Message "$TaskName is not present, nothink to remove. Going to next step." -Source ${CmdletName} }
  } 
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Get-LogStatus {
  param(
    [Parameter(Mandatory = $True)]
    [String]$PKGName,
    [Parameter(Mandatory = $False)]
    [String]$LogPartName,
    [Parameter(Mandatory = $False)]
    [String]$useDirectName = $false
  )

  if ($useDirectName -eq $true) { $LogFile = $PKGName + ".log" }
  else { $LogFile = $PKGName +"_" + $LogPartName +"_" + "VBS.log" }

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  $ReturnCode = $False
  $SplitPath = $Global:PreLogDir | Split-Path
  $Global:PreLogDir = $SplitPath + '\' + $PKGName
  $logPath = "$Global:PreLogDir\$LogFile"
  $Action = $LogPartName + "ation"

  If (!(Test-Path -Path $logPath)) { Write-Log -Message "Log file $logPath doesn't exist." -Source ${CmdletName} }
  Else {
    Write-Log -Message "Log file $logPath exist." -Source ${CmdletName}
    $LogFileContent = Get-Content -Path $logPath | Select-Object -last 10 | ForEach-Object { If (($_ -Match "SETUP INFO: $Action was successful.") -Or ($_ -Match "SETUP INFO: $Action success.")) { Write-Log -Message "Success line found."; $ReturnCode = $True }}
  }

  Return $ReturnCode
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-AppVAction { #how to - handle user context
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #INSTALL,ADD,APPV,AppVFile=Context=LogType=AppVPKGName,null    (INSTALL,ADD,APPV,MozillaFirefox16.appv=Global=Verbose,null)
  #UNINSTALL,REMOVE,APPV,AppVPKGName,null

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  $appvmodule = "AppvClient"
  if(-not(Get-Module -name $appvmodule)) {
    if(Get-Module -ListAvailable | Where-Object { $_.name -eq $appvmodule }) {
      try {
        Import-Module -Name $appvmodule -ErrorAction Stop | Out-Null;
        Write-Log -Message "$appvmodule module has been imported" -Source ${CmdletName}
      } catch { 
        Write-Log -Message "Error: Unable to import '$appvmodule" -Source ${CmdletName} 
      }
    }
    $status = Get-AppvStatus
    $isClientEnabled = $status.AppvClientEnabled
  } else { 
    Write-Log -Message "Error: Powershell module '$appvmodule' does not exist.  Is the App-V 5 Client installed?" -Source ${CmdletName}
    $isClientEnabled = $false
  }

  if ($isClientEnabled -eq $True) {
    Write-Log -Message "AppV client is avaliable, will proceed with $($actionName.ToUpper()) AppV." -Source ${CmdletName}
    If ($actionName.ToUpper() -eq "ADD") {
      $AppVFile = Set-StringFromVarLayered -VarToCheck $Data[0]
      $Context = Set-StringFromVarLayered -VarToCheck $Data[1]
      $LogType = Set-StringFromVarLayered -VarToCheck $Data[2]
      $AppVPKGName = Set-StringFromVarLayered -VarToCheck $Data[3]

      If ($AppVFile -like "*.appv") { $AppVFile = "$AppVFile" }
      else { $AppVFile = "$AppVFile.appv" }

      $AppvPath = Get-FullPath -path $AppvPath
      #if ((-not (($AppVFile -like "\\*") -or ($AppVFile -like "*:\*")))) { $AppvPath = "$Global:SourcePath\$AppVFile" } 
      #else { $AppvPath = "$AppVFile" }

      Test-ParamFile -path $AppvPath
      Get-AppvClientPackage -Name $AppVPKGName | Stop-AppvClientPackage | Remove-AppvClientPackage
      if (($Context.ToLower() -eq "global") -or ($Context.ToLower() -eq "null")) { Add-AppvClientPackage -Path $AppvPath | Publish-AppvClientPackage -Global | Mount-AppvClientPackage -Verbose }
      else { Add-AppvClientPackage -Path $AppvPath | Publish-AppvClientPackage | Mount-AppvClientPackage -Verbose }
    } elseif ($actionName.ToUpper() -eq "REMOVE") {
      $AppVPKGName = $Data[0]
      Get-AppvClientPackage -Name $AppVPKGName | Stop-AppvClientPackage | Unpublish-AppvClientPackage -Global | Remove-AppvClientPackage
    } elseif ($actionName.ToUpper() -eq "UNPUBLISH") {
      Get-AppvClientPackage -Name $AppVPKGName | Stop-AppvClientPackage | Unpublish-AppvClientPackage -Global
    }
  } else { Write-Log -Message "AppV client is not enabled on machine, will skipp all AppV actions." -Source ${CmdletName} }
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-AppVCGAction {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #INSTALL,ADD,AppVCG,CGName=USERSID=XMSLFileName,null
  #UNINSTALL,REMOVE,AppVCG,CGName=USERSID,null

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

	$CGAll = Get-AppvClientConnectionGroup -all
	$Test = $False

	If ($actionName.ToUpper() -eq "ADD") {
		$CGName = Set-StringFromVarLayered -VarToCheck $Data[0]
		$USERSID = Set-StringFromVarLayered -VarToCheck $Data[1]
		$XMLFileName = Set-StringFromVarLayered -VarToCheck $Data[2]

		Set-AppvClientConfiguration -RequirePublishAsAdmin 0

		$RC = Get-ParamCheck -ParamName "USERSID" -Param $USERSID

		If ($XMLFileName -like "*.xml") { $XMLFile = "$Global:ConfigFilesPath\$XMLFileName" }
		else { $XMLFile = "$Global:ConfigFilesPath\$XMLFileName.xml" }

    Test-ParamFile -path $XMLFile

		ForEach ($CG in $CGAll) { If ($CG.Name -eq $CGName) { $Test = $True }}

		If ($Test -eq $False) {
			Add-AppvClientConnectionGroup -path $XMLFile
			If ($RC -eq $True) { Enable-AppVClientConnectionGroup -Name $CGName -UserSID $USERSID -Global }
			Else { Enable-AppVClientConnectionGroup -Name $CGName -Global }
		}
	} elseif ($actionName.ToUpper() -eq "REMOVE") {
		$CGName = Set-StringFromVarLayered -VarToCheck $Data[0]
		$USERSID = Set-StringFromVarLayered -VarToCheck $Data[1]
		$RC = Get-ParamCheck -ParamName "USERSID" -Param $USERSID
    $XMLFile = "$Global:ConfigFilesPath\$CGName.xml"
    Test-ParamFile -path $XMLFile
		[xml]$xmlCGFile = Get-Content $XMLFile

    $AppConnectionGroupId = ($xmlCGFile.AppConnectionGroup).AppConnectionGroupId
    $VersionId = ($xmlCGFile.AppConnectionGroup).VersionId

		ForEach ($CG in $CGAll) {
			If ($CG.Name -eq $CGName) {
				If ($RC -eq $True) {
					Stop-AppvClientConnectionGroup -GroupId $AppConnectionGroupId -VersionId $VersionId # -Name $CGName
					#$CGID = Get-AppVClientConnectionGroup -GroupId $AppConnectionGroupId -VersionId $VersionId
					Disable-AppVClientConnectionGroup -GroupId $AppConnectionGroupId -VersionId $VersionId -UserSID $USERSID
					Remove-AppvClientConnectionGroup -GroupId $AppConnectionGroupId -VersionId $VersionId
				} Else {
					Stop-AppvClientConnectionGroup -GroupId $AppConnectionGroupId -VersionId $VersionId # -Name $CGName
					#$CGID = Get-AppVClientConnectionGroup -GroupId $AppConnectionGroupId -VersionId $VersionId
					Disable-AppVClientConnectionGroup -GroupId $AppConnectionGroupId -VersionId $VersionId -Global
					Remove-AppvClientConnectionGroup -GroupId $AppConnectionGroupId -VersionId $VersionId
				}
			}
		}
	}
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Create-AppVCGXML {
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #INSTALL,ADD,XMLAppVCG,CGName=XMLName=PackageId1;PackageId2=VersionId1;VersionId2,null

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  $DoubleQuota = [char]34

  $AppConnectionGroupId = (New-Guid).Guid
	$VersionId = (New-Guid).Guid
  $CGName = Set-StringFromVarLayered -VarToCheck $Data[0]
	$XMLName = Set-StringFromVarLayered -VarToCheck $Data[1]
  $PackageIdArr = Set-StringFromVarLayered -VarToCheck $Data[2]
  $VersionIdArr = Set-StringFromVarLayered -VarToCheck $Data[3]

  $newLine = "

            "

  $pkgTemplate = "<appv:Package
				PackageId="+[char]34+"%PackageId%"+[char]34+"
				VersionId="+[char]34+"%VersionId%"+[char]34+"
				IsOptional="+[char]34+"false"+[char]34+"
			/>"

  $xmlTemplate = "<?xml version="+[char]34+"1.0"+[char]34+" encoding="+[char]34+"UTF-16"+[char]34+"?>
	<appv:AppConnectionGroup
		xmlns="+[char]34+"http://schemas.microsoft.com/appv/2014/virtualapplicationconnectiongroup"+[char]34+"
		xmlns:appv="+[char]34+"http://schemas.microsoft.com/appv/2014/virtualapplicationconnectiongroup"+[char]34+"
		AppConnectionGroupId="+[char]34+"$AppConnectionGroupId"+[char]34+"
		VersionId="+[char]34+"$VersionId"+[char]34+"
		Priority="+[char]34+"0"+[char]34+"
		DisplayName="+[char]34+"$CGName"+[char]34+">
			<appv:Packages>
			%PKGTemplate%
			</appv:Packages>
	</appv:AppConnectionGroup>"

  $PackageIds = $PackageIdArr.Split(";")
	$VersionIds = $VersionIdArr.Split(";")

	$xmlFileName = "$Global:ConfigFilesPath\$XMLName.xml"

	$ArraySize = $PackageIds.GetUpperBound(0)
	$pkgTemplates = ""
	$x = 0

	ForEach ($PackageId in $PackageIds) {
    If (($VersionIds[$x] -ne "NULL") -AND ($VersionIds[$x] -ne "*") -AND ($VersionIds[$x] -ne "")) { $xmlTemplateTmp = ($pkgTemplate.replace("%PackageId%",$PackageId)).replace("%VersionId%",$VersionIds[$x]) }
    else { $xmlTemplateTmp = ($pkgTemplate.replace("%PackageId%",$PackageId)).replace("%VersionId%","*") }

    If ($pkgTemplates -eq "") { $pkgTemplates = $xmlTemplateTmp }
    else { $pkgTemplates = $pkgTemplates + $newLine + $xmlTemplateTmp }
		$x++
	}

	if (Test-Path $xmlFileName) { Remove-Item $xmlFileName }

	$xmlTemplate = $xmlTemplate.replace("%PKGTemplate%",$pkgTemplates)
	New-Item -ItemType Directory -Force -Path $Global:ConfigFilesPath
	Out-File -FilePath $xmlFileName -InputObject $xmlTemplate -Encoding Unicode -NoClobber -Force
	
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-UserBasedUninstall {
  param(
    [Parameter(Mandatory = $True)]
    [String]$exePath,
    [Parameter(Mandatory = $false)]
    [String]$exeCMD
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "Starting ${CmdletName} for: $GUID_Name" -Source ${CmdletName}


}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Test-UserBasedInstall {
  param(
    [Parameter(Mandatory = $True)]
    [String]$GUID_Name,
    [Parameter(Mandatory = $false)]
    [String]$exeVer = "null"
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "Starting ${CmdletName} for: $GUID_Name" -Source ${CmdletName}

  
  
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Test-EXEGUID {
  param(
    [Parameter(Mandatory = $True)]
    [String]$GUID_Name,
    [Parameter(Mandatory = $false)]
    [String]$exeVer = "null"
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "Starting ${CmdletName} for: $GUID_Name" -Source ${CmdletName}

  $appData = ""
  $isinstalled = $False
  $GUID = $GUID_Name
  $name = "null"
  $version = "null"
  
  if ($GUID_Name.ToLower() -ne 'null') { 
    if ($GUID_Name -like "*{") {
      $appData = Get-InstalledApplication -ProductCode $GUID_Name
      If (-not([string]::IsNullOrWhiteSpace($appData.DisplayName))) { $isinstalled = $True }
    } elseif ($GUID_Name.Contains("*")) {
      $appData = Get-InstalledApplication -ProductCode $GUID_Name
      If ([string]::IsNullOrWhiteSpace($appData.DisplayName)) {
        $appData = Get-InstalledApplication -Name $GUID_Name -WildCard $True 
        If (-not([string]::IsNullOrWhiteSpace($appData.DisplayName))) { $isinstalled = $True }
      } else { $isinstalled = $True }
    } else { 
      $appData = Get-InstalledApplication -ProductCode $GUID_Name
      If ([string]::IsNullOrWhiteSpace($appData.DisplayName)) { 
        $appData = Get-InstalledApplication -Name $GUID_Name
        If ([string]::IsNullOrWhiteSpace($appData.DisplayName)) {
          $appData = Get-InstalledApplication -Name $GUID_Name -WildCard $True
          If (-not([string]::IsNullOrWhiteSpace($appData.DisplayName))) { $isinstalled = $True }
        } else { $isinstalled = $True }
      } else { $isinstalled = $True }
    }
  } else { $isinstalled = $True }

  If (($isinstalled -eq $True) -and (-not([string]::IsNullOrWhiteSpace($appData.DisplayName)))) { $name = $appData.DisplayName }
  If (($isinstalled -eq $True) -and (-not([string]::IsNullOrWhiteSpace($appData.DisplayVersion)))) { $version = $appData.DisplayVersion }
  If (($isinstalled -eq $True) -and (-not([string]::IsNullOrWhiteSpace($appData.ProductCode)))) { $GUID = $appData.ProductCode }
  elseif (($isinstalled -eq $True) -and (-not([string]::IsNullOrWhiteSpace($appData.UninstallSubkey)))) { $GUID = $appData.UninstallSubkey }

  $RC = New-Object System.Collections.ArrayList($null)

  if ($GUID -is [array]) {
    $i = 0
    foreach($G in $GUID) {
      [void]($RC.Add([pscustomobject]@{isinstalled=$isinstalled; GUID=$GUID[$i]; Name=$name[$i]; Version=$version[$i]}))
      $i++
    }
  } else { [void]($RC.Add([pscustomobject]@{isinstalled=$isinstalled; GUID=$GUID; Name=$name; Version=$version})) }

  Foreach ($Item in $RC) { Write-Log -Message "isinstalled: $($Item.GUID) = $($Item.Name) = $($Item.Version) = $isinstalled" -Source ${CmdletName} }

  Return $RC
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-ExeAsUserAction {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$DataType = "null",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #INSTALL,ADD,EXEASUSER,EXEFile=CMDParams=UserName,null

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  $EXEFile = Set-StringFromVarLayered -VarToCheck $Data[0]
  $CMDParams = Set-StringFromVarLayered -VarToCheck $Data[1]
  $UserAccount = Set-StringFromVarLayered -VarToCheck $Data[2]

  $CMDParams = Set-SpecialCharacters $CMDParams
  $SuccessCode = '3010,0'

  if ($UserAccount.ToLower() -eq "null") { Execute-ProcessAsUser -Path "$EXEFile" -Parameters "$CMDParams" -Wait }
  else { Execute-ProcessAsUser -UserName "$env:computername\$UserAccount" -Path "$EXEFile" -Parameters "$CMDParams" -Wait }
  
	
  #Execute process under a user account by specifying a username under which to execute it.
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-ExeAction {
  <#
    .SYNOPSIS
      Can install, uninstall exe based setups or run exe files.  
    .DESCRIPTION
      It handles exe setups; installation and uninstallation or simple exe start process. If additional cmd parameters need to be provided, replace “=” by “><”. Can uninstall exe setups using uninstall.exe or guid (will extract uninstall string).
    .PARAMETER actionName
      The name action type you want to trigger: ADD or REMOVE can be used for	EXE.
    .PARAMETER Data
      Data variable withh all information to execute function like:
      DataEXEFile=Path to .exe file
      DataEXEParams=Additional cmd parameters, for pass to exe 
      DataPKGName=Defined PKG Name for this application or package (used for TAG, log name)
      DataGUID=GUID or item in HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall or HKEY_LOCAL_MACHINE\SOFTWARE \Microsoft\Windows\CurrentVersion\Uninstall
      DataEXEUninstallFile=Path to .exe file
    .PARAMETER DataType
      As default is a null for EXE. 
      DataSuccessCode=Custom exit code that will be treated as success
    .EXAMPLE
      Conf line: UNINSTALL,REMOVE,EXE,{5DD37F97-3F65-4C24-B80D-D12913A4D214}=null=Cisco_CiscoMeeting_1.9.19.0_SCH_W10_EN_B1=null,null - will uninstall Cisco Meeting using silent uninstall string from ARP.
    .EXAMPLE
      Conf line: INSTALL,ADD,EXE,FramePkg.exe=/INSTALL><AGENT /SILENT /LOGDIR><%PkgLogDir%\VendorLogs_Install_%DateTime%=McAfee_McAfeeAgent_5.6.3.157_SCH_W10x64_EN_B1={5D2802F8-A2EE-440E-9BB5-B7EF838BAD74},null - will install FramePkg with a silent cmd parameters.
    .NOTES
      This is an internal script function and should typically not be called directly, it will be triggered by main script if proper conf line will be found.
    .LINK
      https://github.kyndryl.net/wms-global/WMSAutomationTool/
  #>
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$DataType = "null",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #INSTALL,ADD,EXE,EXEFile=CMDParams=Cisco_CiscoMeeting_1.9.10.0_SCH_W10_EN_B1=guid,null
  #INSTALL,ADD,EXE,FramePkg.exe=/INSTALL><AGENT /SILENT /LOGDIR><%PkgLogDir%\VendorLogs_Install_%DateTime%=McAfee_McAfeeAgent_5.6.3.157_SCH_W10x64_EN_B1={5D2802F8-A2EE-440E-9BB5-B7EF838BAD74},null
  #UNINSTALL,REMOVE,EXE,{5DD37F97-3F65-4C24-B80D-D12913A4D214}=EXEFile=Cisco_CiscoMeeting_1.9.19.0_SCH_W10_EN_B1=CMDParams=AppVersion,null
  #UNINSTALL,REMOVE,EXE,{5DD37F97-3F65-4C24-B80D-D12913A4D214}=null=Cisco_CiscoMeeting_1.9.19.0_SCH_W10_EN_B1=null,null
  #UNINSTALL,REMOVE,EXE,{5DD37F97-3F65-4C24-B80D-D12913A4D214}=null=Cisco_CiscoMeeting_1.9.19.0_SCH_W10_EN_B1=null,null=replace
  #UNINSTALL,ALLUSERSREMOVE,EXE,{5DD37F97-3F65-4C24-B80D-D12913A4D214}=null=Cisco_CiscoMeeting_1.9.19.0_SCH_W10_EN_B1=null,null=replace

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  $SuccessCode = '3010,0'

  If ($actionName.ToUpper() -eq "ADD") {
    $EXEFile = Set-StringFromVarLayered -VarToCheck $Data[0]
    $CMDParams = Set-StringFromVarLayered -VarToCheck $Data[1]
    $PKGName = Set-StringFromVarLayered -VarToCheck $Data[2]
    $EXEGUID = Set-StringFromVarLayered -VarToCheck $Data[3]

    $CMDParams = Set-SpecialCharacters $CMDParams

    Write-Log -Message "$EXEGUID is not a GUID but a AppName. Will search for GUID." -Source ${CmdletName}
    Write-Log -Message "CMDParams = $CMDParams" -Source ${CmdletName}

    if (((-not($EXEFile.ToLower() -like "*.exe")) -or (-not($EXEFile.ToLower() -like "*.exe*"))) -and ($EXEFile.ToLower() -ne 'null')) { $EXEFile = "$EXEFile.exe" }
    
    if (($EXEFile.ToLower() -like "*cmd.exe") -or ($EXEFile.ToLower() -like "*powershell.exe") -or ($EXEFile.ToLower() -like "*wscript.exe") -or ($EXEFile.ToLower() -like "*cscript.exe")) { $silent = $False }
    else { $silent = $True }

    $EXEFile = Set-StringFromVarLayered -VarToCheck $EXEFile
    $EXEFile = Get-FullPath -path $EXEFile
    #if ((($EXEFile -like "\*") -and (-not ($EXEFile -like "\\*"))) -or (((-not ($EXEFile -like "*:\*")) -and (-not ($EXEFile -like "*%*"))))) { $EXEFile = "$Global:SourcePath\$EXEFile"}

    Write-Log -Message "EXEFile = $EXEFile." -Source ${CmdletName}

    If (!($DataType.ToLower() -eq "null")){
      $DataType = $DataType.Replace(";",",")
      $SuccessCode = "$SuccessCode,$DataType"
    }

    $CMDParams = $CMDParams.replace("%PreLogDir%",$Global:PreLogDir)
    $CMDParams = $CMDParams.replace("%ConfigFilesPath%",$Global:ConfigFilesPath)
    $CMDParams = $CMDParams.replace("'", "")
    $CMDParams = Set-SpecialCharacters -string $CMDParams
    #$CMDParams = $CMDParams.replace("><", "=")
    #$CMDParams = $CMDParams.replace("|", ",")
    $CMDParams = Set-StringFromVarLayered -VarToCheck $CMDParams
    Write-Log -Message "Modified CMDParams = $CMDParams." -Source ${CmdletName}

    $insStatus = Test-EXEGUID -GUID_Name $EXEGUID 
    
    Write-Log -Message "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------." -Source ${CmdletName}
    Write-Log -Message "Found: EXEGUID($EXEGUID) = GUID($($insStatus.GUID)) = isInstalled($($insStatus.isInstalled)) = version ($($insStatus.version)) = name ($($insStatus.name))." -Source ${CmdletName}
    Write-Log -Message "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------." -Source ${CmdletName}

    $CMDExePath = Get-CMDExePath

    if (($insStatus.isInstalled -eq $False) -or ($EXEGUID.ToUpper() -eq "{DUMMYGUID}")) {
      if ($EXEFile -like '"*') { 
        $EXEFile = "$EXEFile"
      } else {
        $EXEFile = "$EXEFile"
        Test-ParamFile -path $EXEFile
      }
      Write-Log -Message "Execute-Process -Path $EXEFile -Parameters $CMDParams" -Source ${CmdletName}
      if ($silent -eq $False) {
        $CMDParams = Set-SpecialCharacters -string $CMDParams
        $CMDParams = $CMDParams.replace("%ConfigFilesPath%", $Global:ConfigFilesPath).replace("'", "")
        #$CMDParams = $CMDParams.replace("%ConfigFilesPath%", $Global:ConfigFilesPath).replace("'", "").replace("><", "=").replace("|", ",")
        if ($CMDParams -ne "null") {
          $proc = Start-Process -NoNewWindow -Wait -PassThru "$CMDExePath"  "/c $CMDParams"
          $proc.WaitForExit()
        } else {
          $proc = Start-Process -NoNewWindow -Wait -PassThru "$CMDExePath"
          $proc.WaitForExit()
        }
        #Execute-Process -Path $EXEFile -Parameters $CMDParams.replace("%ConfigFilesPath%", $Global:ConfigFilesPath).replace("'", "").replace("><", "=").replace("|", ",") -WindowStyle  'Normal' -IgnoreExitCodes $SuccessCode
      } else {
        $CMDParams = Set-SpecialCharacters -string $CMDParams
        if ($CMDParams -ne "null") {
          Write-Log -Message "Execute-Process -Path $EXEFile -Parameters $CMDParams.replace(`"%ConfigFilesPath%`", $Global:ConfigFilesPath).replace(`"'`", `"`") -WindowStyle 'Hidden' -IgnoreExitCodes $SuccessCode" -Source ${CmdletName}
          Execute-Process -Path $EXEFile -Parameters $CMDParams.replace("%ConfigFilesPath%", $Global:ConfigFilesPath).replace("'", "") -WindowStyle 'Hidden' -IgnoreExitCodes $SuccessCode
        } else {
          Write-Log -Message "Execute-Process -Path $EXEFile -WindowStyle 'Hidden' -IgnoreExitCodes $SuccessCode" -Source ${CmdletName}
          Execute-Process -Path $EXEFile -WindowStyle 'Hidden' -IgnoreExitCodes $SuccessCode
        }
        #Execute-Process -Path $EXEFile -Parameters $CMDParams.replace("%ConfigFilesPath%", $Global:ConfigFilesPath).replace("'", "").replace("><", "=").replace("|", ",") -WindowStyle 'Hidden' -IgnoreExitCodes $SuccessCode
      }
    } else { Write-Log -Message "$($insStatus.GUID) is already installed, going to next action." -Source ${CmdletName} }
  } elseif ($actionName.ToUpper() -eq "ALLUSERSREMOVE") {
    $EXEGUID = Set-StringFromVarLayered -VarToCheck $Data[0]
    $EXEFile = Set-StringFromVarLayered -VarToCheck $Data[1]
    $PKGName = Set-StringFromVarLayered -VarToCheck $Data[2]
    $CMDParams = Set-StringFromVarLayered -VarToCheck $Data[3]

    $CMDParams = Set-SpecialCharacters $CMDParams

    if (($EXEGUID -like "{*") -and ($EXEGUID -like "*}")) {
      $triggers         = @()

      $executable       = "msiexec.exe"
      $arguments        = "/s $EXEGUID /qn"  
      $taskname         = "uninstall_$EXEGUID"
      $tNowPlus5min     = Get-Date
      $tNowPlus5min     = $tNowPlus5min.AddMinutes(5)
      $taskdescription  = "Run the user context application uninstall."
      $action           = New-ScheduledTaskAction $executable -Argument $arguments
      $Trigger1         = New-JobTrigger -AtLogon -RandomDelay (New-TimeSpan -Minutes 1)
      $triggers         += $Trigger1

      $settings         = New-ScheduledTaskSettingsSet -DontStopIfGoingOnBatteries -MultipleInstances Parallel -Priority 0
      $STPrin           = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Users" -RunLevel Highest

      $taskList = Get-ScheduledTask
      foreach ($task in $taskList) {
        $name = $task.TaskName
        if ($name -like "*$taskName") {
          Write-Log -Message "Scheduled Task $taskName found." -Source ${CmdletName}
          Write-Log -Message "Unregister-ScheduledTask -TaskName $name -Confirm:$false" -Source ${CmdletName}
          Unregister-ScheduledTask -TaskName $name -Confirm:$false
        } 
      }

      Write-Log -Message "Register-ScheduledTask -Action $action -Trigger $triggers -TaskName $taskname -Description $taskdescription -Settings $settings" -Source ${CmdletName}
      Register-ScheduledTask -Action $action -Trigger $triggers -TaskName $taskname -Description $taskdescription -Settings $settings -Principal $STPrin #-User "Administrator" -RunLevel Highest

      Write-Log -Message "Start-ScheduledTask -TaskName $taskname"
      Start-ScheduledTask -TaskName "$taskname"
      Write-Log -Message "Unregister-ScheduledTask -TaskName $name -Confirm:$false" -Source ${CmdletName}
      Unregister-ScheduledTask -TaskName $name -Confirm:$false

    } else {
      if (((-not($EXEFile.ToLower() -like "*.exe")) -or (-not($EXEFile.ToLower() -like "*.exe*"))) -and ($EXEFile.ToLower() -ne 'null')) { $EXEFile = "$EXEFile.exe" }

      Write-Log -Message "Uninstalling usercontext installed app." -Source ${CmdletName}
      $arguments = "$CMDParams" 
      $arguments = $arguments.replace("%PreLogDir%",$Global:PreLogDir)
      $arguments = $arguments.replace("%ConfigFilesPath%",$Global:ConfigFilesPath)
      $arguments = $arguments.replace("'", "")
      $arguments = Set-SpecialCharacters -string $arguments
      #$arguments = $arguments.replace("><", "=")
      #$arguments = $arguments.replace("|", ",")
      $arguments = Set-StringFromVarLayered -VarToCheck $arguments
      Write-Log -Message "Modified CMDParams = $arguments." -Source ${CmdletName}

      ForEach ($User In (Get-WmiObject Win32_UserProfile -F "Special != True" | Select-Object -Expand LocalPath)) {
        $dirPath = "$($User)"
        $filePath = "$($dirPath)$EXEFile"
        $filePath = $filePath.Replace(" \","\")
        $filePath = $filePath.Replace("\\","\")

        Write-Log -Message "\User\File - $filePath" -Source ${CmdletName}
        if (Test-Path -Path "$filePath") { 
          Write-Log -Message "Will use $filePath to uninstall application." -Source ${CmdletName}
          $command = '/c, "'+$filePath+'" '+$arguments
          Write-Log -Message "Start-Process -FilePath $env:comspec -ArgumentList $command -Wait -NoNewWindow" -Source ${CmdletName}
          Write-Log -Message "Will use filePath = $command." -Source ${CmdletName}
          Start-Process -FilePath "$env:comspec" -ArgumentList $command -Wait -NoNewWindow
        } else { Write-Log -Message "$filePath - do not exist, going with next one." -Source ${CmdletName} }
      }
    }
  } elseif ($actionName.ToUpper() -eq "REMOVE") {
    $EXEGUID = Set-StringFromVarLayered -VarToCheck $Data[0]
    $EXEFile = Set-StringFromVarLayered -VarToCheck $Data[1]
    $PKGName = Set-StringFromVarLayered -VarToCheck $Data[2]
    $CMDParams = Set-StringFromVarLayered -VarToCheck $Data[3]
    
    if ($Data.Length -eq 5) { $AppVersion = Set-StringFromVarLayered -VarToCheck $Data[4] }
    else { $AppVersion = 'null' }

    $CMDParams = Set-SpecialCharacters $CMDParams

    if ((($EXEFile.ToLower() -eq 'null') -or ($EXEFile.ToLower() -eq 'force')) -and ($EXEGUID.ToLower() -ne 'null')) {
      Write-Log -Message "Will proceed with uninstallation using registry uninstall string." -Source ${CmdletName}
      $replace =  $False

      If (-not($DataType.ToLower() -eq "null")) {
        if(($DataType.ToLower() -like "*=*")) {
          $Data = $DataType.Split("=")
          $DataTypeA = $Data[0]
          $DataTypeB = $Data[1]
          If (-not($DataTypeA.ToLower() -eq "null")) {
            $DataTypeA = $Data.Replace(";",",")
            $SuccessCode = $DataType
          }
          If ($DataTypeB.ToLower() -eq "replace") { $replace =  $True }
        } else { 
          $DataType = $DataType.Replace(";",",")
          $SuccessCode = $DataType
        }
      }
      
      Write-Log -Message "Test-EXEGUID -GUID_Name $EXEGUID ." -Source ${CmdletName}
      [pscustomobject]$insStatus = Test-EXEGUID -GUID_Name $EXEGUID 

      Write-Log -Message "Found name(s): $($insStatus.name)" -Source ${CmdletName}
      Write-Log -Message "Found GUID(s): $($insStatus.GUID)" -Source ${CmdletName}
      Write-Log -Message "Found version(s): $($insStatus.version)" -Source ${CmdletName}

      Write-Log -Message "Will replace uninstall string flags = $replace." -Source ${CmdletName}

      if ($insStatus.isInstalled -eq $True) { 
        Foreach ($status in $insStatus) {
          Write-Log -Message "Will test if $($status.GUID) -like `"WAMP_*`"" -Source ${CmdletName}

          If ($AppVersion -eq 'null') { $proceed = $True }
          Else {
            if ($AppVersion -eq $insStatus.version) { $proceed = $True }
            else { $proceed = $False }
          }

          if ((-not ("$($status.GUID)" -like "WAMP_*")) -and ($proceed -eq $True)) {
            Write-Log -Message "App $EXEGUID - $($status.GUID) - $($status.isInstalled), proceeding with uninstallation." -Source ${CmdletName}
            Write-Log -Message "App $($status.GUID) - $($status.name) - $($status.version) is installed, proceeding with uninstallation." -Source ${CmdletName}
            $Data = (Get-InstalledApplication -ProductCode $status.GUID)

            foreach ($item in $Data) { 
              If (-not ([string]::IsNullOrEmpty($item))) {
                Write-Log -Message "Test if: $item -like `"*WAMP_*`")" -Source ${CmdletName}
                if (-not ($item -like "*WAMP_*")) {
                  $AppARPData = $item 
                } else {
                  Write-Log -Message "Will skip $item because it contains: `"*WAMP_*`"" -Source ${CmdletName}
                }
              } 
            }
    
            Write-Log -Message "----------------------------------------------------------------------------------------------" -Source ${CmdletName}
            if (($AppARPData -like "*@{*") -or ($AppARPData -like "@{*")) {
              Write-Log -Message "Will cleanup @{} from AppARPData string." -Source ${CmdletName}
              Write-Log -Message "AppARPData: $AppARPData." -Source ${CmdletName}
              $AppARPData = $AppARPData.Replace("@{","")
              $AppARPData = $AppARPData.Replace("}","")
            }
            $ARPs = $AppARPData.Split(";")
    
            foreach ($arpD in $ARPs) {
              $a = $arpD.Split("=")
              $ARPName = $a[0]
              $ARPValue = $a[1]
    
              Write-Log -Message "$ARPName -> $ARPValue" -Source ${CmdletName}
    
              if (($ARPName -eq "SilentUninstallString") -or ($ARPName -eq " SilentUninstallString") -or ($ARPName -like "SilentUninstallString*")) { 
                $silentUninstallString = $ARPValue 
                Write-Log -Message "Adding: $ARPName - $silentUninstallString" -Source ${CmdletName}
              }
              if (($ARPName -eq "QuietUninstallString") -or ($ARPName -eq " QuietUninstallString") -or ($ARPName -like "QuietUninstallString*")) { 
                $quietUninstallString = $ARPValue 
                Write-Log -Message "Adding: $ARPName - $quietUninstallString" -Source ${CmdletName}
              }
              if (($ARPName -eq "UninstallString") -or($ARPName -eq " UninstallString") -or ($ARPName -like "UninstallString*")) { 
                $uninstallString = $ARPValue 
                Write-Log -Message "Adding: $ARPName - $UninstallString" -Source ${CmdletName}
              } 
            }
            Write-Log -Message "----------------------------------------------------------------------------------------------" -Source ${CmdletName}
            
            if ($CMDParams.ToLower() -eq 'null') { $arguments = "" }
            else { 
              $arguments = "$CMDParams" 
              $arguments = $arguments.replace("%PreLogDir%",$Global:PreLogDir)
              $arguments = $arguments.replace("%ConfigFilesPath%",$Global:ConfigFilesPath)
              $arguments = $arguments.replace("'", "")
              $arguments = Set-SpecialCharacters -string $arguments
              #$arguments = $arguments.replace("><", "=")
              #$arguments = $arguments.replace("|", ",")
              $arguments = Set-StringFromVarLayered -VarToCheck $arguments
              Write-Log -Message "Modified CMDParams = $arguments." -Source ${CmdletName}
            }
    
            Write-Log -Message "----------------------------------------------------------------------------------------------" -Source ${CmdletName}
            Write-Log -Message "quietUninstallString = $quietUninstallString." -Source ${CmdletName}
            Write-Log -Message "silentUninstallString = $silentUninstallString." -Source ${CmdletName}
            Write-Log -Message "uninstallString = $uninstallString." -Source ${CmdletName}
            Write-Log -Message "----------------------------------------------------------------------------------------------" -Source ${CmdletName}
    
            If (-not ([string]::IsNullOrEmpty($quietUninstallString))) { $quietUninstallString = Fix-String -stringIN $quietUninstallString -isReplace $replace }
            If (-not ([string]::IsNullOrEmpty($silentUninstallString))) { $silentUninstallString = Fix-String -stringIN $silentUninstallString -isReplace $replace }
            If (-not ([string]::IsNullOrEmpty($uninstallString))) { $uninstallString = Fix-String -stringIN $uninstallString -isReplace $replace }

            If (-not ([string]::IsNullOrEmpty($quietUninstallString))) {
              Write-Log -Message "Found quietUninstallString = $quietUninstallString." -Source ${CmdletName}
              if ($replace -eq $True) {
                $quietUninstallString = $quietUninstallString.Replace('"','')
                $tmp = $quietUninstallString.Split(".exe")
                $remove = $tmp[-1]
                if (($remove -ne '') -and (-not([string]::IsNullOrEmpty($remove)))) { 
                  Write-Log -Message "$quietUninstallString.Replace($remove,'')" -Source ${CmdletName}
                  $quietUninstallString = $quietUninstallString.Replace("$remove","") 
                }
              }
    
              $first = $quietUninstallString.SubString(0,1)
              if (-not($quietUninstallString -like '*.exe"')) { $quietUninstallString = $quietUninstallString.Replace(".exe",'.exe"') }
              if (-not($first -eq '"')) { $quietUninstallString = '"'+$quietUninstallString }
    
              Write-Log -Message "Will use quietUninstallString = $quietUninstallString." -Source ${CmdletName}
              $quietUninstallString = $quietUninstallString.Replace('""','"')
              $quietUninstallString = $quietUninstallString.Replace('"','')
              $quietUninstallString = $quietUninstallString.Replace('"','')

              $command = '/c, "'+$quietUninstallString+'" '+$arguments
              Write-Log -Message "Start-Process -FilePath $env:comspec -ArgumentList $command -Wait -NoNewWindow" -Source ${CmdletName}
              Start-Process -FilePath "$env:comspec" -ArgumentList $command -Wait -NoNewWindow
            } elseif (-not ([string]::IsNullOrEmpty($silentUninstallString))) {
              Write-Log -Message "Found silentUninstallString = $silentUninstallString." -Source ${CmdletName}
              if ($replace -eq $True) {
                $silentUninstallString = $silentUninstallString.Replace('"','')
                $tmp = $silentUninstallString.Split(".exe")
                $remove = $tmp[-1]
                if (($remove -ne '') -and (-not([string]::IsNullOrEmpty($remove)))) { 
                  Write-Log -Message "$silentUninstallString.Replace($remove,'')" -Source ${CmdletName}
                  $silentUninstallString = $silentUninstallString.Replace("$remove","") 
                }
              }
    
              $first = $silentUninstallString.SubString(0,1)
              if (-not($silentUninstallString -like '*.exe"')) { $silentUninstallString = $silentUninstallString.Replace(".exe",'.exe"') }
              if (-not($first -eq '"')) { $silentUninstallString = '"'+$silentUninstallString }
    
              Write-Log -Message "Will use silentUninstallString = $silentUninstallString." -Source ${CmdletName}
              $silentUninstallString = $silentUninstallString.Replace('""','"')
              $silentUninstallString = $silentUninstallString.Replace('"','')
              $silentUninstallString = $silentUninstallString.Replace('"','')

              $command = '/c, "'+$silentUninstallString+'" '+$arguments
              Write-Log -Message "Start-Process -FilePath $env:comspec -ArgumentList $command -Wait -NoNewWindow" -Source ${CmdletName}
              Write-Log -Message "Will use silentUninstallString = $command." -Source ${CmdletName}
              Start-Process -FilePath "$env:comspec" -ArgumentList $command -Wait -NoNewWindow
            } elseif (-not ([string]::IsNullOrEmpty($uninstallString))) {
              Write-Log -Message "Found uninstallString = $uninstallString." -Source ${CmdletName}
              if ($replace -eq $True) {
                $uninstallString = $uninstallString.Replace('"','')
                $tmp = $uninstallString.Split(".exe")
                $remove = $tmp[-1]
                if (($remove -ne '') -and (-not([string]::IsNullOrEmpty($remove)))) { 
                  Write-Log -Message "$uninstallString.Replace($remove,'')" -Source ${CmdletName}
                  $uninstallString = $uninstallString.Replace("$remove","") 
                }
              }

              if (($uninstallString.ToLower() -like "msiexec.exe*") -or ($uninstallString.ToLower() -like "*msiexec.exe*")) { Write-Log -Message "Uninstall string contains uses msiexec, is not in exe uninstall scope." -Source ${CmdletName} }
              else { 
                $first = $uninstallString.SubString(0,1)
                if (-not($uninstallString -like '*.exe"')) { $uninstallString = $uninstallString.Replace(".exe",'.exe"') }
                if (-not($first -eq '"')) { $uninstallString = '"'+$uninstallString }
      
                Write-Log -Message "Will use uninstallString = $uninstallString." -Source ${CmdletName}
                $uninstallString = $uninstallString.Replace('""','"')
                $uninstallString = $uninstallString.Replace('"','')
                $uninstallString = $uninstallString.Replace('"','')
                
                Write-Log -Message "Will check for: $uninstallString." -Source ${CmdletName}
                Write-Log -Message "Test-Path -Path `"$uninstallString`" -PathType Leaf." -Source ${CmdletName}
                if(Test-Path -Path "$uninstallString" -PathType Leaf) {
                  Write-Log -Message "File exist, will try to uninstall." -Source ${CmdletName}
                  Write-Log -Message "Start-Process -FilePath `"$uninstallString`" -ArgumentList $arguments -Wait -NoNewWindow" -Source ${CmdletName}
                  Start-Process -FilePath "$uninstallString" -ArgumentList $arguments -Wait -NoNewWindow
                }

                Write-Log -Message "Will recheck for: $uninstallString." -Source ${CmdletName}
                Write-Log -Message "Test-Path -Path `"$uninstallString`" -PathType Leaf." -Source ${CmdletName}
                if(Test-Path -Path "$uninstallString" -PathType Leaf) {
                  Write-Log -Message "File strill exist, will try to uninstall." -Source ${CmdletName}

                  if (-not ([string]::IsNullOrEmpty($arguments)) -and ($arguments -ne "") -and ($arguments -ne " ")) { $command = "/c, `"`"`"$uninstallString`"`" "+$arguments+'"' }
                  else { $command = "/c, `"`"`"$uninstallString`"`" "+$arguments+'"' }
                  
                  Write-Log -Message "Will use uninstallString = $command." -Source ${CmdletName}
                  Write-Log -Message "Start-Process -FilePath `"$env:comspec`" -ArgumentList $command -Wait -NoNewWindow" -Source ${CmdletName}
                  Start-Process -FilePath "$env:comspec" -ArgumentList $command -Wait -NoNewWindow
                }
      
                Write-Log -Message "Will recheck for: $uninstallString." -Source ${CmdletName}
                Write-Log -Message "Test-Path -Path `"$uninstallString`" -PathType Leaf." -Source ${CmdletName}
                if(Test-Path -Path "$uninstallString" -PathType Leaf) {
                  if (-not ([string]::IsNullOrEmpty($arguments)) -and ($arguments -ne "") -and ($arguments -ne " ")) { $command = "/c, `"`"`"$uninstallString`"`" "+$arguments }
                  else { $command = "/c, `"`"`"$uninstallString`"`" "+$arguments }
        
                  Write-Log -Message "Will use uninstallString = $command." -Source ${CmdletName}
                  Write-Log -Message "Start-Process -FilePath `"$env:comspec`" -ArgumentList $command -Wait -NoNewWindow" -Source ${CmdletName}
                  Start-Process -FilePath "$env:comspec" -ArgumentList $command -Wait -NoNewWindow
                }
              }
            } else { Write-Log -Message "Missing any uninstall string in registry, assuming that app was uninstalled. Going to next step." -Source ${CmdletName} }
          } else {
            Write-Log -Message "App $EXEGUID - $($status.GUID) - $($status.isInstalled), will not proceed with uninstallation:" -Source ${CmdletName}
            if (-not ("$($status.GUID)" -like "WAMP_*")) { Write-Log -Message "Is a WAMP GUID. Searching for vendor one." -Source ${CmdletName} }
            if ($proceed -eq $True) { Write-Log -Message "Version was defined and vendor verion is different." -Source ${CmdletName} }
          }
        }
      } else { Write-Log -Message "App $EXEGUID - $isInstalled is not installed, going to next step." -Source ${CmdletName} }
    } else { 
      Write-Log -Message "CMDParams = $CMDParams" -Source ${CmdletName}

      $EXEFile = Set-StringFromVarLayered -VarToCheck $EXEFile
      $EXEFile = Get-FullPath -path $EXEFile
      #if ((($EXEFile -like "\*") -and (-not ($EXEFile -like "\\*"))) -or (((-not ($EXEFile -like "*:\*")) -and (-not ($EXEFile -like "*%*"))))) { $EXEFile = "$Global:SourcePath\$EXEFile"}
      if (((-not($EXEFile.ToLower() -like "*.exe")) -or (-not($EXEFile.ToLower() -like "*.exe*"))) -and ($EXEFile.ToLower() -ne 'null')) { $EXEFile = "$EXEFile.exe" }

      Write-Log -Message "EXEFile = $EXEFile." -Source ${CmdletName}

      If ((-not($DataType.ToLower() -like "null*")) -and (-not($DataType.ToLower() -like "*null*")) -and (-not($DataType.ToLower() -like "*null"))-and (-not($DataType.ToLower() -eq "null"))) {
        $DataType = $DataType.Replace(";",",")
        $SuccessCode = $DataType
      }

      $CMDParams = $CMDParams.replace("%PreLogDir%",$Global:PreLogDir)
      $CMDParams = $CMDParams.replace("%ConfigFilesPath%",$Global:ConfigFilesPath)
      $CMDParams = $CMDParams.replace("'", "")
      $CMDParams = Set-SpecialCharacters -string $CMDParams
      #$CMDParams = $CMDParams.replace("><", "=")
      #$CMDParams = $CMDParams.replace("|", ",")
      $CMDParams = Set-StringFromVarLayered -VarToCheck $CMDParams
      Write-Log -Message "Modified CMDParams = $CMDParams." -Source ${CmdletName}

      $insStatus = Test-EXEGUID -GUID_Name $EXEGUID 
      $isInstalled = $insStatus.isInstalled

      If ($AppVersion -eq 'null') { $proceed = $True }
      Else {
        if ($AppVersion -eq $insStatus.version) { $proceed = $True }
        else { $proceed = $False }
      }

      if (($isInstalled -eq $True) -and ($proceed -eq $True)) {
        $EXEFile = "$EXEFile"
        Test-ParamFile -path $EXEFile
        Write-Log -Message "Execute-Process -Path $EXEFile -Parameters $CMDParams" -Source ${CmdletName}
        Write-Log -Message "Will IgnoreExitCodes $SuccessCode" -Source ${CmdletName}
        Execute-Process -Path "$EXEFile" -Parameters $CMDParams.replace("%ConfigFilesPath%", $Global:ConfigFilesPath).replace("'", "").replace("><", "=").replace("|", ",") -WindowStyle 'Hidden' -IgnoreExitCodes $SuccessCode
      } else {
        Write-Log -Message "Will not uninstall $EXEGUID :" -Source ${CmdletName}
        If ($isInstalled -eq $False) { Write-Log -Message "Because is not installed." -Source ${CmdletName} }
        If ($proceed -eq $False) { Write-Log -Message "Version was defined and vendor verion is different." -Source ${CmdletName} }
      }
    }
  }
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Fix-String {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    $stringIN,
    $isReplace
  )

  $toReturn = $stringIN

  if (($stringIN -like "*{*") -and (-not($stringIN -like "*}*"))) { 
    Write-Log -Message "Problem with {} found. Will try to fix." -Source ${CmdletName}
    Write-Log -Message "String to fix: $stringIN" -Source ${CmdletName}

    $data = $stringIN
    $datePattern = [Regex]::new('([{])(.)*([\\])')
    $stringMatches = $datePattern.Matches($data)
    $RC = $stringMatches.Value
    
    Write-Log -Message "Will replace: $tmp with $tmpA" -Source ${CmdletName}
    Write-Log -Message "Fixed string: $stringIN" -Source ${CmdletName}

    if (-not([string]::IsNullOrEmpty($RC))) { 
      $tmpA = $RC.Replace("\","}\")
      $stringIN = $stringIN.Replace($RC,$tmpA)
      
      Write-Log -Message "Will replace: $RC with $tmpA" -Source ${CmdletName}
      Write-Log -Message "Fixed string: $stringIN" -Source ${CmdletName}

      $toReturn = $stringIN
    } else { 
      Write-Log -Message "Nothing to fix, returnig the same string: $stringIN." -Source ${CmdletName}
      $toReturn = $stringIN 
    }
  }

  if ($isReplace) {
    if ((-not ($toReturn -like "*' *")) -and (-not ($toReturn -like '*" *'))) { Write-Log -Message "Nothing to replace." -Source ${CmdletName} }
    else {
      $toReturn = $toReturn.Replace(" ",":sp:")
      $toReturn = $($toReturn -replace '\s+', ':sp:')

      if ($toReturn -like "*':sp:*") { $toReturn = $toReturn.Replace("':sp:", '^') }
      if ($toReturn -like '*":sp:*') { $toReturn = $toReturn.Replace('":sp:', '^') }

      $tmp = $toReturn.Split('^')
      $toReturn = "$($tmp[0])"
      $toReturn = $toReturn.Replace("'","").Replace('"','')
      $toReturn = $toReturn.Trim()
      $toReturn = '"'+"$($tmp[0])"+'"'
      $toReturn = $toReturn.Replace(":sp:", " ")

      foreach ($subStr in $tmp) { Write-Log -Message "subStr = $subStr." -Source ${CmdletName} }
    }
  }

  if ($toReturn -eq $stringIN) { Write-Log -Message "Nothing to fix, returnig the same string: $stringIN." -Source ${CmdletName} }
  else { Write-Log -Message "String was modified, will return: $toReturn." -Source ${CmdletName} }

  Return $toReturn
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-RemoveFiles {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    $FileName,
    $Directory
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  $forAllUsers =  Get-isAllUsers -stringToTest $Directory
  $forAllUsersUserName = Get-isUserName -stringToTest $Directory
  $Directory = Set-StringFromVarLayered -VarToCheck $Directory
  $FileName = Set-StringFromVarLayered -VarToCheck $FileName

  $File = '"' + $Directory + "\" + $FileName + '"'

  Write-Log -Message "Directory - $Directory" -Source ${CmdletName}
  Write-Log -Message "File - $File" -Source ${CmdletName}

  if ($forAllUsers -eq $True) {
    if ($Global:userActions.ToLower() -eq 'false') { 
      Write-Log -Message "Will skipp ${CmdletName} execution. userActions = $($Global:userActions)." -Source ${CmdletName} -Severity 3
      Write-Log -Message "For your account use an other method for actions in user context/manipulation of user profiles." -Source ${CmdletName} -Severity 3 
    } else {
      ForEach ($User In (Get-WmiObject Win32_UserProfile -F "Special != True" | Select-Object -Expand LocalPath)) {
        $User = $User.trim()

        $dirPath = "$($User)$Directory"
        $filePath = "$($dirPath)\$FileName"
        $filePath = $filePath.Replace(" \","\")
        $filePath = $filePath.Replace("\\","\")

        Write-Log -Message "\User\NewDirectory - $dirPath" -Source ${CmdletName}
        Write-Log -Message "Remove-Item $filePath" -Source ${CmdletName}
        if (Test-Path -Path "$filePath") { Remove-Item "$filePath" }
      }
    }
  } else {
    Write-Log -Message "& cmd /C del $File" -Source ${CmdletName}
    & cmd /C "del $File"
  }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-NewEmptyFile {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    $FileName,
    $Directory
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "Starting file creation files with params: $FileName, $Directory ." -Source ${CmdletName}

  $isForce = "true"
  $forAllUsers =  Get-isAllUsers -stringToTest $Directory
  $forAllUsersUserName = Get-isUserName -stringToTest $Directory
  if ($Directory.ToLower() -like "*%ibmsrc%*") { Set-IBMSRC -PKGName $Global:PKGName -Action "ADD" }
  if ($Directory.ToLower() -like "*%kyndrylsrc%*") { Set-KyndrylSRC -PKGName $Global:PKGName -Action "ADD" }

  $Directory = Set-StringFromVarLayered -VarToCheck $Directory
  $FileName = Set-StringFromVarLayered -VarToCheck $FileName

  $Directory = $Directory.Replace('"','')

  Write-Log -Message "Directory = $Directory" -Source ${CmdletName}
  Write-Log -Message "FileName = $FileName" -Source ${CmdletName}

  Write-Log -Message "Starting file creation files with params: $FileName, $Directory ." -Source ${CmdletName}
  
  #$Destination = '"' + $Directory + '\' + $FileName + '"'
  #if ($Directory -like "*\\") { $NewDirectory = '"' + $Directory + '"' }
  #else { $NewDirectory = '"' + $Directory + '\"' }

  $NewDirectoryF = '"' + $Directory + '\' + $FileName + '"'
  Write-Log -Message "Creating $FileName in $Directory." -Source ${CmdletName}

  if ($forAllUsers -eq $True) {
    if ($Global:userActions.ToLower() -eq 'false') { 
      Write-Log -Message "Will skipp ${CmdletName} execution. userActions = $($Global:userActions)." -Source ${CmdletName} -Severity 3
      Write-Log -Message "For your account use an other method for actions in user context/manipulation of user profiles." -Source ${CmdletName} -Severity 3 
    } else {
			$NewDir = $NewDir.Replace("%allusers%\","\")
      Write-Log -Message "Will proceed with path: $Directory for all users profiles." -Source ${CmdletName}
      ForEach ($User In (Get-WmiObject Win32_UserProfile -F "Special != True" | Select-Object -Expand LocalPath)) {
        $User = $User.trim()
        $Directory = $Directory.trim()
        Write-Log -Message "\User\NewDirectory - $($User)$Directory" -Source ${CmdletName}
        if(!(Test-Path -Path "$($User)$Directory")){  New-Item -ItemType directory -Path "$($User)$Directory" }
        if ($isForce.ToLower() -eq "true") { if (Test-Path -Path "$($User)$Directory$FileName") { Remove-Item "$($User)$Directory$FileName" } }

        $DestToUser = "$($User)$Directory"
        $DestToUser = '"'+"$DestToUser\$FileName"+'"'
        $DestToUser = $DestToUser.Replace(" \","\")
        $DestToUser = $DestToUser.Replace("\\","\")

        if ((Test-Path -Path $DestToUser -PathType Leaf) -eq $True) { Write-Log -Message "$DestToUser already exist, skipping creation." -Source ${CmdletName} }
        else { New-Item -Path $DestToUser -Name $FileName -ItemType File }
      }
    }
  } else {
    $destItem = '"'+"$DestToUser\$FileName"+'"'

    if ($isForce.ToLower() -eq "true") { 
      if (Test-Path -Path $Directory) { 
        Write-Log -Message "Function is set to force, will:" -Source ${CmdletName}
        Write-Log -Message "Remove-Item $destItem -Force" -Source ${CmdletName}
        Remove-Item $destItem -Force
      } 
    }
    if (Test-Path -Path $Directory -PathType "Container") { Write-Log -Message "$Directory exists. Creating $FileName." -Source ${CmdletName} }
    else {
      Write-Log -Message "$Directory doesn't exist, creating." -Source ${CmdletName}
      New-Item -ItemType directory -Path "$Directory"
    }

    $Directory = '"'+$Directory+'"'
    if (-not(Test-Path -Path $NewDirectoryF -PathType "Leaf")) {
      Write-Log -Message "Create $NewDirectoryF" -Source ${CmdletName}
      New-Item -Path $Directory -Name $FileName -ItemType File
    }
  }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-CopyFiles {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    $FileName,
    $OldDir,
    $NewDir,
		$isForce = "true"
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "Starting COPY files with params: $FileName, $OldDir, $NewDir, $isForce ." -Source ${CmdletName}

  $UName = "%username%"
  $forAllUsers =  Get-isAllUsers -stringToTest $NewDir
  $forAllUsersUserName = Get-isUserName -stringToTest $NewDir
  if ($NewDir.ToLower() -like "*%ibmsrc%*") { Set-IBMSRC -PKGName $Global:PKGName -Action "ADD" }
  if ($NewDir.ToLower() -like "*%kyndrylsrc%*") { Set-KyndrylSRC -PKGName $Global:PKGName -Action "ADD" }

  if (($forAllUsers -eq $False) -and ($forAllUsersUserName -eq $False)) { $NewDir = Set-StringFromVarLayered -VarToCheck $NewDir }
  $OldDir = Set-StringFromVarLayered -VarToCheck $OldDir
  $FileName = Set-StringFromVarLayered -VarToCheck $FileName

  $NewDir = $NewDir.Replace('"','')
  $OldDir = $OldDir.Replace('"','')

  Write-Log -Message "NewDir = $NewDir" -Source ${CmdletName}
  Write-Log -Message "OldDir = $OldDir" -Source ${CmdletName}
  Write-Log -Message "FileName = $FileName" -Source ${CmdletName}

  if ($FileName -eq "*") {
    if ($NewDir -like "*\\") { $NewDirectory = '"' + $NewDir + '"' }
    else { $NewDirectory = '"' + $NewDir + '\"' }

    $NewDirectoryF = '"' + $NewDir + '\"'

    if (Test-Path $OldDir -PathType Container) {
      $NewDir = Set-StringFromVarLayered -VarToCheck $NewDir
      $lastChar = $OldDir.Length-1
      if ($lastChar -eq "\") { $OldDirA = $OldDir.Substring(0,$lastChar) }
      else { $OldDirA = $OldDir }

      Write-Log -Message "Get-ChildItem -Path $OldDirA -Name" -Source ${CmdletName}
      $AllFiles = Get-ChildItem -Path $OldDirA -Name
      Write-Log -Message "Starting COPY files from: $OldDir to $NewDir ." -Source ${CmdletName}
      Write-Log -Message "List of files:." -Source ${CmdletName}
    } else { Write-Log -Message "OldDir - $OldDir doesnt exist." -Source ${CmdletName} }

    foreach ($f in $AllFiles) { Write-Log -Message "- $f." -Source ${CmdletName} }

    if (($forAllUsers -eq $True) -or ($forAllUsersUserName -eq $True)) {
      if (($Global:UserContextVar -eq "user") -and ($forAllUsersUserName -eq $True)) {
				$NewDir = $NewDir.Replace("%allusers%\","\")
        Write-Log -Message "Will proceed with path: $NewDir for current user." -Source ${CmdletName}
        $NewDir = $NewDir.trim()
        $DestToUser = Get-userNameString -string $NewDir
        Write-Log -Message "DestToUser - $DestToUser" -Source ${CmdletName}
				foreach ($f in $AllFiles) { Execute-CopyItem -FileName $f.Name -OldDir $OldDir -NewDir $DestToUser -isForce $isForce }
        #Copy-Item -Path "$OldDir\*" -Destination "$DestToUser" -Recurse -Force
      } elseif ($Global:userActions.ToLower() -eq 'false') {
        Write-Log -Message "Will skipp ${CmdletName} execution. userActions = $($Global:userActions)." -Source ${CmdletName} -Severity 3
        Write-Log -Message "For your account use an other method for actions in user context/manipulation of user profiles." -Source ${CmdletName} -Severity 3 
      } else {
        If ($forAllUsers -eq $True) {
					$NewDir = $NewDir.Replace("%allusers%\","\")
          Write-Log -Message "Will proceed with path: $NewDir for all users profiles." -Source ${CmdletName}
          ForEach ($User In (Get-WmiObject Win32_UserProfile -F "Special != True" | Select-Object -Expand LocalPath)) {
            $User = $User.trim()
            $NewDir = $NewDir.trim()
            Write-Log -Message "\User\NewDirectory - $($User)$NewDir" -Source ${CmdletName}
            if(!(Test-Path -Path "$($User)$NewDir")){  New-Item -ItemType directory -Path "$($User)$NewDir" }

            $DestToUser = "$($User)$NewDir"
            $DestToUser = $DestToUser.Replace(" \","\")
            $DestToUser = $DestToUser.Replace("\\","\")
            $DestToUser = Set-StringFromVarLayered -VarToCheck $DestToUser
						foreach ($f in $AllFiles) { Execute-CopyItem -FileName $f.Name -OldDir $OldDir -NewDir $DestToUser -isForce $isForce }
            #Copy-Item -Path "$OldDir\*" -Destination "$DestToUser" -Recurse -Force
          }
        } else {
          Write-Log -Message "Proceed with username's." -Source ${CmdletName}
          ForEach ($User In (Get-WmiObject Win32_UserProfile -F "Special != True" | Select-Object -Expand LocalPath)) {
            $User = $User.trim()
            $userName = Split-Path $User -Leaf
            $NewDir = $NewDir.trim()

            $DestToUser = Set-OwerrideVar -Var $NewDir -IN $UName -OUT $userName
            $DestToUser = $DestToUser.Replace(" \","\").Replace("\\","\")
            $DestToUser = Set-StringFromVarLayered -VarToCheck $DestToUser
						foreach ($f in $AllFiles) { Execute-CopyItem -FileName $f.Name -OldDir $OldDir -NewDir $DestToUser -isForce $isForce }
            #Write-Log -Message "DestToUser - $DestToUser" -Source ${CmdletName}
            #Copy-Item -Path "$OldDir\*" -Destination "$DestToUser" -Recurse -Force
          }
        }
      }
    } else {
      if (Test-Path -Path $NewDir -PathType Container) { Write-Log -Message "$NewDir exists. Copying content of $OldDir." -Source ${CmdletName} }
      else {
        Write-Log -Message "$NewDir doesn't exist, creating." -Source ${CmdletName}
        new-item -itemType "directory" -path $NewDir -Force
      }

      if ($NewDir -like "*\") { $NewDir = $NewDir.Substring(0,$NewDir.Length-1) }
      if ($OldDir -like "*\") { $OldDir = $OldDir.Substring(0,$OldDir.Length-1) }

      #Write-Log -Message "robocopy /Mir $OldDir $NewDir." -Source ${CmdletName}
      #robocopy /Mir /SEC /SECFIX "$OldDir" "$NewDir"
      #robocopy /Mir "$OldDir" "$NewDir"

      $AllFiles = Get-ChildItem -Path "$NewDir\" -Name
      Write-Log -Message "Files in: $NewDir\." -Source ${CmdletName}
      foreach ($f in $AllFiles) { 
				Write-Log -Message "- $f." -Source ${CmdletName}
				Execute-CopyItem -FileName $f.Name -OldDir $OldDir -NewDir $NewDir -isForce $isForce
			}
    }
  } else {
    Write-Log -Message "Starting COPY files with params: $FileName, $OldDir, $NewDir ." -Source ${CmdletName}
    $Directory = '"' + $OldDir + '\' + $FileName + '"'

    if ($NewDir -like "*\\") { $NewDirectory = '"' + $NewDir + '"' }
    else { $NewDirectory = '"' + $NewDir + '\"' }

    $NewDirectoryF = '"' + $NewDir + '\' + $FileName + '"'
    Write-Log -Message "Copying $FileName from $OldDir to $NewDir." -Source ${CmdletName}

    if (($forAllUsers -eq $True) -or ($forAllUsersUserName -eq $True)) {
			$NewDir = $NewDir.Replace("%allusers%\","\")
      if (($Global:UserContextVar -eq "user") -and ($forAllUsersUserName -eq $True)) {
        Write-Log -Message "Will proceed with path: $NewDir for current user." -Source ${CmdletName}
        $NewDir = $NewDir.trim()
        $DestToUser = Get-userNameString -string $NewDir

				Execute-CopyItem -FileName $FileName -OldDir $OldDir -NewDir $DestToUser -isForce $isForce

        <#if (-not (Test-Path -Path "$NewDir$FileName")) {
          Write-Log -Message "& cmd /C copy /Y $Directory $DestToUser" -Source ${CmdletName}
					& cmd /C "copy /Y $Directory $DestToUser"
        } else {
					if ($isForce.ToLower() -eq 'true') {
						Write-Log -Message "$NewDir$FileName exist, but will be overwriten because isForce = $isForce." -Source ${CmdletName}
						Write-Log -Message "& cmd /C copy /Y $Directory $DestToUser" -Source ${CmdletName}
						& cmd /C "copy /Y $Directory $DestToUser"
					} else { Write-Log -Message "Will not copy $Directory to $DestToUser, because target file exist and is set not to force." -Source ${CmdletName} }
				}#>
      } elseif ($Global:userActions.ToLower() -eq 'false') { 
        Write-Log -Message "Will skipp ${CmdletName} execution. userActions = $($Global:userActions)." -Source ${CmdletName} -Severity 3
        Write-Log -Message "For your account use an other method for actions in user context/manipulation of user profiles." -Source ${CmdletName} -Severity 3 
      } else {
        if ($forAllUsers -eq $True) {
					$NewDir = $NewDir.Replace("%allusers%\","\")
          Write-Log -Message "Will proceed with path: $NewDir for all users profiles." -Source ${CmdletName}
          ForEach ($User In (Get-WmiObject Win32_UserProfile -F "Special != True" | Select-Object -Expand LocalPath)) {
            $User = $User.trim()
            $NewDir = $NewDir.trim()
            Write-Log -Message "\User\NewDirectory - $($User)$NewDir" -Source ${CmdletName}
            if(!(Test-Path -Path "$($User)$NewDir")){  New-Item -ItemType directory -Path "$($User)$NewDir" }
            if ($isForce.ToLower() -eq "true") { if (Test-Path -Path "$($User)$NewDir$FileName") { Remove-Item "$($User)$NewDir$FileName" } }

            $DestToUser = "$($User)$NewDir"
            $DestToUser = '"'+"$DestToUser\$FileName"+'"'
            $DestToUser = $DestToUser.Replace(" \","\")
            $DestToUser = $DestToUser.Replace("\\","\")

            Write-Log -Message "Execute-CopyItem -FileName $FileName -OldDir `"$OldDir`" -NewDir `"$($User)$NewDir`" -isForce $isForce" -Source ${CmdletName}
						Execute-CopyItem -FileName $FileName -OldDir "$OldDir" -NewDir "$($User)$NewDir" -isForce $isForce

						<#if (-not (Test-Path -Path "$($User)$NewDir$FileName")) {
							Write-Log -Message "& cmd /C copy /Y $Directory $DestToUser" -Source ${CmdletName}
							& cmd /C "copy /Y $Directory $DestToUser"
						} else {
							if ($isForce.ToLower() -eq 'true') {
								Write-Log -Message "$($User)$NewDir$FileName exist, but will be overwriten because isForce = $isForce." -Source ${CmdletName}
								Write-Log -Message "& cmd /C copy /Y $Directory $DestToUser" -Source ${CmdletName}
								& cmd /C "copy /Y $Directory $DestToUser"
							} else { Write-Log -Message "Will not copy $Directory to $DestToUser, because target file exist and is set not to force." -Source ${CmdletName} }
						}#>
          }
        } else {
          Write-Log -Message "Proceed with username's." -Source ${CmdletName}
          ForEach ($User In (Get-WmiObject Win32_UserProfile -F "Special != True" | Select-Object -Expand LocalPath)) {
            $User = $User.trim()
            $userName = Split-Path $User -Leaf
            $NewDir = $NewDir.trim()

            $DestToUser = Set-OwerrideVar -Var $NewDir -IN $UName -OUT $userName
            $DestToUser = $DestToUser.Replace(" \","\").Replace("\\","\")
            $DestToUser = Set-StringFromVarLayered -VarToCheck $DestToUser

						Execute-CopyItem -FileName $FileName -OldDir $OldDir -NewDir $($User)$NewDir -isForce $isForce

						<#if (-not (Test-Path -Path "$($User)$NewDir$FileName")) {
							Write-Log -Message "& cmd /C copy /Y $Directory $DestToUser" -Source ${CmdletName}
							& cmd /C "copy /Y $Directory $DestToUser"
						} else {
							if ($isForce.ToLower() -eq 'true') {
								Write-Log -Message "$($User)$NewDir$FileName exist, but will be overwriten because isForce = $isForce." -Source ${CmdletName}
								Write-Log -Message "& cmd /C copy /Y $Directory $DestToUser" -Source ${CmdletName}
								& cmd /C "copy /Y $Directory $DestToUser"
							} else { Write-Log -Message "Will not copy $Directory to $DestToUser, because target file exist and is set not to force." -Source ${CmdletName} }
						}#>
          }
        }
      }
    } else {
      <#if ($isForce.ToLower() -eq "true") { 
        if (Test-Path -Path $NewDirectoryF) { 
          Write-Log -Message "Function is set to force, will:" -Source ${CmdletName}
          Write-Log -Message "Remove-Item $NewDirectoryF -Force" -Source ${CmdletName}
          Remove-Item $NewDirectoryF -Force
        } 
      }#>
      if (Test-Path -Path "$OldDir\$FileName" -PathType "Leaf") { Write-Log -Message "`"$OldDir\$FileName`" exist, will continue." -Source ${CmdletName} }
      else {
        Write-Log -Message "`"$OldDir\$FileName`" is missing, will not continue." -Source ${CmdletName}
        Set-Finalize -ExitCode 1
      }

      if (Test-Path -Path $NewDir -PathType "Container") { Write-Log -Message "$NewDir exists. Copying $FileName." -Source ${CmdletName} }
      else {
        Write-Log -Message "$NewDir doesn't exist, creating." -Source ${CmdletName}
        New-Item -ItemType directory -Path "$NewDir"
      }

      <#$NewDir = '"'+$NewDir+'"'
      #Test-ParamFile -path $Directory
      if (-not(Test-Path -Path $NewDirectoryF -PathType "Leaf")) {
        if (Test-Path -Path "$NewDirectoryF" -PathType Leaf) {
          Write-Log -Message "File with the same name exist in $NewDirectory. Will compare them." -Source ${CmdletName}
          $ExistingFile = Get-FileHash "$NewDirectoryF" -Algorithm SHA384
          $NewFile = Get-FileHash "$Directory" -Algorithm SHA384
          Write-Log -Message "Existing file hash = $ExistingFile" -Source ${CmdletName}
          Write-Log -Message "Existing file hash = $NewFile" -Source ${CmdletName}
          If ($ExistingFile -eq $NewFile) { Write-Log -Message "Both files are the same, nothing to do." -Source ${CmdletName} }
          else { 
            Write-Log -Message "Files are not the same, will remove $NewDirectoryF." -Source ${CmdletName}
						if ($isForce.ToLower() -eq "true") {  Remove-Item -Path "$NewDirectoryF" -Force }
            Write-Log -Message "copy $Directory $NewDirectory" -Source ${CmdletName}
            #Write-Log -Message "& cmd /C copy $Directory $NewDirectory" -Source ${CmdletName}

						if (-not (Test-Path -Path "$NewDirectoryF")) {
							Write-Log -Message "& cmd /C copy /Y $Directory $NewDirectory" -Source ${CmdletName}
							& cmd /C "copy /Y $Directory $NewDirectory"
						} else {
							if ($isForce.ToLower() -eq 'true') {
								Write-Log -Message "$NewDirectoryF exist, but will be overwriten because isForce = $isForce." -Source ${CmdletName}
								Write-Log -Message "& cmd /C copy /Y $Directory $NewDirectory" -Source ${CmdletName}
								& cmd /C "copy /Y $Directory $NewDirectory"
							} else { Write-Log -Message "Will not copy $Directory to $NewDirectory, because target file exist and is set not to force." -Source ${CmdletName} }
						}
          }
        } else {#>
          Write-Log -Message "Will copy $Directory to $NewDirectory. isForce = $isForce." -Source ${CmdletName}
					Execute-CopyItem -FileName $FileName -OldDir $OldDir -NewDir $NewDir -isForce $isForce

					<# if ((Test-Path -Path "$NewDirectoryF" -PathType Leaf) -eq $False) {
						Write-Log -Message "$NewDirectoryF is not exist so will: & cmd /C copy /Y $Directory $NewDirectory" -Source ${CmdletName}
						& cmd /C "copy /Y $Directory $NewDirectory"
					} else {
						if ($isForce.ToLower() -eq 'true') {
							Write-Log -Message "$NewDirectoryF exist, but will be overwriten because isForce = $isForce." -Source ${CmdletName}
							Write-Log -Message "& cmd /C `"copy /Y $Directory $NewDirectory`"" -Source ${CmdletName}
							& cmd /C "copy /Y $Directory $NewDirectory"
						} else { Write-Log -Message "Will not copy $Directory to $NewDirectory, because target file exist and is set not to force." -Source ${CmdletName} }
					} #>
          #Write-Log -Message "& cmd /C copy $Directory $NewDirectory" -Source ${CmdletName}
          #& cmd /C "copy $Directory $NewDirectory"
        #}
      #}
      #robocopy $copyAdmin $AdminPath /e /xf "web.config" "Deploy"
      #Copy-File -Path "$Directory" -Destination "$NewDir\" -ContinueOnError $True
    }
  }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Execute-CopyItem {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    $FileName,
    $OldDir,
    $NewDir,
		$isForce
  )

	[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  $NewDir = $NewDir.Replace('\"','')
  $OldDir = $OldDir.Replace('\"','')
  $NewDir = $NewDir.Replace('"','').Replace("\\","\")
  $OldDir = $OldDir.Replace('"','').Replace("\\","\")
	$FileName = $FileName.Replace('"','')

	$OldFullPath = '"' + $OldDir + '\' + $FileName + '"'
	$NewFullPathEasy = "$NewDir\$FileName"
	$NewFullPath = '"' + $NewDir + '\' + $FileName + '"'
	$NewDirectory = '"' + $NewDir + '\"'

	if (([System.IO.File]::Exists($NewFullPath)) -eq $False) {
		Write-Log -Message "Target file is not exist." -Source ${CmdletName}
		$isExist = $False
	} else {
		Write-Log -Message "Target file is exist." -Source ${CmdletName}
		$isExist = $True
	}
	
	if ($isExist -eq $False) {
		Write-Log -Message "Will double check if file is not exist." -Source ${CmdletName}
		$Files = Get-ChildItem -Path $NewDir -Name
		foreach ($File in $Files) { 
			if ($File -eq $FileName) {
				Write-Log -Message "Target file is exist." -Source ${CmdletName}
				$isExist = $True
				break
			}
		}
	}

	Write-Log -Message "Test-Path -Path $NewFullPath -PathType Leaf. isExist = $isExist." -Source ${CmdletName}

	if ($isForce.ToLower() -eq 'true') {
		Write-Log -Message "Proceed with isForce True and isExist = $isExist." -Source ${CmdletName}
		if ($isExist -eq $True) { 
			Write-Log -Message "$isForce = $isForce so will remove $NewFullPath." -Source ${CmdletName}
			Remove-Item -Path "$NewFullPathEasy" -Force
		} else { Write-Log -Message "$NewFullPath is not exist so will: & cmd /C copy /Y $OldFullPath $NewDirectory" -Source ${CmdletName} }
		& cmd /C "copy /Y $OldFullPath $NewDirectory"
	} elseif ($isForce.ToLower() -eq "compare") {
		if ($isExist -eq $True) {
			Write-Log -Message "Will check if files are the same because target file exist and $isForce = $isForce ." -Source ${CmdletName}
			$NewFullPath = Get-FileHash "$NewFullPath" -Algorithm SHA384
			$OldFullPath = Get-FileHash "$OldFullPath" -Algorithm SHA384
			If ($NewFullPath -eq $OldFullPath) { Write-Log -Message "Both files are the same, nothing to do." -Source ${CmdletName} }
			else {
				Write-Log -Message "Files are different, will remove $NewFullPath, and copy new file." -Source ${CmdletName}
				Remove-Item -Path "$NewFullPathEasy" -Force
			}
		}
		& cmd /C "copy /Y $OldFullPath $NewDirectory"
	} else {
		Write-Log -Message "Proceed with isForce False and isExist = $isExist." -Source ${CmdletName}
		if ($isExist -eq $True) { Write-Log -Message "Will not copy $OldFullPath to $NewFullPath, because target file exist and $isForce = $isForce ." -Source ${CmdletName}} 
		else { 
			Write-Log -Message "$NewFullPath is not exist so will: & cmd /C copy /Y $OldFullPath $NewDirectory" -Source ${CmdletName}
			& cmd /C "copy /Y $OldFullPath $NewDirectory"
		}
	}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-FileAction {
  <#
    .SYNOPSIS
      It handles copy, check, remove and rename, move for files. 
    .DESCRIPTION
      It handles all basic actions for files and can process files in batch.
    .PARAMETER actionName
      The name action type you want to trigger: ADD, MOVE, RENAME, CHECK or REMOVE can be used for	FILE.
    .PARAMETER Data
      Data variable withh all information to execute function like:
      DataFileName=File name.
      DataDirPath=Source directory path for file. 
      DataTargetDirPath=Target directory path for file.
    .PARAMETER DataType
      As default is a null for FILE. 
      DoNotForce=if you want to skip if file is already in place to not override it. 
    .EXAMPLE
      Conf line: POSTINSTALL,COPY,FILE,*=%srcfilepath%\Shortcuts\=c:\ProgramData\Microsoft\Windows\Start Menu\Programs\FX Trading\,null - Will copy all files from Shortcut directory into FX Trading start menu folder.
    .EXAMPLE
      Conf line: POSTINSTALL,REMOVE,FILE,Thomson Reuters Eikon Messenger.lnk=%allusers%\Desktop,null - will remove single file for each user from desktop.
    .NOTES
      This is an internal script function and should typically not be called directly, it will be triggered by main script if proper conf line will be found.
    .LINK
      https://github.kyndryl.net/wms-global/WMSAutomationTool/
  #>
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$DataType = "null",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #POSTINSTALL,COPY,FILE,GET_MSIproperty_with_menu.ps1=c:\=C:\Dane\GitHub\wmvareappv-automation\Scripts\OLD\Packaging_improvement_tools\Get_MSI_information\,false
  #PREINSTALL,REMOVE,FILE,GET_MSIproperty_with_menu.ps1=C:\Dane\GitHub\wmvareappv-automation\Scripts\OLD\Packaging_improvement_tools,null
  #PREINSTALL,CHECK,FILE,GET_MSIproperty_with_menu.ps1=C:\Dane\GitHub\wmvareappv-automation\Scripts\OLD\Packaging_improvement_tools,null
  #POSTINSTALL,RENAME,FILE,oldfile=newfile=dir,null
  #%allusers%
  #POSTINSTALL,COPY,FILE,GET_MSIproperty_with_menu.ps1=c:\=C:\Dane\GitHub\wmvareappv-automation\Scripts\OLD\Packaging_improvement_tools\Get_MSI_information\,%somevar%=value
  #POSTINSTALL,ADD,FILE,GET_MSIproperty_with_menu.ps1=C:\Dane\GitHub\wmvareappv-automation\,%somevar%=value


  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  $process = $True

  if ($DataType.ToLower() -ne "null") {
    if ($DataType -like "*=*") {
      $isForce = 'true'
			$process =  Get-TestValueResult -DataType $DataType

      <# Write-Log -Message "Will test if $DataType." -Source ${CmdletName}
      $test = $DataType.Split("=")
      $originalValue = Set-StringFromVarLayered -VarToCheck $test[0]
      $testValue = Set-StringFromVarLayered -VarToCheck $test[1]

      if ($originalValue -eq $testValue) { Write-Log -Message "Will continue with programed action: $actionName." -Source ${CmdletName} }
      else { 
        Write-Log -Message "Test failed, will skipp programed action: $actionName." -Source ${CmdletName}
        $process = $False
      } #>
    } else {
      if ($DataType.ToLower() -eq 'false') { $isForce = 'false' }
      elseif (($DataType.ToLower() -eq 'true') -or ($DataType.ToLower() -eq 'null')) { $isForce = 'true' }
      else { 
        Write-Log -Message "Test is incomplete, is missing =. Will fail." -Source ${CmdletName}
        Set-Finalize -ExitCode 1
      }
    }
  } else {
		Write-Log -Message "Null as last parameter, will set isForce = 'true'." -Source ${CmdletName}
		$isForce = 'true'
	}

  #if($DataType.ToLower() -eq 'null') { $isForce = 'true' }
  #else { $isForce = $DataType }

  if ($process -eq $True) {
    #TODO: implement isForce for actions.
    If ($actionName.ToUpper() -eq "MOVE") {
      $FileName = Set-StringFromVarLayered -VarToCheck $Data[0]
      #$OldDir = Set-StringFromVarLayered -VarToCheck $Data[1]
      #$NewDir = Set-StringFromVarLayered -VarToCheck $Data[2]
      #$Directory = Set-StringFromVarLayered -VarToCheck $OldDir
      $OldDir = $Data[1]
      $NewDir = $Data[2]
      $Directory = $OldDir

      Write-Log -Message "Set-CopyFiles -FileName $FileName -OldDir $OldDir -NewDir $NewDir" -Source ${CmdletName}
      Set-CopyFiles -FileName $FileName -OldDir $OldDir -NewDir $NewDir

      Write-Log -Message "Set-RemoveFiles -FileName $FileName -Directory $Directory" -Source ${CmdletName}
      Set-RemoveFiles -FileName $FileName -Directory $Directory
    } elseif ($actionName.ToUpper() -eq "COPY") {
      $FileName = Set-StringFromVarLayered -VarToCheck $Data[0]
      #$OldDir = Set-StringFromVarLayered -VarToCheck $Data[1]
      #$NewDir = Set-StringFromVarLayered -VarToCheck $Data[2]
      $OldDir = $Data[1]
      $NewDir = $Data[2]

      Write-Log -Message "Set-CopyFiles -FileName $FileName -OldDir $OldDir -NewDir $NewDir -isForce $isForce" -Source ${CmdletName}
      Set-CopyFiles -FileName $FileName -OldDir $OldDir -NewDir $NewDir -isForce $isForce
    } elseif ($actionName.ToUpper() -eq "ADD") {
      #$FileName = Set-StringFromVarLayered -VarToCheck $Data[0]
      #$Directory = Set-StringFromVarLayered -VarToCheck $Data[1]
      $FileName = $Data[0]
      $Directory = $Data[1]

      Write-Log -Message "Will create $FileName in $Directory directory." -Source ${CmdletName}
      Set-NewEmptyFile -FileName $FileName -Directory $Directory
    } elseif ($actionName.ToUpper() -eq "REMOVE") {
      #$FileName = Set-StringFromVarLayered -VarToCheck $Data[0]
      #$Directory = Set-StringFromVarLayered -VarToCheck $Data[1]
      $FileName = $Data[0]
      $Directory = $Data[1]

      Write-Log -Message "Set-RemoveFiles -FileName $FileName -Directory $Directory" -Source ${CmdletName}
      Set-RemoveFiles -FileName $FileName -Directory $Directory
    } elseif ($actionName.ToUpper() -eq "CHECK") {
      $FileName = Set-StringFromVarLayered -VarToCheck $Data[0]
      $Directory = Set-StringFromVarLayered -VarToCheck $Data[1]

      $FilePath = "$Directory\$FileName"
      if (Test-Path $FilePath) { Write-Log -Message "$FilePath exist, returning $True." -Source ${CmdletName}; return $True }
      else { Write-Log -Message "$FilePath is missing, returning $False." -Source ${CmdletName}; return $False }
    } elseif ($actionName -eq "RENAME") {
      $forAllUsers =  Get-isAllUsers -stringToTest $Data[2]
      $forAllUsersUserName = Get-isUserName -stringToTest $Data[2]

      $FileName = Set-StringFromVarLayered -VarToCheck $Data[0]
      $NewFileName = Set-StringFromVarLayered -VarToCheck $Data[1]
      $Directory = Set-StringFromVarLayered -VarToCheck $Data[2]

      $File = '"' + $Directory + "\" + $FileName + '"'
      $NewFileNameB = $NewFileName
      $NewFileName = '"' + $NewFileName + '"'

      if (($forAllUsers -eq $True) -or ($forAllUsersUserName -eq $True)) {
        if (($Global:UserContextVar -eq "user") -and ($forAllUsersUserName -eq $True)) {
          Write-Log -Message "Will proceed for current user." -Source ${CmdletName}
          $Directory = $Directory.trim()
          $FileName = $FileName.trim()
          $NewFileName = $NewFileName.trim()
          Write-Log -Message "Handling User - $userName" -Source ${CmdletName}; 
          $UDir = Get-userNameString -string $Directory

          $Ufile = "$($UDir)\$FileName"
          $Nfile = "$($UDir)\$NewFileNameB"

          Write-Log -Message "Handling UDir - $UDir" -Source ${CmdletName}; 
          Write-Log -Message "Handling Ufile - $Ufile" -Source ${CmdletName}; 
          Write-Log -Message "Handling Nfile - $Nfile" -Source ${CmdletName};
          Write-Log -Message "$Ufile -> $Nfile" -Source ${CmdletName}

          if ((Test-Path -Path "$Ufile") -eq $True) { 
            if ((Test-Path -Path "$Nfile") -eq $False) {
              Write-Log -Message "RENAME $Ufile $NewFileName." -Source ${CmdletName}; 
              & cmd /C "RENAME $Ufile $NewFileName" 
            }
          }
        } elseif ($Global:userActions.ToLower() -eq 'false') { 
          Write-Log -Message "Will skipp ${CmdletName} execution. userActions = $($Global:userActions)." -Source ${CmdletName} -Severity 3
          Write-Log -Message "For your account use an other method for actions in user context/manipulation of user profiles." -Source ${CmdletName} -Severity 3 
        } else {
          If ($forAllUsers -eq $True) {
						$NewDir = $NewDir.Replace("%allusers%\","\")
            Write-Log -Message "Will proceed with path: $File for all users profiles." -Source ${CmdletName}
            ForEach ($User In (Get-WmiObject Win32_UserProfile -F "Special != True" | Select-Object -Expand LocalPath)) {
              $User = $User.trim()
              $Directory = $Directory.trim()
              $FileName = $FileName.trim()
              $NewFileName = $NewFileName.trim()
              Write-Log -Message "Handling User - $User" -Source ${CmdletName}; 
              
              $UDir = "$($User)$Directory"
              $Ufile = "$($UDir)\$FileName"
              $Nfile = "$($UDir)\$NewFileNameB"

              Write-Log -Message "Handling UDir - $UDir" -Source ${CmdletName}; 
              Write-Log -Message "Handling Ufile - $Ufile" -Source ${CmdletName}; 
              Write-Log -Message "Handling Nfile - $Nfile" -Source ${CmdletName};
              Write-Log -Message "$Ufile -> $Nfile" -Source ${CmdletName}

              if ((Test-Path -Path "$Ufile") -eq $True) { 
                if ((Test-Path -Path "$Nfile") -eq $False) {
                  Write-Log -Message "RENAME $Ufile $NewFileName." -Source ${CmdletName}; 
                  & cmd /C "RENAME $Ufile $NewFileName" 
                }
              }
            }
          } else {Write-Log -Message "Will proceed with path: $File for all usersnames." -Source ${CmdletName}
            ForEach ($User In (Get-WmiObject Win32_UserProfile -F "Special != True" | Select-Object -Expand LocalPath)) {
              $User = $User.trim()
              $Directory = $Directory.trim()
              $FileName = $FileName.trim()
              $NewFileName = $NewFileName.trim()
              $userName = Split-Path $User -Leaf
              Write-Log -Message "Handling User - $userName" -Source ${CmdletName}; 
              
              $UDir = $Directory.Replace(" \","\").Replace("\\","\").Replace("%username%",$userName)
              $Ufile = "$($UDir)\$FileName"
              $Nfile = "$($UDir)\$NewFileNameB"

              Write-Log -Message "Handling UDir - $UDir" -Source ${CmdletName}; 
              Write-Log -Message "Handling Ufile - $Ufile" -Source ${CmdletName}; 
              Write-Log -Message "Handling Nfile - $Nfile" -Source ${CmdletName};
              Write-Log -Message "$Ufile -> $Nfile" -Source ${CmdletName}

              if ((Test-Path -Path "$Ufile") -eq $True) { 
                if ((Test-Path -Path "$Nfile") -eq $False) {
                  Write-Log -Message "RENAME $Ufile $NewFileName." -Source ${CmdletName}; 
                  & cmd /C "RENAME $Ufile $NewFileName" 
                }
              }
            }
          }
        }
      } else {  Write-Log -Message "RENAME $File $NewFileName." -Source ${CmdletName}; & cmd /C "RENAME $File $NewFileName" }
    }
  }
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Test-Directory {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    $Directory,
    $Action = "exit"
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  if ((Test-Path -path "$Directory" -PathType Container) -eq $False) {
    if ($Action -eq "exit") {
      Write-Log -Message "Directory: $Directory is missing. Stopping script execution." -Severity 2 -Source ${CmdletName}
      Set-Finalize -ExitCode 1
    } else {
      Write-Log -Message "Directory: $Directory is missing. Going next." -Severity 2 -Source ${CmdletName}
    }
  }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Get-Users {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    $getSpecial = $False,
    $forAllUsersUserName
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  Write-Log -Message "Will gather all users data on machine." -Source ${CmdletName}

  $Users = @()
  $special = "True"
  if ($getSpecial -eq $True) { $special = "False"}

  if (($Global:UserContextVar -eq "user") -and ($forAllUsersUserName -eq $True)) {
    Write-Log -Message "Handling current user context." -Source ${CmdletName}
    $userName = $($env:UserName).trim()
    $User = $($Env:userprofile).trim()
    Write-Log -Message "Got userName = $userName, User = $User." -Source ${CmdletName}
    $Users += ,@("$userName;$User")
  } else {
    Write-Log -Message "Handling all users context." -Source ${CmdletName}
    ForEach ($User In (Get-WmiObject Win32_UserProfile -F "Special != $special" | Select-Object -Expand LocalPath)) {
      $User = $User.trim()
      $userName = Split-Path $User -Leaf
      Write-Log -Message "Got userName = $userName, User = $User." -Source ${CmdletName}
      $Users += ,@("$userName;$User")
    }
  }

  Return $Users
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-CopyDir {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    $OldDir,
    $NewDir
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  Write-Log -Message "Copy directory from: $OldDir to: $NewDir." -Source ${CmdletName}
  $forAllUsers =  Get-isAllUsers -stringToTest $NewDir
  $forAllUsersUserName = Get-isUserName -stringToTest $NewDir
  $NewDir = $NewDir.trim()
  $OldDir = $OldDir.trim()

  Write-Log -Message "Copy directory from: $OldDir to: $NewDir." -Source ${CmdletName}

  if (($forAllUsers -eq $True) -or ($forAllUsersUserName -eq $True)) {
    if ($Global:userActions.ToLower() -eq 'false') {
      Write-Log -Message "Will skipp ${CmdletName} execution. userActions = $($Global:userActions)." -Source ${CmdletName} -Severity 3
      Write-Log -Message "For your account use an other method for actions in user context/manipulation of user profiles." -Source ${CmdletName} -Severity 3
      Return 0
    } else {
      $Users = Get-Users -forAllUsersUserName $forAllUsersUserName

      Foreach($UserData in $Users) {
        Write-Log -Message "UserData: $UserData." -Source ${CmdletName}
        $tmp = $UserData.Split(";")
        $userName = $tmp[0]
        $UserPath = $tmp[1]
        if (($Global:UserContextVar -eq "user") -and ($forAllUsersUserName -eq $True)) {
          Write-Log -Message "Will proceed for current user $userName." -Source ${CmdletName}
          $TargetDir = $NewDir.Replace("%username%",$userName).Replace(" \","\").Replace("\\","\")
        } elseIf ($forAllUsers -eq $True) {
          Write-Log -Message "Will proceed for all users: user $userName." -Source ${CmdletName}
          Write-Log -Message "\User\NewDir - $($UserData[1])$NewDir" -Source ${CmdletName}
          $UserDir = "$UserPath$NewDir"
          $TargetDir = $UserDir.Replace(" \","\").Replace("\\","\")
        } else {
          Write-Log -Message "Proceed with username's, users: user $userName." -Source ${CmdletName}
          $TargetDir = $NewDir.Replace("%username%",$userName).Replace(" \","\").Replace("\\","\")
        }
        $TargetDir = $TargetDir.Replace(" \","\").Replace("\\","\")
        $OldDir = $OldDir.Replace(" \","\").Replace("\\","\")
        Set-XCopy -OldDir $OldDir -NewDir $TargetDir
      }
    }
  } else {
    Write-Log -Message "Standard (not all users) copy action." -Source ${CmdletName}
    Write-Log -Message "Will validate if target dir ($NewDir) is a valid path." -Source ${CmdletName}
    $NewDir = $NewDir.Replace(" \","\").Replace("\\","\")
    $OldDir = $OldDir.Replace(" \","\").Replace("\\","\")
    if($NewDir -like "\*") { $NewDir = $NewDir -replace '^\\' }
    Set-XCopy -OldDir $OldDir -NewDir $NewDir
  }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-XCopy {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    $OldDir,
    $NewDir
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  
  $OldDir = Set-StringFromVarLayered -VarToCheck $OldDir
  $NewDir = Set-StringFromVarLayered -VarToCheck $NewDir

  if ([System.IO.Path]::IsPathRooted("$NewDir")) { 
    if(-Not (Test-Path -Path $NewDir)) {
      Write-Log -Message "Xcopy /E /I /S /H /Y $OldDir $NewDir" -Source ${CmdletName}
      Xcopy /E /I /S /H /Y $OldDir $NewDir
    } elseif ($OldDir.Chars($OldDir.Length - 1) -eq "*" ) {
      $Items = Get-ChildItem -Path "$OldDir"
      foreach ($Item in $Items) {
        Write-Log -Message "Xcopy /E /I /S /H /Y $($Item.FullName) $NewDir" -Source ${CmdletName}
        Xcopy /E /I /S /H /Y $Item.FullName $NewDir
      }
    } else {
      Write-Log -Message "Xcopy /E /I /S /H /Y $OldDir $NewDir" -Source ${CmdletName}
      Xcopy /E /I /S /H /Y $OldDir $NewDir
    }
  } else { Write-Log -Message "Will not copy, path is relative or bad." -Source ${CmdletName} }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-RemoveDir {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    $isForce,
    $Directory,
    $asterisk = 'null'
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  Write-Log -Message "Directory to remove: $Directory " -Severity 2 -Source ${CmdletName}

  $Directory = Set-StringFromVarLayered -VarToCheck $Directory
  $Directory = $Directory.Replace('"','')
  $Directory = $Directory.Trim()
  $LastChar = $Directory.Substring($Directory.get_Length()-1)
  
  if (($asterisk -eq $True) -or ($asterisk -eq "True")) { $LastChar = "*" }

  Write-Log -Message "LastChar: $LastChar, asterisk: $asterisk " -Severity 2 -Source ${CmdletName}

  If ($LastChar -eq "\") { $Directory = $Directory.Substring(0,$Directory.Length-1) }
  If ($LastChar -eq "*") {
    if (-not(($asterisk -eq $True) -or ($asterisk -eq "True"))) {
      $BaseDir = ""
      $DirArr = $Directory.Split("\")
      $ArrLeng = $DirArr.Length
      Write-Log -Message "ArrLeng: $ArrLeng " -Severity 2 -Source ${CmdletName}
      For ($x = 0; $x -lt $ArrLeng - 1; $x++) {
        Write-Log -Message "DirArr[$x]: $DirArr[$x] " -Severity 2 -Source ${CmdletName}
        If ($BaseDir -eq "") { $BaseDir = $DirArr[$x] }
        else { $BaseDir = $BaseDir + "\" + $DirArr[$x] }
      }
      if ((Test-Path -path $BaseDir -PathType Container) -eq $True) {
        #Get-ProcessesFromDir -targetDir $BaseDir #will try to kill all processes related to target base directory to avoid some of ioexeptions.
        $PartName = ($DirArr[$DirArr.Length - 1]).Trim("*")
        $Paths = Get-ChildItem "$BaseDir" -Directory
      } else {
        Write-Log -Message "$BaseDir is not existing. Nothing to remove, Going next." -Severity 2 -Source ${CmdletName}
        Return 0
      }
    } 

    if (($asterisk -eq $True) -or ($asterisk -eq "True")) {
      For ($x = 0; $x -lt $ArrLeng - 1; $x++) {
        Write-Log -Message "DirArr[$x]: $DirArr[$x] " -Severity 2 -Source ${CmdletName}
        If ($BaseDir -eq "") { $BaseDir = $DirArr[$x] }
        else { $BaseDir = $BaseDir + "\" + $DirArr[$x] }
      }
      #Write-Log -Message "Get-ChildItem $BaseDir | Where-Object {$_.Attributes -match 'Directory'} | Where-Object {$_.fullName -like `"$Directory*`" }" -Severity 2 -Source ${CmdletName}
      #$Paths = Get-ChildItem $BaseDir | Where-Object {$_.Attributes -match 'Directory'} | Where-Object {$_.fullName -like "$Directory*" }
			Write-Log -Message "Get-ChildItem `"$Directory*`" -Directory" -Severity 2 -Source ${CmdletName}
      $Paths = Get-ChildItem "$Directory*" -Directory
    }

    If (!($Paths))  { Write-Log -Message "There is no folders match the criterium." -Source ${CmdletName} } 
    Else {
			#Get-ProcessesFromDir -targetDir $BaseDir #will try to kill all processes related to target base directory to avoid some of ioexeptions.
      #Write-Log -Message "PartName: $PartName " -Severity 2 -Source ${CmdletName}
      #Write-Log -Message "BaseDir: $BaseDir " -Severity 2 -Source ${CmdletName}
      #Write-Log -Message "Paths: $Paths " -Severity 2 -Source ${CmdletName}

      foreach ($path in $Paths) {
        $dir = $path.FullName
				Write-Log -Message "Will try to remove path: `"$dir`"." -Severity 2 -Source ${CmdletName}

        #If (($dir -like "*$PartName*") -or ($dir -like "*$PartName")) {
          Write-Log -Message "Directory: $dir" -Severity 2 -Source ${CmdletName}
          if (Test-Path "$dir") {
            Write-Log -Message "Directory: $dir" -Severity 2 -Source ${CmdletName}
            if (($isForce -ne "null") -and ($isForce -eq 'force' )) { Set-RmDir -Directory $dir -isForce "force" } 
            elseif (($isForce -eq "null") -or ($isForce -eq "false")) { Set-RmDir -Directory $dir -isForce "false" }
            if (Test-Path "$dir") { Remove-Item "$dir" -Force -Confirm:$false }
            if ((Test-Path "$dir")-eq $False) { Write-Log -Message "$dir removed." -Source ${CmdletName} }
          }
        #}
      }
    }
  } else {
    $isExist = Test-Path $Directory -PathType 'Container'
    Write-Log -Message "Test-Path $Directory -PathType 'Container' - $isExist" -Source ${CmdletName}
    if ($isExist -eq $True) { Set-RmDir -Directory $Directory -isForce $isForce } 
    else { Write-Log -Message "Directory $Directory doesn't exist." -Source ${CmdletName} }
  }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-RmDir {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    $Directory,
    $isForce
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  
  $Directory = Set-StringFromVarLayered -VarToCheck $Directory
  
  if (Split-Path "$Directory" -IsAbsolute) {
    Test-Directory -Directory "$Directory" -Action "continue"
    if (($isForce -eq "true") -or ($isForce -eq "force")) {
      Write-Log -Message "Will remove $Directory for isForce = $isForce." -Source ${CmdletName}
      Get-ChildItem -Path "$Directory" -Include * -File -Recurse | ForEach-Object { $_.Delete() }
      Get-ChildItem -Path "$Directory" -Include * | Remove-Item -recurse
      $CmdToRun = 'rmdir /s /q "'+$Directory+'"'
      Set-customCMD -CmdToRun $CmdToRun
    } elseif ((($isForce -eq "null") -or ($isForce -eq "false") -or ($isForce -eq "noforce")) -and ((Get-ChildItem $Directory | Measure-Object).Count -eq 0)) {
      Write-Log -Message "$Directory is an empty and line is set not to force. Will remove." -Source ${CmdletName}
      $CmdToRun = 'rmdir /s /q "'+$Directory+'"'
      Set-customCMD -CmdToRun $CmdToRun
    } else {
      Write-Log -Message "$Directory is not an empty or/and line is set not to force. Will skip removal." -Source ${CmdletName}
      Return 0
    }
  } else { Write-Log -Message "Will not remove, path is relative or bad." -Source ${CmdletName} }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Get-TestValueResult {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$DataType
  )

	$process = $False

	[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
	Write-Log -Message "Will test if $DataType." -Source ${CmdletName}
	$test = $DataType.Split("=")
	$originalValue = Set-StringFromVarLayered -VarToCheck $test[0]
	$testValue = Set-StringFromVarLayered -VarToCheck $test[1]

	if (([string]::IsNullOrWhitespace($($originalValue))) -or ([string]::IsNullOrWhitespace($($testValue)))) {
		Write-Log -Message "Test is incomplete, is missing data. Will fail." -Source ${CmdletName}
		Set-Finalize -ExitCode 1
	}
	
	Write-Log -Message "Will test if $testValue holding multiple values." -Source ${CmdletName}
	if ($testValue -like "*|*") { $tests = $testValue.Split("|") }
	else { $tests = $testValue }

	foreach ($test in $tests) {
		Write-Log -Message "Comparing if: $originalValue = $test." -Source ${CmdletName}
		if ($originalValue -eq $test) {
			Write-Log -Message "Will continue with programed action: $actionName." -Source ${CmdletName}
			$process = $True
		}
	}

	if ($process -eq $False) { Write-Log -Message "Test failed, will skipp programed action: $actionName." -Source ${CmdletName} }

	Return $process
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-DirAction {
  <#
    .SYNOPSIS
      It handles copy, check, remove and rename, move for folders. 
    .DESCRIPTION
      It handles all basic actions for folders.
    .PARAMETER actionName
      The name action type you want to trigger: ADD, MOVE, RENAME, CHECK or REMOVE can be used for DIR.
    .PARAMETER Data
      Data variable withh all information to execute function like:
      DataIsForce =True or False value for force remove. If true, target directory with files will be removed, if false – only empty.
      DataDirPath=Target directory path.
      DataTargetDirPath=Target directory path.
    .PARAMETER DataType
      As default is a null for DIR. 
    .EXAMPLE
      Conf line: POSTUNINSTALL,REMOVE,DIR,force=C:\ProgramData\Microsoft\Windows\Start Menu\Programs\FX Trading\,null - will remove folder with its content.
    .EXAMPLE
      Conf line: PREINSTALL,ADD,DIR,C:\Dane\GitHub\wmvareappv-automation\Scripts\OLD\Packaging_improvement_tools=null,null - will create empty folder if doesnt exist.
    .NOTES
      This is an internal script function and should typically not be called directly, it will be triggered by main script if proper conf line will be found.
    .LINK
      https://github.kyndryl.net/wms-global/WMSAutomationTool/
  #>
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$DataType = "null",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #PREINSTALL,REMOVE,DIR,force=C:\Dane\GitHub\wmvareappv-automation\Scripts\OLD\Packaging_improvement_tools,null
  #PREINSTALL,REMOVE,DIR,force=C:\Dane\GitHub\wmvareappv-automation\Scripts\OLD\Packaging_improvement_*,null
  #PREINSTALL,ADD,DIR,C:\Dane\GitHub\wmvareappv-automation\Scripts\OLD\Packaging_improvement_tools=null,null
  #POSTINSTALL,COPY,DIR,c:\=C:\Dane\GitHub\wmvareappv-automation\Scripts\OLD\Packaging_improvement_tools\Get_MSI_information\,null
  #POSTINSTALL,COPY,DIR,c:\*=C:\Dane\GitHub\wmvareappv-automation\Scripts\OLD\Packaging_improvement_tools\Get_MSI_information\,null

  #POSTINSTALL,COPY,DIR,c:\*=C:\Dane\GitHub\wmvareappv-automation\Scripts\OLD\Packaging_improvement_tools\Get_MSI_information\,variable=value

	if ($line -ne " ") {
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}
	}

  $process = $True

  if ($DataType.ToLower() -ne "null") {
    if ($DataType -like "*=*") {
			$process =  Get-TestValueResult -DataType $DataType
      <# Write-Log -Message "Will test if $DataType." -Source ${CmdletName}
      $test = $DataType.Split("=")
      $originalValue = Set-StringFromVarLayered -VarToCheck $test[0]
      $testValue = Set-StringFromVarLayered -VarToCheck $test[1]

      if ($originalValue -eq $testValue) { Write-Log -Message "Will continue with programed action: $actionName." -Source ${CmdletName} }
      else {  Write-Log -Message "Test failed, will skipp programed action: $actionName." -Source ${CmdletName}; $process = $False } #>
    } else { Write-Log -Message "Test is incomplete, is missing =. Will fail." -Source ${CmdletName}; Set-Finalize -ExitCode 1 }
  }

  if ($process -eq $True) {
    If ($actionName.ToUpper() -eq "MOVE") {
      $isForce = "force"
      if (((Get-isUserName -stringToTest $Data[0]) -eq $False) -and ((Get-isAllUsers -stringToTest $Data[0]) -eq $False)) { $OldDir = Set-StringFromVarLayered -VarToCheck $Data[0] }
      else { $OldDir = $Data[0] }
      if (((Get-isUserName -stringToTest $Data[1]) -eq $False) -and ((Get-isAllUsers -stringToTest $Data[1]) -eq $False)) { $NewDir = Set-StringFromVarLayered -VarToCheck $Data[1] }
      else { $NewDir = $Data[1] }

      Write-Log -Message "Set-CopyDir -OldDir $OldDir -NewDir $NewDir." -Source ${CmdletName}
      Set-CopyDir -OldDir $OldDir -NewDir $NewDir

      Write-Log -Message "Set-RemoveDirectories -isForce $isForce -Directory $OldDir." -Source ${CmdletName}
      Set-RemoveDirectories -isForce $isForce -Directory $OldDir  
    } elseif ($actionName.ToUpper() -eq "COPY") {
      $OldDir = Set-StringFromVarLayered -VarToCheck $Data[0]

      if (((Get-isUserName -stringToTest $Data[1]) -eq $False) -and ((Get-isAllUsers -stringToTest $Data[1]) -eq $False)) { $NewDir = Set-StringFromVarLayered -VarToCheck $Data[1] }
      else { $NewDir = $Data[1] }

      Test-Directory -Directory "$OldDir"
      Write-Log -Message "Set-CopyDir -OldDir $OldDir -NewDir $NewDir." -Source ${CmdletName}
      Set-CopyDir -OldDir $OldDir -NewDir $NewDir
    } elseif ($actionName.ToUpper() -eq "REMOVE") {
      $isForce = Set-StringFromVarLayered -VarToCheck $Data[0]
      if (((Get-isUserName -stringToTest $Data[1]) -eq $False) -and ((Get-isAllUsers -stringToTest $Data[1]) -eq $False)) { $Directory = Set-StringFromVarLayered -VarToCheck $Data[1] }
      else { $Directory = $Data[1] }
      
      Write-Log -Message "Directory to remove: $Directory." -Source ${CmdletName}

      Write-Log -Message "Set-RemoveDirectories -isForce $isForce -Directory $Directory." -Source ${CmdletName}
      Set-RemoveDirectories -isForce $isForce -Directory $Directory  
    } elseif ($actionName.ToUpper() -eq "ADD") {
      if (((Get-isUserName -stringToTest $Data[0]) -eq $False) -and ((Get-isAllUsers -stringToTest $Data[0]) -eq $False)) { $Directory = Set-StringFromVarLayered -VarToCheck $Data[0] }
      else { $Directory = $Data[0] }
      
      Write-Log -Message "Directory to create: $Directory." -Source ${CmdletName}

      Set-NewFolder -Directory $Directory
    } elseif ($actionName.ToUpper() -eq "RENAME") {
      if (((Get-isUserName -stringToTest $Data[0]) -eq $False) -and ((Get-isAllUsers -stringToTest $Data[0]) -eq $False)) { $Directory = Set-StringFromVarLayered -VarToCheck $Data[0] }
      else { $Directory = $Data[0] }
      $DirectoryN = Set-StringFromVarLayered -VarToCheck $Data[1]

      Test-Directory -Directory "$Directory"
      Write-Log -Message "Rename-Item $Directory $DirectoryN" -Source ${CmdletName}

      Set-NewDirName -Directory $Directory -DirectoryN $DirectoryN
    }
  }
  if ($line -ne " ") { Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName} }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------






#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-NewDirName {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    $Directory,
    $DirectoryN,
    $isForce = $True
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  Write-Log -Message "Directory to rename: $Directory, new name: $DirectoryN." -Severity 2 -Source ${CmdletName}
  $forAllUsers =  Get-isAllUsers -stringToTest $Directory
  $forAllUsersUserName = Get-isUserName -stringToTest $Directory
  $isForce = Set-StringFromVarLayered -VarToCheck $isForce

  if (($forAllUsers -eq $False) -and ($forAllUsersUserName -eq $False)) { $Directory = Set-StringFromVarLayered -VarToCheck $Directory }

  $Directory = $Directory.trim()

  Write-Log -Message "Directory to rename: $Directory, new name: $DirectoryN." -Source ${CmdletName}

  if (($forAllUsers -eq $True) -or ($forAllUsersUserName -eq $True)) {
    if ($Global:userActions.ToLower() -eq 'false') {
      Write-Log -Message "Will skipp ${CmdletName} execution. userActions = $($Global:userActions)." -Source ${CmdletName} -Severity 3
      Write-Log -Message "For your account use an other method for actions in user context/manipulation of user profiles." -Source ${CmdletName} -Severity 3
      Return 0
    } else {
      $Users = Get-Users -forAllUsersUserName $forAllUsersUserName

      Foreach($UserData in $Users) {
        Write-Log -Message "UserData: $UserData." -Source ${CmdletName}
        $tmp = $UserData.Split(";")
        $userName = $tmp[0]
        $UserPath = $tmp[1]
        if (($Global:UserContextVar -eq "user") -and ($forAllUsersUserName -eq $True)) {
          Write-Log -Message "Will proceed for current user $userName." -Source ${CmdletName}
          $TargetDir = $Directory.Replace("%username%",$userName).Replace(" \","\").Replace("\\","\")
        } elseIf ($forAllUsers -eq $True) {
          Write-Log -Message "Will proceed for all users: user $userName." -Source ${CmdletName}
          Write-Log -Message "\User\targetDir - $($UserData[1])$targetDir" -Source ${CmdletName}
          $targetDir = "$UserPath$Directory"
          $TargetDir = $targetDir.Replace(" \","\").Replace("\\","\")
        } else {
          Write-Log -Message "Proceed with username's, users: user $userName." -Source ${CmdletName}
          $TargetDir = $Directory.Replace("%username%",$userName).Replace(" \","\").Replace("\\","\")
        }
        $prePath = split-path "$TargetDir"
        if ((-not (Test-Path $TargetDir -PathType Container)) -and (Test-Path "$prePath\$DirectoryN" -PathType Container)) { Write-Log -Message "It seems that renaming was done, skipping action now." -Source ${CmdletName} }
        else { Rename-Item "$TargetDir" "$DirectoryN" }
      }
    }
  } else {
    Write-Log -Message "Standard (not all users) remove action." -Source ${CmdletName}
    Write-Log -Message "Will validate if target dir ($Directory) is a valid path." -Source ${CmdletName}
    $prePath = split-path "$Directory"
    if ((-not (Test-Path $Directory -PathType Container)) -and (Test-Path "$prePath\$DirectoryN" -PathType Container)) { Write-Log -Message "It seems that renaming was done, skipping action now." -Source ${CmdletName} }
    else { Rename-Item "$Directory" "$DirectoryN" }
  }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-RemoveDirectories {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    $isForce,
    $Directory,
    $asterisk = 'null'
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  Write-Log -Message "Directory to remove: $Directory " -Severity 2 -Source ${CmdletName}
  $forAllUsers =  Get-isAllUsers -stringToTest $Directory
  $forAllUsersUserName = Get-isUserName -stringToTest $Directory
  $isForce = Set-StringFromVarLayered -VarToCheck $isForce
  
  if (($forAllUsers -eq $False) -and ($forAllUsersUserName -eq $False)) { $Directory = Set-StringFromVarLayered -VarToCheck $Directory }

  $Directory = $Directory.trim()
  $DirAS = Get-isAstrisk -stringToTest $Directory
  $Dir = $($DirAS[0])

  Write-Log -Message "Directory to remove: $Directory." -Source ${CmdletName}

  if (($forAllUsers -eq $True) -or ($forAllUsersUserName -eq $True)) {
    if ($Global:userActions.ToLower() -eq 'false') {
      Write-Log -Message "Will skipp ${CmdletName} execution. userActions = $($Global:userActions)." -Source ${CmdletName} -Severity 3
      Write-Log -Message "For your account use an other method for actions in user context/manipulation of user profiles." -Source ${CmdletName} -Severity 3
      Return 0
    } else {
      $Users = Get-Users -forAllUsersUserName $forAllUsersUserName

      Foreach($UserData in $Users) {
        Write-Log -Message "UserData: $UserData." -Source ${CmdletName}
        $tmp = $UserData.Split(";")
        $userName = $tmp[0]
        $UserPath = $tmp[1]
        if (($Global:UserContextVar -eq "user") -and ($forAllUsersUserName -eq $True)) {
          Write-Log -Message "Will proceed for current user $userName." -Source ${CmdletName}
          $TargetDir = $Dir.Replace("%username%",$userName).Replace(" \","\").Replace("\\","\")
        } elseIf ($forAllUsers -eq $True) {
          Write-Log -Message "Will proceed for all users: user $userName, targetDir $Dir." -Source ${CmdletName}
          Write-Log -Message "\User\targetDir - $($UserData[1])$Dir" -Source ${CmdletName}
          $targetDir = "$UserPath$Dir"
          $TargetDir = $targetDir.Replace(" \","\").Replace("\\","\")
        } else {
          Write-Log -Message "Proceed with username's, users: user $userName." -Source ${CmdletName}
          $TargetDir = $Dir.Replace("%username%",$userName).Replace(" \","\").Replace("\\","\")
        }
        Set-RemoveDir -isForce $isForce -Directory "$TargetDir" -asterisk $DirAS[1]
      }
    }
  } else {
    Write-Log -Message "Standard (not all users) remove action." -Source ${CmdletName}
    Write-Log -Message "Will validate if target dir ($Dir) is a valid path." -Source ${CmdletName}
    Set-RemoveDir -isForce $isForce -Directory "$Dir" -asterisk $DirAS[1]
  }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-NewFolder {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    $Directory
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  Write-Log -Message "Directory to create: $Directory " -Severity 2 -Source ${CmdletName}
  $forAllUsers =  Get-isAllUsers -stringToTest $Directory
  $forAllUsersUserName = Get-isUserName -stringToTest $Directory
  if (($forAllUsers -eq $False) -and ($forAllUsersUserName -eq $False)) { $Directory = Set-StringFromVarLayered -VarToCheck $Directory }

  $Directory = $Directory.trim()

  Write-Log -Message "Directory to create: $Directory." -Source ${CmdletName}

  if (($forAllUsers -eq $True) -or ($forAllUsersUserName -eq $True)) {
    if ($Global:userActions.ToLower() -eq 'false') {
      Write-Log -Message "Will skipp ${CmdletName} execution. userActions = $($Global:userActions)." -Source ${CmdletName} -Severity 3
      Write-Log -Message "For your account use an other method for actions in user context/manipulation of user profiles." -Source ${CmdletName} -Severity 3
      Return 0
    } else {
      $Users = Get-Users -forAllUsersUserName $forAllUsersUserName

      Foreach($UserData in $Users) {
        Write-Log -Message "UserData: $UserData." -Source ${CmdletName}
        $tmp = $UserData.Split(";")
        $userName = $tmp[0]
        $UserPath = $tmp[1]
        if (($Global:UserContextVar -eq "user") -and ($forAllUsersUserName -eq $True)) {
          Write-Log -Message "Will proceed for current user $userName." -Source ${CmdletName}
          $TargetDir = $Directory.Replace("%username%",$userName).Replace(" \","\").Replace("\\","\")
        } elseIf ($forAllUsers -eq $True) {
          Write-Log -Message "Will proceed for all users: user $userName." -Source ${CmdletName}
          Write-Log -Message "\User\targetDir - $($UserData[1])$Directory" -Source ${CmdletName}
          $Directory = "$UserPath$Directory"
          $TargetDir = $Directory.Replace(" \","\").Replace("\\","\")
        } else {
          Write-Log -Message "Proceed with username's, users: user $userName." -Source ${CmdletName}
          $TargetDir = $Directory.Replace("%username%",$userName).Replace(" \","\").Replace("\\","\")
        }
        if (-not(Test-Path $TargetDir -PathType Container)) { New-Item -ItemType Directory -Path $TargetDir -Force:$true | Out-Null }
      }
    }
  } else {
    Write-Log -Message "Standard (not all users) create folder action." -Source ${CmdletName}
    Write-Log -Message "Will validate if target dir ($Directory) is a valid path." -Source ${CmdletName}
    if (-not(Test-Path $Directory -PathType Container)) { New-Item -ItemType Directory -Path $Directory -Force:$true | Out-Null }
  }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Get-isAllUsers {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$stringToTest
  )
  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  Write-Log -Message "Test $stringToTest for %allusers% string." -Source ${CmdletName}
  $RC = $False
  If (($stringToTest -like "%allusers%*") -or ($stringToTest -like "*%allusers%*") -or ($stringToTest -like "*%allusers%") -or ($stringToTest -like "%allusers%")) { $RC = $True }
  If (($stringToTest.toLower() -like "%allusers%*") -or ($stringToTest.toLower() -like "*%allusers%*") -or ($stringToTest.toLower() -like "*%allusers%") -or ($stringToTest.toLower() -like "%allusers%")) { $RC = $True }
  Write-Log -Message "Will return $RC." -Source ${CmdletName}

  Return $RC
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Get-isUserName {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$stringToTest
  )
  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  Write-Log -Message "Test $stringToTest for %username% string." -Source ${CmdletName}
  $RC = $False
  If (($stringToTest -like "%username%*") -or ($stringToTest -like "*%username%*") -or ($stringToTest -like "*%username%") -or ($stringToTest -like "%username%")) { $RC = $True }
  If (($stringToTest.toLower() -like "%username%*") -or ($stringToTest.toLower() -like "*%username%*") -or ($stringToTest.toLower() -like "*%username%") -or ($stringToTest.toLower() -like "%username%")) { $RC = $True }
  Write-Log -Message "Will return $RC." -Source ${CmdletName}

  Return $RC
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Get-isAstrisk {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$stringToTest
  )
  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  Write-Log -Message "Test $stringToTest for *." -Source ${CmdletName}
  $stringToTest = $stringToTest.Replace('"','')
  $LastChar = $stringToTest.Substring($stringToTest.get_Length()-1)

  If ($LastChar -eq "\") { $Directory = $Directory.Substring(0,$Directory.Length-1); $RC = $False }
  If ($LastChar -eq "*") { $Directory = $Directory.Substring(0,$Directory.Length-1); $RC = $True }
  
  $Return = @($Directory,$RC)

  Write-Log -Message "Will return $Directory as asterisk = $RC." -Source ${CmdletName}

  Return $Return
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-Services {
  <#
    .SYNOPSIS
      It handles services, it can add new or change existing. 
    .DESCRIPTION
      Can handle a system services, configure them,change settings, create (add) new ones or remove existing ones.
    .PARAMETER actionName
      The name action type you want to trigger: ADD can be used for SERVICE.
    .PARAMETER Data
      Data variable withh all information to execute function like:
      DataServiceName=Name of the service.
      DataServiceBinary=Service binary.
      DataStartupType=Startup type of service, list: Manual, Auto, Disabled
      DataDependsOn=Dependency service name
    .PARAMETER DataType
      As default is a null for SERVICE.
    .EXAMPLE
      Conf line: INSTALL,STOP,SERVICE,EikonUpdateService=null=null,null - stop Eiokn update service.
    .EXAMPLE
      Conf line: POSTINSTALL,DISABLE,SERVICE,EikonUpdateService=null=null,null - disable Eiokn update service.
    .NOTES
      This is an internal script function and should typically not be called directly, it will be triggered by main script if proper conf line will be found.
    .LINK
      https://github.kyndryl.net/wms-global/WMSAutomationTool/
  #>
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #INSTALL,STOP,SERVICE,nazwaSerwisu=null=null,null
  #UNINSTALL,ADD,SERVICE,nazwaSerwisu=ServiceBinary=StartupType=DependsOn,null
  #INSTALL,REMOVE,SERVICE,nazwaSerwisu=null=null,null
  #POSTINSTALL,DISABLE,SERVICE,EikonUpdateService=null=null,null

	if ($line -ne " ") {
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}
	}
	
  $ServiceName = Set-StringFromVarLayered -VarToCheck $Data[0]

  Write-Log -Message "${CmdletName} = $ServiceName as $actionName." -Source ${CmdletName}

  if($actionName.ToUpper() -eq "ADD") {
    $ServiceBinary = Set-StringFromVarLayered -VarToCheck $Data[1]
    $StartupType = Set-StringFromVarLayered -VarToCheck $Data[2]
    $DependsOn = Set-StringFromVarLayered -VarToCheck $Data[3]

    if ($DependsOn -ne "null") {
      $params = @{
        Name = "$ServiceName"
        BinaryPathName = "$ServiceBinary"
        DependsOn = "$DependsOn"
        DisplayName = "$ServiceName"
        StartupType = "$StartupType"
        Description = "$ServiceName"
      }
    } else {
      $params = @{
        Name = "$ServiceName"
        BinaryPathName = "$ServiceBinary"
        DisplayName = "$ServiceName"
        StartupType = "$StartupType"
        Description = "$ServiceName"
      }
    }
    New-Service @params
  } elseif ($actionName.ToUpper() -eq "STOP") { If (Get-Service $serviceName -ErrorAction SilentlyContinue) { Get-Service -Name $ServiceName | Stop-Service -Force -PassThru }}
  elseif ($actionName.ToUpper() -eq "REMOVE") {
    if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
      Write-Log -Message "Removing: $ServiceName." -Source ${CmdletName}
      Stop-Service $ServiceName
      Get-CimInstance -ClassName Win32_Service -Filter "Name='$ServiceName'" | Remove-CimInstance
    } else { Write-Log -Message "$ServiceName is not present, nothink to remove. Going to next step." -Source ${CmdletName} }
  } elseif ($actionName.ToUpper() -eq "START") { If (Get-Service $serviceName -ErrorAction SilentlyContinue) { Get-Service -Name $ServiceName | Set-Service  -Status Running -PassThru }}
  elseif ($actionName.ToUpper() -eq "PAUSE") { If (Get-Service $serviceName -ErrorAction SilentlyContinue) {Get-Service -Name $ServiceName | Set-Service -Status Paused }}
  elseif ($actionName.ToUpper() -eq "DISABLE") { If (Get-Service $serviceName -ErrorAction SilentlyContinue) {Get-Service -Name $ServiceName | Set-Service -StartupType Disabled -PassThru }}
	
  if ($line -ne " ") { Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName} }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Get-CompareRegistry {
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " "
  )

  #PREINSTALL,CHECK,COMPREG,HKEY_LOCAL_MACHINE\SOFTWARE\Application=1.002,null
  #PREINSTALL,CHECK,COMPREG,RegPath=ValueToValidate,null

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  $Key = Set-StringFromVarLayered -VarToCheck $Data[0]
  $Key = Set-SpecialCharacters -string $Key
  $Value = Set-StringFromVarLayered -VarToCheck $Data[1]

  Write-Log -Message "Will check if key = $Key value is the same as a condition value = $Value." -Source ${CmdletName}
  $Key = Convert-RegistryPath -Key $Key

  if (Test-Path -Path $Key) {
    If ($actionName.ToUpper() -eq "CHECK") { Write-Log -Message "$Key exist, returning $True."; return $True }
    ElseIf ($actionName.ToUpper() -eq "GET") {
      $RegValue = Get-RegistryKey -Key "$Key"
      Write-Log -Message "Getting data, returning $RegValue." -Source ${CmdletName}
      return $RegValue
    }
  } else { Write-Log -Message "$Key is missing, returning $False." -Source ${CmdletName}; return $False }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Get-Registry {
  <#
    .SYNOPSIS
      It can check if registry exist or can return value from registry and compare registry value with a provided conf value.
    .DESCRIPTION
      It can check if registry exist or can return value from registry and compare registry value with a provided conf value. Return value from this function can be used for example in IF function.
    .PARAMETER actionName
      The name action type you want to trigger: ADD can be used for GETREG.
    .PARAMETER Data
      Data variable withh all information to execute function like:
      DataREGPath=Registry path.
      DataValue=Value to compare with registry value. 
    .PARAMETER DataType
      As default is a null for GETREG.
    .EXAMPLE
      Conf line: PREINSTALL,COMPARE,GETREG,HKEY_LOCAL_MACHINE\SOFTWARE\Application=Value,null - compare registry vlue with a conf value.
    .EXAMPLE
      Conf line: PREINSTALL,CHECK,GETREG,HKEY_LOCAL_MACHINE\SOFTWARE\Application,null - check if registry key exist.
    .EXAMPLE
      Conf line: PREINSTALL,GET,GETREG,HKCU\Software\Microsoft\Example,null - get registry key value.
    .NOTES
      This is an internal script function and should typically not be called directly, it will be triggered by main script if proper conf line will be found.
    .LINK
      https://github.kyndryl.net/wms-global/WMSAutomationTool/
  #>
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #PREINSTALL,COMPARE,GETREG,HKEY_LOCAL_MACHINE\SOFTWARE\Application=Value,null
  #PREINSTALL,CHECK,GETREG,HKEY_LOCAL_MACHINE\SOFTWARE\Application,null
  #PREINSTALL,GET,GETREG,HKCU\Software\Microsoft\Example,null

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
	Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}
	
  $Key = Set-StringFromVarLayered -VarToCheck $Data[0]
  $Key = Set-SpecialCharacters -string $Key

  Write-Log -Message "will check key = $Key" -Source ${CmdletName}
  $Key = Convert-RegistryPath -Key $Key

  if (Test-Path -Path $Key) {
    If ($actionName.ToUpper() -eq "CHECK") { 
			Write-Log -Message "$Key exist, returning $True."; 
			Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName};
			return $True }
    ElseIf ($actionName.ToUpper() -eq "GET") {
      $RegValue = Get-RegistryKey -Key "$Key"
      Write-Log -Message "Getting data, returning $RegValue." -Source ${CmdletName}
      return $RegValue
    }
    ElseIf ($actionName.ToUpper() -eq "COMPARE") {
      $Value = $Data[1]
      $RegValue = Get-RegistryKey -Key "$Key"
      Write-Log -Message "Getting data, returning $RegValue." -Source ${CmdletName}
      if($RegValue -eq $Value) { 
				Write-Log -Message "RegValue $RegValue = Value $Value, returning $True." -Source ${CmdletName}; 
				Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName};
				return $True }
      else { 
				Write-Log -Message "RegValue $RegValue != Value $Value, returning $False." -Source ${CmdletName}; 
				Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName};
				return $False }
    }
  } else { 
		Write-Log -Message "$Key is missing, returning $False." -Source ${CmdletName}; 
		Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName};
		return $False }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-UninstallReg {
  param(
    [Parameter(Mandatory = $True)]
    [String]$regPath,
    [Parameter(Mandatory = $False)]
    [String]$type = "key"
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  $TargetDir = $env:Temp

  Write-Log -Message "Set-UninstallReg for $regPath for $type." -Source ${CmdletName}
  
  $regPath = $regPath.Replace("`"","").Replace("'","")

  $CheckForReg = Test-Path -Path $regPath -PathType Leaf
  Write-Log -Message "Test-Path -Path $regPath -PathType Leaf = $CheckForReg" -Source ${CmdletName}

  if ($CheckForReg -eq $True) {
    $file = Get-Item -Path $regPath
    $fileName = "Uninstall_$($file.Name)"
    $TargetFile = "$TargetDir\$fileName"

    Write-Log -Message "Registry file name: $fileName in $TargetDir." -Source ${CmdletName}

    if (Test-Path -Path $TargetFile) { Remove-Item -Path $TargetFile -Force }

    Write-Log -Message "Copy-Item $regPath -Destination $TargetFile -Force." -Source ${CmdletName}
    Copy-Item $regPath -Destination $TargetFile -Force

    if (($type -eq "key") -or ($type -eq "both")) {
      $txt = [System.IO.File]::ReadAllText("$TargetFile").Replace("[HKEY","[-HKEY") 
      [System.IO.File]::WriteAllText("$TargetFile", $txt)
    }
    if (($type -eq "value") -or ($type -eq "both")) {
      $txt = [System.IO.File]::ReadAllText("$TargetFile").Replace('"=','"=-') 
      [System.IO.File]::WriteAllText("$TargetFile", $txt)
    }

    Return $TargetFile
  } else { 
    Write-Log -Message "$regPath is missing. Script failed." -Source ${CmdletName}
    Set-Finalize -ExitCode 1 
  }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Get-TestResult {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$ConditionTest
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "Processing ConditionTest: $ConditionTest." -Source ${CmdletName}
  $process = $True

  if ($ConditionTest -like "*=*") { 
		$process = Get-TestValueResult -DataType $ConditionTest

    <# $test = $DataType.Split("=")
    $originalValue = $test[0]
    $testValue = $test[1]
    if (([string]::IsNullOrWhitespace($($originalValue))) -or ([string]::IsNullOrWhitespace($($testValue)))) {
      Write-Log -Message "Test is incomplete, is missing data. Will fail." -Source ${CmdletName}
      Set-Finalize -ExitCode 1
    }

    $originalValue = Set-StringFromVarLayered -VarToCheck $originalValue
    $testValue = Set-StringFromVarLayered -VarToCheck $testValue

    if ($originalValue -eq $testValue) { Write-Log -Message "Will continue with programed action: $actionName." -Source ${CmdletName} }
    else { 
      Write-Log -Message "Test failed, will skipp programed action: $actionName." -Source ${CmdletName}
      $process = $False
    } #>
  } 

  Return $process
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-RegFileAction {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$regFilePath,
    [Parameter(Mandatory = $True)]
    [String]$actionName
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  Write-Log -Message "Provided .reg file. Will handle it from now." -Source ${CmdletName}
  if ((-not ($regFilePath -like "*%*")) -and (-not ($regFilePath -like "*:\*")) -and (-not ($regFilePath -like "\\*"))) { 
    Write-Log -Message "File without path with variables and without proper path. Will add %srcfilepath%." -Source ${CmdletName}
    $keyPath = "$Global:SourcePath\$regFilePath"
    Test-ParamFile -path $keyPath
    Write-Log -Message "New path to reg file: $keyPath." -Source ${CmdletName}
    $keyPath = """$keyPath"""
  } else { $keyPath = """$regFilePath""" }

  If ($actionName.ToUpper() -ne "REMOVE") {
    Write-Log -Message "ArgumentList: '/s', $keyPath." -Source ${CmdletName}

    $startprocessParams = @{
      FilePath     = "$Env:SystemRoot\REGEDIT.exe"
      ArgumentList = '/s', $keyPath
      Verb         = 'RunAs'
      PassThru     = $true
      Wait         = $true
    }
  } elseIf ($actionName.ToUpper() -ne "ADD") {
    if (($DataType.ToLower() -eq "key") -or ($DataType.ToLower() -eq "value") -or ($DataType.ToLower() -eq "both")) {
      Write-Log -Message "Will use $($DataType.ToLower())." -Source ${CmdletName}
      $typeVar = $DataType.ToLower()
    } else { 
      Write-Log -Message "Will set default key." -Source ${CmdletName} 
      $typeVar = "key"
    }

    Write-Log -Message "Will set uninstall .reg file based on $keyPath." -Source ${CmdletName}
    $RC = Set-UninstallReg -regPath $keyPath -type $typeVar
    $keyPath = """$RC"""
    Write-Log -Message "ArgumentList: '/s', $keyPath." -Source ${CmdletName}
    
    $startprocessParams = @{
      FilePath     = "$Env:SystemRoot\REGEDIT.exe"
      ArgumentList = '/s', $keyPath
      Verb         = 'RunAs'
      PassThru     = $true
      Wait         = $true
    }
  }

  $startprocessParams
  Write-Log -Message "Start-Process @startprocessParams" -Source ${CmdletName}
  $proc = Start-Process @startprocessParams

  if ($proc.ExitCode -eq 0) { 'Success!' }
  else { "Fail! Exit code: $($Proc.ExitCode)" }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------





#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-RegistryIterative {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $True)]
    [String]$DataType,
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #PREINSTALL,REMOVE,REGITERATIVE,Key=Value,null
  #PREINSTALL,ADD,REGITERATIVE,Key=Value,null

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  $Key = Set-StringFromVarLayered -VarToCheck $Data[0]
  $Key = Set-SpecialCharacters -string $Key
  $Key = Get-CharFromAsci -String $Key
  $Value = Set-StringFromVarLayered -VarToCheck $Data[1]
  $Value = Set-SpecialCharacters -string $Value -type "basic"
  $Value = Get-CharFromAsci -String $Value

	$Key = Set-RegPath -KeyPath $Key
  Write-Log -Message "Will $actionName iterative $Value to $Key." -Source ${CmdletName}

  if($actionName.ToUpper() -eq "ADD") { Add-RegistryEntryIterative -Value $Value -registryPath $Key } 
  elseif ($actionName.ToUpper() -eq "REMOVE") { Remove-RegistryEntryIterative -Value $Value -registryPath $Key }

  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function Add-RegistryEntryIterative {
  param (
    [Parameter(Mandatory=$true)]
    [string]$Value,
    [Parameter(Mandatory=$true)]
    [string]$registryPath
  )

  $registry = Get-ItemProperty -Path $registryPath
  $keys = $registry.PSObject.Properties | Where-Object { $_.Name -match "^\d+$" } | Select-Object -ExpandProperty Name
  $newKey = 1

  for ($i = 1; $i -le $keys.Count + 1; $i++) {
    if ($keys -notcontains $i.ToString()) {
      $newKey = $i
      break
    }
  }

  Set-ItemProperty -Path $registryPath -Name $newKey -Value $Value
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function Remove-RegistryEntryIterative {
  param (
    [Parameter(Mandatory=$true)]
    [string]$Value,
    [Parameter(Mandatory=$true)]
    [string]$registryPath
  )

  $registry = Get-ItemProperty -Path $registryPath
  $keysToRemove = $registry.PSObject.Properties | Where-Object { $_.Value -eq $Value } | Select-Object -ExpandProperty Name
  foreach ($key in $keysToRemove) { Remove-ItemProperty -Path $registryPath -Name $key }

  $reindex = 1
  $registry = Get-ItemProperty -Path $registryPath
  $keys = $registry.PSObject.Properties | Where-Object { $_.Name -match "^\d+$" } | Select-Object -ExpandProperty Name
  foreach ($key in $keys) {
    if ($key -ne $reindex) {
      $registry | Set-ItemProperty -Name $reindex -Value $registry.$key
      Remove-ItemProperty -Path $registryPath -Name $key
    }
    $reindex++
  }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-Registry {
  <#
    .SYNOPSIS
      It handles registry: imports .reg files and add, remove modify registry entry’s. 
    .DESCRIPTION
      It handles registry: imports .reg files and add, remove modify registry entry’s. This function can also handle USERS registry (even for unloaded users).
    .PARAMETER actionName
      The name action type you want to trigger: ADD, CHANGE or REMOVE can be used for REG.
    .PARAMETER Data
      Data variable withh all information to execute function like:
      DataREGPath=Registry path or .reg file path.
      DataREGVar(nullable)=Registry variable name. 
      DataREGVarType(nullable)=Registry variable type. 
      DataREGVarValue (nullable)=Registry variable value. 
      DataREGMSICpm (nullable)=MSI component name.
      DataMSIFeatureName(nullable)=MSI feature name.
    .PARAMETER DataType
      As default is a null for REG.
    .EXAMPLE
      Conf line: PREINSTALL,REMOVE,REG,HKEY_LOCAL_MACHINE\SOFTWARE=Application=Dword=1,null - remove single value from registry.
    .EXAMPLE
      Conf line: PREINSTALL,REMOVE,REG,HKEY_LOCAL_MACHINE\SOFTWARE=null=null=null,null - remove whole key from registry.
    .EXAMPLE
      Conf line: PREINSTALL,ADD,REG,HKEY_LOCAL_MACHINE\SOFTWARE=Application=Dword=1,null - add single value in registry.
    .NOTES
      This is an internal script function and should typically not be called directly, it will be triggered by main script if proper conf line will be found.
    .LINK
      https://github.kyndryl.net/wms-global/WMSAutomationTool/
  #>
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $True)]
    [String]$DataType,
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #PREINSTALL,REMOVE,REG,HKEY_LOCAL_MACHINE\SOFTWARE=Application=Dword=1,null
  #PREINSTALL,ADD,REG,HKCU\Software\Microsoft\Example=Data=Binary=(0x01,0x01,0x01,0x01,0x01,0x01,0x01),null
  #PREINSTALL,CHANGE,REG,HKCU\Software\Microsoft\Example=Data=Dword=1,null
  #PREINSTALL,CHANGE,REG,HKCU\Software\Microsoft\Example=Data=Dword=1,null;%bitness%=x64
  #PREINSTALL,ADDALL,REG,RegFileFolder,null
  #PREINSTALL,REMOVEALL,REG,RegFileFolder,null

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}
	
  Write-Log -Message "Key = $($Data[0])." -Source ${CmdletName}
  $Key = Set-StringFromVarLayered -VarToCheck $Data[0]
  $Key = Set-SpecialCharacters -string $Key
  Write-Log -Message "Key = $Key." -Source ${CmdletName}
  #$Key = $Key.Replace("|",",")
  $Name = $Data[1]
  $Type = $Data[2]
  $Value = $Data[3]

  $process = $True

  Write-Log -Message "Key - $Key." -Source ${CmdletName}
  Write-Log -Message "Name - $Name." -Source ${CmdletName}
  Write-Log -Message "Type - $Type." -Source ${CmdletName}
  Write-Log -Message "Value - $Value." -Source ${CmdletName}

  $Value = Set-SpecialCharacters -string $Value -type "basic"
  
  Write-Log -Message "Value - $Value." -Source ${CmdletName}
  Write-Log -Message "Key to $actionName is: $Key." -Source ${CmdletName}

	$Key = Set-RegPath -KeyPath $Key

  $Key = Get-CharFromAsci -String $Key
  $Name = Get-CharFromAsci -String $Name
  $Value = Get-CharFromAsci -String $Value

  Write-Log -Message "Key after transform = $Key." -Source ${CmdletName}

  if($DataType.ToLower() -eq "null") {
    $translateVar = $False
    Write-Log -Message "Set translateVar to $translateVar, DataType = $($DataType.ToLower())." -Source ${CmdletName}
  } else {
    if($DataType.ToLower() -eq "true") { $translateVar = $True }
    else {
      if ($DataType.ToLower() -like "*;*") {
        $DataTypeArr = $DataType.Split(";")
        $translate = $DataTypeArr[0]
        $test = $DataTypeArr[1]
        if($translate.ToLower() -eq "true") { $translateVar = $True }
        else {
          $translateVar = $False
          Write-Log -Message "DataType - $DataType ($translate) - variable value will not be handled." -Source ${CmdletName}
        }
        $process = Get-TestResult -ConditionTest $test
      } else { $process = Get-TestResult -ConditionTest $DataType }

      $translateVar = $False
      Write-Log -Message "DataType - $DataType - variable value will not be handled." -Source ${CmdletName}
      
    }
    Write-Log -Message "Set translateVar to $translateVar, DataType = $($DataType.ToLower())." -Source ${CmdletName}
  }

  if($process -eq $True) {
    if ($translateVar -eq $True) { 
      Write-Log -Message "Will traanslate Value = $Value." -Source ${CmdletName}
      $Value = Set-StringFromVarLayered -VarToCheck $Value 
      Write-Log -Message "New Value = $Value." -Source ${CmdletName}
    } else { Write-Log -Message "Will not translate Value." -Source ${CmdletName} }

    Write-Log -Message "Will make tests: " -Source ${CmdletName}
    Write-Log -Message "Test-ForReg -KeyPath $Key = $(Test-ForReg -KeyPath $Key) " -Source ${CmdletName}
    Write-Log -Message "$Key -like `"*%*`" = $($Key -like "*%*") " -Source ${CmdletName}
    Write-Log -Message "$Key -like `"*.reg`" = $($Key -like "*.reg") " -Source ${CmdletName}
    Write-Log -Message "$Key -like `"*:\*`" = $($Key -like "*:\*") " -Source ${CmdletName}

    $isDirectory = $True

    if ((Test-ForReg -KeyPath $Key) -eq $True) { $isDirectory = $False }
    else { 
      if (($Key -like "*%*") -or ($Key -like "*.reg")) { $isDirectory = $False } 
      elseif ($Key -like "*:\*") { $isDirectory = $True }
    }

    Write-Log -Message "isDirectory test = $isDirectory" -Source ${CmdletName}

    If ($Key.ToLower() -like "*.reg") {
      Write-Log -Message "To proceed with: Key - $Key and actionName - $actionName." -Source ${CmdletName}
      If ($actionName.ToUpper() -ne "REMOVE") { Set-RegFileAction -regFilePath $Key -actionName $actionName } 
      else { Set-RegFileAction -regFilePath $Key -actionName $actionName }
    } elseif ($isDirectory -eq $True) {
      Write-Log -Message "Get-ChildItem -Path $Key -Filter `"*.reg`"" -Source ${CmdletName}
      $RegFiles = Get-ChildItem -Path $Key -Filter "*.reg"
      ForEach ($RegFile in $RegFiles) {
        Write-Log -Message "Set-RegFileAction -regFilePath $($RegFile.FullName) -actionName $actionName" -Source ${CmdletName}
        Set-RegFileAction -regFilePath $RegFile.FullName -actionName $actionName 
      }
    } else {
      Write-Log -Message "Set-Registry will proceed with: $Key." -Source ${CmdletName}
      if (-not($Key.ToUpper() -like "GUID:*")) { $Key = Convert-RegistryPath -Key $Key }
      Write-Log -Message "Set-Registry will proceed with: $Key." -Source ${CmdletName}

      If (($actionName.ToUpper() -eq "ADD") -or ($actionName -eq "CHANGE")) {
        Write-Log -Message "------------------------------------------------------------------------" -Source ${CmdletName}
        Write-Log -Message "Will try to $actionName $Key\$Name $Type = $Value." -Source ${CmdletName}
        Write-Log -Message "------------------------------------------------------------------------" -Source ${CmdletName}

        if (((Test-Path -Path $Key) -and ($actionName -eq "CHANGE")) -or ($actionName.ToUpper() -eq "ADD")) {
					$isDefault = $false
					if (($Name.ToLower() -eq "@") -or ($Name.ToLower() -eq "(default)")) {
						Write-Log -Message "Will work on (Default) registry key." -Source ${CmdletName}
						$isDefault = $true
					}

          if (($Key -like "Registry::HKCU*") -or ($Key -like "Registry::HKEY_CURRENT_USER*") -or ($Key -like "Registry::HKEY_USERS*") -or ($Key -like "Registry::HKU*") -or ($Key -like "HKU*")) {
            Write-Log -Message "Will edit users registry." -Source ${CmdletName}

            $Key = $Key.Replace("Registry::HKCU\","")
            $Key = $Key.Replace("Registry::HKEY_CURRENT_USER\","")
            $Key = $Key.Replace("Registry::HKEY_USERS\","")
            $Key = $Key.Replace("Registry::HKU\","")

            Write-Log -Message "Reg Path = $Key." -Source ${CmdletName}
            Set-RegistryValueForAllUnloadedUsers -Name $Name -Type $Type -Value $Value -Path $Key -Action $Action
          } else {
            if (($Name -eq "null") -and ($Name -eq "null") -and ($Name -eq "null")) { Set-RegistryKey -Key $Key } #TODO check issues when path do not exist, check paths translations
            else {
              Set-RegistryKey -Key $Key
							if ($isDefault -eq $false) { $test = Test-RegValExist -Path $Key -Name $Name }
							else { $test = Test-RegValExist -Path $Key -Name '(Default)' }

              if (-not ($test)) { Write-Log -Message "Test-RegValExist -Path $Key -Name $Name = $test." -Source ${CmdletName} } 
              Else {
                Write-Log -Message "Test-RegValExist -Path $Key -Name $Name = $test." -Source ${CmdletName}
                Write-Log -Message "Registry key $key\$name exists. Removing the key." -Source ${CmdletName}

								if ($isDefault -eq $false) { Remove-RegistryKey -Key $Key -Name $Name -Recurse }
								else { Remove-RegistryKey -Key $Key -Name '(Default)' -Recurse }
                
              }

              If (($Key.ToLower() -ne "null") -and ($Name.ToLower() -ne "null") -and ($Type -ne "null") -and ($Value.ToLower() -ne "null")) {
								if ($isDefault -eq $false) { Set-RegistryKey -Key $Key -Name $Name -Type $Type -Value $Value }
								else { Set-RegistryKey -Key $Key -Name '(Default)' -Type $Type -Value $Value }
							} ElseIf (($Key.ToLower() -ne "null") -and ($Name.ToLower() -ne "null") -and ($Value.ToLower() -ne "null")) {
								if ($isDefault -eq $false) { Set-RegistryKey -Key $Key -Name $Name -Value $Value }
								else { Set-RegistryKey -Key $Key -Name '(Default)' -Value $Value } 
							} ElseIf (($Key.ToLower() -ne "null") -and ($Value.ToLower() -ne "null")) {
								if ($isDefault -eq $false) { Set-RegistryKey -Key $Key -Value $Value  }
								else { Set-RegistryKey -Key $Key -Name '(Default)' -Value $Value }
							} ElseIf (($Key.ToLower() -ne "null") -and ($Name.ToLower() -ne "null") -and ($Value.ToLower() -eq "null")) {
                Write-Log -Message "------------------------------------------------------------------------------------------------------" -Source ${CmdletName}
                Write-Log -Message "Value = $Value. Will only create empty variable." -Source ${CmdletName}
								if ($isDefault -eq $false) {
                  Write-Log -Message "Set-RegistryKey -Key $Key -Name $Name -Value `"`"" -Source ${CmdletName}
                  Set-RegistryKey -Key $Key -Name $Name -Value ""
                }
								else { Set-RegistryKey -Key $Key -Name '(Default)' -Value "" }
                Write-Log -Message "------------------------------------------------------------------------------------------------------" -Source ${CmdletName}
							} 
            }
          }
        }
      } ElseIf ($actionName.ToUpper() -eq "REMOVE") {
        if ($Key.ToUpper() -like "GUID:*") {
          Write-Log -Message "Detected GUID, will remove only Uninstall (ARP) entry." -Source ${CmdletName}
          $GUID = ($Key.ToUpper()).Replace("GUID:","")
          $GUID = Set-StringFromVarLayered -VarToCheck $GUID
          $Keyx86 = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$GUID"
          $Keyx64 = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$GUID"
            
          if(test-path -path $Keyx86) {
            Write-Log -Message "Remove-RegistryKey -Key $Keyx86." -Source ${CmdletName}
            Remove-RegistryKey -Key $Keyx86
          }
          if(test-path -path $Keyx64) {
            Write-Log -Message "Remove-RegistryKey -Key $Keyx64." -Source ${CmdletName}
            Remove-RegistryKey -Key $Keyx64
          }
        } elseif ((($Key -like "Registry::HKCU*") -or ($Key -like "Registry::HKEY_CURRENT_USER*") -or ($Key -like "Registry::HKEY_USERS*") -or ($Key -like "Registry::HKU*")) -and (-not($Key.ToUpper() -like "GUID:*"))) {
          Write-Log -Message "Will edit users registry." -Source ${CmdletName}

          $Key = $Key.Replace("Registry::HKCU\","")
          $Key = $Key.Replace("Registry::HKEY_CURRENT_USER\","")
          $Key = $Key.Replace("Registry::HKEY_USERS\","")
          $Key = $Key.Replace("Registry::HKU\","")

          Write-Log -Message "Reg Path = $Key." -Source ${CmdletName}
          Set-RegistryValueForAllUnloadedUsers -Name $Name -Type $Type -Value $Value -Path $Key -Action $Action
        } else {
          If (($Key.ToLower() -ne "null") -and ($Name.ToLower() -ne "null")) { Remove-RegistryKey -Key $Key -Name $Name -Recurse }
          else { Remove-RegistryKey -Key $Key -Recurse }
        }
      }
    }
  } else { Write-Log -Message "Action processing skipped thrue condition results." -Source ${CmdletName} }
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
<# Function Test-RegValExist($Path, $Value) {
  $ee = @() # Exception catcher

  try { Get-ItemPropertyValue -Path $Path -Name $Value | Out-Null }
  catch { $ee += $_ }

  if ( $ee.Exception.Message -match "Property $Value does not exist" ) { return $false }
  else { return $true }
} #>
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Test-RegValExist {
  param(
    [Parameter(Mandatory = $True)]
    $Path,
    [Parameter(Mandatory = $True)]
    $Name
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  $ee = @() # Exception catcher
  $RC = 'null'

  Write-Log -Message "Will check for: $Path\$Name." -Source ${CmdletName}
  Write-Log -Message "(Get-ItemProperty -Path $Path -Name $Name).$Name." -Source ${CmdletName}

  try { 
    $RC = (Get-ItemProperty -Path $Path -Name $Name).$Name
    Write-Log -Message "RC = $RC"

    if (([string]::IsNullOrEmpty($RC)) -or ([string]::IsNullOrWhiteSpace(($RC)))) { 
      Write-Log -Message "Key: $Path\$Name returns empty string." -Source ${CmdletName}
      If ((test-path -path $RC) -eq $True) {
        Write-Log -Message "Key: $Path\$Name exist. Exiting with $True" -Source ${CmdletName}
        Write-Log -Message "Key value = $RC" -Source ${CmdletName}
        return $true 
      } else {
        Write-Log -Message "Key: $Path\$Name does not exist. Exiting with $False" -Source ${CmdletName}
        return $false 
      }
    } else { 
      Write-Log -Message "Key: $Path\$Name returns string = $RC ." -Source ${CmdletName}
      Write-Log -Message "Key: $Path\$Name exist. Exiting with $True" -Source ${CmdletName}
      return $true 
    }
  } catch { $ee += $_ }

  if (($ee.Exception.Message -match "Property $Name does not exist") -or ($RC -eq 'null') -or ($ee.Exception.Message -like "*because it does not exist*") -or ([string]::IsNullOrEmpty($RC))) { 
    Write-Log -Message "Key: $Path\$Name does not exist. Exiting with $False" -Source ${CmdletName}
    return $false 
  } else { 
    Write-Log -Message "Key: $Path\$Name exist. Exiting with $True" -Source ${CmdletName}
    return $true 
  }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Get-ProcessesFromDir {  
  param(
    [Parameter(Mandatory = $True)]
    [String]$targetDir
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  Write-Log -Message "Will check for working processes from: $targetDir, and kill them." -Source ${CmdletName}

  If ((test-path -Path $targetDir) -eq $True) {
    $ProcessesList = (Get-ChildItem -Path "$targetDir" -Filter "*.exe" -Recurse).Name  
    
    foreach ($ProcessFile in $ProcessesList) {
      $ProcessFile = $ProcessFile.Replace(".exe","")
      Write-Log -Message "Found $ProcessFile, will check if can Stop, and will." -Source ${CmdletName}
      try { 
        #Get-Process -Name $ProcessFile -ErrorAction SilentlyContinue | Stop-Process -Force
				$IDs = (Get-Process -Name $ProcessFile -ErrorAction SilentlyContinue).Id
				ForEach ($ID in $IDs) {
					$cmdLine = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = '$ID'" | Select-Object commandline
					$path = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = '$ID'" | Select-Object commandline
					if (($path -eq "$targetDir\$ProcessFile.exe") -or (($cmdLine -like "$targetDir*") -or ($cmdLine -like "*$targetDir*") -or ($cmdLine -like "*$targetDir"))) { Stop-Process -Force -Id $ID }
				}
      } catch { Write-Log -Message "Cannot find process: $ProcessFile, noting to kill." -Source ${CmdletName} }
      Start-Sleep -Milliseconds 1500
    }

    Write-Log -Message "walidate if all processes are killed." -Source ${CmdletName}
    $ProcessesList = (Get-ChildItem -Path "$targetDir" -Filter "*.exe" -Recurse).Name
    foreach ($ProcessFile in $ProcessesList) {
      $ProcessFile = $ProcessFile.Replace(".exe","")
      Write-Log -Message "Found $ProcessFile, still working. Please add a kill process action before DIR removal. Automatic action cannot handle this one." -Source ${CmdletName}
    }
  } else { Write-Log -Message "$targetDir is not exest. No processes to kill. Going to next step." -Source ${CmdletName} }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Get-MSIVersion {  #TODO, is only started, need to be finished
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #INSTALL,null,MSIVersion,msifile.msi=msifile.mst=MSPFile=Cisco_CiscoMeeting_1.9.10.0_SCH_W10_EN_B1,null
  #UNINSTALL,null,MSIVersion,msifile.msi=MSTFile=MSPFile=Cisco_CiscoMeeting_1.9.10.0_SCH_W10_EN_B1,null

	if ($line -ne " ") {
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}
	}

  $MSIFile = Set-StringFromVarLayered -VarToCheck $Data[0]
  $MSTFile = Set-StringFromVarLayered -VarToCheck $Data[1]

  If (($MSTFile -eq "") -or ($MSTFile.ToLower() -eq "null") -or ($MSTFile.ToLower() -eq "mstfile")) { $Global:MSIVersionVal = Get-MsiTableProperty -Path $MSIFile -Table 'Property' | Select-Object -ExpandProperty 'ProductCode' }
  Else { $Global:MSIVersionVal = Get-MsiTableProperty -Path $MSIFile -TransformPath $MSTFile -Table 'Property' | Select-Object -ExpandProperty 'ProductCode' }

  if ($line -ne " ") { Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName} }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-ActiveSetupVal {
  <#
    .SYNOPSIS
      Can add or remove active setup. 
    .DESCRIPTION
      Can handle Active Setup creation and removal bsed on name of part of a name. Ensure that new AS will be an unique one. 
    .PARAMETER actionName
      The name action type you want to trigger: ADD or REMOVE can be used for AS.
    .PARAMETER Data
      Data variable withh all information to execute function like:
      DataASExecName=Active Setup executable path
      DataASArguments=Active Setup executable additional parameters
      DataASDescription=Active Setup description. 
      DataASREGKeyName=Active Setup registry key name. 
    .PARAMETER DataType
      As default is a null for AS.
    .EXAMPLE
      Conf line: INSTALL,ADD,AS,C:\Users\Public\Company\ProgramUserConfig.vbs=/Silent=Program User Config=ProgramUserConfig,null
    .EXAMPLE
      Conf line: UNINSTALL,REMOVE,AS,null=null=null={604F30E1-35F2-4E34-AA21-3E83CDE863E1};SAS_SASEnterpriseGuide,null
    .NOTES
      This is an internal script function and should typically not be called directly, it will be triggered by main script if proper conf line will be found.
    .LINK
      https://github.kyndryl.net/wms-global/WMSAutomationTool/
  #>
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #INSTALL,ADD,AS,C:\Users\Public\Company\ProgramUserConfig.vbs=/Silent=Program User Config=ProgramUserConfig,null
  #UNINSTALL,ADD,AS,$envWinDir\regedit.exe=/S `"%SystemDrive%\Program Files (x86)\PS App Deploy\PSAppDeployHKCUSettings.reg`"=PS App Deploy Config=PS_App_Deploy_Config,null
  #UNINSTALL,REMOVE,AS,null=null=null={604F30E1-35F2-4E34-AA21-3E83CDE863E1};SAS_SASEnterpriseGuide,null

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  $Description = Set-StringFromVarLayered -VarToCheck $Data[2]
  $Key = Set-StringFromVarLayered -VarToCheck $Data[3]
  $Key = Set-SpecialCharacters -string $Key
  $Executable = $Data[0]
  $Executable = Set-SpecialCharacters -string $Executable
  $Arguments = $Data[1]
  $Arguments = Set-SpecialCharacters -string $Arguments
  $isArray = $False

  if ($Global:userActions.ToLower() -eq 'false') { 
    Write-Log -Message "Will skipp ${CmdletName} execution. userActions = $($Global:userActions)." -Source ${CmdletName} -Severity 3
    Write-Log -Message "For your account use an other method for actions in user context/manipulation of user profiles." -Source ${CmdletName} -Severity 3 
  } else {
    If ($actionName.ToUpper() -eq "ADD") {
      $Executable = Set-StringFromVarLayered -VarToCheck $Executable

      if (($Arguments -like "*!%*") -or ($Arguments -like "!%*") -or ($Arguments -like "*!%")) { 
        Write-Log -Message "Will skipp variables translation for Arguments because !% was found." -Source ${CmdletName} 
        $Arguments = $Arguments.Replace("!%","%")
      }
      else { $Arguments = Set-StringFromVarLayered -VarToCheck $Arguments }

      if ($Arguments.ToLower() -eq "null") { $Arguments = "" }

      $ActiveSetupKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\$Key"
      $ActiveSetupKeyTest = Test-Path -Path $ActiveSetupKey

      if($ActiveSetupKeyTest -eq $True) { 
        $Version = Get-RegistryKey -Key $ActiveSetupKey -Value 'Version' 
        $Version = $Version + 1
      } else { $Version = $(get-date -f ddyHHmmss) }

      Set-ActiveSetup -StubExePath $Executable -Arguments $Arguments -Description $Description -Key $Key -Version $Version
    } Elseif ($actionName.ToUpper() -eq "REMOVE") {
      if ($Key -like "*;*") { $Keys = $Key.Split(";"); $isArray = $True }
      If ($isArray -eq $True) {
        foreach ($KeyVar in $Keys) {
          If ($KeyVar -match "\*") {
            $KeyVar = $KeyVar.replace("*","")
            Write-Log -Message "KeyVar - $KeyVar" -Source ${CmdletName}

            $Regs = Get-Item "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Active Setup\Installed Components\$KeyVar*"
            foreach($Reg in $Regs) { Write-Log -Message "***********************Remove $Reg " -Source ${CmdletName}; Remove-RegistryKey -Key $Reg -Recurse }

            $Regs = Get-Item "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\$KeyVar*"
            foreach($Reg in $Regs) { Write-Log -Message "***********************Remove $Reg " -Source ${CmdletName}; Remove-RegistryKey -Key $Reg -Recurse }
          } else { Set-ActiveSetup -Key $KeyVar -PurgeActiveSetupKey; Remove-RegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Active Setup\Installed Components\$KeyVar" -Recurse }
        }
      } else {
        If ($Key -match "\*") {
          $Key = $Key.replace("*","")
          Write-Log -Message "Key - $Key" -Source ${CmdletName}

          $Regs = Get-Item "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Active Setup\Installed Components\$Key*"
          foreach($Reg in $Regs) { Write-Log -Message "***********************Remove $Reg " -Source ${CmdletName}; Remove-RegistryKey -Key $Reg -Recurse }

          $Regs = Get-Item "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\$Key*"
          foreach($Reg in $Regs) { Write-Log -Message "***********************Remove $Reg " -Source ${CmdletName}; Remove-RegistryKey -Key $Reg -Recurse }
        } else { Set-ActiveSetup -Key $Key -PurgeActiveSetupKey; Remove-RegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Active Setup\Installed Components\$Key" -Recurse }
      }
    }
  }
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-Wait {
  <#
    .SYNOPSIS
      Will pause script execution for provided time period.  
    .DESCRIPTION
      Will stop script execution for a provided time period. default pause is set to 90s. Script canutilize time in ms (without additional unit) or in secounds if user use "s" as a unit.
    .PARAMETER actionName
      The name action type you want to trigger: ADD.
    .PARAMETER Data
      Data variable withh all information to execute function like:
      Time=Time in [s] or [ms]. If number provided without s then will be used as ms.
    .PARAMETER DataType
      As default is a null for WAIT.
    .EXAMPLE
      Conf line: INSTALL,ADD,WAIT,1000,null - will stop script execution for 1000ms.
    .EXAMPLE
      Conf line: INSTALL,ADD,WAIT,10s,null - will stop script execution for 10sec.
    .NOTES
      This is an internal script function and should typically not be called directly, it will be triggered by main script if proper conf line will be found.
    .LINK
      https://github.kyndryl.net/wms-global/WMSAutomationTool/
  #>
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #INSTALL,ADD,WAIT,1000,null
  #UNINSTALL,ADD,WAIT,2000,null

  $Time = $Data[0]
  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

	If (($Time -like "*s") -or ($Time -like "*S")) {
		$Time = $Time.Replace("s","")
		$Time = $Time.Replace("S","")
    Set-Message -Msg "Will sleep script for $Time s." -CmdletName ${CmdletName} -Severity 1
		Start-Sleep -Seconds $Time
	} else { 
    Set-Message -Msg "Will sleep script for $Time ms." -CmdletName ${CmdletName} -Severity 1
    Start-Sleep -Milliseconds $Time 
  }
  Set-Message -Msg "Resuming script." -CmdletName ${CmdletName} -Severity 1
	
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-Vars {
  <#
    .SYNOPSIS
      Will set environment or local variables.  
    .DESCRIPTION
      Can handle env variable creation or removal for Global or Local ones.  
    .PARAMETER actionName
      The name action type you want to trigger: ADD or REMOVE can be used for VAR.
    .PARAMETER Data
      Data variable withh all information to execute function like:
      DataVarType=Type of variable. List: ENV, LOC. 
      DataVarName=Name of variable.
      DataVarValue=Value of variable
      DataVarContext=Context of ENV variable. List: System, User, Process.
    .PARAMETER DataType
      As default is a null for VAR.
    .EXAMPLE
      Conf line: INSTALL,ADD,VAR,ENV=APPKEY=32423-332522-ds=user,null
    .EXAMPLE
      Conf line: INSTALL,REMOVE,VAR,ENV=APPKEY=null=user,null
    .NOTES
      This is an internal script function and should typically not be called directly, it will be triggered by main script if proper conf line will be found.
    .LINK
      https://github.kyndryl.net/wms-global/WMSAutomationTool/
  #>
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #INSTALL,ADD,VAR,type=name=value=context,null
  #UNINSTALL,IF,VAR,2000,null
  #System,User,Process

  $VarType = $Data[0]
  $VarName = $Data[1]
  $VarContext = $Data[3]
  $VarValue = Set-StringFromVarLayered -VarToCheck $Data[2]
  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  Set-Message -Msg "Name to use: $VarName." -CmdletName ${CmdletName} -Severity 1
  Set-Message -Msg "Value to use: $VarValue." -CmdletName ${CmdletName} -Severity 1

  if ($VarContext.ToLower() -eq 'system') { $VarContext = 'Machine' }
  If ($actionName.ToUpper() -eq "ADD") {
    if ($VarType.ToUpper() -eq 'ENV') {
      if ($VarName.ToUpper() -eq "PATH") {
        $pathTmp = [System.Environment]::GetEnvironmentVariable($VarName, [System.EnvironmentVariableTarget]::$VarContext) 
        Set-Message -Msg "pathTmp = $pathTmp." -CmdletName ${CmdletName} -Severity 1
        if (-not(($pathTmp -like "*$VarValue*") -or ($pathTmp -like "*$VarValue*") -or ($pathTmp -like "*$VarValue*"))) { 
          $VarValue = "$VarValue;$pathTmp" 
        } else { $VarValue = $pathTmp } 
      } 
      Set-Message -Msg "New VAR VarValue value: $VarValue" -CmdletName ${CmdletName} -Severity 1
      [System.Environment]::SetEnvironmentVariable($VarName, $VarValue, [System.EnvironmentVariableTarget]::$VarContext)
    }
    if ($VarType.ToUpper() -eq 'LOC') {
      Remove-Variable -Name $VarName -Scope "Global" -ErrorAction SilentlyContinue
      New-Variable -Name $VarName -Value $VarValue -Scope "Global"
    }
  } ElseIf ($actionName.ToUpper() -eq "REMOVE") {
    if ($VarType.ToUpper() -eq 'ENV') {
      if ($VarName.ToUpper() -eq "PATH") {
        $pathTmp = [System.Environment]::GetEnvironmentVariable($VarName, [System.EnvironmentVariableTarget]::$VarContext)
        Set-Message -Msg "pathTmp = $pathTmp." -CmdletName ${CmdletName} -Severity 1
        $VarValue = $pathTmp.Replace($VarValue,"")
        $VarValue = $VarValue.Replace(";;",";")
        if ($VarValue -like ";*") { $VarValue = $VarValue.substring(1) }
      } else { $VarValue = $null }
      Set-Message -Msg "New VAR VarValue value: $VarValue" -CmdletName ${CmdletName} -Severity 1
      [System.Environment]::SetEnvironmentVariable($VarName, $VarValue, [System.EnvironmentVariableTarget]::$VarContext)
    }
    if ($VarType.ToUpper() -eq 'LOC') { Remove-Variable -Name $VarName -Scope "Global" -ErrorAction SilentlyContinue }
  }
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
  #Update-SessionEnvironment
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-ScriptVars {
  <#
    .SYNOPSIS
      Will set additional script variables. 
    .DESCRIPTION
      Can handle env variable creation or removal for Global or Local ones in script context. SVARs are not a enviroment variables.   
    .PARAMETER actionName
      The name action type you want to trigger: ADD or REMOVE can be used for SVAR.
    .PARAMETER Data
      Data variable withh all information to execute function like:
      DataVarName=Name of variable.
      DataVarValue=Value of variable
    .PARAMETER DataType
      As default is a null for SVAR.
    .EXAMPLE
      Conf line: PREINSTALL,ADD,SVAR,RegTest1=PREINSTALL,CHECK,GETREG,HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Kofax Image Products\Ascent Capture\3.0,null
    .EXAMPLE
      Conf line: PREINSTALL,ADD,SVAR,newPath=c:\newPath,null
    .EXAMPLE
      Conf line: PREINSTALL,REMOVE,SVAR,newPath,null
    .NOTES
      This is an internal script function and should typically not be called directly, it will be triggered by main script if proper conf line will be found.
    .LINK
      https://github.kyndryl.net/wms-global/WMSAutomationTool/
  #>
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #INSTALL,ADD,SVAR,Name=Value,null
  #UNINSTALL,REMOVE,SVAR,Name,null

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  $VarValue = $Data[0]

  Write-Log -Message "Will $actionName variable $VarValue." -Source ${CmdletName}

  if($VarValue -like "*=*") { 
    $VarTmp = $VarValue.Split('=')
    $VarName = $VarTmp[0]
    $VarValue = $VarValue.Replace("$VarName=","")
    $VarValue = Set-StringFromVarLayered -VarToCheck $VarValue
  } else { $VarName = $VarValue }

  Write-Log -Message "VarName = $VarName." -Source ${CmdletName}
  Write-Log -Message "VarValue = $VarValue." -Source ${CmdletName}

  If ($actionName.ToUpper() -eq "ADD") {
    Remove-Variable -Name $VarName -Scope "Global" -ErrorAction SilentlyContinue
    Write-Log -Message "====================================" -Source ${CmdletName}
    Write-Log -Message "Adding VAR: $VarName => $VarValue" -Source ${CmdletName}
    Write-Log -Message "====================================" -Source ${CmdletName}
    New-Variable -Name $VarName -Value $VarValue -Scope "Global"
    
    $tempForValidation = Get-Variable $VarName -ErrorAction SilentlyContinue
    If (-not([string]::IsNullOrEmpty($tempForValidation))) { 
      if ($tempForValidation.Value -eq $VarValue) { Set-Message -Msg "Name $VarName, Value $VarValue was added." -CmdletName ${CmdletName} -Severity 1 } 
      else { 
        Set-Message -Msg "Name $VarName, Value $VarValue is missing." -CmdletName ${CmdletName} -Severity 3
				Write-Log -Message "============================ Failing: $line ============================" -Source ${CmdletName}
        Set-Finalize -ExitCode 1
      } 
    } else {
      Set-Message -Msg "Name $VarName, Value $VarValue is missing." -CmdletName ${CmdletName} -Severity 3
			Write-Log -Message "============================ Failing: $line ============================" -Source ${CmdletName}
      Set-Finalize -ExitCode 1
    }
  } ElseIf ($actionName.ToUpper() -eq "REMOVE") { Remove-Variable -Name $VarName -Scope "Global" -ErrorAction SilentlyContinue }
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
  #Update-SessionEnvironment
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-FontAction {
  <#
    .SYNOPSIS
      Handle installation and uninstallation of system fonts.
    .DESCRIPTION
      Can install fonts stored in directory silently or without reboot, also can uninstall fonts using data from installation directory fonts.    
    .PARAMETER actionName
      The name action type you want to trigger: ADD or REMOVE can be used for FONT.
    .PARAMETER Data
      Data variable withh all information to execute function like:
      DataFontDir =Path to directory where fonts to install are stored.
      DataReboot =Reboot or not to reboot definition, Default: noreboot. 
    .PARAMETER DataType
      As default is a null for FONT.
    .EXAMPLE
      Conf line: UNINSTALL,ADD,CERT,c:\fontstoinstall=noreboot,null
    .EXAMPLE
      Conf line: UNINSTALL,REMOVE,CERT,c:\fontstoinstall=noreboot,null
    .NOTES
      This is an internal script function and should typically not be called directly, it will be triggered by main script if proper conf line will be found.
    .LINK
      https://github.kyndryl.net/wms-global/WMSAutomationTool/
  #>
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  Write-Log -Message "Starting ${CmdletName}." -Source ${CmdletName}

  #INSTALL,ADD,FONT,Inpath=null,null
  #INSTALL,ADD,FONT,Inpath=noreboot,null

  $path = Set-StringFromVarLayered -VarToCheck $Data[0]
  $action = $Data[1]

  If ($actionName.ToUpper() -eq "ADD") {
    Write-Log -Message "Add-Font -Path $path -Action $action" -Source ${CmdletName}
    Add-Font -Path $path -Action $action
  }
  If ($actionName.ToUpper() -eq "REMOVE") {
    Write-Log -Message "Remove-Font -Path $path" -Source ${CmdletName}
    Remove-Font -Path $path
  }
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Function Set-RestartAndResume {
  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  Write-Log -Message "Starting Set-RestartAndResume - before reboot." -Source ${CmdletName}
 
  $Key      = "HKLM:\SOFTWARE\WAMP\APPS"
  $RegDir   = Convert-RegistryPath -Key "$Key"
  $PName    = $Global:PKGName
  $Value    = "True"
  $Name     = "Installed"
  $Type     = "String"

  $Key = "$Key\$PName"

  if (-not (Test-RegValExist -Path $Key -Name $Name)) { 
    Set-RegistryKey -Key $Key
        
    if (-not (Test-RegValExist -Path $Key -Name $Name)) {
      If (($Key.ToLower() -ne "null") -and ($Name.ToLower() -ne "null") -and ($Type -ne "null") -and ($Value.ToLower() -ne "null")) { Set-RegistryKey -Key $Key -Name $Name -Type $Type -Value $Value }
      ElseIf (($Key.ToLower() -ne "null") -and ($Name.ToLower() -ne "null") -and ($Value.ToLower() -ne "null")) { Set-RegistryKey -Key $Key -Name $Name -Value $Value }
      ElseIf (($Key.ToLower() -ne "null") -and ($Value.ToLower() -ne "null")) { Set-RegistryKey -Key $Key -Value $Value }
    } Else {
      Write-Log -Message "Registry key $key\$name exists. Removing the key." -Source ${CmdletName}
      Remove-RegistryKey -Key $Key -Name $Name -Recurse
      If (($Key.ToLower() -ne "null") -and ($Name.ToLower() -ne "null") -and ($Type -ne "null") -and ($Value.ToLower() -ne "null")) { Set-RegistryKey -Key $Key -Name $Name -Type $Type -Value $Value }
      ElseIf (($Key.ToLower() -ne "null") -and ($Name.ToLower() -ne "null") -and ($Value.ToLower() -ne "null")) { Set-RegistryKey -Key $Key -Name $Name -Value $Value }
      ElseIf (($Key.ToLower() -ne "null") -and ($Value.ToLower() -ne "null")) { Set-RegistryKey -Key $Key -Value $Value }
    }

    Write-Log -Message "Will reboot now." -Source ${CmdletName}
    Start-Sleep -s 3
    Write-Log -Message "shutdown /r /t 01 /d p:2:3." -Source ${CmdletName}
    shutdown /r /t 01 /d p:2:3
  } else { 
    Write-Log -Message "Registry key $key\$name exists. Removing the key." -Source ${CmdletName}
    Remove-RegistryKey -Key $Key -Name $Name -Recurse
    Remove-RegistryKey -Key $Key -Recurse
    
    $taskList = Get-ScheduledTask
    foreach ($task in $taskList) {
      $name = $task.TaskName
      if ($name -like "*$PName") {
        $taskExists = $true
        Write-Log -Message "Scheduled Task $PName found." -Source ${CmdletName}
      } 
    }

    if($taskExists) {
      Write-Log -Message "Unregister-ScheduledTask -TaskName $PName -Confirm:$false" -Source ${CmdletName}
      Unregister-ScheduledTask -TaskName $PName -Confirm:$false
    } 

    Write-Log -Message "Reboot skipped." -Source ${CmdletName}
    Start-Sleep -s 3
  }

  Write-Log -Message "Finishing Set-RestartAndResume - after reboot." -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-DotNetTools {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $True)]
    [String]$DataType,
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  Write-Log -Message "Starting ${CmdletName}." -Source ${CmdletName}

  #INSTALL,ADD,NUGET,nugetFile=params=engine,null
  #INSTALL,REMOVE,NUGET,null=engine,null
  #INSTALL,ADDSOURCE,NUGET,null,null
  #INSTALL,REMOVESOURCE,NUGET,null,null

	If ($actionName.ToUpper() -eq "ADD") {
		$name = $Data[0]
		$engine = $Data[2]

		If ($engine.ToLower() -eq "nuget") {

		} elseif (($engine.ToLower() -eq "ps") -or ($engine.ToLower() -eq "null")) {
			Install-module -Name $name -Force
		}
	}
	
	If ($actionName.ToUpper() -eq "REMOVE") {
		$name = $Data[0]
		$engine = $Data[1]

		If ($engine.ToLower() -eq "nuget") {

		} elseif (($engine.ToLower() -eq "ps") -or ($engine.ToLower() -eq "null")) {
			Remove-Module -Name $name -Force
		}
	}

	If ($actionName.ToUpper() -eq "ADDSOURCE") {
	}

	If ($actionName.ToUpper() -eq "REMOVESOURCE") {
	}
	
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-RebootAndContinue {
  <#
    .SYNOPSIS
      Action will reboot machine and continue installation after.
    .DESCRIPTION
      can set reboot, and resume installation after even without network access.     
    .PARAMETER actionName
      The name action type you want to trigger: ADD can be used for REBOOTANDCONTINUE.
    .PARAMETER Data
      Data variable withh all information to execute function like:
      DataOption =Defines if script will selfcopy to machine. Default: null. 
    .PARAMETER DataType
      As default is a null for REBOOTANDCONTINUE.
    .EXAMPLE
      Conf line: INSTALL,ADD,REBOOTANDCONTINUE,null,null
    .NOTES
      This is an internal script function and should typically not be called directly, it will be triggered by main script if proper conf line will be found.
    .LINK
      https://github.kyndryl.net/wms-global/WMSAutomationTool/
  #>
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  Write-Log -Message "Starting RebootAndContinue." -Source ${CmdletName}

  #INSTALL,ADD,REBOOTANDCONTINUE,null,null

  if ($Global:userActions.ToLower() -eq 'false') { 
    Write-Log -Message "Will skipp ${CmdletName} execution. userActions = $($Global:userActions)." -Source ${CmdletName} -Severity 3
    Write-Log -Message "For your account use an other method for actions in user context/manipulation of user profiles." -Source ${CmdletName} -Severity 3 
  } else {
    $option = $Data[0]

    $Key      = "HKLM:\SOFTWARE\WAMP\APPS"
    $RegDir   = Convert-RegistryPath -Key "$Key"
    $PName    = $Global:PKGName
    $Value    = "True"
    $Name     = "Installed"
    $Type     = "String"

    $Key = "$Key\$PName"

    if($option.ToLower() -eq "selfcopy") {
      Write-Log -Message "Selfcopy was set, will copy package to temp and set scheduled task to that patch." -Source ${CmdletName}
      $originalPath = "$Script:ParentScriptRoot"
      $newPath = "$($env:temp)\$PName"
      $scriptPath = $newPath

      if(test-path -Path $newPath) { 
        Write-Log -Message "Cleaning up: $newPath." -Source ${CmdletName}
        &cmd.exe /c rd /s /q "$newPath" 
      }

      Write-Log -Message "Xcopy /E /I /S /H /Y $originalPath $newPath." -Source ${CmdletName}
      Xcopy /E /I /S /H /Y $originalPath $newPath
    } else { 
      $scriptPath = $Script:ParentScriptRoot
    }

    If ($actionName.ToUpper() -eq "ADD") {
      if (-not(Test-RegValExist -Path $Key -Name $Name)) { 
        $executable       = "$scriptPath\Deploy-Application.exe"
        $arguments        = "-DeploymentType Install"
        $triggers         = @()
        $taskname         = "$($Global:PKGName)"
        $tNowPlus5min     = Get-Date
        $tNowPlus5min     = $tNowPlus5min.AddMinutes(5)
        $taskdescription  = "Run the package script at startup. The script should delete this scheduled task for package."

        $action           = New-ScheduledTaskAction $executable -Argument $arguments
        $Trigger1         = New-JobTrigger -AtStartUp -RandomDelay (New-TimeSpan -Minutes 1)
        $triggers         += $Trigger1

        $settings         = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 20) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 60)
        
        $taskList = Get-ScheduledTask
        foreach ($task in $taskList) {
          $name = $task.TaskName
          if ($name -like "*$taskName") {
            $taskExists = $true
            Write-Log -Message "Scheduled Task $taskName found." -Source ${CmdletName}
          } 
        }

        if($taskExists) {
          Write-Log -Message "Unregister-ScheduledTask -TaskName $taskname -Confirm:$false" -Source ${CmdletName}
          Unregister-ScheduledTask -TaskName $taskname -Confirm:$false
        } 

        Write-Log -Message "Register-ScheduledTask -Action $action -Trigger $triggers -TaskName $taskname -Description $taskdescription -Settings $settings -User System -RunLevel Highest" -Source ${CmdletName}
        Register-ScheduledTask -Action $action -Trigger $triggers -TaskName $taskname -Description $taskdescription -Settings $settings -User "System" -RunLevel Highest
      }
      Set-RestartAndResume
    }
  }
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-SelfUserTmp {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

	#POSTINSTALL,ADD,SELFUSERTMP,wrapper

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  if ($line -ne " ") { Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName} }

  $scriptPath = $Script:ParentScriptRoot
  $tmpPath = "null"

  Write-Log -Message "ScriptPath = $scriptPath." -Source ${CmdletName}
  Write-Log -Message "Starting ${CmdletName}." -Source ${CmdletName}
  Write-Log -Message "Data $Data." -Source ${CmdletName}

  $tmpName = (Get-Variable "UserTempDirPath" -Scope Global -ErrorAction 'Ignore').Name

  if ($tmpName -eq "UserTempDirPath") { 
    Write-Log -Message "UserTempDirPath = $($Global:UserTempDirPath)." -Source ${CmdletName} 
    $tmpPath = $Global:UserTempDirPath
  } else {
    Write-Log -Message "UserTempDirPath is missing." -Source ${CmdletName}
    Set-Finalize -ExitCode 1
  }

  if ((Test-Path variable:global:AppName) -eq $True) { 
    Write-Log -Message "AppName exist, will use it." -Source ${CmdletName}
    $tmpPath = $tmpPath.replace("<AppName>", $Global:AppName) 
  } else { 
    Write-Log -Message "AppName do not exist, will use ProductName." -Source ${CmdletName}
    $tmpPath = $tmpPath.replace("<AppName>", $Global:ProductName)
  }

  $tmpPath = $tmpPath.Replace("<Manufacturer>", $Global:Manufacturer)
  $tmpPath = $tmpPath.Replace("<ProductName>", $Global:ProductName)

  #[string]$configToolkitLogDir = [string]$configToolkitLogDir.Replace(" (Default)", "")
  
  if ((Test-Path variable:global:PKGBuild) -eq $True) { 
    If ($Global:PKGBuild -ne 0) { $tmpPath = $tmpPath.Replace("<AppVersion>", "$($Global:ProductVersion).$(($Global:PKGBuild)+1)") } 
    else { $tmpPath = $tmpPath.Replace("<AppVersion>", $Global:ProductVersion) }
  } else { $tmpPath = $tmpPath.Replace("<AppVersion>", $Global:ProductVersion) }
  
  $tmpPath = $tmpPath.Replace("<ProductVersion>", $Global:ProductVersion)
  $tmpPath = $tmpPath.replace("<PKGName>", $Global:PKGName)

  #$tmpPath = $tmpPath.replace(" (Default)", "")
  $tmpPath = Set-StringFromVarLayered -VarToCheck $tmpPath
  
  if ($tmpPath -eq 'null') {
    Write-Log -Message "tmpPath = null." -Source ${CmdletName}
		Write-Log -Message "============================ Failing: $line ============================" -Source ${CmdletName}
    Set-Finalize -ExitCode 1
  } else {
    If ($actionName.ToUpper() -eq "ADD") {
      If ((Test-Path -Path $tmpPath -PathType Container) -eq $False) { New-Item -Path "$tmpPath" -ItemType "directory" -Force }

      if ($Data.ToLower() -eq "wrapper") {
        $items = @("Deploy-Application_4.exe","Deploy-Application.exe","Deploy-Application.ps1","ADTConf.wamp","AppDeployToolkit")
        foreach ($item in $items) {
          $src = "$scriptPath\$item"
          $target = "$tmpPath\$item"
          $srcItem = get-item $src

          if ($srcItem.PSIsContainer) {
            Write-Log -Message "Xcopy /E /I /S /H /Y $src $target." -Source ${CmdletName}
            Xcopy /E /I /S /H /Y "$src" "$target"
          } else { 
            If ((Test-Path $target) -eq $True) { Remove-Item "$target" }
            Write-Log -Message "Copy-Item $src $tmpPath." -Source ${CmdletName}
            Copy-Item $src $tmpPath
          }
        }
      } elseif ($Data.ToLower() -eq "src") {
        $srcDir = "$scriptPath\_Source"
        $targetDir = "$tmpPath\_Source"
        Write-Log -Message "Xcopy /E /I /S /H /Y $srcDir $targetDir." -Source ${CmdletName}
        Xcopy /E /I /S /H /Y "$srcDir" "$targetDir"
      } else {
        Write-Log -Message "Xcopy /E /I /S /H /Y $scriptPath $tmpPath." -Source ${CmdletName}
        Xcopy /E /I /S /H /Y "$scriptPath" "$tmpPath"
      }
    }
    If ($actionName.ToUpper() -eq "REMOVE") {
      Write-Log -Message "Cleaning up: $tmpPath." -Source ${CmdletName}
      &cmd.exe /c rd /s /q "$tmpPath"
    }
  }
  if ($line -ne " ") { Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName} }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-SelfAS {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  Write-Log -Message "Starting ${CmdletName}." -Source ${CmdletName}

  #INSTALL,ADD,SelfAS,isSelfcopy=asName,null
  #INSTALL,REMOVE,SelfAS,isSelfcopy=asName,null

  if ($Global:userActions.ToLower() -eq 'false') { 
    Write-Log -Message "Will skipp ${CmdletName} execution. userActions = $($Global:userActions)." -Source ${CmdletName} -Severity 3
    Write-Log -Message "For your account use an other method for actions in user context/manipulation of user profiles." -Source ${CmdletName} -Severity 3 
  } else {
    $isSelfcopy = Set-StringFromVarLayered -VarToCheck $Data[0]
    $asName = Set-StringFromVarLayered -VarToCheck $Data[1]
    if ($asName.ToLower() -eq 'null') { $asName = $Global:PKGName }

    $Key = $asName
    $ActiveSetupKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\$Key"
    
    $scriptPath = $Script:ParentScriptRoot
    Write-Log -Message "scriptPath = $scriptPath." -Source ${CmdletName}

    If ($actionName.ToUpper() -eq "ADD") {
      if (($isSelfcopy.ToLower() -eq "selfcopy") -or ($isSelfcopy.ToLower() -eq "true")) {
        Write-Log -Message "Selfcopy was set, will copy package to temp and set scheduled task to that patch." -Source ${CmdletName}
        $newPath = "$($Global:KyndrylSRC)$PName"

        if(test-path -Path $newPath -PathType Container) { 
          Write-Log -Message "Cleaning up: $newPath." -Source ${CmdletName}
          &cmd.exe /c rd /s /q "$newPath" 
        }

        Write-Log -Message "Xcopy /E /I /S /H /Y $scriptPath $newPath." -Source ${CmdletName}
        Xcopy /E /I /S /H /Y "$scriptPath" "$newPath"
        $scriptPath = $newPath
      } else { $scriptPath = $Script:ParentScriptRoot }

      #"Logon"="Powershell.exe -NoProfile -ExecutionPolicy ByPass -WindowStyle Hidden -file C:\\FinalConfig\\Logon.ps1"
      $psDir = "$envWinDir\System32\WindowsPowerShell\v1.0\powershell.exe"
      $Executable = $psDir
      $Arguments = ("-ExecutionPolicy ByPass -WindowStyle Hidden -Command `"$scriptPath\Deploy-Application.ps1`" -DeploymentType Install -UserContext user").Replace("\\","\")
      $ActiveSetupKeyTest = Test-Path -Path $ActiveSetupKey
      $Description = "$($Global:PKGName) self activesetup to handle per user components."

      if($ActiveSetupKeyTest -eq $True) { 
        $Version = Get-RegistryKey -Key $ActiveSetupKey -Value 'Version' 
        $Version = $Version + 1
      } else { $Version = $(get-date -f ddyHHmmss)+$(Get-Random -Minimum 0 -Maximum 99) }

      Set-ActiveSetup -StubExePath $Executable -Arguments $Arguments -Description $Description -Key $Key -Version $Version
    }
    If ($actionName.ToUpper() -eq "REMOVE") {
      $pkdDir = "$($Global:KyndrylSRC)$PName"
      if ((test-path -Path $pkdDir -PathType Container) -eq $True) { & cmd /c "rmdir /s /q `"$pkdDir`"" }
      else { Write-Log -Message "$taskname is missing. Nothing to remove. Going next." -Source ${CmdletName} }

      If ($Key -match "\*") {
        $Key = $Key.replace("*","")
        Write-Log -Message "Key - $Key" -Source ${CmdletName}

        $Regs = Get-Item "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Active Setup\Installed Components\$Key*"
        foreach($Reg in $Regs) { Write-Log -Message "***********************Remove $Reg " -Source ${CmdletName}; Remove-RegistryKey -Key $Reg -Recurse }

        $Regs = Get-Item "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\$Key*"
        foreach($Reg in $Regs) { Write-Log -Message "***********************Remove $Reg " -Source ${CmdletName}; Remove-RegistryKey -Key $Reg -Recurse }
      } else { Set-ActiveSetup -Key $Key -PurgeActiveSetupKey; Remove-RegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Active Setup\Installed Components\$Key" -Recurse }
    }
  }
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-SelfScheduledTask {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  Write-Log -Message "Starting ${CmdletName}." -Source ${CmdletName}

  #INSTALL,ADD,SelfScheduledTask,null,null

  if ($Global:userActions.ToLower() -eq 'false') { 
    Write-Log -Message "Will skipp ${CmdletName} execution. userActions = $($Global:userActions)." -Source ${CmdletName} -Severity 3
    Write-Log -Message "For your account use an other method for actions in user context/manipulation of user profiles." -Source ${CmdletName} -Severity 3 
  } else {
    $option = $Data[0]

    #$Key      = "HKLM:\SOFTWARE\WAMP\APPS"
    #$RegDir   = Convert-RegistryPath -Key "$Key"
    $PName    = $Global:PKGName
    #$Value    = "True"
    #$Name     = "Installed"
    #$Type     = "String"

    #$Key = "$Key\$PName"

    $scriptPath = $Script:ParentScriptRoot
    Write-Log -Message "scriptPath = $scriptPath." -Source ${CmdletName}

    If ($actionName.ToUpper() -eq "ADD") {
      if($option.ToLower() -eq "selfcopy") {
        Write-Log -Message "Selfcopy was set, will copy package to temp and set scheduled task to that patch." -Source ${CmdletName}
        $newPath = "$($Global:KyndrylSRC)$PName"
    
        if(test-path -Path $newPath -PathType Container) { 
          Write-Log -Message "Cleaning up: $newPath." -Source ${CmdletName}
          &cmd.exe /c rd /s /q "$newPath" 
        }
    
        Write-Log -Message "Xcopy /E /I /S /H /Y $scriptPath $newPath." -Source ${CmdletName}
        Xcopy /E /I /S /H /Y "$scriptPath" "$newPath"
        $scriptPath = $newPath
      } else { $scriptPath = $Script:ParentScriptRoot }

      #if (-not(Test-RegValExist -Path $Key -Name $Name)) { 
        $executable       = "$scriptPath\Deploy-Application.exe"
        $arguments        = "-DeploymentType Install"
        $triggers         = @()
        $taskname         = "$($Global:PKGName)"
        $tNowPlus5min     = Get-Date
        $tNowPlus5min     = $tNowPlus5min.AddMinutes(5)
        $taskdescription  = "Run the package script at startup."

        $action           = New-ScheduledTaskAction $executable -Argument $arguments
        $Trigger1         = New-JobTrigger -AtLogon -RandomDelay (New-TimeSpan -Minutes 1)
        $triggers         += $Trigger1

        $settings         = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 20) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 60)
        $STPrin           = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Administrators" -RunLevel Highest

        $taskList = Get-ScheduledTask
        foreach ($task in $taskList) {
          $name = $task.TaskName
          if ($name -like "*$taskName") {
            $taskExists = $true
            Write-Log -Message "Scheduled Task $taskName found." -Source ${CmdletName}
          } 
        }

        if($taskExists) { Write-Log -Message "$taskname already exist. Skipping." -Source ${CmdletName} } 
        else { 
          Write-Log -Message "Register-ScheduledTask -Action $action -Trigger $triggers -TaskName $taskname -Description $taskdescription -Settings $settings -User System -RunLevel Highest" -Source ${CmdletName}
          Register-ScheduledTask -Action $action -Trigger $triggers -TaskName $taskname -Description $taskdescription -Settings $settings -Principal $STPrin #-User "Administrator" -RunLevel Highest
        }
      #}
    }
    If ($actionName.ToUpper() -eq "REMOVE") {
      $taskname = "$($Global:PKGName)"
      $taskList = Get-ScheduledTask
      foreach ($task in $taskList) {
        $name = $task.TaskName
        if ($name -like "*$taskName") {
          $taskExists = $true
          Write-Log -Message "Scheduled Task $taskName found." -Source ${CmdletName}
        } 
      }
      if($taskExists) {
        Write-Log -Message "Unregister-ScheduledTask -TaskName $taskname -Confirm:$false" -Source ${CmdletName}
        Unregister-ScheduledTask -TaskName $taskname -Confirm:$false
        $pkdDir = "$($Global:KyndrylSRC)$PName"
        if ((test-path -Path $pkdDir -PathType Container) -eq $True) { & cmd /c "rmdir /s /q `"$pkdDir`"" }
      } else { Write-Log -Message "$taskname is missing. Nothing to remove. Going next." -Source ${CmdletName}}
    }
  }
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-If {
  <#
    .SYNOPSIS
      Will create IF test and execute proper actions according to provided data. 
    .DESCRIPTION
      Will create IF test and execute proper actions according to provided data. All additional actions and data are (schould) be defined ad SVAR variables.    
    .PARAMETER actionName
      The name action type you want to trigger: ADD can be used for IF.
    .PARAMETER Data
      Data variable withh all information to execute function like:
      DataCheckName=Var with test.
      DataIfSuccess =Var name(s) for success.  If more than one, then use delimeter “;”
      DataIfFail=Var name(s) for fail.  If more than one, then use delimeter “;”
    .PARAMETER DataType
      As default is a null for IF.
    .EXAMPLE
      Conf line: PREINSTALL,ADD,IF,RegTest1=Fileaction1a;Fileaction1b;Fileaction1c=null,null
    .NOTES
      This is an internal script function and should typically not be called directly, it will be triggered by main script if proper conf line will be found.
    .LINK
      https://github.kyndryl.net/wms-global/WMSAutomationTool/
  #>
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$actionState = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #INSTALL,ADD,IF,VarCChecck,VarForTrue,VarForFalse,null

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  $VarCheck = $Data[0]
  $VarForTrue = $Data[1]
  $VarForFalse = $Data[2]

  Write-Log -Message "====================================" -Source ${CmdletName}
  Write-Log -Message "If for: VarCChecck => $VarCheck" -Source ${CmdletName}
  Write-Log -Message "If for: VarForTrue => $VarForTrue" -Source ${CmdletName}
  Write-Log -Message "If for: VarForFalse => $VarForFalse" -Source ${CmdletName}
  Write-Log -Message "====================================" -Source ${CmdletName}

  $VarCheck = (Get-Variable -Name $VarCheck).Value
  Write-Log -Message "If for: VarCChecck => $VarCheck" -Source ${CmdletName}
  $VarCheckArr = $VarCheck.Split(",")
  $DataA = $VarCheckArr[2]
  $arr = $DataA.Split("=")

  $logString = "Set-ScriptActions -actionName $actionState -Data $arr -Action "+$VarCheckArr[0]+" -Name "+$VarCheckArr[1]+" -DataType "+$VarCheckArr[3]
  Write-Log $logString -Source ${CmdletName}
  $RC = Set-ScriptActions -actionName $actionState -Data $arr -Action $VarCheckArr[0] -Name $VarCheckArr[1] -DataType $VarCheckArr[3]

  Write-Log -Message "actionState = $actionState" -Source ${CmdletName}
  Write-Log -Message "RC = $RC" -Source ${CmdletName}

  If ($RC -eq $True) {
    If ($VarForTrue.ToLower() -eq "finalizefail") { Set-Finalize -ExitCode 1 }
    If ($VarForTrue.ToLower() -eq "finalize") { Set-Finalize -ExitCode 0 }
    If ($VarForTrue.ToLower() -eq "null") { return $True }
    if (($VarForTrue -like "*;") -or ($VarForTrue -like "*;*") -or ($VarForTrue -like ";*")) {
      $VarForTrueArr = $VarForTrue.Split(";")
      foreach ($actionLine in $VarForTrueArr) {
        If ($actionLine.ToLower() -eq "finalize") { Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}; Set-Finalize -ExitCode 0 }
        $actionLine = (Get-Variable -Name $actionLine).Value
        Write-Log -Message "VarForTrue => $actionLine" -Source ${CmdletName}
        If ($actionLine.ToLower() -eq "finalize") { Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}; Set-Finalize -ExitCode 0 }
        $actionLineArr = $actionLine.Split(",")
        $DataA = $actionLineArr[2]
        $arr = $DataA.Split("=")

        $logString = "Set-ScriptActions -actionName $actionState -Data $arr -Action "+$actionLineArr[0]+" -Name "+$actionLineArr[1]+" -DataType "+$actionLineArr[3]
        Write-Log $logString -Source ${CmdletName}
        Set-ScriptActions -actionName $actionState -Data $arr -Action $actionLineArr[0] -Name $actionLineArr[1] -DataType $actionLineArr[3]
      }
    } else {
      $VarForTrue = (Get-Variable -Name $VarForTrue).Value
      If ($VarForTrue.ToLower() -eq "finalize") { Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}; Set-Finalize -ExitCode 0 }
      Write-Log -Message "VarForTrue => $VarForTrue" -Source ${CmdletName}
      $VarForTrueArr = $VarForTrue.Split(",")
      $DataA = $VarForTrueArr[2]
      $arr = $DataA.Split("=")

      $logString = "Set-ScriptActions -actionName $actionState -Data $arr -Action "+$VarForTrueArr[0]+" -Name "+$VarForTrueArr[1]+" -DataType "+$VarForTrueArr[3]
      Write-Log $logString -Source ${CmdletName}
      Set-ScriptActions -actionName $actionState -Data $arr -Action $VarForTrueArr[0] -Name $VarForTrueArr[1] -DataType $VarForTrueArr[3]
    }
  } elseif ($RC -eq $False) {
    Write-Log "Will perform action: $($VarForFalse.ToLower()). " -Source ${CmdletName}
    If ($VarForFalse.ToLower() -eq "finalizefail") { Write-Log -Message "============================ Failing: $line ============================" -Source ${CmdletName}; Set-Finalize -ExitCode 1 }
    If ($VarForFalse.ToLower() -eq "finalize") { Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}; Set-Finalize -ExitCode 0 }
    If ($VarForFalse.ToLower() -eq "null") { return $True }
    if (($VarForFalse -like "*;") -or ($VarForFalse -like "*;*") -or ($VarForFalse -like ";*")) {
      $VarForFalseArr = $VarForFalse.Split(";")
      foreach ($actionLine in $VarForFalseArr) {
        If ($actionLine.ToLower() -eq "finalize") { Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}; Set-Finalize -ExitCode 0 }
        $actionLine = (Get-Variable -Name $actionLine).Value
        Write-Log -Message "VarForFalse => $actionLine" -Source ${CmdletName}
        If ($actionLine.ToLower() -eq "finalize") { Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}; Set-Finalize -ExitCode 0 }
        $actionLineArr = $actionLine.Split(",")
        $DataA = $actionLineArr[2]
        $arr = $DataA.Split("=")

        $logString = "Set-ScriptActions -actionName $actionState -Data $arr -Action "+$actionLineArr[0]+" -Name "+$actionLineArr[1]+" -DataType "+$actionLineArr[3]
        Write-Log $logString -Source ${CmdletName}
        Set-ScriptActions -actionName $actionState -Data $arr -Action $actionLineArr[0] -Name $actionLineArr[1] -DataType $actionLineArr[3]
      }
    } else {
      $VarForFalse = (Get-Variable -Name $VarForFalse).Value
      If ($VarForFalse.ToLower() -eq "finalizefail") { Write-Log -Message "============================ Failing: $line ============================" -Source ${CmdletName}; Set-Finalize -ExitCode 1 }
      If ($VarForFalse.ToLower() -eq "finalize") { Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}; Set-Finalize -ExitCode 0 }
      Write-Log -Message "VarForFalse => $VarForFalse" -Source ${CmdletName}
      $VarForFalseArr = $VarForFalse.Split(",")
      $DataA = $VarForFalseArr[2]
      $arr = $DataA.Split("=")

      $logString = "Set-ScriptActions -actionName $actionState -Data $arr -Action "+$VarForFalseArr[0]+" -Name "+$VarForFalseArr[1]+" -DataType "+$VarForFalseArr[3]
      Write-Log $logString -Source ${CmdletName}
      Set-ScriptActions -actionName $actionState -Data $arr -Action $VarForFalseArr[0] -Name $VarForFalseArr[1] -DataType $VarForFalseArr[3]
    }
  }
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Import-CertificateA  {
  [cmdletbinding(SupportsShouldProcess=$True)]
  Param (
    [parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
    [Alias('PSComputername','__Server','IPAddress')]
    [string[]]$Computername =   $env:COMPUTERNAME,
    [parameter(Mandatory=$True)]
    [string]$Certificate,
    #[System.Security.Cryptography.X509Certificates.StoreName]$StoreName = 'Root',
    $StoreName = 'Root',
    [System.Security.Cryptography.X509Certificates.StoreLocation]$StoreLocation  = 'LocalMachine',
		[parameter(Mandatory=$True)]
    [string]$Pass
  )

  #-Password (ConvertTo-SecureString -String '12345' -AsPlainText -Force)
	if ($Certificate -like "*.pfx") {
		if (($Pass -ne " ") -and ($Pass -ne "null")) {
			Import-PfxCertificate -FilePath "$Certificate" -Password (ConvertTo-SecureString -String $Pass -AsPlainText -Force) -CertStoreLocation "Cert:\$StoreLocation\$StoreName"
		} else { Import-PfxCertificate -FilePath "$Certificate" -CertStoreLocation "Cert:\$StoreLocation\$StoreName" }
	} else {
		Import-Certificate -FilePath "$Certificate" -CertStoreLocation "Cert:\$StoreLocation\$StoreName"
	}

  Write-Log -Message "Import-Certificate -FilePath $Certificate -CertStoreLocation Cert:\$StoreLocation\$StoreName" -Source ${CmdletName}
  Write-Log -Message "Will validate if certyficate was imported properly using $Certificate Thumbprint." -Source ${CmdletName}

  $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $Certificate
  $Thumbprint = $cert.Thumbprint

  Write-Log -Message "$Certificate Thumbprint = $Thumbprint." -Source ${CmdletName}

  $RC = Get-ChildItem -Path "Cert:\$StoreLocation\$StoreName" | Where-Object {$_.Thumbprint -eq $Thumbprint}

  if ([string]::IsNullOrEmpty($RC)) {
    Write-Log -Message "$Certificate = $Thumbprint is missing. Execution failed." -Source ${CmdletName}
    Set-Finalize -ExitCode 1
  } { Write-Log -Message "$Certificate = $Thumbprint was successfully imported." -Source ${CmdletName} }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-Certyficate {
  <#
    .SYNOPSIS
      Will install certyficate in proper cert store. Can also remove existing certyficate.
    .DESCRIPTION
      Will install certyficate in proper cert store. Can also remove existing certyficate. 
    .PARAMETER actionName
      The name action type you want to trigger: ADD or REMOVE can be used for CERT.
    .PARAMETER Data
      Data variable withh all information to execute function like:
      DataCertFile=Path to .cer file.
      DataStoreName=Target Store Name. 
      DataStoreLocation=Where Store is located, Default LocalMachine. 
      DataComputerName=Machine name when certificate will be added, Default: local machine hostname.  
    .PARAMETER DataType
      As default is a null for CERT.
    .EXAMPLE
      Conf line: UNINSTALL,REMOVE,CERT,Thumbprint=StoreName=StoreLocation=ComputerName,null
    .EXAMPLE
      Conf line: UNINSTALL,ADD,CERT,vendor.crt=MY=null= null,null
    .NOTES
      This is an internal script function and should typically not be called directly, it will be triggered by main script if proper conf line will be found.
    .LINK
      https://github.kyndryl.net/wms-global/WMSAutomationTool/
  #>
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$DataType = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #UNINSTALL,ADD,CERT,CertFile=StoreName=StoreLocation=ComputerName,null
  #UNINSTALL,REMOVE,CERT,Thumbprint=StoreName=StoreLocation=ComputerName,null
  #UNINSTALL,REMOVE,CERT,CertFile=StoreName=StoreLocation=ComputerName,null
  #UNINSTALL,RENAME,CERT,CertFile/Thumbprint=StoreName=StoreLocation=NewName,null
  
  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  $StoreName = Set-StringFromVarLayered -VarToCheck $Data[1]
  $StoreLocation = Set-StringFromVarLayered -VarToCheck $Data[2]
  $ComputerName = Set-StringFromVarLayered -VarToCheck $Data[3]

  if ($StoreName.ToLower() -eq 'null') { $StoreName = 'Root' }
  if ($Computername.ToLower() -eq 'null') { $Computername = $env:COMPUTERNAME }
  if ($StoreLocation.ToLower() -eq 'null') { $StoreLocation = 'LocalMachine' }
  
  If ($actionName.ToUpper() -eq "ADD") {
    $CertFile = Set-StringFromVarLayered -VarToCheck $Data[0]
    #$CertFile = Set-StringFromVarLayered -VarToCheck $CertFile

    Write-Log -Message "Will try to ADD certyficate: $CertFile." -Source ${CmdletName};
    
    if ($CertFile.ToLower() -eq 'null') { Write-Log -Message "No cert, exiting script with RC = -1."; Set-Finalize -ExitCode -1  } 
    elseif ((Test-path -path $CertFile) -eq $False) { 
			Write-Log -Message "$CertFile is missing, exiting script with RC = -1."; 
			Write-Log -Message "============================ Failing: $line ============================" -Source ${CmdletName}
			Set-Finalize -ExitCode -1 
		}

    Write-Log -Message "Import-CertificateA -Certificate $CertFile -StoreName $StoreName -StoreLocation $StoreLocation -ComputerName $ComputerName." -Source ${CmdletName};
    Import-CertificateA -Certificate $CertFile -StoreName $StoreName -StoreLocation $StoreLocation -ComputerName $ComputerName -Pass $DataType
  }
  If ($actionName.ToUpper() -eq "REMOVE") {
    $Thumbprint = Set-StringFromVarLayered -VarToCheck $Data[0]

    Write-Log -Message "Will try to REMOVE certyficate: $Thumbprint." -Source ${CmdletName};

    if ($Thumbprint.ToLower() -eq 'null') { 
			Write-Log -Message "No Thumbprint, exiting script with RC = -1."; 
			Write-Log -Message "============================ Failing: $line ============================" -Source ${CmdletName}
			Set-Finalize -ExitCode -1 
		} else {
      if (($Thumbprint -like "*.cer") -or ($Thumbprint -like "*.crt")) { 
        #$Thumbprint = Set-StringFromVarLayered -VarToCheck $Thumbprint
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $Thumbprint
        $Thumbprint = $cert.Thumbprint
      } else {
				$element = Get-ChildItem Cert:\$StoreLocation\$StoreName\$Thumbprint

				if ([string]::IsNullOrWhitespace($element)) {
					$certSubject = $Thumbprint
					$certs = Get-ChildItem -path Cert:\* -Recurse | Where-Object {$_.Subject -like "*$certSubject"}
					Foreach ($cert in $certs) {
						$Thumbprint = $cert.thumbprint
						Write-Log -Message "Get-ChildItem Cert:\$StoreLocation\$StoreName\$Thumbprint | Remove-Item." -Source ${CmdletName};
						Get-ChildItem Cert:\$StoreLocation\$StoreName\$Thumbprint | Remove-Item;
					}
				}
			}

			Write-Log -Message "Get-ChildItem Cert:\$StoreLocation\$StoreName\$Thumbprint | Remove-Item." -Source ${CmdletName};
			Get-ChildItem Cert:\$StoreLocation\$StoreName\$Thumbprint | Remove-Item;
    }
  }
  If ($actionName.ToUpper() -eq "RENAME") {
    $Thumbprint = Set-StringFromVarLayered -VarToCheck $Data[0]
    $CertName = Set-StringFromVarLayered -VarToCheck $Data[3]
    
    if ($Thumbprint.ToLower() -eq 'null') { 
			Write-Log -Message "No Thumbprint, exiting script with RC = -1."; 
			Write-Log -Message "============================ Failing: $line ============================" -Source ${CmdletName}
			Set-Finalize -ExitCode -1 
		} else {
      if($Thumbprint -like "*.cer") { 
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $Thumbprint
        $Thumbprint = $cert.Thumbprint
      }
    }

    Write-Log -Message "Will try to rename cert: Cert:\$StoreLocation\$StoreName\$Thumbprint to: $CertName." -Source ${CmdletName};
    (Get-ChildItem -Path "Cert:\$StoreLocation\$StoreName\$Thumbprint").FriendlyName = "$CertName"
  }
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Get-fileByName {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    $dir,
    [Parameter(Mandatory = $True)]
    $ext,
    [Parameter(Mandatory = $True)]
    $name
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  
  $filesList = Get-ChildItem -Path $dir -Filter *.$ext

  if ($filesList) {
    foreach ($policyFile in $filesList) {
      $filePath = $policyFile.FullName
      $fileName = $policyFile.Name
      if (($fileName -like "$name*") -or ($fileName -eq "$name") -or ($fileName -like "*$name*")) {
        Write-Log -Message "Found: $filePath" -Source ${CmdletName};
        Return $filePath
      }
    }
  }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-Policy {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #UNINSTALL,ADD,POLICY,polDir=polFile,null
  
  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  $polDir = Set-StringFromVarLayered -VarToCheck $Data[0]
  $polFile = Set-StringFromVarLayered -VarToCheck $Data[1]

  $LGPOLocBin = "LGPO_30\LGPO.exe"
  $LGPOPathLoc = "$scriptDirectory\AppDeployToolkit\$LGPOLocBin"

  Write-Log -Message "Will proceed with: polDir - $polDir, polFile - $polFile." -Source ${CmdletName}; 

  if ($polDir.ToLower() -eq 'null') { $polDir = $Global:SourcePath }
  $txtFileS = Get-fileByName -dir $polDir -ext "txt" -name $polFile
  $polFileS = Get-fileByName -dir $polDir -ext "pol" -name $polFile

  if ((($txtFileS -eq "null") -or ([string]::IsNullOrWhitespace($txtFileS))) -and (($polFileS -eq "null") -or ([string]::IsNullOrWhitespace($polFileS)))) { 
		Write-Log -Message "No files to proceed with." -Source ${CmdletName}; 
		Write-Log -Message "============================ Failing: $line ============================" -Source ${CmdletName}
		Set-Finalize -ExitCode 1 
	} else {
    if ((Test-Path -path $LGPOPathLoc -PathType Leaf) -eq $True) { 
      if (($txtFileS -ne "null") -and (-not([string]::IsNullOrWhitespace($txtFileS)))) {
        if ((Test-Path -path "$Global:TempDirPath" -PathType Container) -eq $False) { New-Item -Path "$Global:TempDirPath" -ItemType "directory" -Force }
        $newPolFile = "$Global:TempDirPath\$polFile.pol"
        Write-Log -Message "Start-Process -NoNewWindow -Wait -PassThru $LGPOPathLoc -ArgumentList `"/r $txtFileS /w $newPolFile`"" -Source ${CmdletName}; 
        $proc = Start-Process -NoNewWindow -Wait -PassThru $LGPOPathLoc -ArgumentList "/r `"$txtFileS`" /w `"$newPolFile`""
        $proc.WaitForExit()
        Write-Log -Message "LASTEXITCODE - $LASTEXITCODE" -Source ${CmdletName};
      }
      if (($polFileS -eq "null") -or (([string]::IsNullOrWhitespace($polFileS)) -or ([string]::IsNullOrEmpty($polFileS)))) { $polFileS = "$Global:TempDirPath\$polFile.pol" }
      Write-Log -Message "Start-Process -NoNewWindow -Wait -PassThru $LGPOPathLoc -ArgumentList `"/m $polFileS`"" -Source ${CmdletName}; 
      $proc = Start-Process -NoNewWindow -Wait -PassThru $LGPOPathLoc -ArgumentList "/m `"$polFileS`""
      $proc.WaitForExit()
      Write-Log -Message "LASTEXITCODE - $LASTEXITCODE" -Source ${CmdletName};
    } else { Write-Log -Message "LGPO.exe is not accessible or not available for this account. Please handle policy using GPO." -Source ${CmdletName}; }
  }
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-MSIX {
  <#
    .SYNOPSIS
      Will handle msix installation, uninstallation, and settings.
    .DESCRIPTION
      Will handle msix installation, uninstallation, and settings like: run command in package context, change drive and other   
    .PARAMETER actionName
      The name action type you want to trigger: ADD, MOVE, RUN or REMOVE can be used for MSIX.
    .PARAMETER Data
      Data variable withh all information to execute function like:
      DataMSIXFile=Path to msix file.  
      DataMSIXName=Imported msix package name.
      DataMSIXContext=Imported msix package context.
      DataVolumeName=New drive letter (where to move package).
      DataAppID=Appicaion ID.
      DataCMDToRun=Custom CMD to run in msix package context.
    .PARAMETER DataType
      As default is a null for MSIX.
    .EXAMPLE
      Conf line: INSTALL,ADD,MSIX,MSIXFile,null
    .EXAMPLE
      Conf line: UNINSTALL,REMOVE,MSIX,MSIXName=MSIXContext,null
    .NOTES
      This is an internal script function and should typically not be called directly, it will be triggered by main script if proper conf line will be found.
    .LINK
      https://github.kyndryl.net/wms-global/WMSAutomationTool/
  #>
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #INSTALL,ADD,MSIX,MSIXFile,null
  #UNINSTALL,REMOVE,MSIX,MSIXName=MSIXContext,null
  #POSTINSTALL,MOVE,MSIX,MSIXName=VolumeName,null
  #POSTINSTALL,RUN,MSIX,MSIXName=AppID=CMDToRun,null /run command in package context

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  If ($actionName.ToUpper() -eq "ADD") {
    $MSIXFile = Set-StringFromVarLayered -VarToCheck $Data[0]
    Write-Log -Message "Will $actionName $MSIXFile." -Source ${CmdletName};

    $MSIXFile = Get-FullPath -path $MSIXFile
    #if ((-not ($MSIXFile -like "*%*")) -and (-not ($MSIXFile -like "*:\*")) -and (-not ($MSIXFile -like "\\*"))) { $MSIXFile = "$Global:SourcePath\$MSIXFile" }
    #else { $MSIXFile = "$MSIXFile" }

    Test-ParamFile -path "$MSIXFile"
    Add-AppPackage -path "$MSIXFile"
  } ElseIf ($actionName.ToUpper() -eq "REMOVE"){
    $MSIXName = Set-StringFromVarLayered -VarToCheck $Data[0]
    $MSIXContext = Set-StringFromVarLayered -VarToCheck $Data[1]
    Write-Log -Message "Will $actionName $MSIXName - $MSIXContext." -Source ${CmdletName};

    if (($MSIXContext -eq "null") -or ([string]::IsNullOrEmpty($MSIXContext))) { Remove-AppPackage -Package $MSIXName }
    else { Remove-AppPackage -Package $MSIXName $MSIXContext }
  } ElseIf ($actionName.ToUpper() -eq "MOVE"){
    $MSIXName = Set-StringFromVarLayered -VarToCheck $Data[0]
    $VolumeName = Set-StringFromVarLayered -VarToCheck $Data[1]

    Write-Log -Message "Will $actionName $MSIXName to $VolumeName." -Source ${CmdletName};
    Move-AppPackage -Package $MSIXName -Volume $VolumeName
  } ElseIf ($actionName.ToUpper() -eq "RUN"){
    $MSIXName = Set-StringFromVarLayered -VarToCheck $Data[0]
    $AppID = Set-StringFromVarLayered -VarToCheck $Data[1]
    $CMDToRun = Set-StringFromVarLayered -VarToCheck $Data[2]

    Write-Log -Message "Will $CMDToRun inside $MSIXName ($AppID)." -Source ${CmdletName};
    Invoke-CommandInDesktopPackage -PackageFamilyName $MSIXName -appid $AppID -command $CMDToRun -preventbreakaway
  }
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}

  #Move-AppPackage -Package "Caphyon.MyApp_1.0.0.0_neutral__8wekyb3d8bbwe" -Volume E:\
  #To dismount a volume you can use Dismount-AppVolume -Volume E:\
  #To remove a volume use Remove-AppVolume -Volume E:\
  #Invoke-CommandInDesktopPackage -PackageFamilyName "Caphyon.SampleMSIXPackage_r21n0w1rc5s2y" -appid "SampleMSIXPackage" -command "cmd.exe" -preventbreakaway
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-FastKillProcesses {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$processes
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "Will handle processes: $processes." -Source ${CmdletName}

  if ($processes.ToLower() -ne 'null') {
    if ($processes -like "*;*") { $ProcessesList = $processes.Split(";") }
    else { $ProcessesList = @($processes) }

    foreach ($ProcName in $ProcessesList) {
      $killProcess = Get-Process -Name "$ProcName" -ErrorAction SilentlyContinue

      If ($killProcess) {
        Write-Log -Message "Will kill process: $ProcName." -Source ${CmdletName}
        Stop-Process -Name "$ProcName" -Force
      } else { Write-Log -Message "Process: $ProcName is not active, will go next." -Source ${CmdletName} }
    }
  }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-APPXIfInstalled {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$appName,
    [Parameter(Mandatory = $True)]
    [String]$appID,
    [Parameter(Mandatory = $True)]
    [String]$appVersion,
    [Parameter(Mandatory = $False)]
    [String]$isForce = $True

  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "Will check if $appName is installed and handle versioning." -Source ${CmdletName}

  $install = $true
  $AllInstalled = Get-AppxPackage | Where-Object { $_.PackageFullName.Contains("$appName") }

  if ($AllInstalled) {
    Foreach ($installed in $AllInstalled) {
      Write-Log -Message "Will compare versions: $([System.Version]$appVersion) -to $([System.Version]$installed.Version)." -Source ${CmdletName}
      Write-Log -Message "PackageFamilyName $($installed.PackageFamilyName)." -Source ${CmdletName}
      if ($installed.PackageFamilyName -eq $appID) { Write-Log -Message "$fileName already installed. Noting todo." -Source ${CmdletName}; $install = $false }
      else {
        if ([System.Version]$appVersion -eq [System.Version]$installed.Version) { Write-Log -Message "$fileName already installed. Noting todo." -Source ${CmdletName}; $install = $false }
        else { 
          if ([System.Version]$appVersion -gt [System.Version]$installed.Version) { Write-Log -Message "$fileName already installed, but have bigger version. Will downgrade it." -Source ${CmdletName} } 
          elseif ([System.Version]$appVersion -lt [System.Version]$installed.Version) { Write-Log -Message "$fileName already installed, but have lower version. Will upgrade it." -Source ${CmdletName} }
          if ($isForce -eq $True) {
            Write-Log -Message "Remove-AppxPackage -Package `"$($installed.PackageFullName)`"-ErrorAction Stop | Out-Null" -Source ${CmdletName}; 
            Remove-AppxPackage -Package $($installed.PackageFullName) -ErrorAction Stop | Out-Null
          }
          $install = $true
          #Remove-AppxProvisionedPackage -Online -PackageName $installed.PackageFullName -AllUsers -LogPath "$($Global:PreLogDir)\U_$($installed.PackageFullName).log" -ErrorAction Stop | Out-Null
        }
      }
    }
  } else { Write-Log -Message "$appName not yet installed." -Source ${CmdletName} }

  Return $install
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-APPXDepedency {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$appName,
    [Parameter(Mandatory = $True)]
    [String]$appID,
    [Parameter(Mandatory = $True)]
    [String]$appVersion,
    [Parameter(Mandatory = $True)]
    [String]$appPath
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "Will handle: $appName." -Source ${CmdletName}

  If ((Set-APPXIfInstalled -appName $appName -appID $appID -appVersion $appVersion -isForce $false) -eq $True) {
    Write-Log -Message "Will install $appID." -Source ${CmdletName};
    #Write-Log -Message "Add-AppxProvisionedPackage -Online -PackagePath `"$appPath`" -SkipLicense -LogPath `"$($Global:PreLogDir)\I_$($appName)_$($appVersion).log`" -ErrorAction Stop | Out-Null ." -Source ${CmdletName};
    #Add-AppxProvisionedPackage -Online -PackagePath "$appPath" -SkipLicense -LogPath "$($Global:PreLogDir)\I_$($appName)_$($appVersion).log" -ErrorAction Stop | Out-Null
    Write-Log -Message "Add-AppxPackage -Path `"$appPath`" -ForceTargetApplicationShutdown -ForceUpdateFromAnyVersion -InstallAllResources." -Source ${CmdletName};
    Add-AppxPackage -Path "$appPath" -ForceTargetApplicationShutdown -ForceUpdateFromAnyVersion -InstallAllResources
  } else { Write-Log -Message "$appID is already installed." -Source ${CmdletName}; }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-APPX {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #INSTALL,ADD,APPX,APPXDir=APPXFiles=ProcessName=DependencyPackagePath,null
  #UNINSTALL,REMOVE,APPX,APPXName=ProcessName,null

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  If ($actionName.ToUpper() -eq "ADD") {
    $APPXDir = Set-StringFromVarLayered -VarToCheck $Data[0]
    $APPXFilesTmp = Set-StringFromVarLayered -VarToCheck $Data[1]
    $ProcessName = Set-StringFromVarLayered -VarToCheck $Data[2]
    $Dependency = Set-StringFromVarLayered -VarToCheck $Data[3]
    $Dependency = Set-SpecialCharacters -string $Dependency

    if ($ProcessName.ToLower() -eq "null") { Write-Log -Message "There are no processes to kill, will proceed with installation." -Source ${CmdletName};  } 
    else { 
      Write-Log -Message "Will kill processes: $ProcessName." -Source ${CmdletName};
      Set-FastKillProcesses -processes $ProcessName 
    }

    if ($APPXDir.toLower() -eq 'null') { $APPXDir = $Global:SourcePath }

    $appxExist = $False

    Write-Log -Message "Will search for files in: $APPXDir." -Source ${CmdletName};
    $APPXFiles = Get-ChildItem -Path $APPXDir -File

    if ($APPXFilesTmp.ToLower() -eq "null") {
      Write-Log -Message "APPXFiles variable is empty." -Source ${CmdletName}; 
      Write-Log -Message "============================ Failing: $line ============================" -Source ${CmdletName}
      Set-Finalize -ExitCode 1
    } else {
      ForEach ($Appx in $APPXFiles) {
        Write-Log -Message "Got [$($Appx.Name)] and will compare with [$APPXFilesTmp]." -Source ${CmdletName};
        if ($Appx.Name -eq "$APPXFilesTmp") {
          Write-Log -Message "$($Appx.FullName) exist and is accesible." -Source ${CmdletName};
          $appxExist = $True
          $AppxPath = $Appx.FullName
          break
        }
      }

      if ($appxExist -eq $False) {
        Write-Log -Message "$APPXFilesTmp is missing." -Source ${CmdletName}; 
        Write-Log -Message "============================ Failing: $line ============================" -Source ${CmdletName}
        Set-Finalize -ExitCode 1
      } else {
        $sourceFilePath = $AppxPath
        $appName = ($APPXFilesTmp.Split("_"))[0]
        $appVersion = (($APPXFilesTmp.Split("_"))[1]).Replace(".appxbundle","").Replace(".AppxBundle","").Replace(".appx","").Replace(".Appx","")
        $appID = $APPXFilesTmp.Replace(".appxbundle","").Replace(".AppxBundle","").Replace(".appx","").Replace(".Appx","")
        $AllInstalled = Get-AppxPackage | Where-Object { $_.PackageFullName.Contains("$appName") }
        $install = $true
      }
    }

    $install = Set-APPXIfInstalled -appName $appName -appID $appID -appVersion $appVersion

    if ($install -eq $True) {
      try {
        if ($Dependency.ToLower() -ne "null") {
          if ($Dependency -like "*,*") { $DependencyFiles = $Dependency.Split(",") }
          else { $DependencyFiles = $Dependency }
          Write-Output "Before main package will handle all dependency."
          
          ForEach ($DependencyFile in $DependencyFiles) {
            $DependencyFile = $DependencyFile.Replace("'","").Replace('"','')
            $filepath = Get-ChildItem "$DependencyFile"
            $depName = ($($filepath.Name).Split("_"))[0]
            $depVersion = ($($filepath.Name).Split("_"))[1]
            $depID = $($filepath.Name).Replace(".appx","").Replace(".Appx","")
            Set-APPXDepedency -appName $depName -appID $depID -appVersion $depVersion -appPath $DependencyFile
          }

          Write-Log -Message "Add-AppxPackage -Path `"$sourceFilePath`" -ForceTargetApplicationShutdown -ForceUpdateFromAnyVersion -InstallAllResources." -Source ${CmdletName};
          Add-AppxPackage -Path "$sourceFilePath" -ForceTargetApplicationShutdown -ForceUpdateFromAnyVersion -InstallAllResources
        } else {
          #Write-Log -Message "Add-AppxProvisionedPackage -Online -PackagePath `"$sourceFilePath`" -SkipLicense -LogPath `"$($Global:PreLogDir)\I_$($appName)_$($appVersion).log`" -ErrorAction Stop | Out-Null ." -Source ${CmdletName};
          #Add-AppxProvisionedPackage -Online -PackagePath "$sourceFilePath" -SkipLicense -LogPath `"$($Global:PreLogDir)\I_$($appName)_$($appVersion).log`" -ErrorAction Stop | Out-Null
          Write-Log -Message "Add-AppxPackage -Path `"$sourceFilePath`" -ForceTargetApplicationShutdown -ForceUpdateFromAnyVersion -InstallAllResources." -Source ${CmdletName};
          Add-AppxPackage -Path "$sourceFilePath" -ForceTargetApplicationShutdown -ForceUpdateFromAnyVersion -InstallAllResources
        }
      } catch {
        Write-Output "Something threw an exception or used Write-Error"
        Write-Output $_
        Write-Log -Message "Installation of $($appName)_$($appVersion) failed, will exit with RC = 99." -Source ${CmdletName};
        Write-Log -Message "============================ Failing: $line ============================" -Source ${CmdletName}
        Set-Finalize -ExitCode 99 
      }
    } else { Write-Log -Message "$($appName)_$($appVersion) already installed, going next." -Source ${CmdletName}; }
  } elseif ($actionName.ToUpper() -eq "REMOVE") {
    $APPXNamesTmp = $Data[0]
    $ProcessName = $Data[1]

    Set-FastKillProcesses -processes $ProcessName

    if ($APPXNamesTmp.toLower() -ne 'null') {
      if ($APPXNamesTmp -like "*;*") { $APPXNames = $APPXNamesTmp.Split(";") }
      else { $APPXNames = @($APPXNamesTmp) }

      foreach ($APPXName in $APPXNames) {
        Write-Log -Message "Will try to $actionName $APPXName." -Source ${CmdletName};
        $appxPackage = Get-AppxPackage -Name $APPXName -AllUsers

        If ($appxPackage) {
          $arch = (Get-ChildItem HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Applications\*Microsoft.Todos*).Name

          Write-Log -Message "$($appxPackage.Name) is installed." -Source ${CmdletName}
          try {
            if ($arch -like "*_neutral_*") {
              Write-Log -Message "Get-AppxPackage -AllUsers -PackageTypeFilter Bundle -Name `"$APPXName`" | Remove-AppxPackage -AllUsers" -Source ${CmdletName}
              Get-AppxPackage -AllUsers -PackageTypeFilter Bundle -Name "$APPXName" | Remove-AppxPackage -AllUsers | Out-Null 
            } else {
              Write-Log -Message "Get-AppxPackage -AllUsers -Name `"$APPXName`" | Remove-AppxPackage -AllUsers" -Source ${CmdletName}
              Get-AppxPackage -AllUsers -Name "$APPXName" | Remove-AppxPackage -AllUsers | Out-Null
            }
          } Catch { Set-Finalize -ExitCode 99 }
        } else { Write-Log -Message "Nothing to do with $APPXName - is not installed. Going to next." -Source ${CmdletName} }
      }
    } else { 
			Write-Log -Message "APPXName(s) variable cannot be null, action failed." -Source ${CmdletName}; 
			Write-Log -Message "============================ Failing: $line ============================" -Source ${CmdletName}
			Set-Finalize -ExitCode 1 
		}
  }
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-UnblockFiles {
  <#
    .SYNOPSIS
      Will unblock files locked with some processes so remove, copy, edit or change action can be applied without errors.
    .DESCRIPTION
      Will unblock files locked with some processes so remove, copy, edit or change action can be applied without errors
    .PARAMETER actionName
      The name action type you want to trigger: ADD can be used for UNBLOCKFILE.
    .PARAMETER Data
      Data variable withh all information to execute function like:
      DataDirectory=Path to directory where files to unblock are located. 
    .PARAMETER DataType
      As default is a null for UNBLOCKFILE.
    .EXAMPLE
      Conf line: INSTALL,ADD,UNBLOCKFILE,DirPath,null
    .NOTES
      This is an internal script function and should typically not be called directly, it will be triggered by main script if proper conf line will be found.
    .LINK
      https://github.kyndryl.net/wms-global/WMSAutomationTool/
  #>
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  $DirPath = Set-StringFromVarLayered -VarToCheck $Data[0]
  #INSTALL,ADD,UNBLOCKFILE,DirPath,null

  try {
    Write-Log -Message "${CmdletName} execution started." -Source ${CmdletName}
    Close-HandleToFolder -Folder $DirPath
    Write-Log -Message "${CmdletName} execution finished." -Source ${CmdletName}
		Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
  } catch { 
    Write-Log -Message "Unlocking file failed." -Source ${CmdletName};
		Write-Log -Message "============================ Failing: $line ============================" -Source ${CmdletName}
    #exit 2 
  }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Close-HandleToFolder {
  param(
    [Parameter(Mandatory=$true)]
    [string]$Folder
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  [string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent
  $HandleExe = "$Global:SourcePath\Handle\handle64.exe"

  if (-not(Test-Path $HandleExe)) { $HandleExe = "$scriptDirectory\AppDeployToolkit\Handle\handle64.exe" }
  if (Test-Path $HandleExe) {
    $ErrorActionPreference = "Stop"

    $Folder = $Folder.Replace("'","")
    $Folder = $Folder.Replace("""","")
    $Folder = '"'+$Folder+'"'

    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.RedirectStandardError = $true
    $info.RedirectStandardOutput = $true
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.FileName = $HandleExe
    $info.Arguments = "-a -u -accepteula -nobanner $($Folder)"

    $handles2 = Run-CmdWithLog -processInfo $info
    $handles = $handles2 -split "`n" | ForEach-Object {$_.trim()}

    if (-not([string]::IsNullOrEmpty($handles))) {
      foreach ($line in $handles) {
        $line=$Line.trim()
        $line=$line.Replace("<unable to open process>","unknownuserid")
        $line=$line.Replace("NT AUTHORITY","NTAUTHORITY")

        if($line -like "*pid:*") {
          $result = $line | Select-String -pattern '^([^ ]*)\s*pid: ([0-9]*)\s*type: ([^ ]*)\s*([^ ]*)\s*(.*?): (.*)'
          Write-Log -Message "Checking handle for $result" -Source ${CmdletName}

          $processName =  $result.Matches[0].Groups[1].Value
          Write-Log -Message "processName - $processName" -Source ${CmdletName}
          $processId = [int]::Parse( $result.Matches[0].Groups[2].Value)
          Write-Log -Message "processId - $processId" -Source ${CmdletName}
          $type = $result.Matches[0].Groups[3].Value
          Write-Log -Message "type - $type" -Source ${CmdletName}
          $user = $result.Matches[0].Groups[4].Value
          Write-Log -Message "user - $user" -Source ${CmdletName}
          $handleId =  $result.Matches[0].Groups[5].Value
          Write-Log -Message "handleId - $handleId" -Source ${CmdletName}
          $name = $result.Matches[0].Groups[6].Value
          Write-Log -Message "name - $name" -Source ${CmdletName}

          Write-Log -Message "Found handle for $Folder : $($processName) - $($processId) - $($handleId) - $($name)" -Source ${CmdletName}
          # Close handles
          if($processId -and $handleId) {
            $info.FileName = $HandleExe
            $info.Arguments = "-c $($handleId) -p $($processId) -y -nobanner"
            Write-Log -Message "CloseHandle: $HandleExe -c $($handleId) -p $($processId) -y -nobanner" -Source ${CmdletName}
            $closehandles = Run-CmdWithLog -processInfo $info
            Write-Log -Message "CloseHandle handle for $closehandles" -Source ${CmdletName}
          }
          Stop-Process -ID $processId -Force
          Stop-Process -ID $handleId -Force
        }
      }
    }
  } else { Write-Log -Message "Skiping UNBLOCKFILE,because of missing: $HandleExe." -Source ${CmdletName} }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Run-CmdWithLog {
  param(
    $processInfo
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  $p = New-Object System.Diagnostics.Process
  $p.StartInfo = $processinfo
  Write-Log -Message "Executing command '$($processInfo.Filename)' with arguments '$($processInfo.Arguments)'" -Source ${CmdletName}

  try {
    $p.Start()
    $p.WaitForExit()
    $stdout = $p.StandardOutput.ReadToEnd()

    if ($null -ne $stdout) {
      $result=$stdout
      Write-Log -Message "$($processinfo.Filename) $($processinfo.Arguments) returned: $stdout" -Source ${CmdletName}
    } else {
      $stderror = $p.StandardError.ReadToEnd()
      $result=$stderror
      Write-Log -Message "*** ERROR: $($processinfo.Filename) $($processinfo.Arguments) returned: $stderr" -Source ${CmdletName}
    }
  } Catch {
    Write-Log -Message "*** ERROR: $($processinfo.Filename) $($processinfo.Arguments) returned:" -Source ${CmdletName}
    Write-Log -Message "           $Error" -Source ${CmdletName}
    $result = $Error
    $Error.Clear()
  }

  return $result
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-RunVBS {
  <#
    .SYNOPSIS
      Will run external VBS script with parameters if needed. 
    .DESCRIPTION
      Will run external VBS script with parameters if needed. 
    .PARAMETER actionName
      The name action type you want to trigger: ADD can be used for VBS.
    .PARAMETER Data
      Data variable withh all information to execute function like:
      DataVBSFile=VBS file name
      DataVBSParams (nullable)=Additional parameter that can be passed to VBS file.
      DataVBSFileDir=Path to directory where VBS file is placed.
      DataCheckRC = True or False if you need or do not need checking RC from triggered action. Default null (true).
    .PARAMETER DataType
      As default is a null for UNBLOCKFILE.
      DataCheckRC=True or False if you need or do not need checking RC from triggered action. Default null (true).
    .EXAMPLE
      Conf line: INSTALL,ADD,VBS,Setup.vbs=/s /progressbar=%srcfilepath%\VBSDir,null
    .NOTES
      This is an internal script function and should typically not be called directly, it will be triggered by main script if proper conf line will be found.
    .LINK
      https://github.kyndryl.net/wms-global/WMSAutomationTool/
  #>
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$DataType = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #INSTALL,ADD,VBS,VBSFile=VBSParams=VBSFileDir,null

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}
	
  $VBSFile = Set-StringFromVarLayered -VarToCheck $Data[0]
  $VBSParams = Set-StringFromVarLayered -VarToCheck $Data[1]
  $VBSFileDir = Set-StringFromVarLayered -VarToCheck $Data[2]

  $process = $True

  if($DataType.ToLower() -like "*;*") {
    $DataTypeArr = $DataType.Split(";")
    $process = Get-TestResult -ConditionTest $DataTypeArr[-1]
    $DataTypeD = $DataType.Replace(";$($DataTypeArr[-1])","")
  } else { $process = Get-TestResult -ConditionTest $DataType; $DataTypeD = $DataType }

  if ($process -eq $True) {
    $checkRC = Set-StringFromVarLayered -VarToCheck $DataTypeD

    if (($checkRC.ToLower() -eq "true") -or ($checkRC.ToLower() -eq "null")) { Write-Log -Message "Will validate VBS exit code." -Source ${CmdletName} }
    elseif ($checkRC.ToLower() -eq "false") { Write-Log -Message "Will not validate VBS exit code." -Source ${CmdletName} }
    else {
      Write-Log -Message "Will validate VBS custom exit codes: 0;$checkRC." -Source ${CmdletName} 
      if ($checkRC.ToLower() -like "*;*") {
        $checkRCArr = $checkRC.Split(";")
      } else { $checkRCArr = $checkRC }
    }


    if (($VBSFileDir.ToLower() -eq "null") -or ([string]::IsNullOrEmpty($VBSFileDir))) { $VBSFile = Set-StringFromVarLayered -VarToCheck $VBSFile; $scriptPath = "$Global:SourcePath\$VBSFile" }
    else { $VBSFileDir = Set-StringFromVarLayered -VarToCheck $VBSFileDir; $scriptPath = "$VBSFileDir\$VBSFile" }

    Test-ParamFile -path "$scriptPath"

    if (($VBSParams.ToLower() -eq "null") -or ([string]::IsNullOrEmpty($VBSParams))) { Write-Log -Message "Command to run: $scriptPath"; & cscript /nologo "$scriptPath" }
    else {
      Write-Log -Message "Command to run: $scriptPath $VBSParams" -Source ${CmdletName};
      Write-Log -Message "& cscript /nologo `"$scriptPath`" $VBSParams" -Source ${CmdletName};
      & cscript /nologo "$scriptPath" "$VBSParams"
    }

    $RC = $LastExitCode
    
    <# 
    if (($RC -ne 0) -and (($checkRC.ToLower() -eq "true") -or ($checkRC.ToLower() -eq "null"))) { 
      Write-Log -Message "Set-RunVBS failed with RC = $RC." -Source ${CmdletName}
      Set-Finalize -ExitCode $RC 
    } 
    #>
    
    If (([string]::IsNullOrEmpty($RC)) -and ($checkRC.ToLower() -ne "false")) {
      Write-Log -Message "RC is null, but RC check was set. Will fail scrpt with 1." -Source ${CmdletName}
      Set-Finalize -ExitCode 1 
    }

    if (($RC -ne 0) -and (($checkRC.ToLower() -eq "true") -or ($checkRC.ToLower() -eq "null"))) { 
      Write-Log -Message "Set-RunVBS failed with RC = $RC." -Source ${CmdletName}
			Write-Log -Message "============================ Failing: $line ============================" -Source ${CmdletName}
      Set-Finalize -ExitCode $RC 
    } else {
      foreach ($TestRC in $checkRCArr) { 
        if (($TestRC -eq $RC) -or ($RC -eq 0)) { 
          Write-Log -Message "RC = $RC is a success code. VBS finished successfully." -Source ${CmdletName}
					Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
          Return 0 
        } 
      }

      if ($RC -eq 0) {
        Write-Log -Message "RC = $RC is a success code. VBS finished successfully." -Source ${CmdletName}
        Return 0 
      } elseif ($checkRC.ToLower() -eq "false") {
        Write-Log -Message "Skipping RC checking. Going to next action." -Source ${CmdletName}
				Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
        Return 0 
      } else {
        Write-Log -Message "Set-RunVBS failed with RC = $RC." -Source ${CmdletName}
				Write-Log -Message "============================ Failing: $line ============================" -Source ${CmdletName}
        Set-Finalize -ExitCode $RC 
      }
    }
  } else { Write-Log -Message "Action processing skipped thrue condition results." -Source ${CmdletName} }
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-RunPS {
  <#
    .SYNOPSIS
      Will run external PS script with parameters if needed. 
    .DESCRIPTION
      Will run external PS script with parameters if needed. 
    .PARAMETER actionName
      The name action type you want to trigger: ADD can be used for PS.
    .PARAMETER Data
      Data variable withh all information to execute function like:
      DataPSFile=PS file name
      DataPSParams (nullable)=Additional parameter that can be passed to PS file.
      DataPSFileDir=Path to directory where PS file is placed
      DataCheckRC = True or False if you need or do not need checking RC from triggered action. Default null (true).
    .PARAMETER DataType
      As default is a null for PS.
      DataCheckRC=True or False if you need or do not need checking RC from triggered action. Default null (true).
    .EXAMPLE
      Conf line: INSTALL,ADD,PS,Setup.ps=-installmode silent -action uninstall=%srcfilepath%\PSDir,null
    .NOTES
      This is an internal script function and should typically not be called directly, it will be triggered by main script if proper conf line will be found.
    .LINK
      https://github.kyndryl.net/wms-global/WMSAutomationTool/
  #>
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$DataType = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #INSTALL,ADD,PS,PSFile=PSParams=PSFileDir,null

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  $PSFile = Set-StringFromVarLayered -VarToCheck $Data[0]
  $PSParams = Set-StringFromVarLayered -VarToCheck $Data[1]
  $PSFileDir = Set-StringFromVarLayered -VarToCheck $Data[2]
  
  $process = $True

  if($DataType.ToLower() -like "*;*") {
    $DataTypeArr = $DataType.Split(";")
    $process = Get-TestResult -ConditionTest $DataTypeArr[-1]
    $DataTypeD = $DataType.Replace(";$($DataTypeArr[-1])","")
  } else { $process = Get-TestResult -ConditionTest $DataType; $DataTypeD = $DataType }

  if ($process -eq $True) {
    $checkRC = Set-StringFromVarLayered -VarToCheck $DataTypeD

    if (($checkRC.ToLower() -eq "true") -or ($checkRC.ToLower() -eq "null")) { Write-Log -Message "Will validate PS exit code." -Source ${CmdletName} }
    elseif ($checkRC.ToLower() -eq "false") { Write-Log -Message "Will not validate PS exit code." -Source ${CmdletName} }
    else {
      Write-Log -Message "Will validate PS custom exit codes: 0;$checkRC." -Source ${CmdletName} 
      if ($checkRC.ToLower() -like "*;*") {
        $checkRCArr = $checkRC.Split(";")
      } else { $checkRCArr = $checkRC }
    }

    Write-Log -Message "Trying to start: $PSFileDir\$PSFile $PSParams" -Source ${CmdletName}
    #$char = '"'

    if (($PSFileDir.ToLower() -eq "null") -or ([string]::IsNullOrEmpty($PSFileDir))) { $PSFile = Set-StringFromVarLayered -VarToCheck $PSFile; $scriptPath = "$Global:SourcePath\$PSFile" }
    else { $PSFileDir = Set-StringFromVarLayered -VarToCheck $PSFileDir; $scriptPath = "$PSFileDir\$PSFile" }

    Test-ParamFile -path "$scriptPath"

    #if (($PSParams.ToLower() -eq "null") -or ([string]::IsNullOrEmpty($PSParams))) { Write-Log -Message "Command to run: $scriptPath" -Source ${CmdletName}; Invoke-Expression "$char$scriptPath$char" }
    #else { Write-Log -Message "Command to run: $scriptPath $PSParams" -Source ${CmdletName}; Invoke-Expression "$char$scriptPath$char" "$PSParams" }

    if (($PSParams.ToLower() -eq "null") -or ([string]::IsNullOrEmpty($PSParams))) { Write-Log -Message "Command to run: $scriptPath"; Invoke-Expression "& '$scriptPath'" }
    else { Write-Log -Message "Command to run: $scriptPath $PSParams" -Source ${CmdletName}; Invoke-Expression "& `'$scriptPath`' $PSParams" }

    $RC = $LastExitCode
    
    <# 
    Write-Log -Message "Script result RC = $RC, and is a checkRC = $checkRC." -Source ${CmdletName}

    if (($RC -ne 0) -and (($checkRC.ToLower() -eq "true") -or ($checkRC.ToLower() -eq "null"))) { 
      Write-Log -Message "Set-RunPS failed with RC = $RC." -Source ${CmdletName}
      Set-Finalize -ExitCode $RC 
    }
    #>
    
    If (([string]::IsNullOrEmpty($RC)) -and ($checkRC.ToLower() -ne "false")) {
      Write-Log -Message "RC is null, but RC check was set. Will fail scrpt with 1." -Source ${CmdletName}
			Write-Log -Message "============================ Failing: $line ============================" -Source ${CmdletName}
      Set-Finalize -ExitCode 1 
    }

    if (($RC -ne 0) -and (($checkRC.ToLower() -eq "true") -or ($checkRC.ToLower() -eq "null"))) { 
      Write-Log -Message "Set-RunPS failed with RC = $RC." -Source ${CmdletName}
      Set-Finalize -ExitCode $RC 
    } else {
      foreach ($TestRC in $checkRCArr) { 
        if (($TestRC -eq $RC) -or ($RC -eq 0)) { 
          Write-Log -Message "RC = $RC is a success code. PS finished successfully." -Source ${CmdletName}
					Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
          Return 0 
        } 
      }
      
      if ($RC -eq 0) {
        Write-Log -Message "RC = $RC is a success code. PS finished successfully." -Source ${CmdletName}
        Return 0 
      } elseif ($checkRC.ToLower() -eq "false") {
        Write-Log -Message "Skipping RC checking. Going to next action." -Source ${CmdletName}
				Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
        Return 0 
      } else {
        Write-Log -Message "Set-RunPS failed with RC = $RC." -Source ${CmdletName}
				Write-Log -Message "============================ Failing: $line ============================" -Source ${CmdletName}
        Set-Finalize -ExitCode $RC 
      }
    }
  } else { Write-Log -Message "Action processing skipped thrue condition results." -Source ${CmdletName} }
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-RunCMD {
  <#
    .SYNOPSIS
      Will run external PS script with parameters if needed. 
    .DESCRIPTION
      Will run external PS script with parameters if needed. 
    .PARAMETER actionName
      The name action type you want to trigger: ADD can be used for CMD.
    .PARAMETER Data
      Data variable withh all information to execute function like:
      DataCMDFile=CMD file name
      DataCMDParams (nullable)=Additional parameter that can be passed to CMD file.
      DataCMDFileDir=Path to directory where CMD file is placed
      DataCheckRC = True or False if you need or do not need checking RC from triggered action. Default null (true).
    .PARAMETER DataType
      As default is a null for CMD.
      DataCheckRC=True or False if you need or do not need checking RC from triggered action. Default null (true).
    .EXAMPLE
      Conf line: INSTALL,ADD,CMD,setup.cmd=null=%srcfilepath%\CMDDir,null
    .NOTES
      This is an internal script function and should typically not be called directly, it will be triggered by main script if proper conf line will be found.
    .LINK
      https://github.kyndryl.net/wms-global/WMSAutomationTool/
  #>
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$DataType = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #INSTALL,ADD,CMD,CMDFile=CMDParams=CMDFileDir,null

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}
	
  $CMDFile = Set-StringFromVarLayered -VarToCheck $Data[0]
  $CMDParams = Set-StringFromVarLayered -VarToCheck $Data[1]
  $CMDFileDir = Set-StringFromVarLayered -VarToCheck $Data[2]

  $process = $True
  $CMDExePath = Get-CMDExePath

  if($DataType.ToLower() -like "*;*") {
    $DataTypeArr = $DataType.Split(";")
    $process = Get-TestResult -ConditionTest $DataTypeArr[-1]
    $DataTypeD = $DataType.Replace(";$($DataTypeArr[-1])","")
  } else { $process = Get-TestResult -ConditionTest $DataType; $DataTypeD = $DataType }

  if ($process -eq $True) {
    $checkRC = Set-StringFromVarLayered -VarToCheck $DataTypeD

    if (($checkRC.ToLower() -eq "true") -or ($checkRC.ToLower() -eq "null")) { Write-Log -Message "Will validate CMD exit code." }
    elseif ($checkRC.ToLower() -eq "false") { Write-Log -Message "Will not validate CMD exit code." -Source ${CmdletName} }
    elseif ($checkRC.ToLower() -eq "call") { Write-Log -Message "Will call cmd fileand will not wait for RC." -Source ${CmdletName} }
    else {
      Write-Log -Message "Will validate CMD custom exit codes: 0;$checkRC." -Source ${CmdletName} 
      if ($checkRC.ToLower() -like "*;*") {
        $checkRCArr = $checkRC.Split(";")
      } else { $checkRCArr = $checkRC }
    }

    if (($CMDFileDir.ToLower() -eq "null") -or ([string]::IsNullOrEmpty($CMDFileDir))) { $CMDFile = Set-StringFromVarLayered -VarToCheck $CMDFile; $scriptPath = "$Global:SourcePath\$CMDFile" }
    else { $CMDFileDir = Set-StringFromVarLayered -VarToCheck $CMDFileDir; $scriptPath = "$CMDFileDir\$CMDFile" }

    Test-ParamFile -path "$scriptPath"

    if (($CMDParams.ToLower() -eq "null") -or ([string]::IsNullOrEmpty($CMDParams))) { 
      Write-Log -Message "Command to run: $scriptPath" -Source ${CmdletName};
      #$proc = Start-Process -NoNewWindow -Wait -PassThru "$CMDExePath" "/c `"$scriptPath`""
      #$proc.WaitForExit()
      if ($checkRC.ToLower() -eq "call") { Start-Process -NoNewWindow "$scriptPath"; $RC = 0 }
      elseif ($checkRC.ToLower() -eq "false") { Start-Process -NoNewWindow -Wait -PassThru "$scriptPath" }
      else { 
        $proc = Start-Process -NoNewWindow -Wait -PassThru "$CMDExePath" "/c `"$scriptPath`""
        #$proc = Start-Process -NoNewWindow -Wait -PassThru "$scriptPath"
        $proc.WaitForExit()
        $RC = $process.ExitCode
      }
    } else { 
      Write-Log -Message "Command to run: $scriptPath $CMDParams" -Source ${CmdletName}; 
      #$proc = Start-Process -NoNewWindow -Wait -PassThru "$CMDExePath" "/c `"$scriptPath`" $CMDParams"
      #$proc.WaitForExit()
      if ($checkRC.ToLower() -eq "call") { Start-Process -NoNewWindow "$scriptPath" "$CMDParams"; $RC = 0 }
      elseif ($checkRC.ToLower() -eq "false") { Start-Process -NoNewWindow -Wait -PassThru "$scriptPath" "$CMDParams" }
      else { 
        $proc = Start-Process -NoNewWindow -Wait -PassThru "$CMDExePath" "/c `"$scriptPath`" $CMDParams"
        #$proc = Start-Process -NoNewWindow -Wait -PassThru "$scriptPath" "$CMDParams"
        $proc.WaitForExit()
        $RC = $process.ExitCode
      }
    }

    Write-Log -Message "Precheck for RC = $RC." -Source ${CmdletName}
    if ([string]::IsNullOrEmpty($RC)) { $RC = $LastExitCode }

    If (([string]::IsNullOrEmpty($RC)) -and ($checkRC.ToLower() -ne "false")) {
      Write-Log -Message "RC is null, but RC check was set. Will fail scrpt with 1." -Source ${CmdletName}
      Set-Finalize -ExitCode 1 
    }

    if (($RC -ne 0) -and (($checkRC.ToLower() -eq "true") -or ($checkRC.ToLower() -eq "null"))) { 
      Write-Log -Message "Set-RunCMD failed with RC = $RC." -Source ${CmdletName}
			Write-Log -Message "============================ Failing: $line ============================" -Source ${CmdletName}
      Set-Finalize -ExitCode $RC 
    } else {
      foreach ($TestRC in $checkRCArr) { 
        if (($TestRC -eq $RC) -or ($RC -eq 0)) { 
          Write-Log -Message "RC = $RC is a success code. CMD finished successfully." -Source ${CmdletName}
					Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
          Return 0 
        } 
      }

      if ($RC -eq 0) {
        Write-Log -Message "RC = $RC is a success code. CMD finished successfully." -Source ${CmdletName}
				Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
        Return 0 
      } elseif ($checkRC.ToLower() -eq "false") {
        Write-Log -Message "Skipping RC checking. Going to next action." -Source ${CmdletName}
				Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
        Return 0 
      } else {
        Write-Log -Message "Set-RunCMD failed with RC = $RC." -Source ${CmdletName}
				Write-Log -Message "============================ Failing: $line ============================" -Source ${CmdletName}
        Set-Finalize -ExitCode $RC 
      }
    }
  } else { Write-Log -Message "Action processing skipped thrue condition results." -Source ${CmdletName} }
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-PermissionsByACL {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$DataType = " "
  )

  #INSTALL,ADD,ACL,GroupUser=Directory=AdditionalParams,null
  #INSTALL,ADD,ACL,GroupUser=File=AdditionalParams,null
  
  
  #INSTALL,CLEARFLAGS,ACL,Directory,null
  #INSTALL,INHERITANCE,ACL,Directory=AdditionalParams,null /null or enable, disable, d, e
  #INSTALL,OWNER,ACL,Directory=AdditionalParams,null /user or group
  #INSTALL,REMOVE,ACL,GroupUser=Directory,null

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  Write-Log "DataType - $DataType." -Source ${CmdletName}

  If ($actionName.ToUpper() -eq "REMOVE") {
    $GroupUser = Set-StringFromVarLayered -VarToCheck $Data[0]
    $DirectoryFile = Set-StringFromVarLayered -VarToCheck '"'+$Data[1]+'"'
    
    $acl = Get-Acl -Path $DirectoryFile
    $acl.Access | Where-Object {$_.IdentityReference.Value -eq "$GroupUser"} | ForEach-Object{$acl.RemoveAccessRule($_)}
    Set-Acl -AclObject $acl -Path $DirectoryFile
    #$acesToRemove = $acl.Access | Where-Object { $_.IsInherited -eq $false -and $_.IdentityReference -eq "$GroupUser" }
    #$acl.RemoveAccessRuleAll($acesToRemove)
    #Set-Acl -AclObject $acl -Path $DirectoryFile
  } ElseIf ($actionName.ToUpper() -eq "INHERITANCE") {
    $Directory = Set-StringFromVarLayered -VarToCheck '"'+$Data[0]+'"'
    $AdditionalParams = Set-StringFromVarLayered -VarToCheck $Data[1]
    $isProtected = $true #dissable inheritance
    If ((-not (($AdditionalParams.ToLower() -eq "null") -or ([string]::IsNullOrEmpty($AdditionalParams)))) -or ($AdditionalParams.ToLower() -eq "e") -or ($AdditionalParams.ToLower() -eq "enable")) { 
      $isProtected = $false 
    } #allow inheritance

    $acl = Get-Acl -Path $Directory
    $isProtected = $true
    $preserveInheritance = $false #false is not preserving existing enhiretance rules,
    $acl.SetAccessRuleProtection($isProtected, $preserveInheritance)
    Set-Acl -Path $Directory -AclObject $acl
  } ElseIf ($actionName.ToUpper() -eq "OWNER") {
    $Directory = Set-StringFromVarLayered -VarToCheck '"'+$Data[0]+'"'
    $AdditionalParams = Set-StringFromVarLayered -VarToCheck $Data[1]

    $acl = Get-Acl $Directory
    $object = New-Object System.Security.Principal.Ntaccount("$AdditionalParams")
    $acl.SetOwner($object)
    Set-Acl -Path $Directory -AclObject $acl
  } ElseIf ($actionName.ToUpper() -eq "CLEARFLAGS") {
    $Directory = '"'+$Data[0]+'"'
    $Directory = Set-StringFromVarLayered -VarToCheck $Directory

    Set-CustomAcl -lvl 'ClearFlags' -dir "$Directory"
  } ElseIf ($actionName.ToUpper() -eq "RESET") {

  } ElseIf ($actionName.ToUpper() -eq "ADD") {

  } 

}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-Permissions {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$DataType = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #INSTALL,ADD,PERMISSIONS,GroupUser=Directory=AdditionalParams,null
  #INSTALL,ADD,PERMISSIONS,GroupUser=File=AdditionalParams,null
  #INSTALL,REMOVE,PERMISSIONS,GroupUser=Directory,null
  #INSTALL,REMOVE,PERMISSIONS,GroupUser=File,null
  #INSTALL,INHERITANCE,PERMISSIONS,Directory=AdditionalParams,null
  #INSTALL,CLEARFLAGS,PERMISSIONS,Directory=null,null

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  Write-Log "DataType - $DataType." -Source ${CmdletName}

  if (($DataType.ToLower() -eq "true") -or ($DataType.ToLower() -eq "null")) { 
    $checkRC = $True 
    Write-Log "Set to check execution result." -Source ${CmdletName}
  } else {
    $checkRC = $False 
    Write-Log "Set to not check execution result." -Source ${CmdletName}
  }

  $icaclsPath = "$($Env:Windir)\System32\icacls.exe"
  if ($OSBitness -eq "x64") { $icaclsPath = "$($Env:Windir)\SysWOW64\icacls.exe" }

  #check $env:USERDOMAIN then ussers in $env:USERDOMAIN

  If ($actionName.ToUpper() -eq "CLEARFLAGS") {
    $Directory = '"'+$Data[0]+'"'
    $Directory = Set-StringFromVarLayered -VarToCheck $Directory

    Write-Log "Set-CustomAcl -lvl 'ClearFlags' -dir $Directory." -Source ${CmdletName}
    Set-CustomAcl -lvl 'ClearFlags' -dir "$Directory"
  } else {
    If ($actionName.ToUpper() -eq "ADD") {
      $GroupUser = Set-StringFromVarLayered -VarToCheck $Data[0]
      $AdditionalParams = Set-StringFromVarLayered -VarToCheck $Data[2]
      $AdditionalParams = Set-SpecialCharacters -string $AdditionalParams
      $DirectoryFile = '"'+$Data[1]+'"'
      $DirectoryFile = Set-StringFromVarLayered -VarToCheck $DirectoryFile

      Write-Log "Adding permissions: group $GroupUser, directory/file $DirectoryFile, permissions $AdditionalParams." -Source ${CmdletName}

      If (($AdditionalParams.ToLower() -eq "null") -or ([string]::IsNullOrEmpty($AdditionalParams))) {
        if (Test-Path $Data[1] -PathType Container) {
          Write-Log "Will grant perrmisions on directory.." -Source ${CmdletName}
          $CmdToRun = $icaclsPath+" "+$DirectoryFile+" /grant:r "+'"'+${GroupUser}+'"'+":(OI)(CI)M"
        } else {
          Write-Log "Will grant perrmisions on file.." -Source ${CmdletName}
          $CmdToRun = $icaclsPath+" "+$DirectoryFile+" /grant:r "+'"'+${GroupUser}+'"'+":M"
        }
      } Else { $CmdToRun = $icaclsPath+" "+$DirectoryFile+" /grant:r "+'"'+${GroupUser}+'":'+$AdditionalParams }
    } ElseIf ($actionName.ToUpper() -eq "REMOVE") {
      $GroupUser = $Data[0]
      $DirectoryFile = '"'+$Data[1]+'"'
      $DirectoryFile = Set-StringFromVarLayered -VarToCheck $DirectoryFile
      $objUser = New-Object System.Security.Principal.NTAccount("$GroupUser")
      $strSID = $objUser.Translate([System.Security.Principal.SecurityIdentifier])
      $GroupUserSID = $strSID.Value
      Write-Log "Removing permissions: group GroupUser -> $GroupUserSID, directory/file $DirectoryFile." -Source ${CmdletName}

      $CmdToRun = "$icaclsPath $DirectoryFile /REMOVE *$GroupUserSID"
    } ElseIf ($actionName.ToUpper() -eq "INHERITANCE") {
      $Directory = '"'+$Data[0]+'"'
      $AdditionalParams = Set-StringFromVarLayered -VarToCheck $Data[1]
      $AdditionalParams = Set-SpecialCharacters -string $AdditionalParams
      $Directory = Set-StringFromVarLayered -VarToCheck $Directory
      Write-Log "Setting inheritance: direcotry/file $Directory." -Source ${CmdletName}

      If (($AdditionalParams.ToLower() -eq "null") -or ([string]::IsNullOrEmpty($AdditionalParams))) { $CmdToRun = "icacls $Directory /INHERITANCE:D" }
      Else { $CmdToRun = "$icaclsPath $Directory /INHERITANCE:$AdditionalParams" }
    } ElseIf ($actionName.ToUpper() -eq "RESET") {
      $Directory = '"'+$Data[0]+'"'
      $Directory = Set-StringFromVarLayered -VarToCheck $Directory
      Write-Log "Setting inheritance: direcotry/file $Directory." -Source ${CmdletName}
      $CmdToRun = "$icaclsPath $Directory /T /Q /C /RESET"
    }

    Write-Log "Running: $CmdToRun." -Source ${CmdletName}
    #$Result = Invoke-Expression -Command:$CmdToRun
    $Result = Set-customCMD -CmdToRun $CmdToRun
    Write-Log "Result: $Result." -Source ${CmdletName}
    
    if ($checkRC -eq $True) {
      Write-Log "Will check if result was succes."
      if (($Result -like "Successfully processed 0 files;*") -and (-not($Result -like "*Failed processing 0 files"))) {
        Write-Log "Action failed." -Source ${CmdletName}
				Write-Log -Message "============================ Failing: $line ============================" -Source ${CmdletName}
        Set-Finalize -ExitCode 1
      } elseif ((-not($Result -like "Successfully processed 0 files;*")) -and (-not($Result -like "*Failed processing 0 files"))) { Write-Log "Probabbly success, going to next action." -Source ${CmdletName} } 
      else { Write-Log "Success, going to next action." -Source ${CmdletName} } 
    }
    #if (($Result -eq "null") -or ([string]::IsNullOrEmpty($Result))) { Write-Log -Message "$Result" -Source ${CmdletName} }
  }
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-CombPermissions {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #POSTINSTALL,ADD,COMBINEDPERMS,%programfiles(x86)%\Refinitiv\Eikon=null=%domain%\PRD.%is4fid%.SIDD.UENY.V01.C00.Users=RX,null

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  $Directory = '"'+$Data[0]+'"'
  $AdditionalParams = Set-StringFromVarLayered -VarToCheck $Data[1]
  $Directory = Set-StringFromVarLayered -VarToCheck $Directory

  Write-Log "Setting inheritance: direcotry/file $Directory." -Source ${CmdletName}

  If (($AdditionalParams.ToLower() -eq "null") -or ([string]::IsNullOrEmpty($AdditionalParams))) { $CmdToRun = "icacls $Directory /INHERITANCE:D" }
  Else { $CmdToRun = "icacls $Directory /INHERITANCE:$AdditionalParams" }
    
  Write-Log "Running: $CmdToRun." -Source ${CmdletName}
  $Result = Set-customCMD -CmdToRun $CmdToRun
  Write-Log "Result: $Result." -Source ${CmdletName}

  ####################################################

  $DirectoryFile = '"'+$Data[0]+'"'
  $GroupUser = @('Everyone','Users')
  $DirectoryFile = Set-StringFromVarLayered -VarToCheck $DirectoryFile

  foreach($item in $GroupUser) {
    $objUser = New-Object System.Security.Principal.NTAccount("$item")
    $strSID = $objUser.Translate([System.Security.Principal.SecurityIdentifier])
    $GroupUserSID = $strSID.Value

    Write-Log "Removing permissions: group GroupUser -> $GroupUserSID, directory/file $DirectoryFile." -Source ${CmdletName}

    $CmdToRun = "icacls $DirectoryFile /REMOVE *$GroupUserSID"

    Write-Log "Running: $CmdToRun." -Source ${CmdletName}
    $Result = Set-customCMD -CmdToRun $CmdToRun
    Write-Log "Result: $Result." -Source ${CmdletName}
  }

  ####################################################

  $GroupUser = Set-StringFromVarLayered -VarToCheck $Data[2]
  $AdditionalParams = Set-StringFromVarLayered -VarToCheck $Data[3]
  $DirectoryFile = Set-StringFromVarLayered -VarToCheck $DirectoryFile

  Write-Log "Adding permissions: group $GroupUser, directory/file $DirectoryFile, permissions $AdditionalParams." -Source ${CmdletName}

  If (($AdditionalParams.ToLower() -eq "null") -or ([string]::IsNullOrEmpty($AdditionalParams))) {
    if (Test-Path $Data[1] -PathType Container) {
      Write-Log "Will grant perrmisions on directory.." -Source ${CmdletName}
      $CmdToRun = "icacls "+$DirectoryFile+" /grant:r "+'"'+${GroupUser}+'"'+":(OI)(CI)M"
    } else {
      Write-Log "Will grant perrmisions on file.." -Source ${CmdletName}
      $CmdToRun = "icacls "+$DirectoryFile+" /grant:r "+'"'+${GroupUser}+'"'+":M"
    }
  } Else { $CmdToRun = "icacls "+$DirectoryFile+" /grant:r "+'"'+${GroupUser}+'":'+$AdditionalParams }

  Write-Log "Running: $CmdToRun." -Source ${CmdletName}
  $Result = Set-customCMD -CmdToRun $CmdToRun
  Write-Log "Result: $Result." -Source ${CmdletName}
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Get-userNameString {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$string
  )
  $forAllUsersUserName = Get-isUserName -stringToTest $string
  $UName = "%username%"

  if (($Global:UserContextVar -eq "user") -and ($forAllUsersUserName -eq $True)) {
    $userName = $($env:UserName).trim()
    $string = $string.trim()
    $returnString = Set-OwerrideVar -Var $string -IN $UName -OUT $userName
    $returnString = $returnString.Replace(" \","\").Replace("\\","\")
    $returnString = Set-StringFromVarLayered -VarToCheck $returnString

    Return $returnString
  } else {
    Return $string
  }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-TextContentAction {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    $File
  )

  $Backup = "$File-backup"
  $BaseLine = $Data[1]

  if (-not($actionName.ToUpper() -eq "REPLACEALL")) {
    if (($File -like "*etc\hosts") -and (Test-Path -Path $Backup)) { Copy-Item -Path $File -Destination $Backup -Force }
  }

  If ($actionName.ToUpper() -eq "ADD") {
    #$BaseLine = $BaseLine.Replace("|",",")
    $BaseLine = Set-SpecialCharacters -string $BaseLine
    $BaseLine = Get-userNameString -string $BaseLine
    Write-Log -Message "Adding: $BaseLine to: $File." -Source ${CmdletName}
    $SEL = Select-String -Path $File -Pattern $BaseLine
    if( $SEL.Length -gt 0 ) { Write-Log -Message "will skipp action, string is already in file." -Source ${CmdletName} } 
    else { Add-Content -path $File -value "`r`n$BaseLine" }
  } ElseIf ($actionName.ToUpper() -eq "REMOVE") {
    #$BaseLine = $BaseLine.Replace("|",",")
    $BaseLine = Set-SpecialCharacters -string $BaseLine
    Write-Log -Message "Removing: $BaseLine from: $File." -Source ${CmdletName}
    ((Get-Content -path $File -Raw) -replace $BaseLine,'') | Set-Content -Path $File
  } ElseIf ($actionName.ToUpper() -eq "REPLACE") {
    $NewLine = $Data[2]
    #$BaseLine = $BaseLine.Replace("|",",")
    $BaseLine = Set-SpecialCharacters -string $BaseLine
    $BaseLine = Get-userNameString -string $BaseLine
    #$NewLine = $NewLine.Replace("|",",")
    $NewLine = Set-SpecialCharacters -string $NewLine
    $NewLine = Get-userNameString -string $NewLine
    Write-Log -Message "Replacing: $BaseLine to $NewLine in: $File." -Source ${CmdletName}
    ((Get-Content -path $File -Raw) -replace $BaseLine,$NewLine) | Set-Content -Path $File
  } ElseIf ($actionName.ToUpper() -eq "REPLACEALL") {
    $NewLine = $Data[2]
    $BaseLine = Set-SpecialCharacters -string $BaseLine
    $BaseLine = Get-userNameString -string $BaseLine
    $NewLine = Set-SpecialCharacters -string $NewLine
    $NewLine = Get-userNameString -string $NewLine

    $Files = Get-ChildItem -Path $File -Filter ".$($Data[3])"

    ForEach ($F in $Files) {
      Write-Log -Message "Replacing: $BaseLine to $NewLine in: $($F.FullName)." -Source ${CmdletName}
      ((Get-Content -path $F.FullName -Raw) -replace $BaseLine,$NewLine) | Set-Content -Path $F.FullName
    }
  } ElseIf ($actionName.ToUpper() -eq "MERGE") {
    $srcFilePath = Set-StringFromVarLayered -VarToCheck $Data[0]
    $targetFilePath = Set-StringFromVarLayered -VarToCheck $Data[1]
    if (Test-Path -Path $srcFilePath -PathType Leaf) {
      if (Test-Path -Path $targetFilePath -PathType Leaf) {
        . "$PSScriptRoot\textFileMerger.ps1"
        Write-Log -Message "Set-AppendChanges -deltaFilePath $srcFilePath -targetFilePath $targetFilePath." -Source ${CmdletName}
        if ($targetFilePath.ToLower() -like "*.ini") { Set-AppendIniChanges -deltaFilePath $srcFilePath -targetFilePath $targetFilePath }
        elseif ($targetFilePath.ToLower() -like "*.xml") { Set-AppendXmlChanges -deltaFilePath $srcFilePath -targetFilePath $targetFilePath }
        else {  
          Write-Log -Message "MERGE action only supports ini and xml files. Exiting script." -Source ${CmdletName}
          Set-Finalize -ExitCode 1
        }
      } else { Copy-Item -Path $srcFilePath -Destination $targetFilePath }
    }
  }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-TextContent {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #INSTALL,ADD,TextContent,File=TextLine,null
  #UNINSTALL,REMOVE,TextContent,File=TextLine,null
  #UNINSTALL,REPLACE,TextContent,File=OryginalTextLine=NewTextLine,null
  #UNINSTALL,MERGE,TextContent,srcFilePath=targetFilePath,null
  #UNINSTALL,REPLACEALL,TextContent,Directory=OryginalTextLine=NewTextLine=Extension,null

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  $forAllUsers = Get-isAllUsers -stringToTest $Data[0]
  $File = Set-StringFromVarLayered -VarToCheck $Data[0]
  #$Backup = "$File-backup"
  #$BaseLine = $Data[1]

  if ($forAllUsers) {
    if ($Global:userActions.ToLower() -eq 'false') { 
      Write-Log -Message "Will skipp ${CmdletName} execution. userActions = $($Global:userActions)." -Source ${CmdletName} -Severity 3
      Write-Log -Message "For your account use an other method for actions in user context/manipulation of user profiles." -Source ${CmdletName} -Severity 3 
    } else {
      ForEach ($User In (Get-WmiObject Win32_UserProfile -F "Special != True" | Select-Object -Expand LocalPath)) {
        $File = $File.Replace("%allusers%\","")
        $File = "$($User)$File"
        $File = $File.Replace(" \","\").Replace("\\","\")
        Write-Log -Message "FilePath - $File " -Source ${CmdletName}
        Set-TextContentAction -actionName $actionName -Data $Data -File $File
      }
    }
  } else { Set-TextContentAction -actionName $actionName -Data $Data -File $File }
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-WinFeature {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #INSTALL,ADD,WinFeature,FeatureName,null
  #UNINSTALL,REMOVE,WinFeature,FeatureName,null

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  $FeatureName = Set-StringFromVarLayered -VarToCheck $Data[0]

  if ($FeatureName -like "*;*") { $Features = $FeatureName.Split(";") }
  else { $Features = $FeatureName }

  foreach ($Feature in $Features) {
    If ($actionName.ToUpper() -eq "ADD") {
      Write-Log -Message "Enable-WindowsOptionalFeature -Online -FeatureName $Feature -norestart -All" -Source ${CmdletName}
      Enable-WindowsOptionalFeature -Online -FeatureName $Feature -norestart
    } ElseIf ($actionName.ToUpper() -eq "REMOVE") {
      Write-Log -Message "Disable-WindowsOptionalFeature -Online -FeatureName $Feature -norestart" -Source ${CmdletName}
      Disable-WindowsOptionalFeature -Online -FeatureName $Feature -norestart
    }
  }
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-DisplayWindow {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}
	
  #PREINSTALL,ADD,DISPLAYWINDOW,WindowName,null
  #PREINSTALL,ADD,DISPLAYWINDOW,msg=type=context,null #type=(info, error) #context=(user,allusers)
  $windowType = $Data[0]

  if (($deploymentType.ToLower() -eq "uninstall") -or ($deploymentType.ToLower() -eq "pre-uninstall") -or ($deploymentType.ToLower() -eq "post-uninstall")) { $IsInstall = $False }
  else { $IsInstall = $True }

  If ($actionName.ToUpper() -eq "ADD") {
    if ($windowType.ToLower() -eq "fthstrike") { 
      Write-Log -Message "Show-FthStrikeWindowHTA " -Source ${CmdletName}
      $newEnvVar = Show-FthStrikeWindowHTA 
    }
    if ($windowType.ToLower() -eq "process") {
      Write-Log -Message "Show-ProcessWindowHTA -IsPersistent 'False' -IsInstall $IsInstall " -Source ${CmdletName}
      $newEnvVar = Show-ProcessWindowHTA -IsPersistent 'False' -IsInstall $IsInstall 
    }
    if ($windowType.ToLower() -eq "language") { 
      Write-Log -Message "Select-LanguageWindow " -Source ${CmdletName}
      $Global:selectedLang = Select-LanguageWindow 
    }
    if ($windowType.ToLower() -eq "wait") { 
      Write-Log -Message "Show-WaitForUser " -Source ${CmdletName}
      $Global:selectedLang = Show-WaitForUser 
    }
    if ($windowType.ToLower() -eq "msg") { 
      
    }
  }
	
  If ($actionName.ToUpper() -eq "REMOVE") {
    if ($windowType.ToLower() -eq "msg") { 
      
    }
	}
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-KillProcess {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$ProcName,
    [Parameter(Mandatory = $False)]
    [String]$HowToHandle = 'all'
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  Write-Log -Message "Starting Set-KillProcess." -Source ${CmdletName}

  if (-not ([string]::IsNullOrEmpty($Global:EnableKillAction))) {
    if ($Global:EnableKillAction.ToLower() -eq "false") {
      Write-Log -Message "Kill process actions are disabled for your account. Will skip that action." -Source ${CmdletName}
      Return 0
    }
  }

  #gui,nogui,null,all
  Add-Type -AssemblyName UIAutomationClient
  $state = "nogui"

  if (($HowToHandle.ToLower() -ne 'all') -and ($HowToHandle.ToLower() -ne 'null')) {
    $Processes = Get-Process -Name $ProcName -ErrorAction SilentlyContinue
    foreach ($Process in $Processes) {
      try {
        $isGUI = [System.Windows.Automation.AutomationElement]::FromHandle($Process.MainWindowHandle).Current #| Select-Object -Property Name, HasKeyboardFocus, IsOffscreen, BoundingRectangle, NativeWindowHandle, ProcessId, Orientation, FrameworkId
        Write-Log -Message "$Process - GUI." -Source ${CmdletName}
        $state = "gui"
      } catch { Write-Log -Message "$Process - no GUI." -Source ${CmdletName} }
    }
  }

  if (($HowToHandle.ToLower() -eq 'all') -or ($HowToHandle.ToLower() -eq 'null')) { $CanKill = $True } 
  elseif ((($HowToHandle.ToLower() -eq 'nogui') -and ($state -eq 'nogui')) -or (($HowToHandle.ToLower() -eq 'gui') -and ($state -eq 'gui'))) { $CanKill = $True } 
  else { $CanKill = $False }

  Write-Log -Message "CanKill - $CanKill for HowToHandle - $HowToHandle." -Source ${CmdletName}

  if ($CanKill -eq $False) {
    Write-Log -Message "Process not meet gui expectations, will not try to kill it." -Source ${CmdletName}
    Return 0 
  } else {
    while($i -lt 900) {
      $Processes = Get-Process -Name $ProcName -ErrorAction SilentlyContinue

      if ((($null -ne $Processes) -and (-not($Processes.Responding))) -or ($null -ne $Processes)) { 
        Write-Log -Message "$Processes is active, will try to  stop it." -Source ${CmdletName}
        Stop-Process $Processes -Force -ErrorAction SilentlyContinue 
      } else { 
        Write-Log -Message "No active $Processes, going to next action." -Source ${CmdletName}
        Return 0 
      }
      Start-Sleep -Seconds 1
    }
    Return 1
  }
  
  Return 0
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-Process {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$DataType = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #PREINSTALL,STOP,c:\directory=kill;null;,null
  #PREINSTALL,STOP,Process,proces1.exe;proces2.exe;proces3.exe=kill;null;,null
  #PREINSTALL,STOP,Process,proces1.exe;proces2.exe;proces3.exe=kill,null
  #PREINSTALL,STOP,Process,proces1.exe;proces2.exe;proces3.exe=kill;block;,null
  #POSTINSTALL,START,proces3.exe=path=cmdParams,null
  #PREUNINSTALL,STOP,Process,proces1.exe;proces2.exe;proces3.exe=kill;;cmdInProc,null
  #PREUNINSTALL,STOP,Process,proces1.exe;proces2.exe;proces3.exe=nokill;;,null

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}
	
  $ProcessesNames = Set-StringFromVarLayered -VarToCheck $Data[0]
  $Actions = $Data[1]
  $Process = $ProcessesNames.Split(";")
  $Action = $Actions.Split(";")
  $HowToHandle = $DataType

  if (($HowToHandle.ToLower() -eq "gui") -or ($HowToHandle.ToLower() -eq "nogui")) {
    Write-Log -Message "Will handle $HowToHandle processes." -Source ${CmdletName}
  } elseif (($HowToHandle.ToLower() -eq "null") -or ($HowToHandle.ToLower() -eq "all")) {
    $HowToHandle = "all"
    Write-Log -Message "Will handle $HowToHandle processes." -Source ${CmdletName}
  } 

  $ProcDir = $False
  
  if (($ProcessesNames -like "*\*") -or ($ProcessesNames -like "*\")) { 
    Write-Log -Message "${CmdletName} Process directory: $ProcessesNames,  Action: $Action." -Source ${CmdletName}
    $targetDir = $ProcessesNames
    $targetDir = Set-StringFromVarLayered -VarToCheck $targetDir
    $ProcDir = $True
  } else { 
    Write-Log -Message "${CmdletName} ProcessesNames: $ProcessesNames,  Action: $Action." -Source ${CmdletName}
    Write-Log -Message "${CmdletName} Process - $Process." -Source ${CmdletName}
  }

  If ($Action.Length -gt 0) {
    If (($actionName.ToUpper() -eq "STOP") -AND ($Action[0] -eq "kill")) {
      if (-not ([string]::IsNullOrEmpty($Global:EnableKillAction))) {
        if ($Global:EnableKillAction.ToLower() -eq "false") {
          Write-Log -Message "Kill process actions are disabled for your account. Will skip that action." -Source ${CmdletName}
					Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
          Return 0
        }
      }

      if ($ProcDir -eq $True) {
        Get-ProcessesFromDir -targetDir $targetDir
      } else {
        foreach ($ProcName in $Process) {
          $ProcName = $ProcName.ToLower()
          $ProcName = $ProcName.Replace(".exe","")
          $KillProc = [System.Collections.ArrayList]@()

          Write-Log -Message "ProcName fo handle: $ProcName " -Source ${CmdletName}

          if ($Action.Length -eq 1) {
            #Write-Log -Message "stop-process -name $ProcName -force" -Source ${CmdletName}
            #stop-process -name $ProcName -force -ErrorAction SilentlyContinue #need to test and fix this arghs counting.
            Write-Log -Message "Set-KillProcess -ProcName $ProcName -HowToHandle $HowToHandle" -Source ${CmdletName}
            $RC = Set-KillProcess -ProcName $ProcName -HowToHandle $HowToHandle
            If ($RC -ne 0) { Write-Log -Message "Kill process timeout. RC = $RC." -Source ${CmdletName}; Set-Finalize -ExitCode 1 }
          }

          $lng = $Action.Length
          Write-Log -Message "Action.Length = $lng" -Source ${CmdletName}

          foreach ($actionEl in $Action) { Write-Log -Message "actionEl = $actionEl" -Source ${CmdletName} }

          if ($Action.Length -eq 2) {
            if (($ProcName -ne "") -and ($ProcName -ne " ") -and (-not ([string]::IsNullOrEmpty($ProcName)))) {
              foreach ($ProcName in $Process) { Write-Log -Message "Adding: $ProcName to process list." -Source ${CmdletName}; $KillProc.Add($ProcName) }
              if (($Action[1]).ToLower() -eq "block") { Block-AppExecution -ProcessName ($KillProc) }
              elseif (($Action[1]).ToLower() -eq "unblock") { Unblock-AppExecution }
            }
          } elseif ($Action.Length -eq 3) {
            If  ((($Action[1]).ToLower() -eq "kill") -and (($Action[1]).ToLower() -eq "null")) {
              Write-Log -Message "Set-KillProcess -ProcName $ProcName -HowToHandle $HowToHandle" -Source ${CmdletName}
              $RC = Set-KillProcess -ProcName $ProcName -HowToHandle $HowToHandle
              If ($RC -ne 0) { Write-Log -Message "Kill process timeout. RC = $RC." -Source ${CmdletName}; Set-Finalize -ExitCode 1 }
              #Write-Log -Message "stop-process -name $ProcName -force" -Source ${CmdletName}
              #stop-process -name $ProcName -force -ErrorAction SilentlyContinue
            } else {
              $cmdToKill = $Action[2]
              Write-Log -Message "${CmdletName} cmdToKill - $cmdToKill" -Source ${CmdletName}
              if (($cmdToKill -ne "") -and ($cmdToKill -ne " ") -and (-not ([string]::IsNullOrEmpty($cmdToKill)))) {
                if ($cmdToKill -ne 'null') {
                  #get-wmiobject win32_process | Where-Object commandline -like $cmdToKill | remove-wmiobject
                  $processesA = Get-WmiObject Win32_Process -Filter "name = '$ProcessesNames'"
                  Write-Log -Message "${CmdletName} processesA - $processesA " -Source ${CmdletName}
                  foreach($proc in $processesA) {
                    if (($proc.CommandLine -like "*$cmdToKill") -or ($proc.CommandLine -like "*$cmdToKill*") -or ($proc.CommandLine -like "$cmdToKill*") -or ($proc.CommandLine -like "$cmdToKill")) {
                      Write-Log -Message "Stopping proccess $($proc.ProcessId) with $($proc.ThreadCount) threads; $($proc.CommandLine.Substring(0, 50))..." -Source ${CmdletName}
                      Stop-Process -F $proc.ProcessId
                    } else { Write-Log -Message "Skipping proccess $($proc.ProcessId) with $($proc.ThreadCount) threads; $($proc.CommandLine.Substring(0, 50))..." -Source ${CmdletName} } 
                  }
                } else {
                  Write-Log -Message "Set-KillProcess -ProcName $ProcName -HowToHandle $HowToHandle" -Source ${CmdletName}
                  $RC = Set-KillProcess -ProcName $ProcName -HowToHandle $HowToHandle
                }
              }
            }
          } else {
            Write-Log -Message "Set-KillProcess -ProcName $ProcName -HowToHandle $HowToHandle" -Source ${CmdletName}
            $RC = Set-KillProcess -ProcName $ProcName -HowToHandle $HowToHandle
            If ($RC -ne 0) { 
							Write-Log -Message "Kill process timeout. RC = $RC."; 
							Write-Log -Message "============================ Failing: $line ============================" -Source ${CmdletName}
							Set-Finalize -ExitCode 1 
						}
            #Write-Log -Message "stop-process -name $ProcName -force" -Source ${CmdletName}
            #stop-process -name $ProcName -force -ErrorAction SilentlyContinue
          }
        }
      }
    } ElseIf ($actionName.ToUpper() -eq "START") {
      $exetoRun = Set-StringFromVarLayered -VarToCheck $Data[0]
      $exePath = Set-StringFromVarLayered -VarToCheck $Data[1]
      $exeCMD = Set-StringFromVarLayered -VarToCheck $Data[2]
      if ($exePath -eq "null") { $filePath = $exetoRun }
      else { $filePath = "$exePath\$exetoRun" }

      if (($exeCMD.ToLower() -eq "null") -or ([string]::IsNullOrEmpty($exeCMD))) { 
        Write-Log -Message "Command to run: $filePath" -Source ${CmdletName}
        Start-Process "$filePath" 
      } else { 
        Write-Log -Message "Command to run: $filePath $exeCMD" -Source ${CmdletName}
        Start-Process "$filePath" "$exeCMD" 
      }
    }
  }
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-Tag {
  <#
    .SYNOPSIS
      Will add or remove TAG file or registry. 
    .DESCRIPTION
      Can handle file and registry based tags automated creation and removal. 
    .PARAMETER actionName
      The name action type you want to trigger: ADD and REMOVE can be used for TAG.
    .PARAMETER Data
      Data variable withh all information to execute function like:
      DataTAGName=Tag name
      DataTAGType=Type of the tag. List: REG, FILE.
      DataMSIDirProp=MSI Directory name for TAG. 
    .PARAMETER DataType
      As default is a null for TAG.
      DataTAGMSICpm=MSI component name. 
      DataMSIFeatureName=MSI feature name.
    .EXAMPLE
      Conf line: PREINSTALL,ADD,TAG,TAGName;TAGName;TAGName;TAGName=TAGType,null
    .EXAMPLE
      Conf line: POSTUNINSTALL,REMOVE,TAG,TAGName;TAGName;TAGName;TAGName=TAGType,null
    .NOTES
      This is an internal script function and should typically not be called directly, it will be triggered by main script if proper conf line will be found.
    .LINK
      https://github.kyndryl.net/wms-global/WMSAutomationTool/
  #>
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #PREINSTALL,ADD,TAG,TAGName;TAGName;TAGName;TAGName=TAGType,null
  #POSTUNINSTALL,REMOVE,TAG,TAGName;TAGName;TAGName;TAGName=TAGType,null
  #TAGType - FILE, REG

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  if ($line -ne " ") { Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName} }

  $TagNames = Set-StringFromVarLayered -VarToCheck $Data[0]
  If ($Global:clientBasedBP -eq $true) { $TagsType = $TAGType }
  else { $TagsType = $Data[1] }
  
  $isArray = $True

  if ($TagNames -like "*;*") { $Tags = $TagNames.Split(";") } 
  else { $Tags = @($TagNames) }

  #$PreTAGDirTest = Get-Variable -Name PreTAGDir -Scope Global -ErrorAction SilentlyContinue
	#if $PreTAGDir

  If ($actionName.ToUpper() -eq "ADD") {
    If ($isArray -eq $true) {
      If ($TagsType -eq "FILE") {
        If (!(Test-Path "$TagsDir")) {
          New-Item -Path $TagsDir -ItemType Directory
          If ((Test-Path "$TagsDir")) { Write-Log -Message "$TagsDir created." }
          Else { 
						Write-Log -Message "$TagsDir not created." -Source ${CmdletName}; 
						if ($line -ne " ") { Write-Log -Message "============================ Failing: $line ============================" -Source ${CmdletName} }
						Set-Finalize -ExitCode 1
					}
        } Else { Write-Log -Message "$TagsDir exists." -Source ${CmdletName}}

        foreach ($TagName in $Tags) {
          $TagName = Get-VarFromString -VarToCheck $TagName
          If (-not(Test-Path "$TagsDir\$TagNames.tag")) {
            New-Item -Path "$TagsDir\$TagNames.tag" -ItemType File
            If ((Test-Path "$TagsDir\$TagNames.tag")) { Write-Log -Message "$TagsDir\$TagNames.tag created." }
            Else { 
							Write-Log -Message "$TagsDir\$TagNames.tag not created." -Source ${CmdletName}; 
							if ($line -ne " ") { Write-Log -Message "============================ Failing: $line ============================" -Source ${CmdletName} }
							Set-Finalize -ExitCode 1 
						}
          } Else { Write-Log -Message "$TagsDir\$TagNames.tag exists." -Source ${CmdletName} }
        }
      } elseif ($TagsType -eq "REG") {
        foreach ($TagName in $Tags) {
          $TagName = Get-VarFromString -VarToCheck $TagName
          $TagsDir = Convert-RegistryPath -Key "$TagsDir"
          $Key = "$TagsDir\$TagName"
          $Name = "Installed"
          $Type = "String"
          $Value = "TRUE"

          Set-RegistryKey -Key $Key
          if (-not (Test-RegValExist -Path $Key -Name $Name)) {
            If (($Key.ToLower() -ne "null") -and ($Name.ToLower() -ne "null") -and ($Type -ne "null") -and ($Value.ToLower() -ne "null")) { Set-RegistryKey -Key $Key -Name $Name -Type $Type -Value $Value }
            ElseIf (($Key.ToLower() -ne "null") -and ($Name.ToLower() -ne "null") -and ($Value.ToLower() -ne "null")) { Set-RegistryKey -Key $Key -Name $Name -Value $Value }
            ElseIf (($Key.ToLower() -ne "null") -and ($Value.ToLower() -ne "null")) { Set-RegistryKey -Key $Key -Value $Value }
          } Else {
            Write-Log -Message "Registry key $key\$name exists. Removing the key." -Source ${CmdletName}
            Remove-RegistryKey -Key $Key -Name $Name -Recurse

            If (($Key.ToLower() -ne "null") -and ($Name.ToLower() -ne "null") -and ($Type -ne "null") -and ($Value.ToLower() -ne "null")) { Set-RegistryKey -Key $Key -Name $Name -Type $Type -Value $Value }
            ElseIf (($Key.ToLower() -ne "null") -and ($Name.ToLower() -ne "null") -and ($Value.ToLower() -ne "null")) { Set-RegistryKey -Key $Key -Name $Name -Value $Value }
            ElseIf (($Key.ToLower() -ne "null") -and ($Value.ToLower() -ne "null")) { Set-RegistryKey -Key $Key -Value $Value }
          }
        }
      }
    }
  } elseif ($actionName.ToUpper() -eq "REMOVE") {
    If ($isArray -eq $true) {
      If ($TagsType -eq "FILE") {
        foreach ($TagName in $Tags) {
          $TagName = Get-VarFromString -VarToCheck $TagName
          If (Test-Path "$TagsDir\$TagName.tag") {
            Remove-Item "$TagsDir\$TagName.tag"
            If (!(Test-Path "$TagsDir\$TagName.tag")) { Write-Log -Message "$TagsDir\$TagNames.tag removed." -Source ${CmdletName} }
            Else { 
							Write-Log -Message "$TagsDir\$TagNames.tag not removed." -Source ${CmdletName}; 
							if ($line -ne " ") { Write-Log -Message "============================ Failing: $line ============================" -Source ${CmdletName} }
							Set-Finalize -ExitCode 1 
						}
          }
        }
      } elseif ($TagsType -eq "REG") {
        foreach ($TagName in $Tags) {
          $TagName = Get-VarFromString -VarToCheck $TagName
          $TagsDir = Convert-RegistryPath -Key "$TagsDir"
          $Key = Set-StringFromVarLayered -VarToCheck "$TagsDir\$TagName"
          $Name = "Installed"
          $Type = "String"
          $Value = "TRUE"

          $isTag = Test-Path -Path $Key
          Write-Log -Message "Checking reg TAG; $Key if exist." -Source ${CmdletName};
          if (Test-RegValExist -Path $Key -Name $Name) { Write-Log -Message "Reg TAG removing." -Source ${CmdletName}; Remove-RegistryKey -Key $Key -Recurse }
          if ($isTag -eq $true) { Write-Log -Message "Reg TAG removing." -Source ${CmdletName}; Remove-RegistryKey -Key $Key -Recurse }
        }
      }
    } 
  }
  if ($line -ne " ") { Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName} }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-IBMSRC {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$PKGName,
    [Parameter(Mandatory = $True)]
    [String]$Action
  )

  #[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  If ($Action -eq "ADD") {
    $Global:IBMSRCPkg = $GLOBAL:IBMSRC + $PKGName
    If(!(test-path $Global:IBMSRCPkg)) { new-item -path $Global:IBMSRCPkg -itemtype directory }
  } elseif ($Action -eq "REMOVE") { Get-ChildItem $GLOBAL:IBMSRC -Directory -recurse | Where-Object {-NOT $_.GetFiles("*","AllDirectories")} |  Remove-Item -recurse -whatif }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-KyndrylSRC {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$PKGName,
    [Parameter(Mandatory = $True)]
    [String]$Action
  )

  #[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  If ($Action -eq "ADD") {
    $Global:KyndrylSRCPkg = $KyndrylSRC + $PKGName
    If(!(test-path $Global:KyndrylSRCPkg)) { new-item -path $Global:KyndrylSRCPkg -itemtype directory }
  } elseif ($Action -eq "REMOVE") { Get-ChildItem $KyndrylSRC -Directory -recurse | Where-Object {-NOT $_.GetFiles("*","AllDirectories")} |  Remove-Item -recurse -whatif }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Get-Is4fID {
  $ID = 0
  $ID = ($env:COMPUTERNAME).substring(2, 2)
  return $ID
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-Message {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $False)]
    $Severity = 2,
    [Parameter(Mandatory = $True)]
    [AllowEmptyString()]
    [String]$Msg,
    [Parameter(Mandatory = $True)]
    [String]$CmdletName
  )

  ${CmdletName} = $CmdletName

  if ([string]::IsNullOrEmpty($Msg)) { $Msg = 'null' }
  if (Get-Command "Write-Log" -errorAction SilentlyContinue) { Write-Log -Message "$Msg" -Source ${CmdletName} -Severity $Severity; }
  else { write-verbose "$Msg" -verbose }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Get-VarFromString {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$VarToCheck
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  $VarToCheckBak = $VarToCheck

  Set-Message -Msg "Get-VarFromString for:" -CmdletName ${CmdletName} -Severity 1
  Set-Message -Msg "$VarToCheckBak" -CmdletName ${CmdletName} -Severity 1

  if (($VarToCheckBak -like "*%*") -or ($VarToCheckBak -like "%*") -or ($VarToCheckBak -like "*%")) { $RC = [regex]::Matches($VarToCheckBak, '%([^/)]+?)%') } 
  else { $RC = $VarToCheckBak }

  Set-Message -Msg "Translated variable $VarToCheck with result: $RC" -CmdletName ${CmdletName} -Severity 1

  Return $RC
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Get-VDACleanup {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #INSTALL,SET,REMOVEVDA,GUID=InstallDir,null

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  Write-Log -Message "Start-Process -FilePath `"C:\Program Files\Citrix\XenDesktopVdaSetup\XenDesktopVdaSetup.exe`" -ArgumentList /c, `"/removeall /quiet /noreboot /logpath `"$Global:PrelogDir\VDA_UNINSTALL`"`" -Wait -NoNewWindow" -Source ${CmdletName}
  #Start-Process -FilePath "C:\Program Files\Citrix\XenDesktopVdaSetup\XenDesktopVdaSetup.exe" -ArgumentList "/removeall /quiet /noreboot /logpath `"$Global:PrelogDir\VDA_UNINSTALL`"" -Wait -NoNewWindow
  Start-Process -FilePath "$Global:SourcePath\VDACleanupUtility.exe" -ArgumentList "/silent /DISABLEEXPERIENCEMETRICS /NoReboot" -Wait -NoNewWindow
  #PREINSTALL,ADD,EXE,VDACleanupUtility.exe=/unattended /DISABLEEXPERIENCEMETRICS /NoReboot=CitrixVirtualDeliveryAgent_Uninstall={DUMMYGUID},1;3;8
  
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Get-JavaCleanup {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$actionName,
    [Parameter(Mandatory = $False)]
    [String[]]$Data = " ",
    [Parameter(Mandatory = $False)]
    [String]$line = " "
  )

  #INSTALL,SET,REMOVEJAVA,Family=Bitness,null
  #INSTALL,SET,REMOVEJAVA,8=x64,null

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "============================ Starting: $line ============================" -Source ${CmdletName}

  $Publisher = "Oracle"
  $Name = "Java"
  $Family = Set-StringFromVarLayered -VarToCheck $Data[0]
  $Bitness = Set-StringFromVarLayered -VarToCheck $Data[1]

  Set-Message -Msg "Will uninstall Oracle Java $Family, $Bitness." -CmdletName ${CmdletName} -Severity 1
  
  $paths=@(
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\'
  )

  $apps64 = Get-ChildItem -Path $paths[1] | Get-ItemProperty | Select-Object DisplayName, Publisher, InstallDate, DisplayVersion, PSChildName
  $apps86 = Get-ChildItem -Path $paths[0] | Get-ItemProperty | Select-Object DisplayName, Publisher, InstallDate, DisplayVersion, PSChildName

  if (($Bitness -eq "x64") -or ($Bitness -eq "null") -or ($Bitness -eq "all")) {
    foreach ($app in $apps64) {
      if (-not([string]::IsNullOrWhitespace($app.DisplayName))) {
        if ($Family -ne "null") { 
          if (($app.DisplayName -like "$Name*") -and ($app.Publisher -like "$Publisher*") -and (($app.DisplayVersion).ToLower() -like "$($Family.ToLower())*")) { Remove-MSIApplications -Name $app.DisplayName } 
        } else {
          if (($app.DisplayName -like "$Name*") -and ($app.Publisher -like "$Publisher*")) { Remove-MSIApplications -Name $app.DisplayName }
        }
      }
    }
  }

  if (($Bitness -eq "x86") -or ($Bitness -eq "null") -or ($Bitness -eq "all")) {
    foreach ($app in $apps86) {
      if (-not([string]::IsNullOrWhitespace($app.DisplayName))) {
        if ($Family -ne "null") { 
          if (($app.DisplayName -like "$Name*") -and ($app.Publisher -like "$Publisher*") -and (($app.DisplayVersion).ToLower() -like "$($Family.ToLower())*")) { Remove-MSIApplications -Name $app.DisplayName }
        } else { 
          if (($app.DisplayName -like "$Name*") -and ($app.Publisher -like "$Publisher*")) { Remove-MSIApplications -Name $app.DisplayName } 
        }
      }
    }
  }
  Write-Log -Message "============================ Ending: $line ============================" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-SysVars {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$VarToCheck
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  $VarToCheckBak  = $VarToCheck
  $VarToCheck     = $VarToCheck.ToLower()
  $RC = 'null'

  $vaars = Get-ChildItem -Path Env:

  Set-Message -Msg "Set-SysVars for:" -CmdletName ${CmdletName} -Severity 1
  Set-Message -Msg "$VarToCheckBak" -CmdletName ${CmdletName} -Severity 1

  if (($VarToCheckBak -like "*%*") -or ($VarToCheckBak -like "%*") -or ($VarToCheckBak -like "*%")) { $RCv = [regex]::Matches($VarToCheckBak, '%([^/)]+?)%') } 
  else { $RCv = 'null' }

  Set-Message -Msg "RCv - $RCv" -CmdletName ${CmdletName} -Severity 1

  foreach($var in $RCv) {
    $var = ($var.Value).Replace("%","")
    $var = $var.Replace("%","")

    Set-Message -Msg "Will search for var = $var." -CmdletName ${CmdletName} -Severity 1

    foreach($vara in $vaars) {
      $varaN = $vara.Name
      if($var -eq $varaN) { 
        $RCvals = @{
          'name' = $vara.Name 
          'value' = $vara.Value 
        }
        Set-Message -Msg "Generating hastable $($vara.Name) - $($vara.Value)." -CmdletName ${CmdletName} -Severity 1
        $RC += $RCvals
      }
    }
  }

  Set-Message -Msg "Set variable $VarToCheck with result: $RC." -CmdletName ${CmdletName} -Severity 1

  Return $RC
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-SpecialVar {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$VarToCheck
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  Set-Message -Msg "Starting Set-SpecialVar for $VarToCheck." -CmdletName ${CmdletName} -Severity 1

  if ($VarToCheck.ToLower() -like "%installdir-*") {  
    Set-Message -Msg "Will try to handle special variable: %installdir-GUID% to detect intall directory for app." -CmdletName ${CmdletName} -Severity 1

    $tmp = $VarToCheck.ToLower()
    if(($tmp -like "*%%") -or ($tmp -like "*%%*") -or ($tmp -like "%%")) { $datePattern = [Regex]::new('\%(.*?)\%(.*?)\%\%') } 
    else { $datePattern = [Regex]::new('\%(.*?)\%') }

    Set-Message -Msg "Regexp: $datePattern." -CmdletName ${CmdletName} -Severity 1
    $matchesVar = $datePattern.Matches($VarToCheck)
    $vars = $matchesVar.Value

    foreach ($var in $vars) {
      Set-Message -Msg "Var to resolve is: $var" -CmdletName ${CmdletName} -Severity 1

      $nameTmp = (($var.Split("-"))[0]).Replace("%","")
      $name = $var.Replace("$nameTmp-","")

      if (($var -like "*%%") -or ($var -like "*%%*") -or ($var -like "%%")) {
        $name = $name.Replace("%%","%")
        Set-Message -Msg "Will try to get value for: $name" -CmdletName ${CmdletName} -Severity 1
        $name = Set-StringFromVarLayered -VarToCheck $name
      } else { $name = $name.Replace("%","") }
      
      Set-Message -Msg "App GUID: $name" -CmdletName ${CmdletName} -Severity 1

      $regkey = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$name"

      if (Get-ItemProperty -Path $regkey -Name "InstallLocation" -ErrorAction Ignore) { $exist = $true } 
      else { $exist = $false }

      try {
        if ($exist) { 
          $RC = Get-ItemProperty -Path $regkey 
          foreach ($item in $RC) { 
            Set-Message -Msg "-----" -CmdletName ${CmdletName} -Severity 1 
            Set-Message -Msg "Got InstallLocation = $($item.InstallLocation)" -CmdletName ${CmdletName} -Severity 1 
          }
        }
      } catch {}
      
      if(-not([string]::IsNullOrEmpty($RC))) { 
        foreach ($item in $RC) {
          Set-Message -Msg "-----" -CmdletName ${CmdletName} -Severity 1 
          Set-Message -Msg "Got InstallLocation = $($item.InstallLocation)" -CmdletName ${CmdletName} -Severity 1 
          $tmp = $item.InstallLocation
          if(-not([string]::IsNullOrEmpty($tmp))) { $IL = $tmp }
        }
      }

      if ([string]::IsNullOrEmpty($IL)) {
        Set-Message -Msg "$regkey doesnt exist, will try with next one." -CmdletName ${CmdletName} -Severity 1
        $regkey = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$name"
        if (Get-ItemProperty -Path $regkey -Name "InstallLocation" -ErrorAction Ignore) { $exist = $true } 
        else { $exist = $false }

        try {
          if ($exist) { 
            $RC = Get-ItemProperty -Path $regkey 
          }
        } catch {}

        if(-not([string]::IsNullOrEmpty($RC))) { 
          foreach ($item in $RC) {
            Set-Message -Msg "-----" -CmdletName ${CmdletName} -Severity 1 
            Set-Message -Msg "$($item.InstallLocation)" -CmdletName ${CmdletName} -Severity 1 
            $tmp = $item.InstallLocation
            if(-not([string]::IsNullOrEmpty($tmp))) { $IL = $tmp }
          }
        }

        if ([string]::IsNullOrEmpty($IL)) { 
          Set-Message -Msg "$regkey doesnt exist." -CmdletName ${CmdletName} -Severity 1
          Set-Message -Msg "App was not found or InstallLocation is missinsg." -CmdletName ${CmdletName} -Severity 1
          if (($Global:installPhase -like "*-Installation") -or ($Global:installPhase -eq "Installation")) {
            Set-Message -Msg "Check app status (reinstall) or use a different variable." -CmdletName ${CmdletName} -Severity 1
            Set-Message -Msg "Translate that as failure because of installation phase: $($Global:installPhase)." -CmdletName ${CmdletName} -Severity 1
            Set-Finalize -ExitCode 1
          } else {
            Set-Message -Msg "Check app status." -CmdletName ${CmdletName} -Severity 1
            Set-Message -Msg "Translate that as success because of installation phase: $($Global:installPhase)." -CmdletName ${CmdletName} -Severity 1
            Set-Finalize -ExitCode 0
          }
        }
      }  
      Set-Message -Msg "Return $IL ($($IL.GetType().Name))." -CmdletName ${CmdletName} -Severity 1
      Return $IL
    }
  }

  if ($VarToCheck.ToLower() -like "%getguid-*") {
    Set-Message -Msg "Will try to handle special variable: %getguid-AppName% to get an application GUID based on App Name or part of App Name." -CmdletName ${CmdletName} -Severity 1

    $tmp = $VarToCheck.ToLower()
    if(($tmp -like "*%%") -or ($tmp -like "*%%*") -or ($tmp -like "%%")) { $datePattern = [Regex]::new('\%(.*?)\%(.*?)\%\%') } 
    else { $datePattern = [Regex]::new('\%(.*?)\%') }

    Set-Message -Msg "Regexp: $datePattern." -CmdletName ${CmdletName} -Severity 1
    $matchesVar = $datePattern.Matches($VarToCheck)
    $vars = $matchesVar.Value

    foreach ($var in $vars) {
      Set-Message -Msg "Var to resolve is: $var"  -CmdletName ${CmdletName} -Severity 1

      $nameTmp = (($var.Split("-"))[0]).Replace("%","")
      $name = $var.Replace("$nameTmp-","")

      if (($var -like "*%%") -or ($var -like "*%%*") -or ($var -like "%%")) {
        $name = $name.Replace("%%","%")
        $name = Set-StringFromVarLayered -VarToCheck $name
      } else { $name = $name.Replace("%","") }

      Set-Message -Msg "App Name: $name" -CmdletName ${CmdletName} -Severity 1

      $RC = Get-InstalledApplication -Name $name -Exact $True 
      if ([string]::IsNullOrEmpty($RC)) { $RC = Get-InstalledApplication -Name $name -WildCard $true }

      if (-not([string]::IsNullOrEmpty($RC))) {
        $GUID = $RC.ProductCode
        Set-Message -Msg "Return $GUID." -CmdletName ${CmdletName} -Severity 1
        Return $GUID
      } else {
        Set-Message -Msg "Check app status. App was not found. success of fail depends on installation phase." -CmdletName ${CmdletName} -Severity 1
        Set-Message -Msg "Translate that as success because of installation phase: $($Global:installPhase)." -CmdletName ${CmdletName} -Severity 1
        Return 0
      }
    }
  }

  if ($VarToCheck.ToLower() -like "%lang-*") {
    Set-Message -Msg "Will try to handle special variable: %lang-AcceptedLangs% to get an acceptable system language." -CmdletName ${CmdletName} -Severity 1
  
    $LangNameTmp = (($VarToCheck.Split("-"))[0]).Replace("%","")
    $AcceptedLangs = $VarToCheck.Replace("$LangNameTmp","")
    Set-Message -Msg "Get-SystemLanguage -AcceptedLangs $AcceptedLangs" -CmdletName ${CmdletName} -Severity 1
    $RC = Get-SystemLanguage -AcceptedLangs $AcceptedLangs
    Set-Message -Msg "Got $RC language." -CmdletName ${CmdletName} -Severity 1

    Return $RC
  }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-OwerrideVar {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$Var,
    [Parameter(Mandatory = $True)]
    [String]$IN,
    [Parameter(Mandatory = $True)]
    [AllowEmptyString()]
    [String]$OUT
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  if ($OUT -eq "") { $OUT = "" }

  if (Get-IsLike -VarToTest $IN -VarToChange $Var) { 
    if (Get-Command "Write-Log" -errorAction SilentlyContinue) { Set-Message -Msg "Found - $IN in - $Var, will replace to - $OUT." -CmdletName ${CmdletName} -Severity 2; }
    else { Set-Message -Msg "Found - $IN in - $Var, will replace to - $OUT." -CmdletName ${CmdletName} -Severity 1 }

    $Var = $Var.Replace($IN, $OUT); 
  } 
  
  Return $Var
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Get-ScriptGlobals {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$originalString,
    [Parameter(Mandatory = $True)]
    [String]$VarToCheckBak,
    [Parameter(Mandatory = $True)]
    [String]$VarToCheck
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  
  $tmpName = (Get-Variable $originalString -Scope Global -ErrorAction 'Ignore').Name
  if ($tmpName -eq $originalString) {
    $VarValue = (Get-Variable $originalString -Scope Global -ErrorAction 'Ignore').Value
    if (($originalString -eq $VarToCheckBak) -and ($originalString.ToLower -ne $VarToCheck)) { $Var = $VarToCheck.Replace("$Value","$VarValue"); }
    else { $Var = $VarToCheckBak.Replace("$Value","$VarValue"); }
  }

  if (Get-Command "Write-Log" -errorAction SilentlyContinue) { Set-Message -Msg "originalString - $originalString = Var - $Var." -CmdletName ${CmdletName} -Severity 2; }
  else { Set-Message -Msg "originalString - $originalString = Var - $Var." -CmdletName ${CmdletName} -Severity 1 }


  Return $Var
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-StringFromVarLayered {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$VarToCheck
  )

  $Var = $VarToCheck.Replace("null;","")
  For ($x = 0; $x -lt 4; $x++) { if (($Var -like "*%*") -or ($Var -like "%*") -or ($Var -like "*%")) { $Var = Set-StringFromVar -VarToCheck $Var } }
  Return $Var
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-DesktopPath {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$VarToCheck
  )

  $IN = "%public%"
  $OUT = $GLOBAL:PUBLIC
  $Var = $VarToCheck

  if (Get-IsLike -VarToTest $IN -VarToChange $Var) { 
    if (Get-Command "Write-Log" -errorAction SilentlyContinue) { Set-Message -Msg "Found - $IN in - $Var, will replace to - $OUT." -CmdletName ${CmdletName} -Severity 2; }
    else { Set-Message -Msg "Found - $IN in - $Var, will replace to - $OUT." -CmdletName ${CmdletName} -Severity 1 }
    $Var = $Var.Replace($IN, $OUT); 
  } 

  if ((-not (($Var.ToLower() -like "public desktop"))) -and (($Var.ToLower() -like "*\desktop*") -or ($Var -like "*\desktop"))) {
    if ((Test-Path -Path "$OUT\public desktop" -PathType Container) -eq $True) { $Var = $Var.Replace("\desktop", "\public desktop").Replace("\Desktop", "\public desktop") }
  }

  Return $Var
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Get-DNSDomain {

	$RC = $env:USERDNSDOMAIN
	if ([string]::IsNullOrEmpty($RC)) { 
		$RC = $env:USERDOMAIN
		if ([string]::IsNullOrEmpty($RC)) { $RC = "noDomain" }
	}

	Return $RC
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------





#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-StringFromVar {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$VarToCheck
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  $tempered       = $False
  $originalString = $VarToCheck
  $VarToCheckBak  = $VarToCheck
  $VarToCheck     = $VarToCheck.ToLower()
  $DateTime       = Get-Date -Format "yyyy_MM_dd_hh_mm_ss"
  $is4fid         = Get-Is4fID

  $DefaultUserProfile = ($env:public).Replace("Public","Default")

  $vars = @(("%logfiles%",$env:LOGFILES),
            ("%default%",$DefaultUserProfile),
            ("%datetime%",$DateTime),
            ("%programdata%",$Global:ProgramData),
            ("%is4fid%",$is4fid),
            ("%domain%",$env:USERDOMAIN),
            ("%dnsdomain%","$(Get-DNSDomain)"),
            ("%programfiles86%",$Global:ProgramFiles),
            ("%programfilesx86%",$Global:ProgramFiles),
            ("%programfiles(x86)%",$Global:ProgramFiles),
            ("%programfiles%",$env:programfiles),
            ("%programfiles(x64)%",$Global:ProgramFiles64),
            ("%programfilesx64%",$Global:ProgramFiles64),
            ("%programfiles64%",$Global:ProgramFiles64),
            ("%configfilespath%",$Global:ConfigFilesPath),
            ("%srcfilepath%",$Global:SourcePath),
            ("%sourcepath%",$Global:SourcePath),
            ("%prereqspath%",$Global:PrerequisitesPath),
            ("%allusers%",""),
            ("%ibmsrc%",$GLOBAL:IBMSRCPkg),
            ("%kyndrylsrc%",$Global:KyndrylSRCPkg),
            ("%temp%",$Global:Temp),
            #("%public%",$GLOBAL:PUBLIC),
            ("%commonprogramfiles%",$GLOBAL:COMMONPROGRAMFILES64),
            ("%systemdrive%",$env:SystemDrive),
            ("%rootdrive%",$env:SystemDrive),
            ("%pkglogdir%",$Global:configToolkitLogDir),
            ("%PKGName%",$Global:PKGName),
            ("%AppInstallDir%",$Global:AppInstallDir),
            ("%hostname%",$env:computername),
            ("%prelogdir%",$Global:PreLogDir),
            ("%computername%",$env:computername),
            ("%localappdata%",$env:localappdata),
            ("%appdata%",$env:appdata),
            ("%system%","$env:windir\System32"),
            ("%commonprograms%","$Global:ProgramData\Microsoft\Windows\Start Menu\Programs"),
            ("%startmenuprograms%","$Global:ProgramData\Microsoft\Windows\Start Menu\Programs"),
            ("%ClientName%","$Global:ClientName"),
            ("%PKGGUID%","$Global:PKGGUID"),
            ("%Manufacturer%","$Global:Manufacturer"),
            ("%ProductName%","$Global:ProductName"),
            ("%ProductVersion%","$Global:ProductVersion"),
            ("%PKGBuild%","$Global:PKGBuild"),
            ("%userprofile%","$Env:userprofile"),
            ("%users%",$($Env:public).Replace("\Public","")),
            ("%username%","%username%"),
            ("%bitness%","$(Get-OSBitness)"),
            ("%sysWOW64%","$($Env:Windir)\sysWOW64"),
            ("%syswow64%","$($Env:Windir)\sysWOW64")
            )

  $VarToCheck = Set-DesktopPath -VarToCheck $VarToCheckBak
  $VarToCheck = Set-DesktopPath -VarToCheck $VarToCheck
  foreach ($var in $vars) { $VarToCheck = Set-OwerrideVar -Var $VarToCheckBak -IN $var[0] -OUT $var[1] }
  foreach ($var in $vars) { $VarToCheck = Set-OwerrideVar -Var $VarToCheck -IN $var[0] -OUT $var[1] }

  if (($VarToCheckBak.ToLower() -like "%installdir-*") -or ($VarToCheckBak.ToLower() -like "%getguid-*") -or ($VarToCheckBak.ToLower() -like "%lang-*")) {
    $specialvar = Set-SpecialVar -VarToCheck $VarToCheck
    Set-Message -Msg "Got Set-SpecialVar $VarToCheck = $specialvar." -CmdletName ${CmdletName} -Severity 1

    $tmp = $VarToCheckBak.ToLower()
    if(($tmp -like "*%%") -or ($tmp -like "*%%*") -or ($tmp -like "%%")) { $datePattern = [Regex]::new('\%(.*?)\%(.*?)\%\%') } 
    else { $datePattern = [Regex]::new('\%(.*?)\%') }

    $matchesVar = $datePattern.Matches($VarToCheck)
    $vars = $matchesVar.Value

    Set-Message -Msg "Will set specialvar to VarToCheck" -CmdletName ${CmdletName} -Severity 1

    if (($VarToCheck -like "%*") -and ($VarToCheck -like "*%*")) { $VarToCheck = $specialvar }
    else { $VarToCheck = $VarToCheck.Replace($vars,$specialvar) }
  }

  $Vars = Get-VarFromString -VarToCheck $VarToCheckBak

  foreach($Var in $Vars) {
    $Value = $Var.Value
    if ((($Value -like "%*") -or ($Value -like "*%*")) -and (-not(($Value -like "*%%*") -or ($Value -like "*%%") -or ($Value -like "%%*")))) { $SimValue = $Value.Replace("%","") } 
    else { $SimValue = $Value }

    if (($Value -ne "") -and (-not([string]::IsNullOrEmpty($Value)))) {
      $tmpName = (Get-Variable $SimValue -Scope Global -ErrorAction 'Ignore').Name
      if ($tmpName -eq $SimValue) {
        $VarValue = (Get-Variable $SimValue -Scope Global -ErrorAction 'Ignore').Value
        if (($originalString -eq $VarToCheckBak) -and ($originalString.ToLower -ne $VarToCheck)) { $VarToCheck = $VarToCheck.Replace("$Value","$VarValue"); }
        else { $VarToCheck = $VarToCheckBak.Replace("$Value","$VarValue"); }
      }

      $tmpVars = Set-SysVars -VarToCheck $VarToCheckBak
      if ($tmpVars -ne 'null') {
        <# foreach ($kvp in $tmpVars.GetEnumerator()) {
          $key = $kvp.Name
          $val = $kvp.Value
          if (-not([string]::IsNullOrWhitespace($key))) { Set-Message -Msg "Getting: $key - $val" -CmdletName ${CmdletName} -Severity 1 }
        } #>
        foreach ($tmpVar in $tmpVars) {
          Set-Message -Msg "Getting: $tmpVar" -CmdletName ${CmdletName} -Severity 1
          $VarName = $tmpVar.Name
          $VarValue = $tmpVar.Value
          Set-Message -Msg "Getting: $VarName - $VarValue" -CmdletName ${CmdletName} -Severity 1
          if (($originalString -eq $VarToCheckBak) -and ($originalString.ToLower -ne $VarToCheck)) { $VarToCheck = $VarToCheck.Replace("$Value","$VarValue"); }
          else { $VarToCheck = $VarToCheckBak.Replace("$Value","$VarValue"); }
        }
      } 
    }
  }

  #$VarToCheckBak = Get-ScriptGlobals -originalString $VarToCheckBak -VarToCheckBak $VarToCheckBak -VarToCheck $VarToCheck
  #$VarToCheck = Get-ScriptGlobals -originalString $VarToCheck -VarToCheckBak $VarToCheckBak -VarToCheck $VarToCheck
  
  if (($originalString -ne $VarToCheckBak) -and ($originalString.ToLower -eq $VarToCheck)) { Return $VarToCheckBak }
  elseif (($originalString -eq $VarToCheckBak) -and ($originalString.ToLower -ne $VarToCheck)) { Return $VarToCheck }
  elseif (($originalString -eq $VarToCheckBak) -and ($originalString.ToLower -eq $VarToCheck)) { Return $VarToCheckBak }
  elseif (($originalString -ne $VarToCheckBak) -and ($originalString.ToLower -ne $VarToCheck)) { Return $VarToCheckBak }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Get-SystemLanguage {
  param(
    [Parameter(Mandatory = $False)]
    [String]$RCType = "standard",  #standard, code
    [Parameter(Mandatory = $False)]
    [String]$AcceptedLangs = "english"
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  #%lang-english;german%

  Set-Message -Msg "Will checkif system have $AcceptedLangs language." -CmdletName ${CmdletName} -Severity 1
  $AcceptedLangs = $AcceptedLangs.Replace(" ","").Replace("%","").Replace("-","")

  If ($AcceptedLangs -like "*;*") { $AL = $AcceptedLangs.split(";") }
  else { $AL = $AcceptedLangs }
  
  $LCID = (Get-WinSystemLocale).LCID
  $RC = 'english'
  $found = $False
  
  $English = @(1033, 3081, 10249, 4105, 9225, 6153, 8201, 5129, 13321, 7177, 11273, 2057, 12297)
	$German	= @(1031, 3079, 5127, 4103, 2055)
	$Dutch = @(1043, 2067)
	$Japanese = @(1041)
	$French = @(1036, 2060, 3084, 5132, 6156, 4108)
	$Spanish = @(3082, 8202, 14346, 1034, 20490, 10250, 15370, 6154, 19466, 2058, 18442, 4106, 17418, 12298, 7178, 5130, 9226, 13322, 16394, 11274)
	$Italian = @(1040, 2064)
	$Turkish = @(1055)
	$Polish = @(1045)
	$Czech = @(1029)

  foreach ($lang in $English) { if ($LCID -eq $lang) { $RC = 'english' } }
  foreach ($lang in $German) { if ($LCID -eq $lang) { $RC = 'german' } }
  foreach ($lang in $Dutch) { if ($LCID -eq $lang) { $RC = 'dutch' } }
  foreach ($lang in $Japanese) { if ($LCID -eq $lang) { $RC = 'japanese' } }
  foreach ($lang in $French) { if ($LCID -eq $lang) { $RC = 'jrench' } }
  foreach ($lang in $Spanish) { if ($LCID -eq $lang) { $RC = 'spanish' } }
  foreach ($lang in $Italian) { if ($LCID -eq $lang) { $RC = 'italian' } }
  foreach ($lang in $Turkish) { if ($LCID -eq $lang) { $RC = 'turkish' } }
  foreach ($lang in $Polish) { if ($LCID -eq $lang) { $RC = 'polish' } }
  foreach ($lang in $Czech) { if ($LCID -eq $lang) { $RC = 'czech' } }

  Set-Message -Msg "Found $RC language." -CmdletName ${CmdletName} -Severity 1

  foreach ($lang in $AL) {
    if ($lang -ceq $RC) { 
      $tmpLang = $RC 
      $found = $True
    }
  }

  if ($found -eq $False) { $RC = 'english' } 
  else { $RC = $tmpLang }

  Set-Message -Msg "Will return $RC language." -CmdletName ${CmdletName} -Severity 1

  Return $RC
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Get-IsLike {
  param(
    [Parameter(Mandatory = $True)]
    [AllowEmptyString()]
    [String]$VarToTest,
    [Parameter(Mandatory = $True)]
    [AllowEmptyString()]
    [String]$VarToChange
  )

  #[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  #Set-Message -Msg "Checking if $VarToChange = $VarToTest." -CmdletName ${CmdletName}

  if (($VarToChange -like "$VarToTest*") -or ($VarToChange -like "*$VarToTest*") -or ($VarToChange -like "$VarToTest") -or ($VarToChange -like "*$VarToTest")) { return $true }
  else { return $false }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Get-ParamCheck {
  param(
    [Parameter(Mandatory = $True)]
    [String]$ParamName,
    [Parameter(Mandatory = $False)]
    [String]$Param = " "
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  If (($Param -ne "") -and ($Param -ne "null") -and ($Param -ne $ParamName)) { Write-Log -Message "$ParamName = $Param = True" -Source ${CmdletName}; Return $True }
  else { Write-Log -Message "$ParamName = $Param = False" -Source ${CmdletName}; Return $False }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-AccountBP {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$CN
  )

  #Get-DiscSpace
  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  if ([string]::IsNullOrWhitespace($CN) -or ($CN -eq "") -or ($null -eq $CN)) { $Global:clientBasedBP = $False }
  else {
    $iniProperties = @("AccountNameVar","TitleVar","TimeVar","isForUDP","IsLangWindow","IsKillingWindow","IsUninstallKillingWindow","IsKillingWindowAlwaysON","IsProcessSentenceInRed","IsNetworkDisconnect","arpSubstitiute","arpSubstitiuteMode","arpSubstitiutePublisher" `
                      ,"IsInstallRebootRequired","IsUninstallRebootRequired","IsSuccessFinalizeMsg","IsFailFinalizeMsg","EnableKillAction","ProcessWindowType","HowManyStrikesVar","StrikeWindowActive","StrikeWindowActiveUninstall" `
                      ,"StrikeWindowIsPersistent","PBMode","ProgressBarActive","UninstallProgressBarActive","InstallProgressBarTitle","UninstallProgressBarTitle","InstallProgressBarCaption" `
                      ,"UninstallProgressBarCaption","OneFileSetup","LOGType","TAGType","PreLogDir","PreTAGDir","TempDirPath","UserTempDirPath","PrecheckIsInstalled","IsForceKillingVar","no3010","userActions","blnFthStrikeActive","selfCopy" `
                      ,"forServer","MSIWrapperRequired","EntryRequestURL","G_MessageInstallOptional1","G_MessageInstallOptional2","G_MessageInstallOptional3","G_MessageInstallOptional4" `
                      ,"G_MessageInstallOptional5","G_MessageInstallOptional6","G_MessageInstallOptional7","G_MessageInstallOptional8","G_MessageInstallRequired1","G_MessageInstallRequired2" `
                      ,"G_MessageInstallRequired3","G_MessageInstallRequired4","G_MessageInstallRequired5","G_MessageInstallRequired6","G_MessageInstallRequired7","G_MessageInstallIfRebootRequired","EnableBuildInWindows","msiexecAdditionalParams")

    $INIFile = "$PSScriptRoot\AccountSpecific\$CN.ini"

    If (Test-Path -Path $INIFile) {
      $Global:clientBasedBP = $True
      $iniFileContent = Get-Content -Path $INIFile

      ForEach ($Name in $iniProperties) {
        $tmpName = (Get-Variable $Name -Scope Global -ErrorAction 'Ignore').Name
        if ($tmpName -eq $Name) { Remove-Variable -Name $Name -Scope "Global" -ErrorAction SilentlyContinue }
      }

      ForEach ($Name in $iniProperties) {
        $searchString = "$Name"
        $AppLine = $iniFileContent | Where-Object { $_ -match "$searchString" }
        $AppValueA = $AppLine.Split("=")
        $AppValueA = $AppValueA.replace($searchString,"")
        $AppValueA = $AppValueA.trim()
        $AppValue = $AppValueA[1]

        if ([string]::IsNullOrWhitespace($AppValue) -or ($AppValue -eq "") -or ($null -eq $AppValue)) { $AppValue = "N/A" }
        If (-not ([string]::IsNullOrWhitespace($PKGName) -and ($PKGName -eq "") -and ($null -eq $PKGName))) { $AppValue = $AppValue.replace("<PKGName>", $PKGName) }
        else { $AppValue = $AppValue.replace("<PKGName>", "") }

        $AppValue = Set-Env -varValue $AppValue
        New-Variable -Name $Name -Value $AppValue -Scope "Global"
        $tempForValidation = Get-Variable $Name -ErrorAction SilentlyContinue

        If (-not([string]::IsNullOrEmpty($tempForValidation))) { 
          if ($tempForValidation.Value -eq $AppValue) { Set-Message -Msg "Name $Name, Value $AppValue was added." -CmdletName ${CmdletName} -Severity 1 } 
          else { Set-Message -Msg "Name $Name, Value $AppValue is missing." -CmdletName ${CmdletName} -Severity 3; Set-Finalize -ExitCode 1 } 
        } else { Set-Message -Msg "Name $Name, Value $AppValue is missing." -CmdletName ${CmdletName} -Severity 3; Set-Finalize -ExitCode 1 }
      }
    } Else { 
      $Global:clientBasedBP = $False
      Set-Message -Msg "ini file: $INIFile is missing. Will stop execution." -CmdletName ${CmdletName} -Severity 3
      Set-Finalize -ExitCode -100
    }

    If (($Global:UserTempDirPath -ne '') -and (-not ([string]::IsNullOrWhitespace($Global:UserTempDirPath)))) {
      if ((Test-Path variable:global:AppName) -eq $True) { $Global:UserTempDirPath = $Global:UserTempDirPath.replace("<AppName>", $Global:AppName) } 
      else { $Global:UserTempDirPath = $Global:UserTempDirPath.replace("<AppName>", $Global:ProductName) }
      $Global:UserTempDirPath = $Global:UserTempDirPath.Replace("<Manufacturer>", $Global:Manufacturer)
      $Global:UserTempDirPath = $Global:UserTempDirPath.Replace("<ProductName>", $Global:ProductName)

      if ((Test-Path variable:global:PKGBuild) -eq $True) { 
        If ($Global:PKGBuild -ne 0) { $Global:UserTempDirPath = $Global:UserTempDirPath.Replace("<AppVersion>", "$($Global:ProductVersion).$(($Global:PKGBuild)+1)") } 
        else { $Global:UserTempDirPath = $Global:UserTempDirPath.Replace("<AppVersion>", $Global:ProductVersion) }
      } else { $Global:UserTempDirPath = $Global:UserTempDirPath.Replace("<AppVersion>", $Global:ProductVersion) }

      $Global:UserTempDirPath = $Global:UserTempDirPath.Replace("<ProductVersion>", $Global:ProductVersion)
      $Global:UserTempDirPath = $Global:UserTempDirPath.replace("<PKGName>", $Global:PKGName)
      $Global:UserTempDirPath = Set-StringFromVarLayered -VarToCheck $Global:UserTempDirPath 
    }

    If (($Global:PreLogDir -ne '') -and (-not ([string]::IsNullOrWhitespace($Global:PreLogDir)))) {
      $Global:PreLogDir = $Global:PreLogDir.replace("<PKGName>", $Global:PKGName)
      $Global:PreLogDir = $Global:PreLogDir.replace("<Manufacturer>", $Global:Manufacturer)
      if ((Test-Path variable:global:AppName) -eq $True) { $Global:PreLogDir = $Global:PreLogDir.replace("<AppName>", $Global:AppName) } 
      else { $Global:PreLogDir = $Global:PreLogDir.replace("<AppName>", $Global:ProductName) }
      if ((Test-Path variable:global:PKGBuild) -eq $True) { 
        If ($Global:PKGBuild -ne 0) { $Global:PreLogDir = $Global:PreLogDir.Replace("<AppVersion>", "$($Global:ProductVersion).$(($Global:PKGBuild)+1)") } 
        else { $Global:PreLogDir = $Global:PreLogDir.Replace("<AppVersion>", $Global:ProductVersion) }
      } else { $Global:PreLogDir = $Global:PreLogDir.Replace("<AppVersion>", $Global:ProductVersion) }
      $Global:PreLogDir = Set-StringFromVarLayered -VarToCheck $Global:PreLogDir 
    }

    If (($Global:TempDirPath -ne '') -and (-not ([string]::IsNullOrWhitespace($Global:TempDirPath)))) {
      $Global:IBMSRC = $Global:TempDirPath
      $Global:IBMSRC = Set-StringFromVarLayered -VarToCheck $Global:IBMSRC

      Set-Message -Msg "PreTAGDir = $($Global:PreTAGDir)" -CmdletName ${CmdletName} -Severity 1
      $Global:TagsDir = $Global:PreTAGDir
      $Global:TagsDir = Set-StringFromVarLayered -VarToCheck $Global:TagsDir
    }
  }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Test-ParamFile {
  param(
    [Parameter(Mandatory = $True)]
    [String]$path
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  Write-Log -Message "Testing if: $path is a path or file and if param exist." -Source ${CmdletName}
  $path = Set-StringFromVarLayered -VarToCheck $path
  Write-Log -Message "Testing if: $path is a path or file and if param exist." -Source ${CmdletName}

  If ((Test-Path -Path $path) -eq $True) { Write-Log -Message "Path: $path exist, going next."; Return $True }
  elseif (([System.IO.File]::Exists($path)) -eq $True) { Write-Log -Message "File: $path exist, going next." -Source ${CmdletName}; Return $True }
  elseif ("null" -eq $path) { Write-Log -Message "Skipping param, is null." -Source ${CmdletName}; Return $True }
  else { Write-Log -Message "$path missing, exiting script with RC = -1." -Source ${CmdletName}; Set-Finalize -ExitCode -1 }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-Env {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$varValue
  )

  #[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  if ([string]::IsNullOrWhitespace($varValue) -or ($varValue -eq "") -or ($null -eq $varValue)) { $newEnvVar = $varValue }
  Else {
    If ($varValue -like "%*") {
      $varValueTmp = $varValue.Split("%")
      $varValuecheck = "%"+$varValueTmp[1]+"%"
      $newEnvVarTmp = Set-StringFromVarLayered -VarToCheck $varValuecheck.ToLower()
      $newEnvVarTmp = $newEnvVarTmp+$varValueTmp[2]
    } else { $newEnvVarTmp = $varValue }
    $newEnvVar = $newEnvVarTmp
  }

  Return $newEnvVar
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Show-ClientBasedWindow {
  param(
    [Parameter(Mandatory = $True)]
    [String]$CloseApps
  )

  #[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  # Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent
  #ive used -ine insted of -ne ?

  If ($TmpDeployMode -ne 'null') {
    Write-Log -Message "Show-ClientBasedWindow will proceed." -Source ${CmdletName}
    If ((($blnFthStrikeActive -eq $True) -AND ($deploymentType -ine 'Uninstall')) -and ($TmpDeployMode -eq 'Interactive')) { $newEnvVar = Show-FthStrikeWindowHTA }
    If (((($IsKillingWindow -eq $True) -AND ($deploymentType -ine 'Uninstall')) -OR (($IsUninstallKillingWindow -eq $True) -AND ($deploymentType -ieq 'Uninstall'))) -and ($TmpDeployMode -eq 'Interactive')) { $newEnvVar = Show-ProcessWindowHTA }
    If ((($deploymentType -ine 'Uninstall') -AND ($LanguagesToUse -ine "")) -and ($TmpDeployMode -eq 'Interactive')) { $Global:selectedLang = Select-LanguageWindow }
    If (((($IsKillingWindow -eq $False) -AND ($deploymentType -ine 'Uninstall')) -OR (($IsUninstallKillingWindow -eq $False) -AND ($deploymentType -ieq 'Uninstall'))) -and ($TmpDeployMode -ne 'NonInteractive')) { Set-ProgressBar }
    If ((($StrikeWindowActiveUninstall -eq $True) -AND ($deploymentType -ieq 'Uninstall')) -and ($TmpDeployMode -eq 'Interactive')) { $newEnvVar = Show-FthStrikeWindowHTA }
    If ((($StrikeWindowActive -eq $True) -AND ($deploymentType -ieq 'Install')) -and ($TmpDeployMode -eq 'Interactive')) { $newEnvVar = Show-FthStrikeWindowHTA }
  }
  Return $newEnvVar
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Send-UDPData {
  param(
    $data="empty",
    $address="Loopback",
    $port=2020
	)

  #[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  try{
    $endpoint = new-object System.Net.IPEndPoint( [IPAddress]::$address, $port )
    $udpclient = new-object System.Net.Sockets.UdpClient
  } catch{
    throw $_
    exit -1
  }

  $bytes = [Text.Encoding]::ASCII.GetBytes( $data )
  $bytesSent = $udpclient.Send( $bytes, $bytes.length, $endpoint )

  $udpclient.Close( )
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Get-UDPData {
	param(
		$address="Any",
		$port=2021
	)

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

	try {
		$endpoint = new-object System.Net.IPEndPoint( [IPAddress]::$address, $port )
		$udpclient = new-object System.Net.Sockets.UdpClient $port
	} catch {
		throw $_
		exit -1
	}

	while ($true) {
		if ($udpclient.Available) {
			$content = $udpclient.Receive([ref]$endpoint)
			$rVal = $([Text.Encoding]::ASCII.GetString($content))
			Write-Log -Message "$($endpoint.Address.IPAddressToString):$($endpoint.Port) $rVal" -Source ${CmdletName}

			$udpclient.Close( )
			Return $rVal
		}
	}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function Set-RegistryValueForAllUnloadedUsers {
  [CmdletBinding(SupportsShouldProcess = $false)]
	param(
		$Name,
    $Type,
    $Value,
    $Path,
    $Action
	)

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  # Regex pattern for SIDs
  $LocalSID     = 'S-1-5-21-\d+-\d+\-\d+\-\d+$'
  $AdSID        = 'S-1-12-1-\d+-\d+-\d+-\d+$'
  $PatternsSID  = @($LocalSID, $AdSID)

  if ($Global:userActions.ToLower() -eq 'false') { 
    Write-Log -Message "Will skipp ${CmdletName} execution. userActions = $($Global:userActions)." -Source ${CmdletName} -Severity 3
    Write-Log -Message "For your account use an other method for actions in user context/manipulation of user profiles." -Source ${CmdletName} -Severity 3 
  } else {
    foreach ($PSID in $PatternsSID) {
      $RC = Get-ProfileList -PatternSID $PSID
      if (([string]::IsNullOrEmpty($RC)) -and ([string]::IsNullOrWhitespace($RC))) { Write-Log "$PSID missing on machine."  }
      else { 
        $ProfileList = $RC
        $PatternSID = $PSID
        Write-Log "$PSID found on machine, will be used."

        # Get all user SIDs found in HKEY_USERS (ntuder.dat files that are loaded)
        $LoadedHives = Get-ChildItem Registry::HKEY_USERS | Where-Object {$_.PSChildname -match $PatternSID} | Select-Object @{name="SID";expression={$_.PSChildName}}

        # Get all users that are not currently logged
        $UnloadedHives = Compare-Object $ProfileList.SID $LoadedHives.SID | Select-Object @{name="SID";expression={$_.InputObject}}, UserHive, Username

        if (($Path.ToUpper() -like "*.DEFAULT*") -or ($Path.ToUpper() -like "*.DEFAULT")) {
          Write-Log -Message "Detected .Default profile in Path: $Path. Will skipp other users profiles." -Source ${CmdletName}

          $key = "Registry::HKEY_USERS\$Path"
          Write-Log -Message "Will edit .Default profile: $Path" -Source ${CmdletName}
          Write-Log -Message "Set-RegistryValueForAllUnloadedUsers will change key: $key" -Source ${CmdletName}

          if (($Action -eq "ADD") -or ($Action -eq "CHANGE")) {
            Write-Log -Message "Set-RegistryValueForAllUnloadedUsers will add or chage $key" -Source ${CmdletName}
            if (($Name -eq "null") -and ($Name -eq "null") -and ($Name -eq "null")) {
              Write-Log -Message "Set-RegistryKey -Key $Key" -Source ${CmdletName}
              Set-RegistryKey -Key $Key
            } else {
              If (-not (Get-ItemProperty -LiteralPath $key -Name $Name)) {
                If (($Key.ToLower() -ne "null") -and ($Name.ToLower() -ne "null") -and ($Type -ne "null") -and ($Value.ToLower() -ne "null")) { Set-RegistryKey -Key $Key -Name $Name -Type $Type -Value $Value }
                ElseIf (($Key.ToLower() -ne "null") -and ($Name.ToLower() -ne "null") -and ($Value.ToLower() -ne "null")) { Set-RegistryKey -Key $Key -Name $Name -Value $Value }
                ElseIf (($Key.ToLower() -ne "null") -and ($Value.ToLower() -ne "null")) { Set-RegistryKey -Key $Key -Value $Value }
              } Else {
                Write-Log -Message "Registry key $key\$name exists. Removing the key." -Source ${CmdletName}
                Remove-RegistryKey -Key $Key -Name $Name -Recurse
                If (($Key.ToLower() -ne "null") -and ($Name.ToLower() -ne "null") -and ($Type -ne "null") -and ($Value.ToLower() -ne "null")) { Set-RegistryKey -Key $Key -Name $Name -Type $Type -Value $Value }
                ElseIf (($Key.ToLower() -ne "null") -and ($Name.ToLower() -ne "null") -and ($Value.ToLower() -ne "null")) { Set-RegistryKey -Key $Key -Name $Name -Value $Value }
                ElseIf (($Key.ToLower() -ne "null") -and ($Value.ToLower() -ne "null")) { Set-RegistryKey -Key $Key -Value $Value }
              }
            }
          } elseif ($Action -eq "REMOVE") {
            Write-Log -Message "Set-RegistryValueForAllUnloadedUsers will remove $key" -Source ${CmdletName}
            If (($Key.ToLower() -ne "null") -and ($Name.ToLower() -ne "null")) { Remove-RegistryKey -Key $Key -Name $Name -Recurse }
            else { Remove-RegistryKey -Key $Key -Recurse }
          }

        } else { 
          # Loop through each profile on the machine
          Foreach ($item in $ProfileList) {
            # Load User ntuser.dat if it's not already loaded
            IF ($item.SID -in $UnloadedHives.SID) {
              Write-Log -Message "Loading: HKU\$($Item.SID) $($Item.UserHive)" -Source ${CmdletName}
              reg load HKU\$($Item.SID) $($Item.UserHive) | Out-Null
            }

            #####################################################################
            # This is where you can read/modify a users portion of the registry

            $key = "Registry::HKEY_USERS\$($Item.SID)\$Path"
            Write-Log -Message "Set-RegistryValueForAllUnloadedUsers will change key: $key" -Source ${CmdletName}

            if (($Action -eq "ADD") -or ($Action -eq "CHANGE")) {
              Write-Log -Message "Set-RegistryValueForAllUnloadedUsers will add or chage $key" -Source ${CmdletName}
              if (($Name -eq "null") -and ($Name -eq "null") -and ($Name -eq "null")) {
                Write-Log -Message "Set-RegistryKey -Key $Key" -Source ${CmdletName}
                Set-RegistryKey -Key $Key
              } else {
                If (-not (Get-ItemProperty -LiteralPath $key -Name $Name)) {
                  If (($Key.ToLower() -ne "null") -and ($Name.ToLower() -ne "null") -and ($Type -ne "null") -and ($Value.ToLower() -ne "null")) { Set-RegistryKey -Key $Key -Name $Name -Type $Type -Value $Value }
                  ElseIf (($Key.ToLower() -ne "null") -and ($Name.ToLower() -ne "null") -and ($Value.ToLower() -ne "null")) { Set-RegistryKey -Key $Key -Name $Name -Value $Value }
                  ElseIf (($Key.ToLower() -ne "null") -and ($Value.ToLower() -ne "null")) { Set-RegistryKey -Key $Key -Value $Value }
                } Else {
                  Write-Log -Message "Registry key $key\$name exists. Removing the key." -Source ${CmdletName}
                  Remove-RegistryKey -Key $Key -Name $Name -Recurse
                  If (($Key.ToLower() -ne "null") -and ($Name.ToLower() -ne "null") -and ($Type -ne "null") -and ($Value.ToLower() -ne "null")) { Set-RegistryKey -Key $Key -Name $Name -Type $Type -Value $Value }
                  ElseIf (($Key.ToLower() -ne "null") -and ($Name.ToLower() -ne "null") -and ($Value.ToLower() -ne "null")) { Set-RegistryKey -Key $Key -Name $Name -Value $Value }
                  ElseIf (($Key.ToLower() -ne "null") -and ($Value.ToLower() -ne "null")) { Set-RegistryKey -Key $Key -Value $Value }
                }
              }
            } elseif ($Action -eq "REMOVE") {
              Write-Log -Message "Set-RegistryValueForAllUnloadedUsers will remove $key" -Source ${CmdletName}
              If (($Key.ToLower() -ne "null") -and ($Name.ToLower() -ne "null")) { Remove-RegistryKey -Key $Key -Name $Name -Recurse }
              else { Remove-RegistryKey -Key $Key -Recurse }
            }

            Write-Log -Message "Handling: $($item.Username) - $($Item.SID)" -Source ${CmdletName}

            #####################################################################
            # Unload ntuser.dat
            IF ($item.SID -in $UnloadedHives.SID) {
              ### Garbage collection and closing of ntuser.dat ###
              Write-Log -Message "Uloading: HKU\$($Item.SID)" -Source ${CmdletName}
              [gc]::Collect()
              reg unload HKU\$($Item.SID) | Out-Null
            }
          }

          $key = "Registry::HKEY_USERS\.DEFAULT\$Path"
          Write-Log -Message "Will edit .Default profile: $Path" -Source ${CmdletName}
          Write-Log -Message "Set-RegistryValueForAllUnloadedUsers will change key: $key" -Source ${CmdletName}
        
          if (($Action -eq "ADD") -or ($Action -eq "CHANGE")) {
            Write-Log -Message "Set-RegistryValueForAllUnloadedUsers will add or chage $key" -Source ${CmdletName}
            if (($Name -eq "null") -and ($Name -eq "null") -and ($Name -eq "null")) {
              Write-Log -Message "Set-RegistryKey -Key $Key" -Source ${CmdletName}
              Set-RegistryKey -Key $Key
            } else {
              If (-not (Get-ItemProperty -LiteralPath $key -Name $Name)) {
                If (($Key.ToLower() -ne "null") -and ($Name.ToLower() -ne "null") -and ($Type -ne "null") -and ($Value.ToLower() -ne "null")) { Set-RegistryKey -Key $Key -Name $Name -Type $Type -Value $Value }
                ElseIf (($Key.ToLower() -ne "null") -and ($Name.ToLower() -ne "null") -and ($Value.ToLower() -ne "null")) { Set-RegistryKey -Key $Key -Name $Name -Value $Value }
                ElseIf (($Key.ToLower() -ne "null") -and ($Value.ToLower() -ne "null")) { Set-RegistryKey -Key $Key -Value $Value }
              } Else {
                Write-Log -Message "Registry key $key\$name exists. Removing the key." -Source ${CmdletName}
                Remove-RegistryKey -Key $Key -Name $Name -Recurse
                If (($Key.ToLower() -ne "null") -and ($Name.ToLower() -ne "null") -and ($Type -ne "null") -and ($Value.ToLower() -ne "null")) { Set-RegistryKey -Key $Key -Name $Name -Type $Type -Value $Value }
                ElseIf (($Key.ToLower() -ne "null") -and ($Name.ToLower() -ne "null") -and ($Value.ToLower() -ne "null")) { Set-RegistryKey -Key $Key -Name $Name -Value $Value }
                ElseIf (($Key.ToLower() -ne "null") -and ($Value.ToLower() -ne "null")) { Set-RegistryKey -Key $Key -Value $Value }
              }
            }
          } elseif ($Action -eq "REMOVE") {
            Write-Log -Message "Set-RegistryValueForAllUnloadedUsers will remove $key" -Source ${CmdletName}
            If (($Key.ToLower() -ne "null") -and ($Name.ToLower() -ne "null")) { Remove-RegistryKey -Key $Key -Name $Name -Recurse }
            else { Remove-RegistryKey -Key $Key -Recurse }
          }
        }

        Write-Log -Message "Handling: $($item.Username) - $($Item.SID)" -Source ${CmdletName}
      }
    }
  }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Test-InstState {
	param(
		$procName,
		$PKGName
	)

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  Write-Log -Message "Waiting for process before ending." -Source ${CmdletName}
  Start-Sleep -s 15

  $procName = $procName.Replace("*","%")

  #if ($procName -like "*;*") { $procName = $procName.Split(";") }

  Write-Log -Message "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@" -Source ${CmdletName}
  Write-Log -Message "Found: procName - $procName" -Source ${CmdletName}
  Write-Log -Message "Found: PKGName - $PKGName" -Source ${CmdletName}
  Write-Log -Message "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@" -Source ${CmdletName}

  #ForEach ($ProcInst in $procName) {
    $proc = Get-CimInstance -Query "SELECT * from Win32_Process WHERE name LIKE '$procName'"
    #$proc = Get-CimInstance Win32_Process -Filter "name = '$procName'"

    Write-Log -Message "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@" -Source ${CmdletName}
    Write-Log -Message "Found: proc - $proc" -Source ${CmdletName}
    Write-Log -Message "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@" -Source ${CmdletName}

    if([string]::IsNullOrEmpty($proc)) { Write-Log -Message "No process running." }
    else {
      Write-Log -Message "Process running. Waiting for end." -Source ${CmdletName}
      if (($isProcess.ToLower() -like "cscript.exe") -or ($isProcess.ToLower() -like "wscript.exe")) {
        $processes = $proc

        Write-Log -Message "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@" -Source ${CmdletName}
        Write-Log -Message "Found: processes - $processes" -Source ${CmdletName}
        Write-Log -Message "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@" -Source ${CmdletName}

        foreach ($process in $processes) {
          if ($process.CommandLine -like "*$PKGName*") {
            $CMD = $process.CommandLine
            $nid = $process.ProcessId
            Write-Log -Message "Waiting for $CMD (id = $nid) to end." -Source ${CmdletName}
            Wait-Process -Id $nid
          }
        }
      } else {
        $nid = $proc.ProcessId
        Write-Log -Message "Waiting for $isProcess (id = $nid) to end." -Source ${CmdletName}
        Wait-Process -Id $nid
      }
      Write-Log -Message "Process ended." -Source ${CmdletName}
    }
  #}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-Finalize {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$ExitCode
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

	if (Get-Command 'Write-Log' -errorAction SilentlyContinue) { Write-Log -Message "-------------------------------------------------------------------------Set-Finalize: $ExitCode, deploymentType: $deploymentType" -Source ${CmdletName} }

	If ($Global:clientBasedBP -eq $True) {
    $installSuccess = $false
    $AllowRebootPassThru = $True
    $showUI = $true
    if ($Global:UserContextVar.ToLower() -eq 'user') { $addTag = $false }
    else { $addTag = $true }

    foreach ($EC in $Global:SuccessRC) { if ($exitCode -eq $EC) { $installSuccess = $true }}
    foreach ($EC in $Global:SkipVindowsRC) { if ($exitCode -eq $EC) { $showUI = $false }}
    foreach ($EC in $Global:SkipTagRC) { if ($exitCode -eq $EC) { $addTag = $false }}

		If ($installSuccess) { Clean-ProcessesWindowReg $Global:PKGName }
		If (($blnFthStrikeActive -eq $True) -AND ($deploymentType.ToLower() -ine 'uninstall')) {
			If (($RebootContainer -eq $True) -OR ($ExitCode -eq 3010)) { $blnRebootNeeded = $True }
			If ($SilentInstall -eq $False) {
				Stop-Process -Name "mshta" -force

				If ($installSuccess) {
					Clean-FthStrikeHTA
					if ($showUI -eq $true) { Show-CompletionDialogHTA -Mode "SUCCESS" }
				}
			}
		}

		If (($selfCopy -eq $True) -AND ($deploymentType.ToLower() -ine 'uninstall')) { <#SubstituteARP(AppGUID)#> }
		ElseIf (($selfCopy -eq $True) -AND ($deploymentType.ToLower() -ieq 'uninstall')) {
			#If CheckIfKeyExist(strNKey & "\") = 0 { <#Call RemoveKey(strNKey & "\")#> }
			#If IsExistD(TempDirPath) = 0 { <#Call RemoveDirectory(TempDirPath, False)#> }
		}

    $badConf = -1999

		
		if (($Global:arpSubstitiute.ToLower() -eq "true") -and ($deploymentType.ToLower() -ine 'uninstall')) { 
			If ((($RebootContainer -eq $True) -OR ($ExitCode -eq 3010)) -or (($ExitCode -eq 0) -or ($ExitCode -eq 3010) -or ($ExitCode -eq 1641))) {
				Write-Log -Message  "Will try to set an customized substituted ARP entry." -Severity 1 -Source ${CmdletName}
				Set-ARPsubstitute -GUID $Global:PKGGUID
			}
		} elseif (($Global:arpSubstitiute.ToLower() -eq "true") -and ($deploymentType.ToLower() -ine 'install')) {
			Remove-ARPsubstitute -GUID $Global:PKGGUID
		}

		If (($ExitCode -eq $badConf)) { Write-Log -Message  "There is an error in conf file." -Severity 3  -Source ${CmdletName}}

		If (($AllowRebootPassThru) -AND (-NOT ($ExitCode -eq 0)) -AND (-NOT ($ExitCode -eq 3010)) -AND (-NOT ($ExitCode -eq 1641))) {
			Write-Log -Message  "RetCode is not equal to 0 or 3010 or 1641. Ignoring RebootContainer value." -Severity 1 -Source ${CmdletName}
			$AllowRebootPassThru = $False
		}

		If (($AllowRebootPassThru) -and ($ExitCode -eq 3010)) { Write-Log -Message "AllowRebootPassThru is true, passing 3010 as ExitCode will walidate no3010 later."; $ExitCode = 3010 }								                                            #RebootContainer is set to "True" only in case of success
		If (($ExitCode -eq 3010) -AND (($Global:no3010 -eq $True) -or ($Global:no3010.ToLower() -eq "true"))) { 
      Write-Log -Message "AllowRebootPassThru is $AllowRebootPassThru and ExitCode = 3010, no3010 (it have higher prority) is true so changing 3010 to 0 as ExitCode." -Source ${CmdletName}; 
      $ExitCode = 0 
    }	#Change reboot required exit code from 3010 to 0

		#Hide progress bar:
		If (($deploymentType.ToLower() -ine 'uninstall') -and ($Global:ProgressBarActive.ToLower() -eq "true")) { Hide-ProgressBar -TitleHPB $Global:InstallProgressBarTitle }
		Else { if ($Global:UninstallProgressBarActive.ToLower() -eq "true") { Hide-ProgressBar -TitleHPB $Global:UninstallProgressBarTitle } }

		#Display completion dialog, if needed:
		If (($IsSuccessFinalizeMsg -eq $True) -AND ($SilentInstall -eq $False) -AND ($installSuccess)) {
			If ((($deploymentType.ToLower() -ine 'uninstall') -AND ($IsInstallRebootRequired -eq $False)) -OR (($deploymentType.ToLower() -ieq 'uninstall') -AND ($IsUninstallRebootRequired -eq $False))) {
				if ($showUI -eq $true) { Show-CompletionDialogHTA -Mode "SUCCESS" }
			} Else {
				if ($showUI -eq $true) { Show-CompletionDialogHTA -Mode "SUCCESS REBOOT" }
			}
		} ElseIf (($IsFailFinalizeMsg -eq $True) -AND ($SilentInstall -eq $False)) {
			if ($showUI -eq $true) { Show-CompletionDialogHTA -Mode "FAILURE" }
    }

    if (($TAGType.ToUpper() -ne "NONE") -or ($TAGType.ToUpper() -ne "N/A")) {
      Write-Log -Message  "Automatic TAG creation: $($Global:PKGName),$($Global:TAGType)" -Source ${CmdletName}
      $Data = @($Global:PKGName,$Global:TAGType)
      
      Write-Log -Message  "deploymentType = $deploymentType, addTag = $addTag, installSuccess = $installSuccess" -Source ${CmdletName}
      if ($deploymentType.ToLower() -ine 'uninstall') {
        if (($addTag -eq $true) -and ($installSuccess -eq $true)) { Set-Tag -actionName "ADD" -Data $Data }
        if ($installSuccess -eq $false) { Set-Tag -actionName "REMOVE" -Data $Data }
      } else { Set-Tag -actionName "REMOVE" -Data $Data }
    }
	}

  if ($installSuccess -eq $False) { Set-Rollback -deployment $deploymentType}

	if (Get-Command 'Write-Log' -errorAction SilentlyContinue) { Write-Log -Message "-------------------------------------------------------------------------Set-Finalize: $ExitCode, deploymentType: $deploymentType" -Source ${CmdletName} }
	Exit-Script -ExitCode $ExitCode
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Get-CMDExePath {
  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  $OSBitness = Get-OSBitness
  Write-Log -Message "Will get CMD path accordingly to OS biteness = $OSBitness." -Source ${CmdletName}

  $cmdPath = "$($Env:windir)\System32\cmd.exe"
  if ($OSBitness -eq "x64") { $cmdPath = "$($Env:windir)\SysWOW64\cmd.exe" }

  Write-Log -Message "Will return path = $cmdPath." -Source ${CmdletName}
  Return $cmdPath
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-customCMD {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    [Parameter(Mandatory = $True)]
    [String]$CmdToRun
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  $CMDExePath = Get-CMDExePath

  If (Test-Path -Path $CMDExePath -PathType Leaf) { Write-Log -Message "Starting CMD: $CmdToRun" -Source ${CmdletName} } 
  else { Write-Log -Message "$CMDExePath is missing." -Source ${CmdletName} }

  Write-Log -Message "& $CMDExePath /c $CmdToRun" -Source ${CmdletName}
  #& $CMDExePath /c "2>&1" $CmdToRun
  & $CMDExePath /c $CmdToRun
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-Rollback {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    $deployment
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  Write-Log -Message "Because of PKG failed starting Set-Rollback" -Source ${CmdletName}

  #if ($deployment -ine 'Uninstall') {
  #  Write-Log -Message "Set-Rollback with PREUNINSTALL."
  #  Set-ProjSetting -actionName "PREUNINSTALL"
  #  Write-Log -Message "Set-Rollback with UNINSTALL."
  #  Set-ProjSetting -actionName "UNINSTALL"
  #  Write-Log -Message "Set-Rollback with POSTUNINSTALL."
  #  Set-ProjSetting -actionName "POSTUNINSTALL"
  #}

  Write-Log -Message "Set-Rollback with ROLLBACK in a $deployment state." -Source ${CmdletName}
  Set-ProjSetting -actionName "ROLLBACK"

	if ($deploymentType.ToLower() -ine 'uninstall') {
		if (($Global:TAGType.ToUpper() -ne "NONE") -and ($Global:TAGType.ToUpper() -ne "N/A")) {
			$Data = @($Global:PKGName,$Global:TAGType)
			Set-Tag -actionName "REMOVE" -Data $Data
		}
	}
	
  Write-Log -Message "Ending Set-Rollback" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-CustomAcl {
  [CmdletBinding(SupportsShouldProcess = $false)]
  param(
    $lvl,
    $dir,
    $group
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  Write-Log -Message "Starting Set-CustomAcl" -Source ${CmdletName}

  if ($lvl.ToLower() -eq 'clearflags') {
    Write-Log -Message "attrib /D -i -r -a $dir" -Source ${CmdletName}
    attrib /D -i -r -a $dir
    Write-Log -Message "attrib /D /S -i -r -a $dir/*" -Source ${CmdletName}
    attrib /D /S -i -r -a $dir
  } else {
    $f = "$dir"
    $ADobject = $group
    $acl = Get-Acl $f

    $Grant = $lvl
    # Remove user/group first
    $rule = New-Object system.security.AccessControl.FileSystemAccessRule("$ADobject","Read",,,"Allow")
    $acl.RemoveAccessRuleAll($rule)

    # Add read permissions
    if ($Grant.ToLower() -eq 'readandexecute') { $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("$ADobject", "ReadAndExecute", "ContainerInherit, ObjectInherit", "None", "Allow") }
    if ($Grant.ToLower() -eq 'change') {
      $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("$ADobject", "Modify", "ContainerInherit, ObjectInherit", "Synchronize", "Allow  DeleteSubdirectoriesAndFiles")
      $acl.AddAccessRule($rule)
      $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("$ADobject", "AppendData", "ContainerInherit, ObjectInherit", "ReadAndExecute","Synchronize", "Allow  CreateFiles","DeleteSubdirectoriesAndFiles")
    }
    if ($Grant.ToLower() -eq 'modify') { $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("$ADobject", "Modify", "ContainerInherit, ObjectInherit", "None", "Allow") }
    if ($Grant.ToLower() -eq 'fullcontrol') { $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("$ADobject", "FullControl", "None", "None", "Allow") }
    if ($Grant.ToLower() -eq 'listfoldercontents') { $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("$ADobject", "ReadAndExecute", "ContainerInherit", "None", "Allow") }

    $acl.AddAccessRule($rule)
    Set-Acl $f $acl
  }

  Write-Log -Message "Ending Set-CustomAcl" -Source ${CmdletName}
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function Add-Font {
  [CmdletBinding(DefaultParameterSetName='Directory')]
  Param(
    [Parameter(Mandatory=$false,ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
    [Parameter(ParameterSetName='Directory')]
    [ValidateScript({Test-Path $_ -PathType Container })]
    [System.String[]]
    $Path,
    [Parameter(Mandatory=$false,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
    [Parameter(ParameterSetName='File')]
    [ValidateScript({Test-Path $_ -PathType Leaf })]
    [System.String]
    $FontFile,
    [Parameter(Mandatory=$false)]
    $Action = "noreboot"
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  #Set-Variable Fonts -Value 0x14 -Option ReadOnly
  $Fonts = 0x14
  $fontRegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
  $shell = New-Object -ComObject Shell.Application
  $folder = $shell.NameSpace($Fonts)
  $objfontFolder = $folder.self.Path
  $copyFlag = [string]::Format("{0:x}",4+16)

  switch (($PsCmdlet.ParameterSetName).ToLower()) {
    "directory" {
      ForEach ($fontsFolder in $Path) {
        Write-Log -Message "Processing folder {$fontsFolder}" -Source ${CmdletName}
        $fontFiles = Get-ChildItem -Path $fontsFolder -File -Recurse -Include @("*.fon", "*.fnt", "*.ttf","*.ttc", "*.otf", "*.mmm", "*.pbf", "*.pfm")
      }
    }
    "file" {
      Write-Log -Message "Processing file {$FontFile}" -Source ${CmdletName}
      $fontFiles = Get-ChildItem -Path $FontFile -Include @("*.fon", "*.fnt", "*.ttf","*.ttc", "*.otf", "*.mmm", "*.pbf", "*.pfm")
    }
  }
  if ($fontFiles) {
    foreach ($item in $fontFiles) {
      Write-Log -Message "Processing font file {$item}" -Source ${CmdletName}
      $nameTmp = $item.Name
      $FontName = $nameTmp.subString(0,$nameTmp.length-4).Replace(" ","").Replace("-","").Replace("_","")
      #if ($item -like "*.ttf") { $FontName = "$FontName (TrueType)" }

      $RegistryList = Get-ItemProperty -Path $fontRegistryPath -ErrorAction SilentlyContinue

      $regTest = Get-ItemProperty -Path $fontRegistryPath -Name "*$FontName*" -ErrorAction SilentlyContinue
      if ($regTest) { Write-Log -Message "Font {$($item.Name)} exist in registry with name {$FontName}. Will skipp installation." -Source ${CmdletName} }

      if ((Test-Path (Join-Path -Path $objfontFolder -ChildPath $nameTmp)) -or ($regTest)) {
        Write-Log -Message "Font {$($item.Name)} already exists in {$objfontFolder}" -Source ${CmdletName}
        $isInFolder = $True
      } else {
        Write-Log -Message "Font {$($item.Name)} do not exists in {$objfontFolder}, will copy." -Source ${CmdletName}
        $isInFolder = $False
      }

      Write-Log -Message "Reading font {$($item.Name)} full name" -Source ${CmdletName}

      Add-Type -AssemblyName System.Drawing
      $objFontCollection = New-Object System.Drawing.Text.PrivateFontCollection
      $objFontCollection.AddFontFile($item.FullName)
      #$FontName = $objFontCollection.Families.Name #is not working for some of fonts if running from System account

      Write-Log -Message "Font {$($item.Name)} full name is {$FontName}" -Source ${CmdletName}
      if ($isInFolder -eq $False) {
        Write-Log -Message "Copying font file {$($item.Name)} to system Folder {$objfontFolder}." -Source ${CmdletName}
        if ($Action.ToLower() -eq "noreboot") {
          $folder.CopyHere($item.FullName, $copyFlag)
          #$folder.CopyHere($item.FullName)
          Write-Log -Message "Displaing progress, reboot not required." -Source ${CmdletName}
        } else {
          copy-item -Path $item.FullName -Destination $objfontFolder -force
          Write-Log -Message "Progress hidden, reboot required." -Source ${CmdletName}
        }
      }

      $regTest = Get-ItemProperty -Path $fontRegistryPath -Name "*$FontName*" -ErrorAction SilentlyContinue
      if (-not ($regTest)) {
        New-ItemProperty -Name $FontName -Path $fontRegistryPath -PropertyType string -Value $item.Name
        Write-Log -Message "Registering font {$($item.Name)} in registry with name {$FontName}" -Source ${CmdletName}
      }
    }
  }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function Remove-Font {
  [CmdletBinding(DefaultParameterSetName='Directory')]
  Param(
    [Parameter(Mandatory=$false,ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
    [Parameter(ParameterSetName='Directory')]
    [ValidateScript({Test-Path $_ -PathType Container })]
    [System.String[]]
    $Path,
    [Parameter(Mandatory=$false,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
    [Parameter(ParameterSetName='File')]
    [ValidateScript({Test-Path $_ -PathType Leaf })]
    [System.String]
    $FontFile
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  Set-Variable Fonts -Value 0x14 -Option ReadOnly
  $fontRegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
  $shell = New-Object -ComObject Shell.Application
  $folder = $shell.NameSpace($Fonts)
  $objfontFolder = $folder.self.Path
  $exts = @(".fon", ".fnt", ".ttf",".ttc", ".otf", ".mmm", ".pbf", ".pfm")

  switch (($PsCmdlet.ParameterSetName).ToLower()) {
    "directory" {
      ForEach ($fontsFolder in $Path) {
        Write-Log -Message "Processing folder {$fontsFolder}" -Source ${CmdletName}
        $fontFiles = Get-ChildItem -Path $fontsFolder -File -Recurse -Include @("*.fon", "*.fnt", "*.ttf","*.ttc", "*.otf", "*.mmm", "*.pbf", "*.pfm")
      }
    }
    "file" {
      Write-Log -Message "Processing file {$FontFile}" -Source ${CmdletName}
      $fontFiles = Get-ChildItem -Path $FontFile -Include @("*.fon", "*.fnt", "*.ttf","*.ttc", "*.otf", "*.mmm", "*.pbf", "*.pfm")
    }
  }
  if ($fontFiles) {
    foreach ($item in $fontFiles) {
      Write-Log -Message "Processing font file {$item}" -Source ${CmdletName}
      $FontName = ($item.Name)
      foreach ($ext in $exts) { $FontName = $FontName.Replace("$ext","") }

      $regTest = Get-ItemProperty -Path $fontRegistryPath -Name "*$FontName*" -ErrorAction SilentlyContinue
      if ($regTest) { Write-Log -Message "Font {$($item.Name)} exist in registry with name {$FontName}. Will skipp installation." -Source ${CmdletName} }

      if ((Test-Path (Join-Path -Path $objfontFolder -ChildPath $item.Name)) -or ($regTest)) {
        Write-Log -Message "Font {$($item.Name)} exists in {$objfontFolder}, will remove it." -Source ${CmdletName}
        $isInFolder = $True
      } else {
        Write-Log -Message "Font {$($item.Name)} do not exists in {$objfontFolder}, going next." -Source ${CmdletName}
        $isInFolder = $False
      }

      if ($isInFolder -eq $True) {
        Write-Log -Message "Reading font {$($item.Name)} full name" -Source ${CmdletName}

        Add-Type -AssemblyName System.Drawing
        $objFontCollection = New-Object System.Drawing.Text.PrivateFontCollection
        $objFontCollection.AddFontFile($item.FullName)
        $nameTmp = $item.Name
        $FontName = $nameTmp.subString(0,$nameTmp.length-4)

        Write-Log -Message "Font {$($item.Name)} full name is {$FontName}" -Source ${CmdletName}
        Write-Log -Message "Remove-Item -Path $objfontFolder\$nameTmp -force" -Source ${CmdletName}
        #Remove-Item -Path "$objfontFolder\$nameTmp" -force
        Set-RemoveFiles -FileName $nameTmp -Directory $objfontFolder
      }
      Remove-FontRegistryEntry -FontName $FontName
    }
  }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function Remove-FontRegistryEntry {
  [CmdletBinding(DefaultParameterSetName='Directory')]
  Param(
    $FontName
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

  
  $fontRegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
  $defFontName = $FontName
  $cleanFontName = $FontName.Replace("-","").Replace(" ","")
  $names = @($defFontName, $cleanFontName)

  Foreach ($name in $names) {
    $regTest = Get-ItemProperty -Path $fontRegistryPath -Name "*$name*" -ErrorAction SilentlyContinue
    Write-Log -Message "$regTest = Get-ItemProperty -Path `"$fontRegistryPath`" -Name `"*$name*`"" -Source ${CmdletName}

    if ((-not([string]::IsNullOrEmpty($regTest))) -and (-not([string]::IsNullOrWhiteSpace($regTest)))) {
      Remove-ItemProperty -Path $fontRegistryPath -Name $name
      Write-Log -Message "Removing font {$($item.Name)} from registry with name {$name}" -Source ${CmdletName}
    }
  }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function Get-CharFromAsci {
  [CmdletBinding(DefaultParameterSetName='Directory')]
  Param(
    $String
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message "Will proceed with $String to replace ASCI codes to proper chars." -Source ${CmdletName}

  $NewString = $String

  If ($String -like "*[char]*") {
    $charMatches = ([regex]'\[char\](\d+)').Matches($String).value
    Foreach($charMatch in $charMatches) {
      $number = $charMatch.Replace("[char]","")
      [int]$number = $number
      Write-Host "number = $number"
      $NewString = $NewString.Replace($charMatch,"$([char]$number)")
    }
  } else { Write-Log -Message "Nothing to change." -Source ${CmdletName} }

  Write-Log -Message "Will return: $NewString." -Source ${CmdletName}
  Return $NewString
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------




# Copyright © 2017 Chocolatey Software, Inc.
# Copyright © 2015 - 2017 RealDimensions Software, LLC
# Copyright © 2011 - 2015 RealDimensions Software, LLC & original authors/contributors from https://github.com/chocolatey/chocolatey
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

function Get-EnvironmentVariableNames([System.EnvironmentVariableTarget] $Scope) {
  switch ($Scope) {
    'User' { Get-Item 'HKCU:\Environment' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Property }
    'Machine' { Get-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' | Select-Object -ExpandProperty Property }
    'Process' { Get-ChildItem Env:\ | Select-Object -ExpandProperty Key }
    default { Throw "Unsupported environment scope: $Scope" }
  }
}


function Get-EnvironmentVariable {
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory=$true)][string] $Name,
    [Parameter(Mandatory=$true)][System.EnvironmentVariableTarget] $Scope,
    [Parameter(Mandatory=$false)][switch] $PreserveVariables = $false,
    [parameter(ValueFromRemainingArguments = $true)][Object[]] $ignoredArguments
  )

  [string] $MACHINE_ENVIRONMENT_REGISTRY_KEY_NAME = "SYSTEM\CurrentControlSet\Control\Session Manager\Environment\";
  [Microsoft.Win32.RegistryKey] $win32RegistryKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($MACHINE_ENVIRONMENT_REGISTRY_KEY_NAME)
  
  if ($Scope -eq [System.EnvironmentVariableTarget]::User) {
    [string] $USER_ENVIRONMENT_REGISTRY_KEY_NAME = "Environment";
    [Microsoft.Win32.RegistryKey] $win32RegistryKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($USER_ENVIRONMENT_REGISTRY_KEY_NAME)
  } elseif ($Scope -eq [System.EnvironmentVariableTarget]::Process) { return [Environment]::GetEnvironmentVariable($Name, $Scope) }

  [Microsoft.Win32.RegistryValueOptions] $registryValueOptions = [Microsoft.Win32.RegistryValueOptions]::None

  if ($PreserveVariables) { $registryValueOptions = [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames }

  [string] $environmentVariableValue = [string]::Empty

  try { if ($null -ne $win32RegistryKey) { $environmentVariableValue = $win32RegistryKey.GetValue($Name, [string]::Empty, $registryValueOptions) } } 
  catch { Write-Verbose "Unable to retrieve the $Name environment variable. Details: $_" -Verbose } 
  finally { if ($null -ne $win32RegistryKey) { $win32RegistryKey.Close() } }

  if (($null -eq $environmentVariableValue) -or ($environmentVariableValue -eq '')) { $environmentVariableValue = [Environment]::GetEnvironmentVariable($Name, $Scope) }

  return $environmentVariableValue
}


function Update-SessionEnvironment {
  $userName = $env:USERNAME
  $architecture = $env:PROCESSOR_ARCHITECTURE
  $psModulePath = $env:PSModulePath

  'Process', 'Machine', 'User' | ForEach-Object {
    $scope = $_
    Get-EnvironmentVariableNames -Scope $scope | ForEach-Object { Set-Item "Env:$($_)" -Value (Get-EnvironmentVariable -Scope $scope -Name $_) }
  }

  $paths = 'Machine', 'User' | ForEach-Object { (Get-EnvironmentVariable -Name 'PATH' -Scope $_) -split ';'} | Select-Object -Unique
  $Env:PATH = $paths -join ';'
  $env:PSModulePath = $psModulePath

  if ($userName) { $env:USERNAME = $userName; }
  if ($architecture) { $env:PROCESSOR_ARCHITECTURE = $architecture; }
}


function get-eratosthenes ($n) {
  if($n -gt 1){
    $prime = @(0..$n| ForEach-Object{$true})
    $m = [Math]::Floor([Math]::Sqrt($n))
    function multiple($i) {
      for($j = $i*$i; $j -le $n; $j += $i) { $prime[$j] = $false }
    }
    multiple 2
    for($i = 3; $i -le $m; $i += 2) { if($prime[$i]) {multiple $i} }
    2
    for($i = 3; $i -le $n; $i += 2) { if($prime[$i]) {$i} }
  } else { Write-Error "$n is not greater than 1" }
}
function get-primedecomposition ($n) {
  $array = get-eratosthenes $n
  $prime = @()
  foreach($p in $array) {
    while($n%$p -eq 0) {
      $n /= $p
      $prime += @($p)
    }
  }
  $prime
}
function get-properdivisor ($n) {
  if($n -ge 2) {
    $array = get-primedecomposition $n
    $lim = $array.Count
    function state($res, $i){  
      if($i -lt $lim) {
        state ($res) ($i + 1)
        state ($res*$array[$i]) ($i + 1)   
      } elseif($res -lt $n) {$res}
    }
    state 1 0 | Sort-Object -Unique
  } else {@()}
}