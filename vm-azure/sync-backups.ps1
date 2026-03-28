param(
    [string]$TerraformDir = ".",
    [string]$WorkspaceRoot,
    [string]$SshPrivateKeyPath = "$HOME/.ssh/id_rsa",
    [string]$AdminUser,
    [string]$RemoteBaseDir = "/opt/updates",
    [switch]$IncludeBastion
)

$ErrorActionPreference = "Stop"

function Invoke-External {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [switch]$CaptureOutput
    )

    if ($CaptureOutput) {
        $result = & $Command @Arguments 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Command failed: $Command $($Arguments -join ' ')`n$result"
        }
        return ($result -join "`n")
    }

    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed: $Command $($Arguments -join ' ')"
    }
}

function Test-CommandExists {
    param([Parameter(Mandatory = $true)][string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $Name"
    }
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $WorkspaceRoot) {
    $WorkspaceRoot = Resolve-Path (Join-Path $scriptDir "..")
}

$terraformDirResolved = Resolve-Path $TerraformDir
$workspaceRootResolved = Resolve-Path $WorkspaceRoot
$backupSourceDir = Join-Path $workspaceRootResolved "backup"
$helmSourceDir = Join-Path $workspaceRootResolved "helm_bak_20260318"

if (-not (Test-Path $backupSourceDir)) {
    throw "Source folder not found: $backupSourceDir"
}
if (-not (Test-Path $helmSourceDir)) {
    throw "Source folder not found: $helmSourceDir"
}

if (-not (Test-Path $SshPrivateKeyPath)) {
    throw "SSH private key not found: $SshPrivateKeyPath"
}

Test-CommandExists -Name "terraform"
Test-CommandExists -Name "ssh"
Test-CommandExists -Name "scp"
Test-CommandExists -Name "tar"

$terraformOutputRaw = Invoke-External -Command "terraform" -Arguments @("-chdir=$terraformDirResolved", "output", "-json") -CaptureOutput
$terraformOutput = $terraformOutputRaw | ConvertFrom-Json

if (-not $terraformOutput.bastion_public_ip.value) {
    throw "terraform output bastion_public_ip is empty"
}
if (-not $terraformOutput.vm_private_ips.value) {
    throw "terraform output vm_private_ips is empty"
}

if (-not $AdminUser) {
    $AdminUser = "iwon"
}

$bastionIp = $terraformOutput.bastion_public_ip.value
$vmPrivateIpMap = $terraformOutput.vm_private_ips.value
$targetVmNames = @($vmPrivateIpMap.PSObject.Properties.Name)

if (-not $IncludeBastion) {
    $targetVmNames = $targetVmNames | Where-Object { $_ -ne "bastion01" }
}

if (-not $targetVmNames -or $targetVmNames.Count -eq 0) {
    throw "No target VMs found. Check terraform outputs or -IncludeBastion option."
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$tempDir = Join-Path $env:TEMP "vm-sync-$timestamp"
New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

$backupArchive = Join-Path $tempDir "backup.tar.gz"
$helmArchive = Join-Path $tempDir "helm_bak_20260318.tar.gz"

Write-Host "[1/5] Creating archives..."
Push-Location $workspaceRootResolved
try {
    Invoke-External -Command "tar" -Arguments @("-czf", $backupArchive, "backup")
    Invoke-External -Command "tar" -Arguments @("-czf", $helmArchive, "helm_bak_20260318")
} finally {
    Pop-Location
}

$backupHash = (Get-FileHash -Path $backupArchive -Algorithm SHA256).Hash.ToLowerInvariant()
$helmHash = (Get-FileHash -Path $helmArchive -Algorithm SHA256).Hash.ToLowerInvariant()

Write-Host "[2/5] Local SHA256"
Write-Host " backup.tar.gz           : $backupHash"
Write-Host " helm_bak_20260318.tar.gz: $helmHash"

$results = @()

foreach ($vmName in $targetVmNames) {
    $vmPrivateIp = $vmPrivateIpMap.$vmName
    Write-Host "[3/5] Syncing $vmName ($vmPrivateIp)"

    $commonSshOptions = @(
        "-o", "StrictHostKeyChecking=accept-new",
        "-i", $SshPrivateKeyPath,
        "-J", "$AdminUser@$bastionIp"
    )

    try {
        $prepareCmd = @(
            "sudo mkdir -p $RemoteBaseDir",
            "sudo chown ${AdminUser}:${AdminUser} $RemoteBaseDir",
            "if [ -d $RemoteBaseDir/backup ]; then mv $RemoteBaseDir/backup $RemoteBaseDir/backup.bak.$timestamp; fi",
            "if [ -d $RemoteBaseDir/helm_bak_20260318 ]; then mv $RemoteBaseDir/helm_bak_20260318 $RemoteBaseDir/helm_bak_20260318.bak.$timestamp; fi"
        ) -join " ; "

        Invoke-External -Command "ssh" -Arguments @($commonSshOptions + @("$AdminUser@$vmPrivateIp", $prepareCmd))

        Invoke-External -Command "scp" -Arguments @(
            "-o", "StrictHostKeyChecking=accept-new",
            "-i", $SshPrivateKeyPath,
            "-J", "$AdminUser@$bastionIp",
            $backupArchive,
            $helmArchive,
            "${AdminUser}@${vmPrivateIp}:$RemoteBaseDir/"
        )

        $verifyAndExtract = @(
            "cd $RemoteBaseDir",
            'remote_backup_hash=$(sha256sum backup.tar.gz | awk ''{print $1}'')',
            'remote_helm_hash=$(sha256sum helm_bak_20260318.tar.gz | awk ''{print $1}'')',
            ('if [ "{0}" != "$remote_backup_hash" ]; then echo ''backup archive checksum mismatch''; exit 11; fi' -f $backupHash),
            ('if [ "{0}" != "$remote_helm_hash" ]; then echo ''helm archive checksum mismatch''; exit 12; fi' -f $helmHash),
            "tar -xzf backup.tar.gz",
            "tar -xzf helm_bak_20260318.tar.gz",
            "rm -f backup.tar.gz helm_bak_20260318.tar.gz",
            "test -d $RemoteBaseDir/backup",
            "test -d $RemoteBaseDir/helm_bak_20260318",
            "echo sync-ok"
        ) -join " ; "

        $verifyResult = Invoke-External -Command "ssh" -Arguments @($commonSshOptions + @("$AdminUser@$vmPrivateIp", $verifyAndExtract)) -CaptureOutput

        $results += [PSCustomObject]@{
            vm      = $vmName
            ip      = $vmPrivateIp
            status  = "SUCCESS"
            message = ($verifyResult -replace "\r", "" -replace "\n", " ").Trim()
        }
    } catch {
        $results += [PSCustomObject]@{
            vm      = $vmName
            ip      = $vmPrivateIp
            status  = "FAILED"
            message = $_.Exception.Message
        }
    }
}

Write-Host "[4/5] Result Summary"
$results | Format-Table -AutoSize

$failed = $results | Where-Object { $_.status -eq "FAILED" }

Write-Host "[5/5] Cleanup temp files"
Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

if ($failed.Count -gt 0) {
    throw "Sync completed with failures. Failed count: $($failed.Count)"
}

Write-Host "All target VMs synced successfully."
