{
  local defaultConfig = self,

  name: 'observatorium-xyz',
  namespace: 'observatorium',
  thanosVersion: 'v0.9.0',
  thanosImage: 'yesssssss:' + defaultConfig.thanosVersion,
  objectStorageConfig: {
    name: 'thanos-objectstorage',
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
    local trcConfig = self,
    version: 'master-2019-10-18-d55fee2',
    image: 'quay.io/observatorium/thanos-receive-controller:' + trcConfig.version,
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
    local qcConfig = self,
    replicas: 1,
    version: 'master-8533a216',
    image: 'quay.io/cortexproject/cortex:' + qcConfig.version,
  },
}
