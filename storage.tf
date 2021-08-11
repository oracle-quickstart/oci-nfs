
resource "oci_core_volume" "fs1_blockvolume" {
  count = (var.fs_ha ? (local.derived_storage_server_node_count/2)*local.derived_fs1_disk_count : local.derived_fs1_disk_count * local.derived_storage_server_node_count)
  availability_domain = local.ad
  compartment_id      = var.compartment_ocid
  display_name        = "${local.cluster_name}_xfs1-target${count.index % local.derived_fs1_disk_count + 1}"

  size_in_gbs         = var.fs1_disk_size
  vpus_per_gb         = var.volume_type_vpus_per_gb_mapping[(var.fs1_disk_perf_tier)]
}


resource "oci_core_volume_attachment" "fs1_blockvolume_attach" {
  attachment_type = "iscsi"
  count = (local.derived_storage_server_node_count * local.derived_fs1_disk_count)

  instance_id = element(oci_core_instance.storage_server.*.id, (var.fs_ha ? ((count.index % 2) + (floor(count.index/(local.derived_fs1_disk_count*2))*2))   : count.index % local.derived_storage_server_node_count),)
  volume_id = element(oci_core_volume.fs1_blockvolume.*.id, (var.fs_ha ? floor(count.index/2) : count.index))
  is_shareable = var.fs_ha ? true : false
  # A  "+ 1" was added to "floor(count.index/2) + 1" to start from /dev/oracleoci/oraclevdc instead of /dev/oracleoci/oraclevdb, since we need the /dev/oracleoci/oraclevdb for stonith_fencing device.
  ##device       = var.volume_attach_device_mapping[((var.fs_ha ? floor(count.index/2) + 1 : count.index % local.derived_fs1_disk_count))]
  
  # If uhp is used and HA, then /dev/oracleoci/oraclevdc is reserved for uhp. Non-uhp starts from /dev/oracleoci/oraclevdd
  # with uhp logic
  device       = var.use_uhp ? ( var.volume_attach_device_mapping[(var.fs_ha ? floor(count.index/2) + 2 : (count.index % local.derived_fs1_disk_count) + 1 )] ) : ( var.volume_attach_device_mapping[(var.fs_ha ? floor(count.index/2) + 1 : count.index % local.derived_fs1_disk_count)] )
  

  provisioner "remote-exec" {
    connection {
      agent   = false
      timeout = "30m"
      host    = element(oci_core_instance.storage_server.*.private_ip, (var.fs_ha ? ((count.index % 2) + (floor(count.index/(local.derived_fs1_disk_count*2))*2))   : count.index % local.derived_storage_server_node_count)
      )

      user                = var.ssh_user
      private_key         = tls_private_key.ssh.private_key_pem
      bastion_host        = oci_core_instance.bastion[0].public_ip
      bastion_port        = "22"
      bastion_user        = var.ssh_user
      bastion_private_key = tls_private_key.ssh.private_key_pem

    }

    inline = [
      "sudo -s bash -c 'set -x && iscsiadm -m node -o new -T ${self.iqn} -p ${self.ipv4}:${self.port}'",
      "sudo -s bash -c 'set -x && iscsiadm -m node -o update -T ${self.iqn} -n node.startup -v automatic '",
      "sudo -s bash -c 'set -x && iscsiadm -m node -T ${self.iqn} -p ${self.ipv4}:${self.port} -l '",
    ]
  }
}



resource "null_resource" "notify_storage_server_nodes_fs1_block_attach_complete" {
  depends_on = [ oci_core_volume_attachment.fs1_blockvolume_attach ]
  count = local.derived_storage_server_node_count
  provisioner "remote-exec" {
    connection {
        agent               = false
        timeout             = "30m"
        host                = element(oci_core_instance.storage_server.*.private_ip, count.index)
        user                = var.ssh_user
        private_key         = tls_private_key.ssh.private_key_pem
        bastion_host        = oci_core_instance.bastion.*.public_ip[0]
        bastion_port        = "22"
        bastion_user        = var.ssh_user
        bastion_private_key = tls_private_key.ssh.private_key_pem
    }
    inline = [
      "set -x",
      "sudo touch /tmp/block-attach.complete",
    ]
  }
}


resource "oci_core_volume" "fs2_blockvolume" {
  count = (var.fs_ha ? (local.derived_storage_server_node_count/2)*local.derived_fs2_disk_count : local.derived_fs2_disk_count * local.derived_storage_server_node_count)
  availability_domain = local.ad
  compartment_id      = var.compartment_ocid
  display_name        = "${local.cluster_name}_xfs2-target${count.index % local.derived_fs2_disk_count + 1}"

  size_in_gbs         = var.fs2_disk_size
  vpus_per_gb         = var.volume_type_vpus_per_gb_mapping[(var.fs2_disk_perf_tier)]
}


