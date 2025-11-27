# Kubernetes Deployment Guide

This directory contains a Kubernetes manifest for deploying the Big-O demonstration project.

## Quick start

```bash
# From project root
make demo-k8s
```

## What's included

`big-o-demo.yaml` manifest contains:

### Namespace
- `big-o-demo` - Isolated namespace for all resources

### ConfigMaps
- `prometheus-config` - Prometheus scrape configuration
- `grafana-datasource` - Grafana Prometheus datasource
- `grafana-dashboard-provider` - Dashboard provider configuration
- `grafana-dashboard-json` - Complete dashboard definition

### Deployments
- `bubble-sort` - O(n²) sorting service
- `merge-sort` - O(n log n) sorting service
- `ui` - Interactive web interface for real-time sorting demonstrations
- `prometheus` - Metrics collection and storage
- `grafana` - Metrics visualization

### Services
- `bubble-sort` (ClusterIP:8080) - Internal metrics endpoint
- `merge-sort` (ClusterIP:8080) - Internal metrics endpoint
- `ui` (NodePort:30301) - External web UI
- `prometheus` (ClusterIP:9090) - Internal Prometheus UI
- `grafana` (NodePort:30300) - External Grafana UI

## Architecture

(Check Emacs uniline mode https://github.com/tbanel/uniline !)

```
╭───────────────────────────────────────────────────────────────────╮
│ Namespace: big-o-demo                                             │
│                                                                   │
│  ╭──────────────╮  ╭──────────────╮  ╭──────────────╮             │
│  │ bubble-sort  │  │  merge-sort  │  │      ui      │             │
│  │  Pod:8080    │  │  Pod:8080    │  │  Pod:8080    │             │
│  ╰──────┬───────╯  ╰──────┬───────╯  ╰──────┬───────╯             │
│         │                 │                 │                     │
│         │   ╭─────────────▼───────╮         │                     │
│         │   │                     │         │                     │
│         └───▶  Prometheus:9090    │         │                     │
│             │  (scrapes every 5s) │         │                     │
│             ╰──────────┬──────────╯         │                     │
│                        │                    │                     │
│                ╭───────▼────────╮           │                     │
│                │  Grafana:3000  │           │                     │
│                │  (dashboards)  │           │                     │
│                ╰────────┬───────╯           │                     │
│                         │                   │                     │
╰─────────────────────────┼───────────────────┼─────────────────────╯
                          ▼                   ▼
                  NodePort:30300      NodePort:30301
                          │                   │
                          ▼                   ▼
          http://localhost:30300      http://localhost:30301
```

No Ingress (or Gateway) is used, nor NLB: if needed, that is left as
an exercise to the user :D There's a make target, `k8s-port-forward`,
that sets up port forwarding, but read more about it below.

## Included features

Some care has been taken in provising reasonable useful features, even
if they are not really needed for this small demo.

### Health Checks
All services include liveness and readiness probes:
- Sorting services: `/health` endpoint
- Prometheus: `/-/healthy` and `/-/ready`
- Grafana: `/api/health`

### Resource Management

Appropriate CPU and memory limits have bee set:
```yaml
Bubble/Merge Sort:
  requests: 50m CPU, 64Mi RAM
  limits: 100m CPU, 128Mi RAM

Prometheus:
  requests: 100m CPU, 256Mi RAM
  limits: 200m CPU, 512Mi RAM

Grafana:
  requests: 50m CPU, 128Mi RAM
  limits: 100m CPU, 256Mi RAM

UI:
  requests: 50m CPU, 64Mi RAM
  limits: 100m CPU, 128Mi RAM
```

The total cluster requirements are ~450m CPU, ~1.1Gi RAM.

### Labels and selectors

Proper labeling for organization:
- `app: <service-name>` - Service identifier
- `algorithm: bubble|merge` - Algorithm type
- `component: sorting-service|monitoring|visualization` - Component role

### Configuration as code

All configuration is done via ConfigMaps:

- Prometheus scrape targets
- Grafana datasources
- Dashboard definitions

No manual configuration is expected or required.

## Deployment methods

### Method 1: Makefile (Recommended)

```bash
# Deploy
make k8s-deploy

# Check status
make k8s-status

# View logs
make k8s-logs

# Delete
make k8s-delete
```

### Method 2: kubectl Directly

```bash
# Apply manifest
kubectl apply -f big-o-demo.yaml

# Wait for ready
kubectl wait --for=condition=ready pod --all -n big-o-demo --timeout=120s

# Check status
kubectl get all -n big-o-demo

# View logs
kubectl logs -l app=bubble-sort -n big-o-demo

# Delete
kubectl delete -f big-o-demo.yaml
```

## Accessing Grafana

### Option 1: NodePort (Default)
Access directly via fixed NodePort:
```bash
open http://localhost:30300
```

Login: `admin` / `admin`

### Option 2: Port-Forward
Forward service port to localhost:
```bash
kubectl port-forward -n big-o-demo svc/grafana 3000:3000
```

Then access: http://localhost:3000

## Accessing the Web UI

The interactive web UI lets you run sorting algorithms in real-time and experience the performance difference firsthand.

### Option 1: NodePort (Default)
Access directly via fixed NodePort:
```bash
open http://localhost:30301
```

### Option 2: Port-Forward
Forward service port to localhost:
```bash
kubectl port-forward -n big-o-demo svc/ui 8080:8080
```

Then access: http://localhost:8080

## Cluster Compatibility

### kind (Recommended for Local Development)
```bash
# Create cluster (if needed)
kind create cluster --name big-o-demo

# Deploy (Makefile automatically loads images into kind)
make k8s-deploy
```

The Makefile uses `kind load docker-image` to load images into the cluster automatically.

### minikube
```bash
# Load images into minikube
minikube image load bubble-sort:latest
minikube image load merge-sort:latest
minikube image load ui:latest

# Deploy
kubectl apply -f big-o-demo.yaml
```

### k0s
```bash
# Set KUBECONFIG
export KUBECONFIG=/var/lib/k0s/pki/admin.conf

# Images use imagePullPolicy: Never, so they must be available locally
# You may need to import images: k0s ctr images import

# Deploy
kubectl apply -f big-o-demo.yaml
```

### Cloud Kubernetes (GKE, EKS, AKS)
```bash
# Push images to registry
docker tag bubble-sort:latest gcr.io/YOUR_PROJECT/bubble-sort:latest
docker push gcr.io/YOUR_PROJECT/bubble-sort:latest

# Update manifest to use registry images
# Change imagePullPolicy: Never to imagePullPolicy: IfNotPresent
# Change image: bubble-sort:latest to image: gcr.io/YOUR_PROJECT/bubble-sort:latest

# Deploy
kubectl apply -f big-o-demo.yaml
```

## Storage Considerations

### Current Setup (Demo)
- Uses `emptyDir` volumes for Prometheus and Grafana data
- Data is **ephemeral** (lost on pod restart)
- Acceptable for demo/educational purposes
- Dashboard configuration is auto-provisioned from ConfigMaps

### Production Setup
Replace `emptyDir` with PersistentVolumeClaims:

```yaml
volumes:
  - name: data
    persistentVolumeClaim:
      claimName: grafana-storage
```

Create PVC:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: grafana-storage
  namespace: big-o-demo
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

## Troubleshooting

### Pods Not Starting
```bash
# Check pod status
kubectl get pods -n big-o-demo

# Describe pod for events
kubectl describe pod <pod-name> -n big-o-demo

# Check logs
kubectl logs <pod-name> -n big-o-demo
```

### Image Pull Errors
```bash
# Check images exist locally
docker images | grep -E "bubble-sort|merge-sort|ui"

# Reload images into kind
kind load docker-image bubble-sort:latest
kind load docker-image merge-sort:latest
kind load docker-image ui:latest

# Check imagePullPolicy is set to "Never" for local clusters
kubectl get deployment bubble-sort -n big-o-demo -o yaml | grep imagePullPolicy

# Verify kind cluster is running
kind get clusters
```

### Grafana Dashboard Not Loading
```bash
# Check ConfigMaps are created
kubectl get configmaps -n big-o-demo

# Verify dashboard ConfigMap content
kubectl get configmap grafana-dashboard-json -n big-o-demo -o yaml

# Check Grafana logs
kubectl logs -l app=grafana -n big-o-demo
```

### No Metrics in Prometheus
```bash
# Check Prometheus targets
kubectl port-forward -n big-o-demo svc/prometheus 9090:9090
# Open http://localhost:9090/targets

# Verify services are reachable
kubectl get svc -n big-o-demo

# Check Prometheus logs
kubectl logs -l app=prometheus -n big-o-demo
```

## Customization

### Change Array Sizes
Edit the Deployment env vars:
```yaml
env:
- name: ARRAY_SIZES
  value: "100,1000,10000,50000,100000"  # Modify this
```

### Adjust Resource Limits
Modify resources in Deployments:
```yaml
resources:
  requests:
    cpu: 100m      # Increase for faster execution
    memory: 256Mi  # Increase for larger arrays
  limits:
    cpu: 200m
    memory: 512Mi
```

### Change Scrape Interval
Edit Prometheus ConfigMap:
```yaml
global:
  scrape_interval: 5s  # Change this (e.g., 10s, 15s)
```

## Security Considerations

### Current Setup (Demo)
- Hardcoded Grafana credentials (admin/admin)
- No NetworkPolicies
- No Pod Security Standards
- Acceptable for educational purposes

### Production Hardening
1. **Use Secrets for credentials**:
```yaml
env:
  - name: GF_SECURITY_ADMIN_PASSWORD
    valueFrom:
      secretKeyRef:
        name: grafana-admin
        key: password
```

2. **Add NetworkPolicies**:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: prometheus-ingress
  namespace: big-o-demo
spec:
  podSelector:
    matchLabels:
      app: prometheus
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: grafana
  - ports:
    - port: 9090
```

3. **Apply Pod Security Standards**:
```yaml
metadata:
  namespace: big-o-demo
  labels:
    pod-security.kubernetes.io/enforce: restricted
```

## Monitoring the Demo

### Watch Pods Start
```bash
kubectl get pods -n big-o-demo -w
```

### Follow Logs in Real-Time
```bash
# All services
kubectl logs -f -l component=sorting-service -n big-o-demo

# Specific service
kubectl logs -f -l app=bubble-sort -n big-o-demo
```

### Check Resource Usage
```bash
kubectl top pods -n big-o-demo
```

## Cleanup

```bash
# Delete everything
make k8s-delete

# Or manually
kubectl delete namespace big-o-demo
```

This will remove all resources created by the manifest.

## Files

- `big-o-demo.yaml` - Complete Kubernetes manifest
- `README.md` - This guide

## Next steps

1. Deploy: `make k8s-deploy`
2. Access Web UI: http://localhost:30301 - Try sorting with different algorithms and sizes!
3. Access Grafana: http://localhost:30300 (login: admin/admin)
4. Watch the dashboard populate with metrics
5. Observe the dramatic difference between O(n²) and O(n log n)

---

**Author**: Frederico Muñoz
**Role**: CNCF Ambassador, K8s v1.32 Release Lead, SIG Architecture
**Purpose**: Educational demonstration + portfolio piece
