## Overview

This repository contains a Bash script (`ociauto.sh`) that repeatedly attempts to launch an Oracle Cloud Infrastructure (OCI) Compute instance until it succeeds. All configuration values—OCIDs, shapes, SSH key, etc.—are provided via a `.env` file, which you populate from the included `.env.example`. This README shows you how to:
1. Install the OCI Command Line Interface (CLI)  
2. Authenticate the CLI  
3. Copy and populate `.env` from `.env.example`  
4. Run the retry‐launch script (`ociauto.sh`)  

---

## 1. Installing the OCI CLI
- Installer script (Unix/Linux/macOS)
```bash
bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)"
```
- pip
```bash
pip install oci-cli
```

## 2. Authenticating the CLI
### 1. Generate an API Signing Key
```bash
oci setup config
```
### 2. Upload Your Public Key
1. Sign in to the OCI Console.
2. Navigate to Identity & Security → Users → [Your User] → API Keys.
3. Click Add API Key, choose Upload Public Key File or Paste Public Key, then click Add.
### 3. Environment Variables & Profiles
```bash
export OCI_CLI_PROFILE="<PROFILE>" 		# name of your profile
export OCI_CLI_CONFIG_FILE="~/.oci/config"	# path to your config
export OCI_CLI_AUTH="security_token"   		# use the session token for auth
```

## 3. `.env.example`

```bash
# Copy this file to .env and fill in each value:
DISPLAY_NAME="my-instance"           # Friendly name for your instance
COMPARTMENT_OCID=""                  # OCID of the compartment to launch into
AVAILABILITY_DOMAIN=""               # One of your region’s AD names (e.g. EU-FRANKFURT-1-AD-1)
SHAPE=""                             # Instance shape name (e.g. VM.Standard.A1.Flex)
OCPUS=                               # Number of OCPUs (for flexible shapes)
MEMORY_GB=                           # Memory in GB (for flexible shapes)
IMAGE_OCID=""                        # OCID of the image to boot from
SUBNET_OCID=""                       # OCID of the subnet to attach the VNIC
SSH_KEYS_FILE=""                     # Your SSH public key (one-line string)
BASE_INTERVAL=60       		     # starting retry interval
MAX_INTERVAL=300       		     # maximum interval after back-off
BACKOFF_FACTOR=2       		     # multiply interval by this on each retry
JITTER_PERCENT=10      		     # ±% jitter to spread out retries
```

## 4. Running the script
```bash
chmod +x ociauto.sh
./ociauto.sh
```
- Retries oci compute instance launch every $RETRY_INTERVAL seconds
- Logs successes to ~/.oci/instance_launch_success.log
- Logs failures to ~/.oci/instance_launch_error.log
- Creates ~/.oci/instance_launched on success

## 5. Optional: Create a service (Linux)
1. Create this service at '~/.config/systemd/user/ociauto.service'
2. Save the content: 
```bash
[Service]
Type=oneshot
WorkingDirectory=/home/YOUR_USER/PATH/TO/OCIAUTO/ociauto

# Make sure systemd sees your oci binary
Environment=PATH=/home/YOUR_USER/bin:/usr/local/bin:/usr/bin:/bin

# Tell OCI CLI to use your session token
Environment=OCI_CLI_AUTH=security_token
Environment=OCI_CLI_PROFILE=tomas
Environment=OCI_CLI_CONFIG_FILE=/home/tom/.oci/config

# DBus for desktop notification
Environment=DISPLAY=:0
Environment=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/%U/bus

ExecStart=/home/YOUR_USER/PATH/TO/OCIAUTO/ociauto/ociauto.sh
ExecStartPost=/usr/bin/notify-send "OCI Launched" "Your instance is up!"
Restart=on-failure
RestartSec=10


```
3. After saving, reload and restart:
```bash
systemctl --user daemon-reload
systemctl --user restart ociauto.service
journalctl --user -u ociauto.service -f
```
