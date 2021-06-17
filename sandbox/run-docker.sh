#!/bin/bash
# Copyright (c) 2020, Xilinx
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of FINN nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# green echo
gecho () {
  echo -e "${GREEN}$1${NC}"
}

# red echo
recho () {
  echo -e "${RED}$1${NC}"
}

DOCKER_GID=$(id -g)
DOCKER_GNAME=$(id -gn)
DOCKER_UNAME=$(id -un)
DOCKER_UID=$(id -u)
DOCKER_PASSWD="finn"
# generate a random number per-run to allow multiple
# containers from the same user
DOCKER_RND=$(shuf -i0-32768 -n1)
DOCKER_TAG="sandbox_${DOCKER_UNAME}"
# uncomment to run multiple instances with different names
# DOCKER_INST_NAME="finn_${DOCKER_UNAME}_${DOCKER_RND}"
DOCKER_INST_NAME="sandbox_${DOCKER_UNAME}"
# ensure Docker tag and inst. name are all lowercase
DOCKER_TAG=$(echo "$DOCKER_TAG" | tr '[:upper:]' '[:lower:]')
DOCKER_INST_NAME=$(echo "$DOCKER_INST_NAME" | tr '[:upper:]' '[:lower:]')
# Absolute path to this script, e.g. /home/user/bin/foo.sh
SCRIPT=$(readlink -f "$0")
# Absolute path this script is in, thus /home/user/bin
SCRIPTPATH=$(dirname "$SCRIPT")

# the settings below will be taken from environment variables if available,
# otherwise the defaults below will be used
: ${JUPYTER_PORT=8888}
: ${JUPYTER_PASSWD_HASH=""}
: ${NETRON_PORT=8081}
: ${LOCALHOST_URL="localhost"}
: ${DATASET_PATH=""}

DOCKER_INTERACTIVE=""
DOCKER_EXTRA=""


if [ "$1" = "bash" ]; then
  gecho "Running container only"
  DOCKER_CMD="bash"
  DOCKER_INTERACTIVE="-it"
else
  gecho "Running Jupyter notebook server"
  if [ -z "$JUPYTER_PASSWD_HASH" ]; then
    JUPYTER_PASSWD_ARG=""
  else
    JUPYTER_PASSWD_ARG="--NotebookApp.password='$JUPYTER_PASSWD_HASH'"
  fi
  DOCKER_CMD="jupyter notebook --no-browser --ip=0.0.0.0 --port $JUPYTER_PORT $JUPYTER_PASSWD_ARG notebooks"
  DOCKER_EXTRA+="-e JUPYTER_PORT=$JUPYTER_PORT "
  DOCKER_EXTRA+="-e NETRON_PORT=$NETRON_PORT "
  DOCKER_EXTRA+="-p $JUPYTER_PORT:$JUPYTER_PORT "
  DOCKER_EXTRA+="-p $NETRON_PORT:$NETRON_PORT "
fi

gecho "Docker container is named $DOCKER_INST_NAME"

gecho "Port-forwarding for Jupyter $JUPYTER_PORT:$JUPYTER_PORT"
gecho "Port-forwarding for Netron $NETRON_PORT:$NETRON_PORT"

# Build the FINN Docker image
# Need to ensure this is done within the root folder:
OLD_PWD=$(pwd)
cd $SCRIPTPATH
docker build -f Dockerfile --tag=$DOCKER_TAG \
             --build-arg GID=$DOCKER_GID \
             --build-arg GNAME=$DOCKER_GNAME \
             --build-arg UNAME=$DOCKER_UNAME \
             --build-arg UID=$DOCKER_UID \
             --build-arg PASSWD=$DOCKER_PASSWD \
             .
cd $OLD_PWD

# Launch container with current directory mounted
DOCKER_EXEC="docker run -t --rm $DOCKER_INTERACTIVE --init "
DOCKER_EXEC+="--hostname $DOCKER_INST_NAME "
DOCKER_EXEC+="-e SHELL=/bin/bash "
DOCKER_EXEC+="-v $SCRIPTPATH:/workspace/finn "

# mount dataset
if [ $DATASET_PATH != "" ]; then
  DOCKER_EXEC+="-v $DATASET_PATH:/workspace/dataset "
fi

DOCKER_EXEC+="-e LOCALHOST_URL=$LOCALHOST_URL "
DOCKER_EXEC+="$DOCKER_EXTRA "
DOCKER_EXEC+="$DOCKER_TAG $DOCKER_CMD"

$DOCKER_EXEC