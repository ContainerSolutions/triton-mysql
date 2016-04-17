# Makefile for shipping the container image and setting up
# permissions in Manta. Building with the docker-compose file
# directly works just fine without this.

MAKEFLAGS += --warn-undefined-variables
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail
.DEFAULT_GOAL := build

APPS=mysql
IMAGE_PREFIX ?= lguminski
MANTA_LOGIN ?= triton_mysql
MANTA_ROLE ?= triton-mysql
MANTA_POLICY ?= triton-mysql

build:
	docker-compose -p my -f local-compose.yml build

ship:
	docker tag -f my_mysql lguminski/triton-mysql
	docker push lguminski/triton-mysql

# -------------------------------------------------------
# for testing against Docker locally

stop:
	docker-compose -p my -f local-compose.yml stop || true
	docker-compose -p my -f local-compose.yml rm -f || true

cleanup:
	$(call check_var, SDC_ACCOUNT, Required to cleanup Manta.)
	-mrm -r /${SDC_ACCOUNT}/stor/triton-mysql/
	mmkdir /${SDC_ACCOUNT}/stor/triton-mysql
	mchmod -- +triton_mysql /${SDC_ACCOUNT}/stor/triton-mysql

test: stop build
	docker-compose -p my -f local-compose.yml up -d
	docker ps

replicas:
	docker-compose -p my -f local-compose.yml scale mysql=3
	docker ps

# -------------------------------------------------------

# create user and policies for backups
# you need to have your SDC_ACCOUNT set
# usage:
# make manta EMAIL=example@example.com PASSWORD=strongpassword

manta:
	$(call check_var, EMAIL PASSWORD SDC_ACCOUNT, \
		Required to create a Manta login.)

	ssh-keygen -t rsa -b 4096 -C "${EMAIL}" -f manta
	sdc-user create --login=${MANTA_LOGIN} --password=${PASSWORD} --email=${EMAIL}
	sdc-user upload-key $(ssh-keygen -E md5 -lf ./manta | awk -F' ' '{gsub("MD5:","");{print $2}}') --name=${MANTA_LOGIN}-key ${MANTA_LOGIN} ./manta.pub
	sdc-policy create --name=${MANTA_POLICY} \
		--rules='CAN getobject' \
		--rules='CAN putobject' \
		--rules='CAN putmetadata' \
		--rules='CAN putsnaplink' \
		--rules='CAN getdirectory' \
		--rules='CAN putdirectory'
	sdc-role create --name=${MANTA_ROLE} \
		--policies=${MANTA_POLICY} \
		--members=${MANTA_LOGIN}
	mmkdir ${SDC_ACCOUNT}/stor/${MANTA_LOGIN}
	mchmod -- +triton_mysql /${SDC_ACCOUNT}/stor/${MANTA_LOGIN}

add: check
	@echo "## adding"; \
	cat marathon.json |  \
        sed 's%\$${env.IMAGE_PREFIX}%'${IMAGE_PREFIX}'%' | \
        sed 's%\$${env.CONSUL_ADDRESS}%'${CONSUL_ADDR}'%' | \
	curl -s -u $$MARATHON_LOGIN:$$MARATHON_PASSWORD -k -X POST -H 'Content-Type: application/json' $${MARATHON_URL}/v2/apps -d@-

status: check
	@echo "## checking status"; \
	curl -s -u $$MARATHON_LOGIN:$$MARATHON_PASSWORD -k -H 'Content-Type: application/json' $${MARATHON_URL}/v2/apps?id=triton-mysql/ap-mysql | jq


del: check
	@echo "## removing"; \
	cat marathon.json |  \
        sed 's%\$${env.IMAGE_PREFIX}%'${IMAGE_PREFIX}'%' | \
        sed 's%\$${env.CONSUL_ADDRESS}%'${CONSUL_ADDR}'%' | \
	curl -s -u $$MARATHON_LOGIN:$$MARATHON_PASSWORD -k -X DELETE -H 'Content-Type: application/json' $${MARATHON_URL}/v2/apps/triton-mysql/ap-mysql

check:
	@test_present() { \
		if [[ -n "$${1}" ]] && test -n "$$(eval "echo "\$${$${1}+x}"")"; then \
			export ok=1; \
		else \
			echo Variable $$1 is not set; \
			exit 1; \
		fi; \
	}; \
	for varname in MARATHON_LOGIN MARATHON_PASSWORD; do \
		test_present $$varname; \
	done; \



# -------------------------------------------------------
# helper functions for testing if variables are defined

check_var = $(foreach 1,$1,$(__check_var))
__check_var = $(if $(value $1),,\
	$(error Missing $1 $(if $(value 2),$(strip $2))))



