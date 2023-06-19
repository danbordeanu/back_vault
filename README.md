# back_vault
Backup hashicorp vault and upload snap to sftp gateway

# flow
backup_vault.sh -> sftp gw -> s3 bucket

# requirements
- Create S3 destination
- Add S3 bucket credentials
- Add  Public Ssh Key
- Create public Sftp ingress

