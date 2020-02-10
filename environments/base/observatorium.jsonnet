(import '../../components/observatorium.libsonnet') + {
  config+:: (import 'default-config.libsonnet'),
} + {
  config+:: (import 'generic-operator/config'),
} + (import '../../components/observatorium-configure.libsonnet')
