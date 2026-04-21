#!/bin/sh

if [ $# -eq 0 ]; then
    echo "Usage: $0 [-n name]"
    exit 1
fi

while getopts "hn:" opt; do
    case "$opt" in
    h)
        echo "Usage: $0 [-n name]"
        exit 0
        ;;
    n)  username=$OPTARG
        ;;
    \?)
        echo "invalid option!!!"
        echo "Usage: $0 [-n name]"
        exit 1
        ;;
    esac
done

# echo "Please enter your name or a unique name:"
# echo "Please only use hyphens (-) as a seperator as the services used in this script might not accept anything else."
# read username
uuid=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 6 | head -n 1 )
# echo $username"-"$uuid
echo "Making temporary directory at /home/build/temp/lab"-"$username"-"$uuid/"
mkdir /home/build/temp/lab"-"haproxy"-"$username"-"$uuid/
cd /home/build/temp/lab"-"haproxy"-"$username"-"$uuid/

echo "Copying main Terraform files."
# mkdir terraform
cp -r /home/build/main_files/core_files/tf_build/ terraform/

echo "Copying main IP lookup files"
# mkdir iplookup
cp -r /home/build/main_files/core_files/iplookup/ iplookup/


linux_vm_total=4
echo "We'll be creating $linux_vm_total Linux VMs, 2 Web servers and 2 HAProxy Load balancers."

echo "{\"linux_$username-$uuid-web1\" : { \"vmname\" : \"lab-$username-$uuid-web1\", \"zone\" : \"web\" }}" >> $username-vms-temp.json
echo "{\"linux_$username-$uuid-web2\" : { \"vmname\" : \"lab-$username-$uuid-web2\", \"zone\" : \"web\" }}" >> $username-vms-temp.json
echo "{\"linux_$username-$uuid-lb1\" : { \"vmname\" : \"lab-$username-$uuid-lb1\", \"zone\" : \"DMZ\" }}" >> $username-vms-temp.json
echo "{\"linux_$username-$uuid-lb2\" : { \"vmname\" : \"lab-$username-$uuid-lb2\", \"zone\" : \"DMZ\" }}" >> $username-vms-temp.json

# Create files for Linux VMs
echo "We'll now go through the set up for the Linux VMs"

echo "lin_vms = {" > terraform/linux_vms.auto.tfvars

