# SCS Monitoring

## Course Overview
This course provides an introduction to SCS Monitoring, a scalable, highly available monitoring stack based on Prometheus, Thanos, Grafana and Loki. The course contains brief overview of used technologies as well as examples and demonstrations using KinD.
Note that the SCS Monitoring project is now maintained and evolved in the ALASCA ARKO project.

## Introduction
- Course goals
  - Layout motivation behind monitoring stack in SCS infrastructure
  - Provide understanding of SCS Monitoring Stack
  - Explain monitoring components, their deployments and configuration
  - Utilize hands-on experience with local example deployments using [KinD](https://kind.sigs.k8s.io/)
- Technologies covered
  - [KinD](https://kind.sigs.k8s.io/)
  - [Helm](https://helm.sh/)
  - [Kubernetes](https://kubernetes.io/)
  - [Prometheus](https://prometheus.io/)
  - [Thanos](https://thanos.io/)
  - [Loki](https://grafana.com/oss/loki/)
  - [Grafana](https://grafana.com/)

## Motivation and Use Cases
Monitoring means real-time metrics and logs that inform the operator about current infrastructure state and possible problems. Monitoring makes it easy to detect problems and makes it easier to solve or debug them.

**The main features of SCS Monitoring:**

- Highly available
- Scalable
- Global view
- Long term metrics and logs
- Infrastructure layer monitoring
- IaaS layer monitoring
- Various types of metrics (Prometheus, StatsD)
- Highly modular
- Highly extensible
- Alerting
- Matrix chat notifications

## Monitoring Overview
This section provides brief explanation of SCS monitoring stack and it's components.

### Visualisation and Data Layer
![Data layer Monitoring](images/monitoring1.svg)

- **Data Layer** - for scraping/exporting metrics and logs
	- Prometheus - collects  real-time metrics and alerts based on time-series data 
	   and provides a powerful query language (PromQL) to analyze the data. It's widely adopted in Kubernetes environments for its ease of use, flexibility, and strong community support.
	- Exporters (Node exporter,SSL exporter, etc.) - act as a bridge between Prometheus and the system being monitored, making it possible to gather metrics from services that don’t natively support Prometheus. . Node Exporter for example collects hardware and OS-level metrics - such as CPU, memory, disk, and network statistics - from Linux systems.
	- Thanos - extends Prometheus by enabling scalable, long-term storage and high availability of metrics data. It works by layering components on top of Prometheus, such as sidecars, query nodes, and object storage integrations (like S3 or GCS), to allow for deduplication, global querying across multiple Prometheus instances, and retention of data beyond the local storage limits
	- Loki - log aggregation system designed to work seamlessly with Prometheus and Grafana.Unlike traditional log systems, Loki indexes only metadata (like labels) instead of the full log content, making it efficient and cost-effective for storing and querying logs.
- **Visualization layer** - for visualisation frontend
	- Grafana - open-source analytics and visualization platform that lets users query, visualize, and alert on data from various sources like Prometheus, Loki, InfluxDB, Elasticsearch, and more. It provides interactive dashboards and customizable panels for monitoring metrics and logs in real time.
	- dNation K8S Monitoring - series of intuitive, drill-down Grafana dashboards and Prometheus alerts written in Jsonnet. The layered structure  L0 (all clusters and hosts), L1 (cluster/host overview), L2 and in some cases even L3 for detailed information. This design allows  to quickly detect and investigate a problem in users infrastructure.

### Monitoring Endpoints
SCS monitoring platform can observe various endpoints, such as tcp/http/https through Blackbox exporter, VMs and baremetal nodes through Node exporter, another k8s clusters - see [Multicluster Monitoring](#multicluster-monitoring) and [IaaS](#iaas-monitoring)(Openstack)

### Multicluster Monitoring
The SCS Monitoring Platform supports multi-cluster monitoring, enabling the observation of one or more Kubernetes clusters across various distributions, including K3s, OpenShift, and vanilla Kubernetes. It leverages Prometheus for metric scraping, Thanos for long-term metric storage in object storage services, and Grafana for visualizing metrics through customizable dashboards. Additionally, Loki is used for collecting and aggregating logs, providing a complete observability solution.

![Multicluster Monitoring](images/monitoring3.svg)

- **Workload Cluster** - Contains data layer only. Uses Prometheus to scrape metrics and Thanos to store long term metrics in an object-store service
- **Observer cluster** - Contains both data and visual layer. Utilizes Thanos with Envoy proxy for short term queries multiple clusters, hosts and IaaSs, including the observer cluster itself. Uses Grafana to display dNation dashboards, as well as any additional dashboards. For Long term queries it looks into the object-store service

### IAAS Monitoring
![IaaS Monitoring](images/iaas.png){width=480}

IaaS monitoring uses openstack exporter. The user needs to supply credentials in form of `clouds.yaml` Currently, there's no dNation dashboard, we recommend to use [this dashboard](https://grafana.com/grafana/dashboards/21085-openstack-overview/). See [Dashboards and Customization](#dashboards-and-customisation) on how to add 3rd party dashboards.

## Example Deployments
This section provides example deployments of single-cluster, multi-cluster and IAAS monitoring using [KinD](https://kind.sigs.k8s.io/)

### Quickstart Guide
- Create KinD cluster
  ```shell
  kind create cluster --config kind/kind-observer-config.yaml \
    --image kindest/node:v1.31.6 --name observer
  ```
- Install monitoring stack  
  ```shell
  helm repo add dnationcloud https://dnationcloud.github.io/helm-hub/
  helm repo update dnationcloud
  helm upgrade --install dnation-kubernetes-monitoring-stack \
    dnationcloud/dnation-kubernetes-monitoring-stack -f multicluster/values-observer.yaml
  ```
- Port-forward to Grafana
  ```bash
  kubectl --namespace default port-forward \
    svc/dnation-kubernetes-monitoring-stack-grafana 3000:80
  ```
- Access monitoring [http://localhost:30000/d/monitoring/infrastructure-services-monitoring](http://localhost:30000/d/monitoring/infrastructure-services-monitoring)

#### Assignments
1. Create a cluster and install Monitoring into it
2. Verify accessibility using UI

### Multicluster Monitoring
- Spawn a workload cluster in KinD - observer was already created in [previous section](#quickstart-guide), if not please follow it
  ```shell
  kind create cluster --config kind/kind-workload-config.yaml \
    --image kindest/node:v1.31.6 --name workload
  ```
- Install k8s monitoring on the cluster using `values-observer.yaml`
  ```shell
  helm --kube-context kind-workload  upgrade --install dnation-kubernetes-monitoring-stack \
    dnationcloud/dnation-kubernetes-monitoring-stack -f multicluster/values-workload.yaml
  ```
- Now we connect the clusters

#### Observer Cluster
- Install `cert-manager` 
  ```shell
  helm --kube-context kind-observer install cert-manager jetstack/cert-manager \
    --namespace cert-manager --create-namespace --version v1.17.2 --set crds.enabled=true
  ```
- Create a self signed issuer and a CA issuer with self-signed ca. Use CA issuer to generate client and server certificate.
  ```shell
  kubectl --context kind-observer  apply -f multicluster/tls-resources-observer.yaml 
  ```
- Copy data  from `tls-ca-key-pair`
  ```yaml
  apiVersion: v1
  kind: Secret
  metadata:
    name: thanos-query-envoy-certs
  type: kubernetes.io/tls
  data:
    ca.crt: <ca.crt>
    tls.crt: <tls.crt>
    tls.key: <tls.key>
  ```
- Apply additional observer values to mount this secrets
  ```shell
  helm --kube-context kind-observer upgrade dnation-kubernetes-monitoring-stack \
    dnationcloud/dnation-kubernetes-monitoring-stack -f multicluster/values-observer.yaml \
    -f multicluster/values-connect-observer.yaml
  ```
- Access monitoring [http://localhost:30000/d/monitoring/infrastructure-services-monitoring](http://localhost:30000/d/monitoring/infrastructure-services-monitoring). You will see the box for workload cluster saying `Down`
  > Hack: monitoring is domain based, this should make it work locally in Kind
- Add `query-workload.local` to `/etc/hosts`
  ```
  127.0.0.1 query-workload.local
  ```
- Add `query-workload.local` to `/etc/hosts`
  ```shell
  kubectl --context kind-observer -n kube-system edit configmap coredns
  ```
  ```go
  hosts {
	// Docker address of localhost, may be different for you
    172.17.0.1  query-workload.local
    fallthrough
  }
  ```
- Restart coredns

#### Workload Cluster
- Install ingress nginx
  ```shell
  kubectl --context kind-workload apply -f  multicluster/deploy-ingress-nginx.yaml
  ```
- Add the following secrets to workload cluster
  ```yaml
  apiVersion: v1
  kind: Secret
  metadata:
    name:thanos-server
    namespace: monitoring
  type: kubernetes.io/tls
  data:
  # copied from server-secret created by server-certificate (query-workload.local)
    ca.crt: <ca.crt>
    tls.crt: <tls.crt>
    tls.key: <tls.key>

  ---
  apiVersion: v1
  kind: Secret
  metadata:    
    name: thanos-ca-secret
    namespace: default
  data:
    # copy from tls-ca-key-pair
    ca.crt: <ca.crt>

  ```
- Apply workload observer values to connect the clusters
  ```bash
  helm --kube-context kind-workload  upgrade --install dnation-kubernetes-monitoring-stack \
    dnationcloud/dnation-kubernetes-monitoring-stack -f multicluster/values-workload.yaml \
    -f multicluster/values-connect-workload.yaml 
  ```

#### Assignments
1. Create a workload cluster
2. Interconnect with existing observer cluster with monitoring
3. Verify monitoring of workload cluster

### IaaS Monitoring
- Acquire application credential of your cloud. An admin access is required. You can use Horizon UI `https://your.openstack.cloud.url/identity/application_credentials/` or via `openstack` CLI
>Warning: If you used Horizon, the secret will be automatically generated and shown only once! Make sure to note it down in a secure place i.e. KeyPass
  ```shell
  openstack application credential create my-app-cred \
    --secret <generate-your-app-cred-secret-here> --role <admin or reader>
  ```
- Admin role is required to access all the metrics, without it the resulting dashboard will be incomplete.  In this example however, reader role is sufficient for demonstration purposes, fill free to use it. Also, in some Openstack deployments, internal API inaccessible from outside  is required to read all the metrics.
- Create `values-iaas.yaml` and fill in application credentials.

  ```yaml
  prometheus-openstack-exporter:
    enabled: true
    multicloud:
      enabled: false
    serviceMonitor:
      scrapeTimeout: "1m"
    commonLabels:
    # change if you chaged release name
      release: dnation-kubernetes-monitoring-stack 
  # reoplace with your clouds.yaml
    clouds_yaml_config: |
      clouds.yaml: |
          clouds:
            default:
              auth:
                auth_url: <replace>
                application_credential_id: "<replace>"
                application_credential_secret: "<replace>"
              region_name: "<replace>"
              interface: "public"
              identity_api_version: 3
              auth_type: "v3applicationcredential"
  #  Needed only for internal openstack APIs
  #  Demo purposes only, wont be used in KinD
  #  For example in Yaook, uncomment the following:
              # key: "/etc/ssl/certs/yaook-ca/tls.key"
              # cert: "/etc/ssl/certs/yaook-ca/tls.crt"
              # cacert: "/etc/ssl/certs/yaook-ca/ca.crt"
  
  # Mount certificates in case of internal API, e.g. Yaook
    # extraVolumes:
    # - name: yaook-ca
    #   secret:
    #     secretName: yaook-ca
    #     items:
    #     - key: ca.crt
    #       path: yaook-ca
  ```

- In real deployments e.g. Yaook, Kolla-Ansible, OSISM. Internal API is needed to access the metrics. Often, a private CA must be mounted. To do this, follow the commented part of above example. The observer cluster must, of course, have access to the internal api. The exporter might be deployed on a workload cluster as well, which is advised in case of Yaook.
- Create a file called `values-iaas-dashboard.yaml`. Since dNation K8S monitoring does not provide it's own dashboard for IaaS/Openstack you can use the [recommended dashboard](https://grafana.com/grafana/dashboards/21085-openstack-overview/).

  ```yaml
  kube-prometheus-stack:
    grafana:
      dashboardProviders:
        dashboardprovidersiaas.yaml:
          apiVersion: 1
          providers:
        # Openstack exporter Dashboard provider
          - name: iaas
            folder: 'IaaS'
            type: file
            disableDeletion: false
            editable: true
            options:
              path: /var/lib/grafana/dashboards/iaas
      dashboards:
        iaas:
          # Openstack exporter Dashboard
          openstack-exporter:
          #Dashboard Id from URL
            gnetId: 21085
            revision: 3
            datasource:
            - name: DS_PROMETHEUS
              value: thanos
  
  ```

- In this kind example. You can also use [values file](iaaas/values-iaas.yaml) provided with this documentation, which combines both above yaml files into one. Just fill in your credentials and apply to observer cluster.
  ```bash
  helm upgrade --context kind-observer --install dnationcloud/dnation-kubernetes-monitoring-stack -f multicluster/values-observer.yaml
  ```

#### Assignments
1. Create a workload cluster
2. Interconnect with existing observer cluster with monitoring
3. Verify monitoring of workload cluster

## Dashboards and Customization
dNation K8S Monitoring project provides many dashboards, which are written in Jsonnet and are therefore highly customizable. User can override default thresholds or change the colors with helm values only, there's no need to edit any Json/Jsonnet file. The values files are self-explanatory  for example:

```yaml
dnation-kubernetes-monitoring:
  templates:
    L1:
      k8s:
        # Modify default k8s templates
        #This should be name of the alert
        overallUtilizationMasterNodesRAM:
          panel:
            thresholds:
              critical: 95
              warning: 90
          alert:
            thresholds:
              critical: 95
              warning: 90
```

Another example, can define custom alerts.
```yaml
dnation-kubernetes-monitoring:
  templates:
    L1:
        overallUtilizationRAMSQL:
          parent: 'overallUtilizationRAM'
          default: false
          panel:
            title: 'Overall Utilization ProdSql'
            thresholds:
              critical: 97
              warning: 95
          alert:
            name: 'HostRAMOverallHighProdSql'
            expr: 'round((1 - sum by (job, nodename) (node_memory_MemAvailable_bytes{job=~\"prod-sql-h-1|prod-sql-h-2|prod-sql-h-3\"} * on(instance) group_left(nodename) (node_uname_info)) / sum by (job, nodename) (node_memory_MemTotal_bytes{job=~\"prod-sql-h-1|prod-sql-h-2|prod-sql-h-3\"} * on(instance) group_left(nodename) (node_uname_info))) * 100)'
            thresholds:
              critical: 97
              warning: 95
```

dNation k8s Monitoring has several pre-made dashboard for k8s apps, e.g. MySQL, Ingress Nginx, Java Spring Actuator, etc. These dashboards can have their panel added to the clusters L1 dashboard. 

```yaml
dnation-kubernetes-monitoring:
  clusterMonitoring:
    clusters:
    - name: observer
      label: observer-cluster
      description: 'Observer Cluster'
      apps:
      - name: nginx-ingress
        description: Nginx ingress controller
        jobName: ingress-nginx
        templates:
          nginxIngress:
            enable: true
          nginxIngressCertificateExpiry:
            enable: true
        serviceMonitor:
          jobLabel: app
          namespaceSelector:
            matchNames:
            - ingress-nginx
          selector:
            matchLabels:
              app: ingress-nginx
          endpoints:
          - targetPort: metrics
            interval: 30s
            path: /metrics
            relabelings:
            - *containerLabel
```

### Assignments
1. Lower thresholds for utilization of the monitoring
2. Observe changes in reported values
3. Add an ingress Nginx panel to dashboard

## Appendices and Resources

### ETCD, Kube-Proxy fix
- The metrics of `etcd` and `kube-proxy` control plane components are by default bound to the localhost that prometheus instances **cannot** access.
- When spawning a new cluster (`kubeadm init`) you can use our config
  ```bash
  kubeadm init --config=helpers/kubeadm_init.yaml
  ```
- On existing clusters, access the node via SSH and do the following
  ```bash
  # On k8s master node
  cd /etc/kubernetes/manifests/
  sudo vim etcd.yaml
  ```
  ```yaml
  # Add listen-metrics-urls as etcd command option
  ...
  - --listen-metrics-urls=http://0.0.0.0:2381
  ...
  ```
- Setup `kube-proxy` metrics bind address
   Edit  kube-proxy daemon set
  ```shell
  kubectl edit ds kube-proxy -n kube-system
  ```
  ```yaml
  ...containers:
      - command:
        - /usr/local/bin/kube-proxy
        - --config=/var/lib/kube-proxy/config.conf
        - --hostname-override=$(NODE_NAME)
        - --metrics-bind-address=0.0.0.0  # Add metrics-bind-address line

  ```
  Edit kube-proxy config map
  ```shell
  kubectl -n kube-system edit cm kube-proxy
  ```
  ```yaml
  ...
    kind: KubeProxyConfiguration
    metricsBindAddress: "0.0.0.0:10249" # Add metrics-bind-address host:port
    mode: ""
  ```
  Delete the kube-proxy pods and reapply the new configuration
  ```shell
  kubectl -n kube-system delete po -l k8s-app=kube-proxy
  ```
- Setup `scheduler` metrics bind address
  ```shell
  # On k8s master node
  cd /etc/kubernetes/manifests/
  sudo vim kube-scheduler.yaml
  ```
  ```yaml
  # Edit bind-address and port command options
  ...
  - --bind-address=0.0.0.0
  - --secure-port=10259
  ...
  ```
- Setup `controller-manager` metrics bind address
  ```shell
  # On k8s master node
  cd /etc/kubernetes/manifests/
  sudo vim kube-controller-manager.yaml
  ```
  ```yaml
  # Edit bind-address and port command options
  ...
  - --bind-address=0.0.0.0
  - --secure-port=10257
  ...
  ```

### Resources
* [SCS Monitoring Documentation](https://docs.scs.community/docs/operating-scs/components/monitoring/docs/overview)
* [dNation Kubernetes Monitoring](https://dnationcloud.github.io/kubernetes-monitoring/)
* [ALASCA ARKO](https://alasca.cloud/projects/arko/)
