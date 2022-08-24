IMAGE_NAME ?= ghcr.io/k0sproject/pushgateway-ttl
VERSION = 1.4.3
K0S_VERSION_SUFFIX = k0s.latest
SOURCE_DATE_EPOCH ?= $(shell git log -1 --pretty=%ct || date +%s)

DOCKER ?= docker
PODMAN ?= podman
BUILDAH ?= buildah

arches := amd64 arm64 arm

image := $(IMAGE_NAME):v$(VERSION)-$(K0S_VERSION_SUFFIX)
buildDir := .build/$(VERSION)+$(K0S_VERSION_SUFFIX)-$(SOURCE_DATE_EPOCH)

.SECONDARY: # keep all intermediate targets

.PHONY: all

ifeq "$(shell command -v $(PODMAN))" ""
BUILDX = $(DOCKER) buildx build
all: images
else
BUILDX = $(PODMAN) build --identity-label=false --timestamp $(SOURCE_DATE_EPOCH)
DOCKER = $(PODMAN)
all: $(if "$(shell command -v $(BUILDAH))",oci-manifest,images)
endif

.PHONY: oci-manifest
oci-manifest: $(buildDir)/manifest.iid
	$(info OCI image manifest $(image): $(shell cat -- $<))
	$(info Build timestamp: $(shell date -u -d '@$(SOURCE_DATE_EPOCH)' 2>/dev/null || date -u -r '$(SOURCE_DATE_EPOCH)' 2>/dev/null))
	@$(BUILDAH) manifest inspect -- "$$(cat -- $<)"

.PHONY: images
images: $(foreach arch,$(arches),$(buildDir)/image.$(arch).iid)
	$(info Images have been built.)
	$(info To generate the multiarch OCI manifest, use `$(MAKE) oci-manifest`. Requires podman and buildah.)
	$(info Build timestamp: $(shell date -u -d '@$(SOURCE_DATE_EPOCH)' 2>/dev/null || date -u -r '$(SOURCE_DATE_EPOCH)' 2>/dev/null))
	@for iidFile in $^; do \
	  ver=$${iidFile#.build/}; \
	  ver=$${ver%%/*}; \
	  ver=$${ver%-*}; \
	  arch=$${iidFile##*/image.}; \
	  arch=$${arch%.iid}; \
	  printf '%s %s: %s\n' "$$ver" "$$arch" "$$(cat -- $$iidFile)"; \
	done

$(buildDir):
	mkdir -p $@

$(buildDir)/manifest.iid: $(foreach arch,$(arches),$(buildDir)/image.$(arch).iid)
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

$(buildDir)/image.%.iid: $(buildDir)/context.%.tar
	$(BUILDX) --iidfile $@ \
	  --platform linux/$(patsubst $(buildDir)/image.%.iid,%,$@) \
	  - < $<

$(buildDir)/context.%.tar: $(buildDir)/build.%.iid
	$(DOCKER) run --rm -v '$(realpath $(dir $@)):/out' \
	  --entrypoint sh \
	  --workdir /dist \
	  -- "$$(cat -- $<)" \
	  -c \
	  'chown $(shell id -u):$(shell id -g) "$$1" && cp "$$1" "/out/$$1.tmp"' \
	  -- '$(notdir $@)'
	mv -- $@.tmp $@

$(buildDir)/build.%.iid: Dockerfile.build Dockerfile.image *.patch | $(buildDir)
	$(DOCKER) build --iidfile $@ \
	  --build-arg GOARCH=$(patsubst $(buildDir)/build.%.iid,%,$@) \
	  --build-arg VERSION=$(VERSION) \
	  --build-arg K0S_VERSION_SUFFIX=$(K0S_VERSION_SUFFIX) \
	  --build-arg SOURCE_DATE_EPOCH=$(SOURCE_DATE_EPOCH) \
	  -f $< .

.PHONY: clean
clean:
	for iidFile in .build/*/manifest.iid; do \
	  [ -f $$iidFile ] || continue; \
	  $(DOCKER) manifest rm -- $$(cat -- $$iidFile) || true; \
	done
	for iidFile in .build/*/image.*.iid .build/*/build.*.iid; do \
	  [ -f $$iidFile ] || continue; \
	  $(DOCKER) rmi -f -- $$(cat -- $$iidFile) || true; \
	done
	rm -rf .build
