#!/bin/sh
set -e

for filevar in $(env | grep '_FILE=' | cut -d= -f1); do
  base="${filevar%_FILE}"
  file=$(printenv "$filevar")
  if printenv "$base" > /dev/null 2>&1; then
    # La variable principale est déjà définie
    :
  elif [ -f "$file" ]; then
    export "$base=$(cat "$file")"
  fi
done

exec gosu appuser "$@"
