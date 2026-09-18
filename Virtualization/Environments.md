## Working with multiple Environments

### Production, Reference and Test environments
* As a cloud provider you may run one or several cloud environments
    - In a typical multi-region setup, the regions are rather independent from each other,
      except for user management
* Your customers typically expect very reliable cloud services
    - Unavailability is very bad, losing data is worse
* Cloud environments must be changed often
    - E.g. for deploying security fixes, for increasing capacity, for deploying upgrades, etc.
* In order to do changes with confidence, you need to test them
    - Validating that the changes are good
    - Validating that your roll out procedures work reliably
    - Validating that you can roll back in case of trouble
* Testing is typically done in a reference environment (sometimes also called staging or preproduction)
    - A staging environment has the same configuration as your production plus the changes under test
* You may need environments where you can try out wilder things and diverge more. We call them
    test or development environments.

### Options for your environments
* You may want your reference environment and especially your development environments to be
  much smaller than production.
    - This is a question of cost
* You may opt to set up the reference with old hardware or make it significantly smaller than
  your production.
* Another option for reference env might be a testbed setup; for development a Cloud-in-a-Box
  might be good enough.

#### Testbed
* Testbed is a fully automated multi-node setup where the nodes are VMs rather than physical
  machines. This makes automation *a lot* easier.
    - This makes recreating it straight forward, so you may be better able to always have it working.
    - To be fully automated, a number of the settings are predefined, which might not match
      your production settings and thus prevent it from being a good reference for your
      production.
    - You could adjust this in your fork of the configuration repository or be very careful
      in assessing what test results do well represent your production and which ones do not.
* The default setup for a testbed uses 7 nodes:
    - 1 Manager node (SCS-4V-16-50)
    * 3 Control and Network node (SCS-8V-32-50)
    * 3 Compute and Storage nodes (SCS-8V-32-50)
    * 3x3 = 9 Volumes (for OSDs) 20GiB each
* Testbed has basic HA properties
* It's not hardened for production and has predefined passwords
* Performance of VMs will suck unless you have enabled nested virtualization
* We use it all the time for our CI testing
* See instructions at <https://osism.tech/docs/deployment-examples/testbed/>

#### Cloud-in-a-Box
* Cloud-in-a-Box is a single node deployment of SCS IaaS
    - It can be deployed in a virtual machine (use SCSI disk driver!)
* It has fairly minimal requirements:
    - 32GiB RAM, 4 cores, 400GB disk space, disable k3s and OpenSearch for small setups
    - A 8 core 96GiB machine with 2 4TB NVMes works really rather well and survives quite some workloads
        - Keep 16GiB free for the host, more if k3s and OpenSearch are running
* Fully automated installation process with very limited adaptability
* Uses self-signed certificates and predefined passwords.
* Do not expose this to the internet! Do not ever put valuable data there.
* Really nice test/development environment
* See instructions at <https://osism.tech/docs/deployment-examples/cloud-in-a-box/>

### Assignments
* Review inventory on a testbed setup
* Review a CiaB configuration
