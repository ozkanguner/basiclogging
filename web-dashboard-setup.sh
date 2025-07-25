#!/bin/bash

echo "🌐 === MİKROTİK WEB DASHBOARD KURULUMU ===" 
echo "Bu script web dashboard'u kuracak ve otomatik güncelleme ayarlayacak"
echo

# 1. GEREKLİ PAKETLER
echo "📦 1. Gerekli paketleri kuruyor..."
sudo apt update -q
sudo apt install -y nginx

# 2. WEB DİZİNİ OLUŞTUR
WEB_DIR="/var/www/mikrotik-dashboard"
echo "📁 2. Web dizini oluşturuluyor: $WEB_DIR"
sudo mkdir -p $WEB_DIR
sudo chown www-data:www-data $WEB_DIR
sudo chmod 755 $WEB_DIR

# 3. DOSYALARI KOPYALA
echo "📋 3. Dashboard dosyalarını kopyalıyor..."
sudo cp mikrotik-dashboard.html $WEB_DIR/index.html
sudo cp mikrotik-data-api.sh $WEB_DIR/api.sh
sudo chmod +x $WEB_DIR/api.sh

# 4. NGINX KONFİGÜRASYONU
echo "⚙️ 4. Nginx konfigürasyonu oluşturuluyor..."
sudo tee /etc/nginx/sites-available/mikrotik-dashboard > /dev/null << 'EOF'
server {
    listen 8080;
    server_name _;
    root /var/www/mikrotik-dashboard;
    index index.html;

    # Ana sayfa
    location / {
        try_files $uri $uri/ =404;
    }

    # API endpoint
    location /data.json {
        add_header Content-Type application/json;
        add_header Access-Control-Allow-Origin *;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        
        # API scriptini çalıştır ve JSON döndür
        fastcgi_pass unix:/var/run/fcgiwrap.socket;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root/api.sh;
    }
    
    # Static files
    location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# 5. FCGIWRAP KURULUM (CGI script'ler için)
echo "🔧 5. FastCGI Wrapper kuruluyor..."
sudo apt install -y fcgiwrap

# 6. SİTE AKTİFLEŞTİR
echo "🌍 6. Site aktifleştiriliyor..."
sudo ln -sf /etc/nginx/sites-available/mikrotik-dashboard /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl restart fcgiwrap

# 7. JSON DATA DOSYASI OLUŞTUR
echo "📊 7. İlk veri dosyası oluşturuluyor..."
sudo bash $WEB_DIR/api.sh > $WEB_DIR/data.json
sudo chown www-data:www-data $WEB_DIR/data.json

# 8. OTOMATİK GÜNCELLEME (CRON)
echo "⏰ 8. Otomatik güncelleme ayarlanıyor..."
CRON_COMMAND="*/2 * * * * bash $WEB_DIR/api.sh > $WEB_DIR/data.json 2>/dev/null"

# Root crontab'e ekle
(sudo crontab -l 2>/dev/null; echo "$CRON_COMMAND") | sudo crontab -

# 9. GÜVENLİK İZİNLERİ
echo "🔒 9. Güvenlik izinleri ayarlanıyor..."
sudo chown -R www-data:www-data $WEB_DIR
sudo chmod -R 644 $WEB_DIR/*
sudo chmod +x $WEB_DIR/api.sh

# 10. FIREWALL (isteğe bağlı)
echo "🛡️ 10. Firewall kontrolü..."
if command -v ufw >/dev/null 2>&1; then
    sudo ufw allow 8080/tcp
    echo "Port 8080 firewall'da açıldı"
fi

# 11. TEST
echo "🧪 11. Test ediliyor..."
sleep 3

# Nginx durumu
if sudo systemctl is-active --quiet nginx; then
    echo "✅ Nginx çalışıyor"
else
    echo "❌ Nginx çalışmıyor!"
fi

# Port kontrolü
if ss -tlnp | grep -q ":8080 "; then
    echo "✅ Port 8080 dinleniyor"
else
    echo "❌ Port 8080 dinlenmiyor!"
fi

# API testi
if curl -s http://localhost:8080/data.json | grep -q "sultanahmet"; then
    echo "✅ API çalışıyor"
else
    echo "❌ API çalışmıyor!"
fi

echo
echo "🎉 === KURULUM TAMAMLANDI ==="
echo
echo "📍 Dashboard adresi:"
echo "   http://$(hostname -I | awk '{print $1}'):8080"
echo "   http://localhost:8080"
echo
echo "📊 API endpoint:"
echo "   http://$(hostname -I | awk '{print $1}'):8080/data.json"
echo
echo "⚙️ Konfigürasyon:"
echo "   Web dizini: $WEB_DIR"
echo "   Nginx config: /etc/nginx/sites-available/mikrotik-dashboard"
echo "   Otomatik güncelleme: Her 2 dakikada bir"
echo
echo "🔧 Yönetim komutları:"
echo "   sudo systemctl restart nginx       # Nginx'i yeniden başlat"
echo "   sudo systemctl status nginx        # Nginx durumu"
echo "   sudo tail -f /var/log/nginx/error.log  # Hata logları"
echo "   curl http://localhost:8080/data.json    # API test"
echo
echo "🎯 Dashboard özellikleri:"
echo "   - Gerçek zamanlı MikroTik log analizi"
echo "   - İnteraktif grafikler"
echo "   - Cihaz durumu izleme"
echo "   - Interface aktivite haritası"
echo "   - Otomatik 30 saniyede bir güncelleme"
echo
echo "Kurulum başarılı! Web tarayıcınızda dashboard'u açabilirsiniz." 