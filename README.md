# Omarchy Charger Monitor

An Omarchy bar widget for live battery power flow, USB-C Power Delivery
contracts, and TUXEDO charging-profile management.

![Charger Monitor panel](preview.png)

## Features

- Live net battery charge or discharge power
- USB-C PD voltage, requested current, maximum current, and contract wattage
- TUXEDO Full, Reduced (~90%), and Stationary (~80%) charging profiles
- Active charging-profile display and verified profile changes

## Requirements

- Omarchy Quattro with shell plugin support
- A battery exposed as `/sys/class/power_supply/BAT0`
- Optional USB-C PD data through Linux UCSI power-supply devices
- Optional TUXEDO charging profiles through `tuxedo_keyboard`
- `bash`, `awk`, `/usr/bin/pkexec`, and `/usr/bin/sudo` for helper installation

The live power display works without TUXEDO hardware. Charge-profile buttons
are disabled when the TUXEDO driver does not expose its profile interface.

## Install

```sh
omarchy plugin add https://github.com/edofic/omarchy-charger-monitor.git --enable
```

The power display is ready immediately. To enable TUXEDO charging-profile
changes, install the narrowly scoped helper into its root-owned system
location:

```sh
~/.config/omarchy/plugins/edofic.charger-monitor/install-helper
```

The installer elevates only `/usr/bin/install`. It copies `charger-profile` to
`/usr/local/libexec/omarchy-charger-monitor/charger-profile` as `root:root`
with mode `0755`. The widget invokes that fixed path through
`/usr/bin/pkexec`; it never elevates code from the user-writable plugin
checkout. The privileged helper independently accepts only `high_capacity`,
`balanced`, or `stationary`, then verifies that the driver advertises the
requested value.

Re-run `install-helper` after updating the plugin so the installed helper
matches the plugin release.

Choose the right bar section if prompted. Click the wattage in the bar to open
the detail panel. Changing a firmware charging profile opens an administrator
authorization prompt.

TUXEDO firmware rescales the selected physical capacity to 100% in Linux, so
the displayed percentage can still reach 100% under Reduced or Stationary use.

Some TUXEDO models or firmware versions accept a profile write and immediately
restore Full capacity. The widget verifies the settled value and reports that
rejection instead of displaying the requested profile as active. This behavior
is controlled by the laptop firmware and `tuxedo_keyboard` driver.

## Remove

Remove the root-owned helper first:

```sh
/usr/bin/sudo /usr/bin/rm -f /usr/local/libexec/omarchy-charger-monitor/charger-profile
/usr/bin/sudo /usr/bin/rmdir --ignore-fail-on-non-empty /usr/local/libexec/omarchy-charger-monitor
```

Then remove the plugin:

```sh
omarchy plugin remove edofic.charger-monitor
```

## Development

```sh
omarchy plugin validate .
bash -n charger-info charger-profile install-helper
```

## License

MIT
