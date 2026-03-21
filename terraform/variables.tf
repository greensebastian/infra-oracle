variable "subscription_id" {
  description = "Subscription id for the resources."
  type        = string
}

variable "compartment_ocid" {
  description = "OCID of the compartment to deploy into (use tenancy_ocid for root)"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key to inject into the VM"
  type        = string
}
