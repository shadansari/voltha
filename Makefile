#
# Copyright 2016 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

ifneq ($(VOLTHA_BUILD),docker)
ifeq ($(VOLTHA_BASE)_set,_set)
$(error To get started, please source the env.sh file)
endif
endif

ifeq ($(TAG),)
TAG := latest
endif

ifeq ($(TARGET_TAG),)
TARGET_TAG := latest
endif

# If no DOCKER_HOST_IP is specified grab a v4 IP address associated with
# the default gateway
ifeq ($(DOCKER_HOST_IP),)
DOCKER_HOST_IP := $(shell ifconfig $$(netstat -rn | grep -E '^(default|0.0.0.0)' | head -1 | awk '{print $$NF}') | grep inet | awk '{print $$2}' | sed -e 's/addr://g')
endif

include setup.mk

ifneq ($(http_proxy)$(https_proxy),)
# Include proxies from the environment
DOCKER_PROXY_ARGS = \
       --build-arg http_proxy=$(http_proxy) \
       --build-arg https_proxy=$(https_proxy) \
       --build-arg ftp_proxy=$(ftp_proxy) \
       --build-arg no_proxy=$(no_proxy) \
       --build-arg HTTP_PROXY=$(HTTP_PROXY) \
       --build-arg HTTPS_PROXY=$(HTTPS_PROXY) \
       --build-arg FTP_PROXY=$(FTP_PROXY) \
       --build-arg NO_PROXY=$(NO_PROXY)
endif

DOCKER_BUILD_ARGS = \
	--build-arg TAG=$(TAG) \
	--build-arg REGISTRY=$(REGISTRY) \
	--build-arg REPOSITORY=$(REPOSITORY) \
	$(DOCKER_PROXY_ARGS) $(DOCKER_CACHE_ARG) \
	 --rm --force-rm \
	 --no-cache \
	$(DOCKER_BUILD_EXTRA_ARGS)

VENVDIR := venv-$(shell uname -s | tr '[:upper:]' '[:lower:]')

DOCKER_IMAGE_LIST = \
	base \
	protoc \
	protos \
	voltha \
	ofagent \
	tools \
	cli \
	nginx \
	onos \
	unum \
	config-push \
	j2

# The following list was scavanged from the compose / stack files as well as
# from the Dockerfiles. If nothing else it highlights that VOLTHA is not
# using consistent versions for some of the containers.

# grep  -i "^FROM" docker/Dockerfile.* | grep -v voltha-  | sed -e 's/ as .*$//g' -e 's/\${REGISTRY}//g' | awk '{print $NF}' | grep -v '^scratch' | sed '/:.*$/!s/$/:latest/g' | sort -u | sed -e 's/^/       /g' -e 's/$/ \\/g'
FETCH_BUILD_IMAGE_LIST = \
       alpine:3.6 \
       centos:7 \
       centurylink/ca-certs:latest \
       debian:stretch-slim \
       gliderlabs/registrator:v7 \
       golang:1.9.2 \
       grpc/python:latest \
       maven:3-jdk-8-alpine \
       onosproject/onos:1.10.9 \
       ubuntu:xenial

# find compose -type f | xargs grep image: | awk '{print $NF}' | grep -v voltha- | sed -e 's/\"//g' -e 's/\${REGISTRY}//g' -e 's/:\${.*:-/:/g' -e 's/\}//g' -e '/:.*$/!s/$/:latest/g' | sort -u | sed -e 's/^/        /g' -e 's/$/ \\/g'
FETCH_COMPOSE_IMAGE_LIST = \
        docker.elastic.co/elasticsearch/elasticsearch:5.6.0 \
        gliderlabs/registrator:latest \
        marcelmaatkamp/freeradius:latest \
        postgres:9.6.1 \
        quay.io/coreos/etcd:v3.2.9 \
        registry:2 \
        tianon/true:latest \
        wurstmeister/kafka:latest \
        wurstmeister/zookeeper:latest

# find k8s -type f | xargs grep image: | awk '{print $NF}' | sed -e 's/\"//g' | sed '/:.*$/!s/$/:latest/g' | sort -u | sed -e 's/^/       /g' -e 's/$/ \\/g'
# Manually remove some image from this list as they don't reflect the new 
# naming conventions for the VOLTHA build
FETCH_K8S_IMAGE_LIST = \
       alpine:3.6 \
       busybox:latest \
       nginx:1.13 \
       gcr.io/google_containers/defaultbackend:1.4 \
       gcr.io/google_containers/kubernetes-dashboard-amd64:v1.8.3 \
       marcelmaatkamp/freeradius:latest \
       gcr.io/google-containers/hyperkube:v1.9.5 \
       quay.io/coreos/etcd-operator:v0.7.2 \
       quay.io/coreos/etcd:v3.2.9 \
       quay.io/kubernetes-ingress-controller/nginx-ingress-controller:0.10.2 \
       wurstmeister/kafka:1.0.0 \
       zookeeper:3.4.11

