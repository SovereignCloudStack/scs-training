## Adding flavors with GPU support to SCS OpenStack (OSISM)

Overview:

* Modes: Pass-through vs. virtualized GPUs
* Ensure correct host configuration (driver)
* Host aggregates
* Flavors
* Automation via OSISM configuration

### Virtualized versus PCI pass-through

* Linux/KVM can give direct access to PCIe hardware to VMs
  (PCI-Pass-Through).
    - This requires an IOMMU, which all modern (x86) CPUs have,
      but may need to be enabled in the BIOS/uEFI setup.
    - Without an IOMMU, this would be highly insecure, as the VM
      user could initiate DMA to memory of host or other domains.
    - This works with the same drivers in the VM that would be
      used on bare metal otherwise.
    - No significant overhead.
    - GPUs can not be shared this way.
* SR-IOV/MIG
    - Some hardware allows partitioning of the GPU into several
      pieces via management tooling.
    - The pieces will then be exposed as separate PCI devices which
      can be individually passed through to VMs.
    - Looks like bare metal again to the VM drivers.
    - nVidia calls this Multi-Instance-Graphics (MIG), only supported
      on some models, may require additional licensing fees.
    - Supported AMD models use normal SR-IOV mechanisms.
    - Some people call this GPU virtualization, which is misleading.
* GPU virtualization
    - GPU is handled by a driver on the host.
    - A virtualized GPU can be exposed via virtio-gl to VMs.
    - Does not require an enabled IOMMU.
    - Dynamic sharing is possible.
    - There is a virtualization overhead.
    - Driver support is challenging.
    - Has some popularity in VDI (virtual desktop infrastructure)
      setups, not much in HPC or AI applications.

__We recommend using the hardware pass-through mechanism, with or without
partitioning (MIG/SR-IOV) and the rest of this chapter assumes PCI-Pass-Through.__

### Host (Hypervisor) preparation
* Ensure the IOMMU is enabled in the BIOS.
    - Some mainboards need to also enable ACS (Access Control Services) to
      group PCI devices in separate IOMMU DMA domains, so the GPU can be isolated
      in its own PCI domain.
* Pass `amd_iommu_amd=1` or `intel_iommu=1` and `iommu=pt` (for both) to the
  kernel command line (typically in grub configuration), depending on the CPU
  vendor.
* We need to avoid a GPU driver on the host attaching to the GPU,
  which would prevent it from being passed through.
