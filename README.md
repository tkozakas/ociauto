## Overview

This repository contains a Bash script (`ociauto.sh`) that repeatedly attempts to launch an Oracle Cloud Infrastructure (OCI) Compute instance until it succeeds. All configuration values—OCIDs, shapes, SSH key, etc.—are provided via a `.env` file, which you populate from the included `.env.example`. This README shows you how to:

1. Copy and populate `.env` from `.env.example`  
2. Install the OCI Command Line Interface (CLI)  
3. Authenticate the CLI  
4. Run the retry‐launch script (`ociauto.sh`)  

---

## 1. `.env.example`

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
SSH_KEY=""                           # Your SSH public key (one-line string)
RETRY_INTERVAL=60                    # Seconds to wait before retrying
```

## 2. Finding & Populating .env Values
- COMPARTMENT_OCID
1. Console → Identity & Security → Compartments
2. Click your target compartment → copy its OCID
- AVAILABILITY_DOMAIN
```bash
oci iam availability-domain list
```
- SHAPE
```bash
oci compute shape list --compartment-id $COMPARTMENT_OCID
```
- OCPUS & MEMORY_GB
For flexible shapes, set CPU and RAM within the allowed range for that shape.
- IMAGE_OCID
Copy the OCID of your desired image.
```bash
oci compute image list --compartment-id $COMPARTMENT_OCID --all
```
- SUBNET_OCID
Console → Networking → Virtual Cloud Networks → select your VCN → select subnet → copy OCID.
- SSH_KEY
```bash
ssh-keygen -t ed25519 -C "you@example.com"
cat ~/.ssh/id_ed25519.pub
```
## 3. Installing the OCI CLI
- Installer script (Unix/Linux/macOS)
```bash
bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)"
```
- pip
```bash
pip install oci-cli
```

## 4. Authenticating the CLI
```bash
oci setup config
oci session authenticate
```

## 5. Running the script
```bash
chmod +x ociauto.sh
./ociauto.sh
```
- Retries oci compute instance launch every $RETRY_INTERVAL seconds
- Logs successes to ~/.oci/instance_launch_success.log
- Logs failures to ~/.oci/instance_launch_error.log
- Creates ~/.oci/instance_launched on success
