# MikroTik Log Dashboard - Dashboard Klasöründe Kurulum
# Bu script mevcut dashboard klasöründe yerel analiz kurar

Write-Host "🌐 === MİKROTİK DASHBOARD - KLASÖR İÇİ KURULUM ===" -ForegroundColor Green
Write-Host "Bu klasörde log analizi ve web dashboard kuruluyor..." -ForegroundColor White
Write-Host

# Mevcut klasörü kontrol et
$CurrentDir = Get-Location
Write-Host "📍 Kurulum klasörü: $CurrentDir" -ForegroundColor Cyan

# Alt klasörleri oluştur
$LogsDir = ".\logs"
$ConfigDir = ".\config"

Write-Host "📁 Alt klasörler oluşturuluyor..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path $LogsDir | Out-Null
New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null

# Ana klasörden HTML dosyasını kopyala
Write-Host "📋 Dashboard dosyalarını kopyalıyor..." -ForegroundColor Yellow
if (Test-Path "..\mikrotik-dashboard.html") {
    Copy-Item "..\mikrotik-dashboard.html" ".\index.html" -ErrorAction SilentlyContinue
    Write-Host "✅ HTML dosyası kopyalandı" -ForegroundColor Green
} else {
    Write-Host "⚠️ mikrotik-dashboard.html bulunamadı, ana klasörde olduğundan emin olun" -ForegroundColor Yellow
}

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

# Log dosyalarını kontrol et (ana klasörde ve bu klasörde)
Write-Host "📊 Log dosyaları aranıyor..." -ForegroundColor Yellow
$logFiles = @()
$zipFiles = @()

# Bu klasörde ara
$logFiles += Get-ChildItem -Path "." -Name "*.log" -ErrorAction SilentlyContinue
$zipFiles += Get-ChildItem -Path "." -Name "mikrotik-logs-*.zip" -ErrorAction SilentlyContinue

# Ana klasörde ara
$logFiles += Get-ChildItem -Path ".." -Name "*.log" -ErrorAction SilentlyContinue
$zipFiles += Get-ChildItem -Path ".." -Name "mikrotik-logs-*.zip" -ErrorAction SilentlyContinue

if ($zipFiles.Count -gt 0) {
    $zipFile = $zipFiles[0]
    $zipPath = if (Test-Path ".\$zipFile") { ".\$zipFile" } else { "..\$zipFile" }
    
    Write-Host "📦 ZIP dosyası bulundu: $zipFile" -ForegroundColor Green
    
    # ZIP'i çıkar
    Write-Host "📂 ZIP dosyası çıkarılıyor..." -ForegroundColor Yellow
    try {
        Expand-Archive -Path $zipPath -DestinationPath $LogsDir -Force
        Write-Host "✅ ZIP dosyası logs klasörüne çıkarıldı" -ForegroundColor Green
    } catch {
        Write-Host "❌ ZIP çıkarma hatası: $($_.Exception.Message)" -ForegroundColor Red
    }
} elseif ($logFiles.Count -gt 0) {
    Write-Host "📋 Log dosyaları bulundu: $($logFiles.Count) adet" -ForegroundColor Green
    foreach ($logFile in $logFiles) {
        $sourcePath = if (Test-Path ".\$logFile") { ".\$logFile" } else { "..\$logFile" }
        Copy-Item $sourcePath $LogsDir -ErrorAction SilentlyContinue
    }
    Write-Host "✅ Log dosyaları logs klasörüne kopyalandı" -ForegroundColor Green
} else {
    Write-Host "⚠️ Log dosyası bulunamadı!" -ForegroundColor Yellow
    Write-Host "Log dosyalarını almak için:" -ForegroundColor White
    Write-Host "  1. Sunucuda: ./log-download.sh çalıştırın" -ForegroundColor Cyan
    Write-Host "  2. ZIP dosyasını bu klasöre veya ana klasöre kopyalayın" -ForegroundColor Cyan
    Write-Host "  3. Bu scripti tekrar çalıştırın" -ForegroundColor Cyan
    Write-Host
}

# PowerShell log analiz scripti oluştur
Write-Host "⚙️ Log analiz scripti hazırlanıyor..." -ForegroundColor Yellow

$logAnalysisScript = @'
# MikroTik Log Analysis Script
param($LogsPath = ".\logs")

