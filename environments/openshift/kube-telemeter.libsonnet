(import 'telemeter/server/kubernetes.libsonnet') +
(import 'telemeter/prometheus/kubernetes.libsonnet') +
{
  _config+:: {
    namespace: 'observatorium',
  },

  telemeterServer+:: {
    local image = 'quay.io/app-sre/telemeter:c205c41',

    statefulSet+: {
      spec+: {
        replicas: 3,
        template+: {
          spec+: {
            containers: [
              super.containers[0] {
                image: image,
                command+: [
                  '--token-expire-seconds=3600',
                  '--forward-url=http://%s.%s.svc.cluster.local:%d/api/v1/receive' % [
                    'thanos-receive',
                    $._config.namespace,
                    19291,
                  ],
                ],
              },
            ],
          },
        },
      },
    },
  },
  memcached+:: {
    replicas:: 1,

    statefulSet+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              super.containers[0],
              super.containers[1] {
                name: 'memcached-exporter',
              },
            ],
          },
        },
      },
    },
  },
}
