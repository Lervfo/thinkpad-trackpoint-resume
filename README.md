# ThinkPad touchpad / TrackPoint resume recovery

Checks both input devices after waking, leaving them alone when present. If either
is missing, reloads `psmouse` with a four-second pause and verifies that both return.
One retry and a reload-on-exit fallback cover failed/interrupted recovery.

| Item | Value |
|---|---|
| Target hardware | ThinkPad X1 Carbon 6th Gen (20KG), Synaptics TM3288 + Elan TrackPoint |
| Observed system | Linux Mint 22.3 Cinnamon, kernel 7.0.0-38-generic |
| Helper | `/usr/local/sbin/trackpoint-resume` |
| Integration | `ExecStartPost` in the four systemd sleep services |
| Trigger | After suspend/hibernate and all system-sleep hooks finish; never at boot |
| Health check | Both kernel input devices and evdev nodes, stable across three samples |

## Install / update

```sh
./install.sh
```

The installer requests administrator access, backs up and retires the old
`trackpoint-resume` and `x1c6-touchpad-recover` sleep hooks plus their old helper,
and installs `60-trackpoint-resume.conf` under each sleep service's drop-in directory.
Backups are outside the executable hook directory, under `/var/backups/`.
Installation does not reload drivers, run TLP, change modprobe options, or rebuild
the initramfs. It takes effect on the next wake without rebooting.

## Verify

```sh
sudo /usr/local/sbin/trackpoint-resume post
systemctl show systemd-suspend.service -p ExecStartPost
journalctl -b -u systemd-suspend.service --no-pager
xinput list --name-only
bash tests/recovery.sh
```

A working device must take the `no restart needed` path. After an actual sleep/wake,
test pointer motion and physical buttons as well as checking the journal.
Input registration does not prove that physical movement works.

Validated on 2026-10-04: 11 fault-injection/no-op checks passed, systemd unit
validation passed, and a live systemd invocation preserved both existing devices
without a reload. The next physical sleep/wake test remains pending.

## Why the older hooks failed

On 2026-10-04 at 08:34:00, the guarded hook logged success just before the device
disappeared; a second hook still unconditionally reloaded `psmouse`. Systemd runs
[system-sleep hooks in parallel](https://github.com/systemd/systemd/blob/v255/man/systemd-suspend.service.xml).
`ExecStartPost` checks only after all of them, including TLP, have finished. The
replacement also waits for settling instead of returning on its first sample.

Recovery only addresses missing devices on the named hardware. It cannot detect
every firmware hang while the device remains registered, guarantee recovery from
hardware failure, or run its exit fallback after SIGKILL/power loss. It reports
exhausted retries instead of claiming success. A normal wake adds about five
seconds; a recovery takes longer. No polling daemon runs between wakes.

## Uninstall

```sh
./uninstall.sh
```

Retired files remain in `/var/backups/`. Uninstall does not restore the conflicting
old hooks or alter the running driver. MIT license; see [LICENSE](LICENSE).
