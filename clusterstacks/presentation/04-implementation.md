# Implementation and Practice

Note:
- In this section, we'll move from theory to practice
- We'll cover the practical aspects of working with ClusterStacks
- This includes deployment, configuration, and management
- You'll learn the skills needed to implement ClusterStacks in your environment

----

## Required Tools

- **KinD (Kubernetes in Docker)**: Creates local Kubernetes clusters
- **clusterctl**: CLI tool for Cluster API operations
<!-- .element: class="fragment" data-fragment-index="0" -->
- **Helm**: Package manager for Kubernetes applications
<!-- .element: class="fragment" data-fragment-index="1" -->
- **kubectl**: Kubernetes command-line interface
<!-- .element: class="fragment" data-fragment-index="2" -->

Note:
- We use several essential tools to work with ClusterStacks:
- KinD (Kubernetes in Docker) creates local Kubernetes clusters inside Docker containers
  - Perfect to bootstrap a management cluster that runs the Cluster API controllers
  - Allows for lightweight, isolated testing and development
- clusterctl is the primary CLI for Cluster API
  - Initializes providers in the management cluster
  - Helps create and manage workload clusters
  - Generates cluster templates and configuration
- Helm is the package manager for Kubernetes
  - Used to install the Cluster Stack Operator
  - Manages add-ons and components in workload clusters
  - Provides templating and versioning for deployments
- kubectl is needed for interacting with all Kubernetes clusters
  - We assume familiarity with basic kubectl operations
  - Will use it to examine both management and workload clusters
- These tools work together to create a complete ClusterStacks environment

----

## Installing clusterctl

- Command-line utility provided by Cluster API (CAPI)
- Automates installing Cluster API providers into a management cluster
<!-- .element: class="fragment" data-fragment-index="0" -->
- Helps create workload clusters and manage their life-cycle
<!-- .element: class="fragment" data-fragment-index="1" -->
- Essential for working with ClusterStacks
<!-- .element: class="fragment" data-fragment-index="2" -->

```bash
# Download clusterctl for Linux
curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.9.7/clusterctl-linux-amd64 -o clusterctl

# Make it executable
chmod +x clusterctl

# Move to a location in your PATH
sudo mv clusterctl /usr/local/bin/

# Verify installation
clusterctl version
```

For macOS:
```bash
# Download clusterctl for macOS
curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.9.7/clusterctl-darwin-amd64 -o clusterctl

# Make it executable
chmod +x clusterctl

# Move to a location in your PATH
sudo mv clusterctl /usr/local/bin/

# Verify installation
clusterctl version
```

Note:
- The `clusterctl` tool is a command-line utility provided by Cluster API (CAPI)
- It automates the process of installing Cluster API providers into a management cluster
- It also helps with creating workload clusters and managing their life-cycle
- Moving it to `/usr/local/bin/` makes it available system-wide
- No sudo is needed for running the commands after installation
- If you prefer not to use sudo for installation, you can install it to `~/bin/` instead (ensure this directory is in your PATH):
  ```bash
  # Alternative installation without sudo
  mkdir -p ~/bin
  mv clusterctl ~/bin/
  # Add to PATH if needed (add this to your ~/.bashrc or ~/.zshrc)
  export PATH=$PATH:~/bin
  ```
