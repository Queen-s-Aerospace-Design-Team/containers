#!/bin/bash

set -euo pipefail

echo "==> Container ready"

MicroXRCEAgent udp4 -p 8888 &

exec "$@"