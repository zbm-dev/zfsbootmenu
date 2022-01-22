#!/bin/bash

org="zbm-dev"
repo="zfsbootmenu"

while read -r workflow_id ; do 
  echo "Listing runs for the workflow ID $workflow_id"
  while read -r run_id ; do
    echo "Deleting Run ID $run_id"
    gh api "repos/${org}/${repo}/actions/runs/${run_id}" -X DELETE >/dev/null
  done <<< "$(gh api "repos/${org}/${repo}/actions/workflows/${workflow_id}/runs" --paginate | jq '.workflow_runs[].id')"
done <<< "$(gh api repos/$org/$repo/actions/workflows | jq '.workflows[] | select(.["state"] | contains("disabled_manually")) | .id')"
