# Observatorium Operator

:warning: This project is a work in progress.

## How to deploy (Kubernetes)

### Prerequisites

#### S3 storage endpoint. For testing purposes you may use minio as follows

```
kubectl create namespace minio
kubectl create -f https://raw.githubusercontent.com/nmagnezi/observatorium-jsonnet-operator/master/hack/kubernetes/minio.yaml
```

#### Observatorium namespace thanos-objectstorage secret 

```
kubectl create -f https://raw.githubusercontent.com/nmagnezi/observatorium-jsonnet-operator/master/hack/kubernetes/observatorium_namespace_and_secret.yaml
```

#### RBAC configuration

```
kubectl create -f https://raw.githubusercontent.com/nmagnezi/observatorium-jsonnet-operator/master/hack/kubernetes/observatorium-operator-cluster-role.yaml
kubectl create -f https://raw.githubusercontent.com/nmagnezi/observatorium-jsonnet-operator/master/hack/kubernetes/observatorium-operator-cluster-role_binding.yaml
```

### Deploy the operator
* Deployment via image taken from [quay.io](https://quay.io/repository/nmagnezi/observatorium-jsonnet-operator?tab=tags)

#### Install CRDs
```
kubectl -n observatorium create -f https://raw.githubusercontent.com/nmagnezi/observatorium-jsonnet-operator/master/config/crd/bases/obs-api.observatorium.io_observatoria.yaml
kubectl apply -f https://raw.githubusercontent.com/coreos/kube-prometheus/master/manifests/setup/prometheus-operator-0servicemonitorCustomResourceDefinition.yaml
```
#### Install Operator Manager
```
kubectl -n observatorium create -f https://raw.githubusercontent.com/nmagnezi/observatorium-operator/master/hack/kubernetes/operator.yaml
```
### Deploy CR
```
kubectl -n observatorium create -f https://raw.githubusercontent.com/nmagnezi/observatorium-jsonnet-operator/master/config/samples/obs-api_v1alpha1_observatorium.yaml
```
### Expected Outcome
```
NAME                                                                  READY   STATUS    RESTARTS   AGE
pod/observatorium-sample-cortex-query-frontend-69779db7db-6s7sx       1/1     Running   0          12m
pod/observatorium-sample-thanos-compact-0                             1/1     Running   0          12m
pod/observatorium-sample-thanos-query-59d6985f76-6vhtb                1/1     Running   0          12m
pod/observatorium-sample-thanos-receive-controller-6f7596f588-29m5x   1/1     Running   0          12m
pod/observatorium-sample-thanos-receive-default-0                     1/1     Running   0          12m
pod/observatorium-sample-thanos-receive-default-1                     1/1     Running   0          12m
pod/observatorium-sample-thanos-receive-default-2                     1/1     Running   0          12m
pod/observatorium-sample-thanos-receive-hashring0-0                   1/1     Running   0          12m
pod/observatorium-sample-thanos-receive-hashring0-1                   1/1     Running   0          12m
pod/observatorium-sample-thanos-receive-hashring0-2                   1/1     Running   0          12m
pod/observatorium-sample-thanos-rule-0                                1/1     Running   0          12m
pod/observatorium-sample-thanos-rule-1                                1/1     Running   0          12m
pod/observatorium-sample-thanos-store-0                               1/1     Running   0          12m

NAME                                                     TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                         AGE
service/observatorium-sample-cortex-query-frontend       ClusterIP   10.96.44.203    <none>        9090/TCP                        12m
service/observatorium-sample-thanos-compact              ClusterIP   10.96.67.234    <none>        10902/TCP                       12m
service/observatorium-sample-thanos-query                ClusterIP   10.96.59.53     <none>        10901/TCP,9090/TCP              12m
service/observatorium-sample-thanos-receive              ClusterIP   10.96.253.216   <none>        10901/TCP,10902/TCP,19291/TCP   12m
service/observatorium-sample-thanos-receive-controller   ClusterIP   10.96.232.5     <none>        8080/TCP                        12m
service/observatorium-sample-thanos-receive-default      ClusterIP   None            <none>        10901/TCP,10902/TCP,19291/TCP   12m
service/observatorium-sample-thanos-receive-hashring0    ClusterIP   None            <none>        10901/TCP,10902/TCP,19291/TCP   12m
service/observatorium-sample-thanos-rule                 ClusterIP   None            <none>        10901/TCP,10902/TCP             12m
service/observatorium-sample-thanos-store                ClusterIP   None            <none>        10901/TCP,10902/TCP             12m

NAME                                                             READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/observatorium-sample-cortex-query-frontend       1/1     1            1           12m
deployment.apps/observatorium-sample-thanos-query                1/1     1            1           12m
deployment.apps/observatorium-sample-thanos-receive-controller   1/1     1            1           12m

NAME                                                                        DESIRED   CURRENT   READY   AGE
replicaset.apps/observatorium-sample-cortex-query-frontend-69779db7db       1         1         1       12m
replicaset.apps/observatorium-sample-thanos-query-59d6985f76                1         1         1       12m
replicaset.apps/observatorium-sample-thanos-receive-controller-6f7596f588   1         1         1       12m

NAME                                                             READY   AGE
statefulset.apps/observatorium-sample-thanos-compact             1/1     12m
statefulset.apps/observatorium-sample-thanos-receive-default     3/3     12m
statefulset.apps/observatorium-sample-thanos-receive-hashring0   3/3     12m
statefulset.apps/observatorium-sample-thanos-rule                2/2     12m
statefulset.apps/observatorium-sample-thanos-store               1/1     12m
```

## How to deploy (OpenShift)
TBD

## Known limitations
* See [open issues](https://github.com/nmagnezi/observatorium-operator/issues)