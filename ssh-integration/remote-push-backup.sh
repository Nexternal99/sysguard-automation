#!/usr/bin/env bash
#
# remote-push-backup.sh - Kirim hasil backup terbaru ke mesin remote lewat
# SCP memakai autentikasi SSH berbasis kunci (P12 - SysGuard-Lab).
#
# Pemakaian:
#   ./remote-push-backup.sh <backup_dir> <remote_user> <remote_host> <remote_path> [ssh_key_path] [ssh_port]
#
# Catatan keamanan:
#   - Script ini TIDAK PERNAH meminta/menyimpan password. Autentikasi wajib
#     lewat SSH key (-i ssh_key_path, atau default ~/.ssh/id_ed25519).
#   - Tidak ada private key, token, atau isi ~/.ssh yang ditulis ke log.
#   - Jika koneksi mencoba fallback ke password, script akan gagal dengan
#     pesan jelas, bukan diam-diam meminta input password.
#
# Exit status:
#   0  Berhasil terkirim
#   1  Argumen tidak valid
#   2  backup_dir tidak ditemukan / kosong
#   3  SSH key tidak ditemukan
#   4  Koneksi/transfer SCP gagal

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# shellcheck source=../src/lib/logging.sh
source "$PROJECT_ROOT/src/lib/logging.sh"

LOG_FILE="${LOG_FILE:-$PROJECT_ROOT/evidence/ssh/remote-push.log}"

usage() {
    cat <<EOF
Pemakaian: $(basename "$0") <backup_dir> <remote_user> <remote_host> <remote_path> [ssh_key_path] [ssh_port]

Contoh:
  $(basename "$0") ~/sysguard-automation/backup uts-review 10.0.2.16 /home/uts-review/incoming ~/.ssh/id_ed25519 2222
EOF
}

main() {
    log::init

    local backup_dir="${1:-}"
    local remote_user="${2:-}"
    local remote_host="${3:-}"
    local remote_path="${4:-}"
    local ssh_key="${5:-$HOME/.ssh/id_ed25519}"
    local ssh_port="${6:-22}"

    if [[ -z "$backup_dir" || -z "$remote_user" || -z "$remote_host" || -z "$remote_path" ]]; then
        log::error "Argumen kurang. backup_dir, remote_user, remote_host, remote_path wajib diisi."
        usage >&2
        exit 1
    fi

    if [[ ! -d "$backup_dir" ]] || [[ -z "$(ls -A "$backup_dir" 2>/dev/null)" ]]; then
        log::error "backup_dir tidak ditemukan atau kosong: $backup_dir"
        exit 2
    fi

    if [[ ! -f "$ssh_key" ]]; then
        log::error "SSH key tidak ditemukan: $ssh_key (jalankan setup-ssh-key.sh dahulu)"
        exit 3
    fi

    # Ambil backup paling baru saja (bukan seluruh histori) untuk efisiensi.
    local latest_backup
    latest_backup="$(find "$backup_dir" -maxdepth 1 -type d -name 'backup-*' | sort | tail -n1)"

    if [[ -z "$latest_backup" ]]; then
        log::error "Tidak ada folder backup-* ditemukan di $backup_dir"
        exit 2
    fi

    log::info "Mengirim '$latest_backup' ke $remote_user@$remote_host:$remote_path (port $ssh_port) via SCP + SSH key"

    # BatchMode=yes memastikan SSH TIDAK fallback ke prompt password;
    # kalau key authentication gagal, command ini langsung gagal (bukan nge-hang nunggu password).
    if scp -P "$ssh_port" \
           -i "$ssh_key" \
           -o BatchMode=yes \
           -o StrictHostKeyChecking=accept-new \
           -r "$latest_backup" \
           "$remote_user@$remote_host:$remote_path/" 2>>"$LOG_FILE"; then
        log::info "Transfer berhasil: $(basename "$latest_backup") -> $remote_user@$remote_host:$remote_path"
        exit 0
    else
        log::error "Transfer SCP gagal. Cek: host/port benar, key terdaftar di authorized_keys remote, permission direktori tujuan."
        exit 4
    fi
}

main "$@"
