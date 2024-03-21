# Define Docker Hub credentials
DOCKER_HUB_USR := $(DOCKER_HUB_USR)
DOCKER_HUB_PSW := $(DOCKER_HUB_PSW)
REPO_NAME := $(REPO_NAME)

# Tool Definitions
SHELL := /bin/bash

# Image Tags
VOTE_IMAGE_TAG := $(REPO_NAME)/vote:dev
RESULT_IMAGE_TAG := $(REPO_NAME)/result:latest
WORKER_IMAGE_TAG := $(REPO_NAME)/worker:latest
POSTGRES_IMAGE_TAG := postgres:15-alpine
REDIS_IMAGE_TAG := redis:alpine

# Directories
VOTE_DIR := ./vote
RESULT_DIR := ./result
WORKER_DIR := ./worker

# Target Images for Analysis
IMAGES_TO_ANALYZE := $(VOTE_IMAGE_TAG) $(RESULT_IMAGE_TAG) $(WORKER_IMAGE_TAG) $(POSTGRES_IMAGE_TAG) $(REDIS_IMAGE_TAG)

# List of images to push
IMAGES_TO_PUSH := $(VOTE_IMAGE_TAG) $(RESULT_IMAGE_TAG) $(WORKER_IMAGE_TAG)

# Targets
.PHONY: all build login analyze-all analyze vote result worker analyze-quiet export_env analyze-all-quiet push

all: login build analyze-all

build: vote result worker

login: export_env
	@echo "Logging into Docker Hub..."
	@echo $${DOCKER_HUB_PSW} | docker login -u $${DOCKER_HUB_USR} --password-stdin

vote:
	@echo "Building vote image..."
	docker build -t $(VOTE_IMAGE_TAG) $(VOTE_DIR)

result:
	@echo "Building result image..."
	docker build -t $(RESULT_IMAGE_TAG) $(RESULT_DIR)

worker:
	@echo "Building worker image..."
	docker build -t $(WORKER_IMAGE_TAG) $(WORKER_DIR)

analyze-all:
	$(foreach image,$(IMAGES_TO_ANALYZE),$(MAKE) analyze IMAGE=$(image);)

analyze-all-quiet:
	$(foreach image,$(IMAGES_TO_ANALYZE),$(MAKE) analyze-quiet IMAGE=$(image);)

analyze:
	@echo "Analyzing image $(IMAGE) for vulnerabilities..."
	@docker scout quickview $(IMAGE)
	@docker scout cves $(IMAGE) --exit-code --only-severity critical,high; \
	EXIT_CODE=$$?; \
	if [ $$EXIT_CODE -eq 0 ]; then \
	    echo "$(IMAGE) - Pass"; \
	else \
	    echo "$(IMAGE) - Fail"; \
	fi

analyze-quiet:
	@echo "Analyzing image $(IMAGE)..."
	@{ \
	docker scout cves $(IMAGE) --exit-code --only-severity critical,high > /dev/null 2>&1; \
	EXIT_CODE=$$?; \
	} ; \
	if [ $$EXIT_CODE -eq 0 ]; then \
	    echo "$(IMAGE) - Pass"; \
	else \
	    echo "$(IMAGE) - Fail"; \
	fi

push:
	@for image in $(IMAGES_TO_PUSH); do \
		echo "Pushing $$image..."; \
		docker push $$image; \
	done

export_env:
	$(shell export $(grep -v '^#' .env | xargs))
