#!/bin/bash

set -e

OPTIND=1

HOST=""
PASSWORD=""
DATA_DIR=""

usage()
{
cat << EOF
Usage: upload-benchmark.sh -h HOST -p PASSWORD -d DATA_DIR

Uploads data to a TissueMAPS server to perform a benchmark test:

- creates a experiment named "benchmark"
- creates a plate named "plate1" and an acquisition named "acquisition1"
- uploads microscope image files
- uploads workflow description in YAML format
- uploads jterator project description in YAML format
- submits workflow

Arguments:
   -h      IP address of the host to which data should be uploaded to
   -p      password of the "mustermann" user
   -d      path to the directory where mircoscope files are located
EOF
}

while getopts "h:p:d:" opt
do
    case "$opt" in
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

if [[ -z $HOST ]] || [[ -z $PASSWORD ]] || [[ -z $PASSWORD ]]
then
    echo "Error: Arguments HOST and PASSWORD and DATA_DIR are required." >&2
    echo
    usage
    exit 1
fi

shift $((OPTIND-1))

[ "$1" = "--" ] && shift

if ! ping -c 1 $HOST &> /dev/null
then
    echo "Error: Host not found: \"$HOST\""
    exit 1
fi

if [[ ! -d $DATA_DIR ]]
then
    echo "Error: Data directory not found: \"$DATA_DIR\""
    exit 1
fi

BASE_COMMAND () {
    /usr/bin/time --verbose tm_client -H "$HOST" -u "$USER" -p "$PASSWORD" "$@";
}

USER="mustermann"
EXPERIMENT="benchmark"
PLATE="plate1"
ACQUISITION="acquisition1"

SCRIPT=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT")
WORKFLOW_FILE="$SCRIPT_DIR/workflow.yaml"
JTPROJECT_DIR="$SCRIPT_DIR/jtproject"

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

exit 0
