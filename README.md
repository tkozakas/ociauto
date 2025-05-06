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
```bash
oci setup config
oci session authenticate
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
SSH_KEY=""                           # Your SSH public key (one-line string)
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
