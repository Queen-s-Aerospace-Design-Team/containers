#!/bin/bash

set -euo pipefail

WORKSPACE="${HOME}/AEAC2026/ros_ws"
REPO_ROOT="${HOME}/AEAC2026"

hasRepoConnection() {
    GIT_TERMINAL_PROMPT=0 timeout 5 git -C "${REPO_ROOT}" ls-remote --exit-code origin >/dev/null 2>&1
}

fetchAndBuild() {
    if hasRepoConnection; then
        echo "==> Repo reachable, updating and building"
        cd "${REPO_ROOT}"
        git pull -p >/dev/null 2>&1
        git submodule update --init --recursive >/dev/null 2>&1

        echo "==> Building ROS workspace"
        cd "${WORKSPACE}"
        colcon build --symlink-install >/dev/null 2>&1
    else
        echo "==> No repo/internet connection, skipping pull and build"
    fi
}

fetchAndBuild

if [ "$#" -gt 0 ]; then
    echo "==> Launching main process: $*"
    exec "$@"
else
    echo "==> No main process provided. Exiting..."
fi