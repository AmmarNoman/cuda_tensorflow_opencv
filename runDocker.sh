#!/bin/bash

D_GPUS="--gpus all"

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"

usage () {
  echo ""
  echo "$0 [-h] [-d dir] [-c cmd_full_path] [-N] [-X] [-e \"extra docker options\"] [-b] -- cmd_args"
  echo " -h   this helps text"
  echo " -d   directory mounted in the container as /dmc (default: current directory)"
  echo " -c   Full path of the command to run (accessible from within container) (default: /bin/bash)"
  echo " -N   Non-interactive run (default is interactive)"
  echo " -X   Disable X11 support (default is enabled)"
  echo " -e   Extra docker command line options"
  echo " -b   Bypass any provided command and use the container built in one, if any (also disable any cmd_args provided"
  echo ""
  echo "Run using: CONTAINER_ID=\"<name:tag>\" <PATH_TO_RUNDOCKER>/runDocker.sh <command_line_options>"
  exit 1
}

if [ -z ${CONTAINER_ID+x} ]; then echo "CONTAINER_ID variable not set, unable to continue"; usage; exit 1; fi # variable unset case
if [ "A${CONTAINER_ID}" == "A" ]; then echo "CONTAINER_ID variable empty, unable to continue"; usage; exit 1; fi # variable set but empty case

ARGS_ALWAYS=""
DMC=${PWD}
DRCMD="/bin/bash"
D_ARGS_INT="-it"
D_ARGS_X11=""
D_ARGS_XTRA=""
D_ARGS_BYPASS=""
while getopts ":hd:c:NXe:b" opt; do
  case "$opt" in
    h) usage ;;
    d) DMC=${OPTARG} ;;
    c) RCMD=${OPTARG} ;;
    N) D_ARGS_INT="" ;;
    X) D_ARGS_X11="___" ;;
    e) D_ARGS_XTRA=${OPTARG} ;;
    b) D_ARGS_BYPASS="yes" ;;
    \?) usage ;;
  esac
done
shift "$(($OPTIND -1))"

D_ARGS_OS=""
unameOut="$(uname -s)"
case "${unameOut}" in
  Linux*)     D_ARGS_OS="Linux" ;;
  Darwin*)    D_ARGS_OS="Mac" ;;
  *) echo "Unsupported OS ($unameOut), aborting"; exit 1 ;;
esac

RCMD_ARGS="$@"

if [ "A${D_ARGS_BYPASS}" == "Ayes" ]; then
  RCMD=""
  RCMD_ARGS=""
else
  if [ "A${RCMD}" == "A" ]; then # no command passed, use an interactive shell
    RCMD=${DRCMD}
    D_ARGS_INTS="-it"
  fi
fi

if [ "A${D_ARGS_X11}" == "A___" ]; then
  D_ARGS_X11=""
else
  if [ "A${D_ARGS_OS}" == "ALinux" ]; then
    xhost +local:docker
    XSOCK=/tmp/.X11-unix
    XAUTH=/tmp/.docker.xauth
    USER_UID=$(id -u)
    D_ARGS_X11="-e DISPLAY=$DISPLAY -v $XSOCK:$XSOCK -v $XAUTH:$XAUTH -e XAUTHORITY=$XAUTH"
    xauth nlist :0 | sed -e 's/^..../ffff/' | xauth -f $XAUTH nmerge -
  else # Darwin (macOS)
    xhost + 127.0.0.1
    D_ARGS_X11="-e DISPLAY=host.docker.internal:0"
  fi
fi

if [ "A${D_ARGS_OS}" == "ALinux" ]; then
  ARGS_ALWAYS="-v /etc/localtime:/etc/localtime -v /etc/timezone:/etc/timezone"
fi

DOCKER_RUN="docker run"
if [ "A${D_ARGS_OS}" == "ALinux" ]; then
  if [[ ${CONTAINER_ID} =~ ^datamachines/cud.* ]]; then
    DOCKER_RUN="docker run ${D_GPUS} --ipc host"
  fi 
fi

${DOCKER_RUN} ${D_ARGS_INT} --rm \
    -v ${DMC}:/dmc ${D_ARGS_X11} ${D_ARGS_XTRA} ${ARGS_ALWAYS} \
    ${CONTAINER_ID} ${RCMD} ${RCMD_ARGS}

if [ "A${D_ARGS_X11}" != "A" ]; then
  if [ "A${D_ARGS_OS}" == "ALinux" ]; then
    xhost -local:docker
  fi
fi
