#!/usr/bin/env /usr/bin/bash
# (c) 2022 Chris Coleman
# 
# To run this script:
# wget -O - https://github.com/chris001/CGNAThome/raw/main/start-tunnel.sh | bash
# 
# To install virtualmin, run this:
# https://github.com/virtualmin/virtualmin-install/raw/master/virtualmin-install.sh
#
# How to setup cf tunnel:
# https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/
#
# ssh into your linux localhost, e.g.:
# ssh 10.0.2.15
#
# This hello-world example relies on trycloudflare.com which does not require a Cloudflare account. 
# This is useful to getting started quickly with a single command.
#
# For real usage, get started by creating a free Cloudflare account and heading to 
# https://dash.teams.cloudflare.com/ -> Access -> Tunnels to create your first Tunnel. 
# There, you will get a single line command to start and run your cloudflared 
# docker container authenticating to your Cloudflare account.
#
# You can then use it to expose:
#
#    Private HTTP-based services exposed on a public DNS hostname, 
# optionally locked down by Cloudflare Access 
# (see https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/ 
# and https://developers.cloudflare.com/cloudflare-one/applications/configure-apps/self-hosted-apps/ )
#    Private networks accessed by TCP/UDP IP/port by WARP enrolled users, with a Zero Trust approach, 
# to squash away your legacy VPN 
# (see https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/private-net/ )

CLOUDFLARED_PACKAGE=cloudflared-linux-amd64.deb
CLOUDFLARED_URL=https://github.com/cloudflare/cloudflared/releases/latest/download/$CLOUDFLARED_PACKAGE
# my app virtualmin port is 10000
MY_APP_PORT=10000


install_prereq_if_not_already () {
  if ! command -v $1 > /dev/null; then
    sudo apt -y install $2
  fi
}

install_tunnel_package_if_not_already () {
  if ! command -v $1 > /dev/null; then
    wget $CLOUDFLARED_URL
    sudo dpkg -i $CLOUDFLARED_PACKAGE
    rm $CLOUDFLARED_PACKAGE
  fi
}

open_firewall_ports () {
  #sudo ufw allow ssh
  sudo ufw allow $MY_APP_PORT
  #sudo ufw enable
  #sudo ufw status
}

install_prereq_if_not_already wget wget
install_prereq_if_not_already ufw ufw
#install_prereq_if_not_already snap snapd

install_tunnel_package_if_not_already cloudflared

open_firewall_ports

cloudflared tunnel --url localhost:$MY_APP_PORT
