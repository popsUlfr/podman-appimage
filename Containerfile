FROM quay.io/centos/centos:stream8

RUN dnf -y --exclude=tzdata\* upgrade --refresh \
  && dnf clean all \
  && dnf -y install dnf-plugins-core epel-release \
  && dnf config-manager --set-enabled powertools \
  && dnf -y install $(<packages)
