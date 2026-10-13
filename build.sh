#!/bin/bash
# Builds JagannathaHora-8.0-mac.dmg from the official Windows installer.
#
# Usage: ./build.sh /path/to/jh_full_install.exe
# Requires: Homebrew (installs innoextract and icoutils if missing).
set -euo pipefail

INSTALLER="${1:?Usage: ./build.sh /path/to/jh_full_install.exe}"
WINE_VERSION="11.17"
WINE_URL="https://github.com/Gcenx/macOS_Wine_builds/releases/download/${WINE_VERSION}/wine-staging-${WINE_VERSION}-osx64.tar.xz"

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$HERE/work"
OUT="$HERE/dist"
APP="$WORK/dmg/Jagannatha Hora.app"
C="$APP/Contents"

for tool in innoextract icoutils; do
    brew list "$tool" >/dev/null 2>&1 || brew install "$tool"
done

mkdir -p "$WORK" "$OUT" "$C/MacOS" "$C/Resources/payload"

# 1. Extract JHora program files and fonts from the installer.
innoextract -s -d "$WORK/extract" "$INSTALLER"
ditto "$WORK/extract/app" "$C/Resources/payload/JHora"
ditto "$WORK/extract/fonts" "$C/Resources/payload/Fonts"
cp "$HERE/packaging/jhora.reg" "$C/Resources/payload/jhora.reg"

# 2. Bundle Wine.
curl -fL -o "$WORK/wine.tar.xz" "$WINE_URL"
tar -xf "$WORK/wine.tar.xz" -C "$WORK"
ditto "$WORK/Wine Staging.app/Contents/Resources/wine" "$C/Resources/wine"

# 3. App icon from jhora.exe (icon group 128).
wrestool -x -t 14 -n 128 "$WORK/extract/app/bin/jhora.exe" -o "$WORK/main.ico"
icotool -x -i 1 "$WORK/main.ico" -o "$WORK/main32.png"
mkdir -p "$WORK/AppIcon.iconset"
for s in 16 32 128 256 512; do
    sips -z $s $s "$WORK/main32.png" --out "$WORK/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
    sips -z $((s*2)) $((s*2)) "$WORK/main32.png" --out "$WORK/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$WORK/AppIcon.iconset" -o "$C/Resources/AppIcon.icns"

# 4. Launcher and Info.plist, then ad-hoc sign.
cp "$HERE/packaging/JHora" "$C/MacOS/JHora"
chmod +x "$C/MacOS/JHora"
cp "$HERE/packaging/Info.plist" "$C/Info.plist"
codesign --force --deep -s - "$APP"

# 5. Disk image.
cp "$HERE/packaging/READ ME FIRST.txt" "$WORK/dmg/"
ln -sf /Applications "$WORK/dmg/Applications"
hdiutil create -volname "Jagannatha Hora" -srcfolder "$WORK/dmg" -fs HFS+ -format ULFO -ov \
    "$OUT/JagannathaHora-8.0-mac.dmg"
shasum -a 256 "$OUT/JagannathaHora-8.0-mac.dmg"
