#!/bin/bash

# Checks that all sha hashes from the leaver's fork are represented on the departeduser's fork
# Either:
#  Pass in DEPARTEDUSER as the environment variable
# Or, uncomment and complete the following
#  DEPARTEDUSER=""

function usage
{
  echo "Usage is: ${0} [forkname] [(OPTIONAL) Original name]"
  echo "where [forkname] is the name of the fork (eg someuser/OriginalRepo)"
  echo "if the fork has been renamed, then specify the name of the source repository as a second argument"
}

function check_hashes
{
  if [ -z "${DEPARTEDUSER}" ]; then
    echo "Need to supply a DEPARTEDUSER value"
    exit 1
  fi
  local forkname=$1
  local reponame=$2
  local repository=$(echo ${forkname#*/})
  local owner=$(echo ${forkname%/*})
  local fork="${owner}/${repository}"
  if [ -n "${reponame}" ]; then
    local copy="${DEPARTEDUSER}/${reponame}"
  else
    local copy="${DEPARTEDUSER}/${repository}"
  fi
  declare -i ERROR
  ERROR=0
  # get the shas for the branches on the departed user fork
  copy_branches=$(curl https://api.github.com/repos/${copy}/branches | grep '"sha"' | awk '{print $2}' | sed 's/,//')
  shas=$(curl https://api.github.com/repos/${fork}/branches | grep '"sha"' | awk '{print $2}' | sed 's/,//') 
  for sha in $(echo ${shas}); 
  do 
    check=$(echo "${copy_branches}" | grep $sha); 
    if [ -z "${check}" ]; then 
      ERROR=1
      echo "SHA ${sha} is missing";
      matching=$(curl https://api.github.com/repos/${fork}/branches | grep -B 2 ${sha} | grep "name" | awk '{print $2}')
      echo "Branch: ${matching}"
    fi 
  done
  if [ $ERROR -eq 0 ]; then
    echo "No missing branches found by commit SHA"
  fi
}

if [ $# -ge 1 ]; then
  check_hashes $1 $2
else
  usage
fi
