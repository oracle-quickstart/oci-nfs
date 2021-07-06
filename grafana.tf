
resource "oci_core_instance" "monitoring_server" {
  count               = var.create_monitoring_server ? 1 : 0
  availability_domain = local.ad

  #fault_domain        = "FAULT-DOMAIN-3"
  compartment_id      = var.compartment_ocid
  display_name        = "${local.cluster_name}_${var.monitoring_server_hostname}"
  shape               = var.monitoring_server_shape

  source_details {
    source_type = "image"
    source_id   = local.image_id
  }

  create_vnic_details {
    subnet_id        = local.storage_subnet_id
    hostname_label   = var.monitoring_server_hostname
    assign_public_ip    = "false"
  }

  /* - Optional
  launch_options {
    network_type = (length(regexall("VM.Standard.E", var.monitoring_server_shape)) > 0 ? "PARAVIRTUALIZED" : "VFIO")
  }
  */

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
    for_each = local.is_monitoring_server_flex_shape
      content {
        ocpus = shape_config.value
      }
  }
  agent_config {
    is_management_disabled = true
  }

  timeouts {
    create = "120m"
  }

}

