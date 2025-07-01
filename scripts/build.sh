#!/bin/sh

echo "Please enter your name:"
read username
uuid=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 6 | head -n 1 )
# echo $username"-"$uuid
echo "Making temporary directory at /tmp/$username"-"$uuid/"
mkdir /tmp/$username"-"$uuid/
cd /tmp/$username"-"$uuid/

echo "Copying main Terraform files."
# mkdir terraform
cp -r /home/build/main_files/core_files/tf_build/ terraform/

echo "Copying main IP lookup files"
# mkdir iplookup
cp -r /home/build/main_files/core_files/iplookup/ iplookup/

echo "How many Linux VMs do you want?"
read linux_vm_total
echo "We'll be creating $linux_vm_total Linux VMs"

echo "How many  Windows Server VMs do you want?"
read win_vm_total
echo "We'll be creating $win_vm_total Windows VMs"

num_of_vm=0

# Create files for Linux VMs

if [ $linux_vm_total != 0 ]; then 
    echo "We'll now go through the set up for the Linux VMs"
    num_of_vm=$linux_vm_total

    # start the lin tfvars file
    echo "lin_vms = {" > terraform/linux_vms.auto.tfvars
 
    while [ $num_of_vm != 0 ]; do 
        echo "Please enter the name of the VM"
        read vmname
        echo $vmname
        echo "Please enter the zone the VM should be plaved in? (web, DB, or DMZ)"
        read zone
        while [[ $zone != @("web"|"DB"|"DMZ") ]]; do
            echo "Invalid entry: $zone. The zone needs be be either web, DB, or DMZ"
            echo "try again:"
            read zone
        done
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
        
        echo "  \"$username-$uuid-$vmname\" = {" >> terraform/linux_vms.auto.tfvars
        echo "    vmname: \"lab-$username-$uuid-$vmname\"" >> terraform/linux_vms.auto.tfvars
        echo "    vlanid: \"1816\"" >> terraform/linux_vms.auto.tfvars
        echo "  }" >> terraform/linux_vms.auto.tfvars

        # Build linux_output.tf
        echo "" >> terraform/linux_output.tf
        echo "output \"$username-$uuid-$vmname-IP\" {" >> terraform/linux_output.tf
        echo "  value = proxmox_vm_qemu.linux_vms[\"$username-$uuid-$vmname\"].default_ipv4_address" >> terraform/linux_output.tf
        echo "  sensitive = false" >> terraform/linux_output.tf
        echo "}" >> terraform/linux_output.tf

        echo "" >> terraform/linux_output.tf
        echo "output \"$username-$uuid-$vmname-proxmoxID\" {" >> terraform/linux_output.tf
        echo "  value = proxmox_vm_qemu.linux_vms[\"$username-$uuid-$vmname\"].id" >> terraform/linux_output.tf
        echo "  sensitive = false" >> terraform/linux_output.tf
        echo "}" >> terraform/linux_output.tf

        # Populate File list of VMs in JSON for parsing later 
        echo "{\"linux_$username-$uuid-$vmname\" : { \"vmname\" : \"$username-$uuid-$vmname\", \"vlanid\" : \"$vlanid\", \"ipaddress\" : \"$ip_address\" }}" >> $username-vms.json
        ((num_of_vm--))
    done

    # finish the tfvars file
    echo "}" >> terraform/linux_vms.auto.tfvars
else
    echo "No linux VMs to create removing linux-vms.tf"
    rm terraform/linux_vms.tf
fi

# create files for the Windows VMs