FETCH_IMAGE_LIST = $(shell echo $(FETCH_BUILD_IMAGE_LIST) $(FETCH_COMPOSE_IMAGE_LIST) $(FETCH_K8S_IMAGE_LIST) | tr ' ' '\n' | sort -u)

.PHONY: $(DIRS) $(DIRS_CLEAN) $(DIRS_FLAKE8) flake8 base voltha ofagent onos cli nginx tools unum start stop tag push pull

# This should to be the first and default target in this Makefile
help:
	@echo "Usage: make [<target>]"
	@echo "where available targets are:"
	@echo
	@echo "build        : Build the Voltha protos and docker images.\n\
               If this is the first time you are building, choose \"make build\" option."
	@echo "production   : Build voltha for production deployment"
	@echo "clean        : Remove files created by the build and tests"
	@echo "distclean    : Remove venv directory"
	@echo "fetch        : Pre-fetch artifacts for subsequent local builds"
	@echo "flake8       : Run specifically flake8 tests"
	@echo "help         : Print this help"
	@echo "protoc       : Build a container with protoc installed"
	@echo "protos       : Compile all grpc/protobuf files"
	@echo "rebuild-venv : Rebuild local Python virtualenv from scratch"
	@echo "venv         : Build local Python virtualenv if did not exist yet"
	@echo "containers   : Build all the docker containers"
	@echo "base         : Build the base docker container used by all other dockers"
	@echo "voltha       : Build the voltha docker container"
	@echo "ofagent      : Build the ofagent docker container"
	@echo "onos         : Build the onos docker container"
	@echo "cli          : Build the cli docker container"
	@echo "nginx        : Build the nginx docker container"
	@echo "unum         : Build the unum docker container"
	@echo "j2           : Build the Jinja2 template container"
	@echo "start        : Start VOLTHA on the current system"
	@echo "stop         : Stop VOLTHA on the current system"
	@echo "tag          : Tag a set of images"
	@echo "push         : Push the docker images to an external repository"
	@echo "pull         : Pull the docker images from a repository"
	@echo

## New directories can be added here
DIRS:=\
voltha/northbound/openflow \
voltha/northbound/openflow/agent \
voltha/northbound/openflow/oftest

## If one directory depends on another directory that
## dependency can be expressed here
##
## For example, if the Tibit directory depended on the eoam
## directory being built first, then that can be expressed here.
##  driver/tibit: eoam

# Parallel Build
$(DIRS):
	@echo "    MK $@"
	$(Q)$(MAKE) -C $@

# Parallel Clean
DIRS_CLEAN = $(addsuffix .clean,$(DIRS))
$(DIRS_CLEAN):
	@echo "    CLEAN $(basename $@)"
	$(Q)$(MAKE) -C $(basename $@) clean

# Parallel Flake8
DIRS_FLAKE8 = $(addsuffix .flake8,$(DIRS))
$(DIRS_FLAKE8):
	@echo "    FLAKE8 $(basename $@)"
	-$(Q)$(MAKE) -C $(basename $@) flake8

build: protoc protos containers

containers: base voltha ofagent onos config-push cli nginx tools unum j2

base:
	docker build $(DOCKER_BUILD_ARGS) -t ${REGISTRY}${REPOSITORY}voltha-base:${TAG} -f docker/Dockerfile.base .

ifneq ($(VOLTHA_BUILD),docker)
voltha: voltha-adapters
	docker build $(DOCKER_BUILD_ARGS) -t ${REGISTRY}${REPOSITORY}voltha-voltha:${TAG} -f docker/Dockerfile.voltha .
else
voltha:
	docker build $(DOCKER_BUILD_ARGS) -t ${REGISTRY}${REPOSITORY}voltha-voltha:${TAG} -f docker/Dockerfile.voltha_d .
endif

voltha-adapters:
	make -C voltha/adapters/openolt

ofagent:
ifneq ($(VOLTHA_BUILD),docker)
	docker build $(DOCKER_BUILD_ARGS) -t ${REGISTRY}${REPOSITORY}voltha-ofagent:${TAG} -f docker/Dockerfile.ofagent .
else
	docker build $(DOCKER_BUILD_ARGS) -t ${REGISTRY}${REPOSITORY}voltha-ofagent:${TAG} -f docker/Dockerfile.ofagent_d .
endif

tools:
	docker build $(DOCKER_BUILD_ARGS) -t ${REGISTRY}${REPOSITORY}voltha-tools:${TAG} -f docker/Dockerfile.tools .

