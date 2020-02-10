local t = (import 'kube-thanos/thanos.libsonnet');
local trc = (import 'thanos-receive-controller/thanos-receive-controller.libsonnet');
local cqf = (import '../../components/cortex-query-frontend.libsonnet');

(import '../../components/observatorium.libsonnet') {
  local obs = self,

  local s3EnvVars = [
    {
      name: 'AWS_ACCESS_KEY_ID',
      valueFrom: {
        secretKeyRef: {
          key: 'aws_access_key_id',
          name: '${THANOS_S3_SECRET}',
        },
      },
    },
    {
      name: 'AWS_SECRET_ACCESS_KEY',
      valueFrom: {
        secretKeyRef: {
          key: 'aws_secret_access_key',
          name: '${THANOS_S3_SECRET}',
        },
      },
    },
  ],

  compact+::
    t.compact.withResources +
    (import '../../components/jaeger-agent.libsonnet').statefulSetMixin {
      statefulSet+: {
        spec+: {
          template+: {
            spec+: {
              containers: [
                if c.name == 'thanos-compact' then c {
                  env+: s3EnvVars,
                } else c
                for c in super.containers
              ],
            },
          },
        },
      },
    },

  thanosReceiveController+::
    trc.withResources,

  rule+::
    t.rule.withResources +
    (import '../../components/jaeger-agent.libsonnet').statefulSetMixin {
      statefulSet+: {
        spec+: {
          template+: {
            spec+: {
              containers: [
                if c.name == 'thanos-rule' then c {
                  env+: s3EnvVars,
                } else c
                for c in super.containers
              ],
            },
          },
        },
      },
    },

  store+::
    t.store.withVolumeClaimTemplate +
    t.store.withResources +
    (import '../../components/jaeger-agent.libsonnet').statefulSetMixin {
      statefulSet+: {
        spec+: {
          template+: {
            spec+: {
              containers: [
                if c.name == 'thanos-store' then c {
                  env+: s3EnvVars,
                } else c
                for c in super.containers
              ],
            },
          },
        },
      },
    },

  receivers+:: {
    [hashring.hashring]+:
      t.receive.withVolumeClaimTemplate +
      t.receive.withPodDisruptionBudget +
      t.receive.withResources {
        statefulSet+: {
          spec+: {
            template+: {
              spec+: {
                containers: [
                  if c.name == 'thanos-receive' then c {
                    env+: s3EnvVars,
                  } else c
                  for c in super.containers
                ],
              },
            },
          },
        },
      } + (import '../../components/jaeger-agent.libsonnet').statefulSetMixin
    for hashring in obs.config.hashrings
  },

  query+::
    t.query.withResources +
    t.query.withExternalPrefix +
    (import '../../components/oauth-proxy.libsonnet') +
    (import '../../components/jaeger-agent.libsonnet').deploymentMixin,

  queryCache+::
    cqf.withResources +
    (import '../../components/oauth-proxy.libsonnet'),
} + {
  local obs = self,

  config+:: {
    name: 'observatorium',
    namespace:: '${NAMESPACE}',
    thanosImage:: '${THANOS_IMAGE}:${THANOS_IMAGE_TAG}',
    thanosVersion: '${THANOS_IMAGE_TAG}',
    oauthProxyImage:: '${PROXY_IMAGE}:${PROXY_IMAGE_TAG}',
    jaegerAgentImage:: '${JAEGER_AGENT_IMAGE}:${JAEGER_AGENT_IMAGE_TAG}',
    jaegerAgentCollectorAddress:: 'dns:///jaeger-collector-headless.$(NAMESPACE).svc:14250',
    objectStorageConfig:: {
      name: '${THANOS_CONFIG_SECRET}',
      key: 'thanos.yaml',
    },

    hashrings: [
      {
        hashring: 'default',
        tenants: [
          // Match all for now
          // 'foo',
          // 'bar',
        ],
      },
    ],

    compact+: {
      image: obs.config.thanosImage,
      version: obs.config.thanosVersion,
      objectStorageConfig: obs.config.objectStorageConfig,
      retentionResolutionRaw: '14d',
      retentionResolution5m: '1s',
      retentionResolution1h: '1s',
      resources: {
        replicas: '${{THANOS_COMPACTOR_REPLICAS}}',
        requests: {
          cpu: '${THANOS_COMPACTOR_CPU_REQUEST}',
          memory: '${THANOS_COMPACTOR_MEMORY_REQUEST}',
        },
        limits: {
          cpu: '${THANOS_COMPACTOR_CPU_LIMIT}',
          memory: '${THANOS_COMPACTOR_MEMORY_LIMIT}',
        },
      },
      jaegerAgent: {
        image: obs.config.jaegerAgentImage,
        collectorAddress: obs.config.jaegerAgentCollectorAddress,
      },
    },

    thanosReceiveController+: {
      image: '${THANOS_RECEIVE_CONTROLLER_IMAGE}:${THANOS_RECEIVE_CONTROLLER_IMAGE_TAG}',
      version: '${THANOS_RECEIVE_CONTROLLER_IMAGE_TAG}',
      hashrings: obs.config.hashrings,
      resources: {
        requests: {
          cpu: '10m',
          memory: '24Mi',
        },
        limits: {
          cpu: '64m',
          memory: '128Mi',
        },
      },
      jaegerAgent: {
        image: obs.config.jaegerAgentImage,
        collectorAddress: obs.config.jaegerAgentCollectorAddress,
      },
    },

    receivers+: {
      image: obs.config.thanosImage,
      version: obs.config.thanosVersion,
      objectStorageConfig: obs.config.objectStorageConfig,
      hashrings: obs.config.hashrings,
      podDisruptionBudgetMinAvailable: 2,
      replicas: '${{THANOS_RECEIVE_REPLICAS}}',
      resources: {
        requests: {
          cpu: '${THANOS_RECEIVE_CPU_REQUEST}',
          memory: '${THANOS_RECEIVE_MEMORY_REQUEST}',
        },
        limits: {
          cpu: '${THANOS_RECEIVE_CPU_LIMIT}',
          memory: '${THANOS_RECEIVE_MEMORY_LIMIT}',
        },
      },
      volumeClaimTemplate: {
        spec: {
          accessModes: ['ReadWriteOnce'],
          resources: {
            requests: {
              storage: '50Gi',
            },
          },
          storageClassName: 'gp2-encrypted',
        },
      },
      jaegerAgent: {
        image: obs.config.jaegerAgentImage,
        collectorAddress: obs.config.jaegerAgentCollectorAddress,
      },
    },

    rule+: {
      image: obs.config.thanosImage,
      version: obs.config.thanosVersion,
      objectStorageConfig: obs.config.objectStorageConfig,
      replicas: '${{THANOS_RULER_REPLICAS}}',
      resources: {
        requests: {
          cpu: '${THANOS_RULER_CPU_REQUEST}',
          memory: '${THANOS_RULER_MEMORY_REQUEST}',
        },
        limits: {
          cpu: '${THANOS_RULER_CPU_LIMIT}',
          memory: '${THANOS_RULER_MEMORY_LIMIT}',
        },
      },
      jaegerAgent: {
        image: obs.config.jaegerAgentImage,
        collectorAddress: obs.config.jaegerAgentCollectorAddress,
      },
    },

    store+: {
      image: obs.config.thanosImage,
      version: obs.config.thanosVersion,
      objectStorageConfig: obs.config.objectStorageConfig,
      replicas: '${{THANOS_STORE_REPLICAS}}',
      resources: {
        requests: {
          cpu: '${THANOS_STORE_CPU_REQUEST}',
          memory: '${THANOS_STORE_MEMORY_REQUEST}',
        },
        limits: {
          cpu: '${THANOS_STORE_CPU_LIMIT}',
          memory: '${THANOS_STORE_MEMORY_LIMIT}',
        },
      },
      volumeClaimTemplate: {
        spec: {
          accessModes: ['ReadWriteOnce'],
          resources: {
            requests: {
              storage: '50Gi',
            },
          },
          storageClassName: 'gp2-encrypted',
        },
      },
      jaegerAgent: {
        image: obs.config.jaegerAgentImage,
        collectorAddress: obs.config.jaegerAgentCollectorAddress,
      },
    },

    query+: {
      image: obs.config.thanosImage,
      version: obs.config.thanosVersion,
      replicas: '${{THANOS_QUERIER_REPLICAS}}',
      externalPrefix: '/ui/v1/metrics',
      resources: {
        requests: {
          cpu: '${THANOS_QUERIER_CPU_REQUEST}',
          memory: '${THANOS_QUERIER_MEMORY_REQUEST}',
        },
        limits: {
          cpu: '${THANOS_QUERIER_CPU_LIMIT}',
          memory: '${THANOS_QUERIER_MEMORY_LIMIT}',
        },
      },
      oauthProxy: {
        image: obs.config.oauthProxyImage,
        httpsPort: 9091,
        upstream: 'http://localhost:' + obs.query.service.spec.ports[1].port,
        tlsSecretName: 'query-tls',
        sessionSecretName: 'query-proxy',
        sessionSecret: '',
        serviceAccountName: 'prometheus-telemeter',
        resources: {
          requests: {
            cpu: '${JAEGER_PROXY_CPU_REQUEST}',
            memory: '${JAEGER_PROXY_MEMORY_REQUEST}',
          },
          limits: {
            cpu: '${JAEGER_PROXY_CPU_LIMITS}',
            memory: '${JAEGER_PROXY_MEMORY_LIMITS}',
          },
        },
      },
      jaegerAgent: {
        image: obs.config.jaegerAgentImage,
        collectorAddress: obs.config.jaegerAgentCollectorAddress,
      },
    },

    queryCache+: {
      local qcConfig = self,
      version: 'master-8533a216',
      image: 'quay.io/cortexproject/cortex:' + qcConfig.version,
      replicas: 3,
      resources: {
        requests: {
          cpu: '${THANOS_QUERIER_CACHE_CPU_REQUEST}',
          memory: '${THANOS_QUERIER_CACHE_MEMORY_REQUEST}',
        },
        limits: {
          cpu: '${THANOS_QUERIER_CACHE_CPU_LIMIT}',
          memory: '${THANOS_QUERIER_CACHE_MEMORY_LIMIT}',
        },
      },
      oauthProxy: {
        image: obs.config.oauthProxyImage,
        httpsPort: 9091,
        upstream: 'http://localhost:' + obs.query.service.spec.ports[1].port,
        tlsSecretName: 'query-cache-tls',
        sessionSecretName: 'query-cache-proxy',
        sessionSecret: '',
        serviceAccountName: 'prometheus-telemeter',
        resources: {
          requests: {
            cpu: '${JAEGER_PROXY_CPU_REQUEST}',
            memory: '${JAEGER_PROXY_MEMORY_REQUEST}',
          },
          limits: {
            cpu: '${JAEGER_PROXY_CPU_LIMITS}',
            memory: '${JAEGER_PROXY_MEMORY_LIMITS}',
          },
        },
      },
    },
  },
} + (import '../../components/observatorium-configure.libsonnet') + {
  local obs = self,

  local telemeter = (import 'telemeter.jsonnet') {
    _config+:: {
      namespace: obs.config.namespace,
    },
  },

  local prometheusAMS = (import 'telemeter-prometheus-ams.jsonnet') {
    _config+:: {
      namespace: obs.config.namespace,
    },
  },

  openshiftTemplate:: {
    apiVersion: 'v1',
    kind: 'Template',
    metadata: {
      name: 'observatorium',
    },
    objects: [
      obs.manifests[name]
      for name in std.objectFields(obs.manifests)
    ] + telemeter.objects + prometheusAMS.objects,
    parameters: [
      {
        name: 'NAMESPACE',
        value: 'telemeter',
      },
      {
        name: 'THANOS_IMAGE',
        value: 'quay.io/thanos/thanos',
      },
      {
        name: 'THANOS_IMAGE_TAG',
        value: 'v0.9.0',
      },
      {
        name: 'PROXY_IMAGE',
        value: 'openshift/oauth-proxy',
      },
      {
        name: 'PROXY_IMAGE_TAG',
        value: 'v1.1.0',
      },
      {
        name: 'JAEGER_AGENT_IMAGE',
        value: 'jaegertracing/jaeger-agent',
      },
      {
        name: 'JAEGER_AGENT_IMAGE_TAG',
        value: '1.14.0',
      },
      {
        name: 'THANOS_RECEIVE_CONTROLLER_IMAGE',
        value: 'quay.io/observatorium/thanos-receive-controller',
      },
      {
        name: 'THANOS_RECEIVE_CONTROLLER_IMAGE_TAG',
        value: 'master-2019-10-18-d55fee2',
      },
      {
        name: 'THANOS_QUERIER_REPLICAS',
        value: '3',
      },
      {
        name: 'THANOS_STORE_REPLICAS',
        value: '5',
      },
      {
        name: 'THANOS_COMPACTOR_REPLICAS',
        value: '1',
      },
      {
        name: 'THANOS_RECEIVE_REPLICAS',
        value: '5',
      },
      {
        name: 'THANOS_CONFIG_SECRET',
        value: 'thanos-objectstorage',
      },
      {
        name: 'THANOS_S3_SECRET',
        value: 'telemeter-thanos-stage-s3',
      },
      {
        name: 'THANOS_QUERIER_CPU_REQUEST',
        value: '100m',
      },
      {
        name: 'THANOS_QUERIER_CPU_LIMIT',
        value: '1',
      },
      {
        name: 'THANOS_QUERIER_MEMORY_REQUEST',
        value: '256Mi',
      },
      {
        name: 'THANOS_QUERIER_MEMORY_LIMIT',
        value: '1Gi',
      },
      {
        name: 'THANOS_QUERIER_CACHE_CPU_REQUEST',
        value: '100m',
      },
      {
        name: 'THANOS_QUERIER_CACHE_CPU_LIMIT',
        value: '1',
      },
      {
        name: 'THANOS_QUERIER_CACHE_MEMORY_REQUEST',
        value: '256Mi',
      },
      {
        name: 'THANOS_QUERIER_CACHE_MEMORY_LIMIT',
        value: '1Gi',
      },
      {
        name: 'THANOS_STORE_CPU_REQUEST',
        value: '500m',
      },
      {
        name: 'THANOS_STORE_CPU_LIMIT',
        value: '2',
      },
      {
        name: 'THANOS_STORE_MEMORY_REQUEST',
        value: '1Gi',
      },
      {
        name: 'THANOS_STORE_MEMORY_LIMIT',
        value: '8Gi',
      },
      {
        name: 'THANOS_RECEIVE_CPU_REQUEST',
        value: '100m',
      },
      {
        name: 'THANOS_RECEIVE_CPU_LIMIT',
        value: '1',
      },
      {
        name: 'THANOS_RECEIVE_MEMORY_REQUEST',
        value: '512Mi',
      },
      {
        name: 'THANOS_RECEIVE_MEMORY_LIMIT',
        value: '1Gi',
      },
      {
        name: 'THANOS_COMPACTOR_CPU_REQUEST',
        value: '100m',
      },
      {
        name: 'THANOS_COMPACTOR_CPU_LIMIT',
        value: '1',
      },
      {
        name: 'THANOS_COMPACTOR_MEMORY_REQUEST',
        value: '1Gi',
      },
      {
        name: 'THANOS_COMPACTOR_MEMORY_LIMIT',
        value: '5Gi',
      },
      {
        name: 'THANOS_RULER_REPLICAS',
        value: '2',
      },
      {
        name: 'THANOS_RULER_CPU_REQUEST',
        value: '100m',
      },
      {
        name: 'THANOS_RULER_CPU_LIMIT',
        value: '1',
      },
      {
        name: 'THANOS_RULER_MEMORY_REQUEST',
        value: '512Mi',
      },
      {
        name: 'THANOS_RULER_MEMORY_LIMIT',
        value: '1Gi',
      },
      {
        name: 'THANOS_QUERIER_SVC_URL',
        value: 'http://thanos-querier.observatorium.svc:9090',
      },
      {
        name: 'JAEGER_PROXY_CPU_REQUEST',
        value: '100m',
      },
      {
        name: 'JAEGER_PROXY_MEMORY_REQUEST',
        value: '100Mi',
      },
      {
        name: 'JAEGER_PROXY_CPU_LIMITS',
        value: '200m',
      },
      {
        name: 'JAEGER_PROXY_MEMORY_LIMITS',
        value: '200Mi',
      },
      {
        name: 'AUTHORIZE_URL',
        value: 'https://api.openshift.com/api/accounts_mgmt/v1/cluster_registrations',
      },
      {
        name: 'IMAGE',
        value: 'quay.io/openshift/origin-telemeter',
      },
      {
        name: 'IMAGE_TAG',
        value: 'v4.0',
      },
      {
        name: 'TELEMETER_SERVER_CPU_REQUEST',
        value: '100m',
      },
      {
        name: 'TELEMETER_SERVER_CPU_LIMIT',
        value: '1',
      },
      {
        name: 'TELEMETER_SERVER_MEMORY_REQUEST',
        value: '500Mi',
      },
      {
        name: 'TELEMETER_SERVER_MEMORY_LIMIT',
        value: '1Gi',
      },
      {
        name: 'MEMCACHED_IMAGE',
        value: 'docker.io/memcached',
      },
      {
        name: 'MEMCACHED_IMAGE_TAG',
        value: '1.5.20-alpine',
      },
      {
        name: 'MEMCACHED_EXPORTER_IMAGE',
        value: 'docker.io/prom/memcached-exporter',
      },
      {
        name: 'MEMCACHED_EXPORTER_IMAGE_TAG',
        value: 'v0.6.0',
      },
      {
        name: 'MEMCACHED_CPU_REQUEST',
        value: '500m',
      },
      {
        name: 'MEMCACHED_CPU_LIMIT',
        value: '3',
      },
      {
        name: 'MEMCACHED_MEMORY_REQUEST',
        value: '1329Mi',
      },
      {
        name: 'MEMCACHED_MEMORY_LIMIT',
        value: '1844Mi',
      },
      {
        name: 'MEMCACHED_EXPORTER_CPU_REQUEST',
        value: '50m',
      },
      {
        name: 'MEMCACHED_EXPORTER_CPU_LIMIT',
        value: '200m',
      },
      {
        name: 'MEMCACHED_EXPORTER_MEMORY_REQUEST',
        value: '50Mi',
      },
      {
        name: 'MEMCACHED_EXPORTER_MEMORY_LIMIT',
        value: '200Mi',
      },
      {
        name: 'TELEMETER_FORWARD_URL',
        value: '',
      },
      {
        name: 'PROMETHEUS_AMS_REMOTE_WRITE_PROXY_IMAGE',
        value: 'quay.io/app-sre/observatorium-receive-proxy',
      },
      {
        name: 'PROMETHEUS_AMS_REMOTE_WRITE_PROXY_VERSION',
        value: '14e844d',
      },
      {
        name: 'PROMETHEUS_AMS_IMAGE',
        value: 'quay.io/prometheus/prometheus',
      },
      {
        name: 'PROMETHEUS_AMS_IMAGE_TAG',
        value: 'v2.12.0',
      },
      {
        name: 'PROMETHEUS_AMS_CPU_REQUEST',
        value: '0',
      },
      {
        name: 'PROMETHEUS_AMS_CPU_LIMIT',
        value: '0',
      },
      {
        name: 'PROMETHEUS_AMS_MEMORY_REQUEST',
        value: '0',
      },
      {
        name: 'PROMETHEUS_AMS_MEMORY_LIMIT',
        value: '0',
      },
    ],
  },
}
