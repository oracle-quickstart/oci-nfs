
resource "tls_private_key" "ssh" {
  algorithm   = "RSA"
}


data "template_file" "bastion_config" {
  template = file("${path.module}/config.bastion")
  vars = {
    key = tls_private_key.ssh.private_key_pem
  }
}

resource "oci_core_instance" "bastion" {
  depends_on          = [ oci_core_instance.storage_server, oci_core_subnet.public,  oci_core_private_ip.storage_vip_private_ip, oci_core_instance.quorum_server,
   ]
  count               = var.bastion_node_count
  availability_domain = local.ad
  #fault_domain        = "FAULT-DOMAIN-${(count.index%3)+1}"
  compartment_id      = var.compartment_ocid
  shape               = var.bastion_shape
  display_name        = "${local.cluster_name}_${var.bastion_hostname_prefix}${format("%01d", count.index+1)}"
  metadata = {
    ssh_authorized_keys = "${var.ssh_public_key}\n${tls_private_key.ssh.public_key_openssh}"
    user_data           = base64encode(data.template_file.bastion_config.rendered)
  }

  dynamic "shape_config" {
    for_each = local.is_bastion_flex_shape
      content {
        ocpus = shape_config.value
      }
  }

  source_details {
    source_id   = local.image_id
    source_type = "image"
  }
  create_vnic_details {
    subnet_id = local.bastion_subnet_id
    hostname_label      = "${var.bastion_hostname_prefix}${format("%01d", count.index+1)}"
  }

    connection {
      host        = oci_core_instance.bastion[0].public_ip
      type        = "ssh"
      user        = "opc"
      private_key = tls_private_key.ssh.private_key_pem
    }

  provisioner "file" {
    source        = "${path.module}/playbooks"
    destination   = "/home/opc/"
  }

  provisioner "file" {
    content        = templatefile("${path.module}/inventory.tpl", {  
      bastion_name = oci_core_instance.bastion[0].display_name,
      bastion_ip = oci_core_instance.bastion[0].private_ip,
      storage = zipmap(data.oci_core_instance.storage_server.*.display_name, data.oci_core_instance.storage_server.*.private_ip),
      compute = zipmap(data.oci_core_instance.client_node.*.display_name, data.oci_core_instance.client_node.*.private_ip),
      quorum = zipmap(data.oci_core_instance.quorum_server.*.display_name, data.oci_core_instance.quorum_server.*.private_ip),
      monitor = zipmap(data.oci_core_instance.monitoring_server.*.display_name, data.oci_core_instance.monitoring_server.*.private_ip),
      fs_name = var.fs_name,
      fs_type = var.fs_type,
      fs_ha = var.fs_ha,
      vcn_domain_name = local.vcn_domain_name,
      public_subnet_cidr_block = data.oci_core_subnet.public_subnet.cidr_block,
      private_storage_subnet_cidr_block = data.oci_core_subnet.private_storage_subnet.cidr_block,
      private_storage_subnet_dns_label = data.oci_core_subnet.private_storage_subnet.dns_label,
      private_fs_subnet_dns_label = data.oci_core_subnet.private_fs_subnet.dns_label,
      storage_subnet_domain_name = local.storage_subnet_domain_name,
      storage_server_node_count = local.derived_storage_server_node_count,
      storage_tier_1_disk_perf_tier = var.storage_tier_1_disk_perf_tier,
      mount_point = var.mount_point,
      block_size = var.block_size,
      storage_server_hostname_prefix = var.storage_server_hostname_prefix,
      hacluster_user_password = random_string.hacluster_user_password.result,
      nfs_server_ip = local.nfs_server_ip,
      storage_server_filesystem_vnic_hostname_prefix = local.storage_server_filesystem_vnic_hostname_prefix,
      filesystem_subnet_domain_name = local.filesystem_subnet_domain_name,
      standard_storage_node_dual_nics = local.standard_storage_node_dual_nics,
      private_fs_subnet_cidr_block = data.oci_core_subnet.private_fs_subnet.cidr_block,
      quorum_server_hostname = var.quorum_server_hostname,
      install_monitor_agent = local.install_monitor_agent,
      storage_tier_1_disk_count = var.storage_tier_1_disk_count,
      storage_tier_1_disk_size = var.storage_tier_1_disk_size,

    })

    destination   = "/home/opc/playbooks/inventory"
  }


  provisioner "file" {
    content     = tls_private_key.ssh.private_key_pem
    destination = "/home/opc/.ssh/cluster.key"
  }


  provisioner "file" {
    content     = tls_private_key.ssh.private_key_pem
    destination = "/home/opc/.ssh/id_rsa"
  }

  provisioner "file" {
    content     = join("\n", data.oci_core_instance.storage_server.*.private_ip)
    destination = "/tmp/hosts"
  }


  provisioner "file" {
    source      = "${path.module}/configure.sh"
    destination = "/tmp/configure.sh"
  }


}

