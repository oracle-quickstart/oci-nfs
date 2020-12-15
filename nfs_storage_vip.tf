

data "oci_core_vnic_attachments" "storage_server_vnic_attachments" {
    #Required
    compartment_id = var.compartment_ocid

    #Optional
    instance_id = element(concat(oci_core_instance.storage_server.*.id, [""]), 0)
}


# For NFS HA - VIP
resource "oci_core_private_ip" "storage_vip_private_ip" {
    count = var.fs_ha ? 1 : 0

    #Required
    vnic_id = (local.storage_server_dual_nics ? (local.storage_server_hpc_shape ? element(concat(data.oci_core_vnic_attachments.storage_server_vnic_attachments.vnic_attachments.*.vnic_id,  [""]), 0) : element(concat(oci_core_vnic_attachment.storage_server_secondary_vnic_attachment.*.vnic_id,  [""]), 0)) : element(concat(data.oci_core_vnic_attachments.storage_server_vnic_attachments.vnic_attachments.*.vnic_id,  [""]), 0))

    display_name = "nfs-vip"
    # If user doesn't provide a hostname, use random xxx-xxx string for uniqueness.
    hostname_label = length(var.ha_vip_hostname) > 0 ? var.ha_vip_hostname : random_pet.name.id
    ip_address = local.nfs_server_ip
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


