#!/usr/bin/env bash
#
# backup-log.sh - Otomasi backup dan rotasi log (P11 - SysGuard-Lab)
#
# Deskripsi:
#   Menyalin (backup) direktori log sumber ke direktori backup dengan
#   penanda waktu, lalu membuang backup yang lebih tua dari N hari
#   (rotasi). Semua aktivitas dicatat ke evidence/backup.log.
#
# Pemakaian:
#   ./backup-log.sh <source_dir> <backup_dir> [retention_days]
#
#   source_dir       Direktori berisi log yang akan di-backup (wajib)
#   backup_dir        Direktori tujuan penyimpanan backup (wajib)
#   retention_days    Backup lebih tua dari ini (dalam hari) akan dihapus.
#                     Default: 7
#
# Exit status:
#   0  Berhasil
#   1  Argumen tidak valid / kurang
#   2  Direktori sumber tidak ditemukan / tidak bisa dibaca
#   3  Direktori backup tidak bisa dibuat / tidak bisa ditulis
#   4  Proses penyalinan (rsync/cp) gagal
#
# Modul yang dipakai: lib/logging.sh, lib/validate.sh

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# shellcheck source=lib/logging.sh
source "$SCRIPT_DIR/lib/logging.sh"
# shellcheck source=lib/validate.sh
source "$SCRIPT_DIR/lib/validate.sh"

readonly DEFAULT_RETENTION_DAYS=7

usage() {
    cat <<EOF
Pemakaian: $(basename "$0") <source_dir> <backup_dir> [retention_days]

Contoh:
  $(basename "$0") ~/sysguard-automation/input ~/sysguard-automation/backup 7
EOF
}

# backup::validate_args <argc> <source_dir> <backup_dir> <retention>
# Memvalidasi seluruh argumen sebelum proses utama berjalan.
backup::validate_args() {
    local argc="$1" source_dir="$2" backup_dir="$3" retention="$4"

    if (( argc < 2 )); then
        log::error "Argumen kurang. Dibutuhkan minimal: <source_dir> <backup_dir>"
        usage >&2
        return 1
    fi

    if ! validate::dir_exists "$source_dir"; then
        log::error "Direktori sumber tidak ditemukan atau tidak bisa dibaca: $source_dir"
        return 2
    fi

    if ! validate::positive_int "$retention"; then
        log::error "retention_days harus bilangan bulat positif, diterima: '$retention'"
        return 1
    fi

    return 0
}

# backup::ensure_backup_dir <backup_dir>
# Membuat direktori backup jika belum ada, memastikan bisa ditulis.
backup::ensure_backup_dir() {
    local backup_dir="$1"

    if ! mkdir -p "$backup_dir" 2>>"$LOG_FILE"; then
        log::error "Gagal membuat direktori backup: $backup_dir"
        return 3
    fi

    if ! validate::writable "$backup_dir"; then
        log::error "Direktori backup tidak dapat ditulis: $backup_dir"
        return 3
    fi

    return 0
}

# backup::run <source_dir> <dest_dir>
# Menjalankan penyalinan file dari source ke dest bertimestamp.
backup::run() {
    local source_dir="$1" dest_dir="$2"

    log::info "Memulai backup dari '$source_dir' ke '$dest_dir'"

    if ! cp -a -- "$source_dir"/. "$dest_dir"/ 2>>"$LOG_FILE"; then
        log::error "Proses penyalinan gagal (source=$source_dir, dest=$dest_dir)"
        return 4
    fi

    local file_count
    file_count="$(find "$dest_dir" -type f | wc -l)"
    log::info "Backup selesai. $file_count berkas disalin ke $dest_dir"
    return 0
}

# backup::rotate <backup_dir> <retention_days>
# Menghapus subfolder backup (pola backup-YYYYmmdd-HHMMSS) yang lebih tua
# dari retention_days.
backup::rotate() {
    local backup_dir="$1" retention_days="$2"
    local removed=0

    while IFS= read -r -d '' old_dir; do
        log::info "Rotasi: menghapus backup lama '$old_dir' (lebih dari $retention_days hari)"
        rm -rf -- "$old_dir"
        ((removed++))
    done < <(find "$backup_dir" -maxdepth 1 -type d -name 'backup-*' -mtime "+$retention_days" -print0)

    log::info "Rotasi selesai. $removed backup lama dihapus (retensi: $retention_days hari)"
    return 0
}

main() {
    local source_dir="${1:-}"
    local backup_dir="${2:-}"
    local retention_days="${3:-$DEFAULT_RETENTION_DAYS}"

    log::init

    backup::validate_args "$#" "$source_dir" "$backup_dir" "$retention_days"
    local validate_status=$?
    if (( validate_status != 0 )); then
        exit "$validate_status"
    fi

    backup::ensure_backup_dir "$backup_dir"
    local ensure_status=$?
    if (( ensure_status != 0 )); then
        exit "$ensure_status"
    fi

    local timestamp dest_dir
    timestamp="$(date '+%Y%m%d-%H%M%S')"
    dest_dir="$backup_dir/backup-$timestamp"
    mkdir -p "$dest_dir"

    backup::run "$source_dir" "$dest_dir"
    local run_status=$?
    if (( run_status != 0 )); then
        exit "$run_status"
    fi

    backup::rotate "$backup_dir" "$retention_days"

    log::info "backup-log.sh selesai dengan sukses (exit=0)"
    exit 0
}

main "$@"
