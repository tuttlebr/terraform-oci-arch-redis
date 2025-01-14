## Copyright (c) 2022 Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

data "template_file" "key_script" {
  template = file("${path.module}/scripts/sshkey.tpl")
  vars = {
    ssh_public_key = tls_private_key.public_private_key_pair.public_key_openssh
  }
}

data "template_cloudinit_config" "cloud_init" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "ainit.sh"
    content_type = "text/x-shellscript"
    content      = data.template_file.key_script.rendered
  }
}

resource "oci_core_instance" "redis_master" {
  count               = var.numberOfMasterNodes
  availability_domain = local.availability_domain_name
  # fault_domain        = "FAULT-DOMAIN-1"
  compartment_id      = var.compartment_ocid
  display_name        = "redis${count.index + 1}"
  shape               = var.instance_shape

  dynamic "shape_config" {
    for_each = local.is_flexible_node_shape ? [1] : []
    content {
      memory_in_gbs = var.instance_flex_shape_memory
      ocpus         = var.instance_flex_shape_ocpus
    }
  }

  dynamic "agent_config" {
    for_each = var.use_private_subnet ? [1] : []
    content {
      are_all_plugins_disabled = false
      is_management_disabled   = false
      is_monitoring_disabled   = false
      plugins_config {
        desired_state = "ENABLED"
        name          = "Bastion"
      }
    }
  }

  create_vnic_details {
    subnet_id        = !var.use_existing_vcn ? oci_core_subnet.redis-subnet[0].id : var.redis_subnet_id
    display_name     = "primaryvnic"
    assign_public_ip = var.use_private_subnet ? false : true
    hostname_label   = "${var.redis-prefix}${count.index + 1}"
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.InstanceImageOCID.images[0].id
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = data.template_cloudinit_config.cloud_init.rendered
  }

  provisioner "local-exec" {
    command = "sleep 240"
  }

  # defined_tags = { "${oci_identity_tag_namespace.ArchitectureCenterTagNamespace.name}.${oci_identity_tag.ArchitectureCenterTag.name}" = var.release }
}

resource "oci_core_instance" "redis_replica" {
  count               = var.numberOfReplicaNodes
  availability_domain = local.availability_domain_name
  # fault_domain        = "FAULT-DOMAIN-2"
  compartment_id      = var.compartment_ocid
  display_name        = "redis${count.index + 1 + var.numberOfMasterNodes}"
  shape               = var.instance_shape

  dynamic "shape_config" {
    for_each = local.is_flexible_node_shape ? [1] : []
    content {
      memory_in_gbs = var.instance_flex_shape_memory
      ocpus         = var.instance_flex_shape_ocpus
    }
  }

  dynamic "agent_config" {
    for_each = var.use_private_subnet ? [1] : []
    content {
      are_all_plugins_disabled = false
      is_management_disabled   = false
      is_monitoring_disabled   = false
      plugins_config {
        desired_state = "ENABLED"
        name          = "Bastion"
      }
    }
  }

  create_vnic_details {
    subnet_id        = !var.use_existing_vcn ? oci_core_subnet.redis-subnet[0].id : var.redis_subnet_id
    display_name     = "primaryvnic"
    assign_public_ip = var.use_private_subnet ? false : true
    hostname_label   = "${var.redis-prefix}${count.index + 1 + var.numberOfMasterNodes}"
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.InstanceImageOCID.images[0].id
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = data.template_cloudinit_config.cloud_init.rendered
  }

  provisioner "local-exec" {
    command = "sleep 240"
  }

  # defined_tags = { "${oci_identity_tag_namespace.ArchitectureCenterTagNamespace.name}.${oci_identity_tag.ArchitectureCenterTag.name}" = var.release }
}
