# ThinkPad TrackPoint Resume Fix

A small systemd sleep hook for ThinkPads where the TrackPoint or its physical buttons stop working after waking from suspend.

The hook reloads the Linux `psmouse` driver after resume. It does not run as a background service and does not require network access.

## Tested on

- Lenovo ThinkPad X1 Carbon 6th Gen (20KG)
- Linux Mint 22.3 Cinnamon
- Linux kernel 7.0.0-38-generic
- Synaptics TM3288 touchpad with Elan TrackPoint

Other ThinkPad models may behave differently. Use this only when reloading `psmouse` is an appropriate workaround for the affected device.

## Install

```sh
git clone https://github.com/Lervfo/thinkpad-trackpoint-resume.git
cd thinkpad-trackpoint-resume
./install.sh
```

The installer requests administrator access and installs the hook at:

```text
/usr/lib/systemd/system-sleep/trackpoint-resume
```

On the next suspend/resume cycle, the hook runs automatically during the wake phase.

## Verify or test manually

```sh
ls -l /usr/lib/systemd/system-sleep/trackpoint-resume
sudo /usr/lib/systemd/system-sleep/trackpoint-resume post
```

On X11, the TrackPoint should then appear in the input devices:

```sh
xinput list --name-only | grep -i trackpoint
```

## Uninstall

```sh
./uninstall.sh
```

## How it works

The hook only acts when systemd calls it with the `post` argument:

1. Unload `psmouse`.
2. Wait four seconds for the device to settle.
3. Load `psmouse` again.
4. Wait two seconds for input-device enumeration to finish.

The six-second recovery window may slightly delay the desktop appearing after wake.

## License

MIT. See [LICENSE](LICENSE).
