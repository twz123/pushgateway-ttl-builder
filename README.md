# pushgateway-ttl-builder

Builds [reproducible] multi-architecture OCI container images of a
[patched][dinumathai-patches] [Prometheus Pushgateway] to be used within [k0s].
The patch set adds support for a TTL on pushed metrics, which has been [rejected
upstream][issue117].

Supported architectures:

* amd64
* arm64
* arm

[reproducible]: https://reproducible-builds.org/
[Prometheus Pushgateway]: https://prometheus.io/docs/instrumenting/pushing/
[dinumathai-patches]: https://github.com/prometheus/pushgateway/compare/v1.4.0...dinumathai:pushgateway:v1.4.0
[k0s]: https://k0sproject.io/
[issue117]: https://github.com/prometheus/pushgateway/issues/117

## Requirements

* GNU Make (v3.8.1 or newer)
* Recent versions of [Podman] or [Docker]
* [Buildah] (in conjunction with Podman) to create the multi-arch image manifest

[Podman]: https://podman.io/getting-started/installation
[Docker]: https://docs.docker.com/get-docker/
[Buildah]: https://github.com/containers/buildah/blob/main/install.md

## How it works

The building process is two-fold. To avoid any virtual machines for building,
Go's cross-compilation feature is used. The architecture-dependent images are
then built without any `RUN` directives.

**Note**: Docker won't be able to create reproducible images.

**Note**: Reproducible builds are independent of the Podman version starting
with Podman v4.2 or newer. Previous versions add their version as a label in the
produced images.

**Note**: Both Podman and Buildah are required in order to create the
multi-architecture image manifest. Docker may be used for local testing. Docker
is able to produce (non-reproducible) images, but it will fail to generate the
manifest.

## Building

Given that both `podman` and `buildah` are available:

```console
$ make
[... long build logs ...]
OCI image manifest ghcr.io/k0sproject/pushgateway-ttl:v1.4.3-k0s.latest: 45c7f0ef6ff724dbfc0348f3129616c6d88f5ed81e7722bde5ca3b78580c418d
Build timestamp: Wed Aug 24 10:04:35 UTC 2022
{
    "schemaVersion": 2,
    "mediaType": "application/vnd.docker.distribution.manifest.list.v2+json",
    "manifests": [
        {
            "mediaType": "application/vnd.oci.image.manifest.v1+json",
            "size": 684,
            "digest": "sha256:2de2023f274af1d6fd633bcc772d85018e4e872bf4acf4ff72c0144b4afd5015",
            "platform": {
                "architecture": "amd64",
                "os": "linux"
            }
        },
        {
            "mediaType": "application/vnd.oci.image.manifest.v1+json",
            "size": 820,
            "digest": "sha256:56caebf50c489b3fea851322ed3653821354aba125471f2cc7fcc51b356509eb",
            "platform": {
                "architecture": "arm64",
                "os": "linux"
            }
        },
        {
            "mediaType": "application/vnd.oci.image.manifest.v1+json",
            "size": 820,
            "digest": "sha256:6daece7e74432e635af428c5469fccd21df741bc29759984c67917d97dc30e3f",
            "platform": {
                "architecture": "arm",
                "os": "linux"
            }
        }
    ]
}
```

If only `docker` is available:

```console
$ make
[... long build logs ...]
Images have been built.
To generate the multiarch OCI manifest, use `make oci-manifest`. Requires podman and buildah.
Build timestamp: Mi 24. Aug 10:04:35 UTC 2022
1.4.3+k0s.latest amd64: sha256:4d35949af98ec21e8cb8a9304a250de50e9212529ba4b816660dd610b3973445
1.4.3+k0s.latest arm64: sha256:f737a39411677060bad82fb117ef4799df00bd3fbf59f5e0ced8fcf66b5f9b2f
1.4.3+k0s.latest arm: sha256:36533b1c09a7c86f618dbd918fc3d93d054b0955e1338141864a0180650b49a3
```

## Thanks

Thanks go out to [@dinumathai] who [created][pushgateway-ttl] the patch
set that's being used here.

[@dinumathai]: https://github.com/dinumathai
[pushgateway-ttl]: https://github.com/dinumathai/pushgateway/releases/tag/v1.4.0
