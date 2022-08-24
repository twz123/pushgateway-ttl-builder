IMAGE_NAME ?= ghcr.io/k0sproject/pushgateway-ttl
VERSION = 1.4.3
K0S_VERSION_SUFFIX = k0s.latest
SOURCE_DATE_EPOCH ?= $(shell git log -1 --pretty=%ct || date +%s)

DOCKER ?= docker
PODMAN ?= podman
BUILDAH ?= buildah

arches := amd64 arm64 arm

image := $(IMAGE_NAME):v$(VERSION)-$(K0S_VERSION_SUFFIX)
image-args-id := $(VERSION)+$(K0S_VERSION_SUFFIX)-$(SOURCE_DATE_EPOCH)

.SECONDARY: # keep all intermediate targets

.PHONY: all

ifeq "$(shell command -v $(PODMAN))" ""
BUILDX = $(DOCKER) buildx build
all: images
else
# --identity-label false
BUILDX = $(PODMAN) build --timestamp $(SOURCE_DATE_EPOCH)
DOCKER = $(PODMAN)
all: $(if "$(shell command -v $(BUILDAH))",oci-manifest,images)
endif

.PHONY: oci-manifest
oci-manifest: .manifest.$(image-args-id).iid
	$(info OCI image manifest $(image): $(shell cat -- $<))
	$(info Build timestamp: $(shell date -u -d '@$(SOURCE_DATE_EPOCH)' 2>/dev/null || date -u -r '$(SOURCE_DATE_EPOCH)' 2>/dev/null))
	@$(BUILDAH) manifest inspect -- "$$(cat -- $<)"

.PHONY: images
images: $(foreach arch,$(arches),.image.$(arch).iid)
	$(info Images have been built.)
	$(info To generate the muliatrch OCI manifest, use `$(MAKE) oci-manifest`. Requires podman and buildah.)
	$(info Build timestamp: $(shell date -u -d '@$(SOURCE_DATE_EPOCH)' 2>/dev/null || date -u -r '$(SOURCE_DATE_EPOCH)' 2>/dev/null))
	@for iidFile in $^; do \
	  printf '%s: %s\n' "$$iidFile" "$$(cat -- $$iidFile)"; \
	done

.manifest.$(image-args-id).iid: $(foreach arch,$(arches),.image.$(arch).iid)
	-$(BUILDAH) manifest rm -- $(image)
	set -- && \
	  for iidFile in $^; do \
	    iid="$$(cat -- $$iidFile)" && \
	    set -- "$$@" "$${iid#sha256:}" || \
	    exit $$?; \
	  done && { \
	    $(BUILDAH) manifest create -- $(image) "$$@" > $@.tmp || { \
	      code=$$? ; \
	      $(BUILDAH) manifest rm -- $(image); \
	      exit $$code; \
	    } \
	  }
	mv $@.tmp $@

.image.%.iid: .context.%.tar
	$(BUILDX) --iidfile $@ \
	  --platform linux/$(patsubst .image.%.iid,%,$@) \
	  - < $<

.context.%.tar: .build.%.iid
	$(DOCKER) run --rm -- "$$(cat -- $<)" > $@.tmp
	mv -- $@.tmp $@

.build.%.iid: Dockerfile.build Dockerfile.image *.patch
	$(DOCKER) build --iidfile $@ \
	  --build-arg GOARCH=$(patsubst .build.%.iid,%,$@) \
	  --build-arg VERSION=$(VERSION) \
	  --build-arg K0S_VERSION_SUFFIX=$(K0S_VERSION_SUFFIX) \
	  --build-arg SOURCE_DATE_EPOCH=$(SOURCE_DATE_EPOCH) \
	  -f $< .

clean:
	for iidFile in .manifest.*.iid; do \
	  [ -f $$iidFile ] || continue; \
	  $(DOCKER) manifest rm -f -- $$(cat -- $$iidFile); \
	  rm -- $$iidFile; \
	done
	for iidFile in .image.*.iid .build.*.iid; do \
	  [ -f $$iidFile ] || continue; \
	  $(DOCKER) rmi -f -- $$(cat -- $$iidFile); \
	  rm -- $$iidFile; \
	done
	-rm .context.*.tar .*.tmp
