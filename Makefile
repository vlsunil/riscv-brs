# Makefile for RISC-V Boot and Runtime Services Specification (BRS)
#
# This work is licensed under the Creative Commons Attribution-ShareAlike 4.0
# International License. To view a copy of this license, visit
# http://creativecommons.org/licenses/by-sa/4.0/ or send a letter to
# Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
#
# SPDX-License-Identifier: CC-BY-SA-4.0
#
# Description:
#
# Builds the two independently-versioned documents that live in this repo:
#   - brs.adoc     the BRS spec itself (Ratified, tagged v0.0.1..v1.0 lineage;
#                   VERSION_brs defaults to the git tag via release-info.sh)
#   - brs-ts.adoc  the BRS Test Specification (Draft, revnumber 0.1, no tag
#                   lineage of its own; VERSION_brs-ts is a static value bumped
#                   by hand -- it deliberately does NOT read git tags, since
#                   those tags belong to the BRS spec, not the Test Spec)
# Each gets its own VERSION/PHASE/etc. resolved independently, so `make` can't
# accidentally stamp one document's release metadata onto the other.

DOCS := brs.adoc brs-ts.adoc

DATE ?= $(shell date +%Y-%m-%d)
DATE_STAMP := $(subst -,,$(DATE))

# BRS spec: version comes from the git tag lineage (v0.0.1 .. v1.0) via
# release-info.sh, same as before this migration.
VERSION_brs ?= $(shell ./scripts/release-info.sh version)
SPEC_SHORT_brs := BRS

# BRS Test Specification: no tag lineage of its own yet (still Draft,
# revnumber 0.1) -- static default, bump by hand when the Test Spec cuts a
# release. Override on the command line: `make build-brs-ts VERSION_brs-ts=v0.2.0`.
VERSION_brs-ts ?= v0.1.0
SPEC_SHORT_brs-ts := BRS-TS

DOCKER_IMG := ghcr.io/riscv/riscv-docs-base-container-image:latest
DOCKER_BIN ?= docker
ifneq ($(SKIP_DOCKER),true)
	DOCKER_IS_PODMAN = \
		$(shell ! ${DOCKER_BIN} -v 2>&1 | grep podman >/dev/null ; echo $$?)
	ifeq "$(DOCKER_IS_PODMAN)" "1"
		DOCKER_VOL_SUFFIX = :z
	endif

	DOCKER_CMD := \
		${DOCKER_BIN} run --rm \
			-v ${PWD}:/build${DOCKER_VOL_SUFFIX} \
			-w /build \
			${DOCKER_IMG} \
			/bin/sh -c
	DOCKER_QUOTE := "
endif

SRC_DIR := src
BUILD_DIR := build

ASCIIDOCTOR_PDF := asciidoctor-pdf
REQUIRES := --require=asciidoctor-bibtex \
            --require=asciidoctor-diagram \
            --require=asciidoctor-mathematical

.PHONY: all build clean build-container build-no-container \
        build-brs build-brs-ts stamp-antora

all: build

# Stamp antora.yml with the BRS spec's current VERSION/DATE so the Antora HTML
# site version stays in lockstep with the ARC PDF. Only the BRS spec has an
# Antora component -- the Test Spec is PDF-only, so there is nothing of its to
# stamp. Run at release time -- e.g. `make stamp-antora VERSION_brs=v1.1.0`.
stamp-antora:
	./scripts/stamp-antora-version.sh "$(VERSION_brs)" "$(DATE)"

vpath %.adoc $(SRC_DIR)

# $(call doc_options,<docname>) expands to the -a overrides for one document,
# resolved from that document's own VERSION_<docname>/SPEC_SHORT_<docname> pair
# so the two documents never share release metadata.
define doc_options
-a revnumber=$(VERSION_$(1)) \
-a revremark='$(shell ./scripts/release-info.sh revremark "$(VERSION_$(1))")' \
-a revdate=$(DATE) \
-a phase='$(shell ./scripts/release-info.sh phase "$(VERSION_$(1))")' \
-a phase_display='$(shell ./scripts/release-info.sh display "$(VERSION_$(1))")' \
-a phase_notice='$(shell ./scripts/release-info.sh notice "$(VERSION_$(1))")' \
-a milestone_id='$(shell ./scripts/release-info.sh phase "$(VERSION_$(1))")' \
-a spec_short='$(SPEC_SHORT_$(1))'
endef

# $(call doc_dest,<docname>) expands to the ARC-compliant output filename for
# one document: <SPEC_SHORT>-v<version>-<YYYYMMDD>.pdf
define doc_dest
$(SPEC_SHORT_$(1))-$(VERSION_$(1))-$(DATE_STAMP).pdf
endef

COMMON_OPTIONS := --trace \
           -a compress \
           -a mathematical-format=svg \
           -a pdf-fontsdir=docs-resources/fonts \
           -a pdf-style=docs-resources/themes/riscv-pdf.yml \
           -D $(BUILD_DIR) \
           --failure-level=ERROR

build-brs:
	@mkdir -p $(BUILD_DIR)
	$(DOCKER_CMD) $(DOCKER_QUOTE) $(ASCIIDOCTOR_PDF) $(COMMON_OPTIONS) $(call doc_options,brs) $(REQUIRES) --out-file=$(call doc_dest,brs) $(SRC_DIR)/brs.adoc $(DOCKER_QUOTE)
	@echo "ARC submission PDF: $(BUILD_DIR)/$(call doc_dest,brs)"

build-brs-ts:
	@mkdir -p $(BUILD_DIR)
	$(DOCKER_CMD) $(DOCKER_QUOTE) $(ASCIIDOCTOR_PDF) $(COMMON_OPTIONS) $(call doc_options,brs-ts) $(REQUIRES) --out-file=$(call doc_dest,brs-ts) $(SRC_DIR)/brs-ts.adoc $(DOCKER_QUOTE)
	@echo "ARC submission PDF: $(BUILD_DIR)/$(call doc_dest,brs-ts)"

build-docs: build-brs build-brs-ts

build:
	@echo "Checking if Docker is available..."
	@if command -v ${DOCKER_BIN} >/dev/null 2>&1 ; then \
		echo "Docker is available, building inside Docker container..."; \
		$(MAKE) build-container; \
	else \
		echo "Docker is not available, building without Docker..."; \
		$(MAKE) build-no-container; \
	fi

build-container:
	@echo "Starting build inside Docker container..."
	$(MAKE) build-docs
	@echo "Build completed successfully inside Docker container."

build-no-container:
	@echo "Starting build..."
	$(MAKE) SKIP_DOCKER=true build-docs
	@echo "Build completed successfully."

# Update docker image to latest
docker-pull-latest:
	${DOCKER_BIN} pull ${DOCKER_IMG}

clean:
	@echo "Cleaning up generated files..."
	rm -rf $(BUILD_DIR)
	@echo "Cleanup completed."
