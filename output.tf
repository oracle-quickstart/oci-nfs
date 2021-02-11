

output "Filesystem-Mount-Details" {
value = <<END

        NFSv3 mount for root NFS shared folder (/mnt/nfsshare/exports): sudo mount -t nfs -o vers=3,defaults,noatime,bg,timeo=100,ac,actimeo=120,nocto,rsize=1048576,wsize=1048576,nolock,local_lock=none,proto=tcp,sec=sys,_netdev  ${local.nfs_server_ip}:/mnt/nfsshare/exports  /mnt/nfs


        NFSv4 mount for root NFS shared folder (/mnt/nfsshare/exports): sudo mount -t nfs -o vers=4,defaults,noatime,bg,timeo=100,ac,actimeo=120,nocto,rsize=1048576,wsize=1048576,nolock,local_lock=none,proto=tcp,sec=sys,_netdev  ${local.nfs_server_ip}:/mnt/nfsshare/exports  /mnt/nfsv4

END
}


output "SSH-login" {
value = <<END

        Bastion: ssh -i CHANGEME ${var.ssh_user}@${element(concat(oci_core_instance.bastion.*.public_ip, [""]), 0)}

        Storage Server-1: ssh -i CHANGEME  -o BatchMode=yes -o StrictHostkeyChecking=no  -o ProxyCommand="ssh -i CHANGEME -o BatchMode=yes -o StrictHostkeyChecking=no ${var.ssh_user}@${element(concat(oci_core_instance.bastion.*.public_ip, [""]), 0)} -W %h:%p %r" ${var.ssh_user}@${element(concat(oci_core_instance.storage_server.*.private_ip, [""]), 0)}

        Quorum Server: ssh -i CHANGEME  -o BatchMode=yes -o StrictHostkeyChecking=no  -o ProxyCommand="ssh -i CHANGEME -o BatchMode=yes -o StrictHostkeyChecking=no ${var.ssh_user}@${element(concat(oci_core_instance.bastion.*.public_ip, [""]), 0)} -W %h:%p %r" ${var.ssh_user}@${element(concat(oci_core_instance.quorum_server.*.private_ip, [""]), 0)}

        Client-1: ssh -i CHANGEME  -o BatchMode=yes -o StrictHostkeyChecking=no  -o ProxyCommand="ssh -i CHANGEME -o BatchMode=yes -o StrictHostkeyChecking=no ${var.ssh_user}@${element(concat(oci_core_instance.bastion.*.public_ip, [""]), 0)} -W %h:%p %r" ${var.ssh_user}@${element(concat(oci_core_instance.client_node.*.private_ip, [""]), 0)}

        Grafana-Monitor-node: ssh -i CHANGEME  -o BatchMode=yes -o StrictHostkeyChecking=no  -o ProxyCommand="ssh -i CHANGEME -o BatchMode=yes -o StrictHostkeyChecking=no ${var.ssh_user}@${element(concat(oci_core_instance.bastion.*.public_ip, [""]), 0)} -W %h:%p %r" ${var.ssh_user}@${element(concat(oci_core_instance.monitoring_server.*.private_ip, [""]), 0)}

END
}


output "bastion" {
  value = oci_core_instance.bastion[0].public_ip
}

output "storage_server_primary_vnic_private_ips" {
  value = join(" ", oci_core_instance.storage_server.*.private_ip)
}

/*
output "storage_server_secondary_vnic_private_ips" {
  value = join(" ", element(concat(data.oci_core_private_ips.private_ips_by_vnic.*.private_ips.ip_address,  list("")) , 0) )
}
*/

output "compute_private_ips" {
  value = join(" ", oci_core_instance.client_node.*.private_ip)
}

# All-VNICs: ${join(" ", data.oci_core_vnic_attachments.storage_server_vnic_attachments.vnic_attachments.*.vnic_id)}
# prim-vnic-id: ${element(concat(data.oci_core_vnic_attachments.storage_server_vnic_attachments.vnic_attachments.*.vnic_id,  [""]), 0)}
# path for 2nd VNIC is different from prim-vnic.
# secondary_vnic: ${element(concat(oci_core_vnic_attachment.storage_server_secondary_vnic_attachment.*.vnic_id,  [""]), 0)    }

output "NFS-Server-IP-to-Mount" {
value = <<END
  ${local.nfs_server_ip} (IP for NFS clients to use to mount.)
END
}


output "hacluster_user_password" {
  value = [random_string.hacluster_user_password.result]
}


