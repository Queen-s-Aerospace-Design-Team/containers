#!/bin/bash
set -euo pipefail

# Usage: ./build.sh <folder> [push|local]
# The image will look like this on github: ghcr.io/queen-s-aerospace-design-team/<folder>:latest

general() {
    source .env # Expects GH Token

    FOLDER=$1
    ACTION=${2:-local} # Action defaults to local builds

    GIT_USERNAME="$(git config --get user.name)"
    REGISTRY="ghcr.io"
    ORG="queen-s-aerospace-design-team"
    TAG="latest"
    PLATFORMS=("linux/amd64" "linux/arm64")

    if [[ "$ACTION" == "push" ]]; then
        TARGET_PLATFORMS="$(IFS=,; echo "${PLATFORMS[*]}")"   # multi-arch for pushes
    else
        TARGET_PLATFORMS="$(docker version -f '{{.Server.Os}}/{{.Server.Arch}}')"  # host arch
    fi

    [[ -z "$FOLDER" ]] && { echo "Usage: $0 <folder-with-Dockerfile> [push|local]"; exit 1; }
    [[ -f "$FOLDER/Dockerfile" ]] || { echo "Error: $FOLDER/Dockerfile not found"; exit 1; }

    BASE="$(basename "$FOLDER")"
    NAME="${BASE}"
    REF="${REGISTRY}/${ORG}/${NAME}:${TAG}"

    # Cache the image on the remote as well (GitHub Registry)
    CACHE_IMAGE="${REGISTRY}/${ORG}/${NAME}:buildcache"
}

ensure_builder() {
    local BUILDER="multiarch-builder"

    if docker buildx inspect "$BUILDER" >/dev/null 2>&1; then
        docker buildx use "$BUILDER" >/dev/null
    else
        echo "Creating builder '$BUILDER'..."
        docker buildx create --name "$BUILDER" --driver docker-container --use >/dev/null
    fi

    # binfmt only needed for cross-arch (push)
    if [[ "$ACTION" == "push" ]]; then
        docker run --privileged --rm tonistiigi/binfmt --install all >/dev/null 2>&1 || true
    fi

    docker buildx inspect --bootstrap >/dev/null
}

maybe_login_to_registry() {
    # Login only if a token is provided
    if [[ -n "${GHCR_TOKEN:-}" ]]; then
        echo "$GHCR_TOKEN" | docker login "$REGISTRY" -u "$GIT_USERNAME" --password-stdin >/dev/null
    fi
}

build() {
    echo "Building ${REF} for $TARGET_PLATFORMS..."
    export BUILDX_NO_DEFAULT_ATTESTATIONS=1

    # By default, pull cache from remote registry
    CACHE_FROM_ARGS=( --cache-from=type=registry,ref="${CACHE_IMAGE}" )
    
    ensure_builder
    maybe_login_to_registry

    if [[ "$ACTION" == "push" ]]; then
        # Pushing the image requires auth; fail fast if missing
        if [[ -z "${GHCR_TOKEN:-}" ]]; then
            echo "Error: GHCR_TOKEN is required to push '${REF}'. Perform a local build instead or provide a token."
            exit 1
        fi

        # Upload to registry cache only when a GitHub Token is provided (otherwise you can't run 'docker buildx build ... --push')
        CACHE_TO_ARGS=( --cache-to=type=registry,ref="${CACHE_IMAGE}",mode=max )

        docker buildx build \
            --platform "$TARGET_PLATFORMS" \
            -t "${REF}" \
            --push \
            "${CACHE_FROM_ARGS[@]}" \
            "${CACHE_TO_ARGS[@]}" \
            "${FOLDER}"
    else
        # Local single-arch build that still benefits from local cache
        docker buildx build \
            --platform "$TARGET_PLATFORMS" \
            -t "${REF}" \
            --load \
            "${CACHE_FROM_ARGS[@]}" \
            "${FOLDER}"
    fi
}

general "$@"
build
