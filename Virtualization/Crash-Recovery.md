## Recovering from a crash

The system is designed to survive the failure of individual servers,
disks or network cards by having clusters that are resilient to such
incidents. The typical clusters with three members survive the loss
of one member, a five member cluster can tolerate the loss of two.
In any of these events, the failed node can be repaired or replaced
and brought back in without any noticable interruption of the service.

Ideally, a larger setup would spread the nodes such that the cluster
members are in different failure zones (availability zones, fire
protection zones, power supply zones) to prevent losing the majority
due to a single event. In reality, some setups may not have the
possibility to do so and may (temporarily) lose all member through one
failure of electricty or cooling.

When the system comes back on after such a failure, it has a chance
for all systems and clusters to come back on and for all VMs to be
started again. That chance is not large and there is a significant
likelihood that the system needs manual repairs.

You may have customers impatiently asking when the system comes back
on. Plan for an hour in easier cases with small clouds, several
hours for larger clouds or more complicated issues. Make sure you
keep your operator team working diligently, not ignoring issues
that have been found.

We will subsequently assess the following subsystems:

* manager
* nodes
* ceph cluster
* redis
* mariadb database (galera cluster)
* rabbitmq
* openvswitch and ovn
* openstack services
* stale storage locks
* stale openstack resources

### Manager

* To use kolla-ansible and OSISM management tools, you need to have a
  working manager node. Bring it up.
* It is very rare these days that Linux systems fail to boot even
  after surprise power removal.
    - Journaling file systems (such as ext4) typically ensure that
      file systems are consistent, even if the last write got lost.
    - Hardware damage is possible (e.g. power supply).

### Nodes

* Try to bring up all nodes.
  `osism apply ping` will report any that are not reachable.
* Not reachable can also be caused by network equipment failure.
  Reestablish connectivity before any of the following repair steps.

### Verifying ceph

* On the manager, run `ceph -s`
  It should report `HEALTH_OK`, with 3 mon daemons up and a mgr running.
  All OSDs should be up and in.
* If one of the mons does not come up, log into the node and check the
  docker logs and the logs in `/var/log/ceph/`.
* Ceph control nodes should have ceph-mon and ceph-mgr running.
  If you deployed rgw (rados-gateway), the rgw service should be up.
  Likewise for the mds (metadata service for cephfs) if you use it.
* Ceph resource nodes should have one ceph-osd container running per
  OSD. And ceph-crash.
* After having ensure that the mons are up and running, ensure all
  OSDs are up. Note that your ceph cluster will cope with losing one
  OSD at a time, as you have 3 copies for all data objects spread over
  3 different OSDs. When an OSD is detected to be out, the cluster will
  rebalance and reallocate the blocks to other OSDs to ensure that the
  3-fold redundancy is reestablished. The rebalancing takes time and
  causes serious network traffic, reducing performance.
* Best is to avoid taking out OSDs and incurring the rebalancing by
  bringing them all back up soon after a failure.

### Service containers

* Services like redis, the mariadb/galera database, rabbitmq, the
  OpenStack services, even ceph etc. all run in containers on the respective
  set of nodes.
    - If services fail to work, they tend to exit, so those containers do
      not even run. You will see those containers as `Exited` on the node.
      Others will report and `unhealthy`.
      ```shell
      dragon@node4b(://):~ [0]$ docker ps -a | grep -i '\(exit\|unhealthy\)'
      be195b80167c   registry.osism.tech/kolla/release/2025.1/redis:7.0.15.20260615           \
                    "dumb-init --single-…"   4 minutes ago   Exited (1) 3 minutes ago              redis
      7e4705c0b164   registry.osism.tech/kolla/release/2025.1/cinder-backup:26.2.1.20260615   \
                   "dumb-init --single-…"   6 days ago      Exited (0) 4 seconds ago              cinder_backup
      e923f8519c0c   registry.osism.tech/kolla/release/2025.1/cinder-volume:26.2.1.20260615   \
                   "dumb-init --single-…"   6 days ago      Up 19 hours (unhealthy)               cinder_volume
      ```
    - In the worst case, containers do run and report as `healthy`, and
      you need to look at the logs `/var/log/` to find issues. This is
      relatively rare, fortunately.
