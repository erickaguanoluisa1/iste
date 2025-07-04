#!/bin/bash
# Instalador automatizado de Snort con detección dinámica de interfaz
set -e

# Obtener interfaz de red por default route
INTERFACE=$(ip route | grep default | awk '{print $5}')
SNORT_CONF="/etc/snort/snort.conf"
DEBIAN_CONF="/etc/snort/snort.debian.conf"
RULES_FILE="/etc/snort/rules/local.rules"

echo "[1/6] Usando interfaz detectada automáticamente: $INTERFACE"
if [[ -z "$INTERFACE" ]]; then
  echo "❌ No se pudo detectar una interfaz activa. ¿Tienes conexión de red?"
  exit 1
fi

echo "[2/6] Activando modo promiscuo en $INTERFACE..."
sudo ip link set $INTERFACE promisc on
if ip link show "$INTERFACE" | grep -q PROMISC; then
  echo "✅ Modo promiscuo activado en $INTERFACE."
else
  echo "❌ Falló la activación de modo promiscuo en $INTERFACE."
  exit 1
fi

echo "[3/6] Instalando Snort..."
sudo apt update && sudo apt install -y snort

echo "[4/6] Configurando Snort para usar $INTERFACE..."
sudo sed -i "s|^DEBIAN_SNORT_INTERFACE=.*|DEBIAN_SNORT_INTERFACE=\"$INTERFACE\"|" $DEBIAN_CONF
grep DEBIAN_SNORT_INTERFACE $DEBIAN_CONF

echo "[5/6] Ajustando salida de alertas y reglas..."
sudo sed -i 's|^# output alert_fast:.*|output alert_fast: snort.alert.fast|' $SNORT_CONF
echo 'alert icmp any any -> any any (msg:"ICMP test detected"; sid:1000010; rev:1;)' | sudo tee $RULES_FILE

echo "[6/6] Reiniciando Snort y validando configuración..."
sudo systemctl restart snort
sudo snort -T -i $INTERFACE -c $SNORT_CONF

echo "[+] Iniciando Snort en modo live para generar logs..."
sudo snort -i $INTERFACE -A fast -c /etc/snort/snort.conf -l /var/log/snort &


echo "✅ Snort está listo y escuchando en $INTERFACE."
echo "→ Prueba con 'ping <host>' y revisa /var/log/snort/snort.alert.fast"
