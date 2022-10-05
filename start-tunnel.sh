#!/usr/bin/env /usr/bin/bash
# (c) 2022 Chris Coleman
#
# Start a Cloudflare Quick Tunnel. Defaults to https on port 10000 the Virtualmin default port.
#
# To install Virtualmin in default settings, run:
# wget -q -O - https://github.com/virtualmin/virtualmin-install/raw/master/virtualmin-install.sh | bash
#
# To start a Quick Tunnel for your https localhost Virtualmin on default port 10000:
# wget -q -O - https://github.com/chris001/CGNAThome/raw/main/start-tunnel.sh | bash
# 
# How to setup a more permanent CF tunnel. Requires free CF account + your own domain name:
# https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/
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

# USAGE: ./start-tunnel.sh  # defaults to Quick Tunnel for https://localhost:MY_APP_PORT
#        ./start-tunnel.sh  http # Quick Tunnel for http://localhost:$MY_APP_PORT

CLOUDFLARED_PACKAGE=cloudflared-linux-amd64.deb
# for Fedora, RedHat, Alma, CentOS, etc RPM Linux:
#CLOUDFLARED_PACKAGE=cloudflared-linux-x86_64.rpm

CLOUDFLARED_URL=https://github.com/cloudflare/cloudflared/releases/latest/download/$CLOUDFLARED_PACKAGE
# my app virtualmin port is 10000
MY_APP_PORT=10000
# default to access app over https.  Add http to command line to access your app over http.
MY_APP_SCHEME=https

process_args () {
  if [ -n "$1" ]; then
    MY_APP_SCHEME=$1
  fi
}

install_prereq_if_not_already () {
  if ! command -v $1 > /dev/null; then
    sudo apt -y install $2
  fi
}

install_tunnel_package_if_not_already () {
  if ! command -v $1 > /dev/null; then
    #wget -q -N $CLOUDFLARED_URL
    #sudo dpkg -i $CLOUDFLARED_PACKAGE
    #rm $CLOUDFLARED_PACKAGE
    sudo wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O /usr/local/bin/cloudflared
    sudo chmod +x /usr/local/bin/cloudflared
    cloudflared update  # easier than detect 6 different linux OS, macos, windows, etc, install repo, update pkg cache, and install.
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

process_args

echo "NOTE if browsing to the URL (above) takes a long time and fails, then this command may fix it:  sudo ufw enable"

cloudflared tunnel --url $MY_APP_SCHEME://localhost:$MY_APP_PORT --no-tls-verify
