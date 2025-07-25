#!/bin/bash

# MikroTik Log Sistemi - Ubuntu Hata Giderme Script'i
# Bu script sistemin durumunu kontrol eder ve sorunları tespit eder

echo "=== MikroTik Log Sistemi Hata Giderme ==="
echo "Sistem: $(lsb_release -d | cut -f2)"
echo "Tarih: $(date)"
echo ""

# Fonksiyon: Başlık yazdır
print_header() {
    echo ""
    echo "==================== $1 ===================="
}

# Fonksiyon: Test sonucu
test_result() {
    if [ $1 -eq 0 ]; then
        echo "✓ $2"
    else
        echo "✗ $2"
    fi
}

# 1. rsyslog Servis Durumu
print_header "RSYSLOG SERVİS DURUMU"
systemctl is-active rsyslog > /dev/null 2>&1
test_result $? "rsyslog servisi aktif"

systemctl is-enabled rsyslog > /dev/null 2>&1
test_result $? "rsyslog servisi otomatik başlatma aktif"

echo ""
echo "Servis Detayları:"
systemctl status rsyslog --no-pager -l

# 2. Konfigürasyon Dosyası Kontrolü
print_header "KONFİGÜRASYON DOSYASI"

if [ -f "/etc/rsyslog.d/50-mikrotik-dynamic.conf" ]; then
    echo "✓ Konfigürasyon dosyası mevcut: /etc/rsyslog.d/50-mikrotik-dynamic.conf"
    
    echo ""
    echo "Dosya İçeriği:"
    cat /etc/rsyslog.d/50-mikrotik-dynamic.conf
    
    echo ""
    echo "Dosya İzinleri:"
    ls -la /etc/rsyslog.d/50-mikrotik-dynamic.conf
else
    echo "✗ Konfigürasyon dosyası bulunamadı!"
fi

# 3. Konfigürasyon Sözdizimi Testi
print_header "KONFİGÜRASYON SÖZDİZİMİ"
rsyslogd -N1 > /tmp/rsyslog_test.log 2>&1
if [ $? -eq 0 ]; then
    echo "✓ Konfigürasyon sözdizimi doğru"
else
    echo "✗ Konfigürasyon sözdizimi hatası!"
    echo "Hata detayları:"
    cat /tmp/rsyslog_test.log
fi

# 4. Port Dinleme Durumu
print_header "PORT DİNLEME DURUMU"

# UDP 514
ss -tuln | grep ":514.*UDP" > /dev/null 2>&1
test_result $? "UDP 514 portu dinleniyor"

# TCP 514
ss -tuln | grep ":514.*LISTEN" > /dev/null 2>&1
test_result $? "TCP 514 portu dinleniyor"

echo ""
echo "Aktif Portlar (514):"
ss -tuln | grep ":514"

# 5. rsyslog Konfigürasyonu
print_header "RSYSLOG KONFİGÜRASYONU"

echo "Ana rsyslog.conf UDP ayarları:"
grep -n "^[^#]*514" /etc/rsyslog.conf || echo "514 portu ana konfigürasyonda tanımlı değil"

echo ""
echo "Modül yükleme durumu:"
grep -n "^module.*imudp" /etc/rsyslog.conf || echo "UDP modülü ana konfigürasyonda yüklü değil"

# 6. Log Klasörleri ve İzinler
print_header "LOG KLASÖR ve İZİNLER"

if [ -d "/var/5651" ]; then
    echo "✓ Ana log klasörü mevcut: /var/5651"
    echo ""
    echo "Klasör İzinleri:"
    ls -la /var/5651/
    
    echo ""
    echo "Sahiplik ve İzinler:"
    stat /var/5651
else
    echo "✗ Ana log klasörü bulunamadı: /var/5651"
    echo "Klasör oluşturuluyor..."
    mkdir -p /var/5651
    chown -R syslog:adm /var/5651
    chmod -R 755 /var/5651
    echo "✓ Klasör oluşturuldu"
fi

# 7. Firewall Durumu
print_header "FIREWALL DURUMU"

if command -v ufw > /dev/null 2>&1; then
    ufw_status=$(ufw status | head -1)
    echo "UFW Durumu: $ufw_status"
    
    if echo "$ufw_status" | grep -q "inactive"; then
        echo "✓ UFW firewall kapalı - port engeli yok"
    else
        echo "UFW kuralları:"
        ufw status | grep 514 || echo "✗ 514 portu için kural bulunamadı"
    fi
else
    echo "UFW kurulu değil"
fi

# 8. Sistem Logları
print_header "SİSTEM LOGLARI"

echo "Son rsyslog hataları:"
journalctl -u rsyslog --since "1 hour ago" --no-pager -l | tail -10

echo ""
echo "Syslog mesajları (son 5 satır):"
tail -5 /var/log/syslog

# 9. Test Log Gönderimi
print_header "TEST LOG GÖNDERİMİ"

echo "Yerel test log gönderiliyor..."
logger -p local0.info "TEST: MikroTik log sistemi test mesajı - $(date)"

echo "Test mesajının sistem logunda görünmesi bekleniyor..."
sleep 2
tail -3 /var/log/syslog | grep "TEST: MikroTik"

# 10. Network Bağlantı Testi
print_header "NETWORK BAĞLANTI"

echo "Sistemin dinlediği adresler:"
ss -tuln | grep ":514"

echo ""
echo "Sistem IP adresleri:"
ip addr show | grep "inet " | grep -v "127.0.0.1"

# 11. Öneriler
print_header "ÖNERİLER VE SONRAKI ADIMLAR"

echo "1. MikroTik cihazından test log gönderimi:"
echo "   /log info \"TEST LOG from MikroTik\""
echo ""
echo "2. Gerçek zamanlı log izleme:"
echo "   tail -f /var/5651/*/*/\$(date +%Y-%m-%d).log"
echo ""
echo "3. Port testi (başka makineden):"
echo "   nc -u SUNUCU_IP 514"
echo ""
echo "4. Manuel log klasörü oluşturma (gerekirse):"
echo "   sudo mkdir -p /var/5651/test-device/test-interface"
echo "   sudo chown -R syslog:adm /var/5651"
echo ""

# Özet rapor
print_header "ÖZET RAPOR"

echo "Sistem durumu kontrolü tamamlandı."
echo ""
echo "Kritik kontroller:"
systemctl is-active rsyslog > /dev/null 2>&1 && echo "✓ rsyslog servisi çalışıyor" || echo "✗ rsyslog servisi durmuş"

rsyslogd -N1 > /dev/null 2>&1 && echo "✓ Konfigürasyon geçerli" || echo "✗ Konfigürasyon hatası var"

ss -tuln | grep ":514.*UDP" > /dev/null 2>&1 && echo "✓ UDP 514 portu dinleniyor" || echo "✗ UDP 514 portu dinlenmiyor"

[ -d "/var/5651" ] && echo "✓ Log klasörü mevcut" || echo "✗ Log klasörü eksik"

echo ""
echo "Detaylı inceleme için yukarıdaki çıktıları kontrol edin." 