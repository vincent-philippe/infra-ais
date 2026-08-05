#!/bin/sh
set -e

# Resolve *_FILE env vars: export BASE_VAR=$(cat $BASE_VAR_FILE)
for filevar in $(env | grep '_FILE=' | cut -d= -f1); do
  base="${filevar%_FILE}"
  file=$(eval echo "\$$filevar")
  eval "val=\${${base}:-}"
  if [ -n "$val" ]; then
    # La variable principale est déjà définie (par l'utilisateur/Docker), on ne fait rien.
    :
  elif [ -f "$file" ]; then
    export "$base=$(cat "$file")"
  fi
done

exec gosu appuser "$@"
