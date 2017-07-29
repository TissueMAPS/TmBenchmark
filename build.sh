#!/usr/bin/bash

set -e

OPTIND=1

PROVIDER=""
CLUSTER=""

usage()
{
cat << EOF
Usage: build.sh -p PROVIDER -c CLUSTER

Builds a TissueMAPS cluster in the cloud based on a setup file
"./setup/PROVIDER/CLUSTER.yaml".

ARGUMENTS:
   -p      name of the cloud provider ("sciencecloud", "aws" or "google")
   -c      name of the cluster
EOF
}

while getopts "c:p:" opt
do
    case "$opt" in
    c)
        CLUSTER=$OPTARG
        ;;
    p)  PROVIDER=$OPTARG
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

if [[ -z $CLUSTER ]] || [[ -z $PROVIDER ]]
then
    echo "Error: Arguments CLUSTER and PROVIDER are required." >&2
    echo
    usage
    exit 1
fi

SCRIPT=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT")
SETUP_DIR="$SCRIPT_DIR/setup/$PROVIDER"
SETUP_FILE="$SETUP_DIR/$CLUSTER.yaml"

if [[ ! -d "$SETUP_DIR" ]]
then
    echo "Error: Unknown cloud provider \"$PROVIDER\"" >&2
    exit 1
fi

if [[ ! -f "$SETUP_FILE" ]]
then
    echo "Error: Unknown cluster \"$CLUSTER\"" >&2
    exit 1
fi

BASE_COMMAND () {
    cmd=$1
    /usr/bin/time --verbose tm_deploy -v vm -s $SETUP_FILE "$cmd" > "$SCRIPT_DIR/log/$PROVIDER/$CLUSTER.$cmd.log" 2>&1;
}

BASE_COMMAND launch

BASE_COMMAND deploy

exit 0
