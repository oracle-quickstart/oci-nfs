
resource "random_pet" "name" {
  length = 2
}

locals {

  cluster_name = var.use_custom_name ? var.cluster_name : random_pet.name.id
  storage_server_hpc_shape = (length(regexall("HPC2", local.derived_storage_server_shape)) > 0 ? true : false)
  storage_server_dual_nics = (length(regexall("^BM", local.derived_storage_server_shape)) > 0 ? (local.storage_server_hpc_shape ? false : true) : false)
  #standard_storage_node_dual_nics = (length(regexall("^BM", local.derived_storage_server_shape)) > 0 ? (length(regexall("Standard",local.derived_storage_server_shape)) > 0 ? true : false) : false)
  storage_subnet_domain_name = "${data.oci_core_subnet.private_storage_subnet.dns_label}.${data.oci_core_vcn.nfs.dns_label}.oraclevcn.com"
  vcn_domain_name = "${data.oci_core_vcn.nfs.dns_label}.oraclevcn.com"
  storage_server_filesystem_vnic_hostname_prefix = "${var.storage_server_hostname_prefix}fs-vnic-"
  filesystem_subnet_domain_name = "${data.oci_core_subnet.private_fs_subnet.dns_label}.${data.oci_core_vcn.nfs.dns_label}.oraclevcn.com"


  #is_bastion_flex_shape = var.bastion_shape == "VM.Standard.E3.Flex" ? [var.bastion_ocpus]:[]
  #is_quorum_server_flex_shape = var.quorum_server_shape == "VM.Standard.E3.Flex" ? [var.quorum_server_ocpus]:[]
  #is_storage_server_flex_shape = var.persistent_storage_server_shape == "VM.Standard.E3.Flex" ? [var.storage_server_ocpus]:[]
  #is_client_node_flex_shape = var.client_node_shape == "VM.Standard.E3.Flex" ? [var.client_node_ocpus]:[]
  #is_monitoring_server_flex_shape = var.monitoring_server_shape == "VM.Standard.E3.Flex" ? [var.monitoring_server_ocpus]:[]
  
  
  is_bastion_flex_shape = length(regexall(".*VM.*E[3-4].*Flex$", var.bastion_shape)) > 0 ? [var.bastion_ocpus]:[]
  is_quorum_server_flex_shape = length(regexall(".*VM.*E[3-4].*Flex$", var.quorum_server_shape)) > 0 ? [var.quorum_server_ocpus]:[]
  is_storage_server_flex_shape = length(regexall(".*VM.*E[3-4].*Flex$", var.persistent_storage_server_shape)) > 0 ? [var.storage_server_ocpus]:[]
  is_client_node_flex_shape = length(regexall(".*VM.*E[3-4].*Flex$", var.client_node_shape)) > 0 ? [var.client_node_ocpus]:[]
  is_monitoring_server_flex_shape = length(regexall(".*VM.*E[3-4].*Flex$", var.monitoring_server_shape)) > 0 ? [var.monitoring_server_ocpus]:[]
  
  # If ad_number is non-negative use it for AD lookup, else use ad_name.
  # Allows for use of ad_number in TF deploys, and ad_name in ORM.
  # Use of max() prevents out of index lookup call.
  ad = var.ad_number >= 0 ? lookup(data.oci_identity_availability_domains.availability_domains.availability_domains[max(0,var.ad_number)],"name") : var.ad_name
  derived_bastion_subnet_cidr = var.bastion_subnet_cidr
  derived_storage_subnet_cidr = var.storage_subnet_cidr
  derived_fs_subnet_cidr = var.fs_subnet_cidr
  # length(regexall("10.0.0.0/16", var.vcn_cidr)) > 0 ? "10.0.6.0/24" : var.fs_subnet_cidr
  create_fs_subnet = local.storage_server_dual_nics ? (var.use_existing_vcn ? 0 : 1) : 0


  bastion_subnet_id = var.use_existing_vcn ? var.bastion_subnet_id : element(concat(oci_core_subnet.public.*.id, [""]), 0)
  image_id          = (var.use_marketplace_image ? var.mp_listing_resource_id : data.oci_core_images.InstanceImageOCID.images.0.id)
  storage_subnet_id = var.use_existing_vcn ? var.storage_subnet_id : element(concat(oci_core_subnet.storage.*.id, [""]), 0)
  # If shape is VM* or BM.HPC2.36, then fs_subnet_id will be set to storage_subnet_id rather than setting to "". 
  fs_subnet_id        = var.use_existing_vcn ? (local.storage_server_dual_nics ? var.fs_subnet_id : var.storage_subnet_id) : (local.storage_server_dual_nics ? element(concat(oci_core_subnet.fs.*.id, [""]), 0) :  element(concat(oci_core_subnet.storage.*.id, [""]), 0))
  client_subnet_id    = local.fs_subnet_id
  derived_storage_server_shape = (length(regexall("^Scratch", var.fs_type)) > 0 ? var.scratch_storage_server_shape : var.persistent_storage_server_shape)
  derived_storage_server_node_count = (var.fs_ha ? 2 : 1)
  
  derived_fs1_disk_count = (length(regexall("DenseIO",local.derived_storage_server_shape)) > 0 ? 0 : (var.use_non_uhp_fs1 ? var.fs1_disk_count : 0) )
  derived_fs2_disk_count = (length(regexall("DenseIO",local.derived_storage_server_shape)) > 0 ? 0 : (var.use_non_uhp_fs2 ? var.fs2_disk_count : 0) )
  derived_fs3_disk_count = (length(regexall("DenseIO",local.derived_storage_server_shape)) > 0 ? 0 : (var.use_non_uhp_fs3 ? var.fs3_disk_count : 0) )

  nfs = (length(regexall("^NFS", var.fs_name)) > 0 ? true : false)
  nfs_server_ip = (var.fs_ha ? (var.ha_vip_private_ip) :  (local.storage_server_dual_nics ? (local.storage_server_hpc_shape ? element(concat(oci_core_instance.storage_server.*.private_ip, [""]), 0) : element(concat(data.oci_core_private_ips.private_ips_by_vnic[0].private_ips.*.ip_address,  [""]), 0) ) : element(concat(oci_core_instance.storage_server.*.private_ip, [""]), 0) )     )

  # Grafana monitoring
  install_monitor_agent=((var.create_monitoring_server) ? true : false )

  # https://docs.oracle.com/en-us/iaas/Content/Compute/Tasks/edit-launch-options.htm
  server_network_type = ( ( (length(regexall("VM.Standard.E2", local.derived_storage_server_shape)) > 0) || (length(regexall("VM.Standard.A1.Flex", local.derived_storage_server_shape)) > 0) ) ? "PARAVIRTUALIZED" : "VFIO")

  client_network_type = ( ( (length(regexall("VM.Standard.E2", var.client_node_shape)) > 0) || (length(regexall("VM.Standard.A1.Flex", var.client_node_shape)) > 0) ) ? "PARAVIRTUALIZED" : "VFIO")

}


