$ErrorActionPreference = "Stop"
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

$repo = "norgon2/Norgon-Tweaks"
$exeName = "NorgonsTweaks.exe"
$defaultInstallDir = Join-Path $env:LOCALAPPDATA "NorgonsTweaks"

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Norgon's Tweaks — Installation" Height="460" Width="480"
        WindowStartupLocation="CenterScreen" ResizeMode="NoResize"
        Background="#0A0D12" FontFamily="Segoe UI">
    <Grid Margin="30,25,30,25">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBlock Grid.Row="0" Text="Norgon's Tweaks" Foreground="White" FontSize="26" FontWeight="Bold"/>
        <TextBlock Grid.Row="1" Text="Assistant d'installation" Foreground="#7B8498" FontSize="13" Margin="0,2,0,15"/>

        <StackPanel Grid.Row="2" Margin="0,0,0,15">
            <TextBlock Text="Dossier d'installation" Foreground="#7B8498" FontSize="11" Margin="0,0,0,6"/>
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="10"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBox x:Name="TxtPath" Grid.Column="0" Background="#14171E" Foreground="White" BorderBrush="#252A36" BorderThickness="1" Padding="8" FontSize="12"/>
                <Button x:Name="BtnBrowse" Grid.Column="2" Content="Parcourir..." Width="90" Background="#1A1F26" Foreground="White" BorderBrush="#252A36"/>
            </Grid>
        </StackPanel>

        <CheckBox x:Name="ChkDesktop" Grid.Row="3" Content="Créer un raccourci sur le Bureau" Foreground="White" FontSize="12" Margin="0,0,0,15"/>

        <StackPanel Grid.Row="4" Margin="0,0,0,15">
            <TextBlock Text="Langue" Foreground="#7B8498" FontSize="11" Margin="0,0,0,6"/>
            <RadioButton x:Name="RadioEn" Content="English" Foreground="White" FontSize="12" Margin="0,0,0,4" GroupName="Lang"/>
            <RadioButton x:Name="RadioMixed" Content="Mixte (français + termes anglais)" Foreground="White" FontSize="12" Margin="0,0,0,4" GroupName="Lang" IsChecked="True"/>
            <RadioButton x:Name="RadioFr" Content="Français" Foreground="White" FontSize="12" GroupName="Lang"/>
        </StackPanel>

        <TextBlock x:Name="StatusText" Grid.Row="5" Text="" Foreground="#7B8498" FontSize="12" VerticalAlignment="Bottom"/>

        <ProgressBar x:Name="Progress" Grid.Row="6" Height="6" Margin="0,10,0,15" Background="#14171E" Foreground="#00B4DB" BorderThickness="0" Minimum="0" Maximum="100"/>

        <StackPanel Grid.Row="7" Orientation="Horizontal" HorizontalAlignment="Right">
            <Button x:Name="BtnInstall" Content="Installer" Width="120" Height="36" Background="#3B82F6" Foreground="White" BorderThickness="0" FontWeight="Bold"/>
            <Button x:Name="BtnLaunch" Content="Lancer" Width="120" Height="36" Background="#3B82F6" Foreground="White" BorderThickness="0" FontWeight="Bold" Visibility="Collapsed" Margin="10,0,0,0"/>
        </StackPanel>
    </Grid>
</Window>
'@

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class NorgonConsole {
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
'@
[NorgonConsole]::ShowWindow([NorgonConsole]::GetConsoleWindow(), 0) | Out-Null # SW_HIDE : pas de terminal visible derriere l'assistant, comme un vrai installeur

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$txtPath = $window.FindName("TxtPath")
$btnBrowse = $window.FindName("BtnBrowse")
$chkDesktop = $window.FindName("ChkDesktop")
$radioEn = $window.FindName("RadioEn")
$radioMixed = $window.FindName("RadioMixed")
$radioFr = $window.FindName("RadioFr")
$statusText = $window.FindName("StatusText")
$progress = $window.FindName("Progress")
$btnInstall = $window.FindName("BtnInstall")
$btnLaunch = $window.FindName("BtnLaunch")

$txtPath.Text = $defaultInstallDir

$btnBrowse.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Choisir le dossier d'installation"
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtPath.Text = Join-Path $dialog.SelectedPath "NorgonsTweaks"
    }
})

