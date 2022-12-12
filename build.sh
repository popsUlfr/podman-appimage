#!/usr/bin/env bash
set -eu
# build.sh
IMAGE="quay.io/centos/centos:stream8"

podman run \
  --device=/dev/fuse \
  --cap-add=SYS_ADMIN \
  --tmpfs /tmp:exec \
  --tmpfs /run \
  -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
  -v ./:/tmp/out:z \
  --rm -ti \
  "${IMAGE}" /tmp/out/centos-stream-8-build.sh |& tee build.log
