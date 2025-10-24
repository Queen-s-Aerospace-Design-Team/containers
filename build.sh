#!/bin/bash

set -euo pipefail

# Usage: ./build.sh <folder>
FOLDER=$1
REGISTRY="ghcr.io"
ORG="queen-s-aerospace-design-team"
TAG="latest"
PLATFORMS=("linux/amd64" "linux/arm64")
GIT_USERNAME="$(git config --get user.name)"

source .env # Obtain github cr token from .env file

[[ -z "$FOLDER" ]] && { echo "Usage: $0 <folder-with-Dockerfile>"; exit 1; } # Must provide a folder
[[ -f "$FOLDER/Dockerfile" ]] || { echo "Error: $FOLDER/Dockerfile not found"; exit 1; } # Folder must container dockerfile

BASE="$(basename "$FOLDER")"
NAME="${BASE}"                              # strip optional 'qadt-' prefix
REF="${REGISTRY}/${ORG}/${NAME}:${TAG}"

echo "Building ${REF} for "$(IFS=, ; echo "${PLATFORMS[*]}")" ... "

echo $GHCR_TOKEN | docker login $REGISTRY -u '$GIT_USERNAME' --password-stdin

export BUILDX_NO_DEFAULT_ATTESTATIONS=1 # Builds without default provenance
docker buildx build \
    --platform "$(IFS=,; echo "${PLATFORMS[*]}")" \
    -t "${REF}" \
    "${FOLDER}" \
    --push

echo "Pushed ${REF}"
