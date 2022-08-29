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

SCRIPTNAME=$(basename $(readlink -f ${0}))

print_usage() {
  echo "Usage: $SCRIPTNAME <dockerd-executable>"
}

get_addr() {
  if [ "${1}" == "" ] || [ "${2}" != "" ]; then
    echo "get_addr requires exactly one argument" 1>&2
    exit 1
  fi
  nm ${EXEC} | grep ${1}_ifunc | grep -oE "^[0-9a-f]{8}"
}

is_odd() {
  if [ "${1}" == "" ] || [ "${2}" != "" ]; then
    echo "is_odd requires exactly one argument" 1>&2
    exit 1
  fi
  echo "ibase=16;obase=10;${1^^} % 2" | bc
}

bswap8() {
  echo ${1:6:2}${1:4:2}${1:2:2}${1:0:2}
}

main() {
  SYMS=(memcpy memchr)
  ADRS_ODD=()
  ADRS_EVEN=()

  for sym in "${SYMS[@]}"; do
    echo -n "Determining address of ${sym}... "

    ADR_ODD=$(get_addr ${sym})
    ADR_EVEN=$(printf "%08x" 0x$(echo "ibase=16;obase=10;${ADR_ODD^^} - 1" | bc))

    if [ "$(is_odd ${ADR_ODD})" == "0" ]; then
        echo "Failed! Address of ${sym} is even -- patch does not apply"
        exit 1
    fi
    echo "${ADR_ODD}"

    echo -n "Byte-swapping ${ADR_ODD}... "
    ADR_ODD=$(bswap8 ${ADR_ODD})
    ADRS_ODD+=("${ADR_ODD}")
    echo "${ADR_ODD}"

    echo -n "Byte-swapping ${ADR_EVEN}... "
    ADR_EVEN=$(bswap8 ${ADR_EVEN})
    ADRS_EVEN+=("${ADR_EVEN}")
    echo "${ADR_EVEN}"

    echo -n "Adding replace expression... "
    REPLACE_NEW="s/${ADR_EVEN}/${ADR_ODD}/g;"
    echo  "${REPLACE_NEW}"
    REPLACE="${REPLACE}${REPLACE_NEW}"
  done

  echo -n "Replacing symbol values with ${REPLACE}... "
  if xxd -g 4 ${EXEC} | sed ${REPLACE} | xxd -r >${EXEC}.new; then
    echo "OK"
  else
    echo "Failed!"
    exit 1
  fi

  echo "Verifying .got... "
  for adr in "${ADRS_EVEN[@]}"; do
    if ! objdump -s -j .got ${EXEC}.new | grep ${adr}; then
      echo "    does not contain ${adr}"
    else
      echo "Failed!"
      exit 1
    fi
  done

  for adr in "${ADRS_ODD[@]}"; do
    if objdump -s -j .got ${EXEC}.new | grep ${adr} >/dev/null; then
      echo "    contains ${adr}"
    else
      echo "Failed!"
      exit 1
    fi
  done

  mv -f ${EXEC}.new ${EXEC}
  chmod a+x ${EXEC}

  echo "All done!"
}

EXEC=${1}
if [ -z "${EXEC}" ] || [ ! -x "${EXEC}" ]; then
  print_usage
  exit 1
fi

main
