# honor-fmbp-libfprint-sdcp

Fingerprint support for the **HONOR MagicBook Pro 14 2025 (FMB-P)** — the EgisTec ET171
(`1c7a:05aa`) match-on-chip sensor, which speaks Microsoft's SDCP (the Windows Hello
protocol). The power button *is* the sensor.

This is a **stopgap Debian packaging** of upstream libfprint's SDCP branch
([merge request 547](https://gitlab.freedesktop.org/libfprint/libfprint/-/merge_requests/547),
`feature/sdcp-v2`, pinned commit) plus a three-patch series ([`patches/`](patches/)):

1. `egismoc`: EgisTec ET171 (`1c7a:05aa`) device support
2. SDCP core: mark the identified print as device-stored (every match otherwise fails)
3. `egismoc`: robustness fixes (short-interrupt-packet guard, SW-9000-only duplicate check)

The series is our own work, proposed for upstream inclusion; this package retires once
the SDCP branch plus this device id land in a released libfprint. Hardware-verified on
the FMB-P: enroll, verify, PAM lock-screen unlock, suspend/resume reconnect.

## Installing

Easiest via the PPA (pulled in automatically by the
[`honor-magicbook-pro-14`](https://github.com/drphilth/honor-magicbook-pro-14-ubuntu)
metapackage):

```bash
sudo add-apt-repository ppa:drphilth/honor-fmbp
sudo apt install honor-fmbp-libfprint-sdcp libpam-fprintd
```

The library installs to a private directory and wins over the stock `libfprint-2-2` via
`ld.so.conf.d` ordering — the stock package stays installed and untouched; remove this
package to fall back cleanly.

**Read [`debian/…README.Debian`](debian/honor-fmbp-libfprint-sdcp.README.Debian) before
relying on it** — most importantly: **booting Windows wipes your Linux enrollments**
(the Windows biometric stack garbage-collects on-chip templates it doesn't recognise —
verified experimentally; the fix is disabling the fingerprint device in Windows's Device
Manager if you dual-boot). It also covers enrollment, PAM setup and retry tuning.

Only the ET171 (`1c7a:05aa`) variant is covered. Some FMB-P units ship FPC sensors
(`10a5:9924` / `10a5:9b24`, check `lsusb`) — those need a different driver and are not
supported here.

## Building

`build.sh` assembles the 3.0 (quilt) **source package**: it fetches pristine upstream at
the pinned commit, produces the `.orig` tarball, overlays `debian/` and materialises the
patch series — ready for `debsign` + `dput` (Launchpad builds the binaries). Needs
network once (to clone the upstream mirror into `~/.cache/libfprint-sdcp-v2`).

```bash
./build.sh            # source package -> repo root (.dsc + _source.changes)
./build.sh --binary   # additionally build a local .deb for sanity-checking
./build.sh --sa       # include the .orig in the upload (first upload of an upstream version)
```

## License

LGPL-2.1+ (upstream libfprint's license; see [`LICENSE`](LICENSE) and
[`debian/copyright`](debian/copyright)).
