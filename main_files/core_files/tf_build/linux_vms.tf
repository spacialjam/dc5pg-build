variable "lin_vms" {
  type = map(object({
    vmname = string
    vlanid = string
  }))
  description = "This sets the name and VLAN ID for the Linux VM"
}

resource "proxmox_vm_qemu" "linux_vms" {
  for_each    = var.lin_vms

  timeouts {
    create = "30m"
  }

  name        = each.value.vmname
  target_node = "dc5pg-proxmox2"

  clone      = "dc5pg-alma9-template"
  full_clone = true
  scsihw     = "virtio-scsi-single"
  agent      = 1
  skip_ipv6  = true

  disk {
    size    = "32G"
    storage = "sata-pool"
    slot    = "scsi0"
    format  = "raw"
  }

  network {
    id       = 0
    bridge   = "vmbr0"
    firewall = true
    model    = "virtio"
    tag      = each.value.vlanid
  }
}
