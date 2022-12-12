#!/usr/bin/env bash
set -eux

TEMP_BASE=/tmp
BUILD_DIR="$(mktemp -d --tmpdir="$TEMP_BASE" appimage-build-XXXXXX)"
OUT_DIR="$TEMP_BASE/out"

# make sure to clean up build dir, even if errors occur
_cleanup() {
    if [[ -d "$BUILD_DIR" ]]; then
        rm -rf "$BUILD_DIR"
    fi
}
trap _cleanup EXIT

cd "$BUILD_DIR"
# The following is for centos:stream8
# https://podman.io/getting-started/installation#building-from-scratch
dnf -y --exclude=tzdata\* upgrade --refresh \
    && dnf clean all
dnf -y install dnf-plugins-core epel-release
dnf config-manager --set-enabled powertools
dnf -y install \
    autoconf \
    automake \
    binutils \
    bison \
    flex \
    gcc \
    gcc-c++ \
    gettext \
    libtool \
    make \
    patch \
    pkgconf-pkg-config \
    golang \
    cargo \
    glib2 \
    glib2-devel \
    git \
    libgit2 \
    libgit2-devel \
    yajl \
    yajl-devel \
    systemd \
    systemd-libs \
    systemd-devel \
    libcap \
    libcap-devel \
    libseccomp \
    libseccomp-devel \
    libselinux-devel \
    python3 \
    python3-devel \
    libslirp \
    libslirp-devel \
    device-mapper-devel \
    device-mapper-libs \
    gpgme \
    gpgme-devel \
    libgpg-error-devel \
    libassuan \
    libassuan-devel \
    e2fsprogs-libs \
    e2fsprogs-devel \
    libblkid \
    libblkid-devel \
    zstd \
    libzstd \
    libzstd-devel \
    lzo \
    lzo-devel \
    fuse-libs \
    libbsd \
    libbsd-devel \
    libnet \
    libnet-devel \
    libnl3 \
    libnl3-devel \
    protobuf \
    protobuf-devel \
    protobuf-c \
    protobuf-c-devel \
    python3-protobuf \
    gnutls \
    gnutls-devel \
    nftables \
    nftables-devel \
    asciidoc \
    xmlto \
    fuse3-libs \
    fuse3-devel \
    which \
    file \
    xz

# Fail early if these depedencies are not available
curl -sSLo linuxdeploy-x86_64.AppImage https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage \
    && chmod +x linuxdeploy-x86_64.AppImage
curl -sSLo linuxdeploy-plugin-appimage-x86_64.AppImage https://github.com/linuxdeploy/linuxdeploy-plugin-appimage/releases/download/continuous/linuxdeploy-plugin-appimage-x86_64.AppImage \
    && chmod +x linuxdeploy-plugin-appimage-x86_64.AppImage

# Source the default compiler flags
# Arch Linux flags
CFLAGS="-march=x86-64 -mtune=generic -O2 -pipe -fno-plt -fexceptions -Wp,-D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security -fstack-clash-protection -fcf-protection $(rpm --eval "%{optflags}")"
export CFLAGS
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-Wl,-O1,--sort-common,--as-needed,-z,relro,-z,now"
export RUSTFLAGS="-C opt-level=2"
export PKG_CONFIG_PATH="${PKG_CONFIG_PATH:-}:/usr/lib/pkgconfig:/usr/lib64/pkgconfig"
MAKEFLAGS="-j $(nproc)"
export MAKEFLAGS
export real_pkgdir=/
export pkgdir="$BUILD_DIR/out"

mkdir -p "$pkgdir/usr/lib"
ln -s lib "$pkgdir/usr/lib64"
mkdir -p "$pkgdir/usr/bin"
ln -s bin "$pkgdir/usr/sbin"

cp_to_real_pkgdir() {
    cp -aunv "$pkgdir/." "$real_pkgdir"
}

