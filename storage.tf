
resource "oci_core_volume" "storage_tier_blockvolume" {
  count = (var.fs_ha ? (local.derived_storage_server_node_count/2)*local.derived_storage_server_disk_count : local.derived_storage_server_disk_count * local.derived_storage_server_node_count)
  availability_domain = local.ad
  compartment_id      = var.compartment_ocid
  display_name        = "nfs-target${count.index % local.derived_storage_server_disk_count + 1}"

  size_in_gbs         = var.storage_tier_1_disk_size
  vpus_per_gb         = var.volume_type_vpus_per_gb_mapping[(var.storage_tier_1_disk_perf_tier)]
}


resource "oci_core_volume_attachment" "storage_tier_blockvolume_attach" {
  attachment_type = "iscsi"
  count = (local.derived_storage_server_node_count * local.derived_storage_server_disk_count)

  instance_id = element(oci_core_instance.storage_server.*.id, (var.fs_ha ? ((count.index % 2) + (floor(count.index/(local.derived_storage_server_disk_count*2))*2))   : count.index % local.derived_storage_server_node_count),)
  volume_id = element(oci_core_volume.storage_tier_blockvolume.*.id, (var.fs_ha ? floor(count.index/2) : count.index))
  is_shareable = var.fs_ha ? true : false
  # A  "+ 1" was added to "floor(count.index/2) + 1" to start from /dev/oracleoci/oraclevdc instead of /dev/oracleoci/oraclevdb, since we need the /dev/oracleoci/oraclevdb for stonith_fencing device.
  device       = var.volume_attach_device_mapping[((var.fs_ha ? floor(count.index/2) + 1 : count.index % local.derived_storage_server_disk_count))]


  provisioner "remote-exec" {
    connection {
      agent   = false
      timeout = "30m"
      host    = element(oci_core_instance.storage_server.*.private_ip, (var.fs_ha ? ((count.index % 2) + (floor(count.index/(local.derived_storage_server_disk_count*2))*2))   : count.index % local.derived_storage_server_node_count)
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



resource "null_resource" "notify_storage_server_nodes_block_attach_complete" {
  depends_on = [ oci_core_volume_attachment.storage_tier_blockvolume_attach ]
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
  display_name        = "nfs-stonith-fencing-sbd"
  size_in_gbs         = "50"
  #  Lower cost Block volume
  vpus_per_gb         = "0"
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


