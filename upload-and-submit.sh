#!/bin/bash

set -e

OPTIND=1

PROVIDER=""
CLUSTER=""
HOST=""
PASSWORD=""
DATA_DIR=""

usage() {
cat << EOF
Usage: upload-and-submit.sh -p PROVIDER -c CLUSTER -H HOST -d DATA_DIR

Uploads image data to a TissueMAPS server to perform a benchmark test:

- creates an experiment "benchmark"
- creates a plate "plate1" and an acquisition "acquisition1"
- uploads microscope files located in DATA_DIR
- uploads workflow description from a file in YAML format
- uploads jterator project description from files in YAML format
- submits workflow for asynchronous remote processing

Assumes that the cluster has been built using setup file "CLUSTER.yaml" and
that a TissueMAPS user "mustermann" exists server side.

Arguments:
   -p      name of the cloud provider ("sciencecloud", "aws" or "google")
   -c      name of the cluster
   -H      IP address of the server to which data should be uploaded to
   -d      path to the directory that contains the microscope files
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

if [[ -z "$HOST" ]] || [[ -z "$PROVIDER" ]] || [[ -z "$CLUSTER" ]] || [[ -z "$DATA_DIR" ]]
then
    echo "Error: Arguments PROVIDER, CLUSTER, HOST and DATA_DIR are required." >&2
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

SUPPORTED_PROVIDERS=('sciencecloud', 'aws', 'google')
if echo $SUPPORTED_PROVIDERS[@] | grep -q -v -w "$PROVIDER"
then
    echo "Error: Unknown provider \"$PROVIDER\"." >&2
    exit 1
fi

USER="mustermann"
read -s -p "Password for user \"$USER\":" PASSWORD

if [[ -z "$PASSWORD" ]]
then
    echo "Error: No password entered." >&2
    exit 1
fi

EXPERIMENT="benchmark"
PLATE="plate1"
ACQUISITION="acquisition1"

SCRIPT=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT")
WORKFLOW_FILE="$SCRIPT_DIR/workflow.yaml"
JTPROJECT_DIR="$SCRIPT_DIR/jtproject"

BASE_COMMAND () {
    /usr/bin/time --verbose tm_client -H "$HOST" -u "$USER" -p "$PASSWORD" "$@";
}

ALL_COMMANDS () {
    echo "Create experiment \"$EXPERIMENT\""
    BASE_COMMAND experiment create -n $EXPERIMENT

    echo "Create plate \"$PLATE\""
    BASE_COMMAND plate -e $EXPERIMENT create -n $PLATE

    echo "Create acquisition \"$ACQUISITION\""
    BASE_COMMAND acquisition -e $EXPERIMENT create -p $PLATE -n $ACQUISITION

    echo "Upload microscope files from \"$DATA_DIR\""
    BASE_COMMAND microscope-file -e $EXPERIMENT upload -p $PLATE -a $ACQUISITION --directory $DATA_DIR

    echo "Upload workflow description from \"$WORKFLOW_FILE\""
    BASE_COMMAND workflow -e $EXPERIMENT upload --file $WORKFLOW_FILE

    echo "Upload jterator project description from \"$JTPROJECT_DIR\""
    BASE_COMMAND jtproject -e $EXPERIMENT upload --directory $JTPROJECT_DIR

    echo "Submit workflow"
    BASE_COMMAND workflow -e $EXPERIMENT submit
}

ALL_COMMANDS > "$SCRIPT_DIR/log/$PROVIDER/$CLUSTER.upload.log" 2>&1

exit 0