- Check for the latest release version on the [Cluster API GitHub releases page](https://github.com/kubernetes-sigs/cluster-api/releases)

----

## Installing Helm

- Helm is the package manager for Kubernetes
- Charts are packages of pre-configured Kubernetes resources
<!-- .element: class="fragment" data-fragment-index="0" -->
- Required for installing the Cluster Stack Operator
<!-- .element: class="fragment" data-fragment-index="1" -->
- Provides versioning, templating, and dependency management
<!-- .element: class="fragment" data-fragment-index="2" -->
- Makes cluster deployments consistent and reproducible
<!-- .element: class="fragment" data-fragment-index="3" -->

```bash
# Download Helm for Linux
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod +x get_helm.sh
./get_helm.sh

# Verify installation
helm version
```

For macOS:
```bash
# Using Homebrew (recommended)
brew install helm

# Verify installation
helm version
```

Note:
- Helm is the package manager for Kubernetes - it simplifies deploying and managing applications
- Charts are packages of pre-configured Kubernetes resources - like templates for applications
- The Cluster Stack Operator (CSO) must be installed with Helm - it's a prerequisite
- Helm provides powerful features like versioning, templating, and dependency management
- ClusterStacks use Helm for both core components and add-ons, ensuring consistency
- No sudo needed for Helm commands after installation
- The installation script automatically adds Helm to your PATH

----

## Exercise 1: Installing Prerequisites

**Task: Install and configure the required tools**
1. Install clusterctl and make it executable
2. Install Helm
3. Verify all tools are working correctly

```bash
# 1. Install clusterctl
curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.9.7/clusterctl-linux-amd64 -o clusterctl
chmod +x clusterctl
sudo mv clusterctl /usr/local/bin/

# 2. Install Helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod +x get_helm.sh
./get_helm.sh

# 3. Verify installations
clusterctl version
helm version
```

Note:
- This exercise ensures you have all the necessary tools before proceeding
- clusterctl is essential for working with Cluster API resources
- Make the binaries executable with chmod +x before moving them to your PATH
- If you prefer not to use sudo, you can install to ~/bin instead:
  ```bash
  mkdir -p ~/bin
  mv clusterctl ~/bin/
  export PATH=$PATH:~/bin  # Add to ~/.bashrc or ~/.zshrc for persistence
  ```
- The verification steps confirm that everything is installed correctly
- These tools will be used throughout the following exercises

----

## Setting Up a Management Cluster with KinD

- KinD creates Kubernetes clusters running in Docker containers
- Provides a lightweight environment for the management plane
<!-- .element: class="fragment" data-fragment-index="0" -->
- Hosts the Cluster API and ClusterStack Operator controllers
<!-- .element: class="fragment" data-fragment-index="1" -->
- Simplifies testing and development of Kubernetes clusters
<!-- .element: class="fragment" data-fragment-index="2" -->
- Focus remains on the workload clusters we'll create
<!-- .element: class="fragment" data-fragment-index="3" -->

```bash
# Create a configuration file for KinD with Docker socket access
cat > kind-config.yaml << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraMounts:
  - hostPath: /var/run/docker.sock
    containerPath: /var/run/docker.sock
EOF

# Create a KinD cluster for the management plane
kind create cluster --config kind-config.yaml

# Initialize with CAPI
export CLUSTER_TOPOLOGY=true
export EXP_CLUSTER_RESOURCE_SET=true
export EXP_RUNTIME_SDK=true
clusterctl init --infrastructure docker --ignore-webhook-certificate
```

Note:
- We use KinD as a simple way to create a Kubernetes cluster for our management plane
- This cluster will host the Cluster API and ClusterStack Operator controllers
- We're not focusing on KinD itself - it's just a convenient tool for our demonstration
- The management cluster runs in Docker containers
- The environment variables enable experimental features needed by ClusterStacks
- We initialize the Docker infrastructure provider for this demonstration
- The Docker socket must be mounted to allow Docker-in-Docker operations
- The `--ignore-webhook-certificate` flag helps avoid certificate validation issues
- These configurations are critical for the Docker provider to work correctly

----

## Installing Cluster Stack Operator

```bash
# Install CSO with Helm
helm upgrade -i cso \
  -n cso-system \
  --create-namespace \
  oci://registry.scs.community/cluster-stacks/cso \
  --set clusterStackVariables.ociRepository=registry.scs.community/kaas/cluster-stacks

# Create namespace for clusters
kubectl create namespace cluster
```

Note:
- The Cluster Stack Operator (CSO) extends CAPI with add-on management capabilities
- We install it into its own namespace (cso-system) using Helm
- The ociRepository parameter points to the SCS registry where ClusterStack artifacts are stored
- We also create a dedicated namespace for our cluster resources
- With CSO installed, the management cluster is now ready to deploy workload clusters
- If you encounter webhook errors, you may need to wait a few minutes for all CAPI components to initialize properly

----

## Creating a ClusterStack

Create a basic `clusterstack.yaml` file and apply it:

```yaml
# ClusterStack definition for Docker
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

```bash
# Apply the ClusterStack
kubectl apply -f clusterstack.yaml

# Verify the ClusterClass creation
kubectl get clusterclass -n cluster
```

Note:
- We define a ClusterStack for Docker that specifies the Kubernetes version
- The CSO will download and prepare the necessary cluster stack components
- It creates a ClusterClass that can be referenced by our cluster definition
- Wait for the ClusterClass to be created before proceeding to create the cluster
- You can watch the progress with: kubectl get clusterclass -n cluster -w
- This might take a minute or two to complete

----

## Creating a Single-Node Workload Cluster

For testing and development, a single-node cluster (control plane only) is more reliable:

```bash
# Create the single-node cluster configuration file
cat > cluster-single.yaml << EOF
apiVersion: cluster.x-k8s.io/v1beta1
kind: Cluster
metadata:
  name: docker-testcluster-single
  namespace: cluster
  labels:
    managed-secret: cloud-config
  annotations:
    controlplane.cluster.x-k8s.io/kubeadm-configuration-extraargs: "{\"ignore-preflight-errors\": [\"FileAvailable--etc-kubernetes-kubelet.conf\", \"FileAvailable--etc-kubernetes-pki-ca.crt\"]}"
    controlplane.cluster.x-k8s.io/taints: "[]"
spec:
  topology:
    class: docker-scs-1-30-v0-sha.rwvgrna
    controlPlane:
      replicas: 1
    version: v1.30.10
EOF

# Apply the cluster definition
kubectl apply -f cluster-single.yaml

# Monitor cluster creation
kubectl get cluster -n cluster
clusterctl describe cluster docker-testcluster-single -n cluster
```

Note:
- For testing and development, a single-node setup (control plane only) is more reliable
- This configuration creates a Kubernetes cluster with just one node that acts as both control plane and worker
- The key features of this configuration:
  - Single control plane node (no separate worker nodes)
  - `controlplane.cluster.x-k8s.io/taints: "[]"` removes the control-plane taint so workloads can be scheduled
  - `ignore-preflight-errors` prevents failures during bootstrap due to pre-existing files
- This approach is more resource-efficient and avoids worker node bootstrap issues
- In production environments, you would typically use separate worker nodes for better separation of concerns
- The single-node setup is recommended for development and testing scenarios

----

## Waiting for Cluster Bootstrapping

- Bootstrapping a Kubernetes cluster takes time
- Control plane initialization (~3-5 minutes)
<!-- .element: class="fragment" data-fragment-index="0" -->
- Add-ons deployment (~1-2 minutes)
<!-- .element: class="fragment" data-fragment-index="1" -->
- Monitor the progress with clusterctl
<!-- .element: class="fragment" data-fragment-index="2" -->
- Single-node approach simplifies troubleshooting
<!-- .element: class="fragment" data-fragment-index="3" -->

```bash
# Watch the cluster status
watch -n 10 "clusterctl describe cluster docker-testcluster-single -n cluster"

# Check machine status
kubectl get machines -n cluster

# Check Docker containers
docker ps | grep docker-testcluster
```

Note:
- The bootstrapping process for a CAPI cluster takes time - be patient
- For a Docker-based single-node CAPI cluster, expect 3-7 minutes total bootstrapping time
- During bootstrapping, the following happens:
  - Images are being pulled (Kubernetes components, CNI, etc.)
  - kubeadm initializes the control plane
  - Container networking is set up
  - etcd is initialized
  - API server, controller manager, and scheduler start
  - CNI (Cilium) is deployed
- You can monitor the process using the commands shown
- The cluster is ready when the control plane machine shows as "Running" and "Ready: True"
- Single-node clusters avoid the worker node bootstrap failures that can occur with multi-node setups

----

## Accessing Your Workload Cluster

```bash
# Get kubeconfig for your workload cluster
clusterctl get kubeconfig -n cluster docker-testcluster-single > /tmp/kubeconfig-single

# Check cluster nodes
kubectl --kubeconfig /tmp/kubeconfig-single get nodes
```

Note:
- After your workload cluster is created, you can interact with it like any Kubernetes cluster
- The `clusterctl get kubeconfig` command retrieves the access credentials
- You can use these credentials to directly interact with the workload cluster
- The cluster has the Cilium CNI installed automatically as part of the ClusterStack

----

## Fixing Pod Scheduling Issues

Some pods might remain in Pending state due to resource constraints in a single-node cluster:

```bash
# Check for pending pods
kubectl --kubeconfig /tmp/kubeconfig-single get pods -A | grep Pending

# First identify the exact deployment names if needed
kubectl --kubeconfig /tmp/kubeconfig-single get deployments -A

# Fix CoreDN

Note:
- After creating a single-node cluster, you might notice some pods remain in Pending state
- This happens because many components are configured with multiple replicas by default
- In a single-node environment, anti-affinity rules may prevent multiple replicas from being scheduled
- The solution is to reduce the replica count to 1 for affected deployments
- Common components that need adjustments include:
  - CoreDNS (typically 2 replicas by default)
  - Cilium Operator (typically 2 replicas by default)
  - Metrics Server (may have multiple replicas)
- After applying these patches, all pods should transition to Running state
- This is a normal adjustment required for single-node clusters and doesn't affect functionality

----

## Examining Your Workload Cluster

```bash
# Check cluster nodes and their status
kubectl --kubeconfig /tmp/kubeconfig-single get nodes

# Check pod status across all namespaces
kubectl --kubeconfig /tmp/kubeconfig-single get pods -A

# Examine key components
kubectl --kubeconfig /tmp/kubeconfig-single get pods -n kube-system
```

Note:
- After your workload cluster is created, you can interact with it like any Kubernetes cluster
- The cluster has all the necessary components for a fully functional Kubernetes environment
- ClusterStacks automatically deploys essential add-ons like Cilium for networking
- After the replica adjustments, all pods should be in the Running state
- You can deploy applications to this cluster just like any other Kubernetes cluster
- This is a real Kubernetes cluster, even though it's running as a single node

----

## Deploying Applications to Your Cluster

```bash
# Deploy a sample application
kubectl --kubeconfig /tmp/kubeconfig-single create deployment nginx --image=nginx
kubectl --kubeconfig /tmp/kubeconfig-single expose deployment nginx --port=80 --type=ClusterIP
kubectl --kubeconfig /tmp/kubeconfig-single port-forward service/nginx 8080:80

# Access the application
curl localhost:8080
```

Note:
- After deploying your workload cluster, you can deploy applications just like on any Kubernetes cluster
- The application runs on the Docker container created by the ClusterStack
- This demonstrates that the cluster is fully functional
- ClusterStacks ensures that all necessary components are properly configured
- The single-node approach provides a complete Kubernetes environment while using minimal resources

----

## Troubleshooting Common Issues

- Worker node bootstrap failures with multi-node clusters
- Certificate validation issues
<!-- .element: class="fragment" data-fragment-index="0" -->
- Docker socket access problems
<!-- .element: class="fragment" data-fragment-index="1" -->
- Resource constraints (CPU, memory, disk)
<!-- .element: class="fragment" data-fragment-index="2" -->
- Network connectivity issues
<!-- .element: class="fragment" data-fragment-index="3" -->

```bash
# Check for pending pods due to resource constraints
kubectl --kubeconfig /tmp/kubeconfig-single get pods -A | grep Pending

# Fix multi-replica deployments for single-node clusters
kubectl --kubeconfig /tmp/kubeconfig-single -n kube-system patch deployment coredns --type='json' -p='[{"op": "replace", "path": "/spec/replicas", "value":1}]'

# Check Kubernetes events for issues
kubectl --kubeconfig /tmp/kubeconfig-single get events --sort-by='.lastTimestamp'
```

Note:
- CAPI clusters can encounter various issues during creation and bootstrapping
- For multi-node clusters, worker node bootstrap failures are common due to preflight checks
  - The solution is to use the single-node approach or configure preflight check ignores
- In single-node clusters, pod scheduling issues can occur due to multiple replicas and anti-affinity
  - The solution is to reduce replica counts for system deployments
- Resource constraints are common in development environments
  - Ensure your system has enough CPU, memory, and disk space
- Docker socket access is critical - ensure it's properly mounted
- Certificate validation issues can be resolved with the `--ignore-webhook-certificate` flag
- Check events and logs to diagnose specific issues
