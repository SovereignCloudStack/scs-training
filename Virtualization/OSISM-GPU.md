## Creating and managing GPU flavors in OSISM

### Why GPU flavors?

#### AI progress
* Public visibility with ChatGPT drove this
* Large Language Moddels (LLMs) and other Generative AI (GenAI, e.g. Image
  and Video generation), Audio transcription and translation
* Impressiveness does not always translate into real-world productivity,
  still learning how to best adopt and combine with human strengths
* Classical computing is still much better where it matches
  * Deterministic
  * Orders of magnitude more efficient

#### Compute capacity for AI
* Forms of neural networks with billions of cells translate into
  models with billions of parameters
* Massively parallel computing, mostly matrix (tensor) multiplications.
  where signals are weigthed and added
* Reasonable good fit for graphics processors (GPU = Graphical Processing
  Units) with high-bandwidth video memory and parallel processing
  (shaders that compute pixel colors in parallel)
* GPUs compete with specialized units: TPUs (Tensor Processing Units)
  and NPUs (Neural Processing Units)
  * Most considerations apply to all these accelerators alike
* Future architectures may have memory with simple arithmetic capabilities
  built-in?

### Software ecosystem
* Using GPUs for high-performance computing lead by Nvidia's CUDA
  * Almost 20 years of software ecosystem development
  * C language compiled into shader programs (or other GPU units)
* AMD, intel, Apple ... catching up
  * Own abstractions and providing CUDA-like interfaces
* Vendor-neutral standards OpenCL and Vulkan
* Higher-level interfaces (Python: tensorflow, pytorch, ...)
  typically supporting multiple GPU-brand specific backends

### Chosing compute for GenAI
* Most software developed for Nvidia CUDA
  * Market leader, expensive
* LLMs typically work well on other GPUs
  * llama.cpp, vllm, ollama
  * new features (attention, KV optimizations, ...) sometimes
    still require Nvidia

#### Raw power for LLM inference
* Prompt processing typically compute bound (TFlops of FP16 or
  FP8 or Int8 or even Int4 matrix multiplications)
* Token generation ("decoding") limited by (video) memory bandwidth
* Size of high-bandwidth memory limits the size of models
  * Quantization: Conversion of FP16 to Int8 (`Q8`) or Int4 (`Q4_K_M`)
    allows to work with up to 35B parameters on 24GB consumer/workstation
    GPUs.
* Training or finetuning requires massively more compute power.
  * Avoiding the need for finetuning by using large context windows and
    injecting knowledge as context (via RAG and embeddings)
  
### Exposing GPU (or TPU/NPU) capabilities in SCS clouds
* Accelerators can be used to create specialized platform services
  * For example LLM as a service (via OpenAI APIs)
* Focus on exposed accelerator capacity in VMs and containers for now

#### Virtualization
* Compute flavors with extra accelerator capabilities
* OpenStack: Host aggregates that allow scheduling flavors with `extra_specs`
* Easiest possibility is to pass through GPUs via PCIe-pass-through
  * VMs then have direct access to the PCI device, like on Bare Metal
  * No virtualization overhead, no changes to software and drivers
  * This prevents live-migration
  * Sharing GPUs only possible via static compartmentalization and only
    for GPUs that support MIG (Nvidia) or SR-IOV (AMD)
    * Sometimes called vGPU though it's not really virtualized ...
    * Beware of licensing limitations (MIG)
* Virtualizing GPUs is possible
  * Dynamic sharing and possibility of live migration
  * Driver support is limited (virtio-gpu/virgl/venus)
  * Significant performance impact
  * Typically used for virtual desktops (VDI)
  * Not used here
* SCS flavors: `SCS-16V-64-GNa-84-48` is a SCS compute flavor with
  16vCPUs, 64GiB RAM with a PCI-Pass-Through instance Nvidia
  Ampere with 84 Streaming Multiprocessors and 48GB of video memory
  (this example uses an Nvidia A40).

#### OpenStack / Linux implementation (manual)
* Prevent host system (compute nodes) from attaching GPU driver (but attach vfio-pci)
  * Load `vfio_pci` in initrd:
    `/etc/initramfs-rools/modules`: `vfio_pci ids=xxxx:yyyy`
  * Pass options to vfio-pci:
    `/etc/modprobe.d/vfio.conf`: `options vfio-pci ids=xxxx:yyyy`
  * Optionally blacklist GPU driver on host
    `/etc/modprobe.d/blacklist-gpu.conf`: `blacklist DRIVERNAME`
    Note that this won't work if host system needs this driver for another GPU.
* Use `lspci -nn` to identify correct PCI device IDs
* Enable IOMMU: BIOS and `intel_iommu=on` or `amd_iommu=on` kernel parameters
  * Without IOMMU, PCI pass-through is insecure!
* Nova configuration `/etc/kolla/nova-compute/nova.conf`
  ```ini
  [pci]
  device_spec = pci_gpu:vendor_id=xxxx;product_id=yyyy
  ```
* Create host aggregates for compute hosts
  ```shell
  openstack aggregate create gpu_nodes_Na-84-48
  openstack aggregate add host gpu_nodes_Na-84-48 HOSTID1 HOSTID2 ...
  openstack aggregate set --property has_gpu_a40=true gpu_nodes-Na-84-48
  ```
* Create flavors using the PCI devices
  ```shell
  openstack flavor set --property pci_passthrough:alias=pci_gpu SCS-16V-64-GNa-84-48
  openstack flavor set --property aggregate_instance_extra_specs:has_gpu_a40=true SCS-16V-64-GNa-84-48
  ```
* Optional (not recommended): Images requiring flavor specs
  ```shell
  openstack image set --property aggregate_instance_extra_specs:has_gpu_a40=true "Ubuntu-26.04 Nvidia A40"
  ```

#### Perform this configuratiob via OSISM (kolla-ansible)
TBD


#### Containers
* Use worker nodes with GPUs
