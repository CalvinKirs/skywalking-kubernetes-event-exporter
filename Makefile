# Licensed to Apache Software Foundation (ASF) under one or more contributor
# license agreements. See the NOTICE file distributed with
# this work for additional information regarding copyright
# ownership. Apache Software Foundation (ASF) licenses this file to you under
# the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#

include scripts/base.mk

all: clean lint test build

.PHONY: lint
lint:
	$(GO_LINT) version || curl -sfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(GO_PATH)/bin
	$(GO_LINT) run -v --timeout 5m ./...

.PHONY: fix-lint
fix-lint:
	$(GO_LINT) run -v --fix ./...

.PHONY: check
check: clean
	$(GO) mod tidy > /dev/null
	@if [ ! -z "`git status -s`" ]; then \
		echo "Following files are not consistent with CI:"; \
		git status -s; \
		git diff; \
		exit 1; \
	fi

.PHONY: test
test: clean
	$(GO_TEST) ./... -coverprofile=coverage.txt -covermode=atomic
	@>&2 echo "Great, all tests passed!!"

.PHONY: $(PLATFORMS)
$(PLATFORMS):
	mkdir -p $(OUT_DIR)
	GOOS=$(os) GOARCH=$(ARCH) $(GO_BUILD) $(GO_BUILD_FLAGS) -ldflags "$(GO_BUILD_LDFLAGS)" -o $(OUT_DIR)/$(os)/$(APP) cmd/*.go

.PHONY: build
build: windows linux darwin

.PHONY: clean
clean:
	-rm -rf api/skywalking
	-rm -rf bin
	-rm -rf coverage.txt
	-rm -rf "$(RELEASE_BIN)"*
	-rm -rf "$(RELEASE_SRC)"*

.PHONY: verify
verify: clean license lint test

release-src: clean
	-tar -zcvf $(RELEASE_SRC).tgz \
	--exclude bin \
	--exclude .git \
	--exclude .idea \
	--exclude .DS_Store \
	--exclude .github \
	--exclude $(RELEASE_SRC).tgz \
	.

release-bin: build
	-mkdir $(RELEASE_BIN)
	-cp -R bin $(RELEASE_BIN)
	-cp -R dist/* $(RELEASE_BIN)
	-cp -R CHANGES.md $(RELEASE_BIN)
	-cp -R README.adoc $(RELEASE_BIN)
	-cp -R ../NOTICE $(RELEASE_BIN)
	-tar -zcvf $(RELEASE_BIN).tgz $(RELEASE_BIN)
	-rm -rf "$(RELEASE_BIN)"

release: verify release-src release-bin
	gpg --batch --yes --armor --detach-sig $(RELEASE_SRC).tgz
	shasum -a 512 $(RELEASE_SRC).tgz > $(RELEASE_SRC).tgz.sha512
	gpg --batch --yes --armor --detach-sig $(RELEASE_BIN).tgz
	shasum -a 512 $(RELEASE_BIN).tgz > $(RELEASE_BIN).tgz.sha512
