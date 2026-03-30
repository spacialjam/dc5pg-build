#!/bin/sh

echo "The running labs are:"
running_labs="$(find /tmp -type d -name "lab-*" 2>/dev/null | awk -F "/" '{print $3}')"
for i in $running_labs; do (
    echo $i
)
done
echo "Which lab do you wish to end?"
read lab_choice
echo "You have choosen to end the lab $lab_choice."
echo "This will run the terrafom destroy commend wiping the VMs and then delete the folder containing all the data."
echo "Please confirm that you want to go ahead (Y/N)"
read confirmation

if [ $confirmation = Y ] || [ $confirmation = y ]; then
    echo "Stopping $lab_choice and removing VMs"
    cd /tmp/$lab_choice/terraform
    terraform destroy # --auto-approve
    echo "emptying and removing lab folder and files"
    cd /tmp/
    rm -r $lab_choice
else
    echo "Nothing to do, exiting script"
    exit 0
fi