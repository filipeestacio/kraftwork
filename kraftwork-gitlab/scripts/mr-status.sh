#!/bin/sh
#
# mr-status.sh - Poll MR status for glab-watch
#
# Usage: mr-status.sh <MR_IID>
#   MR_IID: Merge request internal ID (must be run from within a git repo)
#
# Output: JSON object with mr, pipeline, threads, ready_to_merge, merged fields
#
# Exit codes:
#   0 - Success
#   1 - Missing arguments, not in a git repo, or API failure
#

set -eu

MR_IID="${1:-}"

if [ -z "$MR_IID" ]; then
  echo "Usage: mr-status.sh <MR_IID>" >&2
  exit 1
fi

REMOTE_URL=$(git remote get-url origin 2>/dev/null) || {
  echo "Not inside a git repository or no origin remote" >&2
  exit 1
}

PROJECT_PATH=$(echo "$REMOTE_URL" | sed -E 's|^https?://[^/]+/||; s|^.*:||; s|\.git$||')
ENCODED_PATH=$(printf '%s' "$PROJECT_PATH" | jq -sRr @uri)

MR_JSON=$(glab api "projects/${ENCODED_PATH}/merge_requests/${MR_IID}" 2>/dev/null) || {
  echo '{"error": "Failed to fetch MR details"}' >&2
  exit 1
}

APPROVALS_JSON=$(glab api "projects/${ENCODED_PATH}/merge_requests/${MR_IID}/approvals" 2>/dev/null || echo '{}')

PIPELINES_JSON=$(glab api "projects/${ENCODED_PATH}/merge_requests/${MR_IID}/pipelines?per_page=1" 2>/dev/null || echo '[]')

PIPELINE_ID=$(echo "$PIPELINES_JSON" | jq -r '.[0].id // empty')

JOBS_JSON="[]"
if [ -n "$PIPELINE_ID" ]; then
  JOBS_JSON=$(glab api "projects/${ENCODED_PATH}/pipelines/${PIPELINE_ID}/jobs?per_page=100" 2>/dev/null || echo '[]')
fi

DISCUSSIONS_JSON=$(glab api "projects/${ENCODED_PATH}/merge_requests/${MR_IID}/discussions?per_page=100" 2>/dev/null || echo '[]')

jq -n \
  --argjson mr "$MR_JSON" \
  --argjson approvals "$APPROVALS_JSON" \
  --argjson pipelines "$PIPELINES_JSON" \
  --argjson jobs "$JOBS_JSON" \
  --argjson discussions "$DISCUSSIONS_JSON" \
  '{
    mr: {
      iid: $mr.iid,
      state: $mr.state,
      title: $mr.title,
      source_branch: $mr.source_branch,
      mergeable: ($mr.merge_status == "can_be_merged"),
      has_conflicts: $mr.has_conflicts,
      approved: ($approvals.approved // false),
      approvals: {
        current: ($approvals.approved_by | length),
        required: ($approvals.approvals_required // 0)
      }
    },
    pipeline: (
      if ($pipelines | length) > 0 then
        {
          status: $pipelines[0].status,
          id: $pipelines[0].id,
          url: $pipelines[0].web_url,
          failed_jobs: [
            $jobs[] | select(.status == "failed") | {id: .id, name: .name, stage: .stage}
          ],
          summary: (
            ($jobs | map(select(.status == "success")) | length | tostring) + "/" +
            ($jobs | length | tostring) + " passed, " +
            ($jobs | map(select(.status == "failed")) | length | tostring) + " failed, " +
            ($jobs | map(select(.status == "running")) | length | tostring) + " running"
          )
        }
      else
        null
      end
    ),
    threads: {
      unresolved: [
        $discussions[]
        | select(.notes[0].resolvable == true)
        | select(.notes[-1].resolved != true)
        | {
            id: .id,
            author: .notes[0].author.username,
            body: .notes[0].body,
            file: (.notes[0].position.new_path // null),
            line: (.notes[0].position.new_line // null),
            created_at: .notes[0].created_at
          }
      ],
      count: {
        total: ($discussions | length),
        unresolved: (
          [ $discussions[]
            | select(.notes[0].resolvable == true)
            | select(.notes[-1].resolved != true)
          ] | length
        )
      }
    },
    ready_to_merge: (
      ($pipelines | length) > 0
      and $pipelines[0].status == "success"
      and ($approvals.approved // false)
      and ([ $discussions[]
             | select(.notes[0].resolvable == true)
             | select(.notes[-1].resolved != true)
           ] | length) == 0
      and ($mr.merge_status == "can_be_merged")
      and ($mr.has_conflicts | not)
    ),
    merged: ($mr.state == "merged")
  }'
