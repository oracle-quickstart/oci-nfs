# oci-nfs
oci-nfs template is a solution to deploy NFS server in an active/passive High Availability (HA) cluster or a single node NFS server.  OCI's Shared (Multi-attach) Block Volume Storage are a perfect fit to be the storage backend for a highly available NFS cluster.  For HA, the solution utilizes open source corosync/pacemaker.   The solution also allows you to deploy a singe node NFS server,  using either local NVMe SSDs or network attached Block volumes.  Optionally,  with the template, you can deploy NFS client nodes too.   

OCI NFS solution supports both NFSv3 and NFSv4.   



## Architecture
Given below are various high level architecture for NFS deployment. 

### Active/Passive NFS Server in a High Availability Cluster

![](./images/NFS_Active_Passive_HA_High_Level_Arch.png)
    
