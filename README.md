# dc5pg-build

This is the automation of building servers from temaplates on a Proxmox cluster 

IPs are randoimly created and checked via the firewall, which is a cisco ASA to make sure nothing else is using that IP address

## Terraform files
You'll need to add tfvars for the linux and Window servers and a providers .tf so you can connect to your proxmox cluster

## Ansible IPlookup
You'll need to preovide login credentials to your network device for the IP lookup, 

