#!/bin/bash

ENV_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../.env"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "[error] .env file not found at $ENV_FILE"
    exit 1
fi

set -a
source "$ENV_FILE"
set +a

if [[ -z "$AUTHORIZED_KEY" ]]; then
    echo "[error] AUTHORIZED_KEY must be set in .env"
    exit 1
fi