resource "oci_core_volume_attachment" "fs2_blockvolume_attach" {
  attachment_type = "iscsi"
  count = (local.derived_storage_server_node_count * local.derived_fs2_disk_count)

  instance_id = element(oci_core_instance.storage_server.*.id, (var.fs_ha ? ((count.index % 2) + (floor(count.index/(local.derived_fs2_disk_count*2))*2))   : count.index % local.derived_storage_server_node_count),)
  volume_id = element(oci_core_volume.fs2_blockvolume.*.id, (var.fs_ha ? floor(count.index/2) : count.index))
  is_shareable = var.fs_ha ? true : false
  # A  "+ 1" was added to "floor(count.index/2) + 1" to start from /dev/oracleoci/oraclevdc instead of /dev/oracleoci/oraclevdb, since we need the /dev/oracleoci/oraclevdb for stonith_fencing device.
  ##device       = var.volume_attach_device_mapping[((var.fs_ha ? floor(count.index/2) + 1 : count.index % local.derived_fs2_disk_count))]
  
  # If uhp is used and HA, then /dev/oracleoci/oraclevdc is reserved for uhp. Non-uhp starts from /dev/oracleoci/oraclevdd
  # with uhp logic
  device       = var.use_uhp ? ( var.volume_attach_device_mapping[(var.fs_ha ? floor(count.index/2) + 2 + local.derived_fs1_disk_count: (count.index % local.derived_fs2_disk_count) + 1 + local.derived_fs1_disk_count)] ) : ( var.volume_attach_device_mapping[(var.fs_ha ? floor(count.index/2) + 1 + local.derived_fs1_disk_count : (count.index % local.derived_fs2_disk_count) + local.derived_fs1_disk_count )] )
  

  provisioner "remote-exec" {
    connection {
      agent   = false
      timeout = "30m"
      host    = element(oci_core_instance.storage_server.*.private_ip, (var.fs_ha ? ((count.index % 2) + (floor(count.index/(local.derived_fs2_disk_count*2))*2))   : count.index % local.derived_storage_server_node_count)
      )

      user                = var.ssh_user
      private_key         = tls_private_key.ssh.private_key_pem
      bastion_host        = oci_core_instance.bastion[0].public_ip
      bastion_port        = "22"
      bastion_user        = var.ssh_user
      bastion_private_key = tls_private_key.ssh.private_key_pem

    }

    inline = [
      "sudo -s bash -c 'set -x && iscsiadm -m node -o new -T ${self.iqn} -p ${self.ipv4}:${self.port}'",
      "sudo -s bash -c 'set -x && iscsiadm -m node -o update -T ${self.iqn} -n node.startup -v automatic '",
      "sudo -s bash -c 'set -x && iscsiadm -m node -T ${self.iqn} -p ${self.ipv4}:${self.port} -l '",
    ]
  }
}


resource "null_resource" "notify_storage_server_nodes_fs2_block_attach_complete" {
  depends_on = [ oci_core_volume_attachment.fs2_blockvolume_attach ]
  count = local.derived_storage_server_node_count
  provisioner "remote-exec" {
    connection {
        agent               = false
        timeout             = "30m"
        host                = element(oci_core_instance.storage_server.*.private_ip, count.index)
        user                = var.ssh_user
        private_key         = tls_private_key.ssh.private_key_pem
        bastion_host        = oci_core_instance.bastion.*.public_ip[0]
        bastion_port        = "22"
        bastion_user        = var.ssh_user
        bastion_private_key = tls_private_key.ssh.private_key_pem
    }
    inline = [
      "set -x",
      "sudo touch /tmp/block-attach.complete",
    ]
  }
}


resource "oci_core_volume" "fs3_blockvolume" {
  count = (var.fs_ha ? (local.derived_storage_server_node_count/2)*local.derived_fs3_disk_count : local.derived_fs3_disk_count * local.derived_storage_server_node_count)
  availability_domain = local.ad
  compartment_id      = var.compartment_ocid
  display_name        = "${local.cluster_name}_xfs3-target${count.index % local.derived_fs3_disk_count + 1}"

  size_in_gbs         = var.fs3_disk_size
  vpus_per_gb         = var.volume_type_vpus_per_gb_mapping[(var.fs3_disk_perf_tier)]
}


