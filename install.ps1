#requires -Version 5.1
param(
    [string]$InstallDirectory,
    [switch]$NoLaunch,
    [switch]$ShowSetup
)
$ErrorActionPreference = 'Stop'
$useGui = [bool]$ShowSetup
if ($useGui -and ($NoLaunch -or $PSBoundParameters.ContainsKey('InstallDirectory'))) { throw '-ShowSetup cannot be combined with -NoLaunch or -InstallDirectory.' }
if ($env:OS -ne 'Windows_NT' -or -not [Environment]::Is64BitOperatingSystem) {
    throw 'Kien requires 64-bit Windows 10 or later.'
}
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$repository = 'https://github.com/Iki2a/Kien-Releases'
$headers = @{ 'User-Agent' = 'Kien-Installer'; 'Accept' = 'application/vnd.github+json' }
Write-Host 'Kien - a floating notch for Windows'
Write-Host 'Checking the latest published release...'
for ($attempt = 1; $attempt -le 3; $attempt++) {
    try {
        $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/Iki2a/Kien-Releases/releases/latest' -Headers $headers -TimeoutSec 30
        break
    }
    catch {
        $status = 0
        if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
        if ($status -eq 404) {
            throw ('GitHub returned HTTP 404: no public stable Kien release was found. See ' + $repository + '/releases')
        }
        if ($status -eq 403 -or $status -eq 429) {
            throw ('GitHub returned HTTP ' + $status + ': access was denied or the request limit was reached. Wait before retrying, or download Kien-Setup.exe from ' + $repository + '/releases/latest')
        }
        if (($status -eq 0 -or $status -eq 408 -or $status -ge 500) -and $attempt -lt 3) {
            Write-Host 'GitHub could not be reached. Retrying...'
            Start-Sleep -Seconds (2 * $attempt)
            continue
        }
        $detail = if ($status) { 'HTTP ' + $status } else { $_.Exception.Message }
        throw ('Unable to check the Kien release (' + $detail + '). Check your connection, proxy, or firewall, then retry. Download page: ' + $repository + '/releases/latest')
    }
}
$asset = @($release.assets | Where-Object name -eq 'Kien-Setup.exe')
if ($asset.Count -ne 1 -or $release.draft -or $release.prerelease) { throw 'No stable Kien installer is available.' }
$asset = $asset[0]
$downloadUri = [Uri]$asset.browser_download_url
if ($downloadUri.Scheme -ne 'https' -or $downloadUri.Host -ne 'github.com' -or
    -not $downloadUri.AbsolutePath.StartsWith('/Iki2a/Kien-Releases/releases/download/', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Unexpected installer download location.'
}
if ([string]$asset.digest -notmatch '^sha256:([0-9a-fA-F]{64})$') { throw 'The release has no verified SHA-256 metadata.' }
$expectedHash = $Matches[1]
$existing = Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Kien' -ErrorAction SilentlyContinue
$existingPath = if ($existing) { [string]$existing.InstallLocation } else { '' }
if ($existingPath -and (Test-Path -LiteralPath (Join-Path $existingPath 'current\Kien.exe'))) {
    if ($InstallDirectory -and [IO.Path]::GetFullPath($InstallDirectory).TrimEnd('\') -ne $existingPath.TrimEnd('\')) {
        throw 'Uninstall the existing copy before selecting another installation folder.'
    }
    $InstallDirectory = $existingPath
}
if (-not $useGui) {
    if (-not $PSBoundParameters.ContainsKey('InstallDirectory') -and -not $InstallDirectory) {
        $InstallDirectory = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Kien'
    }
    if ($InstallDirectory -notmatch '^[a-zA-Z]:[\\/]' -or $InstallDirectory.Contains('"') -or
        $InstallDirectory.IndexOfAny([IO.Path]::GetInvalidPathChars()) -ge 0) { throw 'Choose an absolute folder on a local drive.' }
    $InstallDirectory = [IO.Path]::GetFullPath($InstallDirectory).TrimEnd('\')
    if ($InstallDirectory -eq [IO.Path]::GetPathRoot($InstallDirectory).TrimEnd('\')) { throw 'Select a folder inside the drive, such as D:\Apps\Kien.' }
    Write-Host ('Preparing Kien ' + $release.tag_name + '...')
}
else { Write-Host 'Setup will open so you can choose the installation folder using Browse.' }
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('KienDownload-' + [Guid]::NewGuid().ToString('N'))
$setupPath = Join-Path $temporary 'Kien-Setup.exe'
New-Item -ItemType Directory -Path $temporary | Out-Null
try {
    Write-Host 'Downloading Kien...'
    # WebClient streams to disk without PowerShell's large native progress panel.
    $client = New-Object System.Net.WebClient
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $downloadStarted = $false
    try {
        $client.Headers['User-Agent'] = 'Kien-Installer'
        $downloadTask = $client.DownloadFileTaskAsync($downloadUri, $setupPath)
        $downloadStarted = $true
        $lastPercent = -1
        $interactive = -not [Console]::IsOutputRedirected
        while (-not $downloadTask.IsCompleted) {
            if ($clock.Elapsed.TotalSeconds -ge 300) {
                $client.CancelAsync()
                throw 'The installer download timed out. Please retry.'
            }
            $received = if (Test-Path -LiteralPath $setupPath) { (Get-Item -LiteralPath $setupPath).Length } else { 0 }
            if ([long]$asset.size -gt 0) {
                $percent = [int][Math]::Min(99, [Math]::Floor(100.0 * $received / [long]$asset.size))
                if ($interactive -and $percent -ne $lastPercent) {
                    $filled = [int][Math]::Floor($percent / 5)
                    Write-Host ("`rDownloading [" + ('#' * $filled) + ('-' * (20 - $filled)) + ('] {0,3}%' -f $percent)) -NoNewline
                    $lastPercent = $percent
                }
            }
            elseif ($interactive) {
                Write-Host ("`rDownloading [{0,6:N1} MB received]" -f ($received / 1MB)) -NoNewline
            }
            Start-Sleep -Milliseconds 150
        }
        $downloadTask.GetAwaiter().GetResult()
        Write-Host ("`rDownloading [####################] 100%") -NoNewline
    }
    finally {
        $client.Dispose()
        $clock.Stop()
        if ($downloadStarted) { Write-Host '' }
    }
    if ((Get-FileHash -LiteralPath $setupPath -Algorithm SHA256).Hash -ne $expectedHash) { throw 'Installer checksum verification failed.' }
    $signature = Get-AuthenticodeSignature -LiteralPath $setupPath
    if ($signature.Status -eq 'NotSigned') {
        Write-Warning 'This Kien installer is not digitally signed. Windows cannot verify its publisher. The SHA-256 checksum matches the GitHub release, but this does not verify publisher identity.'
        $confirmation = Read-Host 'Install this unsigned Kien release? Windows security warnings may appear. [y/N]'
        if (([string]$confirmation).Trim() -inotmatch '^(y|yes)$') { Write-Host 'Installation cancelled.'; return }
    }
    elseif ($signature.Status -ne 'Valid') {
        throw ('The installer does not have a valid trusted signature (status: ' + $signature.Status + '). Installation stopped.')
    }
    # Preserve the Internet zone so Windows can apply its normal downloaded-file checks.
    Set-Content -LiteralPath $setupPath -Stream Zone.Identifier -Value ("[ZoneTransfer]`r`nZoneId=3`r`nHostUrl=" + $downloadUri.AbsoluteUri)
    if ($useGui) {
        $process = Start-Process -FilePath $setupPath -Wait -PassThru
        if ($process.ExitCode -ne 0) { throw ('Kien Setup exited with code ' + $process.ExitCode + '.') }
        return
    }
    Write-Host 'Installing Kien. Please wait...'
    $process = Start-Process -FilePath $setupPath -ArgumentList ('--silent --installto "' + $InstallDirectory + '"') -WindowStyle Hidden -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw ('Kien installation failed with exit code ' + $process.ExitCode + '. Check the selected folder and close Kien before retrying.') }
    $executable = Join-Path $InstallDirectory 'current\Kien.exe'
    if (-not (Test-Path -LiteralPath $executable)) { throw 'Kien was not found in the selected folder after installation.' }
    Write-Host 'Kien installed successfully.'
    if (-not $NoLaunch) { Start-Process -FilePath $executable -WorkingDirectory (Split-Path $executable -Parent) -ArgumentList '--startup' }
}
finally {
    # Only remove the known downloaded file and its empty temporary folder.
    if (Test-Path -LiteralPath $setupPath) { Remove-Item -LiteralPath $setupPath }
    if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary }
}
