###
## Variables.tf for Terraform
## Defines variables and local values
###

# default, do not change.
variable fs_name {
  default = "NFS"
}


# "Scratch" or "Persistent" file system.  Highly Available NFS Server is only supported on fs_type = "Persistent".  "Persistent" file system uses network attached shared block volume storage.   "Scratch" file system is built using local NVMe SSDs attached to compute instances.
variable fs_type {
  default = "Persistent"
}

# Deploy file system with high availability (2 node file server in active/passive mode) or single node file server.
variable fs_ha {
  default = "false"
}


# To use existing VCN or new VCN.
variable use_existing_vcn {
  default = "false"
}

# Existing VCN OCID, if use_existing_vcn = true
variable vcn_id {
  default = ""
}

# Bastion Subnet - Ensure the Subnet is in the same availability domain selected above or use regional subnet
variable bastion_subnet_id {
  default = ""
}

# Enter private subnet OCID to be used to deploy NFS servers. This will be the primary subnet used by the server to access boot/OS disk and network attached data Block Volumes. Ensure the Subnet is in the same availability domain selected above or use regional subnet. Refer to architecture diagrams here: https://github.com/oracle-quickstart/oci-nfs.
variable storage_subnet_id {
  default = ""
}

# Only set this value, if you plan to use Bare metal compute shapes (except BM.HPC2.36) for NFS file servers. Otherwise leave it blank. This 2nd private subnet OCID will be used to create a secondary VNIC using 2nd physical NIC. For Baremetal nodes(except BM.HPC2.36), we need two subnets to use both physical NICs of the node for highest performance. Refer to architecture diagrams here: https://github.com/oracle-quickstart/oci-nfs.
variable fs_subnet_id {
  default = ""
}

# VCN IP Range/Network CIDR to use for VCN.
variable vcn_cidr { default = "10.0.0.0/16" }
# Subnet IP Range/CIDR to use for regional public subnet. Example: 10.0.0.0/24. Must be within VCN subnet.
variable bastion_subnet_cidr { default = "10.0.0.0/24" }
# Subnet IP Range/CIDR to use for regional private subnet. This will be the primary subnet used by NFS file servers & Quorum node to access boot/OS disk and network attached data Block Volumes. Example: 10.0.3.0/24. Must be within VCN subnet.
variable storage_subnet_cidr { default = "10.0.3.0/24" }
# Only set this value, if you plan to use Bare metal compute shapes (except BM.HPC2.36) for NFS file servers. This 2nd private regional subnet will be used to create a secondary VNIC on file servers using 2nd physical NIC to achieve highest performance. Example: 10.0.6.0/24. Must be within VCN subnet.
variable fs_subnet_cidr { default = "10.0.6.0/24" }


# Bastion node variables
variable bastion_shape { default = "VM.Standard2.1" }
# Number of OCPU's for flex shape
variable bastion_ocpus { default = "1" }
variable bastion_node_count { default = 1 }
variable bastion_hostname_prefix { default = "bastion-" }
# min 50GB, Recommend using at least 100 GB in production to ensure there is enough space for logs.
variable bastion_boot_volume_size { default = "100" }


# NFS Storage Server variables
variable persistent_storage_server_shape { default = "VM.Standard2.2" }
# Number of OCPU's for flex shape
variable storage_server_ocpus { default = "1" }
variable scratch_storage_server_shape { default = "VM.DenseIO2.16" }
variable storage_server_hostname_prefix { default = "nfs-server-" }
# Recommend using 200-300 GB in production to ensure there is enough space for logs.
variable storage_server_boot_volume_size { default = "300" }


# Only applicable if you plan to deploy NFS with HA (fs_ha = true, fs_type="Persistent")
# Floating Virtual IP which gets assigned to an active node in an active/passive HA cluster. NFS clients will use this IP to connect to NFS cluster. If you plan to use Bare metal compute shapes (except BM.HPC2.36) for NFS file servers, then provide an unused private IP from the 'secondary subnet'. For Baremetal nodes, we need two subnets to use both physical NICs of the node for highest performance. If you plan to use VM .x or BM.HPC2.36 compute shapes for NFS file servers, then provide an unused private IP from 'primary subnet' to be used to install NFS servers. Refer to architecture diagrams here: https://github.com/oracle-quickstart/oci-nfs.
# example: 10.0.3.200 or 10.0.6.200
variable ha_vip_private_ip {  default = "10.0.3.200" }
# Make sure its unique within the subnet.  Use hyphen, not underscore, if required.
variable ha_vip_hostname {  default = "nfs-vip-xxx" }



# Quorum node - mandatory for HA.  Not required for single server NFS
variable quorum_server_shape { default = "VM.Standard2.2" }
# Number of OCPU's for flex shape
variable quorum_server_ocpus { default = "1" }
variable quorum_server_hostname { default = "qdevice" }

# Stonith/Fencing
# Implemented using SBD fencing agent, shared disk/multi-attach (/dev/oracleoci/oraclevdb) and s/w watchdog (softdog)
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


variable storage_tier_1_disk_perf_tier {
  default = "Higher Performance"
  description = "Select block volume storage performance tier based on your performance needs. Valid values are Higher Performance, Balanced, Lower Cost"
}

variable storage_tier_1_disk_count {
  default = "6"
  description = "Number of block volume disk for entire filesystem (not per file server). If var.fs_ha  was set to true, then these Block volumes will be shared by both NFS file servers, otherwise a single node NFS server will be deployed with Block volumes. Block volumes are more durable and highly available."
}

variable storage_tier_1_disk_size {
  default = "800"
  description = "Select size in GB for each block volume/disk, min 50.  Total NFS filesystem raw capacity will be NUMBER OF BLOCK VOLUMES * BLOCK VOLUME SIZE."
}


# Create a node to run Grafana/Prometheus for monitoring NFS and OCI IaaS.
variable create_monitoring_server { default = "false" }
variable monitoring_server_shape { default = "VM.Standard2.1" }
# Number of OCPU's for flex shape
variable monitoring_server_ocpus { default = "1" }
variable monitoring_server_hostname { default = "nfs-grafana" }


variable instance_os {
    description = "Operating system for compute instances"
    default = "Oracle Linux"
}

# Only latest supported OS version works. if I use 7.7, it doesn't return an image ocid.
variable linux_os_version {
    description = "Operating system version for compute instances except NAT"
    default = "7.9"
}


################################################################
## Variables which in most cases do not require change by user
################################################################


variable tenancy_ocid {}
variable region {}

variable compartment_ocid {
  description = "Compartment where infrastructure resources will be created"
}
variable ssh_public_key {
  description = "SSH Public Key"
}

variable ssh_user { default = "opc" }


# Not used for normal terraform apply, added for ORM deployments.
variable ad_name {
  default = ""
}

variable volume_attach_device_mapping {
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

variable volume_type_vpus_per_gb_mapping {
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
variable mp_listing_id { default = "ocid1.appcataloglisting.oc1..aaaaaaaa26y5fkfvbjmspmuuhpoi6jptq3gc635a3gz72qujfsomvczh2miq" }
variable mp_listing_resource_id { default = "ocid1.image.oc1..aaaaaaaabxwrflhsoaipmm4v7xvjfsmou42bp2fwpmuvyyug2sksfmroihta" }
variable mp_listing_resource_version { default = "1.0" }
variable use_marketplace_image { default = false }

# ------------------------------------------------------------------------------------------------------------



# Generate a new strong password for hacluster user
resource random_string hacluster_user_password {
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


variable "use_custom_name" {
  default = 0
}

variable "cluster_name" {
  default = "nfs_cluster"
}



