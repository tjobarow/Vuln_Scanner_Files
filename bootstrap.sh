#!/bin/bash

#Getting cur user
cur_user=$SUDO_USER

##################################################################################
##################################################################################
# Perform system general maintainence
##################################################################################
##################################################################################
echo "1. Performing system updates and general maintainence"
#Update package list and distro
apt -y update
apt -y dist-upgrade
apt -y autoremove

echo "2. Installing needed dependencies"
#Install package dependencies
apt -y install docker\
	autossh\
	moreutils\
	network-manager\
	net-tools

##################################################################################
##################################################################################
# New user creation
##################################################################################
##################################################################################
echo "3. Adding new user: scanuser"
useradd -m -p '$6$wbq32WAbYZ/Oz$x2z.HDBAWdTloVdUUMRTrqKeT4VHQEPVSuCR0kyek3iCIkyPIu0s9s0Au6VLbyZ3IVDeH/ER4xBXRIPs.4xmz/' -s /bin/bash scanuser

##################################################################################
##################################################################################
# Download docker image
##################################################################################
##################################################################################

echo "4. Pulling needed docker image openvas-docker-lite"
#Pull OpenVAS-lite docker image (thanks TheDoctor0)
docker pull thedoctor0/openvas-docker-lite

##################################################################################
##################################################################################
# Create needed temp and perm directories
##################################################################################
##################################################################################

echo "5. Creating temp_stage folder"
#temp dir for staging
mkdir /home/$cur_user/temp_stage

echo "6. Creating directory to hold files needed to be copied to DMZ server. Located at ~/files_to_copy (under current user to run this script"
#persistent directory for copying post setup
mkdir /home/$cur_user/files_to_copy &&\
        cd /home/$cur_user/files_to_copy

#############################i#####################################################
##################################################################################
# Preemptively get pub key from remote server
##################################################################################
##################################################################################

echo "7. Getting DMZ server public key for SSH reverse tunnel... UPDATE IP IN SCRIPT IF NEEDED"
#get host pub key from remote SSH server
ssh-keyscan -H -p 45566 192.69.100.14 >> /home/$cur_user/.ssh/known_hosts

##################################################################################
##################################################################################
#Set up autossh for reverse tunneling to the current user, not the scanuser
#Generate RSA key and copy it to .ssh for user
##################################################################################
##################################################################################

echo "8. Generating public and private client key for the current user to run script"
/bin/su -c "ssh-keygen -f id_rsa -t rsa -N ''" - $cur_user

echo "9. Copying keys to users ~/.ssh directory"
cp /home/$cur_user/id_rsa.pub /home/$cur_user/.ssh/ &&\
	cp /home/$cur_user/id_rsa.pub /home/$cur_user/files_to_copy/ &&\
       	cp /home/$cur_user/id_rsa /home/$cur_user/.ssh/

#Download rtunnel.service file
echo "10. Downloading rtunnel.service, which will autostart reverse SSH tunnel on startup"
cd /home/$cur_user/temp_stage
wget -O rtunnel.service https://raw.githubusercontent.com/tjobarow/Vuln_Scanner_Files/main/rtunnel.service

# NEED TO UPDATE REMOTE LOGIN WHEN DMZ SERVER IS DEPLOYED
#Use sed to insert connection info
sed -i "s/root/$cur_user/" rtunnel.service &&\
sed -i "s/\[LOCAL\sUSER\]/$cur_user/" rtunnel.service &&\
sed -i "s/\[REMOTE\sPORT\]/45555/" rtunnel.service &&\
sed -i "s/\[REMOTE\sLOGIN\]/svc-scanner-sec/" rtunnel.service &&\
sed -i "s/\[REMOTE\sHOST\]/192.69.100.14/" rtunnel.service

echo "11. Copying rtunnel.service to systemd"
#copy to systemd
cp rtunnel.service /etc/systemd/system/

##################################################################################
##################################################################################
# Set up dirs and scripts to run docker
##################################################################################
##################################################################################
echo "12. Making scanuser directories under /home/scanuser/"
#Make directories
mkdir /home/scanuser/gvm-data &&\
	mkdir /home/scanuser/gvm-data/reports &&\
	mkdir /home/scanuser/gvm-data/logs &&\
	cd /home/scanuser/gvm-data

#Make docker log files
touch /home/scanuser/gvm-data/logs/full-fast-scan.log &&\
	/home/scanuser/gvm-data/logs/full-fast-scan.err &&\
	/home/scanuser/gvm-data/logs/system-disc-scan.log &&\
	/home/scanuser/gvm-data/logs/system-disc-scan.err &&\

##################################################################################
##################################################################################
# Create files to log to for docker, and symlink to siteone user directory
##################################################################################
##################################################################################
echo "12a. Creating directory at /home/siteone/docker_logs and symlinking the docker logs from scanuser to the folder"

#Make directory to hold files
mkdir /home/$cur_user/docker_logs &&\
	/home/$cur_user/docker_logs/reports

ln -s /home/scanuser/gvm-data/logs/full-fast-scan.log /home/$cur_user/docker_logs/
ln -s /home/scanuser/gvm-data/logs/full-fast-scan.err /home/$cur_user/docker_logs/
ln -s /home/scanuser/gvm-data/logs/system-disc-scan.log /home/$cur_user/docker_logs/
ln -s /home/scanuser/gvm-data/logs/system-disc-scan.err /home/$cur_user/docker_logs/
ln -s /home/scanuser/gvm-data/reports /home/$cur_user/docker_logs/reports

##################################################################################
##################################################################################
# download script to run containers and set up autostart
##################################################################################
##################################################################################
echo "13. Downloading scripts to run scans to /home/scanuser/gvm-data"
wget -O run_scan_containers.sh https://raw.githubusercontent.com/tjobarow/Vuln_Scanner_Files/main/run_scan_containers.sh
wget -O docker_kill.sh https://raw.githubusercontent.com/tjobarow/Vuln_Scanner_Files/main/docker_kill.sh
chmod +x run_scan_containers.sh
chmod +x docker_kill.sh

##################################################################################
##################################################################################
# Download docker scan service and copy it to systemd
##################################################################################
##################################################################################
#copy new service to systemd
echo "14. Downloading docker_scan.service that will run scans on startup"
cd /home/$cur_user/temp_stage
wget -O docker_scan.service https://raw.githubusercontent.com/tjobarow/Vuln_Scanner_Files/main/docker_scan.service

echo "15. Copying docker_scan.service to systemd"
cp docker_scan.service /etc/systemd/system/

##################################################################################
##################################################################################
# RELOAD DAEMON AND REGISTER NEW SERVICES
##################################################################################
##################################################################################
#reload the daemon and start service, enable it for autostart
echo "16. Reloading system daemon"
systemctl daemon-reload

echo "17. Starting and enabling rtunnel.service (Reverse SSH Tunnel)"
#Start reverse SSH tunnel and enable at boot
systemctl start rtunnel
systemctl enable rtunnel

echo "18. Starting and enabling docker_scan.service (Docker containers to scan network)"
#Start docker container service and enable at boot
systemctl start docker_scan
systemctl enable docker_scan

##################################################################################
##################################################################################
# Remove temp directories
##################################################################################
##################################################################################
echo "19. Removing temp directories"
rm -rf /home/$cur_user/temp_stage

echo "20. Setup is complete!"
