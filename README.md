# honor-fmbp-libfprint-sdcp

Fingerprint support for the **HONOR MagicBook Pro 14 2025 (FMB-P)** — the EgisTec ET171
(`1c7a:05aa`) match-on-chip sensor, which speaks Microsoft's SDCP (the Windows Hello
protocol). The power button *is* the sensor.

This is a **stopgap Debian packaging** of upstream libfprint's SDCP branch
([merge request 547](https://gitlab.freedesktop.org/libfprint/libfprint/-/merge_requests/547),
`feature/sdcp-v2`, pinned commit) plus a six-patch series ([`patches/`](patches/)):

1. `egismoc`: EgisTec ET171 (`1c7a:05aa`) device support
2. SDCP core: mark the identified print as device-stored (every match otherwise fails)
3. `egismoc`: robustness fixes (short-interrupt-packet guard, SW-9000-only duplicate check)
4. SDCP core: fix an intermittent open hang (~1 in 256 opens) on host keys with a leading
   zero byte ([#1](https://github.com/drphilth/honor-fmbp-libfprint-sdcp/issues/1))
5. `egismoc`: finish the identify task on a finger-wait timeout (fixes a double close
   completion and `G_IS_TASK` critical)
6. `egismoc`: bounds-check the SDCP ConnectResponse against the device-supplied cert length

The series is our own work, proposed for upstream inclusion; this package retires once
the SDCP branch plus this device id land in a released libfprint. Hardware-verified on
the FMB-P: enroll, verify, PAM lock-screen unlock, suspend/resume reconnect.

## Installing

### Ubuntu / Debian

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

### Arch / CachyOS

Packaged in [`arch/`](arch/). Same fork, same patches — only the packaging layer differs from
[`debian/`](debian/).

```sh
cd arch && makepkg -si
fprintd-enroll && fprintd-verify        # the ET171 wants ~15 touches
```

It is also pulled in as an optional dependency of the
[`honor-magicbook-pro-14`](https://github.com/drphilth/honor-magicbook-pro-14-cachy) metapackage.

The Arch build pins **upstream libfprint's git commit directly**, so nothing is vendored:
`git+https://gitlab.freedesktop.org/libfprint/libfprint.git#commit=2d7c527…`.

Two things worth knowing if you touch this PKGBUILD:

- It needs **`glib2-devel`** at build time. Arch split `glib-mkenums` out of `glib2`, and without
  it meson dies with *"tool variable 'glib_mkenums' contains erroneous value"*.
- The `package()` step must match the **real ELF only** — meson also emits
  `libfprint-2.so.2.0.0.symbols` next to it. Globbing that by mistake ships a **dangling symlink
  with no library**, `ldconfig` silently falls back to the stock (SDCP-less) libfprint, and
  fingerprint just stops working with nothing obviously broken.

**KDE:** lock-screen unlock works with no PAM edits — Plasma ships a `kde-fingerprint` stack. The
*login* screen does not support fingerprint; that is an upstream gap
([plasma-login-manager#1](https://invent.kde.org/plasma/plasma-login-manager/-/issues/1)), not a
misconfiguration. The PAM workaround for it breaks KWallet — don't.


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
