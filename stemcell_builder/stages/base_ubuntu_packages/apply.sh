#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

debs="libssl-dev lsof strace bind9-host dnsutils tcpdump iputils-arping \
curl wget libcurl3 libcurl3-dev bison libreadline6-dev \
libxml2 libxml2-dev libxslt1.1 libxslt1-dev zip unzip \
nfs-common flex psmisc apparmor-utils iptables sysstat \
rsync openssh-server traceroute libncurses5-dev quota \
libaio1 gdb libcap2-bin libcap2-dev libbz2-dev \
cmake uuid-dev libgcrypt-dev ca-certificates \
scsitools mg htop module-assistant debhelper runit parted \
cloud-guest-utils anacron software-properties-common \
xfsprogs"

if is_ppc64le; then
  debs="$debs \
libreadline-dev libtool texinfo ppc64-diag libffi-dev \
libruby bundler libgmp-dev libgmp3-dev libmpfr-dev libmpc-dev"
fi

pkg_mgr install $debs

  run_in_chroot $chroot "
    cd /tmp

    wget https://s3.amazonaws.com/bosh-dependencies/rsyslog-8.22.0-0adiscon1trusty1/libgt0_0.3.11-0adiscon4trusty1_amd64.deb
    echo 'ade96cdbe2cd922b63ef8329fc0531323453a410bfae1685657abfcd9c704ae0  libgt0_0.3.11-0adiscon4trusty1_amd64.deb' | shasum -a 256 -c -

    wget https://s3.amazonaws.com/bosh-dependencies/rsyslog-8.22.0-0adiscon1trusty1/libestr0_0.1.10-0adiscon1trusty1_amd64.deb
    echo 'c6cfea557f40a6ab6c558691782a420607961b6981d84752a4ce8dbaba17c4e5  libestr0_0.1.10-0adiscon1trusty1_amd64.deb' | shasum -a 256 -c -

    wget https://s3.amazonaws.com/bosh-dependencies/rsyslog-8.22.0-0adiscon1trusty1/libfastjson4_0.99.4-adiscon1trusty1_amd64.deb
    echo '3eae5ec93d1d7301b293a98ce7997ccbc5678a793de277ff1e3c7741e0d11cfc  libfastjson4_0.99.4-adiscon1trusty1_amd64.deb' | shasum -a 256 -c -

    wget https://s3.amazonaws.com/bosh-dependencies/rsyslog-8.22.0-0adiscon1trusty1/liblogging-stdlog1_1.0.5-0adiscon1trusty1_amd64.deb
    echo '1ce434d56e3c3ee39090f478cd7f3bde86e6868bd9800beb84b99903def90fe9  liblogging-stdlog1_1.0.5-0adiscon1trusty1_amd64.deb' | shasum -a 256 -c -

    wget https://s3.amazonaws.com/bosh-dependencies/rsyslog-8.22.0-0adiscon1trusty1/liblognorm5_2.0.1-1adiscon3trusty1_amd64.deb
    echo 'a943bb7951bdea36a8158e4ba6f77f921d760afc41ddb41ea10e58f7e2b517c5  liblognorm5_2.0.1-1adiscon3trusty1_amd64.deb' | shasum -a 256 -c -

    wget https://s3.amazonaws.com/bosh-dependencies/rsyslog-8.22.0-0adiscon1trusty1/librelp0_1.2.12-0adiscon2trusty1_amd64.deb
    echo '1bc0e85d0b23b8853495fad9bb966985c67a088eff6408c1b3a62f59c3fd2725  librelp0_1.2.12-0adiscon2trusty1_amd64.deb' | shasum -a 256 -c -

    wget https://s3.amazonaws.com/bosh-dependencies/rsyslog-8.22.0-0adiscon1trusty1/rsyslog_8.22.0-0adiscon1trusty1_amd64.deb
    echo 'e616e812ec7fc11aa1309daef68165db22d81cbff8f0ac16913abc72656ce2a0  rsyslog_8.22.0-0adiscon1trusty1_amd64.deb' | shasum -a 256 -c -

    wget https://s3.amazonaws.com/bosh-dependencies/rsyslog-8.22.0-0adiscon1trusty1/rsyslog-gnutls_8.22.0-0adiscon1trusty1_amd64.deb
    echo '8b42b52181f00577f36ad8d1b2d5267972ffbf86af0a52bea90bda2679c8eb06  rsyslog-gnutls_8.22.0-0adiscon1trusty1_amd64.deb' | shasum -a 256 -c -

    wget https://s3.amazonaws.com/bosh-dependencies/rsyslog-8.22.0-0adiscon1trusty1/rsyslog-mmjsonparse_8.22.0-0adiscon1trusty1_amd64.deb
    echo '5193fdc4d5b3a28d0cfacc9e581b06f5c28ae92f0afbfc93e5527361cf94faaa  rsyslog-mmjsonparse_8.22.0-0adiscon1trusty1_amd64.deb' | shasum -a 256 -c -

    wget https://s3.amazonaws.com/bosh-dependencies/rsyslog-8.22.0-0adiscon1trusty1/rsyslog-relp_8.22.0-0adiscon1trusty1_amd64.deb
    echo '8b7f68efc0bf69e5f5a5fc4e19feb15edea875be3f8d8f0fc8a306dde6bf8777  rsyslog-relp_8.22.0-0adiscon1trusty1_amd64.deb' | shasum -a 256 -c -

    dpkg -i libgt0_0.3.11-0adiscon4trusty1_amd64.deb \
      libestr0_0.1.10-0adiscon1trusty1_amd64.deb \
      libfastjson4_0.99.4-adiscon1trusty1_amd64.deb \
      liblogging-stdlog1_1.0.5-0adiscon1trusty1_amd64.deb \
      liblognorm5_2.0.1-1adiscon3trusty1_amd64.deb \
      librelp0_1.2.12-0adiscon2trusty1_amd64.deb \
      rsyslog_8.22.0-0adiscon1trusty1_amd64.deb \
      rsyslog-gnutls_8.22.0-0adiscon1trusty1_amd64.deb \
      rsyslog-mmjsonparse_8.22.0-0adiscon1trusty1_amd64.deb \
      rsyslog-relp_8.22.0-0adiscon1trusty1_amd64.deb

    rm *.deb
  "

exclusions="postfix"
pkg_mgr purge --auto-remove $exclusions
