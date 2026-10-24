#!/usr/bin/env bash
#
# setup-ssh-key.sh - Panduan terbimbing membuat & mendaftarkan SSH key
# untuk autentikasi berbasis kunci (P12 - SysGuard-Lab).
#
# PENTING: Script ini HANYA MEMBUAT key baru dan MENCETAK instruksi.
# Script ini TIDAK PERNAH membaca, mencetak, atau mengirim isi private key
# ke mana pun (termasuk ke evidence/log), sesuai larangan modul.
#
# Pemakaian:
#   ./setup-ssh-key.sh [key_path] [comment]
#
# Exit status:
#   0  Key berhasil dibuat (atau sudah ada sebelumnya)
#   1  Pembuatan key gagal

set -uo pipefail

key_path="${1:-$HOME/.ssh/id_ed25519}"
comment="${2:-sysguard-automation}"

if [[ -f "$key_path" ]]; then
    echo "Key sudah ada di $key_path, tidak membuat ulang (hindari menimpa key yang sudah dipakai)."
else
    echo "Membuat SSH key baru (ed25519, tanpa passphrase untuk kebutuhan otomasi latihan)..."
    ssh-keygen -t ed25519 -f "$key_path" -N "" -C "$comment"
fi

echo
echo "=== Langkah selanjutnya (manual, di mesin REMOTE) ==="
echo "1. Salin public key ke mesin remote:"
echo "   ssh-copy-id -i ${key_path}.pub -p <port> <remote_user>@<remote_host>"
echo "   (atau manual: tempel isi ${key_path}.pub ke ~/.ssh/authorized_keys milik remote_user)"
echo
echo "2. Uji login tanpa password:"
echo "   ssh -i ${key_path} -p <port> <remote_user>@<remote_host>"
echo
echo "3. Untuk bukti 'akses ditolak', coba login dengan key LAIN yang tidak terdaftar:"
echo "   ssh -i ~/.ssh/id_ed25519_bukan_terdaftar -o BatchMode=yes -p <port> <remote_user>@<remote_host>"
echo "   (harapkan: Permission denied (publickey))"
echo
echo "Catatan: jangan pernah menempelkan isi private key (${key_path}) ke evidence, log, atau repository."
