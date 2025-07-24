# Basic Logging System

MikroTik cihazlarından gelen logları otomatik olarak cihaz adı ve interface'e göre klasörlere ayıran rsyslog konfigürasyon sistemi.

## Özellikler

- ✅ Otomatik klasör oluşturma (cihaz adına göre)
- ✅ Interface bazında alt klasörler
- ✅ Günlük dosya rotasyonu
- ✅ 5651 yasası uyumlu loglama
- ✅ Dinamik konfigürasyon

## Kurulum

### 1. rsyslog Konfigürasyonu

```bash
# Konfigürasyon dosyasını kopyala
sudo cp 50-mikrotik-dynamic.conf /etc/rsyslog.d/

# rsyslog'u yeniden başlat
sudo systemctl restart rsyslog
```

### 2. Log Dizini Yapısı

```
/var/log/
├── trasst.maslak-hotspot/
│   ├── 42_MASLAK_AVM/
│   │   └── 2024-07-24.log
│   ├── genel/
│   │   └── 2024-07-24.log
│   └── other/
│       └── 2024-07-24.log
└── [diğer-cihaz-adları]/
    └── [interface-adları]/
        └── günlük-dosyalar.log
```

### 3. MikroTik Ayarları

#### Syslog Action Oluşturma
```bash
/system logging action
add name=remote-syslog target=remote remote=RSYSLOG_SUNUCU_IP remote-port=514
```

#### Firewall Logging
```bash
# Tüm forward trafiği
/ip firewall filter add chain=forward action=log log-prefix="TUM_TRAFIK"

# Syslog'a gönder
/system logging add topics=firewall action=remote-syslog
/system logging add topics=hotspot action=remote-syslog
```

## Kullanım

### Log İzleme

```bash
# Belirli cihazın logları
sudo tail -f /var/log/trasst.maslak-hotspot/42_MASLAK_AVM/$(date +%Y-%m-%d).log

# Tüm interface logları
sudo tail -f /var/log/*/*/$(date +%Y-%m-%d).log

# Klasör yapısını görüntüle
sudo find /var/log -name "*.log" -type f | head -20
```

### Log Analizi

```bash
# Günlük trafik istatistikleri
sudo grep "forward:" /var/log/*/*/$(date +%Y-%m-%d).log | wc -l

# IP bazında analiz
sudo grep "172.6.2" /var/log/*/*/$(date +%Y-%m-%d).log

# MAC bazında analiz (5651 yasası için önemli)
sudo grep "f2:6d:cd:48:1c:74" /var/log/*/*/$(date +%Y-%m-%d).log

# Belirli MAC'in hangi IP'leri kullandığı
sudo grep "src-mac f2:6d:cd:48:1c:74" /var/log/*/*/$(date +%Y-%m-%d).log | grep -o "172\.[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+"

# MAC-IP eşleştirme tablosu
sudo grep "src-mac" /var/log/*/*/$(date +%Y-%m-%d).log | sed 's/.*src-mac \([^,]*\).*\([0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\):\([0-9]*\).*/\1 \2/' | sort | uniq

# Gece saatlerinde aktif MAC adresleri
sudo grep "0[0-6]:[0-9][0-9]:" /var/log/*/*/$(date +%Y-%m-%d).log | grep -o "src-mac [^,]*" | sort | uniq

# En çok trafik üreten MAC adresleri
sudo grep "src-mac" /var/log/*/*/$(date +%Y-%m-%d).log | grep -o "src-mac [^,]*" | sort | uniq -c | sort -nr | head -10
```

## 5651 Yasası Uyumluluğu

### MAC Adres Takibi
Her log kaydında aşağıdaki bilgiler bulunur:
- **Kaynak MAC**: `src-mac f2:6d:cd:48:1c:74`
- **Kaynak IP**: `172.6.2.134:53471`
- **Hedef IP**: `2.23.154.18:80`
- **Zaman Damgası**: `Jul 24 14:29:59`
- **Interface**: `in:42_MASLAK_AVM`

### Yasal Sorgu Örnekleri

```bash
# Belirli MAC adresinin tüm aktiviteleri
sudo grep "src-mac aa:bb:cc:dd:ee:ff" /var/log/*/*/2024-07-24.log

# Belirli tarih aralığındaki tüm MAC adresleri
find /var/log -name "2024-07-2*.log" -exec grep "src-mac" {} \; | grep -o "src-mac [^,]*" | sort | uniq

# Hotspot login bilgileri ile MAC eşleştirme
sudo grep "logged in\|logged out" /var/log/*/genel/$(date +%Y-%m-%d).log
```

## Konfigürasyon Detayları

- **Cihaz Adı**: `%fromhost%` değişkeni kullanılır
- **Interface**: Log mesajından `in:INTERFACE_ADI` regex ile çıkarılır
- **Tarih**: `%$year%-%$month%-%$day%` formatında
- **Yetkilendirme**: `syslog:adm` kullanıcı/grup

## Gereksinimler

- Ubuntu 20.04+
- rsyslog 8.0+
- MikroTik RouterOS 6.40+

## Lisans

MIT License 