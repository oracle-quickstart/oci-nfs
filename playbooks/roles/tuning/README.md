# NFS HA tuning role

This opt-in role runs on the `storage` and `compute` inventory groups before
storage, Pacemaker, and NFS-client configuration. It installs and activates a
local `tuned` profile at `/etc/tuned/nfs-ha-oci-performance/tuned.conf`.

Enable it only after workload testing by setting this in
`inventory/group_vars/all.yml`:

```yaml
nfs_ha_tuning_enabled: true
```

The profile tunes CPU power policy, disables Transparent Huge Pages, and
increases TCP/NFS RPC buffer and slot-table limits. It does **not** disable
SELinux, set a fixed `vm.min_free_kbytes`, modify storage-device queues, force
NIC ring sizes/queues, or disable SMT. Those legacy changes were not portable
across OCI shapes and are intentionally excluded.

The same profile is applied to both NFS nodes so an HA failover does not change
the server performance configuration. NFS clients receive the TCP/RPC tuning
too; clients must still mount the cluster VIP, not an individual NFS node.

## Optional NIC tuning

`tasks/nic.yml` is a separate task and is disabled by default. It never guesses
an interface name and does not create an `/etc/rc.local` entry. First inspect
the exact target shape and interface:

```bash
sudo ethtool -g ens3
sudo ethtool -l ens3
```

Then enable it with values that do not exceed the reported pre-set maximums:

```yaml
nfs_ha_tuning_nic_enabled: true
nfs_ha_tuning_nic_interfaces:
  - ens3
nfs_ha_tuning_nic_rx_ring: 1024
nfs_ha_tuning_nic_tx_ring: 1024
nfs_ha_tuning_nic_combined_queues: 4
```

Use the actual OCI guest interface name. For a bare-metal HA server with a
second filesystem VNIC, list both physical interfaces only after validating
each one. Values are runtime-only and must be re-applied after reboot unless a
shape-specific, separately reviewed persistence mechanism is added.
