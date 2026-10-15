#!/bin/bash

# ==============================
# Script de génération et installation de certificats auto-signés
# Sauvegarde les anciens certificats et configurations
# ==============================

# Variables
DOMAIN="monsite.local"
CERT_DIR="/etc/ssl/certs"
KEY_DIR="/etc/ssl/private"

CERT_FILE="${CERT_DIR}/${DOMAIN}.crt"
KEY_FILE="${KEY_DIR}/${DOMAIN}.key"

APACHE_CONF="/etc/apache2/sites-available/${DOMAIN}.conf"
NGINX_CONF="/etc/nginx/sites-available/${DOMAIN}"

BACKUP_DIR="/etc/ssl/backup_${DOMAIN}_$(date +%Y%m%d%H%M%S)"

# Vérification et sauvegarde des anciens certificats
echo "[*] Vérification des anciens certificats..."
if [[ -f "$CERT_FILE" || -f "$KEY_FILE" ]]; then
    echo "[!] Ancien(s) certificat(s) trouvé(s)."
    echo " -> Sauvegarde dans $BACKUP_DIR"

    sudo mkdir -p "$BACKUP_DIR"

    [[ -f "$CERT_FILE" ]] && sudo mv "$CERT_FILE" "$BACKUP_DIR/"
    [[ -f "$KEY_FILE" ]] && sudo mv "$KEY_FILE" "$BACKUP_DIR/"

    echo "[+] Certificats sauvegardés."
fi

# Vérification et sauvegarde des anciennes configs
echo "[*] Vérification des anciennes configurations..."
for conf in "$APACHE_CONF" "$NGINX_CONF"; do
    if [[ -f "$conf" ]]; then
        echo "[!] Ancienne configuration trouvée : $conf"
        echo " -> Sauvegarde dans $BACKUP_DIR"
        sudo mv "$conf" "$BACKUP_DIR/"
        echo "[+] Fichier sauvegardé."
    fi
done

# Génération du certificat auto-signé
echo "[*] Génération du nouveau certificat pour $DOMAIN ..."
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "$KEY_FILE" \
  -out "$CERT_FILE" \
  -subj "/C=FR/ST=IDF/L=Paris/O=Entreprise/OU=IT/CN=${DOMAIN}"

# Permissions sécurisées
sudo chmod 600 "$KEY_FILE"
sudo chmod 644 "$CERT_FILE"

echo "[+] Nouveau certificat : $CERT_FILE"
echo "[+] Nouvelle clé privée : $KEY_FILE"
echo "[+] Sauvegarde des anciens fichiers : $BACKUP_DIR"

# Instructions pour Apache
echo -e "\n=== Apache ==="
echo "
<VirtualHost *:443>
    ServerName $DOMAIN
    DocumentRoot /var/www/html
    SSLEngine on
    SSLCertificateFile $CERT_FILE
    SSLCertificateKeyFile $KEY_FILE
</VirtualHost>
"

# Instructions pour Nginx
echo -e "\n=== Nginx ==="
echo "
server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate $CERT_FILE;
    ssl_certificate_key $KEY_FILE;

    root /var/www/html;
}
"

echo -e "\n[*] Pensez à activer SSL :"
echo "Apache: sudo a2enmod ssl && sudo systemctl restart apache2"
echo "Nginx:  sudo systemctl restart nginx"