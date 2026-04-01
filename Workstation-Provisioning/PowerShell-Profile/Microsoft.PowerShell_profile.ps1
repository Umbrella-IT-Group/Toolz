# PowerShell Profile - Alex Ivantsov @Exploitacious
# Windows equivalent of .zshrc

# --- ENCODING (fix Nerd Font / Unicode symbol rendering) ---
[console]::InputEncoding = [console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$OutputEncoding = [System.Text.UTF8Encoding]::new()

# --- OH MY POSH (load first so prompt renders while rest loads) ---
oh-my-posh init pwsh --config "$HOME\.config\ohmyposh\catppuccin_mocha.omp.json" | Invoke-Expression

# --- PSREADLINE ---
Set-PSReadLineOption -PredictionSource History -PredictionViewStyle ListView -EditMode Windows -BellStyle None
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -Function DeleteCharOrExit

# --- MODULES ---
Import-Module Terminal-Icons -ErrorAction SilentlyContinue
Import-Module z -ErrorAction SilentlyContinue

# --- ALIASES ---
# Shell
function c { Clear-Host }
function x { exit }
function r { . $PROFILE }
function h { Get-History | Select-Object -Last 10 }
function hc { Clear-History }

# Navigation
function cd.. { Set-Location .. }
function cd... { Set-Location ..\.. }

# Directory listing (colorized with Terminal-Icons)
function ll { Get-ChildItem -Force @args }
Remove-Item Alias:ls -Force -ErrorAction SilentlyContinue
function ls { Get-ChildItem -Force @args }

# Git
function gcu {
    git config user.name "Alex Ivantsov"
    git config user.email "alex@ivantsov.tech"
}
function gs { git status }
function gp { git pull }
function gd { git diff }
function gl { git log --oneline -15 }

# System / Utilities
function myip { (Invoke-WebRequest -Uri "http://ipecho.net/plain" -UseBasicParsing).Content }
function which { param($cmd) Get-Command $cmd -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source }
function touch { param($file) if (Test-Path $file) { (Get-Item $file).LastWriteTime = Get-Date } else { New-Item $file -ItemType File } }
function grep { param($pattern, $path) Select-String -Pattern $pattern -Path $path }
function tail { param($file, $n = 10) Get-Content $file -Tail $n }
function head { param($file, $n = 10) Get-Content $file -TotalCount $n }

# Quick edit
function e { code -n ~ $PROFILE }

# WSL shortcut
function wsl-home { Set-Location "\\wsl$\Ubuntu\home\master" }

# --- FASTFETCH ---
fastfetch
