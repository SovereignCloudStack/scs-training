## Supporting users

### Responsibilities and Data protection considerations
* In a public cloud model, the cloud operator has **no** business looking into the virtual machines and what the customers do there.
    - In many jurisdictions, data protection considerations would prevent the provider's operators from doing so.
    - This creates a very clear delineation of responsibilities:
        * The cloud provider makes sure that the virtual infrastructure and their automation via APIs work
        * What happens inside VMs is the customer's responsibility (assuming the infra works)
* The clear delineation makes sense even in a private cloud model where the customers may be in the same company
* In support situations, customers may ask the provider to support within the VM
    - This is not a standard service and may require special arrangements
    - Including arrangements around data protection (commissioned data processing), fees, etc.
* It does make sense for a cloud provider to unilaterally provide information to help customers within their VMs
    - This may include public images that work well and that are regularly updated
        * The SCS Standard requires a few of them even
    - This may include documentation
    - The following information may be such helpful infos and is all written from a user perspective

### Typical user challenges

#### Floating IPs
* Making a VM reachable from the outside typically requires several steps on OpenStack (which may surprise newcomers)
    - Connecting the VM's network port to a network that is connected to a router that is connected to the outside network
    - Allocating a floating IP from the outside network and associating it with the network port of that VM
    - Ensuring security groups allow (incoming) traffic to that network port
    - The VM itself may have firewalling functionality that needs to be adjusted (or disabled)
* Floating IPs are **not** visible from within the VM
    - You just see the fixed IP address of the network port
    - Traffic from the outside is DNAT'ted and appears to be directed to the network port from within the VM

#### Security Groups
* A security group is a list of ALLOW rules for a group of network ports
    - Most security groups allow all outgoing traffic
        * Related packets (responses to outgoing packets) are allowed back in
    - Many security groups allow all incoming traffic *from the same groups*
        * This means all ports inside the group can freely communicate with each other (thus the name group)
    - Behind the scenes, when referring to a remote security group, the IP addresses belonging to that group are whitelisted
        * This is secure due to port security, which means that network ports cannot spoof their source IP address
            - When using non-private fixed IP address ranges, external traffic might reach your VM without being subject to port security rules, so take extra care not to allow such traffic in if you really have to work with non-private IPs.
                * Private IP addresses here really refers to the non-routable IPv4 netorks 192.168/16, 172.16/12 and 10/8 networks.
            - Port security can be disabled per port, if you want to e.g. create VMs that do advanced networking things such as NAT
            - Be aware that such ports can then circumvent security group rules by spoofing their source IP address
        * This also means that adding a port to a security group that's referenced by this or by another security group can mean updating a lot of network filtering rules
            - This can limit scalability of network operations for setups with lots of VMs; consider assigning IP ranges and filtering for them instead in such setups

#### cloud-init
* While clouds (OpenStack is no different from AWS here) typically support users in creating and using their own private images, they provide mechanisms to use generic images and customize them on (first) boot
* The customization is done by providing metadata: `user_data` by the user (and `vendor_data` by the cloud provider, which however is seldomly used) which the generic image then picks up and uses it to adjust its behavior
* This can be used to do things like
    - Injecting public ssh keys (as `authorized_keys`)
    - Updating and installing software
    - Running scripts
    - Creating users
    - ...
* This allows to do everything with generic images; by doing all the customization on (first) boot, the customer infamous golden images that get more and more outdated over time are avoided
* There are several well-known mechanisms to provide the metadata to the VM; the two most used ones are attaching a virtual drive (CD-Rom typically, used to be a Floppy Disk) and providing an http network source at http://169.254.169.254
    - Try `curl http://169.254.169.254/openstack/latest; echo` on a VM on OpenStack ...
