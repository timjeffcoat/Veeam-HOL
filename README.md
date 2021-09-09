#Usage Instructions

Follow these intructions for setting up a Veeam Test Drive on-prem object storage server.

##Step 1)	Create a new VM on your hypervisor of choice. Required VM settings:

	Minimum CPUs:	2
	Minimum RAM:	2 GB
	CD/DVD Drive: 	Ubuntu 20.04 Server ISO
	Disks:
		1) 16 GB (Ubuntu OS)
		2) 100 GB (data drive 1)
		3) 100 GB (data drive 2)
		4) 100 GB (data drive 3)
		5) 100 GB (data drive 4)
	
Ubuntu 20.04 Server ISO download link: https://releases.ubuntu.com/20.04/ubuntu-20.04.3-live-server-amd64.iso


Note:

MinIO requires at least four drives for erasure encoding (https://docs.min.io/minio/baremetal/concepts/erasure-coding.html). The MinIO deployment script therfore assumes the presence of four (and only four) data drives in addition to the OS drive. It is possible to simply run MinIO with just a single OS drive, with the obvious compromises that brings. Manual configure drive partitions, filesystems, and mount points will be necessary if ANY OTHER configuration of drives is needed. The size of the data drives does not need to be 100 GB, and can match what resources are available.
	
##Step 2) Boot the VM into the Ubuntu 20.04 Server ISO, and follow the install wizard.

Server name:

	TDTV-S3O-01

Username:

	veeam

Password:

	Veeam123456!

Install SSH Server:
	yes

All other options:	default

##Step 3) Deploy MinIO via script.

After the install has finished and the server has completed it's initial post-install boot:

SSH onto the server using the 'veeam' admin user account.

Run the following command (sudo will prompt for the 'veeam' admin user password):
		
	curl -sS https://raw.githubusercontent.com/timjeffcoat/Veeam-Test-Drive/main/minio-setup.sh | sudo bash
