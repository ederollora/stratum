#!/usr/bin/env bash
# Copyright 2021-present Open Networking Foundation
# SPDX-License-Identifier: Apache-2.0
set -e

if [[ $EUID -eq 0 ]]; then
  echo "This script should not be run as root, run it as the user who owns the Stratum source directory"
  exit 1
fi

# ---------- User Credentials -------------
# DOCKER_USER=
# DOCKER_PASSWORD=
# GITHUB_TOKEN=<FILL IN>

# ---------- Release Variables -------------
# VERSION=${VERSION:-$(date +%y.%m)}  # 21.03
VERSION=${VERSION:-0.0.1}
VERSION_LONG=${VERSION_LONG:-v0.0.1}  # 2021-03-31
STRATUM_DIR=${STRATUM_DIR:-$HOME/stratum-$(date +%Y-%m-%d-%H-%M-%SZ)}

# ---------- Build Variables -------------
JOBS=30
BAZEL_CACHE=$HOME/.cache
RELEASE_DIR=$HOME/stratum-release-pkgs

# Clean up and recreate the release package directory
rm -rfv $RELEASE_DIR
mkdir -p $RELEASE_DIR

echo "
Building Stratum release $VERSION ($VERSION_LONG)
Stratum directory: $STRATUM_DIR
Release artifact directory: $RELEASE_DIR
Bazel cache directory: $BAZEL_CACHE
Jobs: $JOBS
"
# ---------- Prerequisites -------------

# Log in to Docker Hub
read -p 'Username: ' DOCKER_USER
read -sp 'Password: ' DOCKER_PASSWORD

exit 1


echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USER" --password-stdin

# ---------- git tag the release -------------
if [ ! -d $STRATUM_DIR ]; then
  git clone -b ngintent https://github.com/ederollora/stratum.git $STRATUM_DIR
  TEMP_STRATUM_DIR=1
fi
cd $STRATUM_DIR
git tag $VERSION_LONG

# ---------- Build release builder container -------------
# This container is currently only used for the BF and BCM builds
set -x
docker build \
  -t ederollora/stratumbuild:build \
  -f Dockerfile.build .
docker tag ederollora/stratumbuild:build ederollora/stratumbuild:${VERSION}
docker push ederollora/stratumbuild:build
docker push ederollora/stratumbuild:${VERSION}

IMAGE_NAME=stratum-release-builder
eval docker build \
  -t $IMAGE_NAME \
  --build-arg USER_NAME="$USER" --build-arg USER_ID="$UID" \
  - < Dockerfile.dev
set +x

# Remove debs and docker.tar.gz files after build
function clean_up_after_build() {
  set +x
  local suffix="deb$\|docker\.tar\.gz"
  local files
  # Untracked files
  files+=$(git ls-files . --exclude-standard --others | grep $suffix || echo "")
  # Ignored files
  files+=$(git ls-files . --exclude-standard --others --ignored | grep $suffix || echo "")
  set -x
  rm -f $files
}

# ---------- Build: BMv2 -------------
#set -x
#RELEASE_BUILD=true \
#  JOBS=${JOBS} \
#  BAZEL_CACHE=${BAZEL_CACHE} \
#  DOCKER_IMG=${IMAGE_NAME} \
#  tools/mininet/build-stratum-bmv2-container.sh
#docker tag opennetworking/mn-stratum:latest opennetworking/mn-stratum:${VERSION}
#docker push opennetworking/mn-stratum:${VERSION}
#docker push opennetworking/mn-stratum:latest
#cp ./stratum_bmv2_deb.deb $RELEASE_DIR
#set +x

# ---------- Cleanup -------------
docker logout
gh auth logout -h github.com
