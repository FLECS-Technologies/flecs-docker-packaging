#!/bin/bash

# Copyright 2021-2022 FLECS Technologies GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

containerd >/tmp/containerd.log 2>&1 &
dockerd >/tmp/dockerd.log 2>&1 &

TIMEOUT=0
while ! docker version >/dev/null 2>&1 && [ ${TIMEOUT} -lt 10 ]; do
  sleep 1;
  TIMEOUT=$((TIMEOUT + 1))
done

if [ ${TIMEOUT} -ge 10 ]; then
  echo "dockerd did not start in time" 1>&2;
  exit 1;
fi

docker version
