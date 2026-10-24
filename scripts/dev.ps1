# Atalhos para Windows (PowerShell). Equivalente ao Makefile do Linux.
# Uso:  .\scripts\dev.ps1 up
#       .\scripts\dev.ps1 down | reset | logs | test | setup
param(
    [Parameter(Position = 0)]
    [ValidateSet("setup", "up", "down", "reset", "logs", "test", "seed", "seed-remove", "pay-sim", "invite-sim", "help")]
    [string]$Command = "help",

    [Parameter(Position = 1)]
    [string]$Team = "",

    [Parameter(Position = 2)]
    [string]$Email = "",

    [Parameter(Position = 3)]
    [string]$Tournament = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Ensure-Env {
    if (-not (Test-Path ".env")) {
        Copy-Item ".env.example" ".env"
        Write-Host ".env criado a partir de .env.example"
    }
}

switch ($Command) {
    "setup" { Ensure-Env }
    "up" {
        Ensure-Env
        docker compose up --build -d
        Write-Host "API:     http://localhost:8080/health"
        Write-Host "MailHog: http://localhost:8025"
    }
    "down"  { docker compose down }
    "reset" { docker compose down -v }
    "logs"  { docker compose logs -f api }
    "test"  {
        docker run --rm -v "${root}\backend:/src" -w /src mcr.microsoft.com/dotnet/sdk:10.0 dotnet test
    }
    "seed" {
        Get-Content "backend\seed\demo_tournaments.sql" -Raw -Encoding UTF8 | docker compose exec -T postgres psql -U gamehall -d gamehall -v ON_ERROR_STOP=1
    }
    "seed-remove" {
        Get-Content "backend\seed\remove_demo.sql" -Raw -Encoding UTF8 | docker compose exec -T postgres psql -U gamehall -d gamehall -v ON_ERROR_STOP=1
    }
    "pay-sim" {
        if (-not $Team) { Write-Host 'Uso: .\scripts\dev.ps1 pay-sim "Nome da equipa"'; exit 1 }
        Get-Content "backend\seed\dev_mark_paid.sql" -Raw -Encoding UTF8 | docker compose exec -T postgres psql -U gamehall -d gamehall -v ON_ERROR_STOP=1 -v "team=$Team"
    }
    "invite-sim" {
        if (-not $Team -or -not $Email) { Write-Host 'Uso: .\scripts\dev.ps1 invite-sim "Nome da equipa" eu@exemplo.pt "parte do nome do torneio"'; exit 1 }
        Get-Content "backend\seed\dev_invite.sql" -Raw -Encoding UTF8 | docker compose exec -T postgres psql -U gamehall -d gamehall -v ON_ERROR_STOP=1 -v "team=$Team" -v "email=$Email" -v "tournament=$Tournament"
    }
    default {
        Write-Host "Comandos: setup | up | down | reset | logs | test | seed | seed-remove | pay-sim | invite-sim"
    }
}
