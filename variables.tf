###
## Variables.tf for Terraform
## Defines variables and local values
###

variable "vpc_cidr" { default = "10.0.0.0/16" }


variable "fs_name" { default = "NFS" }
# Scratch or Persistent
variable "fs_type" { default = "Persistent" }
variable "fs_ha" { default = "true" }


variable bastion_shape { default = "VM.Standard2.1" }
# Number of OCPU's for flex shape
variable bastion_ocpus { default = "1" }
variable bastion_node_count { default = 1 }
variable bastion_hostname_prefix { default = "bastion-" }


# NFS Storage Server variables
variable persistent_storage_server_shape { default = "VM.Standard2.2" }
# Number of OCPU's for flex shape
variable storage_server_ocpus { default = "1" }
variable scratch_storage_server_shape { default = "VM.DenseIO2.16" }
variable storage_server_hostname_prefix { default = "storage-server-" }

# Quorum node - mandatory for HA.  Not required for single server NFS
variable quorum_server_shape { default = "VM.Standard2.2" }
# Number of OCPU's for flex shape
variable quorum_server_ocpus { default = "1" }
variable quorum_server_hostname { default = "qdevice" }


#Stonith/Fencing - Implemented using SBD fencing agent, shared disk/multi-attach (/dev/oracleoci/oraclevdb) and s/w watchdog (softdog)
# https://github.com/ClusterLabs/fence-agents
# https://github.com/ClusterLabs/fence-agents/tree/master/agents/sbd

# Client/Compute nodes variables - nodes which will mount the filesystem - optional.  Set to false, if client nodes are not needed.
variable "create_compute_nodes" { default = "true" }
variable client_node_shape { default = "VM.Standard2.24" }
# Number of OCPU's for flex shape
variable client_node_ocpus { default = "1" }
variable client_node_count { default = 0 }
variable client_node_hostname_prefix { default = "client-" }



# FS related variables
variable mount_point { default = "/mnt/nfs" }
# 
# LVM block/stripe size. In kilobytes. LVM Default is 64 (64KB)  128 = 128KB, 256 = 256KB, 1024 = 1024KB (1MB)
variable block_size { default = "64" }


# This is currently used for Terraform deployment.
# Valid values for Availability Domain: 0,1,2, if the region has 3 ADs, else use 0.
variable "ad_number" {
  default = "-1"
}


variable "storage_tier_1_disk_perf_tier" {
  default = "Higher Performance"
  description = "Select block volume storage performance tier based on your performance needs. Valid values are Higher Performance, Balanced, Lower Cost"
}

variable "storage_tier_1_disk_count" {
  default = "6"
  description = "Number of block volume disk for entire filesystem (not per file server). If var.fs_ha  was set to true, then these Block volumes will be shared by both NFS file servers, otherwise a single node NFS server will be deployed with Block volumes. Block volumes are more durable and highly available."
}

variable "storage_tier_1_disk_size" {
  default = "800"
  description = "Select size in GB for each block volume/disk, min 50.  Total NFS filesystem raw capacity will be NUMBER OF BLOCK VOLUMES * BLOCK VOLUME SIZE."
}

variable "instance_os" {
    description = "Operating system for compute instances"
    default = "Oracle Linux"
}

# Only latest supported OS version works. if I use 7.7, it doesn't return an image ocid.
variable "linux_os_version" {
    description = "Operating system version for compute instances except NAT"
    default = "7.8"
}


################################################################
## Variables which in most cases do not require change by user
################################################################


variable "tenancy_ocid" {}
variable "region" {}

variable "compartment_ocid" {
  description = "Compartment where infrastructure resources will be created"
}
variable "ssh_public_key" {
  description = "SSH Public Key"
}

variable "ssh_user" { default = "opc" }

