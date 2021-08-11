


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

data "oci_core_services" "all_oci_services" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
  count = var.use_existing_vcn ? 0 : (var.use_uhp ? 1 : 0)
}

resource "oci_core_service_gateway" "service_gateway" {
  compartment_id = var.compartment_ocid
  display_name   = "${local.cluster_name}_service_gateway"
  
  services {
    service_id = lookup(data.oci_core_services.all_oci_services[0].services[0], "id")
  }

  vcn_id  = oci_core_virtual_network.nfs[0].id
  count = var.use_existing_vcn ? 0 : (var.use_uhp ? 1 : 0)
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
  
  dynamic "route_rules" {
    # * If Service Gateway is created with the module, automatically creates a rule to handle traffic for "all services" through Service Gateway
    for_each = var.use_existing_vcn ? [] : (var.use_uhp ? [1] : [])

    content {
      destination       = lookup(data.oci_core_services.all_oci_services[0].services[0], "cidr_block")
      destination_type  = "SERVICE_CIDR_BLOCK"
      network_entity_id = oci_core_service_gateway.service_gateway[0].id
      description       = "Terraformed - Auto-generated at Service Gateway creation: All Services in region to Service Gateway"
    }
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


  # TCP for NFSv3
  ingress_security_rules  {
    protocol = "6"
    source   = var.vcn_cidr
  }
  # UDP for NFSv3
  ingress_security_rules  {
    protocol = "17"
    source   = var.vcn_cidr
  }

  # Allow ssh traffic
  ingress_security_rules {
    tcp_options {
      max = 22
      min = 22
    }
    protocol = "6"
    source   = var.vcn_cidr
  }

  # Required for node exporter for IaaS metrics for monitoring
  ingress_security_rules {
    tcp_options {
      max = 9100
      min = 9100
    }
    protocol = "6"
    source   = var.vcn_cidr
  }
  # Required for pacemaker/corosync node exporter metrics
  ingress_security_rules {
    tcp_options {
      max = 9664
      min = 9664
    }
    protocol = "6"
    source   = var.vcn_cidr
  }
  # Required for running Grafana GUI at port 3000
  ingress_security_rules {
    tcp_options {
      max = 3000
      min = 3000
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


