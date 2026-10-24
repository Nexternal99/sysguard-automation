#!/usr/bin/env bash
# validate.sh - modul validasi input untuk sysguard-backup

# validate::dir_exists <path>
# Return 0 jika direktori ada dan bisa dibaca, selain itu return 1.
validate::dir_exists() {
    local path="$1"
    [[ -n "$path" ]] || return 1
    [[ -d "$path" ]] || return 1
    [[ -r "$path" ]] || return 1
    return 0
}

# validate::positive_int <value>
# Return 0 jika value adalah bilangan bulat positif (untuk retensi hari).
validate::positive_int() {
    local value="$1"
    [[ "$value" =~ ^[1-9][0-9]*$ ]]
}

# validate::writable <path>
# Return 0 jika path ada dan dapat ditulis, atau parent-nya ada & writable
# (untuk kasus path belum dibuat).
validate::writable() {
    local path="$1"
    if [[ -e "$path" ]]; then
        [[ -w "$path" ]]
    else
        [[ -w "$(dirname "$path")" ]]
    fi
}