cli:
ifneq ($(VOLTHA_BUILD),docker)
	docker build $(DOCKER_BUILD_ARGS) -t ${REGISTRY}${REPOSITORY}voltha-cli:${TAG} -f docker/Dockerfile.cli .
else
	docker build $(DOCKER_BUILD_ARGS) -t ${REGISTRY}${REPOSITORY}voltha-cli:${TAG} -f docker/Dockerfile.cli_d .
endif

nginx:
	docker build $(DOCKER_BUILD_ARGS) -t ${REGISTRY}${REPOSITORY}voltha-nginx:${TAG} -f docker/Dockerfile.nginx .

onos:
	docker build $(DOCKER_BUILD_ARGS) -t ${REGISTRY}${REPOSITORY}voltha-onos:${TAG} -f docker/Dockerfile.onos docker

unum:
	docker build $(DOCKER_BUILD_ARGS) -t ${REGISTRY}${REPOSITORY}voltha-unum:${TAG} -f unum/Dockerfile ./unum

config-push:
	docker build $(DOCKER_BUILD_ARGS) -t ${REGISTRY}${REPOSITORY}voltha-config-push:${TAG} -f docker/Dockerfile.configpush docker

j2:
	docker build $(DOCKER_BUILD_ARGS) -t ${REGISTRY}${REPOSITORY}voltha-j2:${TAG} -f docker/Dockerfile.j2 docker

@MAKE_ENV := $(shell echo '$(.VARIABLES)' | awk -v RS=' ' '/^[a-zA-Z0-9]+$$/')
@SHELL_EXPORT := $(foreach v,$(MAKE_ENV),$(v)='$($(v))')
start:
	$(SHELL_EXPORT) STACK_TEMPLATE=./compose/voltha-stack.yml.j2 ./scripts/run-voltha.sh start

stop:
	./scripts/run-voltha.sh stop

tag: $(patsubst  %,%.tag,$(DOCKER_IMAGE_LIST))

push: tag $(patsubst  %,%.push,$(DOCKER_IMAGE_LIST))

pull: $(patsubst  %,%.pull,$(DOCKER_IMAGE_LIST))

%.tag:
	docker tag ${REGISTRY}${REPOSITORY}voltha-$(subst .tag,,$@):${TAG} ${TARGET_REGISTRY}${TARGET_REPOSITORY}voltha-$(subst .tag,,$@):${TARGET_TAG}

%.push:
	docker push ${TARGET_REGISTRY}${TARGET_REPOSITORY}voltha-$(subst .push,,$@):${TARGET_TAG}

%.pull:
	docker pull ${REGISTRY}${REPOSITORY}voltha-$(subst .pull,,$@):${TAG}

protoc:
ifeq ($(VOLTHA_BUILD),docker)
	docker build $(DOCKER_BUILD_ARGS) -t ${REGISTRY}${REPOSITORY}voltha-protoc:${TAG} -f docker/Dockerfile.protoc .
endif

protos:
ifneq ($(VOLTHA_BUILD),docker)
	make -C voltha/protos
	make -C ofagent/protos
else
	docker build $(DOCKER_BUILD_ARGS) -t ${REGISTRY}${REPOSITORY}voltha-protos:${TAG} -f docker/Dockerfile.protos .
endif

install-protoc:
	make -C voltha/protos install-protoc

clean:
	find voltha -name '*.pyc' | xargs rm -f

distclean: clean
	rm -rf ${VENVDIR}

fetch:
	@bash -c ' \
		for i in $(FETCH_IMAGE_LIST); do \
			docker pull $$i; \
		done'

purge-venv:
	rm -fr ${VENVDIR}

rebuild-venv: purge-venv venv

ifneq ($(VOLTHA_BUILD),docker)
venv: ${VENVDIR}/.built
else
venv:
endif

VENV_BIN ?= virtualenv
VENV_OPTS ?=

${VENVDIR}/.built:
	@ $(VENV_BIN) ${VENV_OPTS} ${VENVDIR}
	@ $(VENV_BIN) ${VENV_OPTS} --relocatable ${VENVDIR}
	@ . ${VENVDIR}/bin/activate && \
	    pip install --upgrade pip; \
	    if ! pip install -r requirements.txt; \
	    then \
	        echo "On MAC OS X, if the installation failed with an error \n'<openssl/opensslv.h>': file not found,"; \
	        echo "see the BUILD.md file for a workaround"; \
	    else \
	        uname -s > ${VENVDIR}/.built; \
	    fi
	@ $(VENV_BIN) ${VENV_OPTS} --relocatable ${VENVDIR}

flake8: $(DIRS_FLAKE8)

# end file
