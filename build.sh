#!/bin/bash
set -eu
podman run --device=/dev/fuse --cap-add SYS_ADMIN --tmpfs /tmp:exec -v ./:/tmp/out --rm -ti centos:8 /tmp/out/centos8-build.sh |& tee build.log