clean_pkgdir() {
    find "$pkgdir"  \
        \( \( \( -type f -or -type l \) -and \
            -name '*.a' -or \
            -name '*.la' -or \
            -name '*.pc' -or \
            -name '*.h' \) -or \
        \( -type d -and \
            \( -name 'man' -or \
                -name 'doc' -or \
                -name 'info' -or \
                -name 'include' -or \
                -name 'pkgconfig' -or \
                -name 'python*' \) \) \) \
        -exec rm -rf '{}' +
}

# criu
# https://github.com/archlinux/svntogit-community/blob/packages/criu/trunk/PKGBUILD
echo "Building criu..."
(
    pkgname=criu
    pkgver=3.17.1
    _commit='d46f40f4ff0c724e0b9f0f8a2e8c043806897e94'
    # depends=( libbsd libnet libnl protobuf-c python-protobuf gnutls nftables )
    # makedepends=( git xmlto asciidoc )

    git clone 'https://github.com/checkpoint-restore/criu.git' "$pkgname"
    cd "$pkgname"
    git checkout "$_commit"

    CFLAGS="$(sed 's/\S*_FORTIFY_SOURCE\S*//' <<<"${CFLAGS:-}")"
    export CFLAGS
    export CXXFLAGS="$CFLAGS"

    make
    make \
        DESTDIR="$pkgdir" \
        PREFIX=/usr \
        SBINDIR=/usr/bin \
        LIBDIR=/usr/lib \
        LIBEXECDIR=/usr/libexec \
        install
)
echo "Building criu done."
cp_to_real_pkgdir
ldconfig

# catatonit
# https://github.com/archlinux/svntogit-community/blob/packages/catatonit/trunk/PKGBUILD
echo "Building catatonit..."
(
    pkgname=catatonit
    pkgver=0.1.7

    curl -sSLo "$pkgname-$pkgver.tar.xz" "https://github.com/openSUSE/catatonit/releases/download/v$pkgver/$pkgname.tar.xz"
    echo "6ea6cb8c7feeca2cf101e7f794dab6eeb192cde177ecc7714d2939655d3d8997 $pkgname-$pkgver.tar.xz" > "$pkgname-$pkgver.tar.xz.sha256"
    sha256sum -c "$pkgname-$pkgver.tar.xz.sha256"

    curl -sSLo "$pkgname-$pkgver-autoconf.patch" 'https://github.com/openSUSE/catatonit/commit/99bb9048f532257f3a2c3856cfa19fe957ab6cec.patch'
    echo "93e0429aa58cecea6cf2a8727bcc53e6eca90da63305a24c4f826b5e31c90d1a $pkgname-$pkgver-autoconf.patch" > "$pkgname-$pkgver-autoconf.patch.sha256"
    sha256sum -c "$pkgname-$pkgver-autoconf.patch.sha256"

    test -f "$pkgname-$pkgver.tar.xz" && tar -xf "$pkgname-$pkgver.tar.xz"
    cd "$pkgname-$pkgver"

    patch -Np1 -i "../$pkgname-$pkgver-autoconf.patch"
    autoreconf -fiv
    ./configure --prefix=/usr
    make V=1
    make PREFIX=/usr DESTDIR="$pkgdir" install

    install -vdm 755 "$pkgdir/usr/libexec/podman/"
    ln -sv "../../bin/$pkgname" "$pkgdir/usr/libexec/podman/"
)
echo "Building catatonit done."
cp_to_real_pkgdir
ldconfig

# conmon
# https://github.com/archlinux/svntogit-community/blob/packages/conmon/trunk/PKGBUILD
echo "Building conmon..."
(
    pkgname=conmon
    pkgver=2.1.5
    # refs/tags/v2.1.5
    _commit=c9f7f19eb82d5b8151fc3ba7fbbccf03fdcd0325

    git clone 'https://github.com/containers/conmon.git' "$pkgname"
    cd "$pkgname"
    git checkout "$_commit"

    CFLAGS="$CFLAGS -std=c99"
    export CFLAGS
    make PREFIX=/usr LIBEXECDIR=/usr/libexec DESTDIR="$pkgdir"

    install -vDm755 bin/conmon "$pkgdir/usr/bin/conmon"
)
echo "Building conmon done."
cp_to_real_pkgdir
ldconfig

