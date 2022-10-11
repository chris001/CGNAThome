#!/usr/bin/env /usr/bin/bash
# (c) 2022 Chris Coleman
#
# Start a Cloudflare Quick Tunnel with instant temporary https URL. 
#   Defaults to the Virtualmin default port, https localhost port 10000,
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

CLOUDFLARED_BINARY=cloudflared-linux-amd64
CLOUDFLARED_URL=https://github.com/cloudflare/cloudflared/releases/latest/download/$CLOUDFLARED_BINARY
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

open_firewall_ports () {
  #sudo ufw allow ssh
  sudo ufw allow $MY_APP_PORT
  #sudo ufw enable
  #sudo ufw status
}


# step 1
install_tunnel_package_if_not_already () {
  if ! command -v $1 > /dev/null; then
    sudo wget -q $CLOUDFLARED_URL -O /usr/local/bin/cloudflared
    sudo chmod +x /usr/local/bin/cloudflared
    cloudflared update  # easier than detect 6 different linux OS, macos, windows, etc, install repo, update pkg cache, and install from repo.
  fi
}

# Step 2. Authenticate cloudflared
# This command will give a URL (server) or open browser (desktop).
# In browser login to your CF account
# If new doamin, Click Add domain, copy paste CF DNS servers to your registar domain DNS server settings,
# In  CF account, Select your hostname
# CF will generate a cert.pem file and save it in your default cloudflared directory.
login_cloudflare_tunnel () {
  cloudflared tunnel login
}


# 3. Create a tunnel and give it a name.
# creates a tunnel by relating name to UUID. No connection exist yet.
# generates tunnel crediential file in default cloudflared directory.
# creates a subdomain of .cfargotunnel.com (? .trycloudflare.com ?)
# Note UUID and path to tunnel crediential file, will use these soon.
create_tunnel_uuid_json_file_from_name () {
  cloudflared tunnel create $1
  # response contains "Created tunnel mike with id <UUID>"
}


# 4. Create tunnel config file
create_tunnel_config_file () {
  cat << EOF > $HOME/.cloudflared/config.yml
*** start working config.yml ****
#url: https://localhost:10000
tunnel: abbcef39-3cb1-41c8-b194-7034d01d429f
credentials-file: /home/chris/.cloudflared/abbcef39-3cb1-41c8-b194-7034d01d429f.json
originRequest: # Top-level configuration
  connectTimeout: 30s
  #noTLSVerify: true
ingress:
#   #This service inherits all configuration from the root-level config, i.e.
#   #it will use a connectTimeout of 30 seconds.
  - hostname: chris001.tk
    service: https://localhost:10000
    originRequest:
      noTLSVerify: true
  - hostname: webmail.chris001.tk
    #url: https://chris001.tk:20000
    service: https://localhost:20000
    originRequest:
      noTLSVerify: true
#  - hostname: gitlab-ssh.widgetcorp.tech
#    service: ssh://localhost:22
#  - service: http_status:404
#  # This service overrides some root-level config.
#  - service: localhost:8002

#    originRequest:
#      connectTimeout: 10s
#      disableChunkedEncoding: true
#      noTLSVerify: true
# Some built-in services (like `http_status`) don't use any config. So, this
# rule will inherit all the config, but won't actually use it (because it just
# responds with HTTP 404).
  - service: http_status:404
*** end working config.yml ***
EOF
}


# Step 4.5 
# For persistent tunnel with user's domain/subdomain name!
install_cloudflared_service () {  
  sudo cloudflared service install  
  ## install auto updater
  croncommand="cloudflared update"
  cronfile="/etc/cron.hourly/cloudflared-updater"
  tmpcronfile="./temp-cron-xyz"
  sudo echo "$croncommand" >> $tmpcronfile
  sudo mv $tmpcronfile $cronfile
  sudo chmod +x $cronfile
  sudo chown root:root $cronfile
}


# start service
start_tunnel_service () {
  sudo systemctl start cloudflared
  # You can now route traffic thru your tunnel!, Step 5 below.
}


# View status of service
view_status_of_tunnel () {
  sudo systemctl status cloudflared
}


# If you add IP routes or otherwise change the configuration, 
# restart the service to load the new configuration
restart_tunnel () {
  sudo systemctl restart cloudflared
}


# 5. Start routing traffic.
# Now assign a CNAME DNS record that points traffic to your tunnel subdomain.
route_traffic_to_app () {
  #If you are connecting an application
  cloudflared tunnel route dns <UUID or NAME> <hostname>
  #cloudflared tunnel route dns mike chris001.tk
  #Failed to add route: code: 1003, reason: An A, AAAA, or CNAME record with that host already exists.
  #Delete A and AAAA records?
  #Yes! Success shows:
  #INF Added CNAME chris001.tk which will route to this tunnel tunnelID=<UUID>
}

# 5b. Route traffic to network
route_traffic_to_network () {
  #If you are connecting a network
  #Add the IP/CIDR you would like to be routed through the tunnel.
  cloudflared tunnel route ip add <IP/CIDR> <UUID or NAME>
}

# 5.c
#You can confirm that the route has been successfully established by running:
confirm_tunnel_route {
  cloudflared tunnel route ip show
}

# 6. Run the tunnel
#Run the tunnel to proxy incoming traffic from the tunnel to any number of 
#services running locally on your origin.
run_tunnel () {
  cloudflared tunnel run <UUID or NAME>
  #cloudflared tunnel run mike
  # If your configuration file has a custom name or is not in the 
  # .cloudflared directory, add the --config flag and specify the path.
  #cloudflared tunnel --config /path/your-config-file.yaml run
}

# 7. Check the tunnel info
#Your tunnel configuration is complete! If you want to get information 
#on the tunnel you just created, you can run:
tunnel_info () {
  cloudflared tunnel info
}


# step 8 (optional)
remove_cloudflared_service () {
  sudo cloudflared service uninstall
  cronfile="/etc/cron.hourly/cloudflared-updater"
  sudo chmod -x $cronfile
  sudo rm $cronfile
  sudo systemctl daemon-reload
}



# View status of tunnel service
get_status_tunnel_service () {
  sudo systemctl status cloudflared
}

# If you add IP routes or otherwise change the configuration, 
# restart the service to load the new configuration
restart_tunnel_service () {
  sudo systemctl restart cloudflared
}


install_prereq_if_not_already wget wget
install_prereq_if_not_already ufw ufw
#install_prereq_if_not_already snap snapd

install_tunnel_package_if_not_already cloudflared

open_firewall_ports

process_args

echo "NOTE if browsing to your temporary URL (above) takes a long time and fails, \nprobably a firewall issue, you could fix it with this command \nand reload the page:  sudo ufw enable"

#localhost for new installs of most web apps has a self signed cert, do not verify the cert.

cloudflared tunnel --url $MY_APP_SCHEME://localhost:$MY_APP_PORT --no-tls-verify
