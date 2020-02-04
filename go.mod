module github.com/nmagnezi/observatorium-jsonnet-operator

go 1.13

require (
	github.com/blang/semver v3.5.1+incompatible
	github.com/brancz/locutus v0.0.0-20200203092704-53b46056aee5
	github.com/go-kit/kit v0.9.0
	github.com/go-logfmt/logfmt v0.5.0 // indirect
	github.com/go-logr/logr v0.1.0
	github.com/go-openapi/spec v0.19.2
	github.com/go-openapi/swag v0.19.4
	github.com/google/go-jsonnet v0.14.0
	github.com/ksonnet/ksonnet-lib v0.1.12
	github.com/oklog/run v1.0.0
	github.com/onsi/ginkgo v1.12.0
	github.com/onsi/gomega v1.9.0
	github.com/pkg/errors v0.8.1
	github.com/prometheus/client_golang v1.1.0
	github.com/stretchr/testify v1.4.0
	k8s.io/api v0.17.1
	k8s.io/apimachinery v0.17.1
	k8s.io/client-go v12.0.0+incompatible
	sigs.k8s.io/controller-runtime v0.4.0
)

replace k8s.io/client-go => k8s.io/client-go v0.0.0-20190918160344-1fbdaa4c8d90
