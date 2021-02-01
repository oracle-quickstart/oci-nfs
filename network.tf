


/*
All network resources for this template
*/

resource "oci_core_virtual_network" "nfs" {
  count          = var.use_existing_vcn ? 0 : 1
  cidr_block     = var.vcn_cidr
  compartment_id = var.compartment_ocid
  display_name   = "${local.cluster_name}_VCN"
  dns_label      = "nfs"
}

resource "oci_core_internet_gateway" "internet_gateway" {
  count          = var.use_existing_vcn ? 0 : 1
  compartment_id = var.compartment_ocid
  display_name   = "${local.cluster_name}_internet_gateway"
  vcn_id         = oci_core_virtual_network.nfs[0].id
}

resource "oci_core_route_table" "pubic_route_table" {
  count          = var.use_existing_vcn ? 0 : 1
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.nfs[0].id
  display_name   = "${local.cluster_name}_public_route_table"
  route_rules {
    cidr_block        = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.internet_gateway[0].id
  }
}


resource "oci_core_nat_gateway" "nat_gateway" {
  count          = var.use_existing_vcn ? 0 : 1
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.nfs[0].id
  display_name   = "${local.cluster_name}_nat_gateway"
}


resource "oci_core_route_table" "private_route_table" {
  count          = var.use_existing_vcn ? 0 : 1
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.nfs[0].id
  display_name   = "${local.cluster_name}_private_route_table"
  route_rules {
    cidr_block        = "0.0.0.0/0"
    network_entity_id = oci_core_nat_gateway.nat_gateway[0].id
  }
}

resource "oci_core_security_list" "public_security_list" {
  count          = var.use_existing_vcn ? 0 : 1
  compartment_id = var.compartment_ocid
  display_name   = "Public Security List"
  vcn_id         = oci_core_virtual_network.nfs[0].id

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "6"
  }

  ingress_security_rules {
    tcp_options {
      max = 22
      min = 22
    }
    protocol = "6"
    source   = "0.0.0.0/0"
  }
}


resource "oci_core_security_list" "private_security_list" {
  count          = var.use_existing_vcn ? 0 : 1
  compartment_id = var.compartment_ocid
  display_name   = "Private Security List"
  vcn_id         = oci_core_virtual_network.nfs[0].id

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

/*
  ingress_security_rules  {
    protocol = "all"
    source   = var.vcn_cidr
  }
*/
  # Allow ssh traffic
  ingress_security_rules {
    tcp_options {
      max = 22
      min = 22
    }
    protocol = "6"
    source   = var.vcn_cidr
  }

  # rpcinfo -p
  # https://www.systutorials.com/fixing-ports-used-by-nfs-server/
  # rpcbind listens on TCP and UDP port 111
  ingress_security_rules {
    tcp_options {
      max = 111
      min = 111
    }
    protocol = "6"
    source   = var.vcn_cidr
  }

  ingress_security_rules {
    udp_options {
      max = 111
      min = 111
    }
    protocol = "17"
    source   = var.vcn_cidr
  }

  # nfsd listens on TCP and UDP port 2049
  ingress_security_rules {
    tcp_options {
      max = 2049
      min = 2049
    }
    protocol = "6"
    source   = var.vcn_cidr
  }

  ingress_security_rules {
    udp_options {
      max = 2049
      min = 2049
    }
    protocol = "17"
    source   = var.vcn_cidr
  }

  # RQUOTAD_PORT=875
  ingress_security_rules {
    tcp_options {
      max = 875
      min = 875
    }
    protocol = "6"
    source   = var.vcn_cidr
  }

  ingress_security_rules {
    udp_options {
      max = 875
      min = 875
    }
    protocol = "17"
    source   = var.vcn_cidr
  }

  # LOCKD_TCPPORT=32803
  ingress_security_rules {
    tcp_options {
      max = 32803
      min = 32803
    }
    protocol = "6"
    source   = var.vcn_cidr
  }
  # LOCKD_UDPPORT=32769
  ingress_security_rules {
    udp_options {
      max = 32769
      min = 32769
    }
    protocol = "17"
    source   = var.vcn_cidr
  }

  # MOUNTD_PORT=892
  ingress_security_rules {
    tcp_options {
      max = 892
      min = 892
    }
    protocol = "6"
    source   = var.vcn_cidr
  }

  ingress_security_rules {
    udp_options {
      max = 892
      min = 892
    }
    protocol = "17"
    source   = var.vcn_cidr
  }

  # STATD_PORT=662
  ingress_security_rules {
    tcp_options {
      max = 662
      min = 662
    }
    protocol = "6"
    source   = var.vcn_cidr
  }

  ingress_security_rules {
    udp_options {
      max = 662
      min = 662
    }
    protocol = "17"
    source   = var.vcn_cidr
  }

  # corosync-qnetd=5403
  ingress_security_rules {
    tcp_options {
      max = 5403
      min = 5403
    }
    protocol = "6"
    source   = var.vcn_cidr
  }

  # corosync-qnetd=5405
  ingress_security_rules {
    udp_options {
      max = 5405
      min = 5405
    }
    protocol = "17"
    source   = var.vcn_cidr
  }

  # Required for NFSHA nodes to comm with qdevice node for pcs cluster auth
  ingress_security_rules {
    tcp_options {
      max = 2224
      min = 2224
    }
    protocol = "6"
    source   = var.vcn_cidr
  }

}


# Regional subnet - public
resource "oci_core_subnet" "public" {
  count             = var.use_existing_vcn ? 0 : 1
  cidr_block        = trimspace(local.derived_bastion_subnet_cidr)
  display_name      = "${local.cluster_name}_public"
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_virtual_network.nfs[0].id
  route_table_id    = oci_core_route_table.pubic_route_table[0].id
  security_list_ids = [oci_core_security_list.public_security_list[0].id]
  dhcp_options_id   = oci_core_virtual_network.nfs[0].default_dhcp_options_id
  dns_label         = "public"
}


# Regional subnet - private
resource "oci_core_subnet" "storage" {
  count                      = var.use_existing_vcn ? 0 : 1
  cidr_block                 = trimspace(local.derived_storage_subnet_cidr)
  display_name               = "${local.cluster_name}_private_storage"
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_virtual_network.nfs[0].id
  route_table_id             = oci_core_route_table.private_route_table[0].id
  security_list_ids          = [oci_core_security_list.private_security_list[0].id]
  dhcp_options_id            = oci_core_virtual_network.nfs[0].default_dhcp_options_id
  prohibit_public_ip_on_vnic = true
  dns_label                  = "storage"
}

resource "oci_core_subnet" "fs" {
  count                      = local.create_fs_subnet
  cidr_block                 = trimspace(local.derived_fs_subnet_cidr)
  display_name               = "${local.cluster_name}_private_fs"
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_virtual_network.nfs[0].id
  route_table_id             = oci_core_route_table.private_route_table[0].id
  security_list_ids          = [oci_core_security_list.private_security_list[0].id]
  dhcp_options_id            = oci_core_virtual_network.nfs[0].default_dhcp_options_id
  prohibit_public_ip_on_vnic = true
  dns_label                  = "fs"
}


