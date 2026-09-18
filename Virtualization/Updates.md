## Updates and Upgrades

### Security Updates
* Be prepared to install security updates short-term
* Typically, this involves replacing one or a few service containers with fixed versions
* This will typically *not* affect running workloads
* It might however stop control plane (API) access for a number of seconds
    - It is best practice to notify customers, even if most customers will never notice
* Security updates affecting the SCS reference implementation OSISM are published as Blog articles
    - Known trusted partners can get a pre-warning (for coordinated releases)

### Security update example
* See the [security advisory on CVE-2024-40767](https://scs.community/security/2024/07/23/cve-2024-40767/)
    - It documents what the vulnerability is and what under what circumstances providers may be affected
    - It provides information to assess potential attacks and provides mitigation and fixes
* Fixing approach:
    - Download new containers: `osism apply -a pull nova -l compute`
        * In this particular case after manually changing the wanted tag for the nova compute container in `environments/kolla/images.yml` in the configuration repository
    - Restart the containers: `osism apply -a refresh-containers nova -l compute`

### Rebooting systems
* Sometimes, hardware needs to be shut down and rebooted
    - When doing hardware maintenance (e.g. exchanging RAM)
    - When deploying new firmware
    - When installing fixes to the host kernel or hypervisor
* To avoid disruption of user workloads, OpenStack supports live-migration (host evacuation)
    - Limitations:
        * This does not normally work if you expose PCI-pass-through to special hardware (e.g. GPUs)
        * The scheduler (placement) service selects a new host according to the normal scheduling rules (e.g. affinity groups), so ensure that you have enough hosts available
    - Performance: 
        * This works by copying RAM content over in several passes (delta migration) -- workloads that do lots of writes to memory will take a while
        * VMs with only networked volumes (or "local" storage backed by Ceph) don't have any trouble with moving disk contents, really local storage however needs a block-migration service that can be slow to copy disks over
        * The VM will run a bit slower during the copy process and may be down for a few seconds during the final copy and restart process
        * Gratuitous ARP packets should inform switches on new location of VM ports, so network disruption should be short as well
* Rebooting a large set of compute hosts can still be a tedious process
    - Ensure enough capacity when parallelizing the reboot process
    - Ensure proper error handling when host evacuation fails
    - Announcing this to customers beforehand (as a time of higher risk / lower performance) will be appreciated
* See the hints how to take out and evacuate a compute node in the [operations guide](https://osism.tech/docs/guides/operations-guide/node/package-upgrades)

### Version upgrades
* The SCS reference implementation has a new release twice a year (to follow upstream OpenStack releases)
    - You need to be prepared to upgrade within the weeks after the release to get full community support
    - The community has worked with providers successfully ahead of the release to ensure that the upgrade works smoothly
* It is highly advisable to test this within test and reference environments
* Downloading all new container images (`osism apply -a pull`) prior to deploying them will reduce the downtime.
* The process will typically involve live-migrations and a reboot for each node
* There is an [Upgrade Guide](https://osism.tech/docs/guides/upgrade-guide/) that you should
  read and study. The below information is just to provide an overview.
    - If you are upgrading to a new OSISM release, please also read the version-specific release notes.
* Typical sequence:
    - Update the OSISM manager node `osism update manager`
    - Update docker, traefik, netbox `osism update ...` and ensure the facts are in sync (`osism reconciler sync; osism apply facts`).
    - Download container images: `osism apply -e custom pull-container-images`
    - Update infrastructure services:
    ```bash
        set -e
        for svc in common loadbalancer opensearch openvswitch ovn memcached redis \
                   mariadb rabbitmq; do
            osism apply -a upgrade $svc
        done
    ```
    - Update OpenStack services (the exact list depends on your deployment)
    ```bash
        set -e
        for svc in keystone horizon placement glance neutron nova cinder designate \
                   octavia skyline barbican heat magnum; do
            osism apply -a upgrade $svc
        done
    ```
    - Update prometheus and grafana: `osism apply -a upgrade prometheus; osism apply -a upgrade grafana`
    - Ensure other containers are in sync:
    ```bash
        set -e
        for svc in phpmyadmin cgit homer netdata openstackclient kubernetes clusterapi; do
            osism apply $svc
        done
    ```
    - Clean up unneeded containers: `osism apply cleanup-docker-images -e ireallymeanit=yes`
* It is highly recommended to script the upgrade and test this in your reference/preproduction environment extensively.
    - You may use the the [testbed scripts](https://github.com/osism/testbed/tree/main/scripts) as template.

### Adding and removing compute nodes
* Removing:
    - Evacuate compute hosts
* Adjust inventory
* Apply all services with `osism apply` to roll out the change

### Practical assignment
* Upgrade a service