while read LINE; do 
    vmname=$(echo $LINE | jq -r .[].vmname)
    echo $vmname
    zone=$(echo $LINE | jq -r .[].zone)
    
    case $zone in
        web)    vlanid=1808
                subnet="10.0.2"
                ;;
        DB)     vlanid=1813
                subnet="10.0.3"
                ;;
        DMZ)    vlanid=846
                subnet="10.0.4"
                ;;
    esac
    echo "You have chosen $zone which is VLAN ID: $vlanid"

    #Create and find a free IP

    free_ip=false
    while [ $free_ip == false ]; do
        last_octet="$(shuf -i 100-200 -n 1)"
        ip_address=$subnet.$last_octet
        echo "Testing IP address: $ip_address"
        echo "ip_address:" $ip_address > ip_addr.yml
        ansible-playbook  iplookup/ip_test.yml -i iplookup/network-inventory.yml --vault-password-file iplookup/.vaultpass
        if ! grep -q 10.0.[0-9[0-9].[0-9][0-9[0-9] /tmp/lookup.txt; then
            echo "Test passed, IP address $ip_address is free to use"
            rm -f /tmp/lookup.txt
            free_ip=true
        else
            echo "IP in use, trying again."
        fi
    done

    # Build linux_vms.auto.tfvars scipt  
    
    echo "  \"$vmname\" = {" >> terraform/linux_vms.auto.tfvars
    echo "    vmname: \"$vmname\"" >> terraform/linux_vms.auto.tfvars
    echo "    vlanid: \"1816\"" >> terraform/linux_vms.auto.tfvars
    echo "  }" >> terraform/linux_vms.auto.tfvars

    # Build linux_output.tf
    echo "" >> terraform/linux_output.tf
    echo "output \"$vmname-IP\" {" >> terraform/linux_output.tf
    echo "  value = proxmox_vm_qemu.linux_vms[\"$vmname\"].default_ipv4_address" >> terraform/linux_output.tf
    echo "  sensitive = false" >> terraform/linux_output.tf
    echo "}" >> terraform/linux_output.tf

    echo "" >> terraform/linux_output.tf
    echo "output \"$vmname-proxmoxID\" {" >> terraform/linux_output.tf
    echo "  value = proxmox_vm_qemu.linux_vms[\"$vmname\"].id" >> terraform/linux_output.tf
    echo "  sensitive = false" >> terraform/linux_output.tf
    echo "}" >> terraform/linux_output.tf

    # Populate File list of VMs in JSON for parsing later 
    echo "{\"linux_$vmname\" : { \"vmname\" : \"$vmname\", \"vlanid\" : \"$vlanid\", \"ipaddress\" : \"$ip_address\" }}" >> $username-vms.json
done < <(cat  $username-vms-temp.json)

# finish the tfvars file
echo "}" >> terraform/linux_vms.auto.tfvars
echo "No Windows VMs to create removing windows_vms.tf"
rm terraform/windows_vms.tf    


cd terraform
/usr/bin/terraform init
/usr/bin/terraform plan -json | tee plan.log

if ! /usr/bin/grep -q Error plan.log ; then
    echo "Terraform plan successful applying changes"
    /usr/bin/terraform apply -json --auto-approve | tee apply.log
else
    echo "Terraform plan failed. Please review plan.log"
    exit 1
fi

# just in case it built a VM has not reported it's IP back 
echo "Let's give the VMs a minute to start"
sleep 60s
/usr/bin/terraform refresh > /dev/null 2>&1

/usr/bin/terraform output

echo "Success!! Terraform VM creation complete."

cd ../
cp -r /home/build/main_files/core_files/ansible_initial_setup ansible_initial_setup
lin_host=$(grep linux_ $username-vms.json | wc -l)

if [ $lin_host != 0 ]; then 
   # loop through VMs created and pull the linux infor from the json file

    # Create and start Ansible linux inventory file

    echo "lab_linux_inventory:" > ansible_initial_setup/linux_inventory.yml
    echo "  hosts:" >> ansible_initial_setup/linux_inventory.yml

    # start the lin tfvars file
    echo "lin_vms = {" > terraform/linux_vms.auto.tfvars

    # loop through VMs created and pull the linux infor from the json file
    while read LINE; do
        # echo $LINE
        # echo $LINE | jq -r .[].vmname
        vmname=$(echo $LINE | jq -r .[].vmname)
        # echo $LINE | jq -r .[].vlanid
        vlanid=$(echo $LINE | jq -r .[].vlanid)
        # echo $LINE | jq -r .[].ipaddress
        ipaddress=$(echo $LINE | jq -r .[].ipaddress)
        # terraform output -state=terraform/terraform.tfstate | grep $vmname-IP | awk '{print $3}' | sed s/\"//g
        dhcp_ip=$(terraform output -state=terraform/terraform.tfstate | grep $vmname-IP | awk '{print $3}' | sed s/\"//g)
        echo "## All data parsed ##" 
        gateway=$(echo $ipaddress | awk -F. '{print $1"."$2"."$3".254"}')


        #Populate Ansible inventory file
        echo "    $vmname:" >> ansible_initial_setup/linux_inventory.yml
        echo "      ansible_host: $dhcp_ip" >> ansible_initial_setup/linux_inventory.yml
        echo "      ansible_user: root" >> ansible_initial_setup/linux_inventory.yml

        #Create and populate Ansible linux variables file
        echo "vmname: $vmname" > ansible_initial_setup/$vmname-variables.yml
        echo "ipaddress: $ipaddress" >> ansible_initial_setup/$vmname-variables.yml
        echo "gateway: $gateway" >> ansible_initial_setup/$vmname-variables.yml

        sleep 60

        ansible-playbook ansible_initial_setup/linux_initial_setup.yml -i ansible_initial_setup/linux_inventory.yml --extra-vars "@ansible_initial_setup/$vmname-variables.yml"

        echo "  \"$vmname\" = {" >> terraform/linux_vms.auto.tfvars
        echo "    vmname: \"$vmname\"" >> terraform/linux_vms.auto.tfvars
        echo "    vlanid: \"$vlanid\"" >> terraform/linux_vms.auto.tfvars
        echo "  }" >> terraform/linux_vms.auto.tfvars

    done < <(grep "linux_" $username-vms.json)

    # finish the tfvars file
    echo "}" >> terraform/linux_vms.auto.tfvars
fi

cd terraform
/usr/bin/terraform plan -json | tee plan.log

if ! /usr/bin/grep -q Error plan.log; then
    echo "Terraform plan successful applying changes"
    /usr/bin/terraform apply -json --auto-approve | tee -a apply.log
else
    echo "Terraform plan failed. Please review plan.log"
    exit 1
fi
cd ../ 

if [ $lin_host != 0 ]; then 

    echo "lab_linux_inventory:" > ansible_initial_setup/linux_inventory.yml
    echo "  children:" >> ansible_initial_setup/linux_inventory.yml
    echo "    web:" >> ansible_initial_setup/linux_inventory.yml
    echo "    lb:" >> ansible_initial_setup/linux_inventory.yml
    echo "web:" >> ansible_initial_setup/linux_inventory.yml
    echo "  hosts:" >> ansible_initial_setup/linux_inventory.yml


    while read LINE; do
        echo $LINE
        # echo $LINE | jq -r .[].vmname
        vmname=$(echo $LINE | jq -r .[].vmname)
        ipaddress=$(echo $LINE | jq -r .[].ipaddress)
        echo $vmname
        echo $ipaddress
        echo "## All data parsed ##" 

            #Populate Ansible inventory file
        echo "    $vmname:" >> ansible_initial_setup/linux_inventory.yml
        echo "      ansible_host: $ipaddress" >> ansible_initial_setup/linux_inventory.yml
        echo "      ansible_user: root" >> ansible_initial_setup/linux_inventory.yml

    done < <(grep "\-web" $username-vms.json)
    

    echo "lb:" >> ansible_initial_setup/linux_inventory.yml
    echo "  hosts:" >> ansible_initial_setup/linux_inventory.yml

    while read LINE; do
        echo $LINE
        # echo $LINE | jq -r .[].vmname
        vmname=$(echo $LINE | jq -r .[].vmname)
        ipaddress=$(echo $LINE | jq -r .[].ipaddress)
        echo $vmname
        echo $ipaddress
        echo "## All data parsed ##" 

            #Populate Ansible inventory file
        echo "    $vmname:" >> ansible_initial_setup/linux_inventory.yml
        echo "      ansible_host: $ipaddress" >> ansible_initial_setup/linux_inventory.yml
        echo "      ansible_user: root" >> ansible_initial_setup/linux_inventory.yml

    done < <(grep "\-lb" $username-vms.json)

    sleep 60
    ansible lab_linux_inventory -i ansible_initial_setup/linux_inventory.yml -m ping
    ansible-playbook /home/build/main_files/templates/haproxy/webserver-build.yml -i ansible_initial_setup/linux_inventory.yml

fi

# refresh the terraform date 
cd terraform
terraform refresh
cd ../
rm $username-vms-temp.json

exit 0