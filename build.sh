#!/bin/bash
set -euo pipefail

# Usage: ./build.sh <folder> [push|build]

general()
{
    FOLDER=$1
    ACTION=${2:-build} # optional second argument, defaults to "build"

    GIT_USERNAME="$(git config --get user.name)"
    REGISTRY="ghcr.io"
    ORG="queen-s-aerospace-design-team"
    TAG="latest"
    PLATFORMS=("linux/amd64" "linux/arm64")
    if [[ "$ACTION" == "push" ]]; then
        TARGET_PLATFORMS="$(IFS=,; echo "${PLATFORMS[*]}")" # Use all platforms
    else
        TARGET_PLATFORMS="$(docker version -f '{{.Server.Os}}/{{.Server.Arch}}')" # Use host platform
    fi

    source .env # Obtain github cr token from .env file

    [[ -z "$FOLDER" ]] && { echo "Usage: $0 <folder-with-Dockerfile> [push]"; exit 1; }
    [[ -f "$FOLDER/Dockerfile" ]] || { echo "Error: $FOLDER/Dockerfile not found"; exit 1; }

    BASE="$(basename "$FOLDER")"
    NAME="${BASE}"
    REF="${REGISTRY}/${ORG}/${NAME}:${TAG}"

    # --- Things to make sure buildx works ---

    if ! docker buildx ls | grep -q "multiarch-builder"; then
        echo "Creating new multi-platform builder 'multiarch-builder'..."
        docker buildx create --name multiarch-builder --driver docker-container --use
        docker run --privileged --rm tonistiigi/binfmt --install all >/dev/null 2>&1 || true
    else
        docker buildx use multiarch-builder
    fi

    docker buildx inspect --bootstrap >/dev/null
}

build() 
{
    echo "Building ${REF} for $TARGET_PLATFORMS..."

    export BUILDX_NO_DEFAULT_ATTESTATIONS=1 # Needed so we don't get a random unknown:unknown container

    BUILD_CMD=(
        docker buildx build
        --platform "$TARGET_PLATFORMS"
        -t "${REF}"
        "${FOLDER}"
    )

    if [[ "$ACTION" == "push" ]]; then
        # --- Login to GHCR in order to push container ---
        echo "$GHCR_TOKEN" | docker login "$REGISTRY" -u "$GIT_USERNAME" --password-stdin
        BUILD_CMD+=(--push)
    else
        BUILD_CMD+=(--load)
    fi

    "${BUILD_CMD[@]}"
}

general $@
build
