

data "oci_core_vnic_attachments" "storage_server_vnic_attachments" {
    #Required
    compartment_id = var.compartment_ocid

    #Optional
    instance_id = "${element(concat(oci_core_instance.storage_server.*.id, [""]), 0)}"
}


# For NFS HA - VIP

resource "oci_core_private_ip" "storage_vip_private_ip" {
    count = var.fs_ha ? 1 : 0

    #Required
    vnic_id = (local.storage_server_dual_nics ? (local.storage_server_hpc_shape ? element(concat(data.oci_core_vnic_attachments.storage_server_vnic_attachments.vnic_attachments.*.vnic_id,  [""]), 0) : element(concat(oci_core_vnic_attachment.storage_server_secondary_vnic_attachment.*.vnic_id,  [""]), 0)) : element(concat(data.oci_core_vnic_attachments.storage_server_vnic_attachments.vnic_attachments.*.vnic_id,  [""]), 0))

    #Optional
    display_name = "storage-vip"
    hostname_label = "storage-vip"
    ip_address = local.nfs_server_ip
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


resource "oci_core_vnic_attachment" "storage_server_secondary_vnic_attachment" {
  count = (local.storage_server_dual_nics ? (local.storage_server_hpc_shape ? "0" : local.derived_storage_server_node_count) : "0")

  #Required
  create_vnic_details {
    #Required
    subnet_id = local.fs_subnet_id

    #Optional
    assign_public_ip = "false"
    display_name     = "${local.storage_server_filesystem_vnic_hostname_prefix}${format("%01d", count.index + 1)}"
    hostname_label   = "${local.storage_server_filesystem_vnic_hostname_prefix}${format("%01d", count.index + 1)}"

    # false is default value
    skip_source_dest_check = "false"
  }
  instance_id = element(concat(oci_core_instance.storage_server.*.id, [""]), count.index)

  # set to 1, if you want to use 2nd physical NIC for this VNIC
  nic_index = (local.storage_server_dual_nics ? (local.storage_server_hpc_shape ? "0" : "1") : "0")
}