function Analyze-MikroTikLogs {
    param($LogsPath)
    
    Write-Host "🔍 Log analizi başlıyor..." -ForegroundColor Yellow
    Write-Host "📂 Logs klasörü: $LogsPath" -ForegroundColor Cyan
    
    # Log dosyalarını bul
    $logFiles = Get-ChildItem -Path $LogsPath -Recurse -Include "*.log" -ErrorAction SilentlyContinue
    
    if ($logFiles.Count -eq 0) {
        Write-Host "❌ Log dosyası bulunamadı: $LogsPath" -ForegroundColor Red
        return $null
    }
    
    Write-Host "📊 $($logFiles.Count) log dosyası bulundu, analiz ediliyor..." -ForegroundColor Yellow
    
    # Tüm log içeriğini oku
    $allLogs = @()
    foreach ($logFile in $logFiles) {
        Write-Host "📄 Dosya okunuyor: $($logFile.Name)" -ForegroundColor Gray
        try {
            $content = Get-Content $logFile.FullName -ErrorAction Stop
            $allLogs += $content
        } catch {
            Write-Warning "Dosya okunamadı: $($logFile.Name)"
        }
    }
    
    Write-Host "📋 Toplam $($allLogs.Count) log satırı işleniyor..." -ForegroundColor Yellow
    
    if ($allLogs.Count -eq 0) {
        Write-Host "❌ Hiç log satırı bulunamadı!" -ForegroundColor Red
        return $null
    }
    
    # Sultanahmet logları (92.113.42.3)
    $sultanahmetLogs = $allLogs | Where-Object { $_ -match "92\.113\.42\.3" }
    $sultanahmetTotal = $sultanahmetLogs.Count
    Write-Host "🏢 Sultanahmet logları: $sultanahmetTotal" -ForegroundColor Green
    
    # Maslak logları (92.113.42.253)
    $maslakLogs = $allLogs | Where-Object { $_ -match "92\.113\.42\.253" }
    $maslakTotal = $maslakLogs.Count
    Write-Host "🏙️ Maslak logları: $maslakTotal" -ForegroundColor Green
    
    # Interface analizi - Sultanahmet (otel isimleri)
    $sultanahmetInterfaces = $sultanahmetLogs | Where-Object { $_ -match "in:([A-Za-z0-9_\-\.]+)" } | 
        ForEach-Object { 
            if ($_ -match "in:([A-Za-z0-9_\-\.]+)") { 
                $Matches[1] 
            } 
        } | 
        Group-Object | Sort-Object Count -Descending
    
    # Interface analizi - Maslak (network isimleri)
    $maslakInterfaces = $maslakLogs | Where-Object { $_ -match "in:([A-Za-z0-9_\-\.]+)" } | 
        ForEach-Object { 
            if ($_ -match "in:([A-Za-z0-9_\-\.]+)") { 
                $Matches[1] 
            } 
        } | 
        Group-Object | Sort-Object Count -Descending
    
    Write-Host "🔌 Sultanahmet interface'leri: $($sultanahmetInterfaces.Count)" -ForegroundColor Green
    Write-Host "🔌 Maslak interface'leri: $($maslakInterfaces.Count)" -ForegroundColor Green
    
    # Saatlik aktivite simülasyonu (son 6 saat)
    $hourlyData = @()
    for ($i = 5; $i -ge 0; $i--) {
        $hour = (Get-Date).AddHours(-$i).Hour
        $hourStr = $hour.ToString("00")
        $hourLogs = $allLogs | Where-Object { $_ -match "$hourStr:" }
        $hourlyData += $hourLogs.Count
    }
    
    # Sonuç objesi oluştur
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
        totalSize = "$(($allLogs.Count * 150 / 1024).ToString("F1")) KB"
        interfaces = @()
        lastUpdate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        hostnames = @{
            sultanahmet = "sultanahmet-hotspot.trasst.com"
            maslak = "trasst.maslak-hotspot"
        }
    }
    
    # En aktif interface'leri ekle
    $topInterfaces = @()
    
    # Sultanahmet'ten en aktif 5 interface
    if ($sultanahmetInterfaces.Count -gt 0) {
        $sultanahmetInterfaces | Select-Object -First 5 | ForEach-Object {
            $topInterfaces += @{
                name = $_.Name
                device = "Sultanahmet"
                count = $_.Count
                lastSeen = "veri analizi"
                status = "active"
            }
        }
        Write-Host "🔥 En aktif Sultanahmet interface: $($sultanahmetInterfaces[0].Name) ($($sultanahmetInterfaces[0].Count) logs)" -ForegroundColor Cyan
    }
    
    # Maslak'tan en aktif 5 interface
    if ($maslakInterfaces.Count -gt 0) {
        $maslakInterfaces | Select-Object -First 5 | ForEach-Object {
            $topInterfaces += @{
                name = $_.Name
                device = "Maslak"
                count = $_.Count
                lastSeen = "veri analizi"
                status = "active"
            }
        }
        Write-Host "🔥 En aktif Maslak interface: $($maslakInterfaces[0].Name) ($($maslakInterfaces[0].Count) logs)" -ForegroundColor Cyan
    }
    
    $result.interfaces = $topInterfaces | Sort-Object count -Descending | Select-Object -First 10
    
    return $result
}

