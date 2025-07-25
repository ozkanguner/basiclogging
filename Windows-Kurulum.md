# Windows'ta MikroTik Log Toplama - Kurulum Rehberi

Bu proje Linux için tasarlanmıştır, ancak Windows'ta da çalıştırabilirsiniz.

## Seçenek 1: WSL (Windows Subsystem for Linux) - Önerilen

### WSL Kurulumu
1. **PowerShell'i yönetici olarak açın**
2. WSL'i etkinleştirin:
```powershell
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
```
3. **Bilgisayarı yeniden başlatın**
4. Ubuntu kurun:
```powershell
wsl --install -d Ubuntu
```

### WSL'de Proje Kurulumu
```bash
# Ubuntu'da çalıştırın
sudo apt update
sudo apt install -y git rsyslog

# Projeyi klonlayın
git clone https://github.com/ozkanguner/basiclogging.git
cd basiclogging

# Otomatik kurulum
sudo ./install.sh
```

### WSL Network Ayarları
WSL'de network portlarını Windows'a yönlendirmeniz gerekir:
```powershell
# PowerShell'de (yönetici olarak)
netsh interface portproxy add v4tov4 listenport=514 listenaddress=0.0.0.0 connectport=514 connectaddress=172.x.x.x
```

## Seçenek 2: Docker (Tavsiye edilen)

### Docker Desktop Kurulumu
1. [Docker Desktop](https://www.docker.com/products/docker-desktop)'u indirin ve kurun
2. Aşağıdaki Dockerfile'ı oluşturun:

```dockerfile
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y rsyslog && \
    rm -rf /var/lib/apt/lists/*

COPY 50-mikrotik-dynamic.conf /etc/rsyslog.d/

RUN mkdir -p /var/5651 && \
    chown -R syslog:adm /var/5651 && \
    chmod -R 755 /var/5651

EXPOSE 514/udp 514/tcp

CMD ["rsyslogd", "-n"]
```

### Docker ile Çalıştırma
```powershell
# Image oluşturun
docker build -t mikrotik-logger .

# Container başlatın
docker run -d -p 514:514/udp -p 514:514/tcp -v C:\logs:/var/5651 mikrotik-logger
```

## Seçenek 3: Windows Syslog Sunucuları

### Visual Syslog Server (Ücretsiz)
1. [Visual Syslog Server](https://github.com/MaxBelkov/visualsyslog)'ı indirin
2. Port 514'ü dinleyecek şekilde ayarlayın
3. MikroTik'ten gelen logları dosyaya kaydedin

### Kiwi Syslog Server (Ticari)
- Profesyonel kullanım için
- Gelişmiş filtreleme ve raporlama
- 30 günlük deneme sürümü mevcut

## Seçenek 4: PowerShell ile Basit UDP Listener

Windows PowerShell ile basit bir syslog sunucusu:

```powershell
# UDP 514 portunu dinleyen basit syslog sunucusu
$endpoint = [System.Net.IPEndPoint]::new([System.Net.IPAddress]::Any, 514)
$listener = [System.Net.Sockets.UdpClient]::new($endpoint)

Write-Host "Syslog sunucusu 514 portunda dinliyor..."

try {
    while ($true) {
        $result = $listener.ReceiveAsync()
        $result.Wait()
        
        $message = [System.Text.Encoding]::ASCII.GetString($result.Result.Buffer)
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp] $message"
        
        # Konsola yazdır
        Write-Host $logEntry
        
        # Dosyaya kaydet
        Add-Content -Path "C:\mikrotik-logs\$(Get-Date -Format 'yyyy-MM-dd').log" -Value $logEntry
    }
} finally {
    $listener.Close()
}
```

## Hangi Seçeneği Öneriyorum?

1. **Basit test için**: Seçenek 4 (PowerShell)
2. **Geliştirme ortamı**: Seçenek 1 (WSL)
3. **Üretim ortamı**: Seçenek 2 (Docker)
4. **Kurumsal kullanım**: Seçenek 3 (Ticari syslog sunucuları)

Hangi yolu tercih edersiniz? Size o yöntemi detayıyla anlatayım. 