local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';
local list = import 'telemeter/lib/list.libsonnet';

{
  _config+:: {
    namespace: 'observatorium',

    versions+:: {
      prometheusAms: 'v2.12.0',
      remoteWriteProxy: '14e844d',
    },

    imageRepos+:: {
      prometheusAms: 'quay.io/prometheus/prometheus',
      remoteWriteProxy: 'quay.io/app-sre/observatorium-receive-proxy',
    },

    ams+:: {
      proxyPort: 8080,
      remoteWriteTarget: 'http://%s.%s.svc.cluster.local:%d' % [
        'thanos-receive',
        '${NAMESPACE}',
        19291,
      ],
      remoteWriteProxy: 'http://%s.%s.svc.cluster.local:%d/api/v1/receive' % [
        $.prometheusRemoteWriteProxy.proxyService.metadata.name,
        '${NAMESPACE}',
        $.prometheusRemoteWriteProxy.proxyService.spec.ports[0].port,
      ],
      receiveTenantId: 'FB870BF3-9F3A-44FF-9BF7-D7A047A52F43',

      prometheus+:: {
        namespaces: [$._config.namespace],
        name: 'ams',
        replicas: 1,
        rules: {},
        renderedRules: {},
        resourceLimits: {},
        resourceRequests: {},
        remoteWrite: [
          {
            url: $._config.ams.remoteWriteProxy,
            writeRelabelConfigs: [
              {
                sourceLabels: ['__name__'],
                regex: 'subscription_labels',
                action: 'keep',
              },
            ],
          },
        ],
      },
    },
  },

  prometheusAms+:: {
    local commonLabels = {
      'app.kubernetes.io/part-of': 'prometheus-ams',
      'app.kubernetes.io/name': 'prometheus',
      'app.kubernetes.io/instance': 'ams',
    },
    service:
      local service = k.core.v1.service;
      local servicePort = k.core.v1.service.mixin.spec.portsType;

      local prometheusPort = servicePort.newNamed('web', 9090, 'web');

      service.new('prometheus-' + $._config.ams.prometheus.name, { prometheus: $._config.ams.prometheus.name }, prometheusPort) +
      service.mixin.spec.withSessionAffinity('ClientIP') +
      service.mixin.metadata.withNamespace($._config.namespace) +
      service.mixin.metadata.withLabels(commonLabels { prometheus: $._config.ams.prometheus.name }),
    [if $._config.ams.prometheus.rules != null && $._config.ams.prometheus.rules != {} then 'rules']:
      {
        apiVersion: 'monitoring.coreos.com/v1',
        kind: 'PrometheusRule',
        metadata: {
          labels: commonLabels {
            prometheus: $._config.ams.prometheus.name,
            role: 'alert-rules',
          },
          name: 'prometheus-' + $._config.ams.prometheus.name + '-rules',
          namespace: $._config.namespace,
        },
        spec: {
          groups: $._config.ams.prometheus.rules.groups,
        },
      },
    prometheus:
      local statefulSet = k.apps.v1.statefulSet;
      local container = statefulSet.mixin.spec.template.spec.containersType;
      local resourceRequirements = container.mixin.resourcesType;
      local selector = statefulSet.mixin.spec.selectorType;
      local deployment = k.apps.v1.deployment;

      local resources =
        resourceRequirements.new() +
        resourceRequirements.withLimits({
          cpu: '${PROMETHEUS_AMS_CPU_LIMIT}',
          memory: '${PROMETHEUS_AMS_MEMORY_LIMIT}',
        }) +
        resourceRequirements.withRequests({
          cpu: '${PROMETHEUS_AMS_CPU_REQUEST}',
          memory: '${PROMETHEUS_AMS_MEMORY_REQUEST}',
        });

      {
        apiVersion: 'monitoring.coreos.com/v1',
        kind: 'Prometheus',
        metadata: {
          name: $._config.ams.prometheus.name,
          namespace: $._config.namespace,
          labels: commonLabels {
            prometheus: $._config.ams.prometheus.name,
          },
        },
        spec: {
          replicas: $._config.ams.prometheus.replicas,
          version: '${PROMETHEUS_AMS_IMAGE_TAG}',
          baseImage: '${PROMETHEUS_AMS_IMAGE}',
          securityContext: {},
          serviceAccount: 'prometheus-telemeter',
          serviceAccountName: 'prometheus-telemeter',
          serviceMonitorSelector: selector.withMatchLabels({
            prometheus: $._config.ams.prometheus.name,
          }),
          ruleSelector: selector.withMatchLabels({
            role: 'alert-rules',
            prometheus: $._config.ams.prometheus.name,
          }),
          resources: resources,
          remoteWrite: $._config.ams.prometheus.remoteWrite,
          containers: [],
        },
      },
    serviceMonitor:
      {
        apiVersion: 'monitoring.coreos.com/v1',
        kind: 'ServiceMonitor',
        metadata: {
          name: 'prometheus-' + $._config.ams.prometheus.name,
          namespace: $._config.namespace,
          labels: commonLabels,
        },
        spec: {
          selector: {
            matchLabels: {
              'app.kubernetes.io/name': 'prometheus',
              'app.kubernetes.io/instance': 'ams',
            },
          },
          endpoints: [
            {
              port: 'web',
              interval: '30s',
            },
          ],
        },
      },
  },

  prometheusRemoteWriteProxy+:: {
    local commonLabels = {
      'app.kubernetes.io/part-of': 'prometheus-ams',
      'app.kubernetes.io/name': 'nginx',
      'app.kubernetes.io/instance': 'remote-write-proxy',

    },
    local selectorLabels = {
      'app.kubernetes.io/name': 'nginx',
      'app.kubernetes.io/instance': 'remote-write-proxy',
    },
    proxyService:
      local service = k.core.v1.service;
      local servicePort = k.core.v1.service.mixin.spec.portsType;

      local port = servicePort.newNamed('http', 8080, 'http');

      service.new('prometheus-%s-remote-write-proxy' % $._config.ams.prometheus.name, selectorLabels, port) +
      service.mixin.metadata.withNamespace($._config.namespace) +
      service.mixin.metadata.withLabels(commonLabels),
    deployment:
      local deployment = k.apps.v1.deployment;
      local container = deployment.mixin.spec.template.spec.containersType;
      local containerPort = container.portsType;
      local containerVolumeMount = container.volumeMountsType;
      local volumeMount = container.volumeMountsType;

      local c =
        container.new('remote-write-proxy', '${PROMETHEUS_AMS_REMOTE_WRITE_PROXY_IMAGE}:${PROMETHEUS_AMS_REMOTE_WRITE_PROXY_VERSION}') +
        container.withCommand('nginx') +
        container.withArgs([
          '-c',
          '/config/nginx.conf',
        ]) +
        container.withPorts([{ name: 'http', containerPort: $._config.ams.proxyPort }]) +
        container.mixin.resources.withRequests({ cpu: '50m', memory: '16Mi' }) +
        container.mixin.resources.withLimits({ cpu: '100m', memory: '64Mi' }) +
        container.withVolumeMounts([volumeMount.new($.prometheusRemoteWriteProxy.configmap.metadata.name, '/config', true)]);

      deployment.new('prometheus-remote-write-proxy', 1, c, selectorLabels) +
      deployment.mixin.metadata.withNamespace($._config.namespace) +
      deployment.mixin.metadata.withLabels(commonLabels) +
      deployment.mixin.spec.selector.withMatchLabels(selectorLabels) +
      deployment.mixin.spec.template.spec.withVolumes([
        { name: $.prometheusRemoteWriteProxy.configmap.metadata.name, configMap: { name: $.prometheusRemoteWriteProxy.configmap.metadata.name } },
      ]),
    configmap:
      local configmap = k.core.v1.configMap;

      configmap.new() +
      configmap.mixin.metadata.withName('prometheus-remote-write-proxy-config') +
      configmap.mixin.metadata.withNamespace($._config.namespace) +
      configmap.mixin.metadata.withLabels(commonLabels) +
      configmap.withData({
        local f = importstr './prometheus/remote_write_proxy.conf',

        'nginx.conf': std.format(f, {
          listen_port: $._config.ams.proxyPort,
          dns_resolver: $._config.ams.dnsResolver,
          forward_host: $._config.ams.remoteWriteTarget,
          thanos_tenant: $._config.ams.receiveTenantId,
        }),
      }),
  },
} + {
  local prom = super.prometheusAms,
  local proxy = super.prometheusRemoteWriteProxy,
  prometheusAms+:: {
    template+:
      list.asList('prometheus-observatorium-ams', prom + proxy, [
        {
          name: 'PROMETHEUS_AMS_REMOTE_WRITE_PROXY_IMAGE',
          value: $._config.imageRepos.remoteWriteProxy,
        },
        {
          name: 'PROMETHEUS_AMS_REMOTE_WRITE_PROXY_VERSION',
          value: $._config.versions.remoteWriteProxy,
        },
        {
          name: 'PROMETHEUS_AMS_IMAGE',
          value: $._config.imageRepos.prometheusAms,
        },
        {
          name: 'PROMETHEUS_AMS_IMAGE_TAG',
          value: $._config.versions.prometheusAms,
        },
        {
          name: 'PROMETHEUS_AMS_CPU_REQUEST',
          value: if std.objectHas($._config.ams.prometheus.resourceRequests, 'cpu') then $._config.ams.prometheus.resourceRequests.cpu else '0',
        },
        {
          name: 'PROMETHEUS_AMS_CPU_LIMIT',
          value: if std.objectHas($._config.ams.prometheus.resourceLimits, 'cpu') then $._config.ams.prometheus.resourceLimits.cpu else '0',
        },
        {
          name: 'PROMETHEUS_AMS_MEMORY_REQUEST',
          value: if std.objectHas($._config.ams.prometheus.resourceRequests, 'memory') then $._config.ams.prometheus.resourceRequests.memory else '0',
        },
        {
          name: 'PROMETHEUS_AMS_MEMORY_LIMIT',
          value: if std.objectHas($._config.ams.prometheus.resourceLimits, 'memory') then $._config.ams.prometheus.resourceLimits.memory else '0',
        },
      ]) +
      list.withNamespace($._config),
  } + {
    local setNamespace(object) =
      if std.objectHas(object, 'metadata') && std.objectHas(object.metadata, 'namespace') then {
        metadata+: {
          namespace: '${NAMESPACE}',
        },
      },
    local setSubjectNamespace(object) =
      if std.endsWith(object.kind, 'Binding') then {
        subjects: [
          s { namespace: '${NAMESPACE}' }
          for s in super.subjects
        ],
      }
      else {},
    template+: {
      objects: [
        if std.objectHas(o, 'items') then o {
          items: [i + setNamespace(i) + setSubjectNamespace(i) for i in super.items],
        } else o
        for o in super.objects
      ],
    },
  },

  apiVersion: 'v1',
  kind: 'Template',
  metadata: {
    name: 'observatorium-prometheus',
  },
  objects: $.prometheusAms.template.objects,
  parameters: $.prometheusAms.template.parameters,
}
