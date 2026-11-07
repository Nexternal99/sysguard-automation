# Changelog

Seluruh perubahan penting pada proyek ini dicatat di file ini.

## [P2-CHECKPOINT-P12-v01] - Integrasi Layanan dan Akses Aman

### Ditambahkan
- ssh-integration/setup-ssh-key.sh: membuat SSH key pair (ed25519) dan mencetak
  instruksi pendaftaran public key ke mesin remote.
- ssh-integration/remote-push-backup.sh: mengirim hasil backup terbaru dari P11
  ke mesin remote lewat SCP dengan autentikasi SSH berbasis kunci
  (BatchMode=yes, tidak pernah fallback ke password).
- evidence/ssh/remote-push.log: log aktivitas transfer SCP (berhasil dan ditolak).

### Diubah (dari arsitektur P11)
- P11 bersifat lokal: backup-log.sh menyalin log dari input/ ke backup/ di mesin
  yang sama, tanpa komunikasi jaringan.
- P12 memperluas alur menjadi lintas mesin: hasil backup/ dari P11 dipakai sebagai
  input remote-push-backup.sh, yang mengirimkannya ke mesin lain lewat SCP.
  Modul lib/logging.sh dari P11 dipakai ulang sehingga format log tetap konsisten.
- Kontrol akses bertambah dari permission filesystem lokal (P11) menjadi
  autentikasi jaringan berbasis SSH public key di authorized_keys (P12).

### Diperbaiki
- Urutan source lib/logging.sh menyebabkan log SSH masuk ke evidence/backup.log
  (milik P11) alih-alih evidence/ssh/remote-push.log. LOG_FILE sekarang
  ditentukan sebelum baris source.

### Keamanan
- .gitignore mencakup pola private key (id_rsa*, id_ed25519*) dengan pengecualian
  public key (!*.pub).
- SCP memakai BatchMode=yes agar script tidak menunggu input password di sesi
  non-interaktif.

## [P2-CHECKPOINT-P11-v01] - Modul Otomasi Administrasi

### Ditambahkan
- src/backup-log.sh: script utama backup dan rotasi log, modular dengan fungsi
  validate_args, ensure_backup_dir, run, dan rotate.
- src/lib/logging.sh: modul logging terpusat (INFO/WARN/ERROR dengan timestamp).
- src/lib/validate.sh: modul validasi input (dir_exists, positive_int, writable).
- tests/run-tests.sh: 1 pengujian sukses dan 2 pengujian gagal, hasil tersimpan
  di evidence/test-results.log.
- README.md, .gitignore, CONTRIBUTORS.md, config/backup.conf.example.
