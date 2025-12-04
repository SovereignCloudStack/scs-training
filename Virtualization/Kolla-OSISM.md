## Containerized OpenStack with kolla-ansible

### Concepts
* All OpenStack services (and the required infrastructure services) are packaged as containers
* These are then deployed to all hosts where they are needed
* Containers are self-contained and can be individually replaced for bug-fixes or upgrades
* Ansible playbooks are used to orchestrate rollout ... of the docker containers

### Kolla-Ansible
* Is an OpenStack upstream project (with OSISM staff being important core contributors)
* Is well documented <https://docs.openstack.org/kolla-ansible/latest/>

### Ansible 1x2

#### Ansible concepts
* Ansible is a configuration management system that uses ssh to connect to managed nodes (agent-less)
* These are kept track of in an inventory
* Gathered information on those nodes are called facts
* Ansible is run from the control node (in OSISM: the manager)
* Ansible is written in python and uses YAML-formatted configuration files

![Ansible hosts](ansible_inv_start.svg)

#### Ansible Playbooks
* An *ansible playbook* is a set of *ansible plays*
* An *ansible play* applies *tasks* to the applicable managed nodes (mapped hosts)
* Tasks are often composed of *ansible roles*, which are reusable fragments with
    - tasks (instructions to execute)
    - handlers (a task that gets only executed if triggered by a change)
    - variables (settings that control aspects of the task)
* Ansible playbooks *should* be written such that they are *idempotent*
    - Their job is to bring the managed node into the desired state
    - If it already is in the right state, nothing should be done
    * This is best practice in configuration management and allows to create reconciliation loops
* An *ansible collection* is a format to bundle a set of playbooks, roles, modules and plugins that
    can be used independently

#### Ansible demo: Inventory
* We follow the instructions at <https://docs.ansible.com/ansible/latest/getting_started/>

  Inventory directory `inventory` content `inventory/hosts` (ini format):
  ```ini
  [group1]
  hostname1
  IP-address2
  # comment
  
  [group2]
  hostname3
  hostname4
  hostname5
  
  [metagroup:children]
  group1
  group2
  ```
  
*  Test reachability
  ```bash
  ansible -m ping -u ANSIBLEUSER -m ping ROLEORGROUP
  ```

* Above introduced groups and metagroups
* Inventory files can alternatively be kept in yaml format
* You can set per host variables `host_vars/nodename/vars.yaml`
* Follow <https://docs.ansible.com/ansible/latest/getting_started/get_started_inventory.html>

#### Ansible demo: playbooks
`playbooks/testplay.yaml`
```yaml
- name: ping-and-echo-and-touch
  hosts: metagroup
  tasks:
    - name: ping
      ansible.builtin.ping:
       # ignore

    - name: echo
      ansible.builtin.debug:
        msg: hello

    - name: touch
      ansible.builtin.command:
        touch touched
```

Execute it:
```bash
ansible-playbook -i inventory -u ANSIBLEUSER playbook/testplay.yaml
```
* Playbooks <https://docs.ansible.com/ansible/latest/getting_started/get_started_playbook.html>

### OSISM: Open Source InfraStructure Manager

#### What is [OSISM](https://osism.tech/)?
* Life-cycle and deployment management tooling built on top of kolla-ansible
  (and significantly contributing to kolla-ansible)
* Orchestrates the kolla-ansible OpenStack containers plus containers for
    - Infrastructure services (database, queuing, ...)
    - Management tooling (ARA, netbox, phpmyadmin, optional download proxy)
    - Observability tooling (netdata, prometheus)
    - k3s Kubernetes cluster for operator services (add-ons)
    - Optional: Ceph deployment (w/ ceph-ansible or rook)