* The software that processes the metadata and does the customization is typically [cloud-init](https://cloudinit.readthedocs.io/en/latest/) on Linux
    - Read the documentation to get an idea of all the possibilities
    - On Windows, [cloudbase-init](https://cloudbase.it/cloudbase-init/) does provide similar functionality

#### Keypairs
* One thing almost always required on first boot of Linux VMs is the injection of an authorized public ssh key, so the owner of the VM can login and investigate and configure things
    - For production VMs, it may be best-practice to *not* allow any login
* The key injection is done by OpenStack providing the keypair selected in horizon or via the API in the metadata, which cloud-init then picks up
    - Run `curl http://169.254.169.254/openstack/latest/meta_data.json | jq` from within the VM to see it (you need to install `jq` to get the json nicely formatted)
* It's best to just register your public ssh key with OpenStack to make it available
    - You can have OpenStack create key pairs for you -- this is deprecated
        * OpenStack does NOT store the secret key for you, it is displayed once upon generation, grab and store it and keep it safe
* There is no way to recover a lost secret key, so you might lose ssh access to your VMs
    - Most cloud images do not allow a console login by default
        * OpenStack offers a novnc console for VMs that you can use for emergency access if you configured your VM to allow local password authenticated logins

#### Troubleshooting boot issues (self-support)
* When a created VM does not become accessible, this can be debugged in a number of ways
    - Most Linux images are configured to write the boot log to the serial console. This is captured by OpenStack and can be accessed via horizon or via `openstack console log show`
    - Most Linux and Windows images create output to a virtual VGA graphics card. This can be accessed via horizon or by pointing a web browser to the URL given by `openstack console url show`. Many images also allow input this way, so you could log in if local console logins are allowed.
* If you have created your own image, you may be able to observe trouble from the boot-loader to locate and load the operating system.
    - This does not typically happen on generic images provided by the provider
* You may see trouble with your root file-system which may have suffered corruption on a crash
    - This can be recovered by attaching the volume to another VM and using file-system recovery tools
    - For local storage, you can boot with a rescue image (`openstack server rescue`)
* Your volume may be read-only and reject WRITE requests
    - This is due to locks held when Caph went down and needs support from the cloud provider; it is described above in the Maintenance section
* Your VM might have booted perfectly and you just fail to reach it via the network
    - Double check network settings:
        * Do you have a floating IP assigned or another VM attached to the same router to access it?
        * Is the service (ssh) running and the port allowed in firewall and security group rules?
* You may reach it via ssh, but it rejects your login
    - Did you inject the right public ssh key?
        * `openstack server show` and horizon can show you which ssh key was specified for injection upon VM creation
        * If the metadata service was broken on first VM boot, the ssh key might not have been injected. Throw away the VM and recreate it then (assuming that no valuable data is held on a local root volume)
    - Did you specify the right private ssh key when connecting?
        * Use `ssh -v` to get more debug output ...
        * Beware that ssh-agents may offer added keys ahead of the one you just specified. (`SSH_AUTH_SOCK="" ssh -i ~/.ssh/privkey.pem logname@host` helps then).
    - Note that username/password authentication via ssh is not normally enabled in cloud VMs due to security considerations

#### Snapshots and backups
* Definitions
    - A snapshot is a point-in-time state of a block storage device (aka volume).
    - A backup is a copy of a block storage device (aka volume).
* Snapshots:
    - Are typically created within the same storage backend
    - This allows for quick and cheap creation, using copy-on-write
        * Beware that the state of a read-write mounted volume is not necessarily consistent (`sync` helps) due to dirty caches
    - Are useful to protect against user errors or failed application changes etc.
    - The cost of snapshots increase as they age (as they diverge more)
* Backups:
    - Should be stored on a different storage backend, thus also providing protection against storage backend breakage
    - Are typically slow to create as full copies are created
    - Snapshots can be backed up (by creating a temporary volume)
        * For read-write mounted volumes, this is the only way to have a backup that at least comes close to a consistent file-system
    - OpenStack even offers incremental backups, only saving the block-level changes since the last backup

### IaC tooling
* Cloud-natives do not create VMs via the (horizon or skyline) web interface and then login to VMs to do manual configuration
    - Instead they automate the process to make it repeatable and less prone to errors
    - All creation of virtual infrastructure can be automated via the OpenStack set of APIs
    - All configuration inside the VM can be bootstrapped by cloud-init; using a configuration management system (such as ansible) is typically enabled then to take over
* The OpenStack APIs can be used by a number of Infra-as-Code tools
    - `openstackclient` command line interface
    - python OpenStackSDK
    - Ansible
    - opentofu (which is a free fork of the now proprietary terraform)
    - ...
* Of these, the latter ones are the most popular ones.
    - Some people prefer pulumi over the declarative style opentofu
* Inside the VMs, small configuration tasks are typically done directly via cloud-init; larger things typically via ansible.
    - Other config-mgmt tools such as chef, puppet, saltstack etc. are possible
* Fully automating the deployment makes testing, upgrading, recovering from incidents, ... a lot easier and in general allows development speed and test coverage to increase by factors
    - This is probably *the* main benefit of cloud computing

#### Using the OpenStack API
* Most tools assume a `clouds.yaml` style configuration
    - You keep two config files, `~/.config/openstack/clouds.yaml` and `~/.config/openstack/secure.yaml` where you can have several entries, one per OpenStack project
        * Reminder: An OpenStack project is a workspace for virtual resources with associated roles (user authorizations) in a cloud
    - The `secure.yaml` file is for your passwords and secrets and must be kept safe; by doing so, you can freely show the `clouds.yaml` to others
    - Tools do not enforce this separation, it is possible (but not recommended) to put all into `clouds.yaml`
    - Some people (aggrieved by Windows?) prefer `clouds.yml` (without the `a`) file name, which works as well.
    - The openstack CLI looks for `clouds.yaml` first in the current directory, then in `~/.config/openstack`, then `/etc/openstack/`)
* You can `export OS_CLOUD=$NAME` to make the openstack CLI use the cloud project with that name to avoid passing `--os-cloud=$NAME` all the time
* The old-style `OS_` environment variables (`.openrc` config style) are not recommended, though still fully supported by the openstack-sdk and the openstackclient CLI
* Horizon offers users to download openrc and clouds.yaml style config files

#### clouds.yaml and secure.yaml example with username/password auth
```yaml
# clouds.yaml
clouds:
  gxscs2-community:
    region_name: "scs2"
    interface: "public"
    identity_api_version: 3
    auth:
      auth_url: https://scs2.api.pco.get-cloud.io:5000
      #project_id: fe66fd7655814078924155876562dd3d
      project_name: "p500924-scs-community"
      user_domain_name: "d500924"
      project_domain_name: "d500924"
```
```yaml
# secure.yaml
clouds:
  gxscs2-community:
    auth:
      username: "u500924-XXXXX"
      password: "ThisPasswordIsSecret"
```

* Instead of specifying both `project_name` and `project_domain_name`, the `project_id` could have been configured (commented out in this example).
* In most clouds, the domains used for user management (`user_domain_name`) and projects (`project_domain_name`)
are in sync.
* In this example, `interface` and `identity_api_version` could have been omitted as most tools
assume these values as defaults.
* If your user has access to several projects, you can specify `--os-project-id=` on the openstackclient CLI
  without creating a new entry in `clouds.yaml`.

#### clouds.yaml and secure.yaml example with application credentials
```yaml
# clouds.yaml
clouds:
  gxscs2-testbed-ac:
    region_name: "scs2"
    interface: "public"
    identity_api_version: 3
    auth_type: "v3applicationcredential"
    auth:
      auth_url: https://scs2.api.pco.get-cloud.io:5000
```
```yaml
# secure.yaml
clouds:
  gxscs2-testbed-ac:
    auth:
      application_credential_id: "29afa4cdabba4983bfaaaaaaaaaaaaaa"
      application_credential_secret: "This-Is_Really-Secret-123"
```

* Please remember that indentation is relevant for YAML files.
* The application credential is valid for one project (which is selected during creation) and can be limited in validity.
* By default, appcreds are `restricted` which means that appcreds can not be used to authenticate to create more appcreds.

#### Stateful vs Stateless design
* Cloud native deployments seek to make most or better all VMs stateless.
    - Stateless means that you can throw them away without losing any valuable data
    - Think about a web application, where all configuration comes from the outside (git and vault) and where all
      data is stored in a database. None of the VMs here, neither frontend web servers nor business logic hold
      any persistent data.
* Stateless VMs -- if automated well -- have many advantages
    - You can typically horizontally scale them on demand (with the help of a loadbalancer)
    - You can throw them away in case of a fault or security incident and create new ones.
        * In practice, you might want to save artifacts for analysis / forensic analysis before really throwing away
    - You have much less trouble with upgrade, rollback, validation or A/B testing
    - You don't need to think about backups ...
* Stateless VMs are sometimes called cattle -- in contrast to pets (or snowflakes) that are manually maintained VMs that need operator care, backups etc.
* If some VMs (backend, database) hold persistent data, treat them differently

#### Scaling
* Horizontal scaling (using more VMs to work in parallel) is typically easy to do with stateless VMs
* Vertical scaling (creating larger VMs) is supported by OpenStack
    - You can hot(un)plug disks and network ports into running VMs
    - Changing the number of vCPUs or the amour of memory requires a VM resize operation
        * This causes a reboot of the VM
        * Don't forget to confirm the resize after the rebooted VM has been checked
* Autoscaling (horizontal scaling) in OpenStack can be done via [heat](https://wiki.openstack.org/wiki/Heat/AutoScaling) orchestration templates
    - This is not very popular and SCS standards do not require this functionality to be present
    - Many workloads that would benefit from autoscaling are containerized and use the Kubernetes mechanisms for autoscaling

#### Client tooling
* There are numerous [openstack SDKs](https://wiki.openstack.org/wiki/SDKs) available.
    - The [Python openstackSDK](https://docs.openstack.org/openstacksdk/latest/) is well maintained and the standard way to programmatically interact with openStack APIs.
    - The command line tools [openstackclient CLI](https://docs.openstack.org/python-openstackclient/latest/) are derived from the python SDK
    - Both are available as distro packages on most Linux distros or can be installed via `pip` (e.g. in a `venv`).
* Scripting with the python CLI tools is not ideal -- the repeated startup cost (python loading libraries ...) and the new authentication on each invocation lead to slow performance.
    - Using python directly to automate is much better.
    - Or use terraform, ansible, ...
* An interesting project creates openAPI specs for the APIs and generates rust clients:
    * On <https://github.com/gtema/openstack/>
    * openAPI specs derived from the implementation match real behavior
        - Not all services are covered completely yet, but it's pretty good for the OpenStack core services
    * The rust CLI client `osc` has amazing performance and a high level of consistency
    * There is a `k9s`-like terminal user interface `ostui` which is nice for inspection

### Security incidents (provider perspective)
* As public cloud provider, beware that you will have people sign up for your cloud with stolen credit card data
    - During the heydays of crypto mining, these could be more than 50% of new customers
    - You might want to use payment providers that do some checking for you
    - You might want to limit quota that you assign initially and increase them upon confirming that your customer is legitimate
* Your customers may fail to secure their virtual environments accurately
    - If they are hacked into, it does *not* in any way breach your integrity as a public cloud provider
    - By design, you can have evil customers next to legit ones and they are protected from each other
        * While a high degree of security isolation is a condition sine qua non for any public cloud, performance isolation may not be as perfect, especially if you allow over-subscription. (SCS Standards allow for moderate CPU over-subscription for V-type vCPUs.)
        * Without any throttling, evil users might also cause a large load on your control plane (API), so the API response times for legit customers may deteriorate
    - In practice, you still want to get rid of evil customers and help your legit customers to secure their environment to avoid reputational damage
        * And of course you want your bills to be paid
    - Obviously, your public images and configuration advice should be suitable to keep your customers secure.
* Providing transparency to your customers in case of security incidents may help to (re)establish trust
    - This is best practice and the SCS community may support you in the right way to publish root cause analysis
* You will want to have some DoS/DDoS protection in front of the OpenStack API and the public network used by VMs, so you can protect yourself and your customers
    - Large DDoS attacks are hard to defend against and you will only win if you have more bandwidth than the attacking machines combined; this can typically only be achieved with the help of your internet network provider

### Practical assignments (user perspective)
* Download a storage volume from a stopped VM
    - Hint: There are several ways
    - Hint: OpenStack does not offer downloading volumes, but images
    - Hint: You can dynamically attach (and detach) volumes (and ports) to running VMs
* Clone a VM
* Boot a rescue image
* Create snapshots and backups from volumes and restore them
