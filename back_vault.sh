#!/bin/bash

# Variables
authorization="eyJhbG[...]"
url="https://api.almeriaindustries.com/api/user-registry/v1/release"
header="accept: application/json"
backupDirectory="BACK"
uploadDirectory="upload"
deploymentName="backup"

# Check if rsync command is available
if ! command -v rsync >/dev/null; then
    echo "rsync command is not found. Please install rsync."
    exit 1
fi

# Check if lftp command is available
if ! command -v lftp >/dev/null; then
    echo "lftp command is not found. Please install lftp."
    exit 1
fi

# Check if vault command is available
if ! command -v vault >/dev/null; then
    echo "vault command is not found. Please install hashicorp vault cli."
    exit 1
fi

# Check if backup directory exists
if [ ! -d "$backupDirectory" ]; then
  echo "Backup directory does not exist. Creating $backupDirectory..."
  mkdir "$backupDirectory"
else
  echo "Backup directory already exists."
fi

# Check if VAULT_ADDR is set
if [[ -z "${VAULT_ADDR}" ]]; then
  VAULT_ADDR="https://internalvault.com:8200"  # Replace with your hardcoded value
  echo "WARNING: The vault_addr environment variable is not set. Using a hardcoded value: $VAULT_ADDR"
  export VAULT_ADDR
else
  echo "The vault_addr environment variable is set to: $VAULT_ADDR"
fi

# Execute the command to save the snapshot
vault operator raft snapshot save $backupDirectory/backup.snap

# Check if the command executed successfully
if [ $? -eq 0 ]; then
  # Get the current date in the format YYYY-MM-DD
  current_date=$(date +'%Y-%m-%d')
  current_time=$(date +'%H-%M-%S')

  # Zip the snapshot file with the current date appended
  zip "${backupDirectory}/backup_${current_date}_${current_time}.zip" "${backupDirectory}/backup.snap"

  # Check if the zip command executed successfully
  if [ $? -eq 0 ]; then
    echo "Snapshot backup saved and zipped successfully."
    echo "Removing snap file..."
    rm -rf $backupDirectory/backup.snap
  else
    echo "Failed to zip the snapshot backup."
    exit 1
  fi
else
  echo "Failed to save the snapshot backup."
  exit 1
fi

# get public IP of sftp ingress
response=$(curl -X GET "$url" -H "$header" -H "Authorization: $authorization")
loadBalancerIP=$(echo "$response" | grep -oE "\"Name\":\"$deploymentName\".*\"loadBalancerIP\":\"([0-9]{1,3}\.){3}[0-9]{1,3}\"" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}')
externalSFTPPort=$(echo "$response" | grep -oE "\"Name\":\"$deploymentName\".*\"externalSFTPPort\":\"[0-9]+\"" | grep -oE '[0-9]+')

if [[ -n "$loadBalancerIP" ]]; then
  echo "Sftp Gateway Ingress Load Balancer IP: $loadBalancerIP"
  echo "Sftp Ingress External SFTP Port: $externalSFTPPort"
else
  echo "Sftp Gateway Load Balancer IP  not found..."
  exit 1
fi

# Construct the lftp command
lftp  sftp://$loadBalancerIP:$externalSFTPPort -e "put $backupDirectory/backup_${current_date}_${current_time}.zip; exit"

# Check if lftp executed successfully
if [ $? -eq 0 ]; then
    echo "Lftp copy command was successfully."

    echo "Removing zip file..."
    rm -rf $backupDirectory/backup_${current_date}_${current_time}.zip
else
    echo "Failed to lftp the snapshot backup."
    exit 1
fi
