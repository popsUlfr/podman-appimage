#!/bin/bash
set -eux

OUT_DIR="/tmp/out"

TEMP_BASE=/tmp
BUILD_DIR="$(mktemp -d -p "$TEMP_BASE" appimage-build-XXXXXX)"

# make sure to clean up build dir, even if errors occur
cleanup() {
    if [[ -d "$BUILD_DIR" ]]; then
        rm -rf "$BUILD_DIR"
    fi
}
#trap cleanup EXIT

cd "$BUILD_DIR"

# for a newer systemd
#curl -sSLo /etc/yum.repos.d/jsynacek-systemd-centos-7.repo \
#    'https://copr.fedorainfracloud.org/coprs/jsynacek/systemd-backports-for-centos-7/repo/epel-7/jsynacek-systemd-backports-for-centos-7-epel-7.repo'

# Following is for centos:8

dnf -y --disablerepo '*' --enablerepo extras swap centos-linux-repos centos-stream-repos
dnf -y distro-sync
dnf -y install dnf-plugins-core
dnf -y upgrade && dnf clean all
dnf -y install epel-release
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
    git \
    golang \
    cargo \
    glib2 \
    glib2-devel \
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
    python3 \
    python3-devel \
    libslirp \
    libslirp-devel \
    device-mapper-devel \
    device-mapper-libs \
    gpgme \
    gpgme-devel \
    libassuan \
    libassuan-devel \
    e2fsprogs-libs \
    e2fsprogs-devel \
    libblkid \
    libblkid-devel \
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
    fuse3-devel

# source the default compiler flags
# Arch Linux flags
export CFLAGS="-march=x86-64 -mtune=generic -O2 -pipe -fno-plt -fexceptions -Wp,-D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security -fstack-clash-protection -fcf-protection $(rpm --eval "%{optflags}")"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-Wl,-O1,--sort-common,--as-needed,-z,relro,-z,now"
export RUSTFLAGS="-C opt-level=2"
export PKG_CONFIG_PATH="${PKG_CONFIG_PATH:-}:/usr/lib/pkgconfig:/usr/lib64/pkgconfig"

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
    # depends=(
    # 'libbsd'
    # 'libnet'
    # 'libnl'
    # 'protobuf-c'
    # 'python-protobuf'
    # 'gnutls'
    # 'nftables'
    # )
    # makedepends=(
    # 'git'
    # 'xmlto'
    # 'asciidoc'
    # )

    git clone 'https://github.com/checkpoint-restore/criu.git' "$pkgname"
    cd "$pkgname"
    git checkout "$_commit"

    export CFLAGS="$(sed 's/\S*_FORTIFY_SOURCE\S*//' <<<"${CFLAGS:-}")"
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

    curl -sSLo "$pkgname-0.1.7-autoconf.patch" 'https://github.com/openSUSE/catatonit/commit/99bb9048f532257f3a2c3856cfa19fe957ab6cec.patch'
    echo "93e0429aa58cecea6cf2a8727bcc53e6eca90da63305a24c4f826b5e31c90d1a $pkgname-0.1.7-autoconf.patch" > "$pkgname-0.1.7-autoconf.patch.sha256"
    sha256sum -c "$pkgname-0.1.7-autoconf.patch.sha256"

    tar -xf "$pkgname-$pkgver.tar.xz"
    cd "$pkgname-$pkgver"

    patch -Np1 -i "../$pkgname-0.1.7-autoconf.patch"
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
    pkgver=2.1.4
    #refs/tags/v2.1.4
    _commit=bd1459a3ffbb13eb552cc9af213e1f56f31ba2ee

    git clone 'https://github.com/containers/conmon.git' "$pkgname"
    cd "$pkgname"
    git checkout "$_commit"

    export CFLAGS="$CFLAGS -std=c99"
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
    # refs/tags/v1.1.0^{}
    _commit=5d2b799537d080a82ed46725705cfcbcb36417f1
    pkgver=1.1.0

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

