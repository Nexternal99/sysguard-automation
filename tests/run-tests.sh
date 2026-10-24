#!/usr/bin/env bash
#
# run-tests.sh - Menjalankan 1 pengujian sukses + 2 pengujian gagal
# untuk backup-log.sh, dan menyimpan hasilnya sebagai bukti ke evidence/.
#
# Pemakaian: ./run-tests.sh
# Dijalankan dari dalam folder tests/, atau dari mana saja (path otomatis).

set -uo pipefail

TESTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PROJECT_ROOT="$(dirname "$TESTS_DIR")"
SCRIPT="$PROJECT_ROOT/src/backup-log.sh"
EVIDENCE_DIR="$PROJECT_ROOT/evidence"
SANDBOX="$(mktemp -d)"

mkdir -p "$EVIDENCE_DIR"

pass=0
fail=0

run_case() {
    local name="$1" expected_exit="$2"; shift 2
    local out
    out="$("$@" 2>&1)"
    local actual_exit=$?

    {
        echo "=== TEST: $name ==="
        echo "Command : $*"
        echo "Expected exit : $expected_exit"
        echo "Actual exit   : $actual_exit"
        echo "--- Output ---"
        echo "$out"
        echo
    } >> "$EVIDENCE_DIR/test-results.log"

    if [[ "$actual_exit" -eq "$expected_exit" ]]; then
        echo "[PASS] $name (exit=$actual_exit)"
        ((pass++))
    else
        echo "[FAIL] $name (expected=$expected_exit, actual=$actual_exit)"
        ((fail++))
    fi
}

# Reset file hasil tes supaya tidak menumpuk dari run sebelumnya
: > "$EVIDENCE_DIR/test-results.log"

echo "Sandbox pengujian: $SANDBOX"
mkdir -p "$SANDBOX/input" "$SANDBOX/backup"
echo "contoh log baris 1" > "$SANDBOX/input/app.log"
echo "contoh log baris 2" > "$SANDBOX/input/sys.log"

# --- Test 1: SUKSES - backup normal dengan source & dest valid ---
run_case "backup-sukses" 0 \
    "$SCRIPT" "$SANDBOX/input" "$SANDBOX/backup" 7

# --- Test 2: GAGAL - source directory tidak ada ---
run_case "source-tidak-ada" 2 \
    "$SCRIPT" "$SANDBOX/tidak-ada-folder-ini" "$SANDBOX/backup" 7

# --- Test 3: GAGAL - argumen kurang (retention_days bukan angka valid) ---
run_case "argumen-tidak-valid" 1 \
    "$SCRIPT" "$SANDBOX/input" "$SANDBOX/backup" "bukan-angka"

echo
echo "Ringkasan: $pass PASS, $fail FAIL"
echo "Detail tersimpan di: $EVIDENCE_DIR/test-results.log"

rm -rf "$SANDBOX"

if (( fail > 0 )); then
    exit 1
fi
exit 0
