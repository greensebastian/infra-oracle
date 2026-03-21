terraform {
  backend "azurerm" {}
  required_providers {
    oci = { source = "oracle/oci"
    version = "8.5.0" }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

provider "oci" {}

locals {
  env        = terraform.workspace
  domain     = "infra"
  name       = "oracle"
  identifier = "${local.domain}-${local.name}-${local.env}"
  region     = lookup(module.regions.regions_by_display_name, "North Europe", null)
}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.2"
  suffix  = [local.domain, local.name, local.env]
}

module "regions" {
  source  = "Azure/regions/azurerm"
  version = "0.8.2"
}

data "azuread_client_config" "current" {}

data "azurerm_resource_group" "rg" {
  name = module.naming.resource_group.name
}

# --- Network ---

resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = ["10.0.0.0/16"]
  display_name   = "free-tier-vcn"
  dns_label      = "freetier"
}

resource "oci_core_internet_gateway" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "free-tier-igw"
  enabled        = true
}

resource "oci_core_route_table" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "free-tier-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.main.id
  }
}

resource "oci_core_security_list" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "free-tier-sl"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  dynamic "ingress_security_rules" {
    for_each = [22, 80, 443]
    iterator = port
    content {
      protocol = "6" # TCP
      source   = "0.0.0.0/0"
      tcp_options {
        min = port.value
        max = port.value
      }
    }
  }
}

resource "oci_core_subnet" "main" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.main.id
  cidr_block        = "10.0.1.0/24"
  display_name      = "free-tier-subnet"
  dns_label         = "main"
  route_table_id    = oci_core_route_table.main.id
  security_list_ids = [oci_core_security_list.main.id]
}

# Reserve the public IP
resource "oci_core_public_ip" "main" {
  compartment_id = var.compartment_ocid
  lifetime       = "RESERVED"
  display_name   = "free-vm-reserved-ip"
  private_ip_id  = data.oci_core_private_ips.main.private_ips[0].id
}

# Look up the primary VNIC
data "oci_core_vnic_attachments" "main" {
  compartment_id = var.compartment_ocid
  instance_id    = oci_core_instance.free_vm.id
}

# Look up the private IP from the VNIC
data "oci_core_private_ips" "main" {
  vnic_id = data.oci_core_vnic_attachments.main.vnic_attachments[0].vnic_id
}

output "vm_public_ip" {
  value = oci_core_public_ip.main.ip_address
}

# --- Ubuntu 22.04 ARM image lookup ---

data "oci_core_images" "ubuntu_arm" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

# --- VM ---

resource "oci_core_instance" "free_vm" {
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "free-tier-vm"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = 4
    memory_in_gbs = 24
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu_arm.images[0].id
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.main.id
    assign_public_ip = false
    display_name     = "primary-vnic"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = base64encode(file("${path.module}/cloud-init.sh"))
  }
}

# -- Persistent volume

resource "oci_core_volume" "main" {
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "free-tier-main-volume"
  size_in_gbs         = 50
}

resource "oci_core_volume_attachment" "main" {
  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.free_vm.id
  volume_id       = oci_core_volume.main.id
  display_name    = "free-tier-main-volume-attachment"
}
