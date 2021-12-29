#!/bin/bash
trap - SIGINT
def_args="$1"

function sigint() {
  exit 1
}

trap sigint SIGINT
read -r -e -i "${def_args}" -p "> " input 
echo "${input}"
exit 0
