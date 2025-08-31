## Maintenance and Dealing with errors
* There are some maintenance tasks needed for an environment to keep it working well long-term.
* Some errors scenarios exist that need operator attention.

### Database cleanup

#### Nova

* Deleted Servers (VMs) and Volumes are *not* removed from the database tables by OpenStack
    - They are just marked as deleted and deletion time is stored (as was the creation time)
    - You could use those records for billing purposes.
        * These records could also be a second source of truth (allowing to double-check the records created from ceilometer/gnocchi)
        * You would automatically clean them up in your billing runs
* Once you confirmed you don't need them any longer, you can remove them from the database.
    - As admin, you can ask openstack about deleted servers -- beware, the list may be huge.
        * I have not found a good way to tell `openstack` to sort by deletion time, so you might need to retrieve the complete list and then start by looking at the bottom of the list
```bash
# Getting 100 old deleted serversi (the `tr -d` is for CiaB container extra CR)
DELETED=$(openstack server list --all --deleted -c ID -f value | tr -d '\r')
```
* You can use `nova-manage` to move out old entries to shadow tables (for later deletion)
    - See <https://docs.openstack.org/nova/2024.2/cli/nova-manage.html>
* Nova maintenance is covered in the [Nova](https://docs.scs.community/docs/iaas/guides/operations-guide/openstack/nova)
  section of the [OpenStack Operations Guide](https://docs.scs.community/docs/iaas/guides/operations-guide/openstack/)

#### Example: Manually remove deleted servers directly in the database (up till Apr 30 23:59:59 UTC)
```sql
USE nova;
DELETE iae FROM `instance_actions_events` AS iae, `instance_actions` AS ia, `instances` AS inst
    WHERE iae.action_id = ia.id AND ia.instance_uuid = inst.uuid 
        AND inst.deleted_at IS NOT null AND inst.deleted_at < "2025-05-01 00:00:00";
DELETE ia FROM `instance_actions` AS ia, `instances` AS inst
    WHERE ia.instance_uuid = inst.uuid 
        AND inst.deleted_at IS NOT null AND inst.deleted_at < "2025-05-01 00:00:00";
DELETE ism FROM `instance_system_metadata` AS ism, `instances` AS inst
    WHERE ism.instance_uuid = inst.uuid 
        AND inst.deleted_at IS NOT null AND inst.deleted_at < "2025-05-01 00:00:00";
DELETE im FROM `instance_metadata` AS im
    WHERE deleted_at IS NOT null and deleted_at < "2025-05-201 00:00:00";
DELETE FROM `block_device_mappings` WHERE deleted_at IS NOT null AND deleted_at < "2025-05-01 00:00:00";
DELETE FROM `instance_info_caches` WHERE deleted_at IS NOT null AND deleted_at < "2025-05-01 00:00:00";
DELETE FROM `instance_extra` WHERE deleted_at IS NOT null AND deleted_at < "2025-05-01 00:00:00";
DELETE FROM `virtual_interfaces` where deleted_at IS NOT null AND deleted_at < "2025-05-01 00:00:00";
DELETE FROM `instances` WHERE deleted_at IS NOT null AND deleted_at < "2025-05-01 00:00:00";
```
Seasoned SQL admins may find more efficient ways to do this with joins and the like.
More tables might have foreign key references to the `instances` table, so you might add more `DELETE` statements.
Ideally, you can rely on `nova-manage` instead.


#### Cinder Volumes
* Like Nova, cinder only marks volumes as deleted in the database and records the deletion time, but does
not remove the table entries.
* The openstack CLI does not report them at all, no `--deleted` option.
* You can use the `cinder-manage` tool
    - See <https://docs.openstack.org/cinder/2024.2/cli/cinder-manage.html>
* Cinder maintenance is described in the [Cinder](https://docs.scs.community/docs/iaas/guides/operations-guide/openstack/cinder)
  section of the OpenStack Operations Guide. It also has hints on quota management
  and QoS policies.

* Database example (for illustration, only use in case of emergency)
```sql
USE cinder;
DELETE FROM `volume_attachment` WHERE deleted = 1 and deleted_at < "2025-05-01 00:00:00";
DELETE FROM `volume_glance_metadata` WHERE deleted = 1 and deleted_at < "2025-05-01 00:00:00";
DELETE FROM `volumes` WHERE deleted = 1 and deleted_at < "2025-05-01 00:00:00";
```
* Similar for snapshots and backups.
* Preferably you don't need this as `cinder-manage` does the job.
* Glance behaves similarly, although deleted images do not tend to emerge in huge numbers.

#### Learning
* You need to do regular DB maintenance work with `nova-manage` and `cinder-manage`
    - These can be part of your regular billing runs.
* You don't normally tweak database tables directly, consider above examples as an exception,
  where you will need to very carefully document and review what you do.

### Stuck volumes
* Occasionally, you will find cinder volumes that users can not use and not cleanup
    - They could have a `reserved` or `deleting` status for extended amounts of time (many minutes)
    - They could be reported as attached to a VM that has long gone (and which we will only see the UUID of, not the name)
* The cinder service seems to not be very robust if processing of volume changes fall behind in high (control-plane) load situations
    - Longstanding OpenStack issue ...
* Approach: 
    - Set status to error as admin
        * `openstack --os-cloud=admin volume set --status error UUID`
    - Now you can clean them up
* If this does not work:
    - Check in Ceph whether there is an object in the `images` or `volumes` pool that needs deleting
        * Be very careful!
    - If they're not gone yet, you may need to remove them from the database as well
* Charging customers for unusable volume may not create enthusiastic responses

### Stuck LoadBalancers
* Loadbalancers can get stuck in `PENDING_CREATE` or `PENDING_DELETE`.
    - Stuck means that they remain in this state for more than a minute (and then never make any progress).
    - This happens relatively often with the amphora provider (driver)
    - Fortunately, the ovn provider does not expose this bad behavior much
* These can not be cleaned up by the user
* There is no CLI command the author is aware of for the admin to set them to error or to delete them
* The solution is to go in the database :-( and set them to error for deletion
* Charging customers for stuck loadbalancers may not create enthusiastic responses, so avoid it
* Known bug in octavia Loadbalancer (affecting ovn provider): The `octavia_api` container leaks file descriptors.
    - See <https://github.com/osism/issues/issues/959>
    - Automated occasional (nightly) restarts of the `octavia_api` container will help to avoid customer impact
        * Alternatively you monitor the FD count or the `octavia_api` availability and restart when the problem approaches / arises
* There is [documentation on Octavia maintenance](https://docs.scs.community/docs/iaas/guides/operations-guide/openstack/octavia)
  on how to deal with missing database entries.

### RabbitMQ issues
* If your rabbitMQ process is starved of resources, it might fail to deliver all messages
* Subscribers can lose connections to rabbitMQ
* The result is that the backend actions are not taken and while the API services may happily accept requests, the requested actions never make any progress
* See the [Cinder volume create failure](https://docs.scs.community/docs/iaas/guides/troubleshooting-guide/openstack#cinder-volume-create-failure) guide to see how to detect cinder-rabbit issues.
<!--TODO: More information here?-->

### Power loss on storage
* If your complete (Ceph) storage subsystem goes down, while virtual machines are running and writing to storage,
  this will result in bad behavior
* This is a typical situation after a power outage, but also happens, when a Cloud-in-a-Box gets shut down
  without stopping all VMs before.
* The result is ugly:
    - Typically the VMs will no longer boot
    - Checking the console log (`openstack console log show` or using noVNC from horizon), one can see that their
      root disks are read-only
    - This is cinder/Ceph refusing to let them write
* Recovery: Drop locks from rbd devices that correspond to your volume
    - See example below

### Recovering from locks held after surprise Ceph shutdown
* This affects volumes in `volumes` pool with name `volume-${VOLUUID}` and "local" root disks
  in pool `vms` named `${VMUUID}_disk` (in case you have the instance's root disks stored
  on Ceph)
* Cinder locks these disk files (unless you use `multiattach: True`) in Ceph RBD so they
  can not be accessed read-write by more than one VM (thus the read-only character of
  your root disk).
* Example with a running VM booted from volume `82b99323-3b69-4b05-9cb9-770324235099`:

  ```bash
  dragon@cumulus(test):~ [0]$ rbd lock list volumes/volume-82b99323-3b69-4b05-9cb9-770324235099
  There is 1 exclusive lock on this image.
  Locker          ID                    Address
  client.4105767  auto 139984392802144  192.168.16.10:0/3228397893
  dragon@cumulus(test):~ [0]$ rbd lock rm volumes/volume-82b99323-3b69-4b05-9cb9-770324235099 \
      "auto 139984392802144" client.4105767
  dragon@cumulus(test):~ [0]$ rbd lock list volumes/volume-82b99323-3b69-4b05-9cb9-770324235099
  dragon@cumulus(test):~ [0]$
  ```

* Don't do this on a volume backing a running server unless you want to see its volume turn to read-only.
    - Shut it down (`openstack server stop`) and wait for it to be in `SHUTDOWN` state.
    - On a Cloud-in-a-Box, you can use `/usr/local/bin/shutdown-instances.sh` to force-stop all VMs

### More OpenStack maintenance hints
* The [Keystone](https://docs.scs.community/docs/iaas/guides/operations-guide/openstack/keystone/) docs
  may be used as a reminder how to find out users with `member` access to a project.
* See [Upstream Neutron QoS Settings](https://docs.openstack.org/neutron/latest/admin/config-qos.html)
  documentation how to control the usage of network bandwidth in your infrastructure.

### OpenStack Resource Manager
Some of the repeating cleanup work has been automated in OSISM's
[OpenStack Resource Manager](https://github.com/osism/openstack-resource-manager).
A short [documentation](https://osism.tech/docs/guides/operations-guide/openstack/tools/resource-manager/)
is available.

In particular it has tooling for:

* Host evacuation and live migration
* Amphorae rotation
* Detecting and cleaning up stuck cinder volumes
* Identifying orphaned resources, i.e. resources that belong to projects which no longer exist

### Troubleshooting Guide
There is a [Troubleshooting Guide](https://docs.scs.community/docs/iaas/guides/troubleshooting-guide/)
available in the [SCS IaaS docs](https://docs.scs.community/docs/iaas/guides/operations-guide/openstack/tools/resource-manager)
with information on trouble with the Manager, OpenStack database, Ceph connection and cinder
rabbit trouble and Ceph medium errors.

### Practical assignment
* Trainer will create volumes that are attached to already gone VMs or stuck in reserved.
    - Recover
    - Watch out to not leak storage space
