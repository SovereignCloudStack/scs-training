# SCS Cluster Stacks Course

## Course Overview

This course explores the concept of [Cluster Stacks](https://docs.scs.community/docs/container/components/cluster-stacks/components/cluster-stacks/overview) within the
[Sovereign Cloud Stack (SCS)](https://www.sovereigncloudstack.org/) ecosystem.
We'll break down their architecture, explain how they standardize Kubernetes
cluster life-cycles, and dive deep into their deployment, configuration, and
evolution. Hands-on examples will guide learners through practical examples
of common scenarios using local [KinD](https://kind.sigs.k8s.io/) clusters.

## Introduction

- Course objectives
  - Explain the motivation behind another layer of abstraction on top
    of Kubernetes clusters themselves
  - Describe the role of Cluster Stacks in the SCS ecosystem and what
    problems are they solving
  - Provide hands-on examples using local KinD clusters to better accommodate
    learners with the abstract concepts used
- Technologies used
  - [Kubernetes in Docker (KinD)](https://kind.sigs.k8s.io/)
  - [Cluster API](https://cluster-api.sigs.k8s.io/)
  - [Helm](https://helm.sh/)

## What Are Cluster Stacks?

Cluster Stacks is a framework and a set of reference implementations
for defining, and managing Kubernetes clusters,
often across cloud providers or infrastructure environments. The term is
inspired by the idea of application stacks, but at the infrastructure layer:
instead of just defining applications that run on Kubernetes, a cluster stack
defines the actual Kubernetes cluster itself, its configuration, underlying
infrastructure, and operational policies.

Managing Kubernetes clusters at scale, especially in multi-environment,
multi-cloud, or hybrid-cloud setups, can be error-prone, repetitive, and
inconsistent when done manually or with loosely connected tools. Kubernetes
project [Cluster API (CAPI)](https://cluster-api.sigs.k8s.io/) provides
tooling to simplify provisioning, upgrading, and operating multiple Kubernetes
clusters. While Kubernetes itself provides a way to declaratively define how to
manage application workloads and resources using a cluster paradigm, CAPI
tools allow to define the operation of the cluster itself in similar manner.

- Ensure consistency across dev/staging/prod environments
- Enable GitOps and Infrastructure as Code (IaC) workflows
- Support multi-cluster, multi-cloud strategies
- Reduce operational overhead and human error

CAPI provides these benefits using "managing Kubernetes with Kubernetes"
paradigm, using a bootstrap/management Kubernetes cluster in which controllers
managing target workload cluster run reconciling the target cluster to the
desired state defined declaratively as custom resources. CAPI doesn't provide
all the services needed for a fully functional Kubernetes cluster - prominently
Container Network Interface (CNI) plugin, which handles pod networking in the
target cluster is left for the operator to install separately.

Cluster Stacks are a concept that combines all the important components of a
Kubernetes cluster

- Configuration of Kubernetes (e.g. Kubeadm)
- Addons (e.g. CNI)

These main elements are combined in Cluster Stacks and tested as a whole,
providing a directly usable distribution for quick and safe creation or upgrade
of production grade Kubernetes clusters. A Cluster Stack is released only if
everything works together, an upgrade from the previous version is possible
and its function thus is ensured. In addition, the SCS Cluster Stack Operator
simplifies the use of Cluster Stacks.

## Cluster Stacks in the SCS Ecosystem

Cluster Stacks are a core concept in the Sovereign Cloud Stack (SCS) ecosystem.
They define how Kubernetes clusters are composed, deployed, and managed in a
modular and reproducible way.

SCS is built on the principle of digital sovereignty — the ability to control
and operate cloud infrastructure without relying on proprietary or opaque
technologies. Cluster Stacks contribute to this goal by:

- Standardizing cluster deployments - providing a clear, consistent way to
  define Kubernetes clusters using open, declarative configurations
- Enabling self-determination where organizations can run clusters on their
  own infrastructure or trusted platforms, maintaining full control
- Reducing complexity and simplifying the process of deploying clusters by
  encapsulating best practices into reusable building blocks

It builds on established Kubernetes community projects, especially Cluster API
(CAPI), which provides a Kubernetes-native way to manage cluster life-cycle
operations (create, scale, upgrade, delete).

- Using Cluster API CRDs (Custom Resource Definitions) for defining
  infrastructure and cluster configurations
- Supporting CAPI-compatible providers (e.g. OpenStack, Bare Metal)
- Encouraging upstream compatibility, reducing duplication and improving
  long-term sustainability

## Architecture Overview

[SCS Cluster Stacks overview](https://docs.scs.community/docs/container/components/cluster-stacks/components/cluster-stacks/overview/)

Cluster Stacks is packaging components essential for setting up, maintaining
and operating a Kubernetes cluster. They can be divided into two distinct
layers

- cluster-class
- cluster-addons

[ClusterClass](https://cluster-api.sigs.k8s.io/tasks/experimental-features/cluster-class/)
is a feature of CAPI which defines the desired configuration and properties of
a Kubernetes cluster as a template - a customizable blueprint.

Cluster addons are core components or services required for the Kubernetes
cluster to function correctly and efficiently. These are not user-facing
applications but rather foundational services critical to the operation and
management of a Kubernetes cluster. They're usually installed and configured
after the cluster infrastructure has been provisioned and before the cluster
is ready to serve workloads.

- Container Network Interfaces (CNI) - plugins that facilitate container
  networking
- Cloud Controller Manager (CCM) - a control plane component that embeds the
  cloud-specific control logic and manages the communication with the
  underlying cloud services
- Konnectivity service is a network proxy that enables connectivity from the
  control plane to nodes and vice versa
- Metrics Server - cluster-wide aggregator of resource usage data

Any change in any of the layers triggers a version bump in the cluster class,
hence the cluster stack. The cluster stack version doesn't simply mirror the
versions of its components, but rather, it reflects the "version of change".
In essence, the cluster stack version is a reflection of the state of the
entire stack as a whole at a particular point in time.

![Cluster Stacks architecture](https://raw.githubusercontent.com/SovereignCloudStack/cluster-stacks-demo/refs/heads/main/hack/images/syself-cluster-stacks-web.png)

## Components and Responsibilities

Cluster Stacks extend CAPI as the foundational tool which provides declarative
way to manage the life-cycle of Kubernetes clusters. CAPI breaks
responsibilities across several core controller types, each handling
a distinct layer of concern. It is responsible for defining the core
cluster objects and their reconciliation logic.

- Cluster - Represents a logical Kubernetes cluster
- Machine - Represents a single Kubernetes node.
- MachineSet, MachineDeployment: Provide scalable sets of Machine objects
  (like ReplicaSet / Deployment in apps)

Controllers reconcile cluster and machine topology and ensure the right number
and type of machines exist.

Cluster Stack Operator (CSO) implements all the steps needed for the use of a
specific cluster stack implementation. It has to be installed in the management
cluster and extends the functionality of CAPI operators.

Infrastructure Providers (e.g., CAPO for OpenStack, CAPD for Docker)
are responsible for provisioning the underlying infrastructure
needed to host Kubernetes clusters.

- Create infrastructure components (VMs, networks, load balancers, disks)
- Reconcile InfrastructureCluster and InfrastructureMachine resources
  (e.g., OpenStackCluster, OpenStackMachine).
- Run in the management cluster, but act on infrastructure outside of it

The structure of the [SCS cluster-stacks repository](https://github.com/SovereignCloudStack/cluster-stacks)
is specifically designed to handle multiple providers, multiple cluster stacks
per provider, and multiple Kubernetes versions per cluster stack. This
organized structure allows to effectively manage, develop, and maintain
multiple cluster stacks across various Kubernetes versions and providers, all
in a single repository.

- Each IaaS Provider has a directory under providers
- Each IaaS Provider can have multiple cluster stack implementations
- Each cluster stack supports multiple Kubernetes major and minor versions

```
providers/
└── <provider_name>/
    └── <cluster_stack_name>/
        └── <k8s_major_minor_version>/
```

## Quickstart Guide - Docker Infrastructure

[SCS Cluster Stacks Quickstart guide](https://docs.scs.community/docs/container/components/cluster-stacks/components/cluster-stacks/providers/openstack/quickstart)

- Prerequisites (KinD, Helm, kubectl, Clusterctl)
  - [KinD](https://kind.sigs.k8s.io/)
  - [Helm](https://helm.sh/)
  - [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
  - [jq](https://jqlang.github.io/jq/)

- [Install clusterctl](https://cluster-api.sigs.k8s.io/user/quick-start.html#install-clusterctl)
  ```bash
  curl -L https://github.com/kubernetes-sigs/cluster-api/releases/\
    download/v1.9.7/clusterctl-linux-amd64 -o clusterctl
  ```

- Bootstrap a management cluster with KinD
  ```bash
  kind create cluster --config=kind/kind-cluster-with-extramounts.yaml
  ```

- Transform it into a management cluster with `clusterctl`
  ```bash
  export CLUSTER_TOPOLOGY=true
  export EXP_CLUSTER_RESOURCE_SET=true
  export EXP_RUNTIME_SDK=true
  clusterctl init --infrastructure docker
  ```

- Install Cluster Stack Operator (CSO)
  ```bash
  helm upgrade -i cso -n cso-system --create-namespace \
  oci://registry.scs.community/cluster-stacks/cso \
  --set clusterStackVariables.ociRepository=registry.scs.community/kaas/cluster-stacks
  ```
  ```bash
  kubectl create namespace cluster
  ```

- Create a basic `clusterstack.yaml` file
  ```yaml
  apiVersion: clusterstack.x-k8s.io/v1alpha1
  kind: ClusterStack
  metadata:
    name: docker
    namespace: cluster
  spec:
    provider: docker
    name: scs
    kubernetesVersion: "1.30"
    channel: custom
    autoSubscribe: false
    noProvider: true
    versions:
      - v0-sha.rwvgrna
  ```

- Apply `clusterstack.yaml`
  ```bash
  kubectl apply -f clusterstacks/clusterstack.yaml
  ```

- Create a `cluster.yaml` file
  ```yaml
  apiVersion: cluster.x-k8s.io/v1beta1
  kind: Cluster
  metadata:
    name: docker-testcluster
    namespace: cluster
    labels:
      managed-secret: cloud-config
  spec:
    topology:
      class: docker-scs-1-30-v0-sha.rwvgrna
      controlPlane:
        replicas: 1
      version: v1.30.10
      workers:
        machineDeployments:
          - class: default-worker
            name: md-0
            replicas: 1
  ```

- Apply `cluster.yaml`
  ```bash
  kubectl apply -f clusterstacks/cluster.yaml
  ```

- Get kubeconfig and view cluster node
  ```bash
  clusterctl get kubeconfig -n cluster docker-testcluster > /tmp/kubeconfig
  ```
  ```bash
  kubectl get nodes --kubeconfig /tmp/kubeconfig
  ```

- The clusterstack from example installs cilium CNI in the cluster

### Assignments

1. Create a management cluster, install needed infrastructure and create a
  workload cluster using cluster stack version 1.30 for the proper provider
2. Verify workload cluster properly running
3. Deploy a registry service (Harbor) from [Registry training](../registry/registry.md#quickstart-guide)

## Quickstart Guide - OpenStack Infrastructure

Note: There is the repository [scs-training-kaas-scripts](https://github.com/SovereignCloudStack/scs-training-kaas-scripts)
with bash scripts that perform the steps in this quick start guide. Ideally, you have a Linux VM
with some tools installed, use [00-bootstrap-vm-cs.sh](https://github.com/SovereignCloudStack/scs-training-kaas-scripts/blob/main/00-bootstrap-vm-cs.sh) to install tooling.

- Bootstrap a management cluster with KinD ([01-kind-cluster.sh](https://github.com/SovereignCloudStack/scs-training-kaas-scripts/blob/main/01-kind-cluster.sh))
  ```bash
  kind create cluster
  ```

- Transform it into a management cluster with `clusterctl` ([02-deploy-capi.sh](https://github.com/SovereignCloudStack/scs-training-kaas-scripts/blob/main/02-deploy-capi.sh))
  ```bash
  export CLUSTER_TOPOLOGY=true
  export EXP_CLUSTER_RESOURCE_SET=true
  export EXP_RUNTIME_SDK=true
  kubectl apply -f https://github.com/k-orc/openstack-resource-controller/\
    releases/latest/download/install.yaml
  clusterctl init --infrastructure openstack
  
  kubectl -n capi-system rollout status deployment
  kubectl -n capo-system rollout status deployment
  ```

- Create values.yaml for CSO ([03-deploy-cso.sh](https://github.com/SovereignCloudStack/scs-training-kaas-scripts/blob/main/03-deploy-cso.sh))
  ```bash
  cat > values.yaml <<EOF
  clusterStackVariables:
    ociRepository: registry.scs.community/kaas/cluster-stacks
  controllerManager:
    rbac:
      additionalRules:
        - apiGroups:
            - "openstack.k-orc.cloud"
          resources:
            - "images"
          verbs:
            - create
            - delete
            - get
            - list
            - patch
            - update
            - watch
  EOF
  ```

- Install Cluster Stack Operator (CSO) with above values
  ```bash
  helm upgrade -i cso -n cso-system --create-namespace \
  oci://registry.scs.community/cluster-stacks/cso \
  --values values.yaml
  ```

- Create cluster namespace ([04-cloud-secret.sh](https://github.com/SovereignCloudStack/scs-training-kaas-scripts/blob/main/04-cloud-secret.sh))
  ```bash
  kubectl create namespace cluster
  ```

- Create cloud secret using csp-helper chart (Note: This is done differently in the scripts, which do not use the
helm charts; 04-cloud-secret.sh creates the secrets for the CAPO, the workload cluster secrets are created later
per cluster in 07-cluster-secret.sh.)

  You need to run the csp-helper chart always. You always need to specify the path to your `clouds.yaml`.
  The `clouds.yaml` should contain also the secrets that you normally split off into `secure.yaml`.

  If you choose to use clouds.yaml with application credentials (`auth_type: v3applicationcredential`), it is the preferred and more secure option.
  If you opt to use clouds.yaml with password authentication (`auth_type: v3password`), that is also acceptable, but:
  - Ensure that `project_id` is set, `project_name` works only for CAPO, not for OCCM!
  - Using `project_id` guarantees that both CAPO and OCCM function correctly with `v3password` authentication.

  If the OpenStack API is secured with a certificate issued by a custom CA, include `--set cacert="$(cat /path/to/cacert)"` in your Helm command.
  There is no need to update `clouds.yaml` with the custom CA, passing the `--set cacert=...` parameter is sufficient. 
  The openstack-csp-helper ensures that the CA certificate is available to both CAPO and OCCM.

  If you want to use OVN provider OpenStack Octavia for the Workload LBs set `--set octavia_ovn=true` in the helm command.

  ```bash
  helm upgrade -i openstack-secrets -n cluster --create-namespace \
    https://github.com/SovereignCloudStack/openstack-csp-helper/releases/\
    latest/download/openstack-csp-helper.tgz -f /path/to/cloud.yaml \
    --set cacert="$(cat /path/to/cacert)" --set octavia_ovn=true
  ```

- Deploy ClusterStack ([05-deploy-cstack.sh](https://github.com/SovereignCloudStack/scs-training-kaas-scripts/blob/main/05-deploy-cstack.sh))
  ```bash
  cat <<EOF | kubectl apply -f -
  apiVersion: clusterstack.x-k8s.io/v1alpha1
  kind: ClusterStack
  metadata:
    name: openstack
    namespace: cluster
  spec:
    provider: openstack
    name: scs
    kubernetesVersion: "1.32"
    channel: custom
    autoSubscribe: false
    noProvider: true
    versions:
      - v0-sha.lvlvyfw
  EOF
  ```

- Check if ClusterClass exists ([06-wait-clusterclass.sh](https://github.com/SovereignCloudStack/scs-training-kaas-scripts/blob/main/06-wait-clusterclass.sh))
  ```bash
  kubectl get clusterclass -n cluster
  ```

- Check whether the image already exists in the OpenStack project or if the OpenStack Resource Controller (ORC) is currently uploading it
- For demo purposes, it's a good idea to have the image uploaded in advance to avoid delays

- Note: Under normal conditions, cluster creation can proceed even if the image is not yet available. However, we observed a situation where the OpenStackServer resource entered an error state due to the not yet ready image, causing the cluster creation process to stacked.
  Manually deleting the affected OpenStackServer resource and restarting the CAPO controller (`kubectl delete po -l control-plane=capo-controller-manager -n capo-system`) resolved the issue. Please be aware of this behavior, it requires further investigation.

  ```bash
  kubectl get image -n cluster
  ```

- New scripts only: Create per-cluster secret: [07-cluster-secret.sh](https://github.com/SovereignCloudStack/scs-training-kaas-scripts/blob/main/07-cluster-secret.sh)

- Create cluster ([08-create-cluster.sh](https://github.com/SovereignCloudStack/scs-training-kaas-scripts/blob/main/08-create-cluster.sh))

  ```bash
  cat <<EOF | kubectl apply -f -
  apiVersion: cluster.x-k8s.io/v1beta1
  kind: Cluster
  metadata:
    name: my-cluster
    namespace: cluster
    labels:
      managed-secret: cloud-config
  spec:
    clusterNetwork:
      pods:
        cidrBlocks:
        - "172.16.0.0/16"
      serviceDomain: cluster.local
      services:
        cidrBlocks:
        - "10.96.0.0/12"
    topology:
      class: openstack-scs-1-32-v0-sha.lvlvyfw
      controlPlane:
        replicas: 1
      version: v1.32.1
      # If you want to use octavia-ovn provider for Kubernetes API
      variables:
        - name: apiserver_loadbalancer
          value: "octavia-ovn"
      workers:
        machineDeployments:
          - class: default-worker
            name: md-0
            replicas: 1
  EOF
  ```

- Validate the cluster health ([09-wait-cluster.sh](https://github.com/SovereignCloudStack/scs-training-kaas-scripts/blob/main/09-wait-cluster.sh))

  ```bash
  clusterctl describe cluster my-cluster -n cluster
  ```

- Get kubeconfig and play with cluster

  ```bash
  clusterctl get kubeconfig -n cluster my-cluster > ~/.kube/cluster.my-cluster.yaml
  kubectl --kubeconfig ~/.kube/cluster.my-cluster.yaml get nodes -o wide
  kubectl --kubeconfig ~/.kube/cluster.my-cluster.yaml get pods -A
  ```

- You can use the following example to deploy workload (nginx server with html page) with load balancer ([21-deploy-kube-dashboard.sh](https://github.com/SovereignCloudStack/scs-training-kaas-scripts/blob/main/21-deploy-kube-dashboard.sh))

  ```bash
  kubectl --kubeconfig ~/.kube/cluster.my-cluster.yaml apply \
    -f ./clusterstacks/test-workload-lb.yaml
  ```

  Get the IP address of the LB (from its status) and try to reach it, e.g. `curl <LB IP address>`

- Cleanup ([56-cleanup-cluster.sh](https://github.com/SovereignCloudStack/scs-training-kaas-scripts/blob/main/56-cleanup-cluster.sh) and [57-delete-cluster.sh](https://github.com/SovereignCloudStack/scs-training-kaas-scripts/blob/main/57-delete-cluster.sh))

  Tear down both the workload cluster and the bootstrap cluster

  Note: Do not forget to cleanup workload LB before you tear down the workload cluster, e.g. `kubectl --kubeconfig ~/.kube/cluster.my-cluster.yaml delete -f ./clusterstacks/test-workload-lb.yaml`

  LB blocks the workload cluster deletion if it is not removed beforehand.

  ```bash
  kubectl delete cluster -n cluster my-cluster
  kind delete cluster
  ```

## Configuration and Customization

- Cluster stacks can be configured with env variables,
  [Envsubst](https://github.com/drone/envsubst), is required to expand
  environment variables specified in CSO

  ```bash
  GOBIN=/tmp go install github.com/drone/envsubst/v2/cmd/envsubst@latest
  ```

- User can configure their own repository as a clusterstack source, e.g.

  ```bash
  export GIT_PROVIDER_B64=Z2l0aHVi  # github
  export GIT_ORG_NAME_B64=U292ZXJlaWduQ2xvdWRTdGFjaw== # SovereignCloudStack
  export GIT_REPOSITORY_NAME_B64=Y2x1c3Rlci1zdGFja3M=  # cluster-stacks
  export GIT_ACCESS_TOKEN_B64=$(echo -n '<my-personal-access-token>' | base64 -w0)
  ```

- To use custom OCI registry, e.g.

  ```bash
  # echo -n "registry.scs.community" | base64 -w0
  export OCI_REGISTRY_B64=cmVnaXN0cnkuc2NzLmNvbW11bml0eQ==
  # registry.scs.community/kaas/cluster-stacks
  export OCI_REPOSITORY_B64=cmVnaXN0cnkuc2NzLmNvbW11bml0eS9rYWFzL2NsdXN0ZXItc3RhY2tzCg==
  ```

- Deploy CSO. The variables will be replaced in the file

  ```yaml
  # Get the latest CSO release version and apply CSO manifests
  curl -sSL https://github.com/SovereignCloudStack/cluster-stack-operator/releases/latest/\
    download/cso-infrastructure-components.yaml | /tmp/envsubst | kubectl apply -f -
  ```

- Cluster can be further configured by `spec.topology.variables` field , e.g.

  ```yaml
  apiVersion: cluster.x-k8s.io/v1beta1
  kind: Cluster
  metadata:
    name:
    namespace:
    labels:
      managed-secret: cloud-config
  spec:
    clusterNetwork:
      pods:
        cidrBlocks:
          - 192.168.0.0/16
      serviceDomain: cluster.local
      services:
        cidrBlocks:
          - 10.96.0.0/12
    topology:
      variables: # <-- variables can be set here
        - name: controller_flavor
          value: "SCS-4V-8-20"
        - name: worker_flavor
          value: "SCS-4V-8-20"
        - name: external_id
          value: "ebfe5546-f09f-4f42-ab54-094e457d42ec"
      class: openstack-alpha-1-29-v2
      controlPlane:
        replicas: 2
      version: v1.29.3
      workers:
        machineDeployments:
          - class: openstack-alpha-1-29-v2
            failureDomain: nova
            name: openstack-alpha-1-29-v2
            replicas: 4
  ```

For more details, see available variables [table](https://docs.scs.community/docs/container/components/cluster-stacks/components/cluster-stacks/providers/openstack/configuration#available-variables)

### Assignments

1. Use environment variables to set own registry from [Quickstart guide assignments](#quickstart-guide---docker-infrastructure)
   as source
2. Push needed images
3. Create a workload cluster using own registry as a source

## GPU support in Cluster-Stacks

This assumes you have an OpenStack cloud that has GPU capabilities and has
flavors with GPU support such as `SCS-8V-32_GNa-72-24`. (This examples is a
flavor with 8vCPUs, 32GiB of RAM and a pass-through nVidia Ampere with 72
Streaming Multiprocessors and 24GiB of VRAM -- an nVidia A10.)

You need node images that have the GPU drivers installed.
This can be done by using the generic node images and injecting additioal
software during the worker node deployment or by building specialized
images. Please get in touch with the SCS team.

You also need a device plugin that reports the GPU capabilities to the
kubernetes control plane, for nVidia, this is the
[NVIDIA Device Plugin](https://github.com/NVIDIA/k8s-device-plugin). The
nodes now have custom properties that get reported via `kubectl describe node <nodename>`.

The workload can now request GPU resources
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-workload
spec:
  containers:
  - name: cuda-container
    image: nvidia/cuda:12.0-base
    resources:
      limits:
        nvidia.com/gpu: 1 # This tells K8s to schedule this pod on a node with an available GPU
```

## Building your own Cluster Stacks

This section describes how to develop your own Cluster stack release from scratch.

### Directory structure

Create a new directory, e.g. `my-clusterstack`. Inside this directory create the following sub-directories:

- `cluster-class` - containing helm chart for `Cluster Class` and CAPI related resources
- `cluster-addon` - containing helmcharts to be installed as cluster addons, e.g. a CNI of your choice or metrics-server
- `node-image` (optional) - containing files to build your cluster's node-image - not used in this example.

### Cluster Class

- Create directory

  ```bash
  mkdir -p cluster-class/templates
  ```

- Create a  `Chart.yaml`, e.g.

  ```yaml
  apiVersion: v2
  description: "This is my Cluster Stacks Cluster Class"
  name: docker-my-cluster-class-1-32-cluster-class
  type: application
  version: v1
  ```

- Generate resources using `clusterctl` generator, e.g.

  ```bash
  clusterctl init --infrastructure docker
  cd templates
  clusterctl generate cluster my-cluster --infrastructure docker --flavor development \
    --kubernetes-version v1.32.0 --control-plane-machine-count=3 --worker-machine-count=3 \
    > my-cluster.yaml
  ```

- Split the file into different yaml files, e.g. `Kind: Cluster` should be in `cluster.yaml`
- Move `kind: Cluster` outside of `cluster-class` directory e.g.

  ```bash
  mv cluster.yaml ../../cluster.yaml
  ```

- Remove `my-cluster.yaml`

  ```bash
  rm my-cluster.yaml
  ```

- Escape all `{{ }}` so that they are not interpreted by Helm

  ```bash
  sed -i 's/{{/{{ `{{/g;s/}}/}}` }}/g' *.yaml
  ```

- Verify with

  ```bash
  helm template .
  ```

### Cluster Addon

- Initialize cluster addon directory

  ```bash
  cd ..
  mkdir cluster-addon
  cd cluster-addon
  ```

- Create an umbrella helm chart for every cluster addon, e.g. cilium

  ```bash
  helm create cni
  cd cni
  rm -rf templates
  ```

- Add Cilium as dependency to the Chart.yaml file:

  ```yaml
  dependencies:
    - alias: cilium
      name: cilium
      repository: https://helm.cilium.io/
      version: 1.17.2
  ```

- Build dependencies

  ```bash
  helm dep build
  ```

- When all dependency helm charts are created, go to the project main directory and create 
  `clusteraddon.yaml` e.g.

  ```yaml
  apiVersion: clusteraddonconfig.x-k8s.io/v1alpha1
  clusterAddonVersion: clusteraddons.clusterstack.x-k8s.io/v1alpha1
  addonStages:
  AfterControlPlaneInitialized:
    - name: cni
      action: apply
  BeforeClusterUpgrade:
    - name: cni
      action: apply
  ```

### Build clusterstack release using `csctl`

- Download [CSCTL](https://github.com/SovereignCloudStack/csctl/releases/latest) and unpack

  ```bash
  wget https://github.com/SovereignCloudStack/csctl/releases/download/v0.0.5/\
    csctl_0.0.5_linux_amd64.tar.gz
  tar -xzf ~/Downloads/csctl_0.0.5_linux_amd64.tar.gz
  chmod u+x csctt
  sudo mv csctl /usr/local/bin/csctl
  ```

- Configure `csctl`. The configuration of csctl has to be specified in the `csctl.yaml`. It needs to follow this structure:

  ```yaml
  apiVersion: csctl.clusterstack.x-k8s.io/v1alpha1
  config:
    kubernetesVersion: v1.32.0
    clusterStackName: my-clusterstack
    provider:
      type: docker
      apiVersion: docker.csctl.clusterstack.x-k8s.io/v1alpha1
  ```

- Verify the file/directory structure

  ```text
  my-clusterstack/
  	cluster-class/
  		templates/
  			clusterclass.yaml
  			...
  		Chart.yaml
  	cluster-addons/
  		cni/
  			charts/
  				cilium-1.16.6.tgz
  			 Chart.yaml
  	clusteraddons.yaml
  	csctl.yaml
  	cluster.yaml	
  ```

- Setup your repository to publish your cluster stack, e.g. for a git repository

  ```bash
  export GIT_PROVIDER=github #Only github supported
  export GIT_ORG_NAME=<your-org-or-user-name>
  export GIT_REPOSITORY_NAME=<your-repo-name>
  export GIT_ACCESS_TOKEN=<your-github-access-token>
  ```

- For OCI repository, e.g.

  ```bash
  export OCI_REGISTRY=<your-oci-registry>
  export OCI_REPOSITORY=<your-oci-repository>
  export OCI_ACCESS_TOKEN=<your-oci-access-token>
  export OCI_USERNAME=<your-username>
  export OCI_PASSWORD=<your-password>
  ```

- Create your cluster stack e.g.

  ```bash
  csctl create . --output ../my-clusterstack-build --mode hash
  ```

- If you want to publish, you can do so by e.g.

  ```bash
  csctl create . --output ../my-clusterstack-build --mode hash --publish --remote oci
  ```

### Assignments

1. Create own github repository to be used as a source for own cluster stacks implementations
2. Use environment variables to set the cluster stack source to this repository
3. Create own cluster stack implementation with alternative node images
4. Push the implementation to own github repository
5. Create a workload cluster using this cluster stack

## Upgrading Workload Clusters

In the management cluster the `ClusterStack` object is the central resource
referencing specific provider, cluster stack and Kubernetes minor version.
To be able to use multiple different Kubernetes versions new `ClusterStack`
object needs to be created, as the version is part of `ClusterStack`
specification. To be able to use specific versions of cluster stacks they
can be specified in `spec.versions` of given `ClusterStack` object
(see `clusterstack.yaml` file in [Quickstart guide](#quickstart-guide---docker-infrastructure)).

Preferred alternative is to allow `spec.autoSubscribe: true` in the
`ClusterStack` definition so that the operator handles discovery and
provisioning of latest versions.

Upgrading a workload cluster is done by editing the target `Cluster` object
and providing it a new `ClusterClass` in `spec.topology.class`. This assumes
that you have an existing cluster that references a certain `ClusterClass`
e.g. `docker-scs-1-30-v0-sha.rwvgrna` from the
[Quickstart guide](#quickstart-guide---docker-infrastructure).

It is possible to upgrade the Kubernetes version -
`docker-scs-1-30-v0-sha.rwvgrna` to `docker-scs-1-31-v0-sha.hdl6pjy`. In this
case a new `ClusterStack` object is needed as the Kubernetes version is part
of its specification.

```yaml
apiVersion: clusterstack.x-k8s.io/v1alpha1
kind: ClusterStack
metadata:
  name: docker-1-31
  namespace: cluster
spec:
  provider: docker
  name: scs
  kubernetesVersion: "1.31"
  channel: custom
  autoSubscribe: false
  noProvider: true
  versions:
    - v0-sha.hdl6pjy
```

Before upgrade make sure the new `ClusterClass` is available in the management
cluster. Then the target `Cluster` object can be edited:

- Update `spec.topology.class` to the name of the new class

  ```bash
  kubectl -n cluster edit cluster docker-testcluster
  
  ...
  spec:
    topology:
      class: docker-scs-1-31-v0-sha.hdl6pjy
  ...
  ```

- If Kubernetes version is to be changed update `spec.topology.version` in
  the same edit to respective Kubernetes version. Right version (e.g. "1.31.6")
  must be used and can be found in the `ClusterStack` object description, in
  the status of `ClusterStackRelease` object with the same name as desired
  target `ClusterClass` or in the cluster stack releases documentation

  ```bash
  ...
  spec:
    topology:
      version: v1.31.6
  ...
  ```

### Assignments

1. Upgrade Kubernetes version of workload cluster from [Quickstart guide assignments](#quickstart-guide)
   to 1.31
2. Verify Kubernetes version and proper function of the workload cluster

## Debugging and Troubleshooting

In case of cluster not working as expected there are steps you can take to
diagnose the problem.

- Check the latest events

  ```bash
  kubectl get events -A  --sort-by=.lastTimestamp
  ```

- Use a tool which conveniently checks all conditions of all resources in a
  Kubernetes cluster ([check-conditions](https://github.com/guettli/check-conditions))

  ```bash
  go run github.com/guettli/check-conditions@latest all
  ```

- Check the cluster with `clusterctl` tool

  ```bash
  clusterctl describe cluster -n cluster docker-testcluster
  NAME                                                              READY  SEVERITY  REASON                           SINCE  MESSAGE
  Cluster/docker-testcluster                                        False  Warning   ScalingUp                        3h16m  Scaling up control plane to 1 replicas (actual 0)
  ├─ClusterInfrastructure - DockerCluster/docker-testcluster-785wm  True                                              3h16m
  ├─ControlPlane - KubeadmControlPlane/docker-testcluster-45grm     False  Warning   ScalingUp                        3h16m  Scaling up control plane to 1 replicas (actual 0)
  │ └─Machine/docker-testcluster-45grm-tx5lt                        False  Warning   BootstrapFailed                  3h13m  1 of 2 completed
  └─Workers
    └─MachineDeployment/docker-testcluster-md-0-r6z4b               False  Warning   WaitingForAvailableMachines      3h16m  Minimum availability requires 1 replicas, current 0 available
      └─Machine/docker-testcluster-md-0-r6z4b-hlpj4-q8fkx           False  Info      WaitingForControlPlaneAvailable  3h16m  0 of 2 completed
  ```

- Check the logs, list all logs from all deployments, show for last 10 minutes

  ```bash
  kubectl get deployment -A --no-headers | while read -r ns d _; do 
    echo; echo "====== $ns $d"; kubectl logs --since=10m -n $ns deployment/$d;
  done
  ```

## Summary and Further Learning

- Recap of what you’ve learned
  - Cluster Stacks is a framework for fully defining production ready
    Kubernetes clusters, which can be deployed and managed using CAPI
  - Cluster Stacks Operator (CSO) is able to use such definition in
    the form of custom resources and deploy and manage workload
    clusters from it
  - To use Cluster Stacks
    - Define your workload cluster
    - Implement it for target provider or choose existing implementation
    - In a management cluster let CSO create a `ClusterClass` from the
      implementation
    - Use the `ClusterClass` to create target workload clusters
- Community - get help and participate
  - Sovereign Cloud Stack is an open community of providers and end-users
    joining forces in defining, implementing and operating a fully open,
    federated, compatible platform
  - You are actively encouraged to contribute either code, documentation
    or issues and to participate in the various discussions happening
    on GitHub or during our meetings
  - Join open community space on [Matrix network](https://matrix.to/#/#scs-community:matrix.org)
  - Check out the [Community calendar](https://docs.scs.community/community/collaboration)
    for information on teams meetings

## Appendices and Resources

- [Troubleshooting tips](https://docs.scs.community/docs/container/components/cluster-stacks/components/cluster-stack-operator/topics/troubleshoot)
- [SCS cluster-stacks repository](https://github.com/SovereignCloudStack/cluster-stacks)
- [cluster-stacks-demo repository](https://github.com/SovereignCloudStack/cluster-stacks-demo)
- [SCS training KaaS Scripts](https://github.com/SovereignCloudStack/scs-training-kaas-scripts)
- [Cluster Stacks Operator documentation](https://github.com/SovereignCloudStack/cluster-stack-operator/blob/main/docs/README.md)
- Links to documentation:
  - [SCS cluster stacks documentation](https://docs.scs.community/docs/category/cluster-stacks)
  - [CAPI official documentation](https://cluster-api.sigs.k8s.io/)
  - [KinD setup guide](https://kind.sigs.k8s.io/docs/user/quick-start/)
