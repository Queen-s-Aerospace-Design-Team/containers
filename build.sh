#!/bin/bash
set -euo pipefail

# Usage: ./build.sh <folder> [push|local]
# The image will look like this on github: ghcr.io/queen-s-aerospace-design-team/<folder>:latest

use_orbstack_on_macos() {
    if [[ "$(uname -s)" == "Darwin" ]]; then
        # OrbStack creates a Docker context called "orbstack"
        if docker context inspect orbstack >/dev/null 2>&1; then
            local current="$(docker context show 2>/dev/null || true)"

            if [[ "$current" != "orbstack" ]]; then
                echo "Switching Docker context to 'orbstack'..."
                docker context use orbstack >/dev/null
            fi
        else
            echo "Error: Docker context 'orbstack' not found."
            echo "Install/launch OrbStack, then run: docker context use orbstack"
            exit 1
        fi
    fi
}

general() {
    use_orbstack_on_macos

    FOLDER=$1
    ACTION=${2:-local} # Action defaults to local builds

    if [[ $ACTION == "push" ]]; then
        source .env # Expects GH Token
    fi

    [[ -z "${FOLDER:-}" ]] && { echo "Usage: $0 <folder-with-Dockerfile> [push|local]"; exit 1; }
    [[ -f "$FOLDER/Dockerfile" ]] || { echo "Error: $FOLDER/Dockerfile not found"; exit 1; }

    GIT_USERNAME="$(git config --get user.name)"
    REGISTRY="ghcr.io"
    ORG="queen-s-aerospace-design-team"
    PLATFORMS=("linux/amd64" "linux/arm64")
    NAME="$(basename "$FOLDER")"

    CACHE_IMAGE="${REGISTRY}/${ORG}/${NAME}:buildcache"
    CACHE_FROM_ARGS=( --cache-from=type=registry,ref="${CACHE_IMAGE}" )
    CACHE_TO_ARGS=( --cache-to=type=registry,ref="${CACHE_IMAGE}",mode=max )

    if [[ "$ACTION" == "push" ]]; then
        TARGET_PLATFORMS="$(IFS=,; echo "${PLATFORMS[*]}")"
        TAG="latest"
    else
        TARGET_PLATFORMS="$(docker version -f '{{.Server.Os}}/{{.Server.Arch}}')"
        TAG="local"
    fi

    REF="${REGISTRY}/${ORG}/${NAME}:${TAG}"
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
    if [[ -n "${GHCR_TOKEN:-}" ]]; then
        echo "$GHCR_TOKEN" | docker login "$REGISTRY" -u "$GIT_USERNAME" --password-stdin
    fi
}

build() {
    echo "Building ${REF} for $TARGET_PLATFORMS..."
    export BUILDX_NO_DEFAULT_ATTESTATIONS=1

    if [[ "$ACTION" == "push" ]]; then
        ensure_builder

        if [[ -z "${GHCR_TOKEN:-}" ]]; then
            echo "Error: GHCR_TOKEN is required to push '${REF}'. Perform a local build instead or provide a token."
            exit 1
        fi

        maybe_login_to_registry

        docker buildx build \
            --platform "$TARGET_PLATFORMS" \
            -t "${REF}" \
            --push \
            "${CACHE_FROM_ARGS[@]}" \
            "${CACHE_TO_ARGS[@]}" \
            "${FOLDER}"
    else
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

echo
echo "Finished publishing image '${REF}'"
