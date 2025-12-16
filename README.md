# Samba Server with SSSD/LDAP Integration

This Docker image provides a fully-featured Samba server integrated with SSSD (System Security Services Daemon) for LDAP authentication. It allows you to expose file shares over SMB/CIFS protocol while authenticating users against a central LDAP directory. This setup is ideal for home labs or small offices where you want to centralize user management while providing traditional file sharing capabilities.

## Features

- 🔐 **LDAP Integration**: Authenticate users via SSSD against an LDAP server
- 📁 **Flexible Share Configuration**: Define Samba shares by mounting `.conf` files
- 🏥 **Health Checks**: Built-in health monitoring for Samba and SSSD services
- 🐳 **Docker Native**: Easy deployment with Docker Compose
- 📝 **Environment-based Configuration**: Customize via environment variables

## Quick Start

### 1. Create Configuration Override

The base `docker-compose.yaml` is provided. Create your own configuration by copying the example override file:

```bash
cp docker-compose.override.yaml.example docker-compose.override.yaml
```

Edit `docker-compose.override.yaml` with your specific configuration:

```yaml
services:
  samba:
    environment:
      # LDAP Configuration (Required)
      LDAP_URL: 'ldap://ldap.example.com'
      LDAP_SEARCH_BASE: 'dc=example,dc=com'
      LDAP_USER_SEARCH_BASE: 'ou=users,dc=example,dc=com'
      LDAP_GROUP_SEARCH_BASE: 'ou=groups,dc=example,dc=com'

      # Samba Access Control (Optional)
      SMB_HOSTS_ALLOW: '192.168.1.0/24 10.0.0.0/8'

    # Mount your share configurations
    volumes:
      - ./shares.d:/etc/samba/conf.d:ro
```

**Note**: Docker Compose automatically merges `docker-compose.yaml` and `docker-compose.override.yaml` when you run `docker compose up`.

### 2. Define Samba Shares

Create a `shares.d/` directory and add your share configuration files. Each `.conf` file should contain a standard Samba share definition.

Example share configuration (`shares.d/media.conf`):

```ini
[media]
  path = /media
  browseable = yes
  read only = no
  valid users = @media-users
  create mask = 0664
  directory mask = 0775
```

Example home directories (`shares.d/homes.conf`):

```ini
[homes]
  browseable = No
  comment = Home Directories
  create mask = 0644
  path = /home/%S
  read only = No
  valid users = %S
```

### 3. Deploy with Docker Compose

```bash
# Build and start the service
docker compose up -d

# View logs
docker compose logs -f samba
```

### 4. Add Samba Users

**Important**: Even though users are authenticated via LDAP, Samba requires its own password database. You must add each user to Samba's password database:

```bash
# Enter the container
docker compose exec samba bash

# Add a user to Samba (user must exist in LDAP)
smbpasswd -a username

# You will be prompted to enter a Samba-specific password
# This password is independent from the LDAP password
```

**Note**: The Samba password cannot be synchronized with LDAP passwords. Users will need to remember both passwords.

## Kubernetes Deployment

### Using Helm Chart

This project provides a Helm chart for easy deployment on Kubernetes. The chart is available as an OCI artifact in GitHub Container Registry.

#### Prerequisites

- Kubernetes 1.19+
- Helm 3.8+ (with OCI support)
- A LoadBalancer implementation (MetalLB, cloud provider LB, etc.)
- An LDAP server accessible from the cluster

#### Quick Install

```bash
# Install with default values (you MUST override LDAP settings)
helm install samba-server oci://ghcr.io/rclsilver-org/charts/samba-server

# Install with custom values
helm install samba-server oci://ghcr.io/rclsilver-org/charts/samba-server \
  --set ldap.url="ldap://ldap.example.com" \
  --set ldap.baseDN="dc=example,dc=com" \
  --set ldap.userBase="ou=users,dc=example,dc=com" \
  --set ldap.groupBase="ou=groups,dc=example,dc=com"

# Or use a values file
helm install samba-server oci://ghcr.io/rclsilver-org/charts/samba-server \
  -f values.yaml
```

#### Minimal values.yaml Example

```yaml
ldap:
  url: "ldap://ldap.internal.svc.cluster.local"
  baseDN: "dc=company,dc=local"
  userBase: "ou=people,dc=company,dc=local"
  groupBase: "ou=groups,dc=company,dc=local"

samba:
  allowHosts:
    - "192.168.1.0/24"
    - "10.0.0.0/8"

# Mount ConfigMap with share definitions
volumes:
  - name: shares
    configMap:
      name: samba-shares

volumeMounts:
  - name: shares
    mountPath: /etc/samba/conf.d
    readOnly: true
```

#### Creating Share Configurations in Kubernetes

Create a ConfigMap with your share definitions:

```yaml
# samba-shares-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: samba-shares
  namespace: default
data:
  homes.conf: |
    [homes]
      browseable = No
      comment = Home Directories
      create mask = 0644
      path = /home/%S
      read only = No
      valid users = %S

  shared.conf: |
    [shared]
      path = /data/shared
      browseable = yes
      read only = no
      valid users = @users
      create mask = 0664
      directory mask = 0775
```

Apply it before installing the chart:

```bash
kubectl apply -f samba-shares-configmap.yaml
helm install samba-server oci://ghcr.io/rclsilver-org/charts/samba-server -f values.yaml
```

#### Post-Installation

1. **Get the LoadBalancer IP:**

```bash
kubectl get service samba-server
# Wait for EXTERNAL-IP to be assigned
```

2. **Add Samba users** (users must exist in LDAP):

```bash
# Get the pod name
POD_NAME=$(kubectl get pods -l app.kubernetes.io/name=samba-server -o jsonpath='{.items[0].metadata.name}')

# Add a user to Samba
kubectl exec -it $POD_NAME -- smbpasswd -a username
```

