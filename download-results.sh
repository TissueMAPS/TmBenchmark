#!/bin/bash

set -e

OPTIND=1

PROVIDER=""
CLUSTER=""
HOST=""
PASSWORD=""
DATA_DIR=""

usage()
{
cat << EOF
Usage: download-results.sh -p PROVIDER -c CLUSTER -H HOST -d DATA_DIR

Downloads feature data and job statistics from a TissueMAPS server after a benchmark test:

- downloads feature data and metadata for each segmented object of type "Cells"
- downloads workflow statistics of computational jobs

Assumes that the cluster has been built using setup file "CLUSTER.yaml" and
that a TissueMAPS user "mustermann" exists server side.

Arguments:
   -p      name of the cloud provider ("sciencecloud", "aws" or "google")
   -c      name of the cluster
   -H      IP address of the host to which data should be uploaded to
   -d      path to the directory where data should be saved
EOF
}

while getopts "c:H:p:d:" opt
do
    case "$opt" in
    c)
        CLUSTER=$OPTARG
        ;;
    H)
        HOST=$OPTARG
        ;;
    p)  PROVIDER=$OPTARG
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

shift $((OPTIND-1))

[ "$1" = "--" ] && shift

if [[ -z "$HOST" ]] || [[ -z "$DATA_DIR" ]] || [[ -z "$CLUSTER" ]] || [[ -z "$PROVIDER" ]]
then
    echo "Error: Arguments PROVIDER, CLUSTER, HOST and DATA_DIR are required." >&2
    echo
    usage
    exit 1
fi

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

SUPPORTED_PROVIDERS=('sciencecloud', 'aws', 'google')
if echo $SUPPORTED_PROVIDERS[@] | grep -q -v -w "$PROVIDER"
then
    echo "Error: Unknown cloud provider \"$PROVIDER\"." >&2
    exit 1
fi

USER="mustermann"
read -s -p "Password for user \"$USER\":" PASSWORD

if [[ -z "$PASSWORD" ]]
then
    echo "Error: No password entered." >&2
    exit 1
fi

OUTPUT_DIR="$DATA_DIR/$PROVIDER/$CLUSTER"

if [[ ! -d "$OUTPUT_DIR" ]]
then
    echo "Create output directory: \"$OUTPUT_DIR\"" 2>&1
    mkdir -p "$OUTPUT_DIR"
fi

EXPERIMENT="benchmark"
OBJECT_TYPE="Cells"

SCRIPT=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT")

BASE_COMMAND () {
    /usr/bin/time --verbose tm_client -H "$HOST" -u "$USER" -p "$PASSWORD" "$@"
}

ALL_COMMANDS () {
    echo "Show workflow status"
    BASE_COMMAND workflow -e $EXPERIMENT status

    echo "Download features to \"$OUTPUT_DIR\""
    BASE_COMMAND feature-values -e $EXPERIMENT download -o $OBJECT_TYPE --directory "$OUTPUT_DIR"
}

echo ALL_COMMANDS > "$SCRIPT_DIR/log/$PROVIDER/$CLUSTER.download.log" 2>&1

exit 0