if [ $win_vm_total != 0 ]; then 
    echo "We'll now go through the set up for the Windows VMs"
    num_of_vm=$win_vm_total

    # Start the tfvars file 
    echo "win_vms = {" > terraform/windows_vms.auto.tfvars
 
    while [ $num_of_vm != 0 ]; do 
        echo "Please enter the name of the VM"
        read vmname
        echo $vmname
        echo "Please enter the zone the VM should be plaved in? (web, DB, or DMZ)"
        read zone
        while [[ $zone != @("web"|"DB"|"DMZ") ]]; do
            echo "Invalid entry: $zone. The zone needs be be either web, DB, or DMZ"
            echo "try again:"
            read zone
        done
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


        # Build Windows_vms.tfvars scipt 
        echo "  \"$username-$uuid-$vmname\" = {" >> terraform/windows_vms.auto.tfvars
        echo "    vmname: \"lab-$username-$uuid-$vmname\"" >> terraform/windows_vms.auto.tfvars
        echo "    vlanid: \"1816\"" >> terraform/windows_vms.auto.tfvars
        echo "  }" >> terraform/windows_vms.auto.tfvars

        # Build windows_output.tf
        echo "" >> terraform/windows_output.tf
        echo "output \"$username-$uuid-$vmname-IP\" {" >> terraform/windows_output.tf
        echo "  value = proxmox_vm_qemu.windows_vms[\"$username-$uuid-$vmname\"].default_ipv4_address" >> terraform/windows_output.tf
        echo "  sensitive = false" >> terraform/windows_output.tf
        echo "}" >> terraform/windows_output.tf

        echo "" >> terraform/windows_output.tf
        echo "output \"$username-$uuid-$vmname-proxmoxID\" {" >> terraform/windows_output.tf
        echo "  value = proxmox_vm_qemu.windows_vms[\"$username-$uuid-$vmname\"].id" >> terraform/windows_output.tf
        echo "  sensitive = false" >> terraform/windows_output.tf
        echo "}" >> terraform/windows_output.tf

        # Populate File list of VMs in JSON for parsing later 
        echo "{\"win_$username-$uuid-$vmname\" : { \"vmname\" : \"$username-$uuid-$vmname\", \"vlanid\" : \"$vlanid\", \"ipaddress\" : \"$ip_address\" }}" >> $username-vms.json
        ((num_of_vm--))
    done

    # Finish the tfvars file 
    echo "}" >> terraform/windows_vms.auto.tfvars
else
    echo "No Windows VMs to create removing windows_vms.tf"
    rm terraform/windows_vms.tf
fi

cd terraform
/usr/bin/terraform init

if /usr/bin/terraform plan -json | tee plan.log; then
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

cd /tmp/$username"-"$uuid/
cp -r /home/build/main_files/core_files/ansible_initial_setup ansible_initial_setup
lin_host=$(grep linux_ $username-vms.json | wc -l)
win_host=$(grep win_ $username-vms.json | wc -l)

if [ $lin_host != 0 ]; then 
   # loop through VMs created and pull the linux infor from the json file

    # Create and start Ansible linux inventory file

    echo "lab_linux_inventory:" > ansible_initial_setup/linux_inventory.yml
    echo "  hosts:" >> ansible_initial_setup/linux_inventory.yml

    # start the lin tfvars file
    echo "lin_vms = {" > terraform/linux_vms.auto.tfvars

    # loop through VMs created and pull the linux infor from the json file
    while read LINE; do
        echo $LINE
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
        echo "    vmname: \"lab-$vmname\"" >> terraform/linux_vms.auto.tfvars
        echo "    vlanid: \"$vlanid\"" >> terraform/linux_vms.auto.tfvars
        echo "  }" >> terraform/linux_vms.auto.tfvars

    done < <(grep "linux_" chris-vms.json)

    # finish the tfvars file
    echo "}" >> terraform/linux_vms.auto.tfvars
else 
    echo "No Linux servers requested, skipping ansible config."
fi

