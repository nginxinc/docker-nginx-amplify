#!/usr/bin/make -f

TOPDIR := $(realpath $(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
SELF := $(abspath $(lastword $(MAKEFILE_LIST)))
COMMIT := $(shell git describe --always --dirty)
OS = $(shell uname -s | tr '[:upper:]' '[:lower:]')

include Makefile.containers

# https://hub.docker.com/r/nginxinc/amplify-agent/
IMAGE_TAG := amplify-agent

VERSION ?= $(shell curl -fs https://raw.githubusercontent.com/nginxinc/nginx-amplify-agent/master/packages/version | cut -d '-' -f1)

help: ## Show help message (list targets)
	@awk 'BEGIN {FS = ":.*##"; printf "\nTargets:\n"} /^[$$()% 0-9a-zA-Z_-]+:.*?##/ {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' $(SELF)

show-var-%:
	@{ \
	escaped_v="$(subst ",\",$($*))" ; \
	if [ -n "$$escaped_v" ]; then v="$$escaped_v"; else v="(undefined)"; fi; \
	printf "%-19s %s\n" "$*" "$$v"; \
	}

SHOW_ENV_VARS = \
	TOPDIR \
	SELF \
	COMMIT \
	IMAGE_TAG \
	SHELL \
	OS \
	VERSION \
	$(CONTAINER_VARS)

.PHONY: show-env
show-env: $(addprefix show-var-, $(SHOW_ENV_VARS)) ## Show environment details

.PHONY: image
image: ## Build container image based on nginx:latest
	$(CONTAINER_BUILDENV) $(CONTAINER_CLITOOL) build \
		-f $(TOPDIR)/Dockerfile \
		-t $(IMAGE_TAG):$(VERSION) \
		-t $(IMAGE_TAG):latest \
		$(TOPDIR)

.PHONY: image-alpine
image-alpine: ## Build container image based on nginx:alpine
	$(CONTAINER_BUILDENV) $(CONTAINER_CLITOOL) build \
		-f $(TOPDIR)/Dockerfile.alpine \
		-t $(IMAGE_TAG):$(VERSION)-alpine \
		-t $(IMAGE_TAG):latest-alpine \
		$(TOPDIR)

.PHONY: images
images: image image-alpine ## Build all container images

clean-images: ## Remove container images
	for image_tag in $(IMAGE_TAG):$(VERSION) $(IMAGE_TAG):latest $(IMAGE_TAG):$(VERSION)-alpine $(IMAGE_TAG):latest-alpine ; do \
		$(CONTAINER_CLITOOL) rmi -f $${image_tag} ; \
	done
