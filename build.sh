#!/usr/bin/env bash
# build.sh — assemble the honor-fmbp-libfprint-sdcp SOURCE package (3.0 quilt)
# for a Launchpad PPA upload, and optionally test-build the binary locally.
#
# The package repackages upstream libfprint feature/sdcp-v2 @ a pinned commit
# with our three-patch series (patches/) carried as quilt patches under
# debian/patches/. Launchpad builders have NO network and
# never run this script — they build the uploaded .dsc directly. This script's
# job is to PRODUCE that source package: a pristine upstream .orig tarball plus
# debian/ (control, rules, patches). The old 3.0 (native) build.sh git-cloned
# at build time, which cannot work for a source-only PPA upload.
#
#   ./build.sh            -> honor-fmbp-libfprint-sdcp_*.dsc + _source.changes
#                            in the repo root  (ready for debsign + dput)
#   ./build.sh --binary   -> additionally run dpkg-buildpackage -b for a local
#                            .deb (sanity check; the PPA builds its own)
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"

UPSTREAM_URL=https://gitlab.freedesktop.org/libfprint/libfprint.git
UPSTREAM_BRANCH=feature/sdcp-v2
UPSTREAM_COMMIT=2d7c5277de08c6b29b3fac7447f17a516fbc4d1c
SERIES="$here/patches"
LOCAL_MIRROR="${LOCAL_MIRROR:-$HOME/.cache/libfprint-sdcp-v2}"   # reused if present (offline)
WORK="${WORK:-$here/build}"
PKG=honor-fmbp-libfprint-sdcp

ls "$SERIES"/*.patch >/dev/null 2>&1 || { echo "missing series: $SERIES"; exit 1; }

# Version comes from the changelog; quilt requires a Debian revision (a dash),
# so split 1.94.10+sdcpv2-honor6 -> upstream 1.94.10+sdcpv2 / revision honor6.
FULLVER=$(dpkg-parsechangelog -l "$here/debian/changelog" -S Version)
UPVER=${FULLVER%-*}
[ "$UPVER" != "$FULLVER" ] || { echo "FATAL: $FULLVER has no Debian revision (3.0 quilt needs one)"; exit 1; }
SRC="$WORK/${PKG}-${UPVER}"
ORIG="$WORK/${PKG}_${UPVER}.orig.tar.xz"

echo ">> [1/5] locate pinned upstream ${UPSTREAM_COMMIT:0:7} ($UPSTREAM_BRANCH)"
if [ ! -d "$LOCAL_MIRROR/.git" ]; then
  echo "   (no local mirror; cloning $UPSTREAM_BRANCH — needs network this once)"
  git clone -q --branch "$UPSTREAM_BRANCH" --single-branch "$UPSTREAM_URL" "$LOCAL_MIRROR"
fi
git -C "$LOCAL_MIRROR" cat-file -e "${UPSTREAM_COMMIT}^{commit}" 2>/dev/null \
  || { echo "FATAL: $UPSTREAM_COMMIT not in mirror — run once online to fetch it"; exit 1; }

echo ">> [2/5] pristine .orig tarball from the pinned commit"
rm -rf "$WORK"; mkdir -p "$WORK"
git -C "$LOCAL_MIRROR" archive --format=tar --prefix="${PKG}-${UPVER}/" "$UPSTREAM_COMMIT" \
  | xz -6 > "$ORIG"
tar -C "$WORK" -xf "$ORIG"
[ -f "$SRC/meson.build" ] || { echo "FATAL: extracted tree has no meson.build"; exit 1; }

echo ">> [3/5] overlay debian/ and materialise the quilt patch series"
cp -a "$here/debian" "$SRC/"
mkdir -p "$SRC/debian/patches"
: > "$SRC/debian/patches/series"
for p in "$SERIES"/*.patch; do
  cp "$p" "$SRC/debian/patches/"
  basename "$p" >> "$SRC/debian/patches/series"
  echo "   + $(basename "$p")"
done
# Debian-packaging-only patches (NOT part of the upstream MR series), applied
# after it. Kept in debian/patches-local/ in the repo; folded into the single
# debian/patches/ series here and the stray dir dropped from the built source.
for p in "$here/debian/patches-local"/*.patch; do
  [ -e "$p" ] || continue
  cp "$p" "$SRC/debian/patches/"
  basename "$p" >> "$SRC/debian/patches/series"
  echo "   + (debian) $(basename "$p")"
done
rm -rf "$SRC/debian/patches-local"

echo ">> [4/5] build the source package (3.0 quilt, source-only for PPA)"
# Whether to include the .orig tarball in the upload. dpkg defaults to -sd
# (diff-only) for any Debian revision != 1, assuming the archive already has the
# orig. That is WRONG for the FIRST upload of an upstream version to a fresh PPA
# (Launchpad has never seen the orig and rejects the upload) — pass --sa then.
# Use --sd (or nothing) for subsequent uploads that reuse the same orig.
SRCMODE=""
for a in "$@"; do
  case "$a" in
    --sa) SRCMODE="-sa" ;;
    --sd) SRCMODE="-sd" ;;
  esac
done
[ -n "$SRCMODE" ] && echo "   source mode: $SRCMODE ($([ "$SRCMODE" = -sa ] && echo 'orig INCLUDED — first PPA upload' || echo 'diff-only'))"
( cd "$SRC" && dpkg-buildpackage -S -us -uc -d $SRCMODE )

echo ">> [5/5] collect source artifacts into the repo root"
cp -v "$WORK/${PKG}_${FULLVER}.dsc" \
      "$ORIG" \
      "$WORK/${PKG}_${FULLVER}.debian.tar.xz" \
      "$WORK/${PKG}_${FULLVER}_source.buildinfo" \
      "$WORK/${PKG}_${FULLVER}_source.changes" \
      "$here/"

if printf '%s\n' "$@" | grep -qx -- --binary; then
  echo ">> [+] local binary build (dpkg-buildpackage -b)"
  ( cd "$SRC" && dpkg-buildpackage -b -us -uc -d )
  cp -v "$WORK/${PKG}_${FULLVER}_"*.deb "$here/"
fi
echo "done. source package ready: ${PKG}_${FULLVER}.dsc"
