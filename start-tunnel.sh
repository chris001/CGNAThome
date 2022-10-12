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

# USAGE: ./start-tunnel.sh  # defaults to Quick Tunnel for https://RMY_APP_HOSTNAME:$MY_APP_PORT
#        ./start-tunnel.sh  <TUNNEL_NAME> # Persistent Tunnel for https://$MY_APP_HOSTNAME:$MY_APP_PORT

# default to access app with https on localhost port 10000.
# (Deprecated) Add http to command line to access your app over http.
MY_APP_SCHEME="https"
# my app (virtualmin) port is 10000
MY_APP_PORT=10000
# my app hostname
MY_APP_HOSTNAME="localhost"

TUNNEL_NAME=""                 # User chosen tunnel name. Blank =  tunnel with CF generated temp subdomain of ".trycloudflare.com".
TUNNEL_MODE_MY_DOMAIN_NAME=0   # 0 = CF generate temp subdomain of ".trycloudflare.com". 1 = user's own domain/subdomain host name.
TUNNEL_UUID="blank_UUID"       # CF generated tunnel Unique ID 
TUNNEL_HOSTNAME="blank_Hostname"  # (If they provide a command line arg,it must be either Hostname or subnet) user provided custom domain hostname or subdomain.
TUNNEL_IP_CIDR="blank_optional_IP_CIDR"     #  User provided local IP subnet for CF to route incoming traffic

# Step 1a
install_prereq_if_not_already () {
  if ! command -v $1 > /dev/null; then
    sudo apt -y install $2
  fi
}

# step 1b
install_tunnel_package_if_not_already () {
  CLOUDFLARED_BINARY=cloudflared-linux-amd64
  CLOUDFLARED_URL=https://github.com/cloudflare/cloudflared/releases/latest/download/$CLOUDFLARED_BINARY
  if ! command -v $1 > /dev/null; then
    tunnel_binary_path="/usr/local/bin/cloudflared"
    sudo wget -q $CLOUDFLARED_URL -O $tunnel_binary_path
    sudo chmod +x $tunnel_binary_path
    cloudflared update  # easier than detect 6 different linux OS, macos, windows, etc, install repo, update pkg cache, install from repo.
  fi
}

# Step 1c NOTE this is probably unnecessary as local binary calls out to CF. 
#   CF should make no incoming requests from public internet thru external 
#   public IP thru Double CG ANT thru firewall.
open_firewall_ports () {
  sudo ufw allow $MY_APP_PORT
}

# Step 1d process the command line args
process_args () {
  if [ -n "$1" ]; then {
    TUNNEL_NAME=$1
    TUNNEL_MODE_MY_DOMAIN_NAME=1
  }
  else {
    TUNNEL_MODE_MY_DOMAIN_NAME=0
  }
  fi
}

# Step 2. Authenticate cloudflared
# This command will output the URL (server) or open browser to the URL (desktop).
# In browser login to your CF account
# If new doamin, Click Add domain, next thru steps, 
#   copy paste the two DNS servers CF provides you, 
#   to your registar accout your domain's custom DNS servers,
# In  CF account, paste URL provided by CF above, 
#   and Select your domain's hostname or subdomain.
# CF will generate a cert.pem file and
#   save cert.pem in your default cloudflared directory.
login_cloudflare_tunnel () {
  cloudflared tunnel login
}

# 3. Create a tunnel and have user give it a name.
# Creates a tunnel by relating name to UUID. No connection exist yet.
# Generates tunnel crediential file in default cloudflared directory.
# Creates a subdomain of .cfargotunnel.com (? .trycloudflare.com ?)
# Note UUID and path to tunnel crediential file, will use these soon.
create_tunnel_uuid_json_file_from_name () {
  cloudflared tunnel create $TUNNEL_NAME
  # multi line output contains "Created tunnel mike with id <UUID>"
  # or if already exists:
  # "failed to create tunnel: Create Tunnel API call failed: tunnel with name already exists"
  tunnel_uuid="$(cloudflared tunnel list | grep "$TUNNEL_NAME" | cut -d' ' -f1)"
  # Output is: UUID  Name  Created  Connections
  TUNNEL_UUID=$tunnel_uuid
}

