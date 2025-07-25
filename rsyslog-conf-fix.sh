#!/bin/bash

echo "=== RSYSLOG.CONF SYNTAX HATASI DÜZELTİCİ ==="
echo "Tarih: $(date)"

# Backup oluştur
echo "1. Backup oluşturuluyor..."
sudo cp /etc/rsyslog.conf /etc/rsyslog.conf.backup.$(date +%Y%m%d_%H%M%S)

# Problematik satırları comment et
echo "2. Bozuk konfigürasyon düzeltiliyor..."
sudo sed -i '67,69s/^/#/' /etc/rsyslog.conf

# Kontrol et
echo "3. Düzeltme kontrol ediliyor..."
echo "=== DÜZELTİLMİŞ BÖLÜM ==="
sudo sed -n '60,75p' /etc/rsyslog.conf

# rsyslog test et
echo "4. Konfigürasyon test ediliyor..."
sudo rsyslogd -N1

if [ $? -eq 0 ]; then
    echo "✅ Syntax doğru! rsyslog restart ediliyor..."
    sudo systemctl restart rsyslog
    echo "✅ rsyslog restart edildi!"
else
    echo "❌ Hala syntax hatası var!"
fi

echo "5. Test..."
sleep 2
echo "Son sistem logunda MikroTik var mı?"
sudo tail -5 /var/log/syslog | grep -E "(forward|92\.113\.42)" || echo "✅ MikroTik log bulunamadı - BAŞARILI!" 