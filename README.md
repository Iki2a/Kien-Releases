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

GitHub automatically generates source archive links for this distribution repository. Those archives contain this README, not the private Kien application source. Update packages contain compiled binaries and are used by the updater.