# netavark
# https://github.com/archlinux/svntogit-community/blob/packages/netavark/trunk/PKGBUILD
echo "Building netavark..."
(
    pkgname=netavark
    pkgver=1.4.0
    # refs/tags/v1.4.0^{}
    _commit=c2a4b9abd47cac389a95301a94ae7c5d7f7d1573

    git clone 'https://github.com/containers/netavark.git' "$pkgname"
    cd "$pkgname"
    git checkout "$_commit"

    cargo fetch --locked

    export RUSTUP_TOOLCHAIN=stable
    export CARGO_TARGET_DIR=target

    cargo build --frozen --release --all-features

    install -vdm 755 "$pkgdir/usr/libexec/podman/"
    install -vDm 755 "target/release/$pkgname" -t "$pkgdir/usr/libexec/podman/"
)
echo "Building netavark done."
cp_to_real_pkgdir
ldconfig

#  aardvark-dns
# https://github.com/archlinux/svntogit-community/blob/packages/netavark/trunk/PKGBUILD
echo "Building aardvark-dns..."
(
    pkgname=aardvark-dns
    pkgver=1.4.0
    # refs/tags/v1.4.0^{}
    _commit=65b98046024491f27e056788cba2002833684359

    git clone 'https://github.com/containers/aardvark-dns.git' "$pkgname"
    cd "$pkgname"
    git checkout "$_commit"

    cargo fetch --locked

    export RUSTUP_TOOLCHAIN=stable
    export CARGO_TARGET_DIR=target

    cargo build --frozen --release --all-features

    install -vdm 755 "$pkgdir/usr/libexec/podman/"
    install -vDm 755 "target/release/$pkgname" -t "$pkgdir/usr/libexec/podman/"
)
echo "Building aardvark-dns done."
cp_to_real_pkgdir
ldconfig