locals {
  storage_server_dual_nics = (length(regexall("^BM", local.derived_storage_server_shape)) > 0 ? true : false)
  storage_server_hpc_shape = (length(regexall("HPC2", local.derived_storage_server_shape)) > 0 ? true : false)
  standard_storage_node_dual_nics = (length(regexall("^BM", local.derived_storage_server_shape)) > 0 ? (length(regexall("Standard",local.derived_storage_server_shape)) > 0 ? true : false) : false)
  storage_subnet_domain_name = "${data.oci_core_subnet.private_storage_subnet.dns_label}.${data.oci_core_vcn.nfs.dns_label}.oraclevcn.com"
  vcn_domain_name = "${data.oci_core_vcn.nfs.dns_label}.oraclevcn.com"
  storage_server_filesystem_vnic_hostname_prefix = "${var.storage_server_hostname_prefix}fs-vnic-"
  filesystem_subnet_domain_name = "${data.oci_core_subnet.private_fs_subnet.dns_label}.${data.oci_core_vcn.nfs.dns_label}.oraclevcn.com"

  is_bastion_flex_shape = var.bastion_shape == "VM.Standard.E3.Flex" ? [var.bastion_ocpus]:[]
  is_quorum_server_flex_shape = var.quorum_server_shape == "VM.Standard.E3.Flex" ? [var.quorum_server_ocpus]:[]
  is_storage_server_flex_shape = var.persistent_storage_server_shape == "VM.Standard.E3.Flex" ? [var.storage_server_ocpus]:[]
  is_client_node_flex_shape = var.client_node_shape == "VM.Standard.E3.Flex" ? [var.client_node_ocpus]:[]

  # If ad_number is non-negative use it for AD lookup, else use ad_name.
  # Allows for use of ad_number in TF deploys, and ad_name in ORM.
  # Use of max() prevents out of index lookup call.
  ad = var.ad_number >= 0 ? lookup(data.oci_identity_availability_domains.availability_domains.availability_domains[max(0,var.ad_number)],"name") : var.ad_name

}

/*
variable "imagesC" {
  type = map(string)
  default = {
    // https://docs.cloud.oracle.com/iaas/images/image/96ad11d8-2a4f-4154-b128-4d4510756983/
    // See https://docs.us-phoenix-1.oraclecloud.com/images/ or https://docs.cloud.oracle.com/iaas/images/
    // Oracle-provided image "CentOS-7-2018.08.15-0"
    eu-frankfurt-1 = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaavsw2452x5psvj7lzp7opjcpj3yx7or4swwzl5vrdydxtfv33sbmqa"
    us-ashburn-1   = "ocid1.image.oc1.iad.aaaaaaaahhgvnnprjhfmzynecw2lqkwhztgibz5tcs3x4d5rxmbqcmesyqta"
    uk-london-1    = "ocid1.image.oc1.uk-london-1.aaaaaaaa3iltzfhdk5m6f27wcuw4ttcfln54twkj66rsbn52yemg3gi5pkqa"
    us-phoenix-1   = "ocid1.image.oc1.phx.aaaaaaaaa2ph5vy4u7vktmf3c6zemhlncxkomvay2afrbw5vouptfbydwmtq"
  }
}
*/

// See https://docs.cloud.oracle.com/en-us/iaas/images/image/0a72692a-bdbb-46fc-b17b-6e0a3fedeb23/
// Oracle-provided image "Oracle-Linux-7.7-2020.01.28-0"
// Kernel Version: 4.14.35-1902.10.4.el7uek.x86_64

