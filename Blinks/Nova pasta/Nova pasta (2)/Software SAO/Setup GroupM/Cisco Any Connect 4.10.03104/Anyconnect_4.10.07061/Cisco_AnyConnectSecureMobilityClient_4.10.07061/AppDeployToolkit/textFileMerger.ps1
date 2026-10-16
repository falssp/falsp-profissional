# For ini used a code from: https://github.com/lipkau/PsIni/tree/master/PSIni 
# Read more on homepage.

#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Add-IniComment {
  [CmdletBinding(DefaultParameterSetName = "File")]
  [OutputType([System.Collections.Specialized.OrderedDictionary])]
  Param(
    [Parameter( Position = 0, Mandatory = $true, ParameterSetName = "File" )]
    [ValidateNotNullOrEmpty()]
    [String]$FilePath,
    [Parameter( Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = "Object" )]
    [ValidateNotNullOrEmpty()]
    [System.Collections.IDictionary]$InputObject,
    [Parameter( Mandatory = $true )]
    [ValidateNotNullOrEmpty()]
    [String[]]$Keys,
    [Char[]]$CommentChar = @(";"),
    [ValidateNotNullOrEmpty()]
    [String[]]$Sections
  )

  <# $ini = Add-IniComment -FilePath "C:\myinifile.ini" -Sections 'Printers' -Keys 'Headers','Footers'
  Add-IniComment -FilePath "C:\myinifile.ini" -Sections 'Terminals','Monitors' -Keys 'Updated' | Out-IniFile "C:\myinifile.ini" -Force
  Get-IniContent "C:\myinifile.ini" | Add-IniComment -Keys 'Headers' | Out-IniFile "C:\myinifile.ini" -Force
  Get-IniContent "C:\myinifile.ini" | Add-IniComment -Keys 'Updated' -Sections '_' | Out-IniFile "C:\myinifile.ini" -Force #>

  if ($PSCmdlet.ParameterSetName -eq 'File') { $content = Get-IniContent $FilePath }
  if ($PSCmdlet.ParameterSetName -eq 'Object') { $content = $InputObject }

  if ($Sections) {
    foreach ($section in $Sections) {
      $section = $section.Trim() -replace '[][]', ''
      foreach ($key in $Keys) {
        $key = $key.Trim()
        if ($content[$section]) { $currentValue = $content[$section][$key] }
        else { break }
        if ($currentValue) { Convert-IniEntryToComment $content $key $section $CommentChar }
        else { Write-Verbose ("$($MyInvocation.MyCommand.Name):: '[{0}][{1}]' does not exist." -f $section, $key) }
      }
    }
  } else {
    foreach ($item in $content.GetEnumerator()) {
      $section = $item.key
      foreach ($key in $Keys) {
        $key = $key.Trim()
        if ($content[$section][$key]) { Convert-IniEntryToComment $content $key $section $CommentChar }
        else { Write-Verbose ("$($MyInvocation.MyCommand.Name):: '[{0}][{1}]' does not exist." -f $section, $key) }
      }
    }
  }

  Write-Output $content
}  
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Convert-IniCommentToEntry {
  param ($content, $key, $section, $commentChar)

  $index = 0
  $commentFound = $false
  $commentRegex = "^([$($commentChar -join '')]$key.*)$"

  foreach ($entry in $content[$section].GetEnumerator()) {
    if ($entry.key.StartsWith('Comment') -and $entry.value -match $commentRegex) {
      $oldKey = $entry.key
      $split = $entry.value.Split("=")
      if ($split.Length -ge 2) { $newValue = $split[1].Trim() }
      else { $newValue = '' }
      $commentFound = $true
      break
    }
    $index++
  }

  if ($commentFound) {
    if ($content[$section][$key]) { Write-Verbose ("$($MyInvocation.MyCommand.Name):: Unable to uncomment '{0}' key in {1} section as there is already a key with that name." -f $key, $section) }
    else {
      $content[$section].Remove($oldKey)
      $content[$section].Insert($index, $key, $newValue)
    }
  } else { Write-Verbose ("$($MyInvocation.MyCommand.Name):: Did not find '{0}' key in {1} section to uncomment." -f $key, $section) }
} 
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Convert-IniEntryToComment {
  param ($content, $key, $section, $commentChar)

  $commentCount = 1

  foreach ($entry in $content[$section].GetEnumerator()) { if ($entry.key.StartsWith('Comment')) { $commentCount++ } }

  $desiredValue = $content[$section][$key]

  if ($desiredValue) {
    $commentKey = 'Comment' + $commentCount
    $commentValue = $commentChar[0] + $key + '=' + $desiredValue

    # Thanks to http://stackoverflow.com/a/35731603/844937. However, that solution is case sensitive.
    # Tried $index = $($content[$section].keys).IndexOf($key, [StringComparison]"CurrentCultureIgnoreCase")
    # but it said there were no IndexOf overloads with two arguments. So if we get a -1 (not found),
    # use a variation on http://stackoverflow.com/a/34930231/844937 to search for a case-insensitive match.
    
    $sectionKeys = $($content[$section].keys)
    $index = $sectionKeys.IndexOf($key)

    if ($index -eq -1) {
      $i = 0
      foreach ($sectionKey in $sectionKeys) {
        if ($sectionKey -match $key) {
          $index = $i
          break
        } else { $i++ }
      }
    }

    if ($index -ge 0) {
      $content[$section].Remove($key)
      $content[$section].Insert($index, $commentKey, $commentValue)
    } else { Write-Verbose ("$($MyInvocation.MyCommand.Name):: Could not find '{0}' key in {1} section to comment out." -f $key, $section) }
  }
} 
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Get-IniContent {
  [CmdletBinding()]
  [OutputType([System.Collections.Specialized.OrderedDictionary])]
  Param(
    [ValidateNotNullOrEmpty()]
    [Parameter( Mandatory = $true, ValueFromPipeline = $true )]
    [String]$FilePath,
    [Char[]]$CommentChar = @(";"),
    [Switch]$IgnoreComments
  )

 <#
  $FileContent = Get-IniContent "C:\myinifile.ini"
  $inifilepath | $FileContent = Get-IniContent
  C:\PS>$FileContent = Get-IniContent "c:\settings.ini"
  C:\PS>$FileContent["Section"]["Key"]
  #>

  $commentRegex = "^\s*([$($CommentChar -join '')].*)$"
  $sectionRegex = "^\s*\[(.+)\]\s*$"
  $keyRegex     = "^\s*(.+?)\s*=\s*(['`"]?)(.*)\2\s*$"

  $ini = New-Object System.Collections.Specialized.OrderedDictionary([System.StringComparer]::OrdinalIgnoreCase)
  #$ini = @{}

  if (!(Test-Path $Filepath)) { Write-Output $ini }

  $commentCount = 0
  switch -regex -file $FilePath {
    $sectionRegex { # Section
      $section = $matches[1]
      $ini[$section] = New-Object System.Collections.Specialized.OrderedDictionary([System.StringComparer]::OrdinalIgnoreCase)
      $CommentCount = 0
      continue
    }
    $commentRegex { # Comment
      if (!$IgnoreComments) {
        if (!(test-path "variable:local:section")) {
          $section = $script:NoSection
          $ini[$section] = New-Object System.Collections.Specialized.OrderedDictionary([System.StringComparer]::OrdinalIgnoreCase)
        }
        $value = $matches[1]
        $CommentCount++
        $name = "Comment" + $CommentCount
        $ini[$section][$name] = $value
      } else { Write-Debug ("Ignoring comment {0}." -f $matches[1]) }
      continue
    }
    $keyRegex { # Key
      if (!(test-path "variable:local:section")) {
        $section = $script:NoSection
        $ini[$section] = New-Object System.Collections.Specialized.OrderedDictionary([System.StringComparer]::OrdinalIgnoreCase)
      }
      $name, $value = $matches[1, 3]
      if (-not $ini[$section][$name]) { $ini[$section][$name] = $value }
      else {
        if ($ini[$section][$name] -is [string]) {
          $ini[$section][$name] = [System.Collections.ArrayList]::new()
          $ini[$section][$name].Add($ini[$section][$name]) | Out-Null
          $ini[$section][$name].Add($value) | Out-Null
        } else { $ini[$section][$name].Add($value) | Out-Null }
      }
      continue
    }
  }
  Write-Output $ini
} 
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Out-IniFile {
  [CmdletBinding()]
  [OutputType([System.IO.FileSystemInfo])]
  Param (
    [switch]$Append,
    [ValidateSet("Unicode", "UTF7", "UTF8", "ASCII", "BigEndianUnicode", "Byte", "String")]
    [Parameter()]
    [String]$Encoding = "UTF8",
    [ValidateNotNullOrEmpty()]
    [ValidateScript( {Test-Path $_ -IsValid} )]
    [Parameter( Position = 0, Mandatory = $true )]
    [String]$FilePath,
    [Switch]$Force,
    [Parameter( Mandatory = $true, ValueFromPipeline = $true )]
    [System.Collections.IDictionary]$InputObject,
    [Switch]$Passthru,
    [Switch]$Loose,
    [Switch]$Pretty
  )

  <#
  Out-IniFile $IniVar "C:\myinifile.ini"
  $IniVar | Out-IniFile "C:\myinifile.ini" -Force
  $file = Out-IniFile $IniVar "C:\myinifile.ini" -PassThru
  
  $Category1 = @{“Key1”=”Value1”;”Key2”=”Value2”}
  $Category2 = @{“Key1”=”Value1”;”Key2”=”Value2”}
  $NewINIContent = @{“Category1”=$Category1;”Category2”=$Category2}
  Out-IniFile -InputObject $NewINIContent -FilePath "C:\MyNewFile.ini"
  #>

  $delimiter = '='
  if ($Loose) { $delimiter = ' = ' }

  $parameters = @{
    Encoding = $Encoding;
    FilePath = $FilePath
  }

  $extraLF = ""

  if ($Append) { $outfile = Get-Item $FilePath } 
  else { $outFile = New-Item -ItemType file -Path $Filepath -Force:$Force }

  if (!(Test-Path $outFile.FullName)) {Throw "Could not create File"}

  foreach ($i in $InputObject.get_keys()) {
    if (!($InputObject[$i].GetType().GetInterface('IDictionary'))) { "$i$delimiter$($InputObject[$i])" | Out-File -Append @parameters } 
    elseif ($i -eq $script:NoSection) { Out-Keys $InputObject[$i] @parameters -Delimiter $delimiter -MyInvocation $MyInvocation } 
    else {
      if ($i -ne $script:NoSection) { "$extraLF[$i]" | Out-File -Append @parameters }
      if ($Pretty) { $extraLF = "`r`n" }
      if ( $InputObject[$i].Count) { Out-Keys $InputObject[$i] @parameters -Delimiter $delimiter -MyInvocation $MyInvocation }
    }
  }

  if ($PassThru) { Write-Output (Get-Item $outFile) }
} 
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function Out-Keys {
  param(
    [ValidateNotNullOrEmpty()]
    [Parameter( Mandatory, ValueFromPipeline )]
    [System.Collections.IDictionary]$InputObject,
    [ValidateSet("Unicode", "UTF7", "UTF8", "ASCII", "BigEndianUnicode", "Byte", "String")]
    [Parameter( Mandatory )]
    [string]$Encoding = "UTF8",
    [ValidateNotNullOrEmpty()]
    [ValidateScript( {Test-Path $_ -IsValid})]
    [Parameter( Mandatory, ValueFromPipelineByPropertyName )]
    [Alias("Path")]
    [string]$FilePath,
    [Parameter( Mandatory )]$Delimiter,
    [Parameter( Mandatory )]$MyInvocation
  )

  if (!($InputObject.get_keys())) { Write-Warning ("No data found in '{0}'." -f $FilePath) }
  Foreach ($key in $InputObject.get_keys()) {
    if ($key -match "^Comment\d+") { "$($InputObject[$key])" | Out-File -Encoding $Encoding -FilePath $FilePath -Append } 
    else { $InputObject[$key] | ForEach-Object { "$key$delimiter$_" } | Out-File -Encoding $Encoding -FilePath $FilePath -Append }
  }
} 
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Remove-IniComment {
  [CmdletBinding( DefaultParameterSetName = "File" )]
  [OutputType([System.Collections.IDictionary])]
  Param(
    [Parameter( Position = 0,  Mandatory = $true, ParameterSetName = "File" )]
    [ValidateNotNullOrEmpty()]
    [String]$FilePath,
    [Parameter( Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = "Object" )]
    [ValidateNotNullOrEmpty()]
    [System.Collections.IDictionary]$InputObject,
    [Parameter( Mandatory = $true )]
    [ValidateNotNullOrEmpty()]
    [String[]]$Keys,
    [Char[]]$CommentChar = @(";"),
    [ValidateNotNullOrEmpty()]
    [String[]]$Sections
  )

  <#
  $ini = Remove-IniComment -FilePath "C:\myinifile.ini" -Sections 'Printers' -Keys 'Headers'
  Remove-IniComment -FilePath "C:\myinifile.ini" -Sections 'Terminals','Monitors' -Keys 'Updated' | Out-IniFile "C:\myinifile.ini" -Force
  Get-IniContent "C:\myinifile.ini" | Remove-IniComment -Keys 'Headers' | Out-IniFile "C:\myinifile.ini" -Force
  Get-IniContent "C:\myinifile.ini" | Remove-IniComment -Keys 'Updated' -Sections '_' | Out-IniFile "C:\myinifile.ini" -Force
  #>

  if ($PSCmdlet.ParameterSetName -eq 'File') { $content = Get-IniContent $FilePath }
  if ($PSCmdlet.ParameterSetName -eq 'Object') { $content = $InputObject }

  if ($Sections) {
    foreach ($section in $Sections) {
      $section = $section.Trim() -replace '[][]', ''

      foreach ($key in $Keys) {
        $key = $key.Trim()
        if (!($content[$section])) {
          Write-Verbose ("$($MyInvocation.MyCommand.Name):: '{0}' section does not exist." -f $section)
          break
        }
        Convert-IniCommentToEntry $content $key $section $CommentChar
      }
    }
  } else {
    foreach ($item in $content.GetEnumerator()) {
      $section = $item.key

      foreach ($key in $Keys) {
        $key = $key.Trim()
        Convert-IniCommentToEntry $content $key $section $CommentChar
      }
    }
  }
  Write-Output $content
} 
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Remove-IniEntry {
  [CmdletBinding(DefaultParameterSetName = "File")]
  [OutputType([System.Collections.IDictionary])]
  Param(
    [Parameter( Position = 0, Mandatory = $true, ParameterSetName = "File")]
    [ValidateNotNullOrEmpty()]
    [String]$FilePath,
    [Parameter( Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = "Object" )]
    [System.Collections.IDictionary]$InputObject,
    [ValidateNotNullOrEmpty()]
    [String[]]$Keys,
    [ValidateNotNullOrEmpty()]
    [String[]]$Sections
  )

  <#
  $ini = Remove-IniEntry -FilePath "C:\myinifile.ini" -Sections 'Printers' -Keys 'Headers','Version'
  Remove-IniEntry -FilePath "C:\myinifile.ini" -Sections 'Terminals','Monitors' -Keys 'Updated' | Out-IniFile "C:\myinifile.ini" -Force
  Get-IniContent "C:\myinifile.ini" | Remove-IniEntry -Keys 'Headers' | Out-IniFile "C:\myinifile.ini" -Force
  Get-IniContent "C:\myinifile.ini" | Remove-IniEntry -Sections 'Terminals' | Out-IniFile "C:\myinifile.ini" -Force
  Get-IniContent "C:\myinifile.ini" | Remove-IniEntry -Keys 'Updated' -Sections '_' | Out-IniFile "C:\myinifile.ini" -Force
  #>
  
  if ($PSCmdlet.ParameterSetName -eq 'File') { $content = Get-IniContent $FilePath }
  if ($PSCmdlet.ParameterSetName -eq 'Object') { $content = $InputObject }

  if (!$Keys -and !$Sections) { Write-Output $content }

  if ($Sections) {
    foreach ($section in $Sections) {
      $section = $section.Trim() -replace '[][]', ''
      if (!$Keys) { $content.Remove($section) } 
      else {
        foreach ($key in $Keys) {
          $key = $key.Trim()
          if ($content[$section]) { $currentValue = $content[$section][$key] }
          else {
            Write-Verbose ("$($MyInvocation.MyCommand.Name):: '{0}' section does not exist." -f $section)
            break
          }
          if ($currentValue) { $content[$section].Remove($key) } 
          else { Write-Verbose ("$($MyInvocation.MyCommand.Name):: '{0}' key does not exist." -f $key) }
        }
      }
    }
  } else {
    foreach ($item in $content.GetEnumerator()) {
      $section = $item.key
      foreach ($key in $Keys) {
        $key = $key.Trim()
        if ($content[$section][$key]) { $content[$section].Remove($key) } 
        else { Write-Verbose ("$($MyInvocation.MyCommand.Name):: '{0}' key does not exist in {1} section." -f $key, $section) }
      }
    }
  }
  Write-Output $content
} 
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-IniContent {
  [CmdletBinding(DefaultParameterSetName = "File")]
  [OutputType([System.Collections.IDictionary])]
  Param (
    [Parameter( Position = 0, Mandatory = $true, ParameterSetName = "File" )]
    [ValidateNotNullOrEmpty()]
    [String]$FilePath,
    [Parameter( Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = "Object")]
    [ValidateNotNullOrEmpty()]
    [System.Collections.IDictionary]$InputObject,
    [Parameter( Mandatory = $true, ParameterSetName = "File")]
    [Parameter( Mandatory = $true, ParameterSetName = "Object")]
    [ValidateNotNullOrEmpty()]
    [HashTable]$NameValuePairs,
    [Parameter( ParameterSetName = "File" )]
    [Parameter( ParameterSetName = "Object" )]
    [ValidateNotNullOrEmpty()]
    [String[]]$Sections
  )

  <#
  $ini = Set-IniContent -FilePath "C:\myinifile.ini" -Sections 'Printers' -NameValuePairs @{'Name With Space' = 'Value1' ; 'AnotherName' = 'Value2'}
  Set-IniContent -FilePath "C:\myinifile.ini" -Sections 'Terminals','Monitors' -NameValuePairs @{'Updated=FY17Q2'} | Out-IniFile "C:\myinifile.ini" -Force
  Get-IniContent "C:\myinifile.ini" | Set-IniContent -NameValuePairs @{'Headers' = 'True' ; 'Update' = 'False'} | Out-IniFile "C:\myinifile.ini" -Force
  Get-IniContent "C:\myinifile.ini" | Set-IniContent -NameValuePairs @{'Updated'='FY17Q2'} -Sections '_' | Out-IniFile "C:\myinifile.ini" -Force
  #>

  if ($PSCmdlet.ParameterSetName -eq 'File') { $content = Get-IniContent $FilePath }
  if ($PSCmdlet.ParameterSetName -eq 'Object') { $content = $InputObject }

  if ($Sections) {
    foreach ($section in $Sections) {
      $section = $section.Trim() -replace '[][]', ''
      Update-IniEntry $content $section
    }
  } else {
    foreach ($item in $content.GetEnumerator()) {
      $section = $item.key
      Update-IniEntry $content $section
    }
  }
  Write-Output $content
} 
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Update-IniEntry {
  param ($content, $section)

  foreach ($pair in $NameValuePairs.GetEnumerator()) {
    if (!($content[$section])) { $content[$section] = New-Object System.Collections.Specialized.OrderedDictionary([System.StringComparer]::OrdinalIgnoreCase) }
    $content[$section][$pair.key] = $pair.value
  }
} 
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------





