#!/bin/bash

# MikroTik Log Data API - JSON output for web dashboard
# Bu script gerçek log verilerini JSON formatında çıkarır

LOG_DIR="/var/5651"
TODAY=$(date +%Y-%m-%d)
CURRENT_HOUR=$(date +%H)

echo "Content-Type: application/json"
echo ""

# JSON başlat
echo "{"

# 1. SULTANAHMET VERİLERİ
echo "  \"sultanahmet\": {"

# Sultanahmet toplam log sayısı
SULTANAHMET_TOTAL=$(sudo grep "92.113.42.3" $LOG_DIR/*/*/$TODAY.log 2>/dev/null | wc -l)
echo "    \"total\": $SULTANAHMET_TOTAL,"

# Son saat log sayısı
SULTANAHMET_HOURLY=$(sudo grep "$CURRENT_HOUR:" $LOG_DIR/*/*/$TODAY.log 2>/dev/null | grep "92.113.42.3" | wc -l)
echo "    \"hourly\": $SULTANAHMET_HOURLY,"

# Aktif interface sayısı
SULTANAHMET_INTERFACES=$(sudo grep "92.113.42.3" $LOG_DIR/*/*/$TODAY.log 2>/dev/null | grep "in:" | sed 's/.*in:\([^[:space:]]*\).*/\1/' | sort | uniq | wc -l)
echo "    \"interfaces\": $SULTANAHMET_INTERFACES,"

# Status (son 5 dakikada log var mı?)
LAST_5MIN=$(date -d "5 minutes ago" +%H:%M)
SULTANAHMET_RECENT=$(sudo grep -E "$LAST_5MIN|$(date +%H:%M)" $LOG_DIR/*/*/$TODAY.log 2>/dev/null | grep "92.113.42.3" | wc -l)
if [ $SULTANAHMET_RECENT -gt 0 ]; then
    echo "    \"status\": \"online\""
else
    echo "    \"status\": \"offline\""
fi

echo "  },"

# 2. MASLAK VERİLERİ
echo "  \"maslak\": {"

MASLAK_TOTAL=$(sudo grep "92.113.42.253" $LOG_DIR/*/*/$TODAY.log 2>/dev/null | wc -l)
echo "    \"total\": $MASLAK_TOTAL,"

MASLAK_HOURLY=$(sudo grep "$CURRENT_HOUR:" $LOG_DIR/*/*/$TODAY.log 2>/dev/null | grep "92.113.42.253" | wc -l)
echo "    \"hourly\": $MASLAK_HOURLY,"

MASLAK_INTERFACES=$(sudo grep "92.113.42.253" $LOG_DIR/*/*/$TODAY.log 2>/dev/null | grep "in:" | sed 's/.*in:\([^[:space:]]*\).*/\1/' | sort | uniq | wc -l)
echo "    \"interfaces\": $MASLAK_INTERFACES,"

MASLAK_RECENT=$(sudo grep -E "$LAST_5MIN|$(date +%H:%M)" $LOG_DIR/*/*/$TODAY.log 2>/dev/null | grep "92.113.42.253" | wc -l)
if [ $MASLAK_RECENT -gt 0 ]; then
    echo "    \"status\": \"online\""
else
    echo "    \"status\": \"offline\""
fi

echo "  },"

# 3. SAATLIK VERİ (Son 6 saat)
echo "  \"hourlyData\": ["
for hour in {5..0}; do
    time_check=$(date -d "$hour hours ago" '+%H:')
    count=$(sudo grep "$time_check" $LOG_DIR/*/*/$TODAY.log 2>/dev/null | grep -E "(92\.113\.42\.3|92\.113\.42\.253)" | wc -l)
    echo -n "    $count"
    if [ $hour -ne 0 ]; then echo ","; else echo ""; fi
done
echo "  ],"

# 4. TOPLAM BOYUT
TOTAL_SIZE=$(sudo du -sh $LOG_DIR 2>/dev/null | cut -f1)
echo "  \"totalSize\": \"$TOTAL_SIZE\","

# 5. EN AKTİF INTERFACE'LER
echo "  \"interfaces\": ["

