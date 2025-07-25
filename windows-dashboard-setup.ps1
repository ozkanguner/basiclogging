# MikroTik Log Dashboard - Windows Setup
# Bu script Windows'ta yerel dashboard kurar ve log analizi yapar

Write-Host "🌐 === MİKROTİK DASHBOARD - WINDOWS SETUP ===" -ForegroundColor Green
Write-Host "Log dosyalarını analiz edip web dashboard'u başlatır" -ForegroundColor White
Write-Host

# Gerekli dizinleri oluştur
$DashboardDir = ".\mikrotik-dashboard"
$LogsDir = "$DashboardDir\logs"

Write-Host "📁 Dizinler oluşturuluyor..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path $DashboardDir | Out-Null
New-Item -ItemType Directory -Force -Path $LogsDir | Out-Null

# HTML dosyasını kopyala
Write-Host "📋 Dashboard dosyaları hazırlanıyor..." -ForegroundColor Yellow
Copy-Item "mikrotik-dashboard.html" "$DashboardDir\index.html" -ErrorAction SilentlyContinue

# Python kontrolü
Write-Host "🐍 Python kontrolü..." -ForegroundColor Yellow
try {
    $pythonVersion = python --version 2>&1
    Write-Host "✅ Python bulundu: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Python bulunamadı! Python kurmanız gerekiyor." -ForegroundColor Red
    Write-Host "https://python.org adresinden Python indirin" -ForegroundColor Red
    exit 1
}

# Log dosyalarını kontrol et
Write-Host "📊 Log dosyaları kontrol ediliyor..." -ForegroundColor Yellow
$logFiles = Get-ChildItem -Path "." -Name "*.log" -ErrorAction SilentlyContinue
$zipFiles = Get-ChildItem -Path "." -Name "mikrotik-logs-*.zip" -ErrorAction SilentlyContinue