# containers-common
# https://github.com/archlinux/svntogit-community/blob/packages/containers-common/trunk/PKGBUILD
echo "Building containers-common..."
(
    pkgname=containers-common
    pkgver=0.49.1
    _image_pkgver=5.22.0
    _podman_pkgver=4.2.0
    _shortnames_pkgver=2022.02.08
    _skopeo_pkgver=1.9.2
    _storage_pkgver=1.42.0

    curl -sSLo "common-$pkgver.tar.gz" "https://github.com/containers/common/archive/v$pkgver.tar.gz"
    echo "c918c4ba3a5bdcb5164f4fe8b7fc949fc8ddec1a6819b42859383902f41b845d1989ed8abbdd272b812372116505a899e0d632a247f6b79a6e52c446e5a29fdd common-$pkgver.tar.gz" > "common-$pkgver.tar.gz.sha512"
    sha512sum -c "common-$pkgver.tar.gz.sha512"

    curl -sSLo "image-$_image_pkgver.tar.gz" "https://github.com/containers/image/archive/v$_image_pkgver.tar.gz"
    echo "1b286ddd527d47a11f57af74c8f171ae8ec129678bed8b12476737672655548a1218732b27152c80437f1367b1878f80144e569e77c01ff6c05d659f49bcf694 image-$_image_pkgver.tar.gz" > "image-$_image_pkgver.tar.gz.sha512"
    sha512sum -c "image-$_image_pkgver.tar.gz.sha512"

    curl -sSLo "podman-$_podman_pkgver.tar.gz" "https://github.com/containers/podman/archive/v$_podman_pkgver.tar.gz"
    echo "bc9e28d9938127f91be10ea8bc6c6f638a01d74d120efad5ad1e72c5f7b893685871e83872434745bc72ecaca430355b0f59d302660e8b4a53cc88a88cc37f9c podman-$_podman_pkgver.tar.gz" > "podman-$_podman_pkgver.tar.gz.sha512"
    sha512sum -c "podman-$_podman_pkgver.tar.gz.sha512"

    curl -sSLo "skopeo-$_skopeo_pkgver.tar.gz" "https://github.com/containers/skopeo/archive/v$_skopeo_pkgver.tar.gz"
    echo "8d9aad3a6190f0c9bdd85485423dc257408b27088300f8a891615bf47f3ef16e02035d69ea15a75a93f375e6e7ad465f90951725e4ee1509463f05447c7ce174 skopeo-$_skopeo_pkgver.tar.gz" > "skopeo-$_skopeo_pkgver.tar.gz.sha512"
    sha512sum -c "skopeo-$_skopeo_pkgver.tar.gz.sha512"

    curl -sSLo "storage-$_storage_pkgver.tar.gz" "https://github.com/containers/storage/archive/v$_storage_pkgver.tar.gz"
    echo "c8a4fdfbc71915dd3a1d5c1fabef4be7641b8a0edb14805719d93bc9de5bd8fe150636c4457fa544487a6bccbb0f58ad36ca3990d6ca3c2b73935418aaf98f22 storage-$_storage_pkgver.tar.gz" > "storage-$_storage_pkgver.tar.gz.sha512"
    sha512sum -c "storage-$_storage_pkgver.tar.gz.sha512"

    curl -sSLo "shortnames-$_shortnames_pkgver.tar.gz" "https://github.com/containers/shortnames/archive/refs/tags/v$_shortnames_pkgver.tar.gz"
    echo "d0f72ad6f86cc1bcb0f02d9c29d3a982c541679098e417410c8f1a3df42550753e4f491efdec09dc02fe3ab4e3f5d8971c8ab9e964293e6b4e1f1261191b3501 shortnames-$_shortnames_pkgver.tar.gz" > "shortnames-$_shortnames_pkgver.tar.gz.sha512"
    sha512sum -c "shortnames-$_shortnames_pkgver.tar.gz.sha512"

    curl -sSLo "mounts.conf" "https://raw.githubusercontent.com/archlinux/svntogit-community/packages/containers-common/trunk/mounts.conf"
    echo "11fa515bbb0686d2b49c4fd2ab35348cb19f9c6780d6eb951a33b07ed7b7c72a676627f36e8c74e1a2d15e306d4537178f0e127fd3490f6131d078e56b46d5e1 mounts.conf" > "mounts.conf.sha512"
    sha512sum -c "mounts.conf.sha512"

    # directories
    install -vdm 755 "$pkgdir/etc/containers/oci/hooks.d/"
    install -vdm 755 "$pkgdir/etc/containers/registries.conf.d/"
    install -vdm 755 "$pkgdir/etc/containers/registries.d/"
    install -vdm 755 "$pkgdir/usr/share/containers/oci/hooks.d/"
    install -vdm 755 "$pkgdir/var/lib/containers/"

    # configs
    install -vDm 644 mounts.conf -t "$pkgdir/etc/containers/"

    (
        tar -xf "common-$pkgver.tar.gz"
        cd "common-$pkgver"
        # configs
        install -vDm 644 pkg/config/containers.conf -t "$pkgdir/etc/containers/"
        install -vDm 644 pkg/config/containers.conf -t "$pkgdir/usr/share/containers/"
        install -vDm 644 pkg/seccomp/seccomp.json -t "$pkgdir/etc/containers/"
        install -vDm 644 pkg/seccomp/seccomp.json -t "$pkgdir/usr/share/containers/"
    )
    
    (
        tar -xf "image-$_image_pkgver.tar.gz"
        cd "image-$_image_pkgver"
        # configs
        install -vDm 644 registries.conf -t "$pkgdir/etc/containers/"
    )

    (
        tar -xf "shortnames-$_shortnames_pkgver.tar.gz"
        cd "shortnames-$_shortnames_pkgver"
        install -vDm 644 shortnames.conf "$pkgdir/etc/containers/registries.conf.d/00-shortnames.conf"
    )

    (
        tar -xf "skopeo-$_skopeo_pkgver.tar.gz"
        cd "skopeo-$_skopeo_pkgver"
        # configs
        install -vDm 644 default-policy.json "$pkgdir/etc/containers/policy.json"
        install -vDm 644 default.yaml -t "$pkgdir/etc/containers/registries.d/"
    )

    (
        tar -xf "storage-$_storage_pkgver.tar.gz"
        cd "storage-$_storage_pkgver"
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
    pkgver=1.6

    curl -sSLo crun.static "https://github.com/containers/crun/releases/download/${pkgver}/${pkgname}-${pkgver}-linux-amd64"
    echo "69ba74a05cc6147cf65e1bebb79e2adb8c96012eb3a701f5faa51869251cb2dc crun.static" > crun.static.sha256
    sha256sum -c crun.static.sha256
    chmod +x crun.static
    mkdir -p "$pkgdir/usr/bin"
    cp crun.static "$pkgdir/usr/bin/"

    curl -sSLo "$pkgname-$pkgver.tar.xz" "https://github.com/containers/crun/releases/download/$pkgver/$pkgname-$pkgver.tar.xz"
    echo "8ae387950f3f75aaff7fe9da14f2f012be842a8b20038bb8344a451197b40ee4 $pkgname-$pkgver.tar.xz" > "$pkgname-$pkgver.tar.xz.sha256"
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
    #refs/tags/v1.2.0^{}
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
    pkgver=5.19

    # makedepends=('git' 'asciidoc' 'xmlto' 'systemd' 'python' 'python-setuptools' 'e2fsprogs' 'reiserfsprogs' 'python-sphinx')
    # depends=('glibc' 'util-linux-libs' 'lzo' 'zlib' 'zstd' 'libgcrypt')

    curl -sSLo "$pkgname-v$pkgver.tar.xz" "https://www.kernel.org/pub/linux/kernel/people/kdave/btrfs-progs/btrfs-progs-v$pkgver.tar.xz"
    echo "1fbcf06e4b2f80e7a127fd687ed4625a5b74fa674fe212c836ff70e0edfcccf9 $pkgname-v$pkgver.tar.xz" > "$pkgname-v$pkgver.tar.xz.sha256"
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
    pkgver=1.9
    # depends=(fuse3)
    # makedepends=(git)
    #refs/tags/v1.9^{}
    _commit=51592ea406f48faeccab288f65dcba6c4a67cd90

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

# podman
# https://github.com/archlinux/svntogit-community/blob/packages/podman/trunk/PKGBUILD
echo "Building podman..."
(
    pkgbase=podman
    pkgver=4.2.1
    # refs/tags/v4.2.1
    _commit=09f7a954255a273c6c563d34de9cbde5a383ef9d
    # makedepends=(apparmor btrfs-progs catatonit device-mapper go go-md2man git gpgme libseccomp systemd)

    git clone 'https://github.com/containers/podman.git' "$pkgbase"
    cd "$pkgbase"
    git checkout "$_commit"

    export BUILDTAGS='seccomp systemd'
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

curl -sSLo linuxdeploy-x86_64.AppImage https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
chmod +x linuxdeploy-x86_64.AppImage
curl -sSLo linuxdeploy-plugin-appimage-x86_64.AppImage https://github.com/linuxdeploy/linuxdeploy-plugin-appimage/releases/download/continuous/linuxdeploy-plugin-appimage-x86_64.AppImage
chmod +x linuxdeploy-plugin-appimage-x86_64.AppImage

cp "$OUT_DIR/linuxdeploy-plugin-podman.sh" "$OUT_DIR/entrypoint.sh" .
cp "$OUT_DIR/podman-shell" "$pkgdir/usr/bin"

clean_pkgdir
export OUTPUT="podman-4.2.1-x86_64.AppImage"
find "$pkgdir" -type f -executable \
    -exec sh -c 'file -b "$1" | grep -q "^ELF "' _ '{}' \; \
    -printf '--deploy-deps-only=%p\0' \
    -exec strip -s '{}' \; | xargs -0 ./linuxdeploy-x86_64.AppImage --appdir "$pkgdir" \
    --executable "$pkgdir/usr/bin/podman" \
    --desktop-file "$OUT_DIR/podman.desktop" \
    --icon-file "$OUT_DIR/podman.png" \
    --plugin podman \
    --output appimage
mv "$OUTPUT" "$OUT_DIR"
