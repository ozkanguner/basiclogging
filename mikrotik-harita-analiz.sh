#!/bin/bash

echo "🗺️ === MİKROTİK CİHAZ VE LOG HARİTASI ===" 
echo "Analiz Zamanı: $(date)"
echo

# 1. AKTİF CİHAZLARI TESPİT ET
echo "📡 1. AKTİF MİKROTİK CİHAZLARI:"
echo "================================"
echo "Son 24 saatte log gönderen cihazlar:"
sudo find /var/5651 -name "$(date +%Y-%m-%d).log" -exec basename $(dirname $(dirname {})) \; | sort | uniq
echo

# 2. IP VE HOSTNAME MAPPING
echo "🌐 2. CİHAZ IP-HOSTNAME MAPPING:"
echo "================================="
echo "Sultanahmet (92.113.42.3):"
sudo grep "92.113.42.3" /var/5651/*/*/$(date +%Y-%m-%d).log | head -1 | awk '{print $3}' | sed 's/:.*$//'
echo "Maslak (92.113.42.253):"  
sudo grep "92.113.42.253" /var/5651/*/*/$(date +%Y-%m-%d).log | head -1 | awk '{print $3}' | sed 's/:.*$//'
echo

# 3. HER CİHAZDAN GELEN LOG MİKTARLARI
echo "📊 3. GÜNLÜK LOG MİKTARLARI:"
echo "============================"
echo "Sultanahmet (92.113.42.3) - Son 24 saat:"
sudo grep "92.113.42.3" /var/5651/*/*/$(date +%Y-%m-%d).log | wc -l
echo "Maslak (92.113.42.253) - Son 24 saat:"
sudo grep "92.113.42.253" /var/5651/*/*/$(date +%Y-%m-%d).log | wc -l
echo

# 4. AKTİF INTERFACE'LER
echo "🔌 4. AKTİF INTERFACE'LER:"
echo "=========================="
echo "Sultanahmet Interface'leri (otel isimleri):"
sudo grep "92.113.42.3" /var/5651/*/*/$(date +%Y-%m-%d).log | grep "in:" | sed 's/.*in:\([^[:space:]]*\).*/\1/' | sort | uniq -c | sort -nr | head -10

echo "Maslak Interface'leri (network isimleri):"
sudo grep "92.113.42.253" /var/5651/*/*/$(date +%Y-%m-%d).log | grep "in:" | sed 's/.*in:\([^[:space:]]*\).*/\1/' | sort | uniq -c | sort -nr | head -10
echo

# 5. LOG TİPLERİ ANALİZİ
echo "📋 5. LOG TİP ANALİZİ:"
echo "====================="
echo "Sultanahmet log tipleri:"
sudo grep "92.113.42.3" /var/5651/*/*/$(date +%Y-%m-%d).log | awk '{print $6}' | sort | uniq -c | sort -nr

echo "Maslak log tipleri:"
sudo grep "92.113.42.253" /var/5651/*/*/$(date +%Y-%m-%d).log | awk '{print $6}' | sort | uniq -c | sort -nr
echo

# 6. SAATLIK AKTİVİTE
echo "⏰ 6. SAATLIK LOG AKTİVİTESİ:"
echo "============================"
echo "Son 6 saatlik aktivite (Sultanahmet):"
for hour in {0..5}; do
  time_check=$(date -d "$hour hours ago" '+%H:')
  count=$(sudo grep "$time_check" /var/5651/*/*/$(date +%Y-%m-%d).log | grep "92.113.42.3" | wc -l)
  hour_display=$(date -d "$hour hours ago" '+%H:00')
  echo "$hour_display: $count logs"
done

echo "Son 6 saatlik aktivite (Maslak):"
for hour in {0..5}; do
  time_check=$(date -d "$hour hours ago" '+%H:')
  count=$(sudo grep "$time_check" /var/5651/*/*/$(date +%Y-%m-%d).log | grep "92.113.42.253" | wc -l)
  hour_display=$(date -d "$hour hours ago" '+%H:00')
  echo "$hour_display: $count logs"
done
echo

# 7. DOSYA BOYUTLARI
echo "💾 7. LOG DOSYA BOYUTLARI:"
echo "=========================="
echo "Sultanahmet log boyutu:"
sudo find /var/5651 -path "*SULTANAHMET*" -name "*.log" -exec du -sh {} \; | head -5

echo "Maslak log boyutu:"
sudo find /var/5651 -path "*MASLAK*" -name "*.log" -exec du -sh {} \; | head -5
echo

# 8. EN AKTİF INTERFACE'LER
echo "🔥 8. EN AKTİF INTERFACE'LER (TOP 5):"
echo "====================================="
echo "SULTANAHMET:"
sudo grep "92.113.42.3" /var/5651/*/*/$(date +%Y-%m-%d).log | grep "forward:" | sed 's/.*in:\([^[:space:]]*\).*/\1/' | sort | uniq -c | sort -nr | head -5

echo "MASLAK:"
sudo grep "92.113.42.253" /var/5651/*/*/$(date +%Y-%m-%d).log | grep "forward:" | sed 's/.*in:\([^[:space:]]*\).*/\1/' | sort | uniq -c | sort -nr | head -5

echo
echo "🎯 === ANALIZ TAMAMLANDI ==="
echo "Bu verilerle network trafiği ve cihaz performansını izleyebilirsiniz!" 