variable "images" {
  type = map(string)
  default = {
    ap-melbourne-1 = "ocid1.image.oc1.ap-melbourne-1.aaaaaaaa3fvafraincszwi36zv2oeangeitnnj7svuqjbm2agz3zxhzozadq"
    ap-mumbai-1 = "ocid1.image.oc1.ap-mumbai-1.aaaaaaaabyd7swhvmsttpeejgksgx3faosizrfyeypdmqdghgn7wzed26l3q"
    ap-osaka-1 = "ocid1.image.oc1.ap-osaka-1.aaaaaaaa7eec33y25cvvanoy5kf5udu3qhheh3kxu3dywblwqerui3u72nua"
    ap-seoul-1 = "ocid1.image.oc1.ap-seoul-1.aaaaaaaai233ko3wxveyibsjf5oew4njzhmk34e42maetaynhbljbvkzyqqa"
    ap-sydney-1 = "ocid1.image.oc1.ap-sydney-1.aaaaaaaaeb3c3kmd3yfaqc3zu6ko2q6gmg6ncjvvc65rvm3aqqzi6xl7hluq"
    ap-tokyo-1 = "ocid1.image.oc1.ap-tokyo-1.aaaaaaaattpocc2scb7ece7xwpadvo4c5e7iuyg7p3mhbm554uurcgnwh5cq"
    ca-toronto-1 = "ocid1.image.oc1.ca-toronto-1.aaaaaaaa4u2x3aofmhogbw6xsckha6qdguiwqvh5ibnbuskfo2k6e3jhdtcq"
    eu-amsterdam-1 = "ocid1.image.oc1.eu-amsterdam-1.aaaaaaaan5tbzuvtyd5lwxj66zxc7vzmpvs5axpcxyhoicbr6yxgw2s7nqvq"
    eu-frankfurt-1 = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaa4xluwijh66fts4g42iw7gnixntcmns73ei3hwt2j7lihmswkrada"
    eu-zurich-1 = "ocid1.image.oc1.eu-zurich-1.aaaaaaaagj2saw4bisxyfe5joary52bpggvpdeopdocaeu2khpzte6whpksq"
    me-jeddah-1 = "ocid1.image.oc1.me-jeddah-1.aaaaaaaaczhhskrjad7l3vz2u3zyrqs4ys4r57nrbxgd2o7mvttzm4jryraa"
    sa-saopaulo-1 = "ocid1.image.oc1.sa-saopaulo-1.aaaaaaaabm464lilgh2nqw2vpshvc2cgoeuln5wgrfji5dafbiyi4kxtrmwa"
    uk-gov-london-1 = "ocid1.image.oc4.uk-gov-london-1.aaaaaaaa3badeua232q6br2srcdbjb4zyqmmzqgg3nbqwvp3ihjfac267glq"
    uk-london-1 = "ocid1.image.oc1.uk-london-1.aaaaaaaa2jxzt25jti6n64ks3hqbqbxlbkmvel6wew5dc2ms3hk3d3bdrdoa"
    us-ashburn-1 = "ocid1.image.oc1.iad.aaaaaaaamspvs3amw74gzpux4tmn6gx4okfbe3lbf5ukeheed6va67usq7qq"
    us-langley-1 = "ocid1.image.oc2.us-langley-1.aaaaaaaawzkqcffiqlingild6jqdnlacweni7ea2rm6kylar5tfc3cd74rcq"
    us-luke-1 = "ocid1.image.oc2.us-luke-1.aaaaaaaawo4qfu7ibanw2zwefm7q7hqpxsvzrmza4uwfqvtqg2quk6zghqia"
    us-phoenix-1 = "ocid1.image.oc1.phx.aaaaaaaamff6sipozlita6555ypo5uyqo2udhjqwtrml2trogi6vnpgvet5q"
  }
}

# Not used for normal terraform apply, added for ORM deployments.
variable "ad_name" {
  default = ""
}

variable "volume_attach_device_mapping" {
  type = map(string)
  default = {
    "0" = "/dev/oracleoci/oraclevdb"
    "1" = "/dev/oracleoci/oraclevdc"
    "2" = "/dev/oracleoci/oraclevdd"
    "3" = "/dev/oracleoci/oraclevde"
    "4" = "/dev/oracleoci/oraclevdf"
    "5" = "/dev/oracleoci/oraclevdg"
    "6" = "/dev/oracleoci/oraclevdh"
    "7" = "/dev/oracleoci/oraclevdi"
    "8" = "/dev/oracleoci/oraclevdj"
    "9" = "/dev/oracleoci/oraclevdk"
    "10" = "/dev/oracleoci/oraclevdl"
    "11" = "/dev/oracleoci/oraclevdm"
    "12" = "/dev/oracleoci/oraclevdn"
    "13" = "/dev/oracleoci/oraclevdo"
    "14" = "/dev/oracleoci/oraclevdp"
    "15" = "/dev/oracleoci/oraclevdq"
    "16" = "/dev/oracleoci/oraclevdr"
    "17" = "/dev/oracleoci/oraclevds"
    "18" = "/dev/oracleoci/oraclevdt"
    "19" = "/dev/oracleoci/oraclevdu"
    "20" = "/dev/oracleoci/oraclevdv"
    "21" = "/dev/oracleoci/oraclevdw"
    "22" = "/dev/oracleoci/oraclevdx"
    "23" = "/dev/oracleoci/oraclevdy"
    "24" = "/dev/oracleoci/oraclevdz"
    "25" = "/dev/oracleoci/oraclevdaa"
    "26" = "/dev/oracleoci/oraclevdab"
    "27" = "/dev/oracleoci/oraclevdac"
    "28" = "/dev/oracleoci/oraclevdad"
    "29" = "/dev/oracleoci/oraclevdae"
    "30" = "/dev/oracleoci/oraclevdaf"
    "31" = "/dev/oracleoci/oraclevdag"
  }
}

