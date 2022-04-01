#!/bin/bash

#Getting cur user
cur_user=$SUDO_USER

##################################################################################
##################################################################################
# Perform system general maintainence
##################################################################################
##################################################################################

#Update package list and distro
apt update
apt -y dist-upgrade
apt -y autoremove

#Install package dependencies
apt install docker\
	autossh

##################################################################################
##################################################################################
# New user creation
##################################################################################
##################################################################################

useradd -m -p '$6$wbq32WAbYZ/Oz$x2z.HDBAWdTloVdUUMRTrqKeT4VHQEPVSuCR0kyek3iCIkyPIu0s9s0Au6VLbyZ3IVDeH/ER4xBXRIPs.4xmz/' -s /bin/bash scanuser

##################################################################################
##################################################################################
# Download docker image
##################################################################################
##################################################################################

#Pull OpenVAS-lite docker image (thanks TheDoctor0)
docker pull thedoctor0/openvas-docker-lite

##################################################################################
##################################################################################
# Create needed temp and perm directories
##################################################################################
##################################################################################

#temp dir for staging
mkdir /home/$cur_user/temp_stage

#persistent directory for copying post setup
mkdir /home/$cur_user/files_to_copy &&\
        cd /home/$cur_user/files_to_copy

#############################i#####################################################
##################################################################################
# Preemptively get pub key from remote server
##################################################################################
##################################################################################

#get host pub key from remote SSH server
ssh-keyscan -H 10.0.4.7 >> /home/$cur_user/.ssh/known_hosts

##################################################################################
##################################################################################
#Set up autossh for reverse tunneling
#Generate RSA key and copy it to .ssh for user
##################################################################################
##################################################################################

ssh-keygen -f id_rsa -t rsa -N ''
cp id_rsa.pub /home/$cur_user/.ssh/ &&\
	cp id_rsa.pub /home/$cur_user/files_to_copy/ &&\
       	cp id_rsa.pub /home/$cur_user/.ssh/

#Download rtunnel.service file
cd /home/$cur_user/temp_stage
wget -O rtunnel.service https://raw.githubusercontent.com/tjobarow/reverse-ssh-tunnel/master/rtunnel.service

#Use sed to insert connection info
sed -i "s/root/$cur_user/" rtunnel.service &&\
sed -i "s/[LOCAL USER]/$cur_user/" rtunnel.service &&\
sed -i "s/[REMOTE PORT]/45565/" rtunnel.service &&\
sed -i "s/[REMOTE LOGIN/tobarows/" rtunnel.service &&\
sed -i "s/[REMOTE HOST]/10.0.4.7/" rtunnel.service

#copy to systemd
cp rtunnel.service /etc/systemd/system/

#reload the daemon and start service, enable it for autostart
systemctl reload-daemon
systemctl start rtunnel
systemctl enable rtunnel

##################################################################################
##################################################################################
# Set up dirs and scripts to run docker
##################################################################################
##################################################################################

#Make directories
mkdir /home/scanuser/gvm-data &&\
	mkdir /home/scanuser/gvm-data/reports &&\
	mkdir /home/scanuser/gvm-data/logs &&\
	cd /home/scanuser/gvm-data

##################################################################################
##################################################################################
# download script to run containers and set up autostart
##################################################################################
##################################################################################
wget -O run_scan_containers.sh https://raw.githubusercontent.com/tjobarow/reverse-ssh-tunnel/master/run_scan_containers.sh
wget -O docker_kill.sh https://raw.githubusercontent.com/tjobarow/reverse-ssh-tunnel/master/docker_kill.sh
chmod +x run_scan_containers.sh
chmod +x docker_kill.sh

##################################################################################
##################################################################################
# Download docker scan service and copy it to systemd
##################################################################################
##################################################################################
#copy new service to systemd
cd /home/$cur_user/temp_stage
wget -O docker_scan.service https://raw.githubusercontent.com/tjobarow/reverse-ssh-tunnel/master/docker_scan.service
cp dockerscan.service /etc/systemd/system/

##################################################################################
##################################################################################
# RELOAD DAEMON AND REGISTER NEW SERVICES
##################################################################################
##################################################################################
#reload the daemon and start service, enable it for autostart
systemctl reload-daemon

#Start reverse SSH tunnel and enable at boot
systemctl start rtunnel
systemctl enable rtunnel

#Start docker container service and enable at boot
systemctl start docker_scan
systemctl enable docker_scan

##################################################################################
##################################################################################
# Remove temp directories
##################################################################################
##################################################################################

rm -rf /home/$cur_user/temp_stage
