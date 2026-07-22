#!/usr/bin/env bash
set -Eeuo pipefail

# Installation de Docker Engine sur Ubuntu 24.04 LTS
# Usage :
#   chmod +x install_docker_ubuntu_24_04.sh
#   ./install_docker_ubuntu_24_04.sh

log() {
    printf '\n\033[1;34m[INFO]\033[0m %s\n' "$1"
}

success() {
    printf '\n\033[1;32m[OK]\033[0m %s\n' "$1"
}

error() {
    printf '\n\033[1;31m[ERREUR]\033[0m %s\n' "$1" >&2
    exit 1
}

if [[ "${EUID}" -eq 0 ]]; then
    TARGET_USER="${SUDO_USER:-}"
    if [[ -z "${TARGET_USER}" || "${TARGET_USER}" == "root" ]]; then
        error "Exécutez ce script avec un utilisateur normal disposant de sudo, pas directement en root."
    fi
else
    TARGET_USER="${USER}"
fi

command -v sudo >/dev/null 2>&1 || error "La commande sudo n'est pas installée."

if [[ ! -f /etc/os-release ]]; then
    error "Impossible de détecter le système d'exploitation."
fi

# shellcheck disable=SC1091
source /etc/os-release

if [[ "${ID:-}" != "ubuntu" ]]; then
    error "Ce script est prévu pour Ubuntu."
fi

if [[ "${VERSION_ID:-}" != "24.04" ]]; then
    printf '\n\033[1;33m[ATTENTION]\033[0m Version détectée : %s. Le script cible Ubuntu 24.04.\n' "${VERSION_ID:-inconnue}"
fi

log "Suppression des anciens paquets Docker susceptibles de provoquer des conflits..."
OLD_PACKAGES=(
    docker.io
    docker-doc
    docker-compose
    docker-compose-v2
    podman-docker
    containerd
    runc
)

for package in "${OLD_PACKAGES[@]}"; do
    sudo apt-get remove -y "$package" >/dev/null 2>&1 || true
done

log "Mise à jour de l'index APT..."
sudo apt-get update

log "Installation des dépendances..."
sudo apt-get install -y ca-certificates curl

log "Ajout de la clé GPG officielle de Docker..."
sudo install -m 0755 -d /etc/apt/keyrings
sudo rm -f /etc/apt/keyrings/docker.asc
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

ARCHITECTURE="$(dpkg --print-architecture)"
CODENAME="${VERSION_CODENAME:-noble}"

log "Ajout du dépôt officiel Docker..."
cat <<EOF | sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${CODENAME}
Components: stable
Architectures: ${ARCHITECTURE}
Signed-By: /etc/apt/keyrings/docker.asc
EOF

log "Actualisation des paquets après ajout du dépôt Docker..."
sudo apt-get update

log "Installation de Docker Engine, Buildx et Docker Compose..."
sudo apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

log "Activation et démarrage du service Docker..."
sudo systemctl enable --now docker

log "Ajout de l'utilisateur '${TARGET_USER}' au groupe docker..."
sudo groupadd docker >/dev/null 2>&1 || true
sudo usermod -aG docker "${TARGET_USER}"

log "Vérification du service Docker..."
sudo systemctl is-active --quiet docker \
    || error "Le service Docker n'est pas actif."

log "Test avec l'image hello-world..."
sudo docker run --rm hello-world

success "Docker a été installé avec succès."

echo
docker --version
docker compose version

cat <<EOF

IMPORTANT :
L'utilisateur '${TARGET_USER}' a été ajouté au groupe docker.

Pour utiliser Docker sans sudo, déconnectez-vous puis reconnectez-vous,
ou exécutez temporairement :

    newgrp docker

Ensuite, testez :

    docker ps
    docker compose version
EOF