#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-AppendIniChanges {
  Param (
    [Parameter( Mandatory = $true )]
    [String]$deltaFilePath,
    [Parameter( Mandatory = $true )]
    [String]$targetFilePath
  )

  $deltaFileContent = Get-IniContent "$deltaFilePath"
  $Sections = $deltaFileContent.Keys

  foreach ($Section in $Sections) {
    $Keys = $deltaFileContent.$Section.Keys
    foreach ($Key in $Keys) {
      $Value = $deltaFileContent.$Section.$Key
      Set-IniContent -FilePath "$targetFilePath" -Sections "$Section" -NameValuePairs @{"$Key" = "$Value"} | Out-IniFile "$targetFilePath" -Force -Pretty
    }
  }
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Function Set-AppendXmlChanges {
  Param (
    [Parameter( Mandatory = $true )]
    [String]$deltaFilePath,
    [Parameter( Mandatory = $true )]
    [String]$targetFilePath
  )

  [Reflection.Assembly]::LoadWithPartialName("System.Xml.Linq") | Out-Null

  $deltaFileContent = [System.Xml.Linq.XElement]::Load("$deltaFilePath")
  $targetFileContent = [System.Xml.Linq.XElement]::Load("$targetFilePath")
  $targetFileContent.Add($deltaFileContent.FirstNode)

  $targetFileContent.Save("$targetFilePath")

  #$combined = Compare-Object $deltaFileContent $targetFileContent -PassThru -IncludeEqual
  #$combined.Save("$targetFilePath")
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


<# 
$aIni = "$PSScriptRoot\A.ini"
$bIni = "$PSScriptRoot\B.ini"
$cIni = "$PSScriptRoot\C.ini"

Set-AppendIniChanges -deltaFilePath $aIni -targetFilePath $cIni 
#>