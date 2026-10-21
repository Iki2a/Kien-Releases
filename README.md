# Kien

**a floating notch for Windows**

Installers and automatic update packages for Kien.

## Installation

[**Download Kien-Setup.exe**](https://github.com/Iki2a/Kien-Releases/releases/latest/download/Kien-Setup.exe)

The download becomes available after the first release is published. Run the installer to set up Kien.

During setup, use **Browse** to choose a folder on the drive you prefer, for example `D:\Apps\Kien`. Updates keep the existing installation folder. To move an existing installation to another drive, uninstall it and install again.

Requires 64-bit Windows 10 build 19041 or later. Setup installs the .NET 8 Desktop Runtime if it is missing; the runtime download requires internet.

## Updates

Installed copies check for updates in the background after startup and every six hours. Updates are downloaded automatically and applied when Kien exits or starts again. You can also choose **Restart to update Kien** from the tray menu.

To try an installer while a developer copy is running, exit that copy from the tray first.

This repository contains release binaries and update metadata. Application source is maintained separately in a private repository.

GitHub automatically generates source archive links for this distribution repository. Those archives contain this README and the public installation helper, not the private Kien application source. Update packages contain compiled binaries and are used by the updater.


## Install from PowerShell

Run this command in PowerShell:

```powershell
& { $ProgressPreference = 'SilentlyContinue'; irm 'https://raw.githubusercontent.com/Iki2a/Kien-Releases/4ae835111e8067aba34e92d3eae4bf25e7b90c4c/install.ps1' | iex }
```

The command downloads Kien, verifies its SHA-256 checksum, installs it to `%LOCALAPPDATA%\Kien`, and opens the application. It does not ask for an installation folder or open the Setup wizard. Existing installations keep their current folder.

For unsigned releases, the command explains that the publisher cannot be verified and asks for confirmation with `[y/N]` before installation (`y` continues; `n` or Enter cancels). The default is to cancel. Windows security warnings may still appear. Invalid signatures and mismatched checksums are rejected. Draft releases are not installed.

Advanced options: `-InstallDirectory` selects a custom folder, `-NoLaunch` skips opening Kien after installation, and `-ShowSetup` opens the optional folder-picker wizard. The downloadable EXE still provides the graphical installer.
