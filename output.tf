

output "Filesystem-Mount-Details" {
value = <<END

        NFSv3 mount for root NFS shared folder(/mnt/nfsshare/exports): sudo mount -t nfs -o vers=3,defaults,noatime,bg,timeo=100,ac,actimeo=120,nocto,rsize=1048576,wsize=1048576,nolock,local_lock=none,proto=tcp,sec=sys,_netdev  ${local.nfs_server_ip}:/mnt/nfsshare/exports  /mnt/nfs

        NFSv3 mount for NFS shared folder(/mnt/nfsshare/exports/export1): sudo mount -t nfs -o vers=3,defaults,noatime,bg,timeo=100,ac,actimeo=120,nocto,rsize=1048576,wsize=1048576,nolock,local_lock=none,proto=tcp,sec=sys,_netdev  ${local.nfs_server_ip}:/mnt/nfsshare/exports/export1  /mnt/nfs

        NFSv4 mount for root NFS shared folder(denoted as / instead of /mnt/nfsshare/exports): sudo mount -t nfs -o vers=4,defaults,noatime,bg,timeo=100,ac,actimeo=120,nocto,rsize=1048576,wsize=1048576,nolock,local_lock=none,proto=tcp,sec=sys,_netdev  ${local.nfs_server_ip}:/  /mnt/nfsv4

        NFSv4 mount for NFS shared folder(denoted as /export1 instead of /mnt/nfsshare/exports/export1): sudo mount -t nfs -o vers=4,defaults,noatime,bg,timeo=100,ac,actimeo=120,nocto,rsize=1048576,wsize=1048576,nolock,local_lock=none,proto=tcp,sec=sys,_netdev  ${local.nfs_server_ip}:/export1  /mnt/nfsv4

END
}


output "SSH-login" {
value = <<END

        Bastion: ssh -i CHANGEME ${var.ssh_user}@${element(concat(oci_core_instance.bastion.*.public_ip, [""]), 0)}

        Storage Server-1: ssh -i CHANGEME  -o BatchMode=yes -o StrictHostkeyChecking=no  -o ProxyCommand="ssh -i CHANGEME -o BatchMode=yes -o StrictHostkeyChecking=no ${var.ssh_user}@${element(concat(oci_core_instance.bastion.*.public_ip, [""]), 0)} -W %h:%p %r" ${var.ssh_user}@${element(concat(oci_core_instance.storage_server.*.private_ip, [""]), 0)}

        Client-1: ssh -i CHANGEME  -o BatchMode=yes -o StrictHostkeyChecking=no  -o ProxyCommand="ssh -i CHANGEME -o BatchMode=yes -o StrictHostkeyChecking=no ${var.ssh_user}@${element(concat(oci_core_instance.bastion.*.public_ip, [""]), 0)} -W %h:%p %r" ${var.ssh_user}@${element(concat(oci_core_instance.client_node.*.private_ip, [""]), 0)}

END
}



