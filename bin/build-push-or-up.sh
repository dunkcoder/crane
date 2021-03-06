#!/bin/bash

set -e

export REGISTRY_PREFIX=${REGISTRY_PREFIX:-""}
export DEFAULT_TAG=`git log --pretty=format:'%h' -n 1 2>/dev/null`
if [ "x$DEFAULT_TAG" = "x" ]
then
    // local build image with devel tag
    DEFAULT_TAG="dev"
fi
export TAG=${VERSION:-$DEFAULT_TAG}

up_or_push=$1
if [ "x$up_or_push" != "xpush" ] && [ "x$up_or_push" != "xup" ]
then
    echo "run me like this: CRANE_IP=X.X.X.X $0 push or CRANE_IP=X.X.X.X $0 up"
    exit 1
fi

docker run --rm -v $(pwd)/frontend:/data digitallyseamless/nodejs-bower-grunt:5 bower install
docker run --rm -w /go/src/github.com/Dataman-Cloud/crane -v $(pwd):/go/src/github.com/Dataman-Cloud/crane golang:1.5.4 make

if [ ! -f docker/docker ]; then
    curl https://get.docker.com/builds/Linux/x86_64/docker-latest.tgz | tar xzv
fi

# build crane
docker-compose -p crane -f deploy/docker-compose.yml build

if [ "x$up_or_push" = "xpush" ]
then
    docker-compose -p crane -f deploy/docker-compose.yml push
fi

if [ "x$up_or_push" = "xup" ]
then
    # node env check
    echo "Checking the node status"
    ./frontend/misc-tools/node-init.sh

    # swarm init
    echo "Trying to init swarm cluster"
    INIT_ERROR=$(docker swarm init --advertise-addr=$CRANE_IP 2>&1 > /dev/null) || {
       docker info 2>/dev/null | grep Swarm | grep -v inactive || {
          printf "\033[41mERROR:\033[0m failed to init swarm against cmd: \e[1;34mdocker swarm init --advertise-addr=$CRANE_IP\e[0m\n"
          echo "$INIT_ERROR"
          exit 1
       }
    }
    echo "Swarm cluster have been running!"

    docker-compose -p crane -f deploy/docker-compose.yml stop
    docker-compose -p crane -f deploy/docker-compose.yml rm -f

    CRANE_SWARM_MANAGER_IP=${CRANE_IP} docker-compose -p crane -f deploy/docker-compose.yml up -d
fi
