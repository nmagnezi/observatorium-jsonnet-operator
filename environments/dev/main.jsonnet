local obs = (import '../base/observatorium.jsonnet');
local minio = (import '../../components/minio.libsonnet') + {
  config:: {
    namespace: obs.config.namespace,
  },
};

obs.manifests +
minio.manifests
