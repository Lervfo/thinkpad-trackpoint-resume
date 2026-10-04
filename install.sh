#!/bin/bash
set -euo pipefail
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if (( EUID != 0 )); then
    if command -v pkexec >/dev/null; then
        exec pkexec /bin/bash "$script_dir/install.sh" "$@"
    fi
    exec sudo /bin/bash "$script_dir/install.sh" "$@"
fi

for command in flock timeout modprobe systemctl install mktemp cp mv; do
    command -v "$command" >/dev/null || { printf 'Missing %s\n' "$command" >&2; exit 1; }
done
bash -n "$script_dir/trackpoint-resume"
[[ -d /run/systemd/system ]] || { echo 'systemd is required.' >&2; exit 1; }
exec 9>/run/lock/x1c6-touchpad-resume-recover.lock
flock -w 120 9

sleep_dir=/usr/lib/systemd/system-sleep
[[ -d "$sleep_dir" ]] || sleep_dir=/lib/systemd/system-sleep
[[ -d "$sleep_dir" ]] || { echo 'No systemd sleep-hook directory.' >&2; exit 1; }
units=(systemd-suspend systemd-hibernate systemd-hybrid-sleep systemd-suspend-then-hibernate)
targets=(/usr/local/sbin/trackpoint-resume /usr/local/sbin/x1c6-touchpad-resume-recover
    "$sleep_dir/trackpoint-resume" "$sleep_dir/x1c6-touchpad-recover")
for unit in "${units[@]}"; do
    targets+=("/etc/systemd/system/$unit.service.d/60-trackpoint-resume.conf")
done

# Executable backups inside system-sleep also run; keep them outside that directory.
backup_dir=$(mktemp -d /var/backups/thinkpad-trackpoint-resume.XXXXXX)
for i in "${!targets[@]}"; do
    target=${targets[$i]}
    [[ ! -L "$target" ]] || { echo "Refusing symlink: $target" >&2; exit 1; }
    printf '%s\t%s\n' "$i" "$target" >> "$backup_dir/manifest.tsv"
    if [[ -e "$target" ]]; then
        cp -a -- "$target" "$backup_dir/$i"
    fi
done

rollback() {
    local status=$? i target
    trap - EXIT HUP INT TERM
    if (( status != 0 )); then
        echo "Installation failed; restoring files from $backup_dir" >&2
        for i in "${!targets[@]}"; do
            target=${targets[$i]}
            if [[ -e "$backup_dir/$i" ]]; then
                cp -a -- "$backup_dir/$i" "$target" || true
            elif [[ -e "$target" ]]; then
                mv -- "$target" "$backup_dir/failed-$i" || true
            fi
        done
        systemctl daemon-reload || true
    fi
    exit "$status"
}
trap rollback EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

install -o root -g root -m 0755 "$script_dir/trackpoint-resume" /usr/local/sbin/trackpoint-resume
for unit in "${units[@]}"; do
    install -d -m 0755 "/etc/systemd/system/$unit.service.d"
    install -o root -g root -m 0644 "$script_dir/resume-recovery.conf" \
        "/etc/systemd/system/$unit.service.d/60-trackpoint-resume.conf"
done
# Retire both conflicting hooks and the old helper, retaining recoverable copies.
for i in 1 2 3; do
    target=${targets[$i]}
    if [[ -e "$target" ]]; then
        mv -- "$target" "$backup_dir/retired-$i"
    fi
done
systemctl daemon-reload
for unit in "${units[@]}"; do
    effective=$(systemctl show "$unit.service" -p ExecStartPost --value)
    [[ "$effective" == *'/usr/local/sbin/trackpoint-resume post'* ]] || exit 1
done
trap - EXIT HUP INT TERM
printf 'Installed guarded recovery after all wake hooks. No driver was restarted.\nBackups: %s\n' "$backup_dir"