# Ana analiz fonksiyonunu çalıştır
$analysisResult = Analyze-MikroTikLogs -LogsPath $LogsPath

if ($analysisResult) {
    # JSON olarak kaydet
    $json = $analysisResult | ConvertTo-Json -Depth 10
    $json | Out-File -FilePath ".\data.json" -Encoding UTF8
    
    Write-Host ""
    Write-Host "✅ === ANALİZ TAMAMLANDI ===" -ForegroundColor Green
    Write-Host "📊 Sonuçlar:" -ForegroundColor White
    Write-Host "  🏢 Sultanahmet: $($analysisResult.sultanahmet.total) logs" -ForegroundColor Cyan
    Write-Host "  🏙️ Maslak: $($analysisResult.maslak.total) logs" -ForegroundColor Cyan
    Write-Host "  🔌 Toplam interface: $($analysisResult.sultanahmet.interfaces + $analysisResult.maslak.interfaces)" -ForegroundColor Cyan
    Write-Host "  💾 Veri boyutu: $($analysisResult.totalSize)" -ForegroundColor Cyan
    Write-Host "  📅 Son güncelleme: $($analysisResult.lastUpdate)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📄 JSON dosyası oluşturuldu: data.json" -ForegroundColor Green
} else {
    Write-Host "❌ Analiz başarısız!" -ForegroundColor Red
}
'@

$logAnalysisScript | Out-File -FilePath ".\analyze-logs.ps1" -Encoding UTF8

# Web server Python scripti
Write-Host "🌐 Web server scripti hazırlanıyor..." -ForegroundColor Yellow

$webServerScript = @'
import http.server
import socketserver
import webbrowser
import os
import threading
import time
import json

class DashboardHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()
    
    def do_GET(self):
        if self.path == '/':
            self.path = '/index.html'
        elif self.path == '/data.json':
            # JSON dosyasını oku ve sun
            try:
                with open('data.json', 'r', encoding='utf-8') as f:
                    data = f.read()
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(data.encode('utf-8'))
                return
            except:
                # Hata durumunda demo data
                demo_data = {
                    "sultanahmet": {"total": 0, "hourly": 0, "interfaces": 0, "status": "offline"},
                    "maslak": {"total": 0, "hourly": 0, "interfaces": 0, "status": "offline"},
                    "hourlyData": [0, 0, 0, 0, 0, 0],
                    "totalSize": "0 KB",
                    "interfaces": [],
                    "lastUpdate": "Demo veriler"
                }
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps(demo_data).encode('utf-8'))
                return
        
        super().do_GET()

def start_server():
    PORT = 8080
    
    print("🌐 === MİKROTİK DASHBOARD BAŞLATILIYOR ===")
    print(f"📍 Klasör: {os.getcwd()}")
    print(f"🔗 Adres: http://localhost:{PORT}")
    print("🔄 Otomatik yenileme: Her 30 saniye")
    print("⏹️  Durdurmak için: Ctrl+C")
    print("=" * 50)
    
    with socketserver.TCPServer(("", PORT), DashboardHandler) as httpd:
        # 2 saniye sonra browser'ı aç
        def open_browser():
            time.sleep(2)
            webbrowser.open(f'http://localhost:{PORT}')
            print("🌐 Tarayıcı açıldı!")
        
        threading.Thread(target=open_browser, daemon=True).start()
        
        try:
            print("🚀 Server başlatıldı... Bekleniyor.")
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n👋 Dashboard kapatıldı")
            httpd.shutdown()

if __name__ == "__main__":
    start_server()
'@

$webServerScript | Out-File -FilePath ".\start-server.py" -Encoding UTF8

# Başlatma batch dosyası
$batchScript = @'
@echo off
title MikroTik Log Dashboard
echo 🌐 === MİKROTİK LOG DASHBOARD ===
echo Başlatılıyor...
echo.
cd /d "%~dp0"
python start-server.py
echo.
echo Dashboard kapatıldı. Çıkmak için bir tuşa basın...
pause >nul
'@

$batchScript | Out-File -FilePath ".\start-dashboard.bat" -Encoding ASCII

# README dosyası oluştur
$readmeContent = @'
# 🗺️ MikroTik Log Dashboard

Bu klasör MikroTik log analizi için hazırlanmış interaktif dashboard içerir.

