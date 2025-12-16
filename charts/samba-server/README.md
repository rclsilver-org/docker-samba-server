# Samba Server Helm Chart

A Helm chart for deploying a Samba server with SSSD/LDAP integration on Kubernetes.

## Description

This chart deploys a Samba server that authenticates users against an LDAP directory via SSSD. It's ideal for providing SMB/CIFS file sharing in Kubernetes environments with centralized user management.

## Features

- 🔐 LDAP authentication via SSSD
- 📁 Configurable Samba shares
- 🏥 Built-in health checks
- 🔄 LoadBalancer service for external access
- 📊 Optional horizontal pod autoscaling
- 🔒 Kubernetes-native security (ServiceAccount, SecurityContext)

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- An LDAP server accessible from the cluster
- A LoadBalancer implementation (MetalLB, cloud provider LB, etc.)

## Installation

### Add the Helm repository

If you're hosting the chart in a repository:

```bash
helm repo add samba-server https://your-repo-url
helm repo update
```

### Install from local chart

```bash
# From the repository root
helm install samba-server ./charts/samba-server

# Or from a packaged chart
helm install samba-server samba-server-*.tgz
```

### Install with custom values

```bash
helm install samba-server ./charts/samba-server -f custom-values.yaml
```

## Configuration

### Required Configuration

You **must** configure the LDAP connection parameters:

```yaml
ldap:
  url: "ldap://ldap.example.com"
  baseDN: "dc=example,dc=com"
  userBase: "ou=users,dc=example,dc=com"
  groupBase: "ou=groups,dc=example,dc=com"
```

### Minimal Example

```yaml
# values.yaml
ldap:
  url: "ldap://ldap.internal.svc.cluster.local"
  baseDN: "dc=company,dc=local"
  userBase: "ou=people,dc=company,dc=local"
  groupBase: "ou=groups,dc=company,dc=local"

samba:
  allowHosts:
    - "192.168.1.0/24"
    - "10.0.0.0/8"
```

### Complete Example with Shares

```yaml
# values.yaml
image:
  repository: ghcr.io/rclsilver-org/samba-server
  tag: "v1.0.0"

ldap:
  url: "ldap://ldap.internal.svc.cluster.local"
  baseDN: "dc=company,dc=local"
  userBase: "ou=people,dc=company,dc=local"
  groupBase: "ou=groups,dc=company,dc=local"

samba:
  allowHosts:
    - "192.168.1.0/24"
  denyHosts:
    - "ALL"

service:
  type: LoadBalancer
  port: 445

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

# Mount ConfigMaps with share definitions
volumes:
  - name: shares
    configMap:
      name: samba-shares

volumeMounts:
  - name: shares
    mountPath: /etc/samba/conf.d
    readOnly: true
```

### Creating Share Configurations

Create a ConfigMap with your Samba share definitions:

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
      force group = users
```

Apply the ConfigMap:

```bash
kubectl apply -f samba-shares-configmap.yaml
```

## Configuration Parameters

### Global Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `1` |
| `nameOverride` | Override chart name | `""` |
| `fullnameOverride` | Override full name | `""` |

### Image Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Image repository | `ghcr.io/rclsilver-org/samba-server` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `image.tag` | Image tag (overrides chart appVersion) | `""` |
| `imagePullSecrets` | Image pull secrets | `[]` |

### Service Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Kubernetes service type | `LoadBalancer` |
| `service.port` | Service port | `445` |

### LDAP Parameters

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `ldap.url` | LDAP server URL | ✅ Yes | `ldap://ldap.example.com` |
| `ldap.baseDN` | LDAP base DN | ✅ Yes | `dc=example,dc=com` |
| `ldap.userBase` | LDAP user search base | ✅ Yes | `ou=users,dc=example,dc=com` |
| `ldap.groupBase` | LDAP group search base | ✅ Yes | `ou=groups,dc=example,dc=com` |

### Samba Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `samba.allowHosts` | List of allowed hosts/networks | `[]` |
| `samba.denyHosts` | List of denied hosts/networks | `["ALL"]` |

### Resource Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `resources.limits.cpu` | CPU limit | `nil` |
| `resources.limits.memory` | Memory limit | `nil` |
| `resources.requests.cpu` | CPU request | `nil` |
| `resources.requests.memory` | Memory request | `nil` |

