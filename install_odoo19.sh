#!/bin/bash

set -e

ODOO_USER="odoo19"
ODOO_HOME="/opt/odoo19"
ODOO_SRC="$ODOO_HOME/src"
ODOO_VENV="$ODOO_HOME/odoo19-venv"
ODOO_CONF="/etc/odoo19.conf"
ODOO_LOG_DIR="/var/log/odoo"
ODOO_LOG="$ODOO_LOG_DIR/odoo19.log"
ODOO_DB_PASSWORD="123456"

echo "=== Update system ==="
sudo apt update && sudo apt upgrade -y

echo "=== Install Odoo dependencies ==="
sudo apt install -y \
python3-dev libxml2-dev libxslt1-dev zlib1g-dev libsasl2-dev libldap2-dev \
build-essential libssl-dev libffi-dev libmysqlclient-dev libjpeg-dev libpq-dev \
libjpeg8-dev liblcms2-dev libblas-dev libatlas-base-dev \
git wget curl python3-pip python3-wheel

echo "=== Install Python 3.12 ==="
sudo apt install -y software-properties-common
sudo add-apt-repository ppa:deadsnakes/ppa -y
sudo apt update
sudo apt install -y python3.12 python3.12-venv python3.12-dev

echo "=== Install Web dependencies ==="
sudo apt install -y npm node-less
sudo npm install -g less less-plugin-clean-css rtlcss

echo "=== Install PostgreSQL ==="
sudo apt install -y postgresql postgresql-client

echo "=== Create PostgreSQL user ==="
sudo -u postgres createuser --createdb --no-createrole --no-superuser "$ODOO_USER" || true
sudo -u postgres psql -c "ALTER USER $ODOO_USER WITH SUPERUSER PASSWORD '$ODOO_DB_PASSWORD';"

echo "=== Install wkhtmltopdf 0.12.6 ==="
cd /tmp

wget -q http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_amd64.deb || true
sudo dpkg -i libssl1.1_1.1.1f-1ubuntu2_amd64.deb || sudo apt --fix-broken install -y

wget -q https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox_0.12.6-1.focal_amd64.deb
sudo apt install -y xfonts-75dpi xfonts-base
sudo dpkg -i wkhtmltox_0.12.6-1.focal_amd64.deb || sudo apt --fix-broken install -y

echo "=== Create Odoo system user ==="
sudo useradd -m -U -r -d "$ODOO_HOME" -s /bin/bash "$ODOO_USER" || true

echo "=== Clone Odoo source ==="
sudo mkdir -p "$ODOO_HOME"
sudo chown -R "$ODOO_USER:$ODOO_USER" "$ODOO_HOME"

sudo -u "$ODOO_USER" git clone -b 19.0 https://github.com/odoo/odoo.git "$ODOO_SRC"

echo "=== Create Python virtual environment ==="
sudo -u "$ODOO_USER" python3.12 -m venv "$ODOO_VENV"

echo "=== Install Python requirements ==="
sudo -u "$ODOO_USER" "$ODOO_VENV/bin/pip" install --upgrade pip wheel setuptools
sudo -u "$ODOO_USER" "$ODOO_VENV/bin/pip" install -r "$ODOO_SRC/requirements.txt"

echo "=== Create Odoo config file ==="
sudo tee "$ODOO_CONF" > /dev/null <<EOF
[options]
admin_passwd = admin
db_host = localhost
db_port = 5432
db_user = $ODOO_USER
db_password = $ODOO_DB_PASSWORD
addons_path = $ODOO_SRC/addons
logfile = $ODOO_LOG
EOF

sudo chown "$ODOO_USER:$ODOO_USER" "$ODOO_CONF"
sudo chmod 640 "$ODOO_CONF"

echo "=== Create log directory ==="
sudo mkdir -p "$ODOO_LOG_DIR"
sudo touch "$ODOO_LOG"
sudo chown -R "$ODOO_USER:root" "$ODOO_LOG_DIR"

echo "=== Create systemd service ==="
sudo tee /etc/systemd/system/odoo19.service > /dev/null <<EOF
[Unit]
Description=Odoo 19
After=network.target postgresql.service

[Service]
Type=simple
SyslogIdentifier=odoo19
PermissionsStartOnly=true
User=$ODOO_USER
Group=$ODOO_USER
ExecStart=$ODOO_VENV/bin/python3 $ODOO_SRC/odoo-bin -c $ODOO_CONF
StandardOutput=journal+console
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "=== Start Odoo service ==="
sudo systemctl daemon-reload
sudo systemctl enable --now odoo19

echo "=== Installation terminée ==="
echo "URL: http://localhost:8069"
echo "Log: sudo journalctl -u odoo19 -f"
