#!/usr/bin/env bash
set -e

# Detectar interfaz de red por defecto
IFACE=$(ip -o route show default | awk '{print $5}' | head -n1)
echo "Usando interfaz: $IFACE"

# Instalar dependencias
sudo apt update
sudo apt install -y software-properties-common curl

# Repositorio oficial de Suricata
sudo add-apt-repository -y ppa:oisf/suricata-stable
sudo apt update
sudo apt install -y suricata

# Reemplazar solo la interfaz dentro de af-packet
sudo awk -v iface="$IFACE" '
  BEGIN { in_af_packet=0 }
  {
    if ($0 ~ /^af-packet:/) in_af_packet=1
    if (in_af_packet && $0 ~ /- interface:/) {
      sub(/- interface: .*/, "- interface: " iface)
      in_af_packet=0
    }
    print
  }
' /etc/suricata/suricata.yaml | sudo tee /etc/suricata/suricata.yaml.new > /dev/null && \
sudo mv /etc/suricata/suricata.yaml.new /etc/suricata/suricata.yaml

# Activar community-id sin alterar el seed
sudo sed -i 's/^\( *community-id:\) *false/\1 true/' /etc/suricata/suricata.yaml

# Activar recarga de reglas en caliente
if ! grep -q "rule-reload:" /etc/suricata/suricata.yaml; then
  echo -e "\n# Habilitar recarga de reglas en caliente\ndetect-engine:\n  - rule-reload: true" | sudo tee -a /etc/suricata/suricata.yaml > /dev/null
fi
# Listar fuentes disponibles (opcional)
echo "Fuentes disponibles:"
sudo suricata-update list-sources || true

# Habilitar fuente de reglas hunting
sudo suricata-update enable-source tgreen/hunting

# Descargar reglas
sudo suricata-update

# Activar y reiniciar servicio
sudo systemctl enable suricata
sudo systemctl restart suricata

# Mostrar estado final
#sudo systemctl status suricata --no-pager
sudo suricata -T -c /etc/suricata/suricata.yaml -v