* OSISM is the reference implementation for the Virtualization (IaaS) layer in
    the SCS project
    - It's used by most SCS compliant production environments (6 plus a few more
      upcoming)
    - Some others use [yaook](https://alasca.cloud/yaook/) or internally grown
      tooling.
* Most of the following information is specific to OSISM (or kolla-ansible),
  though concepts on other tooling is similar.

#### Digression: Comparison OSISM and yaook
* yaook also uses containerized OpenStack services
    - Not currently using the kolla ones though, but custom-built
* The service containers are not managed via ansible and docker, but
  orchestrated with Kubernetes (K8s).
* The orchestration is done with K8s operators
    - K8s operators is software that knows how to manage a service, i.e.
      knows how to bring the service up, how to change settings on it,
      how to get it back working in some cases of breakage, how to scale it
      up and down and how to remove it again.
* Deployment thus starts with a (minimal) Bare Metal K8s deployment (yaook-kubernetes, aka tarook)
* yaook has a good abstraction level to reduce complexity for automating OpenStack
  operational tasks
* With maturing yaook operators, this may become the future reference implementation
  for SCS
* Used by a number of production environments (amongst which StackIT, not SCS-compliant,
  and upcoming UhuruTec/Yorizon which will be SCS-compatible).

#### The OSISM manager node
* It is the ansible control node of your setup
* Acts as central control point for all changes, the only node where you login during
  normal operations
    - gitops: The configuration settings are stored in git, automation could be built
      to no longer require login to the manager node in order to trigger changes;
      `osism reconciler` prepared for this
    - Other nodes are technically accessible (`osism console` command), but this may
      be against policy (except maybe for debugging). Local changes are strongly
      discouraged and potentially destroy the manageability/trustworthiness of the
      system.
* Hosts management tooling
    - ARA, netbox, database, phpmyadmin, OpenSearch(optional)
    - CLI tooling for the operator
    - Homer Web Frontend for the operator, Traefik ("Ingress")
    - Backends for the above: Redis, Postgres
* The configuration repository is stored in `/opt/configuration/`
    - Main location for config settings there in `inventory/` and `environments/` directories,
      e.g. `/opt/configuration/environments/kolla/` for the OpenStack services.
        * Rendered OpenStack config files in `/etc/kolla/`, collected logs in `/var/log/kolla/`
* Deployment scripts in `/opt/configuration/scripts/`

#### Node type: Control node
* Control nodes host infrastructure and monitoring
    - Database (mariadb/galera cluster, proxysql, memcached)
    - rabbitmq
    - Prometheus
    - Grafana
    - OpenSearch (if not disabled), fluentd
    - k3s (if enabled, useful for extending control plane, e.g. with keycloak)
* OpenStack services
    - keystone
    - cinder, manila (if enabled)
    - glance
    - magnum (if enabled)
    - designate
    - barbican (if enabled), octavia
    - skyline, horizon
    - nova (not compute, libvirt, ssh)
    - aodh (if enabled)
* Avoid overloading them

#### Node type: Compute node
* Compute nodes host the virtual machines
* To do so, they host a few OpenStack services
    - cinder, iSCSI (tgtd, iscsid)
    - nova (compute, libvirt, ssh)
    - neutron metatdata agent
* Also prometheus, fluentd
* Capacity determined by RAM and CPU cores

#### Node type: Network node
* Networking functions
    - neutron
    - octavia
    - openvswitch and OVN

#### Node type: Storage node
* Ceph containers
    - OSDs
    - Mon+Mgr, MDS, RGW

### Planning hardware

See also <https://docs.scs.community/docs/iaas/guides/concept-guide/bom>

#### Hyperconverged vs. Fully decomposed
* We need some nodes to run OSISM
    - 1 manager node (M)
    - 3 control plane nodes (M)
    - 3 network nodes (M)
    - 3 ceph storage nodes (S)
    - 3 compute nodes (L), better 4+
        * The 4th compute node helps with doing rolling upgrades for clusters of all kinds
        * E.g. a Cluster-API cluster with 3 anti-affinity control plane nodes needs a 4th compute host
          for a rolling upgrade
* A fully decomposed setup would thus have 14+ nodes
* We can combine some functions
    - Combine storage and Compute nodes
    - Combine Control Plane and Network Nodes
    - This results in a setup with 8 nodes
    - This is how the testbed setup looks like (7 nodes actually, only 3 for compute)
* We can go fully hyperconverged (HCI)
    - Then we have 4 large nodes plus one small manager node
    - Reasonable compromise for small systems
    - Some QoS needed to ensure stability in high-load situations
        * Avoid control rabbitmq dropping messages due to customer VM overload
    - More decomposed setups can more easily scale
    - Your security architects may want network nodes to be separate from compute nodes ...

#### Sizing: Compute Nodes
* Customer VMs have a mixture of 1:2 ... 1:8 ratio vCPU to RAM
* vCPUs can be oversubscribed, unlike memory. 2--3x over-subscription per real core is
  a reasonable sizing approach
* Compute nodes thus should have 1:8 ... 1:16 ratios
    - E.g. 64 core w/ 768 GiB RAM, 96 core with 1024 GiB RAM
    - 32 core w/ 384 GiB is perfectly reasonable as well, lower than 16 core w/ 192GiB RAM becomes inefficient
* You could squeeze a bit more by having larger RAM, but you tend to then run against vCPU limits and
  your customers might feel less happy whereas your savings are minimal
* Reserve some cores (1C +5% of all) and some RAM (4GiB + 4% of all) for the host
* Turn on hyperthreading if it's secure on your CPU, it adds ~20% CPU capacity
    - Lower max. over-subscription ratio from 5/Core to 3/Thread then

#### Sizing: Control Nodes
* Avoid these to hit their limits
    - Especially rabbitmq and also database are needed and must not be starved for resources
* If you run OpenSearch, this alone adds ~32GiB RAM, 4 core requirement (even for smaller clouds)
* Assume 32GiB for small clouds, double for larger ones (plus OpenSearch)
* 16 cores is enough, more for large environments (plus OpenSearch)
* Ensure sufficient and fast storage (database): NVMe (RAID-1)
* k3s also adds 4GiB RAM, 2 cores plus the requirements of workloads running on k3s

#### Sizing: Network Nodes
* Need to deal with lots of flows
* 16GiB plus 4C for low network utilization
    - double for medium
    - double again for high
* Good network I/O (obviously)

#### Sizing: Storage nodes
* 1C (2HTs) and 4GB per OSD
    - Double this when using encryption
    - Also add a core and a few GB if you use erasure coding
* Network I/O is very important, fast storage as well obviously
* See notes in Ceph Doc

#### Sizing: Manager node:
* 32GB, more if you want to use OpenSearch
* 8C, more for large environments / OpenSearch
* Storage: SSD/NVMe; use 2x1.9TB to have sufficient space for caching packages and containers

#### Putting it together:
* Add requirements up when combining roles in not fully decomposed setups
* Smaller setups will work
    - If you carefully design QoS settings to avoid starvation
    - If you avoid too high load
    - This adds complexity and the engineering time and operational trouble tends to be more
      expensive than the saved hardware cost, at least for production / production-like systems

### OSISM Installation workflow

#### Overview over the steps
* Procure hardware, set it up, connecting it to the network
    - With (static) DHCP this works conveniently
* Bootstrap manager using the Ubuntu auto-install image
    - BMC allows this without physical USB sticks (but some require SMB or PXE server)
    - Firmware upgrades, NVMe reformatting, ... may conveniently be done now
* On seed node (can be the admin's Linux/Mac/WSL desktop system):
    - Create configuration repository using cookiecutter
    - Setup manager from seed node
* On manager node
    - Configure inventory, select roles (control, compute, network, storage)
    - Customize the setup according to your needs
    - Roll the configuration using the ansible playbooks (via OSISM CLI)

#### Bootstrapping hardware (BareMetal provisioning) - Manager and all other resource nodes
* Auto-install images are available from OSISM <https://github.com/osism/node-image>
    - Variants based on disk setup (SCSI/SSD sda vs. NVMe nvme0n1)
    - If nothing matches (and you have enough machines to want to avoid manual adjustments)
      you can build your own auto-install images
* On server hardware, you can attach the boot image as virtual drive
    - Some BMC implementations allow to just upload the images, others require a SMB/CIFS server
    - You can set up a PXE server and have servers do a PXE boot
    - Physically attaching USB stick works as well
* Server needs (outgoing) internet connection to download software and updates
    - If that is unwanted, a package mirror can be set up (see air-gap blog articles)
* Server install phases:
    - Server shuts down after first installation phase, after which (virtual) boot image should be removed
    - Server sets up some services (mostly in docker containers) in the second phase and shuts down again
    - Server is ready after switching it on the 3rd time
* You can also manually provision the hardware in case you need to
  <https://docs.scs.community/docs/iaas/guides/deploy-guide/provisioning>

#### Creating the configuration repository (seed node)
* This should be prepared on the operators control outside of the cloud
    - A desktop system (preferably Linux, but Mac or WSL work as well) that supports docker
    - A small VM somewhere can be setup if needed; it can be disposed after config repo and manager node are set up
* Follow the steps on <https://docs.scs.community/docs/iaas/guides/deploy-guide/seed>
* Chose where you want to store your configuration repository
    - Any git server will do, your company's git, your private gitlab, a public github will all do
    - Secrets are stored separately
* Install `git python3-pip python3-virtualenv sshpass libssh-dev`
* Run the cookiecutter:
  ```bash
  mkdir cookiecutter-output
  docker run \
    -e TARGET_UID="$(id -u)" -e TARGET_GID="$(id -g)" \
    -v $(pwd)/cookiecutter-output:/output --rm -it quay.io/osism/cookiecutter
```
* Answer the questions from cookiecutter, see <https://docs.scs.community/docs/iaas/guides/configuration-guide/configuration-repository/#creating-a-new-configuration-repository>
* Output is stored in directory `cookiecutter-output/`. Commit and push it to your git.

####  Secrets handling
* There is a sub-directory `cookiecutter-output/secrets/` which is *not* (and should *never* be) committed to git
* Ensure to save the contents of this directory at a safe and secure place!
* `secrets/vaultpass` contains the password for your ansible vault and is stored as a `keepass` file.
    - The *initial* password for the Keepass file is `password`. Change it.
    - Alternatively handle the secrets in another vault of your choice.
* Makefile targets to get ansible vault secrets, see <https://docs.scs.community/docs/iaas/guides/configuration-guide/configuration-repository/#working-with-encrypted-files>, e.g. `make ansible_vault_show FILE=all`
* Keepass clients exist for many operating systems (incl. Android), there is also a nextcloud app

#### Inventory
<https://docs.scs.community/docs/iaas/guides/configuration-guide/configuration-repository/#step-4-post-processing-of-the-generated-configuration>

* Cookiecutter creates node `node01` for your manager. Adjust it to the real name.
    - It is convenient to ensure that DNS resolution works with the used names
    - If you use the domain `region1.mycloud.org` and call the manager `manager`, it is
      convenient to have `region1.mycloud.org` as a default search domain and ensure that
      `manager.region1.mycloud.org` resolves to the IP address of the manager node. Same
      for the other nodes.
    - You can use netbox for IP Address Management
    - Set the `ansible_host` 
* Set the manager inventory in `environments//manager/hosts`
    - You can set `host_vars` in `environments/manager/host_vars/`
* Global settings: DNS, NTP, .... `environments/configuration.yml`
* Deploy TLS (SSL) certificates in `environments/kolla/certificates/haproxy.pem` and `haproxy-internal.pem`
* Parameter reference: <https://docs.scs.community/docs/iaas/guides/configuration-guide/configuration-repository/#parameter-reference>
* Later (on the manager host in `/opt/configuration/`) : Adjust the inventory
    - List the nodes and add them to the roles `[manager]`, `[monitoring]`, `[control]`,
      `[network]`, `[ceph-control]`, `[ceph-resource]`, `[ceph-rgw:children]` in `inventory/20-roles`.
* You can set `host_vars` there in `inventory/host_vars/NODE.yml`
    - You can also assign vars to group (Group vars), use `generic` for all groups.
* Changes should always be committed and push to git
* `osism apply configuration` gets the latest status from git (overwrites local changes if any)

#### Manager
* Setting the operator user: <https://docs.scs.community/docs/iaas/guides/deploy-guide/manager#step-1-create-operator-user>
* Also apply network settings, bootstrap and reboot the manager node
* Deploy the manager service and set vault password (it's in your keepass vault if you did not move it elsewhere)
* These steps should work without any errors

#### Nodes
* Do the bare metal provisioning as described before
* Make them managed by applying the bootstrap steps <https://docs.scs.community/docs/iaas/guides/deploy-guide/bootstrap>
* All nodes should be reachable (cf. step 6 with `osism apply ping`), resolve any issues prior to proceeding
    - Remember that an ansible ping verifies that ansible can log in via ssh to manage the host
    - This is why the final steps are `osism apply sshconfig` and `osism apply known-hosts`

#### Network
* If you use VLANs, Link aggregation (802.3ad, also called bonding or trunking), you will need to adjust
  your network settings.
* For Ubuntu hosts (since OSISM 6.1.0), netplan is used,
  read <https://docs.scs.community/docs/iaas/guides/configuration-guide/network>
* If you want to proxy outgoing internet access on the manager node (e.g. for security reasons),
  read <https://docs.scs.community/docs/iaas/guides/configuration-guide/proxy>
* Extra hints for the loadbalancer, e.g. TLS/SSL certificate deployment:
  read <https://docs.scs.community/docs/iaas/guides/configuration-guide/loadbalancer>
    - Note: This is for the loadbalancer(s) in from of the Infra/OpenStack API services, not the
      loadbalancers that cloud users create with the OpenStack octavia service

#### Nodes: Infrastructure, Network, Logging/Monitoring, Ceph, OpenStack
* <https://docs.scs.community/docs/iaas/guides/deploy-guide/services/>
  covers this well
* Maintain the order: infra, network, logging/mon, kubernetes (optional), ceph, OpenStack
* This can be scripted (and there are scripts e.g. for testbed deployments)
    - If you use your own script, ensure you do *not* ignore errors
    - `set -e` is a must in shell scripts
* For Ceph, the deployment with ceph-ansible is still the default, this will change to
  ceph rook in the future. Ensure you have kubernetes/k3 set up

#### OpenStack tuning
* See <https://docs.scs.community/docs/iaas/guides/configuration-guide/openstack/>
    - E.g. 3x CPU over-subscription assumes that you have HT(SMT) enabled, you might increase to 5x otherwise.
* It also explains the mechanism how config file templating works and how these are rolled out with
  the ansible playbooks (example: OpenSearch)
* The service-specific hints mostly link the upstream OpenStack docu
* The Commons and Services chapters have kolla and OSISM specific information

### Validating that the installed environment works

#### Connect to the deployed environment
* The most convenient is to use a wireguard connection to the manager
* This creates a tunnel into the environment, even if it has otherwise
  no inbound internet access
    - Access to the manager (192.168.16.10 on testbed/CiaB) and the dashboards ()
    - Access to the external Floating IP network (192.168.112.0/24 - inbound connections to VMs)
* Config on manager in `/etc/wireguard/wg0.conf`, client config in dragon home directory
* Create additional wg configs and devices if you want to connect from multiple hosts simultaneously
    - Change device name (`wg1`), port, virtual server IP 192.168.48.x and virtual client IPs to avoid confusion
    - Obviously, you would want to change the secrets as well in case you want to avoid impersonation of admins

#### Visual inspection
* For an overview of dashboards look at CiaB or testbed documentation
  at <https://docs.scs.community/docs/iaas/guides/configuration-guide/openstack/>
* The most important ones are linked from Homer at: <https://homer.services.YOURCLOUDDOMAIN/>
    - Homer should work and link roughly s dozen further dashboards
* Check whether Ceph is healthy
    - `ceph healh detail`
    - Dashboard
* OpenStack dashboard works (horizon and/or skyline)
    - You can login to the Default domain with the admin credentials from vault
    - On CiaB, there is also a test domain with a test user with password test

#### Reviewing install logs
* ARA records the outcome from all playbooks
    - There should not be any failures
* osism logs

#### Testing
* RefStack is the framework used by (former) OpenStack InterOp Working Group to run the
  InterOp Guideline tests. In general, you can use it to run sets of Tempest tests.
    - Tempest is the test framework and test case collection from OpenStack
    - Note that RefStack is no longer maintained well upstream; you may need to
      set up rally manually instead.
* SCS Compliance test
    - Check whether you fulfill the SCS-compatible IaaS tests (currently version 5.1):
        * Check out <https://github.com/SovereignCloudStack/standards> and go to `standards/Tests/`
        * Ensure you can access your cloud via the API / CLI tools and have configured
              `~/.config/openstack/clouds.yaml` and `~/.config/openstack/secure.yaml` for it
            = Test this with openstack command line tools (you need the python SDK installed anyway)
            - It is recommended to run compliance checks with**out** admin privileges
            - In case they ever clean up too much, this won't hit anything but itself
  ```bash
  # This example assumes you want to name the cloud CiaB-KG7 and have a
  #  cloud "test" defined in clouds/secure.yaml
  ./scs-compliance-check.py scs-compatible-iaas.yaml --subject=CiaB-KG7 -a os_cloud=test
  ```
* OpenStack Health Monitor (OSHM)
    - Will cover this later
    - Running one iteration manually is a good scenario test for the core functionality
      (Catalog, Router, Networks, Subnets, Floating IPs, Security Groups, Images, Block Storage,
       VMs, metadata-service, LoadBalancer) and also checks the availability of a number
       of other services.
    - You should get a run without any error or timeout -- i.e. no red color.
    - Same comment as for SCS Compliance test: Run this with normal project `member` privileges, not as admin
* In case you don't want to set up permanent OSHM monitoring anyway, you may find the
  [Simple Stress](https://docs.scs.community/docs/iaas/guides/operations-guide/openstack/tools/simple-stress)
  tool easier to use.

### The OSISM tool

#### osismclient
* All management happens on the manager node
    - Most of it by calling the osism command line tool
    - It's a wrapper to call the `osism` program in the `osismclient` container
        * except for `update manager` and `update docker`
* osism offers command line completion (with `<TAB>`) and help
    - e.g. `osism reconciler --help`
* `osism get versions manager` gives you information on your managed setup
* `osism log container HOST CONTAINER` will retrieve log files for you (`docker logs`)
* `osism manage XXX` is a wrapper for flavor and image manager
* With some docker versions, the commands may output a spurious `\r` (CR) at every line,
  so filter this out when doing scripting.

#### OSISM playbooks
* `osism apply PLAYBOOK` runs ansible playbooks with the appropriate settings
    - `osism apply -a stop PLAYBOOK` would typically stop the service referenced by `PLAYBOOK`
    - `osism apply -a upgrade PLAYBOOK` would get the latest version of a service (container) and then
      run the `PLAYBOOK` to start the service referenced by it
* `osism apply` gives you a list of PLAYBOOKS
* Running playbooks to start services that already run is harmless
    - Changed settings will be applied if there are
    - The playbook summary allows you to see whether that is the case (`changed=`)
* `osism get facts/hosts/hostvars/tasks/...` also just wraps ansible

#### Performing changes workflow
* Perform changes in the checked out configuration repository ON A TEST OR REFERENCE ENVIRONMENT
    - Typically you end up editing some file under `/opt/configuration/environments/`
    - Push the changes (for your test environment) and apply them:

      ```bash
      osism apply configuration   # Pull config from git
      osism reconciler sync       # Adjust derived config files
      osism apply facts           # Gather/Update ansible facts
      ```

    - Run the playbooks that consume the new settings: `osism apply PLAYBOOK`
    - If everything works as designed, commit the same changes to the config repository
      of your production environment.
        * Ensure review and approval processes are in place for this; some changes may
          require customer communication or approval from your security team
        * Same procedure: push to repo and use the above osism commands
* Read recommendations how to work with git branches
  <https://docs.scs.community/docs/iaas/guides/configuration-guide/manager#working-with-git-branches>
* Review is good, testing is better
    - Take reviews seriously!
        * Be mindful of hierarchies or cultural habits that e.g. prevent questioning higher ranked people
        * Think a moment about AF447 or Fukushima

### Practical assignments for OSISM

#### Create a config repository (seed node)
* Decide where to store the git config repository
* Decide where to store the secrets
* Get a name/domain for your (test) cloud
* Run the cookiecutter container and push the result to your git repo
* Ensure you store the secrets in a safe place
* Adjust manager inventory on git repo as needed

#### Bootstrap and install manager (manager node) -- if we have a real lab env
* Identify the suitable auto installation image
* Perform installation
* Run scripts to make manager managed

#### Study the OSISM tool on the manager (can do this on testbed or CiaB)
* Get the manager and the main components version
* Look at the inventory
* Facts collection
* Update images
