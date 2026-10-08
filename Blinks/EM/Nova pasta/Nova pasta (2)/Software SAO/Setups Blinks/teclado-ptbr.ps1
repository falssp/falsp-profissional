Write-Output "Idioma atual do teclado: "
Get-WinUserLanguageList

Write-Output "`nInstalando pt-BR..."
Set-WinUserLanguageList pt-BR

Write-Output "`nNovo Idioma do teclado: "
Get-WinUserLanguageList

Read-Host -Prompt "`nPressione qualquer tecla para encerrar"