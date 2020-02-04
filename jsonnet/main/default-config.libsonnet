{
  local defaultConfig = self,

  namespace: 'observatorium',
  thanosVersion: '0.9.0',
  thanosImage: 'quay.io/thanos/thanos:v0.9.0',
  objectStorageConfig: {
    name: 'thanos-objectstorage',
    key: 'thanos.yaml',
  },

  hashrings: (import '../../tenants.libsonnet'),

  compact: {
    image: defaultConfig.thanosImage,
    version: defaultConfig.thanosVersion,
    objectStorageConfig: defaultConfig.objectStorageConfig,
    retentionResolutionRaw: '14d',
    retentionResolution5m: '1s',
    retentionResolution1h: '1s',
    volumeClaimTemplate: {
      spec: {
        accessModes: ['ReadWriteOnce'],
        resources: {
          requests: {
            storage: '50Gi',
          },
        },
      },
    },
  },

  thanosReceiveController: {
    image: 'quay.io/observatorium/thanos-receive-controller:master-2019-10-18-d55fee2',
    version: 'master-2019-10-18-d55fee2',
    hashrings: defaultConfig.hashrings,
  },

  receivers: {
    image: defaultConfig.thanosImage,
    version: defaultConfig.thanosVersion,
    hashrings: defaultConfig.hashrings,
    objectStorageConfig: defaultConfig.objectStorageConfig,
    volumeClaimTemplate: {
      spec: {
        accessModes: ['ReadWriteOnce'],
        resources: {
          requests: {
            storage: '50Gi',
          },
        },
      },
    },
  },

  rule: {
    image: defaultConfig.thanosImage,
    version: defaultConfig.thanosVersion,
    objectStorageConfig: defaultConfig.objectStorageConfig,
    volumeClaimTemplate: {
      spec: {
        accessModes: ['ReadWriteOnce'],
        resources: {
          requests: {
            storage: '50Gi',
          },
        },
      },
    },
  },

  store: {
    image: defaultConfig.thanosImage,
    version: defaultConfig.thanosVersion,
    objectStorageConfig: defaultConfig.objectStorageConfig,
    volumeClaimTemplate: {
      spec: {
        accessModes: ['ReadWriteOnce'],
        resources: {
          requests: {
            storage: '50Gi',
          },
        },
      },
    },
  },

  query: {
    image: defaultConfig.thanosImage,
    version: defaultConfig.thanosVersion,
  },

  queryCache: {
    replicas: 1,
    version: 'master-8533a216',
    image: 'quay.io/cortexproject/cortex:master-8533a216',
  },
}
