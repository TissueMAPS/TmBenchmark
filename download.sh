#!/bin/bash

set -e

OPTIND=1

NAME=""
HOST=""
PASSWORD=""
DATA_DIR=""

usage()
{
cat << EOF
Usage: download.sh -n NAME -h HOST -p PASSWORD -d DATA_DIR

Downloads feature data and job statistics from a TissueMAPS server after a benchmark test:

- downloads feature data and metadata for each segmented object of type "Cells"
- downloads workflow statistics of computational jobs

Arguments:
   -n      name of the architecture
   -h      IP address of the host to which data should be uploaded to
   -p      password of the "mustermann" user
   -d      path to the directory where data should be saved
EOF
}

while getopts "n:h:p:d:" opt
do
    case "$opt" in
    n)
        NAME=$OPTARG
        ;;
    h)
        HOST=$OPTARG
        ;;
    p)  PASSWORD=$OPTARG
        ;;
    d)  DATA_DIR=$OPTARG
        ;;
    \?)
        usage
        exit 1
        ;;
    :)
        echo "Error: Option -$OPTARG requires an argument." >&2
        echo
        usage
        exit 1
        ;;
    esac
done

if [[ -z "$HOST" ]] || [[ -z "$PASSWORD" ]] || [[ -z "$PASSWORD" ]] || [[ -z "$NAME" ]]
then
    echo "Error: Arguments NAME, HOST, PASSWORD and DATA_DIR are required." >&2
    echo
    usage
    exit 1
fi

shift $((OPTIND-1))

[ "$1" = "--" ] && shift

if ! ping -c 1 "$HOST" &> /dev/null
then
    echo "Error: Host not found: \"$HOST\"" >&2
    exit 1
fi

if [[ ! -d "$DATA_DIR" ]]
then
    echo "Error: Data directory not found: \"$DATA_DIR\"" >&2
    exit 1
fi

OUTPUT_DIR="$DATA_DIR/$NAME"

if [[ ! -d "$OUTPUT_DIR" ]]
then
    echo "Create output directory: \"$OUTPUT_DIR\"" 2>&1
    mkdir "$OUTPUT_DIR"
fi

BASE_COMMAND () {
    /usr/bin/time --verbose tm_client -H "$HOST" -u "$USER" -p "$PASSWORD" "$@"
}

USER="mustermann"
EXPERIMENT="benchmark"
OBJECT_TYPE="Cells"

SCRIPT=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT")

ALL_COMMANDS () {
    echo "Show detailed workflow status"
    BASE_COMMAND workflow -e $EXPERIMENT status --depth 5

    echo "Download features to \"$OUTPUT_DIR\""
    BASE_COMMAND feature-values -e $EXPERIMENT download -o $OBJECT_TYPE --directory "$OUTPUT_DIR"
}

ALL_COMMANDS > "$SCRIPT_DIR/log/$NAME.download.log" 2>&1

exit 0
