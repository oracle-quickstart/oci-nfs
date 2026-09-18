# Gets a list of Availability Domains
data "oci_identity_availability_domains" "availability_domains" {
  compartment_id = var.compartment_ocid
}

data "oci_core_instance" "storage_server" {
  count       = local.derived_storage_server_node_count
  instance_id = element(concat(oci_core_instance.storage_server.*.id, [""]), count.index)
}

data "oci_core_instance" "client_node" {
  count       = (var.create_compute_nodes ? var.client_node_count : 0)
  instance_id = element(concat(oci_core_instance.client_node.*.id, [""]), count.index)
}

data "oci_core_instance" "quorum_server" {
  count       = var.fs_ha ? 1 : 0
  instance_id = element(concat(oci_core_instance.quorum_server.*.id, [""]), count.index)
}

data "oci_core_instance" "monitoring_server" {
  count       = var.create_monitoring_server ? 1 : 0
  instance_id = element(concat(oci_core_instance.monitoring_server.*.id, [""]), count.index)
}


data "oci_core_subnet" "private_storage_subnet" {
  subnet_id = local.storage_subnet_id
}

data "oci_core_subnet" "private_fs_subnet" {
  subnet_id = local.fs_subnet_id
}

data "oci_core_subnet" "public_subnet" {
  subnet_id = local.bastion_subnet_id
}

data "oci_core_vcn" "nfs" {
  vcn_id = var.use_existing_vcn ? var.vcn_id : oci_core_virtual_network.nfs[0].id
}

data "oci_core_private_ips" "private_ips_by_vnic" {
  count = (local.storage_server_dual_nics ? (local.storage_server_hpc_shape ? 0 : local.derived_storage_server_node_count) : 0)
  #Optional
  vnic_id = element(concat(oci_core_vnic_attachment.storage_server_secondary_vnic_attachment.*.vnic_id, [""]), 0)
}

data "oci_core_images" "InstanceImageOCID" {
  compartment_id   = var.compartment_ocid
  operating_system = var.instance_os
  state            = "AVAILABLE"
  sort_by          = "TIMECREATED"
  sort_order       = "DESC"

  # OCI does not consistently return platform images when minor OS version and
  # flexible shape filters are combined. Select the standard x86 image family
  # by name, excluding aarch64 and GPU variants.
  filter {
    name   = "display_name"
    values = ["^Oracle-Linux-${replace(var.linux_os_version, ".", "\\.")}-[0-9].*$"]
    regex  = true
  }

  lifecycle {
    postcondition {
      condition     = length(self.images) > 0
      error_message = "No standard x86 ${var.instance_os} ${var.linux_os_version} platform image is available in this region."
    }
  }
}
