#!/bin/bash

set -e

# Argument parsing
OPTIND=1

HOST=""
PASSWORD=""

usage()
{
cat << EOF
usage: upload-benchmark.sh -h HOST -p PASSWORD

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
EOF
}

while getopts "h:p:" opt
do
    case "$opt" in
    h)
        HOST=$OPTARG
        ;;
    p)  PASSWORD=$OPTARG
        ;;
    \?)
        usage
        exit 1
        ;;
    :)
        echo "Error: Option -$OPTARG requires an argument." >&2
        usage
        exit 1
        ;;
    esac
done

if [[ -z $HOST ]] || [[ -z $PASSWORD ]]
then
    echo "Error: Arguments HOST and PASSWORD are required." >&2
    exit 1
fi

shift $((OPTIND-1))

[ "$1" = "--" ] && shift

if ! ping -c 1 $HOST &> /dev/null
then
    echo "Error: Host \"$HOST\" not found."
fi

USER="mustermann"

BASE_COMMAND="tm_client -H $HOST -u $USER -p $PASSWORD"

EXPERIMENT="benchmark"
PLATE="plate1"
ACQUISITION="acquisition1"

DATA_DIR="/storage/$EXPERIMENT"
MICROSCOPE_FILES_DIR="$DATA_DIR/microscope_files"
WORKFLOW_FILE="$DATA_DIR/workflow.yml"
JTPROJECT_DIR="$DATA_DIR/jtproject"

echo "Create experiment \"$EXPERIMENT\""
$BASE_COMMAND experiment create -n $EXPERIMENT

echo "Create plate \"$PLATE\""
$BASE_COMMAND plate -e $EXPERIMENT create -n $PLATE

echo "Create acquisition \"$ACQUISITION\""
$BASE_COMMAND acquisition -e $EXPERIMENT create -p $PLATE -n $ACQUISITION

echo "Upload microscope files from \"$MICROSCOPE_FILES_DIR\""
$BASE_COMMAND microscope-file -e $EXPERIMENT upload -p $PLATE -a $ACQUISITION --directory $MICROSCOPE_FILES_DIR

echo "Upload workflow description from \"$WORKFLOW_FILE\""
$BASE_COMMAND workflow -e $EXPERIMENT upload --file $WORKFLOW_FILE

echo "Upload jterator project description from \"$JTPROJECT_DIR\""
$BASE_COMMAND jtproject -e $EXPERIMENT upload --directory $JTPROJECT_DIR

echo "Submit workflow"
$BASE_COMMAND workflow -e $EXPERIMENT submit

exit 0
