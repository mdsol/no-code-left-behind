#!/bin/bash

# Checks that all sha hashes from the leaver's fork are represented on the departeduser's fork
# Either:
#  Pass in DEPARTEDUSER as the environment variable
# Or, uncomment and complete the following
#  DEPARTEDUSER=""

function check_hashes
{
  local forkname=$1
  local repository=$(echo ${forkname#*/})
  local owner=$(echo ${forkname%/*})
  local fork="${owner}/${repository}"
  local copy="${DEPARTEDUSER}/${repository}"
  copy_branches=$(curl https://api.github.com/repos/${copy}/branches)
  shas=$(curl https://api.github.com/repos/${fork}/branches | grep '"sha"' | awk '{print $2}') 
  for sha in ${shas}; 
  do 
    echo "Checking ${sha}" 
    check=$(echo $copy_branches | grep $sha); 
    if [ -z "${check}" ]; then 
      echo "${shas} is missing"; 
    fi; 
  done
}

check_hashes $1