#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Fix Network After VPN - восстанавливает интернет после некорректного отключения VPN.
.DESCRIPTION
    Чистит таблицу маршрутизации, DNS-кэш, обновляет DHCP-аренду
    и опционально сбрасывает Winsock/TCP-IP стек.
#>

[CmdletBinding()]
param(
    [switch]$ResetStack  # если указан, выполняет netsh winsock/ip reset (нужна перезагрузка)
)

$ErrorActionPreference = 'Continue'

function Step {
    param([string]$Name, [scriptblock]$Action)
    Write-Host "==> $Name" -ForegroundColor Cyan
    try {
        & $Action
        Write-Host "    OK" -ForegroundColor Green
    } catch {
        Write-Host "    FAIL: $_" -ForegroundColor Yellow
    }
}

Step "Flush routing table"      { route -f | Out-Null }
Step "Flush DNS cache"          { ipconfig /flushdns | Out-Null }
Step "Register DNS"             { ipconfig /registerdns | Out-Null }
Step "Release DHCP lease"       { ipconfig /release | Out-Null }
Step "Renew DHCP lease"         { ipconfig /renew | Out-Null }

if ($ResetStack) {
    Step "Reset Winsock catalog"    { netsh winsock reset | Out-Null }
    Step "Reset TCP/IP stack"       { netsh int ip reset | Out-Null }
    Write-Host ""
    Write-Host "Winsock/TCP-IP stack has been reset. Reboot is recommended." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Done. Try opening a website now." -ForegroundColor Green
