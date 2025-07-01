variable "win_vms" {
  type = map(object({
    vmname = string
    vlanid = string
  }))
  description = "This sets the name and VLAN ID for the Windows VM"
}

resource "proxmox_vm_qemu" "windows_vms" {
  for_each    = var.win_vms

  timeouts {
    create = "30m"
  }

  name        = each.value.vmname
  target_node = "dc5pg-proxmox3"

  clone      = "dc5pg-win22-template"
  full_clone = true
  cores      = "4"
  memory     = "8192"
  scsihw     = "virtio-scsi-single"
  bios       = "ovmf"
  agent      = 1
  skip_ipv6  = true

  disk {
    size    = "60G"
    storage = "sata-pool"
    slot    = "scsi0"
  }

  efidisk {
    efitype = "4m"
    storage = "local-zfs"
  }

  tpm_state {
    storage = "local-zfs"
    version = "v2.0"
  }

  network {
    id       = 0
    bridge   = "vmbr0"
    firewall = true
    model    = "virtio"
    tag      = each.value.vlanid
  }
}

