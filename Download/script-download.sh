#!/bin/bash

# Daftar layanan untuk diuji
SERVICES=(
    "archive.ubuntu.com"
    "storage.googleapis.com"
    "huggingface.co"
    "www.kaggle.com"
    "drive.google.com"
    "lintasarta-my.sharepoint.com"
)

# Token Hugging Face
HF_TOKEN=${HF_TOKEN:-"hf_xxxxxxxx"}

# Konfigurasi InfluxDB
INFLUXDB_URL="http://10.0.2.2:8086"
INFLUXDB_TOKEN="su_zy06hByo7NKikjBVIwpdwm6-tg0Pc9sPyYGj4SZghUx-10zJ4jGDiJ-W2C5m7tbmm1NwirTo63EEylxkCUA=="
INFLUXDB_ORG="my-org"
INFLUXDB_BUCKET="download"

# Fungsi untuk mencatat hasil ke InfluxDB
log_to_influxdb_dw() {
    SERVICE=$1
    URL=$2
    SPEED=$3
    SIZE=$4
    ELAPSE=$5

    # Encode URL agar aman untuk dimasukkan sebagai field, bukan tag
    SAFE_URL=$(echo "$URL" | sed 's/[ ,]/_/g')

    curl -s --request POST "$INFLUXDB_URL/api/v2/write?org=$INFLUXDB_ORG&bucket=$INFLUXDB_BUCKET&precision=s" \
        --header "Authorization: Token $INFLUXDB_TOKEN" \
        --data-binary "
download_speed,service=$SERVICE speed=$SPEED,size=$SIZE,elapse=$ELAPSE,url=\"$SAFE_URL\" $(( $(date +%s) ))"
}

# Fungsi untuk tes kecepatan download dan ukuran file
test_download_speed() {
    URL=$1
    HEADER=$2 # Header opsional untuk autentikasi
    echo "Testing download speed from $URL..."

    # Mulai timer
    START_TIME=$(date +%s)

    # Menyimpan output `curl` untuk kecepatan dan ukuran file
    CURL_OUTPUT=$(curl -L -H "$HEADER" -o /dev/null -s -w '%{speed_download} %{size_download}\n' "$URL")

    # Akhiri timer
    END_TIME=$(date +%s)
    ELAPSED_TIME=$((END_TIME - START_TIME))

    # Memisahkan output untuk kecepatan dan ukuran
    DOWNLOAD_SPEED=$(echo "$CURL_OUTPUT" | awk '{print $1}')
    SIZE_DOWNLOAD=$(echo "$CURL_OUTPUT" | awk '{print $2}')

    if [[ -z "$DOWNLOAD_SPEED" || -z "$SIZE_DOWNLOAD" ]]; then
        echo "Download test from $URL: Failed"
        log_to_influxdb_dw "$SERVICE" "$URL" "0" "0" "0"
    else
        # Mengonversi kecepatan download ke MB/s
        SPEED_IN_MB=$(echo "$DOWNLOAD_SPEED / 1048576" | bc -l | awk '{printf "%.2f", $1}')

        # Mengonversi ukuran file ke MB
        SIZE_IN_MB=$(echo "$SIZE_DOWNLOAD / 1048576" | bc -l | awk '{printf "%.2f", $1}')

        # Output kecepatan download dan ukuran file
        echo "Download speed from $URL: $SPEED_IN_MB MB/s"
        echo "File size downloaded from $URL: $SIZE_IN_MB MB"
        echo "Time taken to download from $URL: $ELAPSED_TIME seconds"

        # Log ke InfluxDB
        log_to_influxdb_dw "$SERVICE" "$URL" "$SPEED_IN_MB" "$SIZE_IN_MB" "$ELAPSED_TIME"
    fi
}

# Mulai pengujian
for SERVICE in "${SERVICES[@]}"; do
    # Tes download speed hanya untuk domain yang mendukung file download
    if [[ "$SERVICE" == "archive.ubuntu.com" ]]; then
        test_download_speed "https://$SERVICE/ubuntu/pool/main/m/mysql-8.4/mysql-8.4_8.4.4.orig.tar.gz"
    elif [[ "$SERVICE" == "storage.googleapis.com" ]]; then
        test_download_speed "https://$SERVICE/gcp-public-data-landsat/index.csv.gz"
    elif [[ "$SERVICE" == "huggingface.co" ]]; then
        test_download_speed "https://huggingface.co/google/gemma-7b/resolve/main/model-00001-of-00004.safetensors?download=true" \
            "Authorization: Bearer $HF_TOKEN"
    elif [[ "$SERVICE" == "www.kaggle.com" ]]; then
        test_download_speed "https://$SERVICE/api/v1/datasets/download/gpiosenka/cards-image-datasetclassification"
    elif [[ "$SERVICE" == "drive.google.com" ]]; then
        test_download_speed "https://drive.usercontent.google.com/download?id=1cWn2jxHucURx4Kt9jIbJ8z8o0c1629Zv&export=download&confirm=t"
    elif [[ "$SERVICE" == "lintasarta-my.sharepoint.com" ]]; then
        test_download_speed "https://lintasarta-my.sharepoint.com/personal/afnan_ngathour_lintasarta_co_id/_layouts/15/download.aspx?share=EUfoI_MChNZOrVNe0EM2TYoB81qQ0yWdSLPwzJV1mXQtxw"
    fi
done

echo "All tests completed. Results saved in InfluxDB."
