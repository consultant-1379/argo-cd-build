#! /usr/bin/env bash
#
# COPYRIGHT Ericsson 2024
#
#
#
# The copyright to the computer program(s) herein is the property of
#
# Ericsson Inc. The programs may be used and/or copied only with written
#
# permission from Ericsson Inc. or in accordance with the terms and
#
# conditions stipulated in the agreement/contract under which the
#
# program(s) have been supplied.
#

set -x;

DECLARATIVE_DEPLOYER_PATH="$1"
CHANGED_FILES_BOBVAR_FILE="$2"
IMAGE_VERSION="$3"

# Absolute filepath to this script
case "$(uname -s)" in
Darwin*) SCRIPT=$(greadlink -f $0) ;;
*) SCRIPT=$(readlink -f $0) ;;
esac

# Location of parent dir
BASE_DIR=$(dirname $SCRIPT)
REPOROOT=$(dirname $(dirname $BASE_DIR))

mapfile -t changedFiles < $CHANGED_FILES_BOBVAR_FILE

cd $DECLARATIVE_DEPLOYER_PATH

gerrit create-patch --file ${changedFiles[*]} \
    --message "[NoJira] Update Argo CD images to $IMAGE_VERSION" \
    --git-repo-local . \
    --wait-label "Verified"="+1" \
    --debug \
    --email ${EMAIL} \
    --timeout 7200
    #--submit

changeStatus=$? 

if [ $changeStatus -eq 0 ]; then
        echo "Change verification is successful"
else
    echo "Change failed verification"
    exit 1
fi 