# containers-common
# https://github.com/archlinux/svntogit-community/blob/packages/containers-common/trunk/PKGBUILD
echo "Building containers-common..."
(
    pkgname=containers-common
    pkgver=0.49.2
    _image_pkgver=5.23.1
    _podman_pkgver=4.3.1
    _shortnames_pkgver=2022.02.08
    _skopeo_pkgver=1.9.3
    _storage_pkgver=1.44.0

    curl -sSLo "common-$pkgver.tar.gz" "https://github.com/containers/common/archive/v$pkgver.tar.gz"
    echo "2744a3490f5286a94fd00f31322ef0fd0338456e39cbd03f8a97b75f9ee9aec10f61b0ea69ea2afd5c216885ce1665cd78a97cc4723211e0424efa4151d51463 common-$pkgver.tar.gz" > "common-$pkgver.tar.gz.sha512"
    sha512sum -c "common-$pkgver.tar.gz.sha512"

    curl -sSLo "image-$_image_pkgver.tar.gz" "https://github.com/containers/image/archive/v$_image_pkgver.tar.gz"
    echo "559fda1addb342aa049500e118df840ed299a985cd08c9ad3103931fb5afe967b4949c47d91a0483ae328d8eaeed4f855d2d9c3ec9e31cdaf35e2f555f7f19ac image-$_image_pkgver.tar.gz" > "image-$_image_pkgver.tar.gz.sha512"
    sha512sum -c "image-$_image_pkgver.tar.gz.sha512"

    curl -sSLo "podman-$_podman_pkgver.tar.gz" "https://github.com/containers/podman/archive/v$_podman_pkgver.tar.gz"
    echo "907dafc6481cbcb7a9b6771c3682a88d6c3b055050c0a180f9ceb985c1a3826318056b62dd6d2859a2a23eba7aad4bf26404327d5479bde98658745fa7d88efa podman-$_podman_pkgver.tar.gz" > "podman-$_podman_pkgver.tar.gz.sha512"
    sha512sum -c "podman-$_podman_pkgver.tar.gz.sha512"

    curl -sSLo "skopeo-$_skopeo_pkgver.tar.gz" "https://github.com/containers/skopeo/archive/v$_skopeo_pkgver.tar.gz"
    echo "108a015bdd62f03210686838e5960e0bf4cbbe7a4f63f0fe3de67f9f6b1faad68568b78aafae4034e5ec33d28770eb10fd6d30f364fabe7d654c572eb1003417 skopeo-$_skopeo_pkgver.tar.gz" > "skopeo-$_skopeo_pkgver.tar.gz.sha512"
    sha512sum -c "skopeo-$_skopeo_pkgver.tar.gz.sha512"

    curl -sSLo "storage-$_storage_pkgver.tar.gz" "https://github.com/containers/storage/archive/v$_storage_pkgver.tar.gz"
    echo "5256d376e944fe781d927362156fdb1c42db1c175de98ceb461599fc19738d312fc2eb4ad3e179477f12a8435939385c965607960c6a2128775d9ddbfd730db4 storage-$_storage_pkgver.tar.gz" > "storage-$_storage_pkgver.tar.gz.sha512"
    sha512sum -c "storage-$_storage_pkgver.tar.gz.sha512"

    curl -sSLo "shortnames-$_shortnames_pkgver.tar.gz" "https://github.com/containers/shortnames/archive/refs/tags/v$_shortnames_pkgver.tar.gz"
    echo "d0f72ad6f86cc1bcb0f02d9c29d3a982c541679098e417410c8f1a3df42550753e4f491efdec09dc02fe3ab4e3f5d8971c8ab9e964293e6b4e1f1261191b3501 shortnames-$_shortnames_pkgver.tar.gz" > "shortnames-$_shortnames_pkgver.tar.gz.sha512"
    sha512sum -c "shortnames-$_shortnames_pkgver.tar.gz.sha512"

    curl -sSLo "mounts.conf" "https://raw.githubusercontent.com/archlinux/svntogit-community/packages/containers-common/trunk/mounts.conf"
    echo "11fa515bbb0686d2b49c4fd2ab35348cb19f9c6780d6eb951a33b07ed7b7c72a676627f36e8c74e1a2d15e306d4537178f0e127fd3490f6131d078e56b46d5e1 mounts.conf" > "mounts.conf.sha512"
    sha512sum -c "mounts.conf.sha512"

    # Podman container directories
    install -vdm 755 "$pkgdir/etc/containers/oci/hooks.d/"
    install -vdm 755 "$pkgdir/etc/containers/registries.conf.d/"
    install -vdm 755 "$pkgdir/etc/containers/registries.d/"
    install -vdm 755 "$pkgdir/usr/share/containers/oci/hooks.d/"
    install -vdm 755 "$pkgdir/var/lib/containers/"

    # Podman container configs
    install -vDm 644 mounts.conf -t "$pkgdir/etc/containers/"

    (
        tar -xf "common-$pkgver.tar.gz" \
          && cd "common-$pkgver"

        # configs
        install -vDm 644 pkg/config/containers.conf -t "$pkgdir/etc/containers/"
        install -vDm 644 pkg/config/containers.conf -t "$pkgdir/usr/share/containers/"
        install -vDm 644 pkg/seccomp/seccomp.json -t "$pkgdir/etc/containers/"
        install -vDm 644 pkg/seccomp/seccomp.json -t "$pkgdir/usr/share/containers/"
    )

    (
        tar -xf "image-$_image_pkgver.tar.gz" \
          && cd "image-$_image_pkgver"

        # configs
        install -vDm 644 registries.conf -t "$pkgdir/etc/containers/"
    )

    (
        tar -xf "shortnames-$_shortnames_pkgver.tar.gz" \
          && cd "shortnames-$_shortnames_pkgver"

        # configs
        install -vDm 644 shortnames.conf "$pkgdir/etc/containers/registries.conf.d/00-shortnames.conf"
    )

    (
        tar -xf "skopeo-$_skopeo_pkgver.tar.gz" \
          && cd "skopeo-$_skopeo_pkgver"

        # configs
        install -vDm 644 default-policy.json "$pkgdir/etc/containers/policy.json"
        install -vDm 644 default.yaml -t "$pkgdir/etc/containers/registries.d/"
    )

    (
        tar -xf "storage-$_storage_pkgver.tar.gz" \
          && cd "storage-$_storage_pkgver"

        # configs
        install -vDm 644 storage.conf -t "$pkgdir/etc/containers/"
        install -vDm 644 storage.conf -t "$pkgdir/usr/share/containers/"
    )
)
echo "Building containers-common done."
cp_to_real_pkgdir
ldconfig