## 📁 Klasör Yapısı
- `index.html` - Ana dashboard sayfası
- `data.json` - Log analiz sonuçları (JSON format)
- `analyze-logs.ps1` - PowerShell log analiz scripti
- `start-server.py` - Python web server
- `start-dashboard.bat` - Hızlı başlatma dosyası
- `logs/` - Log dosyaları klasörü
- `config/` - Konfigürasyon dosyaları

## 🚀 Hızlı Başlama

### 1. Dashboard'u Başlat
Dashboard'u başlatmak için:
```
start-dashboard.bat
```
**VEYA** PowerShell'de:
```
python start-server.py
```

### 2. Logları Güncelle
Yeni log dosyalarını analiz etmek için:
```
PowerShell -ExecutionPolicy Bypass -File analyze-logs.ps1
```

### 3. Dashboard'a Eriş
Tarayıcıda: http://localhost:8080

## 🔄 Log Güncellemesi
1. Sunucudan yeni logları indirin
2. ZIP dosyasını bu klasöre koyun
3. `dashboard-kurulum.ps1` scriptini çalıştırın
4. Dashboard otomatik güncellenecek

## 📊 Dashboard Özellikleri
- ✅ Gerçek zamanlı MikroTik log analizi
- ✅ Sultanahmet ve Maslak cihaz izleme
- ✅ Interface aktivite haritası
- ✅ Saatlik log grafikleri
- ✅ En aktif bağlantılar tablosu

## 🛠️ Sorun Giderme
- Python yüklü değilse: https://python.org
- Port 8080 kullanımdaysa start-server.py'da PORT değerini değiştirin
- Log bulunamazsa logs/ klasörünü kontrol edin
'@

$readmeContent | Out-File -FilePath ".\README.md" -Encoding UTF8

# İlk log analizi yap (eğer log varsa)
if ((Get-ChildItem -Path $LogsDir -Recurse -Include "*.log" -ErrorAction SilentlyContinue).Count -gt 0) {
    Write-Host "📊 İlk log analizi başlatılıyor..." -ForegroundColor Yellow
    try {
        & PowerShell -ExecutionPolicy Bypass -File ".\analyze-logs.ps1" -LogsPath $LogsDir
    } catch {
        Write-Host "❌ İlk analiz hatası: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host
Write-Host "🎉 === KURULUM TAMAMLANDI ===" -ForegroundColor Green
Write-Host
Write-Host "📍 Dashboard klasörü: $CurrentDir" -ForegroundColor White
Write-Host "📄 Ana sayfa: index.html" -ForegroundColor White
Write-Host "📊 Veri dosyası: data.json" -ForegroundColor White
Write-Host "📚 Yardım: README.md" -ForegroundColor White
Write-Host
Write-Host "🚀 Dashboard'u başlatmak için:" -ForegroundColor Yellow
Write-Host "   1. start-dashboard.bat dosyasını çift tıklayın" -ForegroundColor Cyan
Write-Host "   2. VEYA PowerShell'de: python start-server.py" -ForegroundColor Cyan
Write-Host
Write-Host "🌐 Dashboard adresi: http://localhost:8080" -ForegroundColor Green
Write-Host
Write-Host "🔄 Logları güncellemek için:" -ForegroundColor Yellow
Write-Host "   PowerShell -ExecutionPolicy Bypass -File analyze-logs.ps1" -ForegroundColor Cyan

# Dosya listesini göster
Write-Host
Write-Host "📂 Oluşturulan dosyalar:" -ForegroundColor White
Get-ChildItem -Path "." -File | ForEach-Object {
    Write-Host "   ✅ $($_.Name)" -ForegroundColor Green
}

# Hemen başlatma seçeneği
Write-Host
if ((Get-ChildItem -Path $LogsDir -Recurse -Include "*.log" -ErrorAction SilentlyContinue).Count -gt 0) {
    $response = Read-Host "🚀 Dashboard'u şimdi başlatmak ister misiniz? (Y/n)"
    if ($response -eq '' -or $response -eq 'y' -or $response -eq 'Y') {
        Write-Host "🌐 Dashboard başlatılıyor..." -ForegroundColor Green
        Write-Host "Tarayıcıda http://localhost:8080 açılacak..." -ForegroundColor Cyan
        Start-Process "python" -ArgumentList "start-server.py"
    }
} else {
    Write-Host "💡 Log dosyası olmadığı için demo verilerle çalışacak" -ForegroundColor Yellow
    $response = Read-Host "🚀 Demo dashboard'u başlatmak ister misiniz? (Y/n)"
    if ($response -eq '' -or $response -eq 'y' -or $response -eq 'Y') {
        Write-Host "🌐 Demo dashboard başlatılıyor..." -ForegroundColor Green
        Start-Process "python" -ArgumentList "start-server.py"
    }
} 