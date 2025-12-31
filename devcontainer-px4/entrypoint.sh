#!/bin/bash

set -euo pipefail

MicroXRCEDDS udp4 -p 8888 >/dev/null 2>&1 &

echo "==> Container ready"

exec "$@"