# Usage Instructions
The bash script `minio-setup.sh` automates the process of building an on-prem S3-compatible object storage server.  
It attempts to perform the following tasks:
1. Create a linux user and directories for MinIO to use
2. Check that there are mount points for MinIO to use for reasure coding
3. Download the MinIO (`minio`) and MinIO Admin Utiltiy (`mc`) binaries
4. Add an alias for the MinIO server via `mc`
5. Create a self-signed SSL certificate and private key
6. Register MinIO as a systemd service so that it starts after a reboot
7. Start the MinIO server
8. Adds MinIO user accounts
9. Adds a bucket with object lock
  
Before carrying out any of the above tasks, the script will perform a very rudimentary check to try and determine if the task is necessary.  
These checks have ***not*** been thoroughly tested, but do allow for the script to be run multiple times should something fail.  
For instance, if the MinIO server does not start (task 7), running the script again will skip tasks 1-6, and re-attempt task 7.  
  
#### The following steps outline the recommended deployment for creating a server and running the `minio-setup.sh` script.  
### Step 1) Create VM
Create a new VM on your hypervisor of choice.  
Required VM settings:
```
Minimum CPUs:	2
Minimum RAM:	2 GB
CD/DVD Drive: 	Ubuntu 20.04 Server ISO or newer
Disks:
	1) 16 GB (Ubuntu OS)
	2) 100 GB (data drive), formatted with XFS, and mounted to /minio-dir/mnt
```	
Ubuntu 20.04 Server ISO can be downloaded [here](https://releases.ubuntu.com/20.04/ubuntu-20.04.3-live-server-amd64.iso).

#### Notes:
* MinIO requires a minimum of four drives for [erasure encoding](https://docs.min.io/minio/baremetal/concepts/erasure-coding.html). It is possible to simply run MinIO with just a single OS drive, with the obvious compromises that brings.
* This script will create four directories in `/minio-dir/mnt` that will be used for MinIO data volumes. If you want 'proper' erasure coding, then add four logical volumes to your server, format these with XFS, and mount them to `/minio-dir/mnt/disk_{1,2,3,4}`
* Manual configure drive partitions, filesystems, and mount points will be necessary if ANY OTHER configuration of drives is needed. 
* The size of the data drive does not need to be 100 GB, and can match what resources are available.

### Step 2) Install Linux
Boot the VM into the Ubuntu 20.04 Server ISO, and follow the install wizard.  
Server name:		`s3-object`  
Username: 		`Enter the agreed HOL admin username`  
Password: 		`Enter the agreed HOL admin password`    
Install SSH Server:	`yes`  
All other options:	`default`  

### Step 3) Deploy MinIO via script.
After the install has finished and the server has completed it's initial post-install boot:
* SSH onto the server using the 'veeam' admin user account.  
* Run the following command to download and execute the script:  
`curl -S https://raw.githubusercontent.com/timjeffcoat/Veeam-HOL/main/minio-setup.sh | sudo bash`  
  
Sudo will prompt for the `admin user` password, after which the script task outputs will be shown as the script runs.  
