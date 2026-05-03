#!/bin/bash

# Obtener brillo actual en porcentaje
BRIGHTNESS=$(brightnessctl g)
MAX=$(brightnessctl m)
PERCENT=$((BRIGHTNESS * 100 / MAX))

# Elegir icono según nivel de brillo
if [ $PERCENT -lt 20 ]; then
    ICON="🌙"
elif [ $PERCENT -lt 50 ]; then
    ICON="🔅"
elif [ $PERCENT -lt 80 ]; then
    ICON="🔆"
else
    ICON="☀️"
fi

# Salida simple para Waybar (sin JSON, solo texto)
echo "$ICON $PERCENT%"
