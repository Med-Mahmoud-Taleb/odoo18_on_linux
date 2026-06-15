#!/bin/bash

# --- CONFIGURATION ---
PARTITION="/dev/disk/by-label/BKP_USB"
MOUNT_POINT="/media/usb"
SOURCE_DIR="/home/abc/backups" 
RETENTION_DAYS=30 
LOG_FILE="/var/log/backup_usb.log"

# --- FONCTION DE LOG ---
log_message() {
    # Aligne la date et le message dans le fichier de log
    echo "$(date "+%Y-%m-%d %H:%M:%S") : $1" >> "$LOG_FILE"
}

# --- DÉBUT DU SCRIPT ---
log_message "[INFO] Début du service de sauvegarde automatique."

DATE_AUJOURDHUI=$(date +%Y-%m-%d)

# 1. Vérification que la clé USB est bien branchée physiquement
if [ ! -b "$PARTITION" ]; then
    log_message "[CRITICAL] La clé USB 'BKP_USB' n'est pas branchée ou introuvable. Sauvegarde avortée."
    exit 1
fi

# 2. Création du point de montage et tentative de montage
mkdir -p $MOUNT_POINT
mount $PARTITION $MOUNT_POINT 2>> "$LOG_FILE"

# 3. Vérification sécurisée du montage
if mountpoint -q "$MOUNT_POINT"; then
    log_message "[SUCCESS] Clé USB montée avec succès."
    
    # --- NETTOYAGE ---
    log_message "[INFO] Nettoyage des fichiers de plus de $RETENTION_DAYS jours sur la clé..."
    # On liste les fichiers supprimés directement dans le log
    find "$MOUNT_POINT" -maxdepth 1 -name "*.zip" -type f -mtime +$RETENTION_DAYS -print -delete >> "$LOG_FILE"
    
    # --- COPIE ---
    log_message "[INFO] Recherche du fichier du jour (*$DATE_AUJOURDHUI*.zip)..."
    FOUND_FILES=$(ls $SOURCE_DIR/*$DATE_AUJOURDHUI*.zip 2>/dev/null)

    if [ -z "$FOUND_FILES" ]; then
        log_message "[WARNING] Aucun fichier de backup trouvé aujourd'hui dans $SOURCE_DIR."
    else
        log_message "[INFO] Fichier(s) trouvé(s). Début de la copie..."
        # Copie et envoie les erreurs potentielles dans le log
        cp $SOURCE_DIR/*$DATE_AUJOURDHUI*.zip "$MOUNT_POINT/" 2>> "$LOG_FILE"
        if [ $? -eq 0 ]; then
            log_message "[SUCCESS] Copie du fichier du jour réussie."
        else
            log_message "[ERROR] Échec lors de la copie du fichier."
        fi
    fi
    
    # 4. Démontage de la clé
    sync
    umount $MOUNT_POINT 2>> "$LOG_FILE"
    log_message "[INFO] Clé USB démontée proprement."
else
    log_message "[CRITICAL] Impossible de monter la clé USB ($PARTITION). Sauvegarde avortée."
    exit 1
fi # <--- AJOUTÉ : Ferme proprement le bloc "if mountpoint"
