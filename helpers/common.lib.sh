#!/bin/sh
# Licensed under GPL-3
#
# Common functions used by the scripts

function message () {
  if [ "$quiet" != 1 ]
  then
    printf "$1"
  fi
}

function info () {
  message "\e[34m$1\e[0m"
}

function success () {
  message "\e[32m$1\e[0m"
}

function warn () {
  message "\e[33m$1\e[0m"
  message "\n"
}

function fail () {
  message "\e[31m$1\e[0m"
  message "\n"
  exit
}

function countdown () {
  totaltime=$1
  timeleft=$totaltime

  while [ "$timeleft" -gt "0" ]; do
    message_error "${bold} $timeleft";
    # fork and merge to reduce delays introduced by instruciton executions
    sleep 1 &
    timeleft=`expr $timeleft - 1`;
    wait
  done
  message "\n";
}

bold=`tput bold`
normal=`tput sgr0`

