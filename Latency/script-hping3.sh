#!/bin/bash

# Daftar layanan untuk diuji
SERVICES=(
    "nvcr.io"
    "gcr.io"
    "archive.ubuntu.com"
    "ghcr.io"
    "storage.googleapis.com" # Google Bucket
    "docker.io"
    "quay.io"
    "huggingface.co"
    "www.kaggle.com"
    "drive.google.com"
    "lintasarta-my.sharepoint.com"
)

# InfluxDB configuration
INFLUXDB_URL="http://10.0.2.2:8086"
INFLUXDB_BUCKET="latency"
INFLUXDB_ORG="my-org"
INFLUXDB_TOKEN="su_zy06hByo7NKikjBVIwpdwm6-tg0Pc9sPyYGj4SZghUx-10zJ4jGDiJ-W2C5m7tbmm1NwirTo63EEylxkCUA=="

# Fungsi untuk menyimpan data ke InfluxDB
log_to_influxdb() {
    SERVICE=$1
    LATENCY=$2
    TIMESTAMP=$(date +"%s%N") # Timestamp in nanoseconds

    if [[ "$LATENCY" == "0" ]]; then
        STATUS="false"
    else
        STATUS="true"
    fi

    curl -s -X POST "$INFLUXDB_URL/api/v2/write?org=$INFLUXDB_ORG&bucket=$INFLUXDB_BUCKET&precision=ns" \
        --header "Authorization: Token $INFLUXDB_TOKEN" \
        --data-binary "latency,service=$SERVICE,status=$STATUS latency=$LATENCY $TIMESTAMP"
}

# Fungsi untuk tes latency menggunakan hping3
test_latency_with_hping3() {
    SERVICE=$1
    echo "Testing TCP latency to $SERVICE with hping3..."
    HPING_RESULT=$(sudo hping3 -S -p 443 -c 3 $SERVICE 2>/dev/null | grep "rtt=" | awk -F'rtt=' '{print $2}' | awk '{print $1}')
    
    if [[ -z "$HPING_RESULT" ]]; then
        echo "Latency to $SERVICE: Blocked (hping3)"
        log_to_influxdb "$SERVICE" "0"
    else
        AVG_RTT=$(echo "$HPING_RESULT" | awk '{sum+=$1; count++} END {if(count > 0) print sum/count}')
        echo "Latency to $SERVICE: ${AVG_RTT} ms"
        log_to_influxdb "$SERVICE" "$AVG_RTT"
    fi
}

# Mulai pengujian
for SERVICE in "${SERVICES[@]}"; do
    test_latency_with_hping3 $SERVICE
done
