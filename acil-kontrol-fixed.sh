#!/bin/bash

echo "=== ACİL KONFİGÜRASYON KONTROLÜ ==="
echo "Tarih: $(date)"
echo

echo "1. AKTİF RSYSLOG KONFİGÜRASYON DOSYALARI:"
echo "====================================="
ls -la /etc/rsyslog.d/ | grep -E "(mikrotik|50-)"

echo
echo "2. HANGİ MİKROTİK KONFİGÜRASYONU AKTİF:"
echo "======================================="
find /etc/rsyslog.d/ -name "*mikrotik*" -exec basename {} \; | sort

echo
echo "3. MEVCUT AKTİF KONFİGÜRASYON İÇERİĞİ:"
echo "====================================="
echo "--- 50-mikrotik-dynamic.conf ---"
if [ -f /etc/rsyslog.d/50-mikrotik-dynamic.conf ]; then
    head -20 /etc/rsyslog.d/50-mikrotik-dynamic.conf
else
    echo "DOSYA BULUNAMADI!"
fi

echo
echo "4. ESKİ KONFİGÜRASYON DOSYALARI VAR MI:"
echo "====================================="
find /etc/rsyslog.d/ -name "*basic*" -o -name "*backup*" | head -5

echo
echo "5. RSYSLOG SERVİS DURUMU:"
echo "========================"
systemctl status rsyslog --no-pager -l | head -10

echo
echo "6. SON RSYSLOG RESTART ZAMANı:"
echo "=============================="
systemctl show rsyslog --property=ActiveEnterTimestamp

echo
echo "7. KONFİGÜRASYON TEST:"
echo "===================="
rsyslogd -N1

echo
echo "8. GÜNCEL ZAMAN VE SON LOG:"
echo "=========================="
echo "Şu an: $(date '+%H:%M:%S')"
echo "Son sistem log MikroTik:"
tail -1 /var/log/syslog | grep -E "(forward|92\.113\.42)" || echo "MikroTik log bulunamadı" 