#!/usr/bin/env bash

set -euo pipefail

# -------------------- Detectar interfaz WiFi --------------------
INTERFACE=$(ip -br link | awk '/^wl/ {print $1}' | head -1)
[[ -z "$INTERFACE" ]] && INTERFACE="wlan0"

# -------------------- Obtener SSID y señal --------------------
SSID=$(iw dev "$INTERFACE" info 2>/dev/null | awk -F 'ssid ' '/ssid/ {print $2}')
if [[ -z "$SSID" ]]; then
    printf '{"text":"󰤮 No WiFi","tooltip":"Desconectado","class":"disconnected","percentage":0}\n'
    exit 0
fi

SIGNAL=$(iw dev "$INTERFACE" link 2>/dev/null | awk -F 'signal: ' '/signal/ {print $2}' | cut -d' ' -f1)
if [[ -z "$SIGNAL" ]]; then
    PERCENT=0
else
    PERCENT=$(( (SIGNAL + 90) * 100 / 60 ))
    (( PERCENT > 100 )) && PERCENT=100
    (( PERCENT < 0 ))   && PERCENT=0
fi

# -------------------- Icono y clase de señal --------------------
# Clase CSS según intensidad (útil para colorear el icono o fondo)
if (( PERCENT >= 80 )); then
    ICON="󰤨"
    SIGNAL_CLASS="signal-4"
elif (( PERCENT >= 60 )); then
    ICON="󰤥"
    SIGNAL_CLASS="signal-3"
elif (( PERCENT >= 40 )); then
    ICON="󰤢"
    SIGNAL_CLASS="signal-2"
elif (( PERCENT >= 20 )); then
    ICON="󰤟"
    SIGNAL_CLASS="signal-1"
else
    ICON="󰤯"
    SIGNAL_CLASS="signal-0"
fi

# -------------------- Cálculo de velocidades --------------------
CACHE_DIR="/tmp/waybar_wifi_$USER"
mkdir -p "$CACHE_DIR"

RX_PREV_FILE="$CACHE_DIR/rx_prev"
TX_PREV_FILE="$CACHE_DIR/tx_prev"
TIME_PREV_FILE="$CACHE_DIR/time_prev"

read -r RX_CURR TX_CURR < <(
    awk -v iface="$INTERFACE:" '$1 == iface {print $2, $10}' /proc/net/dev
)
RX_CURR=${RX_CURR:-0}
TX_CURR=${TX_CURR:-0}
TIME_CURR=$(date +%s)

RX_SPEED="…"
TX_SPEED="…"

if [[ -f "$RX_PREV_FILE" && -f "$TX_PREV_FILE" && -f "$TIME_PREV_FILE" ]]; then
    RX_PREV=$(<"$RX_PREV_FILE")
    TX_PREV=$(<"$TX_PREV_FILE")
    TIME_PREV=$(<"$TIME_PREV_FILE")

    if [[ "$RX_PREV" =~ ^[0-9]+$ && "$TX_PREV" =~ ^[0-9]+$ && "$TIME_PREV" =~ ^[0-9]+$ ]]; then
        DELTA_TIME=$((TIME_CURR - TIME_PREV))
        if (( DELTA_TIME > 0 )); then
            DELTA_RX=$((RX_CURR - RX_PREV))
            DELTA_TX=$((TX_CURR - TX_PREV))
            (( DELTA_RX < 0 )) && DELTA_RX=0
            (( DELTA_TX < 0 )) && DELTA_TX=0

            RX_KBPS=$(( DELTA_RX / DELTA_TIME / 1024 ))
            TX_KBPS=$(( DELTA_TX / DELTA_TIME / 1024 ))

            format_speed() {
                local kbps=$1
                if (( kbps >= 1024 )); then
                    printf "%d MB/s" $(( kbps / 1024 ))
                else
                    printf "%d KB/s" "$kbps"
                fi
            }
            RX_SPEED=$(format_speed "$RX_KBPS")
            TX_SPEED=$(format_speed "$TX_KBPS")
        fi
    fi
fi

printf "%s\n" "$RX_CURR" > "$RX_PREV_FILE"
printf "%s\n" "$TX_CURR" > "$TX_PREV_FILE"
printf "%s\n" "$TIME_CURR" > "$TIME_PREV_FILE"

# -------------------- Construir JSON final --------------------
TEXT="$ICON $PERCENT% 󰕒 $TX_SPEED 󰇚 $RX_SPEED"
TOOLTIP="Conectado a: $SSID | Velocidad: ⬇️ $RX_SPEED ⬆️ $TX_SPEED"
# Clase combinada: la general "connected" más la específica de intensidad
CLASS="connected $SIGNAL_CLASS"

escape_json() {
    local s=$1
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    printf "%s" "$s"
}

TEXT_ESC=$(escape_json "$TEXT")
TOOLTIP_ESC=$(escape_json "$TOOLTIP")

printf '{"text":"%s","tooltip":"%s","class":"%s","percentage":%d}\n' \
    "$TEXT_ESC" "$TOOLTIP_ESC" "$CLASS" "$PERCENT"