### Autoscaling Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `autoscaling.enabled` | Enable horizontal pod autoscaling | `false` |
| `autoscaling.minReplicas` | Minimum replicas | `1` |
| `autoscaling.maxReplicas` | Maximum replicas | `100` |
| `autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization | `80` |

### Volume Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `volumes` | Additional volumes | `[]` |
| `volumeMounts` | Additional volume mounts | `[]` |

### Probe Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `livenessProbe` | Liveness probe configuration | Health check script |
| `readinessProbe` | Readiness probe configuration | Health check script |

## Post-Installation Steps

### 1. Get the LoadBalancer IP

```bash
kubectl get service samba-server
```

Wait for the `EXTERNAL-IP` to be assigned.

### 2. Add Samba Users

Users must be added to Samba's password database. Even though authentication is via LDAP, Samba requires its own passwords:

```bash
# Get the pod name
POD_NAME=$(kubectl get pods -l app.kubernetes.io/name=samba-server -o jsonpath='{.items[0].metadata.name}')

# Add a user (user must exist in LDAP)
kubectl exec -it $POD_NAME -- smbpasswd -a username
```

### 3. Test Connection

From a client machine:

```bash
# List shares
smbclient -L //<EXTERNAL-IP> -U username

# Mount a share
mount -t cifs //<EXTERNAL-IP>/sharename /mnt/share -o username=username
```

## Upgrading

```bash
# Upgrade with new values
helm upgrade samba-server ./charts/samba-server -f values.yaml

# Upgrade to a new version
helm upgrade samba-server ./charts/samba-server --version 1.2.0
```

## Uninstalling

```bash
helm uninstall samba-server
```

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -l app.kubernetes.io/name=samba-server
kubectl logs -f <pod-name>
```

### Verify LDAP Connection

```bash
POD_NAME=$(kubectl get pods -l app.kubernetes.io/name=samba-server -o jsonpath='{.items[0].metadata.name}')

# Test LDAP connectivity
kubectl exec -it $POD_NAME -- bash -c 'ldapsearch -x -H "$LDAP_URL" -b "$LDAP_SEARCH_BASE"'

# Check LDAP users
kubectl exec -it $POD_NAME -- getent passwd

# Check LDAP groups
kubectl exec -it $POD_NAME -- getent group
```

### Check Samba Status

```bash
# Check if Samba is running
kubectl exec -it $POD_NAME -- supervisorctl status smbd

# Check connected users
kubectl exec -it $POD_NAME -- smbstatus

# List Samba users
kubectl exec -it $POD_NAME -- pdbedit -L
```

### Check Health Probes

```bash
# Execute health check manually
kubectl exec -it $POD_NAME -- /healthcheck.sh
echo $?  # Should return 0 if healthy
```

### Common Issues

#### LoadBalancer Pending

If the service stays in `Pending` state:
- Ensure you have a LoadBalancer controller (MetalLB, cloud provider, etc.)
- Check LoadBalancer logs for errors

#### LDAP Users Not Showing

1. Verify LDAP configuration in values.yaml
2. Check SSSD logs: `kubectl exec -it $POD_NAME -- tail -f /var/log/sssd/sssd_ldap.log`
3. Restart SSSD: `kubectl exec -it $POD_NAME -- supervisorctl restart sssd`

#### Connection Refused

1. Verify `samba.allowHosts` includes your client's network
2. Check service external IP: `kubectl get svc samba-server`
3. Verify firewall rules allow port 445

## Examples

### Development Environment

```yaml
# dev-values.yaml
ldap:
  url: "ldap://ldap.dev.local"
  baseDN: "dc=dev,dc=local"
  userBase: "ou=users,dc=dev,dc=local"
  groupBase: "ou=groups,dc=dev,dc=local"

samba:
  allowHosts:
    - "0.0.0.0/0"  # Allow all (development only!)

resources:
  limits:
    cpu: 200m
    memory: 256Mi
```

### Production Environment

```yaml
# prod-values.yaml
replicaCount: 2

image:
  tag: "1.0.0"

ldap:
  url: "ldaps://ldap.prod.local"  # Use LDAPS in production
  baseDN: "dc=prod,dc=local"
  userBase: "ou=people,dc=prod,dc=local"
  groupBase: "ou=groups,dc=prod,dc=local"

samba:
  allowHosts:
    - "10.0.0.0/8"
    - "192.168.0.0/16"
  denyHosts:
    - "ALL"

resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 70

affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
              - key: app.kubernetes.io/name
                operator: In
                values:
                  - samba-server
          topologyKey: kubernetes.io/hostname
```

## Contributing

Contributions are welcome! Please submit issues and pull requests on the project repository.

## License

This project is provided as-is for personal and educational use.

## Support

For issues and questions:
- GitHub Issues: https://github.com/rclsilver-org/docker-samba-server
- Documentation: See main project README.md
