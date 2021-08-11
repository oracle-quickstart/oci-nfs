[bastion]
${bastion_name} ansible_host=${bastion_ip} ansible_user=opc role=bastion
[storage]
%{ for host, ip in storage ~}
${host} ansible_host=${ip} ansible_user=opc role=storage
%{ endfor ~}
[quorum]
%{ for host, ip in quorum ~}
${host} ansible_host=${ip} ansible_user=opc role=quorum
%{ endfor ~}
[compute]
%{ for host, ip in compute ~}
${host} ansible_host=${ip} ansible_user=opc role=compute
%{ endfor ~}
[monitor]
%{ for host, ip in monitor ~}
${host} ansible_host=${ip} ansible_user=opc role=monitor
%{ endfor ~}
[all:children]
bastion
storage
compute
quorum
monitor
[all:vars]
ansible_connection=ssh
ansible_user=opc
fs_name=${fs_name}
fs_type=${fs_type}
fs_ha=${fs_ha}
vcn_domain_name=${vcn_domain_name}
public_subnet_cidr_block=${public_subnet_cidr_block}
private_storage_subnet_cidr_block=${private_storage_subnet_cidr_block}
private_storage_subnet_dns_label=${private_storage_subnet_dns_label}
storage_subnet_domain_name=${storage_subnet_domain_name}
storage_server_node_count=${storage_server_node_count}
mount_point=${mount_point}
block_size=${block_size}
storage_server_hostname_prefix=${storage_server_hostname_prefix}
hacluster_user_password=${hacluster_user_password}
ipaddr2_vip_name="nfs_VIP"
lv_name="disk"
vg_name="vg_nfs_disk"
nfs_server_ip=${nfs_server_ip}
storage_server_filesystem_vnic_hostname_prefix=${storage_server_filesystem_vnic_hostname_prefix}
private_fs_subnet_dns_label=${private_fs_subnet_dns_label}
filesystem_subnet_domain_name=${filesystem_subnet_domain_name}
storage_server_dual_nics=${storage_server_dual_nics}
private_fs_subnet_cidr_block=${private_fs_subnet_cidr_block}
quorum_server_hostname=${quorum_server_hostname}
install_monitor_agent=${install_monitor_agent}

use_uhp=${use_uhp}

use_non_uhp_fs1=${use_non_uhp_fs1}
use_non_uhp_fs2=${use_non_uhp_fs2}
use_non_uhp_fs3=${use_non_uhp_fs3}

fs1_disk_perf_tier=${fs1_disk_perf_tier}
fs1_disk_count=${fs1_disk_count}
fs1_disk_size=${fs1_disk_size}

fs2_disk_perf_tier=${fs2_disk_perf_tier}
fs2_disk_count=${fs2_disk_count}
fs2_disk_size=${fs2_disk_size}

fs3_disk_perf_tier=${fs3_disk_perf_tier}
fs3_disk_count=${fs3_disk_count}
fs3_disk_size=${fs3_disk_size}

fs0_name=uhp_nfsshare
fs1_name=nfsshare
fs2_name=nfsshare2
fs3_name=nfsshare3
fs0_lv_name="disk0"
fs0_vg_name="vg_nfs_disk0"
fs1_lv_name="disk"
fs1_vg_name="vg_nfs_disk"
fs2_lv_name="disk2"
fs2_vg_name="vg_nfs_disk2"
fs3_lv_name="disk3"
fs3_vg_name="vg_nfs_disk3"
fs0_dir="/mnt/uhp_nfsshare"
fs1_dir="/mnt/nfsshare"
fs2_dir="/mnt/nfsshare2"
fs3_dir="/mnt/nfsshare3"