# 4. Create tunnel config file
create_tunnel_config_file () {
  config_file_path="$HOME/.cloudflared/config.yml"
  MY_APP_URL="$MY_APP_SCHEME://$MY_APP_HOSTNAME:$MY_APP_PORT"

cat << EOF > $config_file_path
*** start working config.yml ****
#url: $MY_APP_URL
tunnel: $TUNNEL_UUID
credentials-file: $HOME/.cloudflared/$TUNNEL_UUID.json
originRequest: # Top-level configuration
  connectTimeout: 30s
  #noTLSVerify: true
ingress:
#   #This service inherits all configuration from the root-level config, i.e.
#   #it will use a connectTimeout of 30 seconds.
  - hostname: $TUNNEL_HOSTNAME
    service: $MY_APP_URL
    originRequest:
      noTLSVerify: true
  - hostname: webmail.$TUNNEL_HOSTNAME
    #url: $MY_APP_SCHEME://$TUNNEL_HOSTNAME:20000
    service: $MY_APP_SCHEME://$MY_APP_HOSTNAME:20000
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

# Step 4.5a For persistent tunnel with user's domain/subdomain name.
install_cloudflared_service () {
  #First copy my .clouflared/* to /etc/cloudflared or /usr/local/etc/cloudflared
  # contains: cert.pem (for cloudflared to login to CF), <uuid>.json (tunnel info), 
  #     config.yml (configs and rules for routing to user's local services).
  sudo mkdir -p /usr/local/etc/cloudflared/
  sudo cp ~/.cloudflared/* /usr/local/etc/cloudflared/
  #Modify (sed/awk) 2 lines inside this yml file like this:
  # tunnel: <tunnel uuid>
  # credentials-file: /home/$USER/.cloudflared/<tunnel uuid>.json  ##### to:
  # credentials-file: /usr/local/etc/cloudflared/<tunnel uuid>.json

  sudo cloudflared service install  
  ## install auto updater
  croncommand="cloudflared update"
  cronfile="/etc/cron.hourly/cloudflared-updater"
  tmpcronfile="./temp-cron-xyz"
  sudo echo "$croncommand" >> $tmpcronfile
  sudo mv $tmpcronfile $cronfile
  sudo chown root:root $cronfile
  sudo chmod +x $cronfile
}

# Step 4.5b  Start service
start_tunnel_service () {
  sudo systemctl start cloudflared
  # You can now route traffic thru your tunnel!, Step 5 below.
}

# Step 4.5c  View status of service
view_status_of_tunnel () {
  sudo systemctl status cloudflared
}

# 5a. Start route traffic to app. CF creates DNS record, points to your tunnel subdomain.
route_traffic_to_app () {
  #If you are connecting an application
  cloudflared tunnel route dns $TUNNEL_NAME $TUNNEL_HOSTNAME
  #cloudflared tunnel route dns mike myhostname.tld
  #Failed to add route: code: 1003, reason: An A, AAAA, or CNAME record with that host already exists.
  #Delete A and AAAA records?
  #Yes! Success shows:
  #INF Added CNAME myhostname.tld which will route to this tunnel tunnelID=<TUNNEL_UUID>
}

# 5b. (either 5a or 5b) Route traffic to network
route_traffic_to_network () {
  #If you are connecting a network
  #Add the IP/CIDR you would like to be routed through the tunnel NAME or UUID.
  cloudflared tunnel route ip add $TUNNEL_IP_CIDR $TUNNEL_NAME
}

# 5c. (optional) Confirm route is successful.
#You can confirm that the route has been successfully established by running:
confirm_tunnel_route {
  cloudflared tunnel route ip show
}

# 6. Run the tunnel
#Run the tunnel to proxy incoming traffic from the tunnel to any number of 
#services running locally on your origin.
run_tunnel () {
  cloudflared tunnel run $TUNNEL_NAME
  #cloudflared tunnel run mike
  # If your configuration file has a custom name or is not in the 
  # .cloudflared directory, add the --config flag and specify the path.
  #cloudflared tunnel --config /path/your-config-file.yaml run
}

# 7. Check the tunnel info
#Your tunnel configuration is complete! If you want to get information 
#on the tunnel you just created, you can run:
tunnel_info () {
  cloudflared tunnel info $TUNNEL_NAME
}

# step 8 (optional)
remove_cloudflared_service () {
  sudo cloudflared service uninstall
  cronfile="/etc/cron.hourly/cloudflared-updater"
  sudo chmod -x $cronfile
  sudo rm $cronfile
  sudo systemctl daemon-reload
}

# Step 9 (optional)
# If you add IP routes or otherwise change the configuration, 
# restart the service to load the new configuration
restart_tunnel_service () {
  sudo systemctl restart cloudflared
}

# Step 10 Start tunnel
start_tunnel () {
  # localhost for new installs of web apps has self signed cert, so do not verify the cert.
  cloudflared tunnel --url "$MY_APP_SCHEME://$MY_APP_HOSTNAME:$MY_APP_PORT" --no-tls-verify
}

# Step 1a
install_prereq_if_not_already wget wget
install_prereq_if_not_already ufw ufw
#install_prereq_if_not_already snap snapd

#Step 1b
install_tunnel_package_if_not_already cloudflared

#Step 1c
open_firewall_ports

#Step 1d
process_args

if [ -n "$TUNNEL_MODE_MY_DOMAIN_NAME" ]; then {
  # Step 2 Login (authenticate) for Cloudflare Tunnel
  # CREATES cert.pem
  login_cloudflare_tunnel

  #Step 3 Create a tunnel and give it a name. 
  # CREATES <UUID>.json
  create_tunnel_uuid_json_file_from_name $TUNNEL_NAME

  #Step 4 Create tunnel config file. 
  # CREATES config.yml
  create_tunnel_config_file $TUNNEL_UUID

  # Step 4.5a  For persistent tunnel with user's domain/subdomain name
  #   (or if none provided to CF, CF provide temp hostname?)
  install_cloudflared_service

  # Step 4.5b Start service
  start_tunnel_service

  # Step 4.5c  View status of service
  view_status_of_tunnel

  # 5a. Start routing traffic to app.
  # Now CF assigns a CNAME DNS record that points traffic to your tunnel subdomain/domain.
  route_traffic_to_app

  # 5c. (optional) Confirm route is successful.
  # You can confirm that the route has been successfully established by running:
  confirm_tunnel_route

  # 6. Run the tunnel
  # Run the tunnel to proxy incoming traffic from the tunnel 
  # to any number of services running locally on your origin.
  run_tunnel

  # 7. Check the tunnel info
  # Your tunnel configuration is complete! If you want to get information 
  # on the tunnel you just created, you can run:
  tunnel_info
}
fi

# Step 10 Start tunnel
start_tunnel