if [ $win_vm_total != 0 ]; then 
# loop through VMs created and pull the Windows info from the json file

    # Create and start Ansible linux inventory file

    echo "lab_windows_inventory:" > ansible_initial_setup/windows_inventory.yml
    echo "  hosts:" >> ansible_initial_setup/windows_inventory.yml

    # start the lin tfvars file
    echo "win_vms = {" > terraform/windows_vms.auto.tfvars

    # loop through VMs created and pull the linux infor from the json file
    while read LINE; do
        echo $LINE
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
        echo "    $vmname:" >> ansible_initial_setup/windows_inventory.yml
        echo "      ansible_host: $dhcp_ip" >> ansible_initial_setup/windows_inventory.yml
        echo "      ansible_user: administrator" >> ansible_initial_setup/windows_inventory.yml
        echo "      ansible_password: Wfjt2bdge!" >> ansible_initial_setup/windows_inventory.yml
        echo "      ansible_port: 5986" >> ansible_initial_setup/windows_inventory.yml
        echo "      ansible_connection: winrm" >> ansible_initial_setup/windows_inventory.yml
        echo "      ansible_winrm_transport: ntlm" >> ansible_initial_setup/windows_inventory.yml
        echo "      ansible_winrm_server_cert_validation: ignore" >> ansible_initial_setup/windows_inventory.yml

        #Create and populate Ansible linux variables file
        echo "vmname: $vmname" > ansible_initial_setup/$vmname-variables.yml
        echo "ipaddress: $ipaddress" >> ansible_initial_setup/$vmname-variables.yml
        echo "gateway: $gateway" >> ansible_initial_setup/$vmname-variables.yml

        sleep 60

        ansible-playbook ansible_initial_setup/windows_initial_setup.yml -i ansible_initial_setup/windows_inventory.yml --extra-vars "@ansible_initial_setup/$vmname-variables.yml"

        echo "  \"$vmname\" = {" >> terraform/windows_vms.auto.tfvars
        echo "    vmname: \"lab-$vmname\"" >> terraform/windows_vms.auto.tfvars
        echo "    vlanid: \"$vlanid\"" >> terraform/windows_vms.auto.tfvars
        echo "  }" >> terraform/windows_vms.auto.tfvars

    done < <(grep "win_" chris-vms.json)

    # finish the tfvars file
    echo "}" >> terraform/windows_vms.auto.tfvars

else 
    echo "No Windows servers requested, skipping ansible config."
fi

cd terraform

if /usr/bin/terraform plan -json | tee plan.log; then
    echo "Terraform plan successful applying changes"
    /usr/bin/terraform apply -json --auto-approve | tee -a apply.log
else
    echo "Terraform plan failed. Please review plan.log"
    exit 1
fi
cd ../ 

if [ $lin_host != 0 ]; then 

    echo "lab_linux_inventory:" > ansible_initial_setup/linux_inventory.yml
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

    done < <(grep "linux_" chris-vms.json)
    sleep 10
    ansible lab_linux_inventory -i ansible_initial_setup/linux_inventory.yml -m ping

fi

if [ $win_vm_total != 0 ]; then 
 
    echo "lab_windows_inventory:" > ansible_initial_setup/windows_inventory.yml
    echo "  hosts:" >> ansible_initial_setup/windows_inventory.yml

    while read LINE; do
        echo $LINE
        # echo $LINE | jq -r .[].vmname
        vmname=$(echo $LINE | jq -r .[].vmname)
        ipaddress=$(echo $LINE | jq -r .[].ipaddress)
        echo $vmname
        echo $ipaddress
        echo "## All data parsed ##" 

        #Populate Ansible inventory file
        echo "    $vmname:" >> ansible_initial_setup/windows_inventory.yml
        echo "      ansible_host: $ipaddress" >> ansible_initial_setup/windows_inventory.yml
        echo "      ansible_user: administrator" >> ansible_initial_setup/windows_inventory.yml
        echo "      ansible_password: Wfjt2bdge!" >> ansible_initial_setup/windows_inventory.yml
        echo "      ansible_port: 5986" >> ansible_initial_setup/windows_inventory.yml
        echo "      ansible_connection: winrm" >> ansible_initial_setup/windows_inventory.yml
        echo "      ansible_winrm_transport: ntlm" >> ansible_initial_setup/windows_inventory.yml
        echo "      ansible_winrm_server_cert_validation: ignore" >> ansible_initial_setup/windows_inventory.yml

    done < <(grep "win_" chris-vms.json)
    sleep 10
    ansible lab_windows_inventory -i ansible_initial_setup/windows_inventory.yml -m win_ping
    ansible lab_windows_inventory -i ansible_initial_setup/windows_inventory.yml -m win_reboot

fi
exit 0