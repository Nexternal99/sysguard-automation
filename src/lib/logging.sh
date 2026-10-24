#!/usr/bin/env bash
# logging.sh - modul logging terpusat untuk sysguard-backup
# Dipakai dengan: source "$(dirname "$0")/lib/logging.sh"

# Lokasi file log default; bisa ditimpa dengan export LOG_FILE=... sebelum sourcing.
LOG_FILE="${LOG_FILE:-$HOME/sysguard-automation/evidence/backup.log}"

log::_write() {
    local level="$1"; shift
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
    printf '[%s] [%s] %s\n' "$ts" "$level" "$*" | tee -a "$LOG_FILE" >&2
}

log::info()  { log::_write "INFO"  "$*"; }
log::warn()  { log::_write "WARN"  "$*"; }
log::error() { log::_write "ERROR" "$*"; }

# log::init
# Memastikan direktori log sudah ada SEBELUM ada redirect (2>>, >>) lain
# yang menunjuk ke LOG_FILE, supaya shell tidak gagal membuka file tujuan.
log::init() {
    mkdir -p "$(dirname "$LOG_FILE")"
}
