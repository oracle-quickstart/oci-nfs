
resource "random_pet" "name" {
  length = 2
}

locals {

  cluster_name             = var.use_custom_name ? var.cluster_name : random_pet.name.id
  storage_server_hpc_shape = (length(regexall("HPC2", local.derived_storage_server_shape)) > 0 ? true : false)
  # E5 and E6 bare-metal shapes expose one network interface.  They must keep
  # the NFS VIP on the primary VNIC rather than attempting a second VNIC/NIC.
  storage_server_dual_nics = (
    length(regexall("^BM", local.derived_storage_server_shape)) > 0 &&
    !contains([
      "BM.HPC2.36",
      "BM.Standard.E5.192",
      "BM.Standard.E6.256",
      "BM.Standard.E6.Ax.192",
    ], local.derived_storage_server_shape)
  )
  #standard_storage_node_dual_nics = (length(regexall("^BM", local.derived_storage_server_shape)) > 0 ? (length(regexall("Standard",local.derived_storage_server_shape)) > 0 ? true : false) : false)
  storage_subnet_domain_name                     = "${data.oci_core_subnet.private_storage_subnet.dns_label}.${data.oci_core_vcn.nfs.dns_label}.oraclevcn.com"
  vcn_domain_name                                = "${data.oci_core_vcn.nfs.dns_label}.oraclevcn.com"
  storage_server_filesystem_vnic_hostname_prefix = "${var.storage_server_hostname_prefix}fs-vnic-"
  filesystem_subnet_domain_name                  = "${data.oci_core_subnet.private_fs_subnet.dns_label}.${data.oci_core_vcn.nfs.dns_label}.oraclevcn.com"

  is_bastion_flex_shape           = length(regexall(".*VM.*E[3-5].*Flex$", var.bastion_shape)) > 0 ? [var.bastion_ocpus] : []
  is_quorum_server_flex_shape     = length(regexall(".*VM.*E[3-5].*Flex$", var.quorum_server_shape)) > 0 ? [var.quorum_server_ocpus] : []
  is_storage_server_flex_shape    = length(regexall("^VM\\.Standard(3|4(\\.Ax)?|\\.E[3-6](\\.Ax)?)\\.Flex$", var.persistent_storage_server_shape)) > 0 ? [var.storage_server_ocpus] : []
  is_client_node_flex_shape       = length(regexall(".*VM.*E[3-5].*Flex$", var.client_node_shape)) > 0 ? [var.client_node_ocpus] : []
  is_monitoring_server_flex_shape = length(regexall(".*VM.*E[3-5].*Flex$", var.monitoring_server_shape)) > 0 ? [var.monitoring_server_ocpus] : []

  # If ad_number is non-negative use it for AD lookup, else use ad_name.
  # Allows for use of ad_number in TF deploys, and ad_name in ORM.
  # Use of max() prevents out of index lookup call.
  ad                          = var.ad_number >= 0 ? lookup(data.oci_identity_availability_domains.availability_domains.availability_domains[max(0, var.ad_number)], "name") : var.ad_name
  derived_bastion_subnet_cidr = var.bastion_subnet_cidr
  derived_storage_subnet_cidr = var.storage_subnet_cidr
  derived_fs_subnet_cidr      = var.fs_subnet_cidr
  # length(regexall("10.0.0.0/16", var.vcn_cidr)) > 0 ? "10.0.6.0/24" : var.fs_subnet_cidr
  create_fs_subnet = local.storage_server_dual_nics ? (var.use_existing_vcn ? 0 : 1) : 0


  bastion_subnet_id = var.use_existing_vcn ? var.bastion_subnet_id : element(concat(oci_core_subnet.public.*.id, [""]), 0)
  image_id          = data.oci_core_images.InstanceImageOCID.images[0].id
  storage_subnet_id = var.use_existing_vcn ? var.storage_subnet_id : element(concat(oci_core_subnet.storage.*.id, [""]), 0)
  # If shape is VM* or BM.HPC2.36, then fs_subnet_id will be set to storage_subnet_id rather than setting to "". 
  fs_subnet_id                      = var.use_existing_vcn ? (local.storage_server_dual_nics ? var.fs_subnet_id : var.storage_subnet_id) : (local.storage_server_dual_nics ? element(concat(oci_core_subnet.fs.*.id, [""]), 0) : element(concat(oci_core_subnet.storage.*.id, [""]), 0))
  client_subnet_id                  = local.fs_subnet_id
  derived_storage_server_shape      = (length(regexall("^Scratch", var.fs_type)) > 0 ? var.scratch_storage_server_shape : var.persistent_storage_server_shape)
  derived_storage_server_node_count = (var.fs_ha ? 2 : 1)

  derived_fs1_disk_count = (length(regexall("DenseIO", local.derived_storage_server_shape)) > 0 ? 0 : (var.use_non_uhp_fs1 ? var.fs1_disk_count : 0))

  nfs                         = (length(regexall("^NFS", var.fs_name)) > 0 ? true : false)
  requested_ha_vip_private_ip = var.ha_vip_private_ip == null ? "" : trimspace(var.ha_vip_private_ip)
  nfs_server_ip               = var.fs_ha ? oci_core_private_ip.storage_vip_private_ip[0].ip_address : (local.storage_server_dual_nics ? (local.storage_server_hpc_shape ? element(concat(oci_core_instance.storage_server.*.private_ip, [""]), 0) : element(concat(data.oci_core_private_ips.private_ips_by_vnic[0].private_ips.*.ip_address, [""]), 0)) : element(concat(oci_core_instance.storage_server.*.private_ip, [""]), 0))

  # Grafana monitoring
  install_monitor_agent = ((var.create_monitoring_server) ? true : false)

  # https://docs.oracle.com/en-us/iaas/Content/Compute/Tasks/edit-launch-options.htm
  # OCI lists paravirtualized networking as the default for current VM Standard
  # Flex shapes, and VM Ax Flex shapes reject explicit VFIO launch options.
  # Keep BM behavior unchanged while using the VM default for VM shapes.
  storage_server_paravirtualized_network = length(regexall("^VM\\.", local.derived_storage_server_shape)) > 0
  client_node_paravirtualized_network    = length(regexall("^VM\\.", var.client_node_shape)) > 0
  quorum_server_paravirtualized_network  = length(regexall("^VM\\.", var.quorum_server_shape)) > 0

  server_network_type        = local.storage_server_paravirtualized_network ? "PARAVIRTUALIZED" : "VFIO"
  client_network_type        = local.client_node_paravirtualized_network ? "PARAVIRTUALIZED" : "VFIO"
  quorum_server_network_type = local.quorum_server_paravirtualized_network ? "PARAVIRTUALIZED" : "VFIO"

}
