# fern runbook

## CPU governor

power-profiles-daemon leaves acpi-cpufreq on `powersave`, which pins this Picasso
APU at its 1400 MHz floor while `balanced` is selected and the machine is on AC.
Measured 2026-11-01 on a 3M-iteration loop: powersave 1396 MHz / 0.891 s,
schedutil 2586 MHz / 0.476 s, performance 0.469 s. schedutil scales the same
1.4-2.6 GHz range and is power-aware, so it takes the 2x without the heat.

Ordering matters: cpufreq's oneshot runs off systemd-modules-load, ppd starts
later, and ppd does not re-apply on restart, so the oneshot has to be last.

## Keybase autostart

Keybase's GUI writes `~/.config/autostart/keybase_autostart.desktop`, whose Exec
is `env KEYBASE_AUTOSTART=1 run_keybase`. `run_keybase` ships only with
keybase-gui, and `services.keybase` already runs Keybase as user services, so the
entry can only fail: fern logged `env: 'run_keybase': No such file or directory`
(exit 127) at every login. The activation script removes the entry while
`run_keybase` is absent and leaves it alone if the GUI is installed.

Dock Ethernet: `.agents/deploy/dock-ethernet.md`.
