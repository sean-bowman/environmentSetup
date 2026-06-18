<#
.SYNOPSIS
    Provisions Sean Bowman's Windows 11 development environment.

.DESCRIPTION
    Idempotent, winget-based replacement for the old VBScript/keypress installers.
    Installs core tooling (VS Code, Miniconda, Git, Node.js, .NET SDK, Rust), sets
    up a Python 3.10 scientific stack, wires up a thermodynamic backend (REFPROP if
    already present, otherwise open-source CoolProp), and installs VS Code extensions.

    Designed to be run two ways:
      1. From a clone:   pwsh ./scripts/bootstrap.ps1
      2. Remotely (USB):  powershell -NoProfile -ExecutionPolicy Bypass -Command
                          "irm <raw-url>/scripts/bootstrap.ps1 | iex"

    When run remotely, the package lists (requirements.txt, vscode-extensions.txt)
    are fetched from $RepoRawBase. When run from a clone, the local files are used.

.NOTES
    Author : Sean Bowman
    Target : Windows 11 (winget required; ships with Win11)
    Most installs are user-scope and do not require administrator rights. A few
    packages (e.g. the .NET SDK) may request elevation; failures are reported,
    not fatal, so the rest of the environment still provisions.
#>

[CmdletBinding()]
param(
    # Raw base URL of the published repo (used only when run remotely).
    [string]$RepoRawBase = 'https://raw.githubusercontent.com/sean-bowman/environmentSetup/main',

    # Python version to pin in the conda base environment.
    [string]$PythonVersion = '3.10',

    # Skip the winget application installs (useful when only refreshing Python/extensions).
    [switch]$SkipWinget
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Write-Step  { param([string]$Message) Write-Host "`n==> $Message" -ForegroundColor Cyan }
function Write-Ok    { param([string]$Message) Write-Host "    [ok] $Message" -ForegroundColor Green }
function Write-Warn2 { param([string]$Message) Write-Host "    [warn] $Message" -ForegroundColor Yellow }

function Update-SessionPath {
    # Refresh PATH from the registry so freshly-installed tools resolve without a new shell.
    $machine = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user    = [System.Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = ($machine, $user | Where-Object { $_ }) -join ';'
}

function Test-WingetInstalled {
    param([string]$Id)
    # winget list returns non-zero when the package is absent.
    winget list --id $Id -e --accept-source-agreements 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function Install-WingetPackage {
    param([string]$Id, [string]$Name)
    if (Test-WingetInstalled -Id $Id) {
        Write-Ok "$Name already installed ($Id)"
        return
    }
    Write-Host "    installing $Name ($Id)..."
    try {
        winget install --id $Id -e --silent `
            --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -eq 0) { Write-Ok "$Name installed" }
        else { Write-Warn2 "$Name returned exit code $LASTEXITCODE (may need elevation; continuing)" }
    } catch {
        Write-Warn2 "Failed to install ${Name}: $($_.Exception.Message)"
    }
}

function Get-ListItems {
    # Read a list file (requirements.txt / vscode-extensions.txt) from the local
    # scripts dir if available, otherwise fetch it from the published repo.
    param([string]$FileName)

    $content = $null
    if ($PSScriptRoot) {
        $local = Join-Path $PSScriptRoot $FileName
        if (Test-Path $local) { $content = Get-Content -Raw -Path $local }
    }
    if (-not $content) {
        $url = "$RepoRawBase/scripts/$FileName"
        try { $content = Invoke-RestMethod -Uri $url -UseBasicParsing }
        catch { Write-Warn2 "Could not read $FileName (local or $url)"; return @() }
    }
    return $content -split "`r?`n" |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith('#') }
}

function Resolve-Conda {
    # Return the path to conda.exe, searching PATH then the default user install.
    $cmd = Get-Command conda -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $candidate = Join-Path $env:USERPROFILE 'miniconda3\Scripts\conda.exe'
    if (Test-Path $candidate) { return $candidate }
    return $null
}

# ---------------------------------------------------------------------------
# 1. Core applications via winget
# ---------------------------------------------------------------------------

if (-not $SkipWinget) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'winget not found. Install "App Installer" from the Microsoft Store and re-run.'
    }

    Write-Step 'Installing core applications (winget)'
    Install-WingetPackage -Id 'Microsoft.VisualStudioCode' -Name 'Visual Studio Code'
    Install-WingetPackage -Id 'Anaconda.Miniconda3'        -Name 'Miniconda3'
    Install-WingetPackage -Id 'Git.Git'                    -Name 'Git'
    Install-WingetPackage -Id 'OpenJS.NodeJS'              -Name 'Node.js'
    Install-WingetPackage -Id 'Microsoft.DotNet.SDK.10'    -Name '.NET SDK 10'
    Install-WingetPackage -Id 'Rustlang.Rustup'            -Name 'Rust (rustup)'
    Install-WingetPackage -Id 'Anthropic.ClaudeCode'       -Name 'Claude Code'
    Update-SessionPath
} else {
    Write-Step 'Skipping winget application installs (-SkipWinget)'
}

# ---------------------------------------------------------------------------
# 2. Python scientific environment (conda base, pinned to $PythonVersion)
# ---------------------------------------------------------------------------

Write-Step "Configuring Python $PythonVersion scientific environment"
$conda = Resolve-Conda
if (-not $conda) {
    Write-Warn2 'conda not found on PATH yet. Open a new terminal and re-run with -SkipWinget to finish the Python setup.'
} else {
    Write-Ok "Using conda at $conda"

    # Pin base Python to the preferred version if it differs.
    $current = (& $conda run -n base python -c 'import platform; print(platform.python_version())' 2>$null)
    if ($current -notlike "$PythonVersion*") {
        Write-Host "    base python is '$current'; pinning to $PythonVersion..."
        & $conda install -n base -y "python=$PythonVersion"
    } else {
        Write-Ok "base python already $current"
    }

    Write-Host '    installing scientific stack (numpy, scipy, pandas, matplotlib)...'
    & $conda install -n base -y numpy scipy pandas matplotlib

    # Thermodynamic backend: prefer an existing REFPROP install, else CoolProp.
    $refpropDir = Join-Path $env:USERPROFILE 'REFPROP'
    if (Test-Path $refpropDir) {
        Write-Ok "REFPROP found at $refpropDir -> installing ctREFPROP wrapper"
        & $conda run -n base python -m pip install --upgrade ctREFPROP
        # ctREFPROP reads RPPREFIX to locate the REFPROP install.
        [System.Environment]::SetEnvironmentVariable('RPPREFIX', $refpropDir, 'User')
        Write-Ok "Set user environment variable RPPREFIX=$refpropDir"
    } else {
        Write-Warn2 'REFPROP not found -> installing open-source CoolProp instead'
        & $conda run -n base python -m pip install --upgrade CoolProp
    }

    # Remaining pip packages from requirements.txt.
    $pipPkgs = Get-ListItems -FileName 'requirements.txt'
    if ($pipPkgs.Count -gt 0) {
        Write-Host "    pip installing: $($pipPkgs -join ', ')"
        & $conda run -n base python -m pip install --upgrade @pipPkgs
    }
    Write-Ok 'Python environment ready'
}

# ---------------------------------------------------------------------------
# 3. VS Code extensions
# ---------------------------------------------------------------------------

Write-Step 'Installing VS Code extensions'
Update-SessionPath
if (Get-Command code -ErrorAction SilentlyContinue) {
    $extensions = Get-ListItems -FileName 'vscode-extensions.txt'
    foreach ($ext in $extensions) {
        Write-Host "    installing $ext..."
        code --install-extension $ext --force | Out-Null
    }
    Write-Ok "Processed $($extensions.Count) extension(s)"
} else {
    Write-Warn2 "'code' CLI not on PATH yet. Open a new terminal and re-run with -SkipWinget to install extensions."
}

Write-Step 'Done'
Write-Host 'Environment provisioning complete. Open a new terminal so all PATH changes take effect.' -ForegroundColor Green