# Le telechargement/l'ecriture disque tournent dans un runspace separe pour ne jamais geler la
# fenetre ("Not Responding" pendant l'appel reseau) : chaque mise a jour d'UI est marshalee sur le
# thread de la fenetre via Dispatcher.Invoke, jamais touchee directement depuis ce thread.
$installWork = {
    param($window, $statusText, $progress, $btnInstall, $btnLaunch, $txtPath, $btnBrowse, $chkDesktop, $radioEn, $radioMixed, $radioFr, $repo, $exeName, $installDir, $language, $createDesktop)

    # Sinon PowerShell affiche sa propre banniere de progression par-dessus notre fenetre pendant
    # Invoke-WebRequest/Invoke-RestMethod, ce qui donne l'impression que l'installeur a plante.
    $ProgressPreference = "SilentlyContinue"

    function Set-Status([string]$text, [int]$percent) {
        $window.Dispatcher.Invoke([action]{
            $statusText.Text = $text
            $progress.Value = $percent
        })
    }

    $exePath = Join-Path $installDir $exeName

    try {
        Set-Status "Recherche de la derniere version..." 10
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -Headers @{ "User-Agent" = "NorgonsTweaks-Installer" }
        $asset = $release.assets | Where-Object { $_.name -eq $exeName } | Select-Object -First 1
        if (-not $asset) { throw "Aucun asset '$exeName' trouve dans la derniere release." }

        Set-Status "Creation du dossier d'installation..." 20
        New-Item -ItemType Directory -Force -Path $installDir | Out-Null

        Set-Status "Telechargement de $($release.tag_name)..." 35
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $exePath -UseBasicParsing

        Set-Status "Ecriture des preferences..." 60
        $settings = @{ language = $language } | ConvertTo-Json
        Set-Content -Path (Join-Path $installDir "settings.json") -Value $settings -Encoding UTF8

        Set-Status "Creation du raccourci Menu Demarrer..." 70
        $shell = New-Object -ComObject WScript.Shell
        $startMenu = [Environment]::GetFolderPath("StartMenu")
        $startShortcutPath = Join-Path $startMenu "Programs\Norgon's Tweaks.lnk"
        $shortcut = $shell.CreateShortcut($startShortcutPath)
        $shortcut.TargetPath = $exePath
        $shortcut.WorkingDirectory = $installDir
        $shortcut.IconLocation = "$exePath,0"
        $shortcut.Save()

        if ($createDesktop) {
            Set-Status "Creation du raccourci Bureau..." 78
            $desktopPath = [Environment]::GetFolderPath("Desktop")
            $deskShortcut = $shell.CreateShortcut((Join-Path $desktopPath "Norgon's Tweaks.lnk"))
            $deskShortcut.TargetPath = $exePath
            $deskShortcut.WorkingDirectory = $installDir
            $deskShortcut.IconLocation = "$exePath,0"
            $deskShortcut.Save()
        }

        Set-Status "Ecriture de l'entree de desinstallation..." 88
        $uninstallKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\NorgonsTweaks"
        New-Item -Path $uninstallKey -Force | Out-Null
        Set-ItemProperty -Path $uninstallKey -Name "DisplayName" -Value "Norgon's Tweaks"
        Set-ItemProperty -Path $uninstallKey -Name "DisplayVersion" -Value $release.tag_name
        Set-ItemProperty -Path $uninstallKey -Name "Publisher" -Value "Norgon's Tweaks"
        Set-ItemProperty -Path $uninstallKey -Name "InstallLocation" -Value $installDir
        Set-ItemProperty -Path $uninstallKey -Name "DisplayIcon" -Value "$exePath,0"
        Set-ItemProperty -Path $uninstallKey -Name "UninstallString" -Value "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$installDir\uninstall.ps1`""
        Set-ItemProperty -Path $uninstallKey -Name "NoModify" -Value 1 -Type DWord
        Set-ItemProperty -Path $uninstallKey -Name "NoRepair" -Value 1 -Type DWord

        $uninstallScript = @"
`$installDir = "$installDir"
Remove-Item -Path "`$installDir" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$startShortcutPath" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$(Join-Path ([Environment]::GetFolderPath('Desktop')) "Norgon's Tweaks.lnk")" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$uninstallKey" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "Norgon's Tweaks a ete desinstalle."
"@
        Set-Content -Path (Join-Path $installDir "uninstall.ps1") -Value $uninstallScript -Encoding UTF8

        Set-Status "Installation terminee dans $installDir" 100
        $window.Dispatcher.Invoke([action]{
            $btnInstall.Visibility = [System.Windows.Visibility]::Collapsed
            $btnLaunch.Visibility = [System.Windows.Visibility]::Visible
            $btnLaunch.Tag = $exePath
        })
    }
    catch {
        $errorMessage = $_.Exception.Message
        Set-Status "Erreur : $errorMessage" 0
        $window.Dispatcher.Invoke([action]{
            $btnInstall.IsEnabled = $true
            $txtPath.IsEnabled = $true
            $btnBrowse.IsEnabled = $true
            $chkDesktop.IsEnabled = $true
            $radioEn.IsEnabled = $true; $radioMixed.IsEnabled = $true; $radioFr.IsEnabled = $true
        })
    }
}

$btnInstall.Add_Click({
    $btnInstall.IsEnabled = $false
    $txtPath.IsEnabled = $false
    $btnBrowse.IsEnabled = $false
    $chkDesktop.IsEnabled = $false
    $radioEn.IsEnabled = $false; $radioMixed.IsEnabled = $false; $radioFr.IsEnabled = $false

    $installDir = $txtPath.Text
    $language = if ($radioEn.IsChecked) { "en" } elseif ($radioFr.IsChecked) { "fr" } else { "mixed" }
    $createDesktop = [bool]$chkDesktop.IsChecked

    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = "STA"
    $rs.ThreadOptions = "ReuseThread"
    $rs.Open()
    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript($installWork).AddArgument($window).AddArgument($statusText).AddArgument($progress).AddArgument($btnInstall).AddArgument($btnLaunch).AddArgument($txtPath).AddArgument($btnBrowse).AddArgument($chkDesktop).AddArgument($radioEn).AddArgument($radioMixed).AddArgument($radioFr).AddArgument($repo).AddArgument($exeName).AddArgument($installDir).AddArgument($language).AddArgument($createDesktop)
    $ps.BeginInvoke() | Out-Null
})

$btnLaunch.Add_Click({
    Start-Process -FilePath $btnLaunch.Tag
    $window.Close()
})

$window.ShowDialog() | Out-Null
