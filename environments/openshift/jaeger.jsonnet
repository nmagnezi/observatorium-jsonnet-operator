local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

local app =
  (import 'kube-jaeger.libsonnet') + {
    jaeger+:: {
      namespace:: '${NAMESPACE}',
      image:: '${IMAGE}:${IMAGE_TAG}',
      replicas:: '${{REPLICAS}}',  // additional parenthesis does matter, they convert argument to an int.
      pvc+:: {
        class: 'gp2-encrypted',
      },

      queryService+: {
        metadata+: {
          annotations+: {
            'service.alpha.openshift.io/serving-cert-secret-name': 'jaeger-query-tls',
          },
        },
        spec+: {
          ports+: [
            { name: 'https', port: 16687, targetPort: 16687 },
          ],
        },
      },

      local deployment = k.apps.v1.deployment,
      local volume = deployment.mixin.spec.template.spec.volumesType,
      local container = deployment.mixin.spec.template.spec.containersType,
      local volumeMount = container.volumeMountsType,

      deployment+: {
        spec+: {
          template+: {
            spec+: {
              containers+: [
                container.new('proxy', '${PROXY_IMAGE}:${PROXY_IMAGE_TAG}') +
                container.withArgs([
                  '-provider=openshift',
                  '-https-address=:%d' % $.jaeger.queryService.spec.ports[1].port,
                  '-http-address=',
                  '-email-domain=*',
                  '-upstream=http://localhost:%d' % $.jaeger.queryService.spec.ports[0].port,
                  '-openshift-service-account=prometheus-telemeter',
                  '-openshift-sar={"resource": "namespaces", "verb": "get", "name": "${NAMESPACE}", "namespace": "${NAMESPACE}"}',
                  '-openshift-delegate-urls={"/": {"resource": "namespaces", "verb": "get", "name": "${NAMESPACE}", "namespace": "${NAMESPACE}"}}',
                  '-tls-cert=/etc/tls/private/tls.crt',
                  '-tls-key=/etc/tls/private/tls.key',
                  '-client-secret-file=/var/run/secrets/kubernetes.io/serviceaccount/token',
                  '-cookie-secret-file=/etc/proxy/secrets/session_secret',
                  '-openshift-ca=/etc/pki/tls/cert.pem',
                  '-openshift-ca=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt',
                ]) +
                container.withPorts([
                  { name: 'https', containerPort: $.jaeger.queryService.spec.ports[1].port },
                ]) +
                container.withVolumeMounts(
                  [
                    volumeMount.new('secret-jaeger-query-tls', '/etc/tls/private'),
                    volumeMount.new('secret-jaeger-proxy', '/etc/proxy/secrets'),
                  ]
                ) +
                container.mixin.resources.withRequests({
                  cpu: '${JAEGER_PROXY_CPU_REQUEST}',
                  memory: '${JAEGER_PROXY_MEMORY_REQUEST}',
                }) +
                container.mixin.resources.withLimits({
                  cpu: '${JAEGER_PROXY_CPU_LIMITS}',
                  memory: '${JAEGER_PROXY_MEMORY_LIMITS}',
                }),
              ],

              serviceAccount: 'prometheus-telemeter',
              serviceAccountName: 'prometheus-telemeter',
              volumes+: [
                { name: 'secret-jaeger-query-tls', secret: { secretName: 'jaeger-query-tls' } },
                { name: 'secret-jaeger-proxy', secret: { secretName: 'jaeger-proxy' } },
              ],
            },
          },
        },
      },
    },
  };

{
  apiVersion: 'v1',
  kind: 'Template',
  metadata: {
    name: 'jaeger',
  },
  objects: [
    app.jaeger[name]
    for name in std.objectFields(app.jaeger)
  ],
  parameters: [
    { name: 'NAMESPACE', value: 'telemeter' },
    { name: 'IMAGE', value: 'jaegertracing/all-in-one' },
    { name: 'IMAGE_TAG', value: '1.14.0' },
    { name: 'REPLICAS', value: '1' },
    { name: 'PROXY_IMAGE', value: 'openshift/oauth-proxy' },
    { name: 'PROXY_IMAGE_TAG', value: 'v1.1.0' },
    { name: 'JAEGER_PROXY_CPU_REQUEST', value: '100m' },
    { name: 'JAEGER_PROXY_MEMORY_REQUEST', value: '100Mi' },
    { name: 'JAEGER_PROXY_CPU_LIMITS', value: '200m' },
    { name: 'JAEGER_PROXY_MEMORY_LIMITS', value: '200Mi' },
  ],
}
