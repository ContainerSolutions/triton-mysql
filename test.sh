#!/usr/bin/env bash
set -e

export IMAGE_PREFIX=moretea
export MANTL_CONTROL_HOST=mantl-lg-control-02.node.infra.container-solutions.com
export MANTL_LOGIN=admin
export MANTL_PASSWORD=''
export IMAGE_PREFIX=moretea

echo "###### BUILDING"
docker build -t my_mysql .

echo "##### PUSH TO DOCKER HUB"
make ship


#echo "##### FETCH FROM DOCKER HUB"
docker run --rm -ti --volumes-from gcloud-config -v `pwd`:/pwd gcloud-cli gcloud compute ssh mantl-lg-worker-02 --zone europe-west1-d sudo docker pull docker.io/$IMAGE_PREFIX/triton-mysql
docker run --rm -ti --volumes-from gcloud-config -v `pwd`:/pwd gcloud-cli gcloud compute ssh mantl-lg-worker-01 --zone europe-west1-c sudo docker pull docker.io/$IMAGE_PREFIX/triton-mysql

sleep 1

echo "##### DEL/ADD MANTL"
make mantl-del
sleep 1
make mantl-add
