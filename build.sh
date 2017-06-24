#!/usr/bin/bash

set -e

NAME=$1

if [[ -z $NAME ]]
then
    echo "Error: Name of the architecture must be provided." >&2
    exit 1
fi

SCRIPT=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT")

BASE_COMMAND () {
    cmd=$1
    /usr/bin/time --verbose tm_deploy -v vm -s "$SCRIPT_DIR/setup/$NAME.yaml" "$cmd" > "$SCRIPT_DIR/log/$NAME.$cmd.log" 2>&1;
}

BASE_COMMAND launch

BASE_COMMAND deploy

exit 0
