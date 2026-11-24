# honor-fmbp-libfprint-sdcp

Fingerprint support for the **HONOR MagicBook Pro 14 2025 (FMB-P)**. The power button *is*
the sensor, and units ship one of two match-on-chip sensors (check `lsusb`):

| USB ID | Sensor | Driver |
|---|---|---|
| `1c7a:05aa` | EgisTec ET171, speaks Microsoft's SDCP (the Windows Hello protocol) | `egismoc` + SDCP (patches 1–6) |
| `10a5:9924` | FPC "L:2407" (`10a5:9b24` is a related FPC id) | `fpcmoc` (patches 7–8) |

This is a **stopgap Debian packaging** of upstream libfprint's SDCP branch
([merge request 547](https://gitlab.freedesktop.org/libfprint/libfprint/-/merge_requests/547),
`feature/sdcp-v2`, pinned commit) plus an eight-patch series ([`patches/`](patches/)):

1. `egismoc`: EgisTec ET171 (`1c7a:05aa`) device support
2. SDCP core: mark the identified print as device-stored (every match otherwise fails)
3. `egismoc`: robustness fixes (short-interrupt-packet guard, SW-9000-only duplicate check)
4. SDCP core: fix an intermittent open hang (~1 in 256 opens) on host keys with a leading
   zero byte ([#1](https://github.com/drphilth/honor-fmbp-libfprint-sdcp/issues/1))
5. `egismoc`: finish the identify task on a finger-wait timeout (fixes a double close
   completion and `G_IS_TASK` critical)
6. `egismoc`: bounds-check the SDCP ConnectResponse against the device-supplied cert length
7. `fpcmoc`: FPC `10a5:9b24` id — upstream commit d8641635 (lichenggang), released in
   1.94.100, backported because the pinned SDCP base predates it
8. `fpcmoc`: FPC `10a5:9924` id and no USB reset on open (the reset restarts its firmware,
   which re-enumerates and kills the handle) — upstream
   [MR !666](https://gitlab.freedesktop.org/libfprint/libfprint/-/merge_requests/666)
   (Lukas Thomann), still open

Both drivers are built: the library replaces the stock one for fprintd (see below), so a
driver missing here would be missing altogether.

Patches 1–6 are our own work, proposed for upstream inclusion; 7–8 are upstream commits.
This package retires once the SDCP branch plus these device ids land in a released
libfprint. Hardware-verified on the FMB-P with the ET171: enroll, verify, PAM lock-screen
unlock, suspend/resume reconnect. The FPC patch matches the one colorcube's Fedora
package ships (tested there: enroll, verify, other fingers rejected); this build of it
still needs an FPC owner's confirmation.

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

The Windows caveat above was verified with the ET171; whether Windows also prunes
Linux templates on the FPC sensor is not known yet. A third FMB-P variant, FPC
`10a5:a920`, is not covered (see [feraxtx/libfprint-10a5-a920](https://github.com/feraxtx/libfprint-10a5-a920)).

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