resource "oci_core_volume_attachment" "fs3_blockvolume_attach" {
  attachment_type = "iscsi"
  count = (local.derived_storage_server_node_count * local.derived_fs3_disk_count)

  instance_id = element(oci_core_instance.storage_server.*.id, (var.fs_ha ? ((count.index % 2) + (floor(count.index/(local.derived_fs3_disk_count*2))*2))   : count.index % local.derived_storage_server_node_count),)
  volume_id = element(oci_core_volume.fs3_blockvolume.*.id, (var.fs_ha ? floor(count.index/2) : count.index))
  is_shareable = var.fs_ha ? true : false
  # A  "+ 1" was added to "floor(count.index/2) + 1" to start from /dev/oracleoci/oraclevdc instead of /dev/oracleoci/oraclevdb, since we need the /dev/oracleoci/oraclevdb for stonith_fencing device.
  ##device       = var.volume_attach_device_mapping[((var.fs_ha ? floor(count.index/2) + 1 : count.index % local.derived_fs3_disk_count))]
  
  # If uhp is used and HA, then /dev/oracleoci/oraclevdc is reserved for uhp. Non-uhp starts from /dev/oracleoci/oraclevdd
  # with uhp logic
  device       = var.use_uhp ? ( var.volume_attach_device_mapping[(var.fs_ha ? floor(count.index/2) + 2 + local.derived_fs1_disk_count + local.derived_fs2_disk_count: (count.index % local.derived_fs3_disk_count) + 1 + local.derived_fs1_disk_count + local.derived_fs2_disk_count )] ) : ( var.volume_attach_device_mapping[(var.fs_ha ? floor(count.index/2) + 1 + local.derived_fs1_disk_count + local.derived_fs2_disk_count: (count.index % local.derived_fs3_disk_count) + local.derived_fs1_disk_count + local.derived_fs2_disk_count  )] )
  

  provisioner "remote-exec" {
    connection {
      agent   = false
      timeout = "30m"
      host    = element(oci_core_instance.storage_server.*.private_ip, (var.fs_ha ? ((count.index % 2) + (floor(count.index/(local.derived_fs3_disk_count*2))*2))   : count.index % local.derived_storage_server_node_count)
      )

      user                = var.ssh_user
      private_key         = tls_private_key.ssh.private_key_pem
      bastion_host        = oci_core_instance.bastion[0].public_ip
      bastion_port        = "22"
      bastion_user        = var.ssh_user
      bastion_private_key = tls_private_key.ssh.private_key_pem

    }

    inline = [
      "sudo -s bash -c 'set -x && iscsiadm -m node -o new -T ${self.iqn} -p ${self.ipv4}:${self.port}'",
      "sudo -s bash -c 'set -x && iscsiadm -m node -o update -T ${self.iqn} -n node.startup -v automatic '",
      "sudo -s bash -c 'set -x && iscsiadm -m node -T ${self.iqn} -p ${self.ipv4}:${self.port} -l '",
    ]
  }
}


resource "null_resource" "notify_storage_server_nodes_fs3_block_attach_complete" {
  depends_on = [ oci_core_volume_attachment.fs3_blockvolume_attach ]
  count = local.derived_storage_server_node_count
  provisioner "remote-exec" {
    connection {
        agent               = false
        timeout             = "30m"
        host                = element(oci_core_instance.storage_server.*.private_ip, count.index)
        user                = var.ssh_user
        private_key         = tls_private_key.ssh.private_key_pem
        bastion_host        = oci_core_instance.bastion.*.public_ip[0]
        bastion_port        = "22"
        bastion_user        = var.ssh_user
        bastion_private_key = tls_private_key.ssh.private_key_pem
    }
    inline = [
      "set -x",
      "sudo touch /tmp/block-attach.complete",
    ]
  }
}




resource "oci_core_volume" "stonith_fencing_blockvolume" {
  count = (var.fs_ha ? 1 : 0)
  availability_domain = local.ad
  compartment_id      = var.compartment_ocid
  display_name        = "${local.cluster_name}_nfs-stonith-fencing-sbd"
  size_in_gbs         = "50"
  #  Lower cost Block volume
  vpus_per_gb         = "10"
}


resource "oci_core_volume_attachment" "stonith_fencing_blockvolume_attach" {
  attachment_type = "iscsi"
  count = (var.fs_ha ? 2 : 0)

  instance_id = element(oci_core_instance.storage_server.*.id, count.index, )
  volume_id = element(oci_core_volume.stonith_fencing_blockvolume.*.id, 0)
  is_shareable = var.fs_ha ? true : false
  device       = var.volume_attach_device_mapping[0]


  provisioner "remote-exec" {
    connection {
      agent   = false
      timeout = "30m"
      host    = element(oci_core_instance.storage_server.*.private_ip, count.index )

      user                = var.ssh_user
      private_key         = tls_private_key.ssh.private_key_pem
      bastion_host        = oci_core_instance.bastion[0].public_ip
      bastion_port        = "22"
      bastion_user        = var.ssh_user
      bastion_private_key = tls_private_key.ssh.private_key_pem

    }

    inline = [
      "sudo -s bash -c 'set -x && iscsiadm -m node -o new -T ${self.iqn} -p ${self.ipv4}:${self.port}'",
      "sudo -s bash -c 'set -x && iscsiadm -m node -o update -T ${self.iqn} -n node.startup -v automatic '",
      "sudo -s bash -c 'set -x && iscsiadm -m node -T ${self.iqn} -p ${self.ipv4}:${self.port} -l '",
    ]
  }
}



