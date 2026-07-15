#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/lib.sh"

service="$1"
shift

compose "${service}" "$@"
