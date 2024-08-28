#!/usr/bin/env bash
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

set -eux -o pipefail

# Function usage() shows how to invoke this script
usage() {
  echo "usage: $0 -v RELEASE_TAG"
  exit 1
}

# parse input args
while [ $# -gt 0 ]; do
  case "$1" in
    --repoURL)
        REPO_URL="${2}"
        shift 2
      ;;
    --version|-v)
        RELEASE_TAG="${2}"
        shift 2
      ;;
    --clone-to)
        WORKSPACE="${2}"
        shift 2
      ;;
    *)
      usage
      ;;
  esac
done

# Function cleanup() cleans all temporary directories if they are available
cleanup() {
    TEMP_DIRS=(
        "${WORKSPACE}"
    )

    for temp_dir in "${TEMP_DIRS[@]}"
    do
      if [[ -d "${temp_dir}" ]]
      then
        rm -rf "${temp_dir}"
      fi
    done
}

# clean workspace if it already exists
cleanup

# clone Release tag version to argo workspace dir
git clone -b "${RELEASE_TAG}" "${REPO_URL}" "${WORKSPACE}"

