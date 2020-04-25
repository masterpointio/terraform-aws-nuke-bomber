SHELL := /bin/bash
.PHONY: all .check-env-vars build tag push

all: build tag push

.check-env-vars:
	@test $${ECR_REPO?Please pass ECR_REPO environment variable}

nuke-config.yml:
	@echo "Copy nuke-config.yml.example and fill in your account info!"
	@exit 1

build: nuke-config.yml
	docker build . -t bomber:latest

tag: .check-env-vars
	docker tag bomber:latest $(ECR_REPO):latest

push: .check-env-vars
	docker push $(ECR_REPO):latest
