#!/bin/bash

# Daftar layanan untuk diuji (menggunakan | sebagai pemisah)
SERVICES=(
    "nvcr.io|nvcr.io/nvidia/cntk:18.08-py3|6170"
    "gcr.io|gcr.io/google-containers/cos-nvidia-driver-install:v0.4|2930"
    "ghcr.io|ghcr.io/jumppad-labs/dind:v1.1.3|425"
    "docker.io|docker.io/library/node:latest|1120"
    "quay.io|quay.io/fedora/mariadb-105|422"
)

# Konfigurasi InfluxDB
INFLUXDB_URL="http://10.0.2.2:8086"
INFLUXDB_TOKEN="RDMNyecs7tl5G-mEGazz2YQhJbxVdtj_itzR3OnerFjqL4p5c9hiO6Ou_E-YDdexbOdBN6R8lKHMYE2OHgOzfw=="
INFLUXDB_ORG="my-org"
INFLUXDB_BUCKET="performance_metrics"

log_to_influxdb_docker() {
    SERVICE=$1
    IMAGE=$2
    SIZE=$3
    DURATION=$4
    SPEED=$5
    TIMESTAMP=$(date +"%s") # Timestamp dalam detik

    # Pastikan semua nilai numerik valid
    if ! [[ "$SIZE" =~ ^[0-9]+$ ]] || ! [[ "$DURATION" =~ ^[0-9]+$ ]] || ! [[ "$SPEED" =~ ^[0-9]+$ ]]; then
        echo "Error: Invalid number detected in size, duration, or speed"
        return
    fi

    # Kirim data ke InfluxDB dengan IMAGE dalam tanda kutip
    curl -s --request POST "$INFLUXDB_URL/api/v2/write?org=$INFLUXDB_ORG&bucket=$INFLUXDB_BUCKET&precision=s" \
        --header "Authorization: Token $INFLUXDB_TOKEN" \
        --data-binary "
docker_pull,service=$SERVICE size=$SIZE,duration=$DURATION,speed=$SPEED,image=\"$IMAGE\" $TIMESTAMP"
}

# Fungsi untuk tes kecepatan pull container image
test_pull_image_speed() {
    SERVICE=$1
    IMAGE=$2
    SIZE=$3
    echo "Testing image pull speed for $IMAGE from $SERVICE..."
    START=$(date +%s)
    docker pull $IMAGE >/dev/null 2>&1
    END=$(date +%s)
    DURATION=$((END - START))
    if [[ $DURATION -eq 0 ]]; then
        SPEED=0
        echo "Pull speed for $IMAGE: Failed"
    else
        SPEED=$((SIZE / DURATION))
        echo "Pull speed for $IMAGE: $DURATION seconds, $SPEED MB/s"
    fi
    log_to_influxdb_docker "$SERVICE" "$IMAGE" "$SIZE" "$DURATION" "$SPEED"
}

# Clear existing Docker images
clear_docker_images

# Loop melalui semua layanan
for ENTRY in "${SERVICES[@]}"; do
    SERVICE=$(echo "$ENTRY" | cut -d '|' -f 1)
    IMAGE=$(echo "$ENTRY" | cut -d '|' -f 2)
    SIZE=$(echo "$ENTRY" | cut -d '|' -f 3)
    test_pull_image_speed "$SERVICE" "$IMAGE" "$SIZE"
done
