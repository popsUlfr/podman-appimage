#!/bin/bash
set -eux

APPIMAGE="$1"
SIGN_KEY="8DECB02C9406DC24"

pid=
TMP_DIR="$(mktemp -d)"
cleanup() {
    if [[ -n "$pid" ]]; then
        /bin/kill --timeout 2000 KILL "$pid" || true
        wait "$pid" || true
    fi
    if [[ -d "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR"
    fi
}
trap cleanup EXIT
mkfifo -m 600 "$TMP_DIR/mount"
"$(realpath "$APPIMAGE")" --appimage-mount > "$TMP_DIR/mount" &
pid="$!"
APPIMAGE_MOUNT="$(head -n 1 "$TMP_DIR/mount")"
if [[ ! -f appimagetool-x86_64.AppImage ]]; then
    curl -sSLo appimagetool-x86_64.AppImage 'https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage'
    chmod +x appimagetool-x86_64.AppImage
fi
./appimagetool-x86_64.AppImage --sign --sign-key "$SIGN_KEY" "$APPIMAGE_MOUNT" "${APPIMAGE%.*}-signed.AppImage"
/bin/kill --timeout 2000 KILL "$pid"
wait "$pid" || true
pid=
if [[ ! -f key.asc ]]; then
    gpg --export --armor "$SIGN_KEY" > key.asc
fi
podman run --rm -it -v ./:/work \
    -e APPIMAGEFILE="${APPIMAGE%.*}-signed.AppImage" \
    -e PUBKEYASC=key.asc \
    --name appimagevalidate \
    registry.gitlab.com/apfelwurm/appimagevalidate:latest
mv "$APPIMAGE" "${APPIMAGE%.*}-unsigned.AppImage"
mv "${APPIMAGE%.*}-signed.AppImage" "$APPIMAGE"
sha256sum "$APPIMAGE" > "${APPIMAGE}.sha256"
