#!/bin/bash
set -euo pipefail
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if (( EUID != 0 )); then
    if command -v pkexec >/dev/null; then
        exec pkexec /bin/bash "$script_dir/uninstall.sh" "$@"
    fi
    exec sudo /bin/bash "$script_dir/uninstall.sh" "$@"
fi
exec 9>/run/lock/x1c6-touchpad-resume-recover.lock
flock -w 120 9
backup_dir=$(mktemp -d /var/backups/thinkpad-trackpoint-uninstall.XXXXXX)
for unit in systemd-suspend systemd-hibernate systemd-hybrid-sleep systemd-suspend-then-hibernate; do
    target="/etc/systemd/system/$unit.service.d/60-trackpoint-resume.conf"
    if [[ -f "$target" ]]; then
        mv -- "$target" "$backup_dir/$unit.conf"
    fi
done
systemctl daemon-reload
if [[ -f /usr/local/sbin/trackpoint-resume ]]; then
    mv /usr/local/sbin/trackpoint-resume "$backup_dir/trackpoint-resume"
fi
printf 'Recovery uninstalled; files preserved in %s\n' "$backup_dir"