# crun
# https://github.com/archlinux/svntogit-community/blob/packages/crun/trunk/PKGBUILD
echo "Building crun..."
(
    pkgname=crun
    pkgver=1.7.2

    curl -sSLo "$pkgname-static" "https://github.com/containers/crun/releases/download/${pkgver}/${pkgname}-${pkgver}-linux-amd64"
    echo "2bd2640d43bc78be598e0e09dd5bb11631973fc79829c1b738b9a1d73fdc7997 crun-static" > "$pkgname-static.sha256"
    sha256sum -c "$pkgname-static.sha256"
    chmod +x "$pkgname-static"
    mkdir -p "$pkgdir/usr/bin"
    cp "$pkgname-static" "$pkgdir/usr/bin/crun-static"

    curl -sSLo "$pkgname-$pkgver.tar.xz" "https://github.com/containers/crun/releases/download/$pkgver/$pkgname-$pkgver.tar.xz"
    echo "dfce0fdf042c7de84e8672369f54f723c2f788d2bde076a4c6edf530e6306b5a $pkgname-$pkgver.tar.xz" > "$pkgname-$pkgver.tar.xz.sha256"
    sha256sum -c "$pkgname-$pkgver.tar.xz.sha256"

    tar -xf "$pkgname-$pkgver.tar.xz"
    cd "${pkgname}-${pkgver}"

    ./autogen.sh
    ./configure \
        --prefix=/usr \
        --enable-shared \
        --enable-dynamic
    make
    make DESTDIR="$pkgdir" install
)
echo "Building crun done."
cp_to_real_pkgdir
ldconfig

# slirp4netns
# https://github.com/archlinux/svntogit-community/blob/packages/slirp4netns/trunk/PKGBUILD
echo "Building slirp4netns..."
(
    pkgname=slirp4netns
    pkgver=1.2.0
    # depends=(glibc glib2 libcap libseccomp libslirp)
    # makedepends=(git)
    # refs/tags/v1.2.0^{}
    _commit=656041d45cfca7a4176f6b7eed9e4fe6c11e8383

    git clone 'https://github.com/rootless-containers/slirp4netns.git' "$pkgname"
    cd "$pkgname"
    git checkout "$_commit"

    autoreconf -fi
    ./configure --prefix=/usr
    make
    make DESTDIR="$pkgdir" install
)
echo "Building slirp4netns done."
cp_to_real_pkgdir
ldconfig

