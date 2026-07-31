# Norgon's Tweaks

*[Lire en français](README.fr.md)*

PC optimization and diagnostics, honest about what actually works.

This software never enables or disables Windows Defender, the firewall, Windows Update, VBS,
memory integrity, or Smart App Control. Reversible changes can be undone from within the app.
No telemetry, no network connection outside of updates.

## Installation

Open PowerShell and run:

```powershell
irm https://raw.githubusercontent.com/norgon2/Norgon-Tweaks/main/install.ps1 | iex
```

This downloads the latest version, installs the app to `%LOCALAPPDATA%\NorgonsTweaks`,
creates a Start Menu shortcut, and adds a standard uninstall entry.

## Uninstallation

From **Settings → Apps**, search for "Norgon's Tweaks", or run
`%LOCALAPPDATA%\NorgonsTweaks\uninstall.ps1`.
