# Norgon's Tweaks

*[Read in English](README.md)*

Optimisation et diagnostic PC, honnête sur ce qui marche vraiment.

Ce logiciel n'active ni ne désactive jamais Windows Defender, le pare-feu, Windows Update, VBS,
l'intégrité de la mémoire ou Smart App Control. Les changements réversibles peuvent être annulés
depuis l'application. Aucune télémétrie, aucune connexion réseau en dehors des mises à jour.

## Installation

Ouvre PowerShell et lance :

```powershell
irm https://raw.githubusercontent.com/norgon2/Norgon-Tweaks/main/install.ps1 | iex
```

Ça télécharge la dernière version, installe l'app dans `%LOCALAPPDATA%\NorgonsTweaks`,
crée un raccourci dans le menu Démarrer et une entrée de désinstallation standard.

## Désinstallation

Depuis **Paramètres → Applications**, cherche "Norgon's Tweaks", ou lance
`%LOCALAPPDATA%\NorgonsTweaks\uninstall.ps1`.