# Geçici dosya oluştur
TEMP_FILE="/tmp/interface_stats.tmp"
{
    echo "# Sultanahmet interfaces"
    sudo grep "92.113.42.3" $LOG_DIR/*/*/$TODAY.log 2>/dev/null | grep "forward:" | sed 's/.*in:\([^[:space:]]*\).*/\1/' | sort | uniq -c | sort -nr | head -5 | while read count name; do
        last_seen=$(sudo grep "$name" $LOG_DIR/*/*/$TODAY.log 2>/dev/null | grep "92.113.42.3" | tail -1 | awk '{print $2}' | cut -d: -f1-2)
        if [ ! -z "$last_seen" ]; then
            current_time=$(date +%H:%M)
            echo "$count|$name|Sultanahmet|$last_seen|active"
        fi
    done
    
    echo "# Maslak interfaces"
    sudo grep "92.113.42.253" $LOG_DIR/*/*/$TODAY.log 2>/dev/null | grep "forward:" | sed 's/.*in:\([^[:space:]]*\).*/\1/' | sort | uniq -c | sort -nr | head -5 | while read count name; do
        last_seen=$(sudo grep "$name" $LOG_DIR/*/*/$TODAY.log 2>/dev/null | grep "92.113.42.253" | tail -1 | awk '{print $2}' | cut -d: -f1-2)
        if [ ! -z "$last_seen" ]; then
            echo "$count|$name|Maslak|$last_seen|active"
        fi
    done
} > $TEMP_FILE

# JSON interface array oluştur
interface_count=0
grep -v "^#" $TEMP_FILE | head -10 | while IFS="|" read count name device last_seen status; do
    if [ ! -z "$name" ]; then
        if [ $interface_count -gt 0 ]; then echo ","; fi
        
        # Zaman farkını hesapla
        if [ ! -z "$last_seen" ]; then
            time_diff="az önce"
        else
            time_diff="bilinmiyor"
        fi
        
        echo "    {"
        echo "      \"name\": \"$name\","
        echo "      \"device\": \"$device\","
        echo "      \"count\": $count,"
        echo "      \"lastSeen\": \"$time_diff\","
        echo "      \"status\": \"$status\""
        echo -n "    }"
        
        interface_count=$((interface_count + 1))
    fi
done

# Son interface'den sonra virgül koymamak için
if [ -s $TEMP_FILE ]; then
    # Interface'ler mevcut
    grep -v "^#" $TEMP_FILE | head -10 | {
        first=true
        while IFS="|" read count name device last_seen status; do
            if [ ! -z "$name" ]; then
                if [ "$first" = false ]; then echo ","; fi
                first=false
                
                echo "    {"
                echo "      \"name\": \"$name\","
                echo "      \"device\": \"$device\","
                echo "      \"count\": $count,"
                echo "      \"lastSeen\": \"az önce\","
                echo "      \"status\": \"$status\""
                echo -n "    }"
            fi
        done
        echo ""
    }
else
    # Veri bulunamadı
    echo "    {"
    echo "      \"name\": \"Veri bulunamadı\","
    echo "      \"device\": \"-\","
    echo "      \"count\": 0,"
    echo "      \"lastSeen\": \"-\","
    echo "      \"status\": \"inactive\""
    echo "    }"
fi

echo "  ],"

# 6. HOSTNAME BİLGİLERİ
echo "  \"hostnames\": {"
SULTANAHMET_HOSTNAME=$(sudo grep "92.113.42.3" $LOG_DIR/*/*/$TODAY.log 2>/dev/null | head -1 | awk '{print $3}' | sed 's/:.*$//')
MASLAK_HOSTNAME=$(sudo grep "92.113.42.253" $LOG_DIR/*/*/$TODAY.log 2>/dev/null | head -1 | awk '{print $3}' | sed 's/:.*$//')

echo "    \"sultanahmet\": \"${SULTANAHMET_HOSTNAME:-sultanahmet-hotspot.trasst.com}\","
echo "    \"maslak\": \"${MASLAK_HOSTNAME:-trasst.maslak-hotspot}\""
echo "  },"

# 7. GÜNCELLENME ZAMANI
echo "  \"lastUpdate\": \"$(date '+%Y-%m-%d %H:%M:%S')\""

# JSON bitir
echo "}"

# Geçici dosyayı temizle
rm -f $TEMP_FILE 