param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RawArgs
)

$ErrorActionPreference = 'Continue'

function Show-Usage {
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  register-keys.cmd [vault-name] [list-file] [--debug]"
    Write-Host "  register-keys.cmd [list-file] [--debug]"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  register-keys.cmd"
    Write-Host "  register-keys.cmd .\\.keyvault-list"
    Write-Host "  register-keys.cmd iwonsvckvkrc001 .\\.keyvault-list --debug"
    Write-Host ""
}

$rawArgs = @($RawArgs)

if ($rawArgs -contains '/?' -or $rawArgs -contains '-h' -or $rawArgs -contains '--help') {
    Show-Usage
    exit 0
}

$debug = $true
$args = @()
foreach ($a in $rawArgs) {
    if ($a -eq '--debug' -or $a -eq '-d') {
        $debug = $true
    }
    else {
        $args += $a
    }
}

$vaultName = $env:VAULT_NAME
if ([string]::IsNullOrWhiteSpace($vaultName)) {
    $vaultName = 'iwonsvckvkrc001'
}

$listFile = $null
if ($args.Count -eq 1) {
    if (Test-Path -LiteralPath $args[0]) {
        $listFile = $args[0]
    }
    else {
        $vaultName = $args[0]
    }
}
elseif ($args.Count -ge 2) {
    $vaultName = $args[0]
    $listFile = $args[1]
}

if ([string]::IsNullOrWhiteSpace($listFile)) {
    $listFile = Join-Path $PSScriptRoot '.keyvault-list'
}

if (-not (Test-Path -LiteralPath $listFile)) {
    Write-Host "[ERROR] List file not found: $listFile"
    Show-Usage
    exit 1
}

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host '[ERROR] az CLI not found. Install Azure CLI first.'
    exit 1
}

& az account show --query id -o tsv 1>$null 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host '[ERROR] Azure login is required. Run: az login'
    exit 1
}

Write-Host "[INFO] Target Key Vault: $vaultName"
Write-Host "[INFO] List file: $listFile"
Write-Host '[INFO] Registering secrets...'

[int]$processed = 0
[int]$failed = 0
[int]$skipped = 0

function Upsert-Secret {
    param(
        [string]$Name,
        [string]$Value,
        [string]$Description
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return
    }

    if ([string]::IsNullOrEmpty($Value)) {
        $script:skipped++
        Write-Host "[WARN] Skip $Name (value is empty)"
        return
    }

    $tempValueFile = Join-Path $env:TEMP ("kvval_{0}.txt" -f ([Guid]::NewGuid().ToString('N')))
    [System.IO.File]::WriteAllText($tempValueFile, $Value, [System.Text.UTF8Encoding]::new($false))

    $azArgs = @(
        'keyvault', 'secret', 'set',
        '--vault-name', $vaultName,
        '--name', $Name,
        '--file', $tempValueFile,
        '--encoding', 'utf-8',
        '--only-show-errors'
    )

    if (-not [string]::IsNullOrWhiteSpace($Description)) {
        $azArgs += @('--tags', "description=$Description")
    }

    $azOutput = $null
    try {
        $azOutput = & az @azArgs 2>&1
    }
    catch {
        $azOutput = $_
    }
    finally {
        if (Test-Path -LiteralPath $tempValueFile) {
            Remove-Item -LiteralPath $tempValueFile -Force -ErrorAction SilentlyContinue
        }
    }

    if ($LASTEXITCODE -ne 0) {
        $script:failed++
        Write-Host "[ERROR] Failed to set $Name (exit=$LASTEXITCODE)"
        if ($debug -and $null -ne $azOutput) {
            Write-Host "[DEBUG] az error for ${Name}:"
            $azOutput | ForEach-Object { Write-Host "[DEBUG] $_" }
        }
        return
    }

    $script:processed++
    if ($debug) {
        Write-Host "[OK] $Name"
    }
}

$ext = [System.IO.Path]::GetExtension($listFile)

if ($ext -ieq '.md') {
    Get-Content -LiteralPath $listFile | ForEach-Object {
        if ($_ -match '\*\*([A-Z0-9_-]+)\*\*') {
            $key = $matches[1]
            if ($debug) {
                Write-Host "[DEBUG] markdown key=$key"
            }
            $val = [Environment]::GetEnvironmentVariable($key)
            Upsert-Secret -Name $key -Value $val -Description $null
        }
    }
}
else {
    $pendingDesc = ''
    Get-Content -LiteralPath $listFile | ForEach-Object {
        $line = $_
        if ([string]::IsNullOrWhiteSpace($line)) {
            return
        }

        $trim = $line.TrimStart()
        if ($trim.StartsWith('#')) {
            $pendingDesc = $trim.Substring(1).Trim()
            if ($debug) {
                Write-Host "[DEBUG] comment=$pendingDesc"
            }
            return
        }

        $parts = $line -split '=', 2
        $key = $parts[0].Trim()
        $val = ''
        if ($parts.Length -gt 1) {
            $val = $parts[1]
        }

        if ($debug) {
            Write-Host "[DEBUG] env key=$key hasInlineValue=$([bool]($val -ne ''))"
        }

        if ([string]::IsNullOrEmpty($val)) {
            $val = [Environment]::GetEnvironmentVariable($key)
        }

        Upsert-Secret -Name $key -Value $val -Description $pendingDesc
        $pendingDesc = ''
    }
}

Write-Host ''
Write-Host "[SUMMARY] Processed: $processed, Failed: $failed, Skipped: $skipped"

if ($failed -gt 0) {
    exit 1
}
exit 0
