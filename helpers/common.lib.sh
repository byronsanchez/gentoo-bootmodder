#!/bin/sh
#
# Common functions used by the scripts

# Standard output functions

function message () {
  if [ "$quiet" != 1 ]
  then
    printf "$1"
  fi
}

function message_error () {
  message "\e[31m$1\e[0m"
}

function message_warn () {
  message "\e[33m$1\e[0m"
}

function message_success () {
  message "\e[32m$1\e[0m"
}

# Flat output inprogress -> complete logging functions

function info () {
  message "  [ \033[00;34m..\033[0m ] $1"
}

function user () {
  message "\r  [ \033[0;33m?\033[0m ] $1 "
}

function success () {
  message "\r\033[2K  [ \033[00;32mOK\033[0m ] $1\n"
}

function warn () {
  message "\r\033[2K  [\033[0;33mWARNING\033[0m] $1\n"
  message "\n"
}

function fail () {
  message "\r\033[2K  [\033[0;31mFAIL\033[0m] $1\n"
  message "\n"
  exit
}

function countdown () {
  totaltime=$1
  timeleft=$totaltime

  while [ "$timeleft" -gt "0" ]; do
    message_error "${bold} $timeleft";
    sleep 1 &
    timeleft=`expr $timeleft - 1`;
    wait
  done
  message "\n";
}

bold=`tput bold`
normal=`tput sgr0`

