# Copyright 2021-2022 FLECS Technologies GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

ARCH?=amd64
BUILD_DIR_BASE=build
DISTRO?=debian
DISTRO_VERSION?=buster
DOCKER_VERSION?=20.10.17
DOCKER_RELEASE?=3
MAPPED_ARCH=$(call map_arch)

BASE_URL=https://download.docker.com/linux/$(DISTRO)
BUILD_DIR:=$(BUILD_DIR_BASE)/$(ARCH)/$(DISTRO)/$(DISTRO_VERSION)/docker-$(DOCKER_VERSION)
DEB_NAME=$*_$(DOCKER_VERSION)~$(DOCKER_RELEASE)-0~$(DISTRO)-$(DISTRO_VERSION)_$(ARCH).deb

define map_arch
$(subst arm64,aarch64,$(subst amd64,x86_64,$(ARCH)))
endef

.PHONY: all
all: docker-ce

.PHONY: test
test: test-docker-ce

.PHONY: clean
clean:
	rm -rf $(BUILD_DIR_BASE)/

.PHONY: docker-ce
docker-ce: $(BUILD_DIR_BASE)/flecs-docker-ce$(DEB_NAME)

.PRECIOUS: $(BUILD_DIR)/%.deb
$(BUILD_DIR)/%.deb:
	rm -rf $(BUILD_DIR)/$* && mkdir -p $(BUILD_DIR)/$*
ifeq ($(filter-out debian ubuntu,$(DISTRO)),)
	wget --quiet --output-document=$@ $(BASE_URL)/dists/$(DISTRO_VERSION)/pool/stable/$(ARCH)/$(DEB_NAME)
endif
	dpkg-deb -R $(BUILD_DIR)/$*.deb $(BUILD_DIR)/$*

$(BUILD_DIR)/docker-static.tgz: DISTRO=static
$(BUILD_DIR)/docker-static.tgz:
	rm -rf $(BUILD_DIR)/static && mkdir -p $(BUILD_DIR)/static
	wget --quiet --output-document=$(BUILD_DIR)/docker-static.tgz $(BASE_URL)/stable/$(MAPPED_ARCH)/docker-$(DOCKER_VERSION).tgz
	tar -C $(BUILD_DIR)/static -xf $(BUILD_DIR)/docker-static.tgz

.PRECIOUS: $(BUILD_DIR)/flecs-%
$(BUILD_DIR)/flecs-%: $(BUILD_DIR)/docker-static.tgz $(BUILD_DIR)/%.deb
	cp -r $(BUILD_DIR)/$* $(BUILD_DIR)/flecs-$*
	@for i in `find $(BUILD_DIR)/$*/usr/bin/ -type f -executable`; do \
		cp -pf $(BUILD_DIR)/static/docker/$$(basename $${i}) $(BUILD_DIR)/flecs-$*/usr/bin/; \
	done
	@if [ "$(ARCH)" == "armhf" ]; then \
		./scripts/patch-dockerd.sh $(BUILD_DIR)/flecs-$*/usr/bin/dockerd; \
	fi

$(BUILD_DIR_BASE)/flecs-%$(DEB_NAME): $(BUILD_DIR)/flecs-%
	sed -i "s/Package:.*/Package: flecs-docker-ce/" $</DEBIAN/control
	sed -i "s/Maintainer:.*/Maintainer: FLECS Technologies GmbH <info@flecs.tech>/" $</DEBIAN/control
	sed -i "s/Depends:.*/Depends: containerd.io (>= 1.4.1), docker-ce-cli, iptables, libseccomp2 (>= 2.3.0), libc6 (>= 2.4)/" $</DEBIAN/control
	sed -i "s/Conflicts:.*/Conflicts: docker-ce, docker (<< 1.5~), docker-engine, docker-engine-cs, docker.io, lxc-docker, lxc-docker-virtual-package/" $</DEBIAN/control
	sed -i "s/Replaces:.*/Replaces: docker-engine, docker-ce/" $</DEBIAN/control
	sed -i "s/Installed-Size:.*/Installed-Size: $(shell du -s --exclude=DEBIAN/** $< | cut -f1)/" $</DEBIAN/control
	@dpkg-deb --verbose --root-owner-group -Z gzip --build $< $@

test-%: %
	docker build \
		--tag flecs-test-$*:$(DOCKER_VERSION) \
		--build-arg ARCH=$(ARCH) \
		--build-arg BUILD_DIR_BASE=$(BUILD_DIR_BASE) \
		--build-arg DOCKER_VERSION=$(DOCKER_VERSION) \
		--build-arg DOCKER_RELEASE=$(DOCKER_RELEASE) \
		--build-arg DISTRO=$(DISTRO) \
		--build-arg DISTRO_VERSION=$(DISTRO_VERSION) \
		--build-arg PRODUCT=$* \
		--file test/Dockerfile.$* .
	docker run --rm --privileged flecs-test-$*:$(DOCKER_VERSION)