* `osism validate container-status` will check for containers in a bad state.
    - You may be able to recover some by reapplying the respective role, e.g.
      `osism apply squid`. Expect this not to be the case in general.

### Redis

* Check the log `/var/log/kolla/redis/redis.log`
* You may find something like:
  ```
  7:M 23 Sep 2026 07:37:22.574 * DB loaded from base file redis-staging-ao.aof.4.base.rdb: 0.000 seconds
  7:M 23 Sep 2026 07:37:22.958 # Bad file format reading the append only file redis-staging-ao.aof.4.incr.aof: make a backup of your AOF file, then use ./redis-check-aof --fix <filename.manifest>
  ```
* Trouble: The repair tool (`redis-check-aof`) is in the container which does not start ...
    - ... so you can't `docker exec -it redis bash` into it
    - Installing tools on the host is a possible workaround (not recommended)
    - I have a script (`docker-debug-run`) that constructs a debug container with
      the same mounts (important) and network connections (less important) and
      image (of course, trivial) as the failing container.
* Recommended repair approach:
  ```shell
  ./docker-debug-run redis bash
  docker run --rm -it --network host --mount type=bind,source=/etc/kolla/redis,target=/var/lib/kolla/config_files --mount type=bind,source=/etc/localtime,target=/etc/localtime --mount type=bind,source=/etc/timezone,target=/etc/timezone --mount type=volume,source=redis,target=/var/lib/redis --mount type=volume,source=kolla_logs,target=/var/log/kolla -e KOLLA_CONFIG_STRATEGY=COPY_ALWAYS -e KOLLA_SERVICE_NAME=redis -e PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin -e LANG=en_US.UTF-8 -e KOLLA_BASE_DISTRO=ubuntu -e KOLLA_BASE_ARCH=x86_64 -e PS1=$(tput bold)($(printenv KOLLA_SERVICE_NAME))$(tput sgr0)[$(id -un)@$(hostname -s) $(pwd)]$  -e DEBIAN_FRONTEND=noninteractive --user redis --workdir  --entrypoint bash registry.osism.tech/kolla/release/2025.1/redis:7.0.15.20260615
  (redis)[redis@node4b /]$ (redis)[redis@node4b /]$ tail -n 10 /var/log/kolla/redis/redis.log 
  [...]
  7:M 23 Sep 2026 07:37:22.574 * DB loaded from base file redis-staging-ao.aof.4.base.rdb: 0.000 seconds
  7:M 23 Sep 2026 07:37:22.958 # Bad file format reading the append only file redis-staging-ao.aof.4.incr.aof: make a backup of your AOF file, then use ./redis-check-aof --fix <filename.manifest>
  (redis)[redis@node4b /]$ cd /var/lib/redis/appendonlydir/
  (redis)[redis@node4b appendonlydir]$ ls -l
  total 61788
  -rw-r--r-- 1 redis redis     3056 Sep 19 03:33 redis-staging-ao.aof.4.base.rdb
  -rw-r--r-- 1 redis redis 63257369 Sep 21 20:13 redis-staging-ao.aof.4.incr.aof
  -rw-r--r-- 1 redis redis      100 Sep 19 03:33 redis-staging-ao.aof.manifest
  (redis)[redis@node4b appendonlydir]$ cp -p redis-staging-ao.aof.4.incr.aof redis-staging-ao.aof.4.incr.aof.bak
  (redis)[redis@node4b appendonlydir]$ redis-check-aof --fix redis-staging-ao.aof.4.incr.aof
  Start checking Old-Style AOF
  AOF redis-staging-ao.aof.4.incr.aof format error
  AOF analyzed: filename=redis-staging-ao.aof.4.incr.aof, size=63257369, ok_up_to=63257129, ok_up_to_line=5741142, diff=240
  This will shrink the AOF redis-staging-ao.aof.4.incr.aof from 63257369 bytes, with 240 bytes, to 63257129 bytes
  Continue? [y/N]: y
  Successfully truncated AOF redis-staging-ao.aof.4.incr.aof
  (redis)[redis@node4b appendonlydir]$ 
  exit
  ```
  So the last, incomplete record (240 bytes) has been dropped. That's typically harmless.
