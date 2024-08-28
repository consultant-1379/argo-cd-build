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

push_image() {
    local image="$1"
    docker push "$image"
    status=$?
    if [ $status -eq 0 ]; then
        echo "Successfully pushed $image"
        return 0
    else
        echo "Failed to push $image"
        return 1
    fi
}

declare -A pids
images=("$@")

for image in "${images[@]}"; do
    push_image "$image" &
    pid="$!"
    pids["$pid"]="$image"
done;

for pid in "${!pids[@]}"; do
    image=${pids["$pid"]}
    wait "$pid"
    returnVal="$?"
    if [ "$returnVal" -eq 0 ]; then
        echo "Pushing $image succeeded"
    else
        echo "Pushing $image failed"
    fi
done;