# btrfs-progs
# https://github.com/archlinux/svntogit-packages/blob/packages/btrfs-progs/trunk/PKGBUILD
echo "Building btrfs-progs..."
(
    pkgname=btrfs-progs
    pkgver=5.19.1
    # depends=( glibc util-linux-libs lzo zlib zstd libgcrypt )
    # makedepends=( git asciidoc xmlto systemd python python-setuptools e2fsprogs reiserfsprogs python-sphinx )

    curl -sSLo "$pkgname-v$pkgver.tar.xz" "https://www.kernel.org/pub/linux/kernel/people/kdave/btrfs-progs/btrfs-progs-v$pkgver.tar.xz"
    echo "26429e540343ccc7f5d4b3f8f42b916713280e898c5471da705026ef6d2c10a6 $pkgname-v$pkgver.tar.xz" > "$pkgname-v$pkgver.tar.xz.sha256"
    sha256sum -c "$pkgname-v$pkgver.tar.xz.sha256"

    tar -xf "$pkgname-v$pkgver.tar.xz"
    cd "$pkgname-v$pkgver"

    ./configure --prefix=/usr --disable-documentation
    make
    make DESTDIR="$pkgdir" install
)
echo "Building btrfs-progs done."
cp_to_real_pkgdir
ldconfig

# fuse-overlayfs
# https://github.com/archlinux/svntogit-community/blob/packages/fuse-overlayfs/trunk/PKGBUILD
echo "Building fuse-overlayfs..."
(
    pkgname=fuse-overlayfs
    pkgver=1.10
    # depends=( fuse3 )
    # makedepends=( git )
    # refs/tags/v1.10^{}
    _commit=a1e8466e2c2b46593656481508c1cf65a853e4bd

    git clone 'https://github.com/containers/fuse-overlayfs.git' "${pkgname}"
    cd "${pkgname}"
    git checkout "$_commit"

    autoreconf -fis
	./configure \
	    --prefix=/usr \
	    --sbindir=/usr/bin
    make
    make DESTDIR="${pkgdir}" install
)
echo "Building fuse-overlayfs done."
cp_to_real_pkgdir
ldconfig

# Podman
# https://github.com/archlinux/svntogit-community/blob/packages/podman/trunk/PKGBUILD
echo "Building podman..."
(
    pkgbase=podman
    pkgver=4.3.1
    # makedepends=( apparmor btrfs-progs catatonit device-mapper go go-md2man git gpgme libseccomp systemd )
    # refs/tags/v4.3.1
    _commit=814b7b003cc630bf6ab188274706c383f9fb9915

    git clone 'https://github.com/containers/podman.git' "$pkgbase"
    cd "$pkgbase"
    git checkout "$_commit"

    export BUILDTAGS='selinux seccomp systemd'
    export CGO_CPPFLAGS="${CPPFLAGS:-}"
    export CGO_CFLAGS="${CFLAGS:-}"
    export CGO_CXXFLAGS="${CXXFLAGS:-}"
    export CGO_LDFLAGS="${LDFLAGS:-}"
    export GOFLAGS="-buildmode=pie -trimpath"

    make EXTRA_LDFLAGS='-s -w -linkmode=external'
    make install.bin install.remote install.systemd DESTDIR="$pkgdir" PREFIX=/usr LIBEXECDIR=/usr/libexec
    make -j1 install.docker DESTDIR="$pkgdir" PREFIX=/usr
)
echo "Building podman done."
cp_to_real_pkgdir
ldconfig

cp "$OUT_DIR/assets/linuxdeploy-plugin-podman.sh" "$OUT_DIR/assets/entrypoint.sh" .
cp "$OUT_DIR/assets/podman-shell" "$pkgdir/usr/bin"

clean_pkgdir

export OUTPUT="podman-4.3.1-x86_64.AppImage"
find "$pkgdir" -type f -executable \
    -exec sh -c 'file -b "$1" | grep -q "^ELF "' _ '{}' \; \
    -printf '--deploy-deps-only=%p\0' \
    -exec strip -s '{}' \; | xargs -0 ./linuxdeploy-x86_64.AppImage --appdir "$pkgdir" \
    --executable "$pkgdir/usr/bin/podman" \
    --desktop-file "$OUT_DIR/assets/podman.desktop" \
    --icon-file "$OUT_DIR/assets/podman.png" \
    --plugin podman \
    --output appimage
mv "$OUTPUT" "$OUT_DIR"