* After the repair, redis should start again, force the restart with `docker restart redis`.
* Check with `docker ps | grep redis`. redis should be reported as `healthy` again after 30s or so.
* Repeat this on all nodes where redis fails to start up.

### Database (mariadb)

The process is similar, check the logs and build a debug container to repair,
following the hints.

### Queuing (rabbitmq)

Same.

### openvswitch and ovn

These are required for OpenStack, so double-check that they are OK.
Fortunately, openvswitch is very robust.
openvswitch and ovn have databases which may need repair like the other clusters.
Same procedure ...

### OpenStack services

* After repairing redis, mariadb, rabbitmq, these may need to be restarted. Make sure the infra services all work
  before trying to repair higher-level services.
* Check which services are down.
* When bringing them back up, follow the sequence of installation,
  i.e. keystone, glance, designate, placement, cinder, neutron, nova, octavia, rgw, horizon,
  skyline, barbican, heat, ... (some of these are optional)
* You can do this by applying the respective role again, e.g. `osism apply designate`
    - These should succeed now.
    - If they don't, you need to investigate logs again (`/var/log/kolla/` or OpenSearch)
* Your OpenStack should be fully operational again after going through all services.
    - You may validate this using the OpenStack-Health-Monitor.
    - If you've had it running on the platform itself before, you might do the VM
      repair steps depicted below.
* `osism validate container-status` should be green.

### VMs

* When rebooting a host, the VMs that ran there before (and which were not migrated away),
  will be started again automatically.
* VMs may fail to start if the rest of the platform (e.g. volume service) is not working.
    - You can see the VMs in SHUTDOWN
    - Double-check that the VMs have not been shutdown deliberately by the customer
      <!-- TODO: HOW?-->
* Your customers may prefer to restart their VMs themselves, so you need to communicate
  and align with them and possibly offer them a choice and support.
    - Some badly configured VMs may not even survive a reboot ...
    - So definitely ask customers to check

### VMs with read-only volumes (ceph locks)

* When a VM uses a volume (without `multi-attach`), it uses a lock in ceph to ensure that
  no other VM tries to mount the same volume, which would cause data corruption.
    - On a surprise power failure, these locks are not dropped.
* When trying to access a volume that is locked already, ceph will refuse writing to it.
    - This causes boot failures, check the console log `openstack console log show`. You may see
      SCSI errors on write commands and the Operating System does not complete the booting
      successfully.
* If you see VMs that failed to boot with write errors, shut those VMs down again (via
  `openstack server stop`), wait until they're in `SHUTDOWN` state and then drop the lock
  of its volumes in ceph.
    - I have the script `drop-locks.sh` that you can pass volume IDs and VM IDs. The latter
      is for ephemeral boot volumes that are backed by ceph.

### Stale OpenStack resources

If OpenStack was interrupted in the middle of creating or deleting a resource, you
may find these resources in an unsuable state. Some resources can not be cleaned up
by a normal project member and need admin intervention. Some resource types are more
prone to this than others:

* Volumes may be in `deleting` or `reserved` or `attaching` state or may be reported
  as attached to a VM ID that no longer exists.
    - The admin can typically set them to error and then delete them via openstack CLI.
* (Amphora) loadbalancers may be in `pending_XXXX` forever.
    - These need to be cleaned up in the database. (Be careful!)

You should ensure not to charge customers for broken resources.