3. **Test connection:**

```bash
# From a client machine
smbclient -L //<EXTERNAL-IP> -U username
```

#### Kubernetes Debugging

```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/name=samba-server

# View logs
kubectl logs -f <pod-name>

# Verify LDAP users
kubectl exec -it <pod-name> -- getent passwd

# Check SSSD status
kubectl exec -it <pod-name> -- supervisorctl status sssd
```

#### Chart Documentation

For complete chart documentation, configuration options, and advanced examples, see:
- [Helm Chart README](./charts/samba-server/README.md)
- [Chart on GitHub Container Registry](https://github.com/rclsilver-org/docker-samba-server/pkgs/container/charts%2Fsamba-server)

**Note**: Although GitHub displays `docker pull` instructions on the package page, this is a Helm chart and must be installed using `helm install` as shown above.

## Docker Compose Configuration

### Project Structure

```
.
├── docker-compose.yaml              # Base configuration (do not modify)
├── docker-compose.override.yaml     # Your custom configuration (create from .example)
├── docker-compose.override.yaml.example  # Configuration template
├── shares.d/                        # Your Samba share definitions
│   ├── homes.conf
│   ├── media.conf
│   └── ...
├── Dockerfile
├── docker-entrypoint.sh
└── healthcheck.sh
```

### Configuration Files

1. **docker-compose.override.yaml**: Your environment-specific configuration
   - Copy from `docker-compose.override.yaml.example`
   - Set LDAP connection details
   - Configure network access control
   - Add health check configuration
   - Not tracked in git (add to `.gitignore`)

2. **shares.d/*.conf**: Samba share definitions
   - Each file defines one or more shares
   - Files are loaded in alphabetical order
   - Standard Samba share syntax

### Environment Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `LDAP_URL` | LDAP server URL (e.g., `ldap://ldap.example.com`) | ✅ Yes | - |
| `LDAP_SEARCH_BASE` | LDAP base DN for all searches | ✅ Yes | - |
| `LDAP_USER_SEARCH_BASE` | LDAP base DN for user searches | ✅ Yes | - |
| `LDAP_GROUP_SEARCH_BASE` | LDAP base DN for group searches | ✅ Yes | - |
| `SMB_HOSTS_ALLOW` | Space-separated list of allowed hosts/networks | ❌ No | `` (empty) |
| `SMB_HOSTS_DENY` | Space-separated list of denied hosts/networks | ❌ No | `ALL` |

### Shares Configuration

Samba share configurations are loaded from `/etc/samba/conf.d/`. The recommended approach is to mount your entire `shares.d/` directory:

```yaml
# In docker-compose.override.yaml
volumes:
  - ./shares.d:/etc/samba/conf.d:ro
```

All `.conf` files in this directory will be automatically included in alphabetical order. Each file should contain standard Samba share definitions.

## Health Check

The image includes a health check script (`/healthcheck.sh`) that verifies:

1. **Samba daemon** (`smbd`) is running
3. **SSSD daemon** is running

## Debugging

### Verify LDAP User Integration

Check if LDAP users are being retrieved correctly:

```bash
# List all users (should include LDAP users)
docker compose exec samba getent passwd

# Check a specific user
docker compose exec samba getent passwd username
```

Expected output should include users from your LDAP directory with their UID, GID, home directory, and shell.

### Verify LDAP Group Integration

Check if LDAP groups are being retrieved correctly:

```bash
# List all groups (should include LDAP groups)
docker compose exec samba getent group

# Check a specific group
docker compose exec samba getent group groupname
```

### Check SSSD Status

```bash
# View SSSD status
docker compose exec samba supervisorctl status sssd

# Clear SSSD cache if needed
docker compose exec samba sss_cache -E
```

### View Samba Logs

```bash
# View Samba logs
docker compose exec samba tail -f /var/log/samba/log.smbd

# List connected users
docker compose exec samba smbstatus
```

### Test LDAP Connection

```bash
# Test LDAP connectivity from within the container (uses container's env vars)
docker compose exec samba bash -c 'ldapsearch -x -H "$LDAP_URL" -b "$LDAP_SEARCH_BASE"'

# Or enter the container and run interactively
docker compose exec samba bash
# Then inside the container:
ldapsearch -x -H "$LDAP_URL" -b "$LDAP_SEARCH_BASE"
```

## Troubleshooting

### Users Can't Connect

1. Verify the user exists in LDAP: `getent passwd username`
2. Ensure the user has been added to Samba: `pdbedit -L`
3. If user is missing from Samba, add them: `smbpasswd -a username`
4. Check Samba logs for authentication errors

### LDAP Users Not Appearing

1. Check SSSD configuration: Verify environment variables are set correctly
2. Restart SSSD: `docker compose exec samba supervisorctl restart sssd`
3. Check SSSD logs: `docker compose exec samba tail -f /var/log/sssd/sssd_ldap.log`
4. Clear SSSD cache: `docker compose exec samba sss_cache -E`

### Connection Refused

1. Verify port 445 is exposed and not blocked by firewall
2. Check if Samba is running: `docker compose exec samba supervisorctl status smbd`
3. Verify `SMB_HOSTS_ALLOW` includes your client's IP/network

## Security Considerations

- **Samba Passwords**: Passwords are stored separately from LDAP and cannot be synchronized
- **Network Access**: Use `SMB_HOSTS_ALLOW` to restrict access to trusted networks
- **TLS/LDAPS**: For production, use LDAPS (`ldaps://`) instead of plain LDAP
- **Minimal Protocol**: The server enforces SMB2 as minimum protocol for security

## License

This project is provided as-is for personal and educational use.
