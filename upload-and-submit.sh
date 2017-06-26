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
Usage: upload-and-submit.sh -n NAME -h HOST -p PASSWORD -d DATA_DIR

Uploads image data to a TissueMAPS server to perform a benchmark test:

- creates an experiment "benchmark"
- creates a plate "plate1" and an acquisition "acquisition1"
- uploads microscope files located in DATA_DIR
- uploads workflow description from a file in YAML format
- uploads jterator project description from files in YAML format
- submits workflow for asynchronous remote processing

Assumes that the architecture has been built using setup file "NAME.yml"
provided via the Github repository "tissuemaps/tmbenchmark" and the server side
existence of a TissueMAPS user "mustermann" with matching PASSWORD.

Arguments:
   -n      name of the architecture
   -h      IP address of the server to which data should be uploaded to
   -p      password of the "mustermann" user
   -d      path to the directory that contains the microscope files
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

ALL_COMMANDS > "$SCRIPT_DIR/log/$NAME.upload.log" 2>&1

exit 0