resource "null_resource" "run_configure_sh" {
  depends_on = [ oci_core_instance.bastion, null_resource.notify_storage_server_nodes_block_attach_complete ]
  count      = var.bastion_node_count

    connection {
      host        = oci_core_instance.bastion[0].public_ip
      type        = "ssh"
      user        = "opc"
      private_key = tls_private_key.ssh.private_key_pem
    }


  provisioner "file" {
    source      = "${path.module}/configure.sh"
    destination = "/tmp/configure.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 600 /home/opc/.ssh/cluster.key",
      "chmod 600 /home/opc/.ssh/id_rsa",
      "chmod a+x /tmp/configure.sh",
      "chmod a+x /tmp/*.sh",
      "/tmp/configure.sh"
    ]
  }
}







resource "oci_core_instance" "storage_server" {
  count               = local.derived_storage_server_node_count
  availability_domain = local.ad

  fault_domain        = "FAULT-DOMAIN-${(count.index%3)+1}"
  compartment_id      = var.compartment_ocid
  display_name        = "${local.cluster_name}_${var.storage_server_hostname_prefix}${format("%01d", count.index+1)}"
  shape               = local.derived_storage_server_shape

  source_details {
    source_type = "image"
    source_id   = local.image_id
  }

  create_vnic_details {
    subnet_id           = local.storage_subnet_id
    hostname_label      = "${var.storage_server_hostname_prefix}${format("%01d", count.index+1)}"
    assign_public_ip    = "false"
  }

  launch_options {
    network_type = (length(regexall("VM.Standard.E", local.derived_storage_server_shape)) > 0 ? "PARAVIRTUALIZED" : "VFIO")
  }

  metadata = {
    ssh_authorized_keys = join(
      "\n",
      [
        var.ssh_public_key,
        tls_private_key.ssh.public_key_openssh
      ]
    )
    user_data = base64encode(join("\n", list(
      "#!/usr/bin/env bash",
      "set -x",
    )))
  }

  dynamic "shape_config" {
    for_each = local.is_storage_server_flex_shape
      content {
        ocpus = shape_config.value
      }
  }

  timeouts {
    create = "120m"
  }

}



resource "oci_core_instance" "client_node" {
  count               = (var.create_compute_nodes ? var.client_node_count : 0)
  availability_domain = local.ad
  #fault_domain        = "FAULT-DOMAIN-${(count.index%3)+1}"
  compartment_id      = var.compartment_ocid
  display_name        = "${var.client_node_hostname_prefix}${format("%01d", count.index+1)}"
  shape               = var.client_node_shape

  source_details {
    source_type = "image"
    source_id   = local.image_id
  }

  create_vnic_details {
    subnet_id           = local.client_subnet_id
    hostname_label      = "${var.client_node_hostname_prefix}${format("%01d", count.index+1)}"
    assign_public_ip    = "false"
  }

  launch_options {
    network_type = (length(regexall("VM.Standard.E", var.client_node_shape)) > 0 ? "PARAVIRTUALIZED" : "VFIO")
  }

  metadata = {
    ssh_authorized_keys = join(
      "\n",
      [
        var.ssh_public_key,
        tls_private_key.ssh.public_key_openssh
      ]
    )
    user_data = base64encode(join("\n", list(
        "#!/usr/bin/env bash",
        "set -x",
      )))
    }

  dynamic "shape_config" {
    for_each = local.is_client_node_flex_shape
      content {
        ocpus = shape_config.value
      }
  }

  timeouts {
    create = "120m"
  }

}


# Quorum node named qdevice
resource "oci_core_instance" "quorum_server" {
  count               = var.fs_ha ? 1 : 0
  availability_domain = local.ad

  fault_domain        = "FAULT-DOMAIN-3"
  compartment_id      = var.compartment_ocid
  display_name        = "${local.cluster_name}_${var.quorum_server_hostname}"
  shape               = var.quorum_server_shape

  source_details {
    source_type = "image"
    source_id   = local.image_id
  }

  create_vnic_details {
    subnet_id        = local.storage_subnet_id
    hostname_label   = var.quorum_server_hostname
    assign_public_ip    = "false"
  }


  launch_options {
    network_type = (length(regexall("VM.Standard.E", var.quorum_server_shape)) > 0 ? "PARAVIRTUALIZED" : "VFIO")
  }

  metadata = {
    ssh_authorized_keys = join(
      "\n",
      [
        var.ssh_public_key,
        tls_private_key.ssh.public_key_openssh
      ]
    )
    user_data = base64encode(join("\n", list(
        "#!/usr/bin/env bash",
        "set -x",
      )))
    }

  dynamic "shape_config" {
    for_each = local.is_quorum_server_flex_shape
      content {
        ocpus = shape_config.value
      }
  }

  timeouts {
    create = "120m"
  }

}


