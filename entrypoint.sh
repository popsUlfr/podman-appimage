#!/bin/sh
set -e
export PATH="$APPDIR/usr/bin:$PATH"

conf_setup() {
    configroot="${1:?}"
    dataroot="${2:?}"
    runtimeroot="${3:?}"

    storagepath="$dataroot/containers/storage"
    if [ ! -d "$storagepath" ]
    then
        mkdir -p "$storagepath" >&2
    fi

    storageconfpath="$configroot/containers/storage.conf"
    if [ ! -f "$storageconfpath" ]
    then
        mkdir -p "$(dirname "$storageconfpath")" >&2
        cp "$APPDIR/etc/containers/storage.conf" "$storageconfpath" >&2
        sed -i 's|^\s*#\?\s*\(runroot\s*=\s*\).*$|\1"'"$runtimeroot/containers/storage"'"|' "$storageconfpath" >&2
        sed -i 's|^\s*#\?\s*\(graphroot\s*=\s*\).*$|\1"'"$storagepath"'"|' "$storageconfpath" >&2
        if [ "$(stat -f -c '%T' "$storagepath")" = 'btrfs' ]
        then
            sed -i 's/^\s*#\?\s*\(driver\s*=\s*\).*$/\1"btrfs"/' "$storageconfpath" >&2
        fi
    fi
    sed -i 's|^\s*#\?\s*\(mount_program\s*=\s*\).*$|\1"'"$APPDIR/usr/bin/fuse-overlayfs"'"|' "$storageconfpath" >&2

    containersconfpath="$configroot/containers/containers.conf"
    if [ ! -f "$containersconfpath" ]
    then
        mkdir -p "$(dirname "$containersconfpath")" >&2
        cp "$APPDIR/etc/containers/containers.conf" "$containersconfpath" >&2
        sed -i 's|^\s*#\?\s*\(volume_path\s*=\s*\).*$|\1"'"$storagepath/volumes"'"|' "$containersconfpath" >&2
        seccompconfpath="$configroot/containers/seccomp.json"
        sed -i 's|^\s*#\?\s*\(seccomp_profile\s*=\s*\).*$|\1"'"$seccompconfpath"'"|' "$containersconfpath" >&2
    fi
    sed -i 's|^\s*#\?\s*\(init_path\s*=\s*\).*$|\1"'"$APPDIR/usr/libexec/podman/catatonit"'"|' "$containersconfpath" >&2
    sed -i '/^\s*#\?\s*conmon_path\s*=/,/\]/{s|"/tmp/\.mount_[^"]*",\?||;Tx;s|^\s*#\?\s*$||;Tx;d;:x;s|^\s*#||;s|\[|[\n  "'"$APPDIR/usr/bin/conmon"'",|}' "$containersconfpath" >&2
    sed -i '/^\s*#\?\s*helper_binaries_dir\s*=/,/\]/{s|"/tmp/\.mount_[^"]*",\?||;Tx;s|^\s*#\?\s*$||;Tx;d;:x;s|^\s*#||;s|\[|[\n  "'"$APPDIR/usr/libexec/podman"'",|}' "$containersconfpath" >&2
    sed -i '/^\s*#\?\s*crun\s*=/,/\]/{s|"/tmp/\.mount_[^"]*",\?||;Tx;s|^\s*#\?\s*$||;Tx;d;:x;s|^\s*#||;s|\[|[\n  "'"$APPDIR/usr/bin/crun.static"'",|}' "$containersconfpath" >&2

    registriesconfpath="$configroot/containers/registries.conf"
    if [ ! -f "$registriesconfpath" ]
    then
        mkdir -p "$(dirname "$registriesconfpath")" >&2
        cp "$APPDIR/etc/containers/registries.conf" "$registriesconfpath" >&2
        sed -i 's/^\s*#\?\s*\(unqualified-search-registries\s*=\s*\).*$/\1["docker.io"]/' "$registriesconfpath" >&2
    fi

    tar -cf - -C "$APPDIR/etc/containers" . | tar -xf - --skip-old-files -C "$configroot/containers"
}

root_setup() {
    conf_setup '/etc' '/var/lib' '/run'
}

rootless_setup() {
    asroot=''
    if [ "$(lsb_release -is)" == "SteamOS" ]
    then
        uuccommand(){
            sysctl -n kernel.unprivileged_userns_clone -e >&2 || echo 1
        }
    else
        uuccommand(){
            sysctl -n kernel.unprivileged_userns_clone >&2 || echo 1
        }
    fi
    if [ "$(uuccommand)" -ne 1 ]
    then
        echo "WARNING: kernel.unprivileged_userns_clone not set to 1." >&2
        asroot="${asroot}sysctl kernel.unprivileged_userns_clone=1\n"
    fi
    for f in /etc/subuid /etc/subgid
    do
        if [ ! -f "$f" ]
        then
            echo "WARNING: '$f' missing for rootless mode." >&2
            asroot="${asroot}touch '$f'\n"
            asroot="${asroot}chmod 644 '$f'\n"
            asroot="${asroot}echo '$(id -u -n):100000:65536' >> '$f'\n"
        elif ! grep -q "^$(id -u -n):" "$f"
        then
            echo "WARNING: '$f' not set up for '$(id -u -n)'." >&2
             maxid=0
            while read -r line
            do
                s="${line#*:}"
                s="${s%%:*}"
                e="${line##*:}"
                cmaxid=$((s+e))
                if [ "$cmaxid" -gt "$maxid" ]
                then
                    maxid="$cmaxid"
                fi
            done <"$f"
            l="$(printf '%s:%s%0*d:65536' "$(id -u -n)" "$(($(printf '%.1s' "$maxid")+1))" "$((${#maxid}-1))" 0)"
            asroot="${asroot}echo '$l' >> '$f'\n"
        fi
    done
    if [ "${#asroot}" -gt 0 ]
    then
        printf 'Do you want to fix these issues as root ? (Y/n): ' >&2
        read -r resp
        if [ -z "$resp" ] || [ "$resp" = 'Y' ] || [ "$resp" = 'y' ] || [ "$resp" = '1' ]
        then
            # shellcheck disable=SC2059
            printf "$asroot" | while read -r line
            do
                printf "echo '=> %s' >&2\n" "$line"
                printf '%s\n' "$line"
            done | { sudo sh || exit "$?"; }
        fi
    fi

    conf_setup \
        "${XDG_CONFIG_HOME:-${HOME:?}/.config}" \
        "${XDG_DATA_HOME:-${HOME:?}/.local/share}" \
        "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
}

if [ "$(id -u)" -ne 0 ]
then
    lockfile="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/podman-appimage.lock"
else
    lockfile='/run/podman-appimage.lock'
fi
exec 4<>"$lockfile"
if flock -n 4
then
    echo "$APPDIR" > "$lockfile"
    if [ "$(id -u)" -ne 0 ]
    then
        rootless_setup
    else
        root_setup
    fi
fi

exe="$(basename "$ARGV0")"
if PATH="$APPDIR/usr/bin" command -v "$exe" >/dev/null >&2
then
    "$exe" "$@"
else
    podman-shell "$@"
fi
exit "$?"
