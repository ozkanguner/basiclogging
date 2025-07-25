#!/bin/bash

echo "📥 === MİKROTİK LOG İNDİRME SCRİPTİ ==="
echo "Bu script log dosyalarını ZIP ile paketleyip indirmeye hazır hale getirir"
echo

# Bugünün tarihi
TODAY=$(date +%Y-%m-%d)
YESTERDAY=$(date -d "1 day ago" +%Y-%m-%d)

# ZIP dosya adı
ZIP_NAME="mikrotik-logs-$(date +%Y%m%d_%H%M).zip"

echo "📊 Log istatistikleri hazırlanıyor..."

# Log sayıları
SULTANAHMET_TODAY=$(sudo grep "92.113.42.3" /var/5651/*/*/$TODAY.log 2>/dev/null | wc -l)
MASLAK_TODAY=$(sudo grep "92.113.42.253" /var/5651/*/*/$TODAY.log 2>/dev/null | wc -l)

echo "Bugün ($TODAY):"
echo "  - Sultanahmet: $SULTANAHMET_TODAY logs"
echo "  - Maslak: $MASLAK_TODAY logs"

# 5651 klasör boyutu
TOTAL_SIZE=$(sudo du -sh /var/5651 2>/dev/null | cut -f1)
echo "  - Toplam boyut: $TOTAL_SIZE"

echo
echo "📦 Log dosyaları paketleniyor..."

# Geçici dizin oluştur
TEMP_DIR="/tmp/mikrotik-export-$(date +%Y%m%d_%H%M%S)"
mkdir -p $TEMP_DIR/logs
mkdir -p $TEMP_DIR/config

# Son 2 günün loglarını kopyala
echo "📋 Son 2 günün logları kopyalanıyor..."
sudo find /var/5651 -name "$TODAY.log" -exec cp {} $TEMP_DIR/logs/ \; 2>/dev/null
sudo find /var/5651 -name "$YESTERDAY.log" -exec cp {} $TEMP_DIR/logs/ \; 2>/dev/null

# Örnek veriler için klasör yapısını koru
echo "📁 Klasör yapısı korunuyor..."
sudo cp -r /var/5651/*/genel/$TODAY.log $TEMP_DIR/logs/ 2>/dev/null || true

# Konfigürasyon dosyalarını kopyala
echo "⚙️ Konfigürasyon dosyaları ekleniyor..."
sudo cp /etc/rsyslog.d/50-mikrotik-dynamic.conf $TEMP_DIR/config/ 2>/dev/null || true
sudo cp /etc/logrotate.d/mikrotik-logs $TEMP_DIR/config/ 2>/dev/null || true

# Sistem bilgilerini ekle
echo "💾 Sistem bilgileri ekleniyor..."
{
    echo "=== MİKROTİK LOG EXPORT BİLGİLERİ ==="
    echo "Export Tarihi: $(date)"
    echo "Sunucu: $(hostname)"
    echo "IP: $(hostname -I | awk '{print $1}')"
    echo
    echo "=== LOG İSTATİSTİKLERİ ==="
    echo "Sultanahmet (92.113.42.3) - Bugün: $SULTANAHMET_TODAY"
    echo "Maslak (92.113.42.253) - Bugün: $MASLAK_TODAY"
    echo "Toplam 5651 boyutu: $TOTAL_SIZE"
    echo
    echo "=== DOSYA LİSTESİ ==="
    find $TEMP_DIR -type f -name "*.log" | wc -l | xargs echo "Log dosya sayısı:"
    find $TEMP_DIR -type f -name "*.log" -exec ls -lh {} \;
    echo
    echo "=== ÖRNEK LOG SATIRLARI ==="
    echo "--- Sultanahmet örnekleri ---"
    sudo grep "92.113.42.3" /var/5651/*/*/$TODAY.log 2>/dev/null | head -5
    echo
    echo "--- Maslak örnekleri ---"
    sudo grep "92.113.42.253" /var/5651/*/*/$TODAY.log 2>/dev/null | head -5
} > $TEMP_DIR/export-info.txt

# İzinleri düzelt
sudo chown -R $USER:$USER $TEMP_DIR
chmod -R 644 $TEMP_DIR/*

# ZIP oluştur
echo "🗜️ ZIP dosyası oluşturuluyor..."
cd /tmp
zip -r $ZIP_NAME $(basename $TEMP_DIR) >/dev/null 2>&1

if [ -f "/tmp/$ZIP_NAME" ]; then
    echo "✅ ZIP dosyası hazır: /tmp/$ZIP_NAME"
    echo "📊 ZIP bilgileri:"
    ls -lh /tmp/$ZIP_NAME
    echo
    echo "📱 İndirme komutları:"
    echo "SCP ile:"
    echo "  scp root@$(hostname -I | awk '{print $1}'):/tmp/$ZIP_NAME ."
    echo
    echo "Veya HTTP ile (geçici sunucu):"
    echo "  cd /tmp && python3 -m http.server 8888"
    echo "  Tarayıcıda: http://$(hostname -I | awk '{print $1}'):8888/$ZIP_NAME"
    echo
    echo "📂 ZIP içeriği:"
    unzip -l /tmp/$ZIP_NAME | head -20
else
    echo "❌ ZIP oluşturma hatası!"
fi

# Temizlik
rm -rf $TEMP_DIR 