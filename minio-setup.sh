#!/bin/bash 

# This script sets up MinIO as per the specifications for the Test Drive To Veeam lab environment.
# It will:
# 	1) Create configuration directories and mountpoints.
# 	2) Download MinIO and MC binaries from the MinIO website.
# 	3) Generate an SSL config file and use it to create a self-signed SSL private key and certificate.
#	4) Start the MinIO server, and create a bucket with object lock enabled
#	5) Create config files necessary for MinIO to run as a systemd service on boot.
#
# This script only performs redimentary checks, and has NOT been through much/any testing.
# Use at your own risk!
# Cobbled together by tim.jeffcoat@veeam.com on 17 July 2021
# Please don't judge me for my so-called code: bash (and coding in general) is not my strength...


temp=$(cut -d: -f1 /etc/passwd | grep -i minio)
hostname=$(hostname)

if [ ! ${#temp} = 0 ]
then
        echo "minio-user exists"
else
	echo "Adding minio-user"
	useradd -r minio-user -s /sbin/nologin
fi

if [ -d "/minio-dir/mnt" ] 
then
	echo "Found directories"
else
	fdisk -l | grep 'Disk /dev/sd'

	echo "Found these drives, which do you want to use?"
	read -p "List drives separated by a space: " -i "sda sdb sdc sdd" -e disk1 disk2 disk3 disk4 

	read -p "Using drives: $disk1 $disk2 $disk3 $disk4. Proceed? y/n: " -i "y" -e carryon

	if [ ${carryon,,} != 'y' ]
	then
	exit
	fi
	
	mkdir /minio-dir /minio-dir/mnt /minio-dir/mnt/disk_{1,2,3,4} 
	chown -R minio-user:minio-user /minio-dir 
	echo "Directories created"
	
fi


temp=$(grep -c 'sdb[0-9]' /proc/partitions)

if [ ${temp} > 1 ]
then

echo "Looks like disks need partitions - creating"
echo "start=2048, type=83" >> /minio-dir/partition_template_sfdisk

sfdisk  /dev/$disk1 < /minio-dir/partition_template_sfdisk
sleep 1
mkfs.ext4 /dev/$disk11
sleep 1

sfdisk  /dev/$disk2 < /minio-dir/partition_template_sfdisk
sleep 1
mkfs.ext4 /dev/$disk21
sleep 1

sfdisk  /dev/$disk3 < /minio-dir/partition_template_sfdisk
sleep 1
mkfs.ext4 /dev/$disk31
sleep 1

sfdisk  /dev/$disk4 < /minio-dir/partition_template_sfdisk
sleep 1
mkfs.ext4 /dev/$disk41
sleep 1

echo "UUID=`blkid -s UUID -o value /dev/$disk11` /minio-dir/mnt/disk_1 ext4 defaults 0 1" >> /minio-dir/fstab.append
echo "UUID=`blkid -s UUID -o value /dev/$disk21` /minio-dir/mnt/disk_2 ext4 defaults 0 1" >> /minio-dir/fstab.append
echo "UUID=`blkid -s UUID -o value /dev/$disk31` /minio-dir/mnt/disk_3 ext4 defaults 0 1" >> /minio-dir/fstab.append
echo "UUID=`blkid -s UUID -o value /dev/$disk41` /minio-dir/mnt/disk_4 ext4 defaults 0 1" >> /minio-dir/fstab.append

cat /minio-dir/fstab.append >> /etc/fstab

rm /minio-dir/fstab.append
rm /minio-dir/partition_template_sfdisk

mount -a
else
	echo "Disk partitions look OK"
fi


if [ -f "/usr/local/bin/minio" ] 
then
	echo "Found minio binaries"
else
	cd /minio-dir/
	echo "Downloading minio binaries"
	wget https://dl.min.io/server/minio/release/linux-amd64/minio 
	wget https://dl.min.io/client/mc/release/linux-amd64/mc 
	chmod +x minio mc

	echo "Downloaded binaries, moving to /usr/local/bin/"
	mv minio /usr/local/bin/minio
	mv mc /usr/local/bin/mc
	chown minio-user:minio-user  /usr/local/bin/minio
	chown minio-user:minio-user  /usr/local/bin/mc

#screen -dmS minio-screen minio server --address :443 /minio-dir/mnt/disk_sd{b,c,d,e}
#screen -S minio-screen -X quit

fi


temp=$(mc alias list | grep -i $hostname)

if [ ! ${#temp} = 0 ]
then
        echo "mc alias exists"
else

	echo "Adding alias to MinIO Config Tool"
	mc config host add $hostname https://$hostname minio minio-storage --api S3v4
fi

if [ -f "/minio-dir/openssl.conf" ] 
then
	echo "Found openssl.conf"
else
	echo "Creating openssl.conf"
	mkdir /etc/minio /etc/minio/certs /etc/minio/certs/CAs
	cd /minio-dir/
	touch openssl.conf

	cat > openssl.conf << EOL
[req]
distinguished_name = req_distinguished_name 
x509_extensions = v3_req 
prompt = no 

[req_distinguished_name] 
C = VM 
ST = VM 
L = VM 
O = Veeam-MinIO-O 
OU = Veeam-MinIO-OU 
CN = Veeam-MinIO-CN 

[v3_req] 
subjectAltName = @alt_names 

[alt_names] 
DNS.1 = $hostname
EOL

	temp=$(ip a s|sed -ne '/127.0.0.1/!{s/^[ \t]*inet[ \t]*\([0-9.]\+\)\/.*$/\1/p}')

	echo "IP.1 = $temp" >> openssl.conf

	echo "Created openssl.conf, generating certificate and private key"

	openssl genrsa -out /etc/minio/certs/private.key 2048
	openssl req -new -x509 -nodes -days 730 -key /etc/minio/certs/private.key -out /etc/minio/certs/public.crt -config /minio-dir/openssl.conf
	echo "Created cert and key"
#	chown -R minio-user:minio-user  /etc/minio/certs
# fi

# if [ -f "/root/.mc/certs/CAs/public.crt" ] 
# then
#         echo "Certs in correct locations"
# else
	cp /etc/minio/certs/public.crt /root/.mc/certs/CAs/public.crt
	cp /etc/minio/certs/private.key /root/.mc/certs/private.key
#	chown minio-user:minio-user /root/.mc/certs/*
	echo "Copied certs to necessary locations"
fi

if [ -f "/etc/default/minio" ] 
then
        echo "Found service config files"
else
        echo "Creating service config files"
        touch /etc/default/minio

        cat > /etc/default/minio << EOL

MINIO_VOLUMES="/minio-dir/mnt/disk_1 /minio-dir/mnt/disk_2 /minio-dir/mnt/disk_3 /minio-dir/mnt/disk_4"
MINIO_OPTS="--address :443 -console-address :1337 -S /etc/minio/certs/"
MINIO_ROOT_USER="minio"
MINIO_ROOT_PASSWORD="minio-storage"
EOL

#	chown minio-user:minio-user  /etc/default/minio

# curl -O https://raw.githubusercontent.com/minio/minio-service/master/linux-systemd/minio.service
# mv minio.service /etc/systemd/system/minio.service

 touch /etc/systemd/system/minio.service

        cat > /etc/systemd/system/minio.service << EOL

[Unit]
Description=MinIO
Documentation=https://docs.min.io
Wants=network-online.target
After=network-online.target
AssertFileIsExecutable=/usr/local/bin/minio

[Service]
WorkingDirectory=/usr/local/

# User=minio-user
# Group=minio-user
ProtectProc=invisible

EnvironmentFile=/etc/default/minio
ExecStartPre=/bin/bash -c "if [ -z \"\${MINIO_VOLUMES}\" ]; then echo \"Variable MINIO_VOLUMES not set in /etc/default/minio\"; exit 1; fi"

ExecStart=/usr/local/bin/minio server \$MINIO_OPTS \$MINIO_VOLUMES

# Let systemd restart this service always
Restart=always

# Specifies the maximum file descriptor number that can be opened by this process
LimitNOFILE=65536

# Specifies the maximum number of threads this process can create
TasksMax=infinity

# Disable timeout logic and wait until process is stopped
TimeoutStopSec=infinity
SendSIGKILL=no

[Install]
WantedBy=multi-user.target

EOL
systemctl daemon-reload
systemctl enable minio

#systemctl status minio


# ufw allow 80
# ufw allow 443
# ufw allow 9000

fi

if (systemctl is-active --quiet minio)
then
        echo "Service running"
else
        echo "MinIO service not running - attempting to start"
        systemctl start minio
        echo "Waiting for 5 seconds while server comes online"
        sleep 5
fi


temp="$(mc admin info $hostname)"

if [ ${#temp} = 0 ]
then
	echo "Unable to check Bucket - MinIO server offline"
else
	temp=$(mc ls $hostname)

	if [ ! ${#temp} = 0 ]
	then
        	echo "Bucket exists"
	else	
		echo "Adding  bucket"
       		mc mb --debug -l $hostname/bucket-immutable
	fi
fi


temp="$(mc admin info $hostname)"

if [ ${#temp} = 0 ]
then
        echo "Unable to check Users - MinIO server offline"
else

	temp=$(mc admin user list $hostname | grep -i VBOLABACCKEY)

	if [ ! ${#temp} = 0 ]
	then
        	echo "Users exist"
	else

        	echo "Adding MinIO Users"

        	echo "Veeam123456!" | mc admin user add tdtv-s3o-01 veeam
        	echo "VBOLABSECKEY" | mc admin user add tdtv-s3o-01 VBOLABACCKEY
        	# mc admin user list $hostname
        	mc admin policy set $hostname readwrite user=VBOLABACCKEY
        	mc admin policy set $hostname readonly user=veeam
	fi
fi
echo "End of script"
