# Makefile for shipping the container image and setting up
# permissions in Manta. Building with the docker-compose file
# directly works just fine without this.

MAKEFLAGS += --warn-undefined-variables
SHELL := $(shell which bash)
.SHELLFLAGS := -eu -o pipefail
.DEFAULT_GOAL := help

MANTA_LOGIN ?= triton_mysql
MANTA_ROLE ?= triton_mysql
MANTA_POLICY ?= triton_mysql

help:
	cat ./README.md

build:
	docker-compose -p my -f local-compose.yml build

ship:
	$(call check_var, IMAGE_PREFIX, IMAGE_PREFIX must be set)
	docker tag -f my_mysql ${IMAGE_PREFIX}/triton-mysql
	docker push ${IMAGE_PREFIX}/triton-mysql

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


# -------------------------------------------------------
# helper functions for testing if variables are defined

check_var = $(foreach 1,$1,$(__check_var))
__check_var = $(if $(value $1),,\
	$(error Missing $1 $(if $(value 2),$(strip $2))))

# -------------------------------------------------------
# mantl.io stuff

mantle-add: mantl-check
		cat marathon.json |  \
			sed "s/\$${env.IMAGE_PREFIX}/$${IMAGE_PREFIX}/" | \
			curl -q -u $$MANTL_LOGIN:$$MANTL_PASSWORD -k -X POST -H 'Content-Type: application/json' https://$${MANTL_CONTROL_HOST}:8080/v2/apps -d@-


mantl-check:
	$(call check_var, MANTL_LOGIN MANTL_PASSWORD MANTL_CONTROL_HOST, Required for interaction with mantl)

.PHONY: mantl-check
