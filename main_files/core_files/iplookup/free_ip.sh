#!/bin/sh

last_octet="$(shuf -i 100-200 -n 1)"
#echo $last_octet

ip_address=10.0.3.$last_octet
#echo $ip_address

echo "ip_address:" $ip_address > ip_addr.yml
#cat ip_addr.yml 

ansible-playbook  ip_test.yml -i network-inventory.yml --vault-password-file .vaultpass

if ! grep -q 10.0.[0-9[0-9].[0-9][0-9[0-9] /tmp/lookup.txt; then
  echo "Test passed, IP address $ip_address is free to use"
fi

