# HA NFS failover test

Use the test-cluster bastion as the Ansible control host. Run commands from the
`playbooks` directory.

## Before the test

Confirm both storage nodes are online and the NFS resource group is healthy:

```bash
ansible -i inventory/inventory storage -b -m command -a "pcs status --full"
```

Expected group order:

```text
nfsgroup: disk nfsshare nfs-daemon OCIVIP
```

Do not begin the test if either storage node is offline, if a resource is
stopped, or if `vg_nfs_disk` is not visible to Pacemaker.

## Controlled failover

Move the complete group to the standby node:

```bash
ansible -i inventory/inventory nfs-server-1 -b -m command \
  -a "pcs resource move nfsgroup nfs-server-2"
```

Check cluster status until all group resources run on `nfs-server-2`:

```bash
ansible -i inventory/inventory storage -b -m command -a "pcs status --full"
```

Verify that `disk`, `nfsshare`, `nfs-daemon`, and `OCIVIP` moved together. If a
client is configured, confirm its NFS mount remains available and that a test
file can be read and written.

## Recovery

Remove the temporary move constraint after the test:

```bash
ansible -i inventory/inventory nfs-server-1 -b -m command \
  -a "pcs resource clear nfsgroup"
```

If Pacemaker records a failed LVM activation, repair the underlying LVM issue
first, then clear the failure state:

```bash
ansible -i inventory/inventory nfs-server-1 -b -m command \
  -a "pcs resource cleanup disk"
```
