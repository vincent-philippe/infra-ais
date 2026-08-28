#!/bin/bash
# This script will export any env variable from the .env to the current script

ENV_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../.env"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "[error] .env file not found at $ENV_FILE"
    exit 1
fi

set -a
source "$ENV_FILE"
set +a

if [[ -z "$SSH_KEY_PATH" ]]; then
    echo "[error] SSH_KEY_PATH must be set in .env"
    exit 1
fi

if [[ ! -f "$SSH_KEY_PATH.pub" ]]; then
    echo "[error] public key not found at $SSH_KEY_PATH.pub"
    exit 1
fi

export AUTHORIZED_KEY
AUTHORIZED_KEY="$(cat "$SSH_KEY_PATH.pub")"

if [[ -z "$CONSOLE_ADMIN_PASSWORD" ]]; then
    echo "[error] CONSOLE_ADMIN_PASSWORD must be set in .env"
    exit 1
fi
