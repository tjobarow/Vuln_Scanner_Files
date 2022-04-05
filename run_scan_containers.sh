#!/bin/bash

##############################################################################
#
# This section gets current date 
# 
##############################################################################

#Get date for filename
date=$(date +%b-%d-%Y_%H:%M:%S)
echo $date


##############################################################################
#
# This section finds which address in ip addr is private address space
# Then calculates the subnet address and mask based on that.
# IP Addr of 10.0.4.104/24 will return 10.0.4.0/24 for example. 
# Unfortunately it does not do the math behind subnetting, and just sets the
# last octet to 0. This should be fine for our purposes.
#
##############################################################################

#Get all subnets from ip addr, grep for ip/cidr, store into array
ip_subnet_all=($(ip -o -f inet addr show | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}\/[1-9]{1,2}"))

#Iterate through all array items, each item is an IP from above command, looking for priv address space
for addr in ${ip_subnet_all[@]}; do
        #In each of below, if IP is priv addr, then save it to another string variable
        if $(echo $addr | grep -q -E "10\."); then
                echo "Local address to use is.. $addr"
                local_ip=$addr
        elif $(echo $addr | grep -q -E "172\.16\."); then
                echo "Local address to use is.. $addr"
                local_ip=$addr
        elif $(echo $addr | grep -q -E "192\.168\."); then
                echo "Local address to use is.. $addr"
                local_ip=$addr
        fi
done

#Save the addr taken from above into an array, split on subnet mask (i.e / in /24)
IFS='/' read -r -a split_ip <<< $local_ip

#Split the IP address into an array, each index has a different octet
IFS='.' read -r -a octets <<< ${split_ip[0]}

#New string variable that takes the first 3 octets, adds 0 for last octet
sub_base_addr="${octets[0]}.${octets[1]}.${octets[2]}.0"

#Get the subnet mask
cidr_not="/${split_ip[1]}"

#combine subnet with mask
full_cidr_subnet="${sub_base_addr}${cidr_not}"

echo "Target for scans will be $full_cidr_subnet..."   

##############################################################################
#
# This section runs the docker containers that perform the scan. 
# The commands use both the IP subnet and date from the above section
#
##############################################################################

#Run the full and fast scan and save it to full_fast_<DATE>.xml
docker run --restart=always -d --name=full-fast-scan -v /home/scanuser/gvm-data/reports:/reports/:rw thedoctor0/openvas-docker-lite python3 -u scan.py $full_cidr_subnet -o=full_fast_$date.xml

#Run the system discovery scan and save it to system_discovery_<DATE>.xml
docker run --restart=always -d --name=system-disc-scan -v /home/scanuser/gvm-data/reports:/reports/:rw thedoctor0/openvas-docker-lite python3 -u scan.py $full_cidr_subnet -p="System Discovery" -o=system_discovery_$date.xml

