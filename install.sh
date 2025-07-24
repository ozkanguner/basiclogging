#!/bin/bash

# Basic Logging System - Ubuntu Server Installation Script
# Bu script rsyslog konfigürasyonunu otomatik olarak kurar

echo "=== Basic Logging System Kurulumu Başlıyor ==="

# Root yetkisi kontrolü
if [[ $EUID -ne 0 ]]; then
   echo "Bu script root yetkisi ile çalıştırılmalıdır (sudo kullanın)"
   exit 1
fi

# rsyslog kurulu mu kontrol et
if ! command -v rsyslogd &> /dev/null; then
    echo "rsyslog kuruluyor..."
    apt update
    apt install -y rsyslog
else
    echo "rsyslog zaten kurulu ✓"
fi

# Konfigürasyon dosyasını kopyala
echo "Konfigürasyon dosyası kopyalanıyor..."
cp 50-mikrotik-dynamic.conf /etc/rsyslog.d/

# Dosya yetkilerini ayarla
chmod 644 /etc/rsyslog.d/50-mikrotik-dynamic.conf
chown root:root /etc/rsyslog.d/50-mikrotik-dynamic.conf

# rsyslog servisini etkinleştir ve başlat
echo "rsyslog servisi ayarlanıyor..."
systemctl enable rsyslog
systemctl restart rsyslog

# Servis durumunu kontrol et
if systemctl is-active --quiet rsyslog; then
    echo "✓ rsyslog servisi başarıyla çalışıyor"
else
    echo "✗ rsyslog servisi başlatılamadı"
    systemctl status rsyslog
    exit 1
fi

# 514 portunu kontrol et
echo "514 portları kontrol ediliyor..."
if ss -tuln | grep -q ":514"; then
    echo "✓ 514 portu dinleniyor"
    ss -tuln | grep ":514"
else
    echo "⚠ 514 portu dinlenmiyor - rsyslog konfigürasyonunu kontrol edin"
fi

# 5651 yasası için ana klasör oluştur
echo "5651 yasası için klasör yapısı oluşturuluyor..."
mkdir -p /var/5651
chown -R syslog:adm /var/5651
chmod -R 755 /var/5651

# Test log klasörü oluştur
echo "Test klasörü oluşturuluyor..."
mkdir -p /var/5651/test-device/test-interface
chown -R syslog:adm /var/5651/test-device

# Konfigürasyon dosyasını test et
echo "Konfigürasyon test ediliyor..."
if rsyslogd -N1 >/dev/null 2>&1; then
    echo "✓ rsyslog konfigürasyonu geçerli"
else
    echo "✗ rsyslog konfigürasyonu hatası!"
    echo "Detaylar için: sudo rsyslogd -N1"
fi

# UFW firewall kontrol et ve öner
if command -v ufw &> /dev/null; then
    if ufw status | grep -q "Status: active"; then
        echo ""
        echo "⚠ UFW firewall aktif. 514 portunu açmak için:"
        echo "sudo ufw allow 514/udp"
        echo "sudo ufw allow 514/tcp"
    else
        echo "✓ UFW firewall deaktif"
    fi
fi

echo ""
echo "=== Kurulum Tamamlandı ==="
echo ""
echo "📁 5651 Log Klasörleri: /var/5651/[cihaz-ip]/[interface-adı]/"
echo "👀 Canlı İzleme: sudo tail -f /var/5651/*/*/\$(date +%Y-%m-%d).log"
echo "🔧 Port Kontrolü: sudo ss -tuln | grep 514"
echo "📊 Log Analizi: sudo grep 'src-mac' /var/5651/*/*/\$(date +%Y-%m-%d).log"
echo ""
echo "🎯 Sıradaki Adımlar:"
echo "1. MikroTik cihazlarınızda syslog ayarlarını yapın"
echo "2. Firewall kurallarını ekleyin"
echo "3. Test logları gönderin"
echo ""
echo "📖 Detaylı kullanım: https://github.com/ozkanguner/basiclogging" 