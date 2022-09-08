# Podman appimage

This is a portable [AppImage](https://appimage.org/) for [podman](https://podman.io/).

This project was mostly created to ease the access to podman on platforms where it's not straightforward to get it from the package manager (e.g.: read-only rootfs) like [SteamOS](https://help.steampowered.com/en/faqs/view/1b71-edf2-eb6d-2bb3) used on Valve's [Steam Deck](https://www.steamdeck.com/).

But it should also work as portable podman solution in any other environment.

The AppImage's entrypoint does the necessary setup to get a working environment and should generally be used in [rootless](https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md) mode (the user will be prompted for root access for the first time setup to configure the necessary files to get a working rootless mode). **root mode** does work too if really needed.

<img src="https://raw.githubusercontent.com/containers/common/main/logos/podman-logo-full-vert.png" height="200" />

## Releases

Head on over to the [Releases](https://github.com/popsUlfr/podman-appimage/releases) for the latest builds.

## Usage

By default launching the AppImage will open a `podman-shell` session:

![](data/Screenshot_20220908_211807.png)

In it you have access to the various podman commands: https://docs.podman.io/en/latest/Commands.html

You can also rename the appimage or more practically, create a symlink to it to quickly access a specific binary.

For instance to access podman directly without going through the `podman-shell` you can do the following:
```sh
ln -s podman-*.AppImage podman
```
And invoke `podman` directly:
```sh
./podman info
```
The AppImage currently includes the following binaries:
```
btrfs            btrfs-image         catatonit  criu         docker          podman
btrfsck          btrfs-map-logical   compel     criu-ns      fsck.btrfs      podman-remote
btrfs-convert    btrfs-select-super  conmon     crun         fuse-overlayfs  podman-shell
btrfs-find-root  btrfstune           crit       crun.static  mkfs.btrfs      slirp4netns
```

## Build

Install `podman` through your package manager and then simply run:
```sh
./build.sh
```

A `podman-*.AppImage` will created in the current folder.

CentOS 8 is used as base for building. At first CentOS 7 was considered but the systemd version was too old to build the most recent podman version and dependencies.

## Credits

- [Arch Linux](https://archlinux.org/) for providing the build recipes for the packages and the wiki ressources
- [podman](https://github.com/containers/podman) for being an awesome container tool
- [AppImage](https://appimage.org/) for being a very neat portable packaging solution