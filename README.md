# KNkvmHostBackup - Backup KVM host and guests to external storage

The home environment for KitsNet is centered on a single KVM Host running a series of guest VMs along side a number of desktop, mobile and other devices sharing access to resources on the internal network. To protect all these systems, I established a multi-layered backup strategy and supporting scripts for client and host backups. At the front end is a Guest VM which implements a NAS solution for backup of client systems (Windows, Mac and iOS) and for some Linux Guest VM instances. The NAS solution is able to support file level and bare metal restore of all these backup clients. The KVM Host implements storage on a hardware RAID controller with a tiered storage layout. Logical devices presented by the RAID controller are protected by RAID&nbsp;1 or RAID&nbsp;5 constructions. While this have proven to have very high performance and reliability, there is still a risk of data loss dur to catastrophic hardware failure, including loss of the building. Therefore, I have implemented a regular cycle of backups to external media, with a rotation allowing me to have at least five copies of any data element (starting the count from the original data item itself). 

This project contains the scripts used for backup operations at the KVM Host. There are a number of capabilities implemented with these scripts:

* mount/dismount an external volume encrypted with [VeraCrypt](https://www.veracrypt.fr/code/VeraCrypt/)
* backup the KVM host and snapshot all Guest VM storage to an encrypted external volume
* "cold snap" procedure to generate a snapshot of a Guest VM while briefly shutdown then automatically restarted (if found in a running state)
* "cold snap" backup procedure
* mount/dismount a snapshot of an LV from within a Guest VM at the KVM host level
* backup a snapshot of the multi-TB NAS backup target from the Guest VM at the KVM host level to an encrypted external volume

***

## Table of Contents


  * [Usage Prototypes](#usage-prototypes)
    + [backup_guestlv-sitevg_sitelv](#backup_guestlv-sitevg_sitelv)
    + [KVMbackup-site](#kvmbackup-site)
    + [vcmount-site](#vcmount-site)
    + [vcumount-site](#vcumount-site)
  * [Major Components](#major-components)
    + [backup_cold_snap](#backup_cold_snap)
      - [Usage](#usage)
      - [Options](#options)
      - [Example](#example)
    + [backup_guestlv](#backup_guestlv)
      - [Usage](#usage-1)
      - [Options](#options-1)
      - [Example](#example-1)
    + [cold_snap.sh](#cold_snapsh)
      - [Usage](#usage-2)
      - [Options](#options-2)
      - [Example](#example-2)
    + [guestlvmnt](#guestlvmnt)
      - [Usage](#usage-3)
      - [Options](#options-3)
      - [Example](#example-3)
    + [KVMbackup](#kvmbackup)
      - [Usage](#usage-4)
      - [Options](#options-4)
    + [make_guest_backup_script.awk](#make_guest_backup_scriptawk)
      - [Usage](#usage-5)
      - [Options](#options-5)
      - [Example](#example-4)
    + [vcmount](#vcmount)
      - [Usage](#usage-6)
      - [Options](#options-6)
      - [Example](#example-5)
    + [vcumount](#vcumount)
      - [Usage](#usage-7)
      - [Options](#options-7)
      - [Example](#example-6)
  * [Environment Assumptions](#environment-assumptions)

***

## Usage Prototypes

To provide implementation guidance, a number of prototype bash scripts are provided as examples of how the Major Component scripts may be used. The prototypes should be renamed and customized to meet local requirements.

### backup_guestlv-sitevg_sitelv

This prototype provides an example of calling [backup_guestlv](#backup_guestlv) for backing up a Guest OS instance LV within the context of the KVM Host. In my environment, backups of all client systems and some servers are written under a consolidated mountpoint on my NAS solution. While this serves up a huge capacity, it creates a difficulty in terms of backing this up to external storage. By exposing the Guest OS instance filesystem for this LV to the KVM Host, I need backup only the occupied space of the filesystem. Furthermore, [backup_guestlv](#backup_guestlv) supports segmenting the backup so that a subset of the directory structure is written to a second backup target on the KVM Host. This prototype provides an example of executing the backup in this manner. 

### KVMbackup-site

This prototype provides a practical example of using [KVMbackup](#KVMbackup) to carry out a backup of the entire virtualization environment, including the KVM Host and all the Guest VMs. Paths on the KVM Host for local repo and installation packages are excluded, since these would be redownloaded from the internet if required. Certain Guest VM LVs are excluded since they are backed up separately.

### vcmount-site

This prototype provides an example of calling [vcmount](#vcmount) to mount an external storage device previously encrypted with [VeraCrypt](https://www.veracrypt.fr/code/VeraCrypt/). In my environment, I use a pair of disks for one set of backup targets. To make sure the right disk goes to the right mountpoint, I use [`smartctl`](https://www.smartmontools.org/) to read the physical device attributes to get the model. The unique model names are then mapped the the relative volume number that should be used for the mount. 

### vcumount-site

This prototype provides an example of calling [vcumount](#vcumount) to unmount an external storage device previously mounted with [vcmount](#vcmount) .

***

## Major Components



### backup_cold_snap

This procedure will use with [`cold_snap.sh`](#cold_snapsh) to generate a cold snapshot (snapshot taken when the target system is down) of the Guest VM then use `dd` to back them up. Once the backup operation is complete, the snapshots will be removed from the KVM Host. 

#### Usage

    backup_cold_snap target_mp source_hn

#### Options

##### positional arguments:

    target_mp             Mountpoint under which the backups will be written. A directory named cold_snaps 
                           must exist here.
    source_hn             Passed to cold_snap.sh to identify the Guest VM to be snapped and backed up

#### Example

```bash
[root@mykvmhost ~]# backup_cold_snap /mnt/mysite-pbd1 myguestos
u=rwx,g=rx,o=
***
***
*** 05/23/2021 14:52:58: Find /mnt/mysite-pbd1/cold_snaps
***
meta-data=/dev/mapper/veracrypt1 isize=256    agcount=16, agsize=61047132 blks
         =                       sectsz=512   attr=2, projid32bit=0
         =                       crc=0        finobt=0 spinodes=0
data     =                       bsize=4096   blocks=976754112, imaxpct=5
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=0
log      =internal               bsize=4096   blocks=32768, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
***
***
*** 05/23/2021 14:52:58: Check for target hostname argument and source cold snap procedure
***
***
***
*** 05/23/2021 14:52:58: Find target VM for myguestos
***
Current state of VM uv062 (myguestos): running

***
***
*** 05/23/2021 14:52:58: Shutdown VM uv062 (myguestos)
***
Shutting down running VM uv062 (myguestos)
Domain uv062 is being shutdown


***
***
*** 05/23/2021 14:52:58: Wait for shutdown of VM uv062 (myguestos)
***
- 05/23/2021 14:52:58: Current state is running - sleep 10
- 05/23/2021 14:53:08: Current state is shut off - wait complete

***
***
*** 05/23/2021 14:53:08: Snap LVs for VM uv062 (myguestos)
***
  LV            VG  Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  uv062-disk0   T0  -wi-a-----  10.00g
  uv062-disk1   T3  -wi-a-----  50.00g

  Logical volume "bu-uv062-disk0" created.
  --- Logical volume ---
  LV Path                /dev/T0/uv062-disk0
  LV Name                uv062-disk0
  VG Name                T0
  LV UUID                HX25yy-zYTs-jG3M-5jUe-lV0w-oBcO-nTnAjI
  LV Write Access        read/write
  LV Creation host, time mykvmhost.lan.kitsnet.us, 2021-05-08 20:05:18 -0400
  LV snapshot status     source of
                         bu-uv062-disk0 [active]
  LV Status              available
  # open                 0
  LV Size                10.00 GiB
  Current LE             2560
  Segments               1
  Allocation             inherit
  Read ahead sectors     auto
  - currently set to     256
  Block device           253:32

  Logical volume "bu-uv062-disk1" created.
  --- Logical volume ---
  LV Path                /dev/T3/uv062-disk1
  LV Name                uv062-disk1
  VG Name                T3
  LV UUID                4mw3El-hrdD-CjeN-z1ZM-aW7R-IIYo-eJmV1m
  LV Write Access        read/write
  LV Creation host, time mykvmhost.lan.kitsnet.us, 2021-05-08 20:06:01 -0400
  LV snapshot status     source of
                         bu-uv062-disk1 [active]
  LV Status              available
  # open                 0
  LV Size                50.00 GiB
  Current LE             12800
  Segments               1
  Allocation             inherit
  Read ahead sectors     auto
  - currently set to     256
  Block device           253:84

  LV             VG  #Seg Attr       LSize   Maj Min KMaj KMin Pool Origin      Data%  Meta%  Move Cpy%Sync Log Convert LV UUID                                LProfile
  bu-uv062-disk0 T0     1 swi-a-s---   5.04g  -1  -1  253   91      uv062-disk0 0.00                                    curJYd-0IB2-nPnV-fDsy-0evr-xTPg-vKhwx5
  uv062-disk0    T0     1 owi-a-s---  10.00g  -1  -1  253   32                                                          HX25yy-zYTs-jG3M-5jUe-lV0w-oBcO-nTnAjI
  bu-uv062-disk1 T3     1 swi-a-s--- <25.20g  -1  -1  253   94      uv062-disk1 0.00                                    KoqB9s-z2Pc-DI6r-D8bS-iAty-Py5g-67Ccte
  uv062-disk1    T3     1 owi-a-s---  50.00g  -1  -1  253   84                                                          4mw3El-hrdD-CjeN-z1ZM-aW7R-IIYo-eJmV1m

***
***
*** 05/23/2021 14:53:08: Restart VM uv062 (myguestos) if previously running
***
Restart VM uv062 (myguestos)
Domain uv062 started


***
***
*** 05/23/2021 14:53:09: Backup snapshot LVs for host on VM uv062 (myguestos)
***
  bu-uv062-disk0 T0  swi-a-s---    5164.00      uv062-disk0 0.00
dd if=/dev/T0/bu-uv062-disk0 of=/mnt/mysite-pbd1/cold_snaps/T0--bu-uv062-disk0.dd ibs=128k obs=128k
81920+0 records in
81920+0 records out
10737418240 bytes (11 GB) copied, 57.7909 s, 186 MB/s
  bu-uv062-disk1 T3  swi-a-s---   25804.00      uv062-disk1 0.00
dd if=/dev/T3/bu-uv062-disk1 of=/mnt/mysite-pbd1/cold_snaps/T3--bu-uv062-disk1.dd ibs=128k obs=128k
409600+0 records in
409600+0 records out
53687091200 bytes (54 GB) copied, 365.533 s, 147 MB/s
***
***
*** 05/23/2021 15:00:13: Remove snapshot LVs for host on VM uv062 (myguestos)
***
  bu-uv062-disk0 T0  swi-a-s---    5164.00      uv062-disk0 0.09
/sbin/lvremove --verbose --force /dev/T0/bu-uv062-disk0
    Archiving volume group "T0" metadata (seqno 955).
    Removing snapshot volume T0/bu-uv062-disk0.
    Loading table for T0-uv062--disk0 (253:32).
    Loading table for T0-bu--uv062--disk0 (253:91).
    Not monitoring T0/bu-uv062-disk0 with libdevmapper-event-lvm2snapshot.so
    Unmonitored LVM-2Ttv1rQKPchu5WHDk4j38t06wOWEjFq7curJYd0IB2nPnVfDsy0evrxTPgvKhwx5 for events
    Suspending T0-uv062--disk0 (253:32) with device flush
    Suspending T0-bu--uv062--disk0 (253:91) with device flush
    Suspending T0-uv062--disk0-real (253:89) with device flush
    Suspending T0-bu--uv062--disk0-cow (253:90) with device flush
    activation/volume_list configuration setting not defined: Checking only host tags for T0/bu-uv062-disk0.
    Resuming T0-bu--uv062--disk0-cow (253:90).
    Resuming T0-uv062--disk0-real (253:89).
    Resuming T0-bu--uv062--disk0 (253:91).
    Resuming T0-uv062--disk0 (253:32).
    Removing T0-uv062--disk0-real (253:89)
    Removing T0-bu--uv062--disk0 (253:91)
    Removing T0-bu--uv062--disk0-cow (253:90)
    Releasing logical volume "bu-uv062-disk0"
    Creating volume group backup "/etc/lvm/backup/T0" (seqno 957).
  Logical volume "bu-uv062-disk0" successfully removed
  bu-uv062-disk1 T3  swi-a-s---   25804.00      uv062-disk1 0.12
/sbin/lvremove --verbose --force /dev/T3/bu-uv062-disk1
    Archiving volume group "T3" metadata (seqno 6502).
    Removing snapshot volume T3/bu-uv062-disk1.
    Loading table for T3-uv062--disk1 (253:84).
    Loading table for T3-bu--uv062--disk1 (253:94).
    Not monitoring T3/bu-uv062-disk1 with libdevmapper-event-lvm2snapshot.so
    Unmonitored LVM-QfBiGXTZo3dkfEuOu0Fd3JOrLZkF2Y99KoqB9sz2PcDI6rD8bSiAtyPy5g67Ccte for events
    Suspending T3-uv062--disk1 (253:84) with device flush
    Suspending T3-bu--uv062--disk1 (253:94) with device flush
    Suspending T3-uv062--disk1-real (253:92) with device flush
    Suspending T3-bu--uv062--disk1-cow (253:93) with device flush
    activation/volume_list configuration setting not defined: Checking only host tags for T3/bu-uv062-disk1.
    Resuming T3-bu--uv062--disk1-cow (253:93).
    Resuming T3-uv062--disk1-real (253:92).
    Resuming T3-bu--uv062--disk1 (253:94).
    Resuming T3-uv062--disk1 (253:84).
    Removing T3-uv062--disk1-real (253:92)
    Removing T3-bu--uv062--disk1 (253:94)
    Removing T3-bu--uv062--disk1-cow (253:93)
    Releasing logical volume "bu-uv062-disk1"
    Creating volume group backup "/etc/lvm/backup/T3" (seqno 6504).
  Logical volume "bu-uv062-disk1" successfully removed

***
***
*** 05/23/2021 15:00:14: Final state for LVs for host on VM uv062 (myguestos)
***
  LV            VG  Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  uv062-disk0   T0  -wi-ao----  10.00g
  uv062-disk1   T3  -wi-ao----  50.00g

```




### backup_guestlv

This procedure will backup a source LV from within a Guest OS instance within the context of the KVM Host, typically to external storage. If desired, a subset of the backup source may be written to a second target. With this capability, if the backup source filesystem is too big to fit in a single target, the subsetting mechanism can be used to break the backup into two parts on separate targets. Mounting and dismounting of the source LV is handled by the [`guestlvmnt`](#guestlvmnt) utility.

#### Usage

    backup_guestlv source_mp host_vg host_lv guest_vg guest_lv target_mp [target2_mp] subset_dir

#### Options

##### positional arguments:

    source_mp             Mountpoint where the LV from the Guest VM will be mounted on the KVM Host.
    host_vg               Volume Group within the KVM host that contains the LV that implements the Guest VM 
                           virtual disk that contains the Guest OS instance target LV.
    host_lv               Name of the LV on the KVM host that implements the Guest VM virtual disk that contains 
                           the Guest OS instance target LV.
    guest_vg              Name of the Volume Group within the Guest OS instance that contains the target LV.
    guest_lv              Name of the target LV within the Guest OS instance.
    target_mp             Mountpoint under which the backups will be written.
    [target2_mp]          Mountpoint under which backups of the subset directory path will be written.
    [subset_dir]          Partial directory path from beneath the original source_mp that will be subset. This 
                           means that the subset source path will be written to target2_mp and excluded from 
                           target_mp. If target2_mp is specified, this argument become mandatory.

#### Example

```bash
[root@mykvmhost ~]# backup_guestlv /mnt/nas_backup T3b uv059-disk3 V3buv059 backups /mnt/mysite-pbd2 /mnt/mysite-pbd1 Win/foo

```




 ### cold_snap.sh

This script is used to generate a snapshot of the virtual disks for a target Guest VM while the Guest VM is shutdown. This is a good way to generate a point in time copy of the Guest VM, ensuring that all IO has been flushed to disk. 

The script will used the passed `target` argument to locate the VM in the output of the `virsh list -all --title` command. This is a handy way to reference the VM either by text in the Guest VM title (say, the hostname from the Guest OS instance) or the KVM Guest VM name. Once the script has isolated the KVM Guest VM name, it will check the run state of the Guest VM and shut it down if necessary. Snapshots of all the KVM Host LVs implementing the virtual disks of the Guest VM are then taken. If the Guest VM had to be shutdown by the script, it will restart the Guest VM on the way out.

If the script is invoked with the `source` command, the variables `$UV` and `$TARGET` will have the KVM Guest name and the text of the `target` argument respectively. 

#### Usage

    source cold_snap.sh target

#### Options

##### positional arguments:

    target                Target Guest VM for snapshot operations. This text will be matched agfainst the
                           KVM Guest VM name and its assocaited title from the virsh list --all --title command

#### Example

```bash
[root@mykvmhost ~]# source cold_snap myguestos
***
***
*** 05/23/2021 14:03:24: Find target VM for myguestos
***
Current state of VM uv062 (myguestos): running

***
***
*** 05/23/2021 14:03:24: Shutdown VM uv062 (myguestos)
***
Shutting down running VM uv062 (myguestos)
Domain uv062 is being shutdown


***
***
*** 05/23/2021 14:03:24: Wait for shutdown of VM uv062 (myguestos)
***
- 05/23/2021 14:03:24: Current state is running - sleep 10
- 05/23/2021 14:03:34: Current state is shut off - wait complete

***
***
*** 05/23/2021 14:03:34: Snap LVs for VM uv062 (myguestos)
***
  LV            VG  Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  uv062-disk0   T0  -wi-a-----  10.00g
  uv062-disk1   T3  -wi-a-----  50.00g

  Logical volume "bu-uv062-disk0" created.
  --- Logical volume ---
  LV Path                /dev/T0/uv062-disk0
  LV Name                uv062-disk0
  VG Name                T0
  LV UUID                HX25yy-zYTs-jG3M-5jUe-lV0w-oBcO-nTnAjI
  LV Write Access        read/write
  LV Creation host, time mykvmhost.lan.kitsnet.us, 2021-05-08 20:05:18 -0400
  LV snapshot status     source of
                         bu-uv062-disk0 [active]
  LV Status              available
  # open                 0
  LV Size                10.00 GiB
  Current LE             2560
  Segments               1
  Allocation             inherit
  Read ahead sectors     auto
  - currently set to     256
  Block device           253:32

  Logical volume "bu-uv062-disk1" created.
  --- Logical volume ---
  LV Path                /dev/T3/uv062-disk1
  LV Name                uv062-disk1
  VG Name                T3
  LV UUID                4mw3El-hrdD-CjeN-z1ZM-aW7R-IIYo-eJmV1m
  LV Write Access        read/write
  LV Creation host, time mykvmhost.lan.kitsnet.us, 2021-05-08 20:06:01 -0400
  LV snapshot status     source of
                         bu-uv062-disk1 [active]
  LV Status              available
  # open                 0
  LV Size                50.00 GiB
  Current LE             12800
  Segments               1
  Allocation             inherit
  Read ahead sectors     auto
  - currently set to     256
  Block device           253:84

  LV             VG  #Seg Attr       LSize   Maj Min KMaj KMin Pool Origin      Data%  Meta%  Move Cpy%Sync Log Convert LV UUID                                LProfile
  bu-uv062-disk0 T0     1 swi-a-s---   5.04g  -1  -1  253   91      uv062-disk0 0.00                                    emhTXa-Nusb-hLM1-9zOG-1YPk-aioc-2yj4jf
  uv062-disk0    T0     1 owi-a-s---  10.00g  -1  -1  253   32                                                          HX25yy-zYTs-jG3M-5jUe-lV0w-oBcO-nTnAjI
  bu-uv062-disk1 T3     1 swi-a-s--- <25.20g  -1  -1  253   94      uv062-disk1 0.00                                    LKM2rg-xxvO-phkX-C3CF-MRnH-9PjF-0qzo1J
  uv062-disk1    T3     1 owi-a-s---  50.00g  -1  -1  253   84                                                          4mw3El-hrdD-CjeN-z1ZM-aW7R-IIYo-eJmV1m

***
***
*** 05/23/2021 14:03:34: Restart VM uv062 (myguestos) if previously running
***
Restart VM uv062 (myguestos)
Domain uv062 started


[root@mykvmhost ~]# echo $UV
uv062
[root@mykvmhost ~]# echo $TARGET
myguestos
```




### guestlvmnt
This utility supports mounting and dismounting read-only copies of LVs from within a Guest OS instance at the KVM Host level. This is useful for executing backups that need to be aware of the filesystem at the Guest OS level or for just taking a look. This is accomplished by creating snapshot copies of LVs implementing virtual disks for the Guest VM, then activating them to locate and mount the target LV from the Guest OS instance. 

#### Usage

    guestlvmnt opcode export_mp host_vg host_lv guest_vg guest_lv

#### Options

##### positional arguments:

    opcode                Operation to be performed. Must be one of m (mount) of u (unmount).
    export_mp             Mountpoint where the LV from the Guest VM will be mounted on the KVM Host.
    host_vg               Volume Group within the KVM host that contains the LV that implements the Guest VM 
                           virtual disk that contains the Guest OS instance target LV.
    host_lv               Name of the LV on the KVM host that implements the Guest VM virtual disk that contains 
                           the Guest OS instance target LV.
    guest_vg              Name of the Volume Group within the Guest OS instance that contains the target LV.
    guest_lv              Name of the target LV within the Guest OS instance.

#### Example

```bash
[root@mykvmhost ~]# guestlvmnt m /mnt/nas_backup T3b uv059-disk3 V3buv059 backups
**
**
** 05/23/2021 16:16:45: Mounting guest filesystem V3buv059/backups on /mnt/nas_backup
**

*** 05/23/2021 16:16:45: Snap the host LV used by the guest (T3b/uv059-disk3)
  Logical volume "bu-uv059-disk3" created.

*** 05/23/2021 16:16:47: Create guest-level device map on host from snapshot LV (/dev/T3b/bu-uv059-disk3)
add map T3b-bu--uv059--disk3p1 (253:92): 0 9663672320 linear /dev/T3b/bu-uv059-disk3 2048

** 05/23/2021 16:16:52: Check for existence of guest-level VG/LV before continuing

** 05/23/2021 16:16:52: Activate guest-level volume group exposed to host (V3buv059)
    1 logical volume(s) in volume group "V3buv059" already active
    1 existing logical volume(s) in volume group "V3buv059" monitored
    Activating logical volume V3buv059/backups.
    activation/volume_list configuration setting not defined: Checking only host tags for V3buv059/backups.
    Activated 1 logical volumes in volume group V3buv059
  1 logical volume(s) in volume group "V3buv059" now active

** 05/23/2021 16:16:52: Mount guest-level LV as read-only filesystem (/dev/V3buv059/backups on /mnt/nas_backup)
Filesystem                    1K-blocks       Used  Available Use% Mounted on
/dev/mapper/V3buv059-backups 4831309824 3071040572 1760269252  64% /mnt/nas_backup

[root@wort ~]# guestlvmnt u /mnt/nas_backup T3b uv059-disk3 V3buv059 backups
**
**
** 05/23/2021 16:17:35: Unmounting filesystem V3buv059/backups from /mnt/nas_backup
**

** 05/23/2021 16:17:35: Unmount guest-level LV (/mnt/nas_backup)
Filesystem                    1K-blocks       Used  Available Use% Mounted on
/dev/mapper/V3buv059-backups 4831309824 3071040572 1760269252  64% /mnt/nas_backup

** 05/23/2021 16:17:35: De-activate guest-level volume group exposed to host (V3buv059)
    Deactivating logical volume V3buv059/backups.
    Removing V3buv059-backups (253:93)
    Deactivated 1 logical volumes in volume group V3buv059
  0 logical volume(s) in volume group "V3buv059" now active

*** 05/23/2021 16:17:35: Remove guest-level device map on host from snapshot LV (/dev/T3b/bu-uv059-disk3)
del devmap : T3b-bu--uv059--disk3p1

*** 05/23/2021 16:17:35: Remove the snap the host LV used by the guest (T3b/uv059-disk3)
  Logical volume "bu-uv059-disk3" successfully removed

  VG  #PV #LV #SN Attr   VSize    VFree
  T0    1  18   0 wz--n- <476.94g <289.94g
  T0h   1   3   0 wz--n-   74.00g    4.00m
  T1    1  32   0 wz--n-   <1.82t   <1.05t
  T3    1  33   0 wz--n-   <2.73t   <2.03t
  T3b   1   1   0 wz--n-   <7.28t   <2.78t
```



### KVMbackup

Backs up the KVM Host OS instance and all Guest VM LVs to the specified mountpoint. It is intended that this will be an external encrypted volume previously mounted with [`vcmount`](#vcmount). The KVM Host OS instance will be backed up with rsync while snapshots will be taken Guest VM LVs and copied to the backup target volume using dd. Filters are available to exclude paths from the KVM Host backup as well as specific Guest VM LVs, if desired. 

KVMbackup constructs the script for backing up the Guest VM LVs dynamically each run. Output from the lvs command is first piped through `lvm-vm-filter.awk` to select only those LVs associated with Guest VMs and to drop those LVs that will not be processed based on the `filter_lv` list. The next stage of the pipeline sorts the list of LVs, grouping the LVs for each Guest VM together. The final pipeline stage runs through `make_guest_bck_script.awk` to construct the actual backup script. 

Backup operations begin with the rsync of the KVM Host OS instance. A fixed set of directory exclusions is loaded for the rsync operation, with additional exclusions added with the `exclude_paths` parameter. After this, the backup script for the Guest VM LVs is executed.

This procedure would generally be scheduled as a cron job. The default method of email delivery of the run log works well enough. 

#### Usage

    KVMbackup target_mp [host_bdir] [filter_lv] [exclude_paths]

#### Options

##### positional arguments:

    target_mp             Mountpoint under which the backups will be written.
    [host_bdir]           Name of the directory that will have the KVM Host backup written. The directory
                           that will have the backups of Guest VM LVs will have this name with -lvm added
                           (e.g. for host_bdir "foo", the Guest VM LVs will be backed up to "foo-lvm").
                           This parameter defaults to the unqualified hostname of the KVM Host. 
    [filter_lv]           Optional space-delimited list of LVs that should be excluded from Guest VM LV 
                           backups. This is useful for specific LVs that require their own backup due to 
                           size or other constraint.
    [exclude_paths]       Optional comma-delimited list of paths on the KVM Host to exclude from the rsync
                           backup operation. Good choices here include paths used for KVM suspend to disk
                           storage, mirrored repositories and OS distributions.

 



### make_guest_backup_script.awk

This awk script will be used in the final pipeline stage of formatted and filtered output from lvs to construct the bash script that will carry out the actual backup operations. The awk script variable `ExtTarget` needs to be set to the target directory for the backup operations. 

Once the awk script loads the sorted, filtered list of KVM Host LVs for backup, it generates the output bash script. For each Guest LV that will be backed up, the output bash script will contain instructions to:

1. create all the snapshot LVs for the Guest VM on the KVM Host
2. use `dd` to backup each snapshot LV to the `ExtTarget` and remove the snapshot LV once the `dd` command completes.

If the size of the LV to be backed up is larger than a set threshold, the `dd` operation will be piped through `gzip` on its way to `ExtTarget`

#### Usage

    awk -f /usr/local/sbin/make_guest_bck_script.awk -v ExtTarget=target_mp

#### Options

##### option arguments:

    target_mp             Mountpoint under which the backups will be written.

####  Example

```bash
[root@mykvmhost ~]# /sbin/lvs --units=m  --noheadings --nosuffix \
	| awk -f /usr/local/bin/lvm-vm-filter.awk -v filterlv="$FILTER_LV" \
	| sort --reverse \
	| awk -f /usr/local/sbin/make_guest_bck_script.awk -v ExtTarget="/mnt/mysite-pbd1/mykvmhost-lvm" \
		> ~/generated_script.sh
```




### vcmount 

This is a bash script used to mount a volume that has been previously encrypted with [VeraCrypt](https://www.veracrypt.fr/code/VeraCrypt/) using a keyfile.

#### Usage

    vcmount base_mp devpart volnum [keyfile]

Note that it may be necessary to press return a second time to complete the command, even if a keyfile without a password is used. Some versions of [VeraCrypt](https://www.veracrypt.fr/code/VeraCrypt/) will insist that the empty password be entered (i.e. press the return key).

#### Options

##### positional arguments:

    base_mp               Base part of the mountpoint where the volume will be mounted. The volnum will be 
                           appended to this to determine the full mountpoint
    devpart               Device specification for the partition to be mounted
    volnum                Relative volume designation for devices mounted by this procedure. This will be 
                           appended to the base_mp to determine the full mountpoint
    [keyfile]             Optionsl argument to specify the keyfile used for Veracrypt encryption. If not 
                           specified, it will default to ~/truecrypt.keyfile

#### Example

```bash
[root@mykvmhost ~]# vcmount /dev/mysite-pbd /dev/sde1 1 ~/mysite.keyfile
Model: ASMT USB 3.0 Destop H (scsi)
Disk /dev/sde: 4001GB
Sector size (logical/physical): 512B/4096B
Partition Table: gpt
Disk Flags:

Number  Start   End     Size    File system  Name     Flags
1      1049kB  4001GB  4001GB               primary

CRYPT_PART=/dev/sde1
veracrypt -k=/root/mysite.keyfile -p="" --pim=0 --protect-hidden=no --verbose  --fs-options=nobarrier,async /dev/sde1 /mnt/mysite-pbd1

Volume "/dev/sde1" has been mounted.
meta-data=/dev/mapper/veracrypt1 isize=256    agcount=16, agsize=61047132 blks
         =                       sectsz=512   attr=2, projid32bit=0
         =                       crc=0        finobt=0 spinodes=0
data     =                       bsize=4096   blocks=976754112, imaxpct=5
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=0
log      =internal               bsize=4096   blocks=32768, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0

Filesystem              Size  Used Avail Use% Mounted on
/dev/mapper/veracrypt1  3.7T  3.0T  731G  81% /mnt/mysite-pbd1
  
total 18
drwxr-xr-x.  9 root root         137 Dec 17 20:27 .
drwxr-xr-x.  5 root root          65 May 29  2020 ..
drwxr-x---.  2 root mysite_adm  4096 Feb  1  2020 cold_snaps
-rw-r-----.  1 root mysite_adm     1 Jan 19  2020 mysite-pbd1.set1
drwxr-xr-x.  3 root mysite_adm    28 Dec 18 08:45 nas_backup
drwxr-x---. 21 root mysite_adm  4096 May 20 17:43 kvmh
drwxr-x---.  2 root mysite_adm  4096 May 20 21:23 kvmh-lvm
```



### vcumount

This is a bash script used to dismount a volume previously mounted with [`vcmount`](#vcmount).

#### Usage

    vcumount volnum

#### Options

##### positional arguments:

    volnum                Relative volume designation used with vcmount

#### Example

```bash
[root@mykvmhost ~]# vcumount 1
Filesystem              Size  Used Avail Use% Mounted on
/dev/mapper/veracrypt1  3.7T  3.0T  731G  81% /mnt/mysite-pbd1

Dismounting Veracrypt volume on partition /dev/sde1...
Volume "/dev/sde1" has been dismounted.
```



***

## Environment Assumptions
The KVM Host is a [CentOS&nbsp;7](https://docs.centos.org/en-US/centos/install-guide/) system currently running on an [AMD Ryzen Zen 2](https://www.amd.com/en/technologies/zen-core) system on a Gigabyte B550 platform with 64 GB of RAM. This is a hardware update from the aging EVGA&nbsp;X58 platform it had been running on for about six years (at the time of retirement, the repurposed hardware had been running for a total 12 years!) . The hardware update was carried out without need for an OS re-install. Storage on the KVM host includes a SATA SSD attached to the motherboard controller dedicated for KVM Host OS usage; no Guest VM makes use of any of this storage. All remaining storage is presented by the [LSI Logic SAS9260-8i](https://docs.broadcom.com/doc/12352152) hardware RAID controller with battery backup and equipped with the [CacheCade](https://www.broadcom.com/products/storage/raid-controllers/megaraid-cachecade-pro-software) function implementing a front-side flash cache for the entire array. The only storage from the RAID controller used by the KVM Host OS instance is that supporting KVM suspend to disk operations and the local repo served by the KVM Host. With this setup, the KVM Host OS instance has no dependency of its own on the storage from the RAID controller. This design was very helpful the one time I had a catastrophic failure of the RAID controller.

Storage on the RAID controller is organized with LVM Volume Groups into tiered storage pools for use by the Guest VMs:

* T0 is the fastest, low latency storage, implemented on NVMe
* T1 is for medium performance, device-internal flash accelerated storage
* T2 reserved
* T3 large capacity, low performance general purpose storage
* T3b is the same device classification as T3, but implemented on a segregated pool of devices dedicated to implementing backup target volumes

Within KVM, Guest VMs are named within according to their type:

* a Linux virtual server (uv###)
* a Windows virtual desktop (wv9##)
* a Windows virtual server (ws8##)

These names are strictly those of the Guest VM within KVM. The actual Linux hostname within the Guest OS instance can be anything.

When allocating storage for the Guest VM, each guest virtual disk will be implemented as a Logical Volume presented by the KVM Host. These LVs will have a name reflecting the name of the Guest VM and the disk sequence. For example, then Guest VM named uv059 equipped with "fast" and "slow" disks could have allocated to it T0/uv059-disk0 and T3/uv059-disk1. The result of this arrangement makes tracing IO load anomalies relatively straightforward with [iostat](https://www.redhat.com/sysadmin/io-reporting-linux) since the physical disk and the Guest VM(s) responsible for the IO load will be clearly shown. 

Within the Guest OS instance, Volume Groups are named in such a way as to be unique across all Guest OS instances in the environment. This makes it easier to activate and mount Guest OS instance LVs at the KVM Host level without fear of conflict or confusion. Volume groups will be named with an indicator of the underlying storage tier, followed by the name of the Guest VM within KVM. For example, within uv059 OS instance, the Volume Group constructed from KVM Host T0 storage will be named V0uv059. The LVs created within the Guest OS instances have no restrictions or need for uniqueness across the estate, since uniqueness has already been ensured with the Volume Group naming convention. 

Bringing all this together, here is what the output of the [lvs](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/4/html/cluster_logical_volume_manager/lv_display#:~:text=The%20lvs%20command%20provides%20logical,%E2%80%9CCustomized%20Reporting%20for%20LVM%E2%80%9D.) command could look like on the KVM Host

      LV            VG  Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
      uv050-disk0    T0  -wi-ao----   8.00g
      uv053-disk0    T0  -wi-ao----   8.00g
      uv053-disk1    T0  -wi-ao----   3.00g
      uv054-disk0    T0  -wi-ao----   4.00g
      uv054-disk3    T0  -wi-ao----   4.00g
      uv055-disk0    T0  -wi-ao----  10.00g
      uv056-disk0    T0  -wi-ao----   6.00g
      uv057-disk0    T0  -wi-a-----   4.00g
      uv059-disk0    T0  -wi-ao----  10.00g
      uv050-disk1    T1  -wi-ao----   2.00g
      uv050-disk3    T1  -wi-ao---- 200.00g
      uv050-disk4    T1  -wi-ao----  16.00g
      uv052-disk0    T1  -wi-a-----  50.00g
      uv053-disk2    T1  -wi-ao----   4.00g
      uv054-disk1    T1  -wi-ao----   4.00g
      uv054-disk4    T1  -wi-ao----   8.00g
      uv056-disk1    T1  -wi-ao----  16.00g
      uv050-disk2    T3  -wi-ao----   2.00g
      uv053-disk3    T3  -wi-ao----   8.00g
      uv054-disk2    T3  -wi-ao----   2.00g
      uv054-disk5    T3  -wi-ao----  32.00g
      uv055-disk1    T3  -wi-ao----  32.00g
      uv056-disk2    T3  -wi-ao----   4.00g
      uv057-disk1    T3  -wi-a-----   3.00g
      uv059-disk1    T3  -wi-ao----  16.00g

The KVM Host currently employs a USB&nbsp;3 connected SATA dual drive dock for connection of external storage.

___

**Peter Smode**

`psmode [at] kitsnet.us`