if ($zipFiles.Count -gt 0) {
    Write-Host "📦 ZIP dosyası bulundu: $($zipFiles[0])" -ForegroundColor Green
    
    # ZIP'i çıkar
    Write-Host "📂 ZIP dosyası çıkarılıyor..." -ForegroundColor Yellow
    try {
        Expand-Archive -Path $zipFiles[0] -DestinationPath $LogsDir -Force
        Write-Host "✅ ZIP dosyası çıkarıldı" -ForegroundColor Green
    } catch {
        Write-Host "❌ ZIP çıkarma hatası: $($_.Exception.Message)" -ForegroundColor Red
    }
} elseif ($logFiles.Count -gt 0) {
    Write-Host "📋 Log dosyaları bulundu: $($logFiles.Count) adet" -ForegroundColor Green
    foreach ($logFile in $logFiles) {
        Copy-Item $logFile $LogsDir -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "⚠️ Log dosyası bulunamadı!" -ForegroundColor Yellow
    Write-Host "Önce sunucudan log dosyalarını indirin:" -ForegroundColor White
    Write-Host "  1. Sunucuda: ./log-download.sh" -ForegroundColor Cyan
    Write-Host "  2. ZIP dosyasını bu klasöre kopyalayın" -ForegroundColor Cyan
    Write-Host "  3. Bu scripti tekrar çalıştırın" -ForegroundColor Cyan
    Write-Host
}

# PowerShell log analiz scripti oluştur
Write-Host "⚙️ Log analiz scripti oluşturuluyor..." -ForegroundColor Yellow

$logAnalysisScript = @'
# MikroTik Log Analysis Script
param($LogsPath = ".\logs")

function Analyze-MikroTikLogs {
    param($LogsPath)
    
    $today = Get-Date -Format "yyyy-MM-dd"
    $currentHour = (Get-Date).Hour
    
    # Log dosyalarını bul
    $logFiles = Get-ChildItem -Path $LogsPath -Recurse -Name "*.log" -ErrorAction SilentlyContinue
    
    if ($logFiles.Count -eq 0) {
        Write-Host "Log dosyası bulunamadı!" -ForegroundColor Red
        return $null
    }
    
    Write-Host "📊 $($logFiles.Count) log dosyası analiz ediliyor..." -ForegroundColor Yellow
    
    # Tüm log içeriğini oku
    $allLogs = @()
    foreach ($logFile in $logFiles) {
        $fullPath = Join-Path $LogsPath $logFile
        try {
            $content = Get-Content $fullPath -ErrorAction Stop
            $allLogs += $content
        } catch {
            Write-Warning "Dosya okunamadı: $logFile"
        }
    }
    
    Write-Host "📋 Toplam $($allLogs.Count) log satırı işleniyor..." -ForegroundColor Yellow
    
    # Sultanahmet logları
    $sultanahmetLogs = $allLogs | Where-Object { $_ -match "92\.113\.42\.3" }
    $sultanahmetTotal = $sultanahmetLogs.Count
    
    # Maslak logları  
    $maslakLogs = $allLogs | Where-Object { $_ -match "92\.113\.42\.253" }
    $maslakTotal = $maslakLogs.Count
    
    # Interface analizi
    $sultanahmetInterfaces = $sultanahmetLogs | Where-Object { $_ -match "in:([A-Za-z0-9_]+)" } | 
        ForEach-Object { if ($_ -match "in:([A-Za-z0-9_]+)") { $Matches[1] } } | 
        Group-Object | Sort-Object Count -Descending
    
    $maslakInterfaces = $maslakLogs | Where-Object { $_ -match "in:([A-Za-z0-9_]+)" } | 
        ForEach-Object { if ($_ -match "in:([A-Za-z0-9_]+)") { $Matches[1] } } | 
        Group-Object | Sort-Object Count -Descending
    
    # Saatlik aktivite (son 6 saat simülasyonu)
    $hourlyData = @()
    for ($i = 5; $i -ge 0; $i--) {
        $hour = (Get-Date).AddHours(-$i).Hour
        $hourStr = $hour.ToString("00")
        $hourLogs = $allLogs | Where-Object { $_ -match "$hourStr:" }
        $hourlyData += $hourLogs.Count
    }
    
    # Sonuç objesi
    $result = @{
        sultanahmet = @{
            total = $sultanahmetTotal
            hourly = ($sultanahmetLogs | Where-Object { $_ -match (Get-Date -Format "HH:") }).Count
            interfaces = $sultanahmetInterfaces.Count
            status = if ($sultanahmetTotal -gt 0) { "online" } else { "offline" }
        }
        maslak = @{
            total = $maslakTotal
            hourly = ($maslakLogs | Where-Object { $_ -match (Get-Date -Format "HH:") }).Count
            interfaces = $maslakInterfaces.Count
            status = if ($maslakTotal -gt 0) { "online" } else { "offline" }
        }
        hourlyData = $hourlyData
        totalSize = "$(($allLogs.Count * 100 / 1024).ToString("F1")) KB"
        interfaces = @()
        lastUpdate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    # En aktif interface'leri ekle
    $topInterfaces = @()
    if ($sultanahmetInterfaces.Count -gt 0) {
        $sultanahmetInterfaces | Select-Object -First 5 | ForEach-Object {
            $topInterfaces += @{
                name = $_.Name
                device = "Sultanahmet"
                count = $_.Count
                lastSeen = "az önce"
                status = "active"
            }
        }
    }
    
    if ($maslakInterfaces.Count -gt 0) {
        $maslakInterfaces | Select-Object -First 5 | ForEach-Object {
            $topInterfaces += @{
                name = $_.Name
                device = "Maslak"
                count = $_.Count
                lastSeen = "az önce"
                status = "active"
            }
        }
    }
    
    $result.interfaces = $topInterfaces | Sort-Object count -Descending | Select-Object -First 10
    
    return $result
}

# Ana analiz
$analysisResult = Analyze-MikroTikLogs -LogsPath $LogsPath

if ($analysisResult) {
    # JSON olarak kaydet
    $json = $analysisResult | ConvertTo-Json -Depth 10
    $json | Out-File -FilePath ".\mikrotik-dashboard\data.json" -Encoding UTF8
    
    Write-Host "✅ Analiz tamamlandı!" -ForegroundColor Green
    Write-Host "📊 Sonuçlar:" -ForegroundColor White
    Write-Host "  - Sultanahmet: $($analysisResult.sultanahmet.total) logs" -ForegroundColor Cyan
    Write-Host "  - Maslak: $($analysisResult.maslak.total) logs" -ForegroundColor Cyan
    Write-Host "  - Toplam interface: $($analysisResult.sultanahmet.interfaces + $analysisResult.maslak.interfaces)" -ForegroundColor Cyan
    Write-Host "  - Veri boyutu: $($analysisResult.totalSize)" -ForegroundColor Cyan
} else {
    Write-Host "❌ Analiz başarısız!" -ForegroundColor Red
}
'@

$logAnalysisScript | Out-File -FilePath "$DashboardDir\analyze-logs.ps1" -Encoding UTF8

# Log analizi çalıştır
Write-Host "📊 Log analizi başlatılıyor..." -ForegroundColor Yellow
try {
    & PowerShell -ExecutionPolicy Bypass -File "$DashboardDir\analyze-logs.ps1" -LogsPath $LogsDir
} catch {
    Write-Host "❌ Log analiz hatası: $($_.Exception.Message)" -ForegroundColor Red
}

# Web server başlatma scripti
Write-Host "🌐 Web server scripti oluşturuluyor..." -ForegroundColor Yellow

$webServerScript = @'
import http.server
import socketserver
import webbrowser
import os
import threading
import time

class MyHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()

def start_server():
    PORT = 8080
    os.chdir('mikrotik-dashboard')
    
    with socketserver.TCPServer(("", PORT), MyHTTPRequestHandler) as httpd:
        print(f"🌐 Dashboard başlatıldı: http://localhost:{PORT}")
        print("🔄 Otomatik yenileme: Her 30 saniye")
        print("⏹️  Durdurmak için Ctrl+C")
        print()
        
        # 2 saniye sonra browser'ı aç
        def open_browser():
            time.sleep(2)
            webbrowser.open(f'http://localhost:{PORT}')
        
        threading.Thread(target=open_browser, daemon=True).start()
        
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n👋 Dashboard kapatıldı")
            httpd.shutdown()

if __name__ == "__main__":
    start_server()
'@

$webServerScript | Out-File -FilePath "$DashboardDir\start-server.py" -Encoding UTF8

# Başlatma batch dosyası
$batchScript = @'
@echo off
echo 🌐 MikroTik Dashboard Başlatılıyor...
cd /d "%~dp0"
python start-server.py
pause
'@

$batchScript | Out-File -FilePath "$DashboardDir\start-dashboard.bat" -Encoding ASCII

Write-Host
Write-Host "🎉 === KURULUM TAMAMLANDI ===" -ForegroundColor Green
Write-Host
Write-Host "📍 Dashboard klasörü: $DashboardDir" -ForegroundColor White
Write-Host "📊 Veri dosyası: $DashboardDir\data.json" -ForegroundColor White
Write-Host
Write-Host "🚀 Dashboard'u başlatmak için:" -ForegroundColor Yellow
Write-Host "   1. $DashboardDir\start-dashboard.bat dosyasını çift tıklayın" -ForegroundColor Cyan
Write-Host "   VEYA" -ForegroundColor White
Write-Host "   2. PowerShell'de: cd $DashboardDir; python start-server.py" -ForegroundColor Cyan
Write-Host
Write-Host "🌐 Dashboard adresi: http://localhost:8080" -ForegroundColor Green
Write-Host
Write-Host "🔄 Logları güncellemek için:" -ForegroundColor Yellow
Write-Host "   PowerShell -ExecutionPolicy Bypass -File $DashboardDir\analyze-logs.ps1" -ForegroundColor Cyan

# Eğer log dosyaları varsa hemen başlat
if ((Get-ChildItem -Path $LogsDir -Recurse -Name "*.log" -ErrorAction SilentlyContinue).Count -gt 0) {
    Write-Host
    $response = Read-Host "🚀 Dashboard'u şimdi başlatmak ister misiniz? (y/N)"
    if ($response -eq 'y' -or $response -eq 'Y') {
        Write-Host "🌐 Dashboard başlatılıyor..." -ForegroundColor Green
        Start-Process "cmd" -ArgumentList "/c `"cd /d `"$((Get-Location).Path)\$DashboardDir`" && start-dashboard.bat`""
    }
} 