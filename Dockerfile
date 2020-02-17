# Build the manager binary
FROM golang:1.13 as builder
WORKDIR /workspace
# Copy the jsonnet source
COPY jsonnet/ jsonnet/
COPY components/ components/
COPY jsonnetfile.json jsonnetfile.json
# Build
RUN GO111MODULE="on" go get github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb
RUN jb install
RUN GO111MODULE="on" go get github.com/brancz/locutus


FROM registry.access.redhat.com/ubi8/ubi-minimal
WORKDIR /
COPY --from=builder /go/bin/locutus .
COPY --from=builder /workspace/jsonnet/ ./jsonnet/
COPY --from=builder /workspace/components/ ./components/
COPY --from=builder /workspace/vendor/ ./vendor/
ENTRYPOINT ["/locutus", "--renderer=jsonnet", "--renderer.jsonnet.entrypoint=jsonnet/main/main.jsonnet", "--trigger=resource", "--trigger.resource.config=jsonnet/main/config.yaml"]
