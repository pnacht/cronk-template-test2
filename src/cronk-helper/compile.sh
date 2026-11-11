#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
cd "$SCRIPT_DIR"
mkdir -p ../../bin
gcc -O2 -Wall -o ../../bin/cronk-helper cronk_helper.c
