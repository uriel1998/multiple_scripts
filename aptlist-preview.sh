#!/bin/bash

set -euo pipefail

script_dir="$(dirname "$(readlink -f "$0")")"
exec "$script_dir/aptlist" __preview "${1:-}"
