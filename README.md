# SysGuard Automation — Backup & Rotasi Log + Integrasi Akses Aman

Proyek kelompok untuk **Checkpoint P11** (otomasi administrasi) dan **Checkpoint P12**
(integrasi layanan dan akses aman), SIM024302 Praktikum Sistem Operasi.

## Ringkasan

Script ini mengotomasi pekerjaan administrasi: **backup direktori log** dengan
penanda waktu, lalu **rotasi** (menghapus backup yang lebih tua dari batas
retensi). Pada P12, hasil backup terbaru dapat dikirim ke mesin remote lewat
**SCP dengan autentikasi SSH berbasis kunci** — tanpa password sama sekali.

## Struktur repository

```
sysguard-automation/
├── README.md                          # dokumen ini
├── CONTRIBUTORS.md                    # kontribusi anggota kelompok
├── src/
│   ├── backup-log.sh                  # script utama P11
│   └── lib/
│       ├── logging.sh                 # modul logging terpusat
│       └── validate.sh                # modul validasi input
├── tests/
│   └── run-tests.sh                   # 1 uji sukses + 2 uji gagal
├── ssh-integration/                   # P12
│   ├── setup-ssh-key.sh               # bikin & daftarkan SSH key
│   └── remote-push-backup.sh          # kirim backup via SCP + SSH key
└── evidence/                          # log & hasil uji (sudah disanitasi)
    ├── backup.log
    ├── test-results.log
    └── ssh/remote-push.log
```

## P11 — `src/backup-log.sh`

### Pemakaian

```bash
./src/backup-log.sh <source_dir> <backup_dir> [retention_days]
```

| Argumen | Wajib | Keterangan |
|---|---|---|
| `source_dir` | Ya | Direktori berisi log yang akan di-backup |
| `backup_dir` | Ya | Direktori tujuan penyimpanan backup |
| `retention_days` | Tidak (default 7) | Backup lebih tua dari N hari akan dihapus |

### Modularitas

- `lib/logging.sh` — semua pesan INFO/WARN/ERROR dicatat dengan timestamp ke
  `evidence/backup.log`, bisa dipakai ulang oleh script lain (termasuk
  `remote-push-backup.sh` di P12).
- `lib/validate.sh` — fungsi validasi input (`dir_exists`, `positive_int`,
  `writable`) terpisah dari logika utama, mudah diuji dan dipakai ulang.
- `src/backup-log.sh` sendiri dipecah menjadi fungsi `backup::validate_args`,
  `backup::ensure_backup_dir`, `backup::run`, `backup::rotate` — masing-masing
  tanggung jawab tunggal.

### Exit status

| Kode | Arti |
|---|---|
| 0 | Berhasil |
| 1 | Argumen tidak valid / kurang |
| 2 | Direktori sumber tidak ditemukan / tidak bisa dibaca |
| 3 | Direktori backup tidak bisa dibuat / ditulis |
| 4 | Proses penyalinan gagal |

### Pengujian

```bash
bash tests/run-tests.sh
```

Menjalankan:
1. **Sukses** — backup normal dengan source & tujuan valid (exit 0).
2. **Gagal** — direktori sumber tidak ada (exit 2).
3. **Gagal** — parameter retensi bukan angka valid (exit 1).

Hasil tersimpan di `evidence/test-results.log`.

## P12 — Integrasi SSH Key + SCP

### 1. Setup SSH key

```bash
./ssh-integration/setup-ssh-key.sh ~/.ssh/id_ed25519 sysguard-automation
```

Membuat key baru (jika belum ada), lalu mencetak instruksi untuk mendaftarkan
public key ke mesin remote (`ssh-copy-id`) dan cara mengujinya.

### 2. Kirim backup terbaru ke remote

```bash
./ssh-integration/remote-push-backup.sh \
    <backup_dir> <remote_user> <remote_host> <remote_path> \
    [ssh_key_path] [ssh_port]
```

Memakai `scp` dengan `-o BatchMode=yes` — **tidak akan pernah fallback ke
prompt password**. Kalau autentikasi key gagal, script langsung berhenti
dengan exit code jelas, bukan menggantung menunggu password.

### Exit status

| Kode | Arti |
|---|---|
| 0 | Transfer berhasil |
| 1 | Argumen tidak valid |
| 2 | `backup_dir` tidak ditemukan / kosong |
| 3 | SSH key tidak ditemukan |
| 4 | Koneksi/transfer SCP gagal (termasuk akses ditolak) |

### Membuktikan akses diizinkan vs ditolak

**Akses diizinkan** — key terdaftar di `authorized_keys` remote:
```bash
./ssh-integration/remote-push-backup.sh ~/sysguard-automation/backup \
    uts-review 10.0.2.16 /home/uts-review/incoming ~/.ssh/id_ed25519 2222
# exit=0, file sampai di remote
```

**Akses ditolak** — pakai key yang sengaja TIDAK didaftarkan di remote:
```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_tidak_terdaftar -N "" -C "uji-ditolak"
./ssh-integration/remote-push-backup.sh ~/sysguard-automation/backup \
    uts-review 10.0.2.16 /home/uts-review/incoming ~/.ssh/id_ed25519_tidak_terdaftar 2222
# exit=4, pesan "Permission denied (publickey)" di evidence/ssh/remote-push.log
```

### Permission & risiko

- Private key **tidak pernah** disalin ke repository atau folder `evidence/`.
- `authorized_keys` di sisi remote sebaiknya `600`, dan folder `~/.ssh` `700`,
  supaya SSH tidak menolak key karena permission terlalu longgar.
- `BatchMode=yes` dipakai justru sebagai kontrol keamanan: mencegah script
  diam-diam menunggu input password di sesi non-interaktif (misalnya saat
  dijalankan dari cron).
- Risiko utama: salah host/port akan membuat script gagal di exit 4 tanpa
  merusak data — tidak ada operasi destruktif di sisi remote.

## Cleanup & rollback

```bash
# Hapus seluruh hasil backup latihan (tidak menyentuh source asli)
rm -rf ~/sysguard-automation/backup/backup-*

# Hapus SSH key uji yang sengaja dibuat untuk skenario "ditolak"
rm -f ~/.ssh/id_ed25519_tidak_terdaftar ~/.ssh/id_ed25519_tidak_terdaftar.pub

# Rollback: kembalikan ke commit/tag sebelumnya bila perlu
git checkout P2-CHECKPOINT-P11-v01 -- src/ tests/
```

Folder `evidence/` sengaja **tidak** dihapus saat cleanup — ini adalah bukti
pengerjaan yang harus tetap ada untuk penilaian.

## Batasan yang belum diselesaikan

- Belum ada containerization (direncanakan P13–P15).
- Rotasi backup saat ini berbasis waktu modifikasi folder (`mtime`), belum
  mendukung jumlah maksimum backup (`max_count`) sebagai alternatif kebijakan
  retensi.
- `remote-push-backup.sh` hanya mengirim backup *terbaru*, belum ada mode
  sinkronisasi penuh / incremental (misalnya via `rsync`).

## Catatan keamanan

Repository ini **tidak** menyertakan password, token, private key, isi
`~/.ssh`, atau data pribadi apa pun. Semua contoh IP/host/user di atas adalah
placeholder dan harus disesuaikan dengan topologi VM kelompok masing-masing.
