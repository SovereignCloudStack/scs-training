## OSISM manager tooling

### OpenStack Flavor-Manager

#### Purpose
* SCS prescribes a flavor naming scheme in standard [scs-0100](https://docs.scs.community/standards/scs-0100-v3-flavor-naming)
    - Flavor names like `SCS-nV-m` denote a flavor with `n` vCPUs and `m` GiB of RAM, the `V` denotes that
      vCPUs might be oversubscribed (up to 5x, or 3x for a hyperthread), but they need to be secure
      (CPU speculation vulnerabilities mitigated), RAM must be ECC protected and not oversubscribed.
    - `SCS-nC-m-20s` would denote a flavor with `n` dedicated Cores (the `C`) and 20 GiB SSD/NVMe
      (the `s`) root disk.
    - Decoding can be done with a simple web tool <https://flavors.scs.community/>.
    - The scheme allows for many more details (such as hypervisor, CPU generation, GPU, ...) 
      to be specified via the name, but these are really only used for special requirements.
    - The scheme also prescribes metadata (`extra_specs`) for discoverability
    - Flavors that do not start with `SCS-` are allowed and don't need to comply
* There is also a set of mandatory flavors that need to be present on each cloud that
  wants to be *SCS-compatible* at the IaaS (virtualization) layer. It is specified in standard
  [scs-0103](https://docs.scs.community/standards/scs-0103-v1-standard-flavors).
    - Note that there is a selection of 13 flavors with 1:2, 1:4 and 1:8 ratio of vCPU to RAM (in GiB),
      with up to 16 vCPUs and up to 32GiB of RAM. Larger flavors are of course allowed.
    - Two flavors `SCS-2V-4-20s` and `SCS-4V-16-100s` have a local SSD/NVMe included and are meant
      for etcd and database usage.
* The SCS compliance checks test for these.
- The SCS flavor manager allows to create these flavors

#### Usage
On the manager node, run `osism manage flavors --help`
```bash
dragon@testbed-manager(test):~/.config/openstack [0]$ osism manage flavors --help
usage: osism manage flavors [-h] [--no-wait] [--cloud CLOUD] [--name {scs,osism,local,url}]
                            [--url URL] [--recommended]

options:
  -h, --help            show this help message and exit
  --no-wait             Do not wait until flavor management has been completed
  --cloud CLOUD
                        Cloud name in clouds.yaml
  --name {scs,osism,local,url}
                        Name of flavor definitions
  --url URL     Overwrite the default URL where the flavor definitions are available
  --recommended         Also create recommended flavors
```

### Image Manager

#### Purpose
* Cloud providers must allow users to upload their own images (within fair use limits)
* For convenience, we recommend they offer public images that are centrally maintained
    - This saves work to customers by not having to upload standard vanilla upstream images
    - And it avoids the need to repeat this regularly to include the latest bug- and security fixes
    - Customization is then done via *user-data* injected at boot and typically consumed by `cloud-init`
* To make them really useful, users need to know what the policies of these images are
    - SCS has specified mandatory metadata (properties) for images in standard [scs-0102](https://docs.scs.community/standards/scs-0102-v1-image-metadata)
    - The metadata specifies technical settings (`architecture`, `os_version`, `min_disk`, `min_ram`),
      image handling policies (`replace_frequency`), image information (`image_source`, `image_build_date`,
      `image_original_user`), licensing information (only required for commercial OSes).
* The Image Manager helps the cloud operator to register compliant public images and to regularly
  provide updated versions of them.

#### Usage
On the manager node, run
```bash
dragon@testbed-manager(test):~ [0]$ osism manage image --help
usage: osism manage image [-h] [--no-wait] [--dry-run] [--hide] [--delete] [--latest]
                          [--cloud CLOUD] [--filter FILTER] [--images IMAGES]

options:
  -h, --help            show this help message and exit
  --no-wait             Do not wait until image management has been completed
  --dry-run             Do not perform any changes
  --hide                Hide images that should be deleted
  --delete              Delete images that should be deleted
  --latest              Only import the latest version for images of type multi
  --cloud CLOUD
                        Cloud name in clouds.yaml
  --filter FILTER
                        Filter images with a regex on their name
  --images IMAGES
                        Path to the directory containing all image files or path to single image file
```

#### Available images (as of 2025-05)
- Debian 12, Debian 11
- Ubuntu 24.04, Ubuntu 22.04, Ubuntu 22.04 Minimal
- Rocky 9, AlmaLinux 9, CentOS Stream 9
- openSUSE Leap 15.6
- Cirros 0.6.3, Cirros 0.6.2

#### Example
Example: Register AlmaLinux 9
```bash
dragon@testbed-manager(test):~ [0]$ osism manage image --cloud admin --latest --filter "AlmaLinux"`
2025-05-09 16:44:43 | INFO     | It takes a moment until task 27d41583-8bca-4518-a861-81b101fe3cf2 (image-manager) has been started and output is visible here.
2025-05-09 16:44:45 | INFO     | Processing image 'AlmaLinux 9 (20241120)'
2025-05-09 16:44:45 | INFO     | Tested URL https://swift.services.a.regiocloud.tech/swift/v1/AUTH_b182637428444b9aa302bb8d5a5a418c/openstack-images/almalinux-9/20241120-almalinux-9.qcow2: 200
2025-05-09 16:44:45 | INFO     | Importing image AlmaLinux 9 (20241120)
2025-05-09 16:44:45 | INFO     | Importing from URL https://swift.services.a.regiocloud.tech/swift/v1/AUTH_b182637428444b9aa302bb8d5a5a418c/openstack-images/almalinux-9/20241120-almalinux-9.qcow2
2025-05-09 16:44:46 | INFO     | Waiting for image to leave queued state...
2025-05-09 16:44:48 | INFO     | Waiting for import to complete...
2025-05-09 16:44:58 | INFO     | Waiting for import to complete...
[...]
2025-05-09 16:49:10 | INFO     | Waiting for import to complete...
2025-05-09 16:49:20 | INFO     | Import of 'AlmaLinux 9 (20241120)' successfully completed, reloading images
2025-05-09 16:49:20 | INFO     | Checking parameters of 'AlmaLinux 9 (20241120)'
2025-05-09 16:49:20 | INFO     | Setting internal_version = 20241120
2025-05-09 16:49:20 | INFO     | Setting image_original_user = almalinux
2025-05-09 16:49:20 | INFO     | Adding tag os:centos
2025-05-09 16:49:20 | INFO     | Setting property architecture: x86_64
2025-05-09 16:49:21 | INFO     | Setting property hw_disk_bus: scsi
2025-05-09 16:49:21 | INFO     | Setting property hw_rng_model: virtio
2025-05-09 16:49:21 | INFO     | Setting property hw_scsi_model: virtio-scsi
2025-05-09 16:49:21 | INFO     | Setting property hw_watchdog_action: reset
2025-05-09 16:49:21 | INFO     | Setting property hypervisor_type: qemu
2025-05-09 16:49:21 | INFO     | Setting property os_distro: centos
2025-05-09 16:49:21 | INFO     | Setting property os_version: 9
2025-05-09 16:49:21 | INFO     | Setting property replace_frequency: quarterly
2025-05-09 16:49:22 | INFO     | Setting property uuid_validity: last-3
2025-05-09 16:49:22 | INFO     | Setting property provided_until: none
2025-05-09 16:49:22 | INFO     | Setting property image_description: AlmaLinux 9
2025-05-09 16:49:22 | INFO     | Setting property image_name: AlmaLinux 9
2025-05-09 16:49:22 | INFO     | Setting property internal_version: 20241120
2025-05-09 16:49:22 | INFO     | Setting property image_original_user: almalinux
2025-05-09 16:49:22 | INFO     | Setting property image_source: https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2
2025-05-09 16:49:23 | INFO     | Setting property image_build_date: 2024-11-20
2025-05-09 16:49:23 | INFO     | Checking status of 'AlmaLinux 9 (20241120)'
2025-05-09 16:49:23 | INFO     | Checking visibility of 'AlmaLinux 9 (20241120)'
2025-05-09 16:49:23 | INFO     | Setting visibility of 'AlmaLinux 9 (20241120)' to 'public'
2025-05-09 16:49:23 | INFO     | Renaming AlmaLinux 9 (20241120) to AlmaLinux 9
```

Image was converted to raw to allow for Copy-on-Write usage with ceph
- This took a bit of time (4min30s) on ceph on the testbed's ceph

### Onboarding users

#### Workflow
* Create a domain
* Create first user in domain
    - For self-service capabilities (recommended): Assign domain-scoped manager role for domain
        * !NOTE! Never ever confuse `admin` privileges with `manager`. An `admin` owns your cloud.
* Create first project in domain, assign project-scoped `member` (+`load-balancer_member` + `creator`) roles
    - Optional convenience: Create first network with subnet, first router, connect to public network and subnet
    - Default security group (with egress and only internal traffic allowed) should be automatically there
* Recommendation: Automate these steps
    - Script
    - Workflow triggered from customer platform

<!--TODO Explaining domains, users, roles, ... here-->

### Creating projects (for new users)
The is a [Project Manager](https://github.com/osism/openstack-project-manager) tool,
which can be used to create domains, projects, users default networks and manage quota.
It may be used as part of the onboarding workflow for new users.
It is [well documented](https://docs.scs.community/docs/iaas/guides/operations-guide/openstack/tools/project-manager).
When using `manaage.py`, be careful to limit it to the domains that you want to affect;
it defaults to affecting all, which may be an unwelcome surprise.

Amongst the things that OpenStack project manager supports are:
* Creating a new domain with an initial project in it
* Creating a new user in that domain with member rights in the project
* Assigning quota to a project (in terms of templates or multiples of the values)
* Sharing images and services inside a domain (across multiple projects)


### Assignments Manager

#### Image registration
- Add a Debian 12 image using the openstack image manager
- Add Ubuntu 24.04

#### User onboarding
- Perform the steps using the openstack CLI (optional: python SDK)
    * Domain creation
    * First user in Domain
        - Optional: Give domain-scoped manager privileges to user
    * Create first project
    * Assign `member`, `load-balancer_member`, `creator` roles for project to user
    * Optional: Net, subnet, router settings
- Validate that the user can work
    * Assign a password, create clouds and secure.yaml and try to work as user
- Put this in a script, accepting two options to toggle domain-manager and default
  network/subnet/router creation
