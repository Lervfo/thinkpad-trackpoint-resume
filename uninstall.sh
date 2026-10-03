#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if [ "$(id -u)" -ne 0 ]; then
    if command -v pkexec >/dev/null 2>&1; then
        exec pkexec "$script_dir/uninstall.sh" "$@"
    fi
    if command -v sudo >/dev/null 2>&1; then
        exec sudo "$script_dir/uninstall.sh" "$@"
    fi
    printf '%s\n' 'Root access is required. Install pkexec or sudo, then run this script again.' >&2
    exit 1
fi

if [ -d /usr/lib/systemd/system-sleep ]; then
    target=/usr/lib/systemd/system-sleep/trackpoint-resume
elif [ -d /lib/systemd/system-sleep ]; then
    target=/lib/systemd/system-sleep/trackpoint-resume
else
    printf '%s\n' 'Could not find a systemd sleep-hook directory.' >&2
    exit 1
fi

if [ -e "$target" ]; then
    /bin/rm -f "$target"
    printf 'Removed %s\n' "$target"
else
    printf 'Nothing to remove at %s\n' "$target"
fi
