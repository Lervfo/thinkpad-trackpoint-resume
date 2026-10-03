#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if [ "$(id -u)" -ne 0 ]; then
    if command -v pkexec >/dev/null 2>&1; then
        exec pkexec "$script_dir/install.sh" "$@"
    fi
    if command -v sudo >/dev/null 2>&1; then
        exec sudo "$script_dir/install.sh" "$@"
    fi
    printf '%s\n' 'Root access is required. Install pkexec or sudo, then run this script again.' >&2
    exit 1
fi

if [ -d /usr/lib/systemd/system-sleep ]; then
    target_dir=/usr/lib/systemd/system-sleep
elif [ -d /lib/systemd/system-sleep ]; then
    target_dir=/lib/systemd/system-sleep
else
    printf '%s\n' 'Could not find a systemd sleep-hook directory.' >&2
    exit 1
fi

/usr/bin/install -o root -g root -m 0755 \
    "$script_dir/trackpoint-resume" \
    "$target_dir/trackpoint-resume"

printf 'Installed %s\n' "$target_dir/trackpoint-resume"
