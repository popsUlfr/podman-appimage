<img src="https://raw.githubusercontent.com/containers/common/main/logos/podman-logo-full-vert.png" height="200" />

# Podman-AppImage: A portable tool for managing OCI containers and pods

This is a portable [AppImage](https://appimage.org/) for [podman](https://podman.io/).

This project is intended to reduce the burden to access podman on platforms where it may not be available (e.g. [SteamOS 3.x](https://help.steampowered.com/en/faqs/view/1b71-edf2-eb6d-2bb3)), which is used on Valve's [Steam Deck](https://www.steamdeck.com/).

It should also work as portable Podman solution on other Linux distributions.

The AppImage's entrypoint will perform the necessary steps to setup a working [Rootless](https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md) environment. The user will be prompted for root during the first run to complete some necessary setup steps. If needed, can also be used in **Rootful mode**.

## Releases

Check the [Releases](https://github.com/popsUlfr/podman-appimage/releases) section for the latest builds.

## Basic Usage

By default, launching the AppImage will open a `podman-shell` session:

![](assets/Screenshot_20220908_211807.png)

See the following resource for more details about the various [podman commands](https://docs.podman.io/en/latest/Commands.html).

You can rename the AppImage or create a symlink to it and refer to the binary name to access a specific binary e.g. podman.

For example, access podman directly without using `podman-shell` by creating the following symlink:

```sh
ln -s podman-*.AppImage podman
```

Noww invoke `podman` directly:

```sh
./podman info
```

```sh
./podman run quay.io/podman/hello
```

The Podman AppImage includes the following binaries:

```
btrfs            btrfs-image      catatonit         criu                  podman           btrfsck          btrfs-map-logical compel                  fsck.btrfs       podman-remote    btrfs-convert     btrfs-select-super  conmon           crun             fuse-overlayfs    podman-shell     btrfs-find-root  btrfstune        crit              crun-static
mkfs.btrfs       slirp4netns      docker            criu-ns
```

The AppImage contents can be extracted to a directory using the following command:

```sh
./podman-*.AppImage --appimage-extract
```

## Build

To build, install `podman` from your package manager, clone this repo and then simply run the build script:

```sh
./build.sh
```

Once it's done building, a `podman-*.AppImage` will be found in the same directory.

CentOS Stream 8 is used as base for building.

## Credits

- [Arch Linux](https://archlinux.org/): for providing the build recipes for the packages and the wiki resources
- [CentOS Project](https://www.centos.org/): for providing the image used to build podman and it's depedencies from source
- [podman](https://github.com/containers/podman): for being an awesome daemonless container tool
- [AppImage](https://appimage.org/): for being a very neat portable packaging solution
