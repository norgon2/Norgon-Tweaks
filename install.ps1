$ErrorActionPreference = "Stop"

$repo = "norgon2/Norgon-Tweaks"
$installDir = Join-Path $env:LOCALAPPDATA "NorgonsTweaks"
$exeName = "SafeBoostOptimizer.exe"
$exePath = Join-Path $installDir $exeName

Write-Host "=== Norgon's Tweaks — Installateur ===" -ForegroundColor Cyan

Write-Host "Recherche de la derniere version..."
$release = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -Headers @{ "User-Agent" = "NorgonsTweaks-Installer" }
$asset = $release.assets | Where-Object { $_.name -eq $exeName } | Select-Object -First 1
if (-not $asset) { throw "Aucun asset '$exeName' trouve dans la derniere release." }

Write-Host "Version trouvee : $($release.tag_name)"
New-Item -ItemType Directory -Force -Path $installDir | Out-Null

Write-Host "Telechargement..."
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $exePath -UseBasicParsing

Write-Host "Creation du raccourci Menu Demarrer..."
$startMenu = [Environment]::GetFolderPath("StartMenu")
$shortcutPath = Join-Path $startMenu "Programs\Norgon's Tweaks.lnk"
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $exePath
$shortcut.WorkingDirectory = $installDir
$shortcut.IconLocation = "$exePath,0"
$shortcut.Save()

Write-Host "Ecriture de l'entree de desinstallation..."
$uninstallKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\NorgonsTweaks"
New-Item -Path $uninstallKey -Force | Out-Null
Set-ItemProperty -Path $uninstallKey -Name "DisplayName" -Value "Norgon's Tweaks"
Set-ItemProperty -Path $uninstallKey -Name "DisplayVersion" -Value $release.tag_name
Set-ItemProperty -Path $uninstallKey -Name "Publisher" -Value "Norgon"
Set-ItemProperty -Path $uninstallKey -Name "InstallLocation" -Value $installDir
Set-ItemProperty -Path $uninstallKey -Name "DisplayIcon" -Value "$exePath,0"
Set-ItemProperty -Path $uninstallKey -Name "UninstallString" -Value "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$installDir\uninstall.ps1`""
Set-ItemProperty -Path $uninstallKey -Name "NoModify" -Value 1 -Type DWord
Set-ItemProperty -Path $uninstallKey -Name "NoRepair" -Value 1 -Type DWord

$uninstallScript = @"
`$installDir = "$installDir"
Remove-Item -Path "`$installDir" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$shortcutPath" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$uninstallKey" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "Norgon's Tweaks a ete desinstalle."
"@
Set-Content -Path (Join-Path $installDir "uninstall.ps1") -Value $uninstallScript -Encoding UTF8

Write-Host "Installation terminee dans $installDir" -ForegroundColor Green
Write-Host "Lancement..."
Start-Process -FilePath $exePath