* Instead the the vfio-pci needs to take ownership so it can be handed out
  to a VM. Best to do this at boot-time through a kernel option as well.
  `vfio-pci.ids=10de:1b81,10de:10f0` (replace this with the real PCI IDs
  from `lspci -nn`. Note that modern GPUs may consist of several PCI devices,
  e.g. an audio device along with the graphics device. It is least confusing
  to VM drivers if the devices are passed-through together, so reserve them
  all.
    - You can unbind a driver at runtime by invoking the right unbind
      command in sysfs, so this can be done without rebooting (unlike
      IOMMU enablement).
    - `lspci -k` shows what kernel drivers have attached to the hardware.
* In libvirt, we'd reference a GPU on pci 03:00.0 and 03:00.1 so:
```xml
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <source>
        <address domain='0x0000' bus='0x03' slot='0x00' function='0x0'/>
      </source>
      <address type='pci' domain='0x0000' bus='0x05' slot='0x00' function='0x0'/>
    </hostdev>
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <source>
        <address domain='0x0000' bus='0x03' slot='0x00' function='0x1'/>
      </source>
      <address type='pci' domain='0x0000' bus='0x06' slot='0x00' function='0x0'/>
    </hostdev>
```
* Note that AMD GPUs need atomic completion, which does not work if you
  pass an audio device belonging to the GPU as a function of a multi-function
  device, even if this the topology on the host. Rather pass as separate PCI
  devices.
* See below for OpenStack.

### Host aggregates with GPUs
* We'll define flavors which will require a the GPU.
* The nova-scheduler can be told that certain hosts have certain
  GPU capabilities by adding them to an host aggregate with the appropriate
  property.
* This is done by a configuration line in `nova.conf` for the `nova-compute` service.
  ```ini
  [pci]
  alias = nvidia_a10:1,10de:2236,10de:228b
  ```
    - This example creates an alias `nvidia_a10` for allocating `1` resource group with
      these two PCI IDs.
* All hosts that have this equipment should be added to a host aggregate:
  ```shell
  openstack aggregate create nvidia_a10_nodes
  openstack aggregate add host nvidia_a10_nodes <compute-node-hostname>
  openstack aggregate set --property gpu_model=nvidia_a10 nvidia_a10_nodes
  ```
* The placement service will get usage reports and report it to the nova-scheduler
  for the scheduling decisions.

### Flavor registration
* The SCS standard has a [naming scheme](https://docs.scs.community/standards/scs-0100-v3-flavor-naming)
  for compute flavors to avoid needless divergence
  of flavor naming causing challenges.
* The flavor naming scheme also [covers GPUs](https://docs.scs.community/standards/scs-0100-v3-flavor-naming#optional-gpu-support),
  please see the [tables](https://docs.scs.community/standards/scs-0100-w1-flavor-naming-implementation-testing#gpu-table)
  in the implementation notes for it.
* So we need to first determine the correct name for the flavors with
  GPU support, the [flavor name generator](https://flavors.scs.community/) can help with it.
* Register flavors with the GPUs:
  ```shell
  openstack flavor create --ram 32768 --vcpus 8 SCS-8V-32_GNa-72-24
  openstack flavor set --property pci_passthrough:alias=nvidia_a10:1 SCS-8V-32_GNa-72-24
  openstack flavor set --property aggregate_instance_extra_specs:gpu_model=nvidia_a10 SCS-8V-32_GNa-72-24
  ```

### Doing it all via the configuration repository
* Create a group in inventory (`inventory/20-roles`)
  ```ini
  [nividia-a10-nodes]
  nvnode01
  nvnode02
  ```
  You can now specify `hosts: nvidia-a10-nodes` in playbooks to run tasks there.
* Here's the playbook to prepare the hosts:
```yaml
---
- name: Prepare Compute Nodes for GPU Passthrough
  hosts: nvidia-a10-nodes
  become: true
  vars:
    # Change to 'amd_iommu=on' if using AMD CPUs
    iommu_param: "intel_iommu=on iommu=pt"
    pci_alias_config: |
      [pci]
      alias = nvidia_a10:1,10de:2236,10de:228b

  tasks:
    - name: Update GRUB command line for IOMMU
      lineinfile:
        path: /etc/default/grub
        regexp: '^GRUB_CMDLINE_LINUX_DEFAULT='
        line: 'GRUB_CMDLINE_LINUX_DEFAULT="{{ iommu_param }} %s"'
        backrefs: yes
      register: grub_updated

    - name: Regenerate GRUB configuration
      command: update-grub
      when: grub_updated.changed

    - name: Create Kolla directory for nova config
      file:
        path: /etc/kolla/nova-compute/
        state: directory
        mode: '0755'

    - name: Inject PCI alias into Kolla nova.conf
      blockinfile:
        path: /etc/kolla/nova-compute/nova.conf
        block: "{{ pci_alias_config }}"
        create: yes
        mode: '0644'
      register: kolla_config_updated

    - name: Reboot node to apply kernel changes
      reboot:
        msg: "Rebooting to apply IOMMU kernel parameters"
      when: grub_updated.changed or kolla_config_updated.changed

    - name: Final Note
      debug:
        msg: "Nodes are ready. Please run 'kolla-ansible -i inventory reconfigure' to apply nova changes."
```
* Host aggregate registration and flavor creation
```yaml
---
- name: Configure OpenStack GPU Resources
  hosts: localhost
  connection: local
  become: false
  vars:
    # Configuration Variables
    aggregate_name: "nvidia-a10-nodes"
    aggregate_metadata:
      gpu_model: "nvidia_a10"

    flavor_name: "SCS-8V-32_GNa-72-24"
    flavor_ram: 32768
    flavor_vcpus: 8

    pci_alias: "nvidia_a10:1"
    aggregate_spec: "aggregate_instance_extra_specs:gpu_model=nvidia_a10"

  tasks:
    - name: Create Host Aggregate
      openstack.cloud.os_host_aggregate:
        name: "{{ aggregate_name }}"
        state: present

    - name: Set Metadata on Host Aggregate
      openstack.cloud.os_host_aggregate_metadata:
        name: "{{ aggregate_name }}"
        metadata: "{{ aggregate_metadata }}"
        state: present

    - name: Create GPU Flavor
      openstack.cloud.os_flavor:
        name: "{{ flavor_name }}"
        ram: "{{ flavor_ram }}"
        vcpus: "{{ flavor_vcpus }}"
        state: present

    - name: Add PCI Passthrough Extra Spec to Flavor
      openstack.cloud.os_flavor_extra_specs:
        name: "{{ flavor_name }}"
        key: "pci_passthrough:alias"
        value: "{{ pci_alias }}"
        state: present

    - name: Add Aggregate Requirement Extra Spec to Flavor
      openstack.cloud.os_flavor_extra_specs:
        name: "{{ flavor_name }}"
        key: "{{ aggregate_spec }}"
        value: "true" # This matches the 'true' logic in the key presence
        state: present
```

### Validation and testing
* `openstack resource provider list`
  `for host in ...; do openstack resource provider $host show ; done`
* Start VM using the flavor.
* `lspci -k` should show the GPU and the driver attached to it.