resource "null_resource" "notify_storage_server_nodes_stonith_fencing_block_attach_complete" {
  depends_on = [ oci_core_volume_attachment.stonith_fencing_blockvolume_attach ]
  count = (var.fs_ha ? 2 : 0)
  provisioner "remote-exec" {
    connection {
        agent               = false
        timeout             = "30m"
        host                = element(oci_core_instance.storage_server.*.private_ip, count.index)
        user                = var.ssh_user
        private_key         = tls_private_key.ssh.private_key_pem
        bastion_host        = oci_core_instance.bastion.*.public_ip[0]
        bastion_port        = "22"
        bastion_user        = var.ssh_user
        bastion_private_key = tls_private_key.ssh.private_key_pem
    }
    inline = [
      "set -x",
      "sudo touch /tmp/stonith_fencing_block-attach.complete",
    ]
  }
}



resource "oci_core_volume" "uhp_blockvolume" {
  count = var.use_uhp ? 1 : 0
  availability_domain = local.ad
  compartment_id      = var.compartment_ocid
  display_name        = "${local.cluster_name}_xfs-uhp-target1"
  #  UHP Block volume
  size_in_gbs         = var.uhp_fs0_disk_size
  vpus_per_gb         = var.volume_type_vpus_per_gb_mapping[(var.uhp_fs0_disk_perf_tier)]
    
}


resource "oci_core_volume_attachment" "uhp_blockvolume_attach" {
  attachment_type = "iscsi"
  count = var.use_uhp ? (var.fs_ha ? 2 : 1) : 0

  instance_id = element(oci_core_instance.storage_server.*.id, count.index, )
  volume_id = element(oci_core_volume.uhp_blockvolume.*.id, 0)
  is_shareable = var.fs_ha ? true : false
  device       = var.fs_ha ? var.volume_attach_device_mapping[1] : var.volume_attach_device_mapping[0]


  /*
  NOTE: FOR UHP, Block Plugin does login for iSCSI. The below remote-exec is not required.
  provisioner "remote-exec" {
    connection {
      agent   = false
      timeout = "30m"
      host    = element(oci_core_instance.storage_server.*.private_ip, count.index )

      user                = var.ssh_user
      private_key         = tls_private_key.ssh.private_key_pem
      bastion_host        = oci_core_instance.bastion[0].public_ip
      bastion_port        = "22"
      bastion_user        = var.ssh_user
      bastion_private_key = tls_private_key.ssh.private_key_pem

    }

    inline = [
      "/usr/bin/hostname",
      "sudo -s bash -c 'set -x && iscsiadm -m node -o new -T ${self.iqn} -p ${self.ipv4}:${self.port}'",
      "sudo -s bash -c 'set -x && iscsiadm -m node -o update -T ${self.iqn} -n node.startup -v automatic '",
      "sudo -s bash -c 'set -x && iscsiadm -m node -T ${self.iqn} -p ${self.ipv4}:${self.port} -l '",
    ]
  }
  */
  
}


/*
  NOTE: FOR UHP, Block Plugin does login for iSCSI.
  Hence the below is not required and to confirm attach complete, do a check before using the volume (see _nfs_install_storage.sh.j2)
*/
/*
resource "null_resource" "notify_storage_server_nodes_uhp_block_attach_complete" {
  depends_on = [ oci_core_volume_attachment.uhp_blockvolume_attach ]
  count = var.use_uhp ? (var.fs_ha ? 2 : 1) : 0
  provisioner "remote-exec" {
    connection {
        agent               = false
        timeout             = "30m"
        host                = element(oci_core_instance.storage_server.*.private_ip, count.index)
        user                = var.ssh_user
        private_key         = tls_private_key.ssh.private_key_pem
        bastion_host        = oci_core_instance.bastion.*.public_ip[0]
        bastion_port        = "22"
        bastion_user        = var.ssh_user
        bastion_private_key = tls_private_key.ssh.private_key_pem
    }
    inline = [
      "set -x",
      "sudo touch /tmp/uhp_block-attach.complete",
    ]
  }
}
*/