variable "volume_type_vpus_per_gb_mapping" {
  type = map(string)
  default = {
    "Higher Performance" = "20"
    "Balanced" = "10"
    "Lower Cost" = "0"
    "None" = "-1"
  }
}


# Not compatible with E3.Flex shapes.  Need image released after April 2020.
#-------------------------------------------------------------------------------------------------------------
# Marketplace variables
# OL78UEK-4.14.35-1902.305.4.el7uek.x86_64
# Oracle Linux 7.8 UEK Image for filesystem
# ------------------------------------------------------------------------------------------------------------
variable "mp_listing_id" { default = "ocid1.appcataloglisting.oc1..aaaaaaaa26y5fkfvbjmspmuuhpoi6jptq3gc635a3gz72qujfsomvczh2miq" }
variable "mp_listing_resource_id" { default = "ocid1.image.oc1..aaaaaaaabxwrflhsoaipmm4v7xvjfsmou42bp2fwpmuvyyug2sksfmroihta" }
variable "mp_listing_resource_version" { default = "1.0" }
variable "use_marketplace_image" { default = true }

#-------------------------------------------------------------------------------------------------------------
# Marketplace variables
# hpc-filesystem-BeeGFS-OL77_4.14.35-1902.10.4.el7uek.x86_64
# Oracle Linux 7.7 UEK Image for BeeGFS filesystem on Oracle Cloud Infrastructure
# ------------------------------------------------------------------------------------------------------------
/*
variable "mp_listing_id" {
  default = "ocid1.appcataloglisting.oc1..aaaaaaaadu427jmx3pbdw76ek6xkgin4ucmfbrlsavb45snvzk5d7ckrs3nq"
}
variable "mp_listing_resource_id" {
  default = "ocid1.image.oc1..aaaaaaaa6pvs3ovuveqb7pepzjhemyykkyjae7tttrb2fkf5adzwqm3izvxq"
}
variable "mp_listing_resource_version" {
 default = "1.0"
}

variable "use_marketplace_image" {
  default = true
}
*/
# ------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------
# Marketplace variables
# hpc-filesystem-BeeGFS-OL77_3.10.0-1062.9.1.el7.x86_64
# ------------------------------------------------------------------------------------------------------------

# variable "mp_listing_id" {
#   default = "ocid1.appcataloglisting.oc1..aaaaaaaajmdokvtzailtlchqxk7nai45fxar6em7dfbdibxmspjsvs4uz3uq"
# }
# variable "mp_listing_resource_id" {
#   default = "ocid1.image.oc1..aaaaaaaacnodhlnuidkvnlvu3dpu4n26knkqudjxzfpq3vexi7cobbclmbxa"
# }
# variable "mp_listing_resource_version" {
#  default = "1.0"
# }

# variable "use_marketplace_image" {
#   default = true
# }

# ------------------------------------------------------------------------------------------------------------



variable "use_existing_vcn" {
  default = "false"
}

variable "vcn_id" {
  default = ""
}

variable "bastion_subnet_id" {
  default = ""
}

variable "storage_subnet_id" {
  default = ""
}

variable "fs_subnet_id" {
  default = ""
}



# This are used by TF only.  Not by Resource manager.
variable storage_primary_vnic_vip_private_ip { default = "10.0.3.200" }
variable storage_secondary_vnic_vip_private_ip { default = "10.0.6.200" }

# This is only used for RM GUI logic.  Do not change the default value.
variable "rm_only_ha_vip_private_ip" {  default = "" }


# Generate a new strong password for hacluster user
resource "random_string" "hacluster_user_password" {
  length      = 16
  special     = true
  min_special = 2
  upper       = true
  min_upper   = 2
  lower       = true
  min_lower   = 2
  number      = true
  min_numeric = 2
  override_special = "!@#-_&*=+"
}





