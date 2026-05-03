# ByteTrack Windows Setup Script (CPU-Optimized)
# Run this in PowerShell as Administrator if possible
# Execution: powershell -ExecutionPolicy Bypass -File .\setup_windows.ps1

Write-Host "--- Starting ByteTrack Setup for Windows ---" -ForegroundColor Cyan

# 0. Check Environment
Write-Host "[0/5] Checking environment..." -ForegroundColor Yellow
if (!(Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Python is not installed or not in PATH." -ForegroundColor Red
    Write-Host "Please install Python from python.org and check 'Add Python to PATH'." -ForegroundColor Yellow
    exit
}

python --version
python -m pip --version

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Pip is not working correctly." -ForegroundColor Red
    exit
}

# 1. Install Basic Requirements
Write-Host "[1/5] Installing dependencies from requirements.txt..." -ForegroundColor Yellow
python -m pip install --upgrade pip
python -m pip install -r requirements.txt

# ... (Step 2 and 3 remain same)

# 4. Create Pretrained Folder and Download Models
Write-Host "[4/5] Downloading pretrained models..." -ForegroundColor Yellow
if (!(Test-Path "pretrained")) { New-Item -ItemType Directory -Force -Path "pretrained" }
python -m gdown 1uSmhXzyV1Zvb4TJJCzpsZOIcw7CCJLxj -O pretrained/bytetrack_s_mot17.pth.tar
python -m gdown 1LFAl14sql2Q5Y9aNFsX_OqsnIzUD_1ju -O pretrained/bytetrack_tiny_mot17.pth.tar

# 5. Finalize
Write-Host "[5/5] Setup Complete!" -ForegroundColor Green
Write-Host "To run the demo, use the following command:" -ForegroundColor Cyan
Write-Host "`$env:PYTHONPATH = `"`$(Get-Location)`"; python tools/demo_track.py video -f exps/example/mot/yolox_tiny_cpu.py -c pretrained/bytetrack_tiny_mot17.pth.tar --device cpu --save_result" -ForegroundColor White

