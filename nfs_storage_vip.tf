
data "oci_core_vnic_attachments" "storage_server_primary_vnic_attachments" {
    #Required
    compartment_id = var.compartment_ocid

    #Optional
    instance_id = "${element(concat(oci_core_instance.storage_server.*.id, [""]), 0)}"
}


# For NFS HA - VIP
resource "oci_core_private_ip" "storage_vip_private_ip" {
    count = var.fs_ha ? 1 : 0

    #Required
    vnic_id = "${element(concat(data.oci_core_vnic_attachments.storage_server_primary_vnic_attachments.vnic_attachments.*.vnic_id,  [""]), 0)}"

    #Optional
    display_name = "storage-vip"
    hostname_label = "storage-vip"
    ip_address = var.storage_vip_private_ip
}

# All-VNICs: ${join(" ", data.oci_core_vnic_attachments.storage_server_primary_vnic_attachments.vnic_attachments.*.vnic_id)}
# prim-vnic-id: ${element(concat(data.oci_core_vnic_attachments.storage_server_primary_vnic_attachments.vnic_attachments.*.vnic_id,  [""]), 0)}

output "NFS-HA-VIP-Private-IP" {
value = <<END
${local.nfs_server_ip} (Only applicable, if HA was enabled, else its IP of single node NFS server)
END
}

