# Samba Share Configurations

This directory contains Samba share configuration files. Each `.conf` file defines one or more SMB shares.

## Usage

All `.conf` files in this directory are automatically loaded by Samba in alphabetical order. The directory is mounted into the container at `/etc/samba/conf.d/`.

## Example Configurations

This directory includes several example share configurations:

- **homes.conf**: Personal home directories for each user
- **downloads.conf**: Shared downloads folder for the `downloads` group
- **music.conf**: Shared music library for the `music` group
- **videos.conf**: Shared video library for the `videos` group

## Creating Your Own Shares

### Basic Share

```ini
[sharename]
  path = /path/to/directory
  browseable = yes
  read only = no
  valid users = user1 user2
  create mask = 0664
  directory mask = 0775
```

### Group-based Share

```ini
[groupshare]
  path = /path/to/directory
  browseable = yes
  read only = no
  valid users = @groupname
  force group = groupname
  create mask = 0664
  directory mask = 02775
```

### Read-only Share

```ini
[readonly]
  path = /path/to/directory
  browseable = yes
  read only = yes
  valid users = @users
```

### Public Share (Guest Access)

```ini
[public]
  path = /path/to/directory
  browseable = yes
  read only = yes
  guest ok = yes
  guest only = yes
```

## Common Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `path` | Physical path to the share | `/media/data` |
| `browseable` | Show share in network browser | `yes` or `no` |
| `read only` | Make share read-only | `yes` or `no` |
| `valid users` | Users/groups allowed access | `user1 @group1` |
| `create mask` | Default permissions for new files | `0664` |
| `directory mask` | Default permissions for new directories | `0775` |
| `force group` | Force all files to belong to a group | `groupname` |
| `force user` | Force all files to belong to a user | `username` |
| `guest ok` | Allow guest access | `yes` or `no` |

## Tips

1. **Use LDAP groups**: Prefix group names with `@` (e.g., `@media-users`)
2. **Set permissions**: Use `create mask` and `directory mask` to control file permissions
3. **Force ownership**: Use `force group` to ensure consistent group ownership
4. **Test access**: Use `smbclient` to test share access before mounting

## Testing

```bash
# List available shares
smbclient -L localhost -U username

# Connect to a share
smbclient //localhost/sharename -U username

# Test with specific user
docker compose exec samba smbclient //localhost/sharename -U username
```

## See Also

- [Samba Share Configuration Documentation](https://www.samba.org/samba/docs/current/man-html/smb.conf.5.html)
- Main project README.md for LDAP and user setup
