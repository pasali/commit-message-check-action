#!/usr/bin/env bash

set -e
set -o pipefail

if [[ -z "$GITHUB_TOKEN" ]]; then
	echo "Set the GITHUB_TOKEN env variable."
	exit 1
fi

if [[ -z "$GITHUB_REPOSITORY" ]]; then
	echo "Set the GITHUB_REPOSITORY env variable."
	exit 1
fi

if [[ -z "$MSG_REGEX" ]]; then
	echo "Set the MSG_REGEX env variable."
	exit 1
fi

URI=https://api.github.com
API_VERSION=v3
API_HEADER="Accept: application/vnd.github.${API_VERSION}+json; application/vnd.github.antiope-preview+json"
AUTH_HEADER="Authorization: token ${GITHUB_TOKEN}"

delete_comment_if_exists() {
	# Get all the comments for the pull request.
	body=$(curl -sSL -H "${AUTH_HEADER}" -H "${API_HEADER}" "${URI}/repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments")

	comments=$(echo "$body" | jq --raw-output '.[] | {id: .id, body: .body} | @base64')

	for c in $comments; do
		comment="$(echo "$c" | base64 --decode)"
		id=$(echo "$comment" | jq --raw-output '.id')
		b=$(echo "$comment" | jq --raw-output '.body')

		if [[ "$b" == *"<!--commit-message-check-action-->"* ]]; then
			echo "Deleting old comment ID: $id"
			curl -sSL -H "${AUTH_HEADER}" -H "${API_HEADER}" -X DELETE "${URI}/repos/${GITHUB_REPOSITORY}/issues/comments/${id}"
		fi
	done
}

post_comment() {
request_body=$(cat <<EOF
{
  "body": "<!--commit-message-check-action-->Following commit message(s) does not meet the criteria:\n\n $1"

}
EOF
)
	curl -sSL -H "${AUTH_HEADER}" \
	          -H "${API_HEADER}" \
	          -H "Content-Type: application/json" \
	          -X POST "${URI}/repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments"\
	          -d "${request_body}"
}

main() {
  curl -o /dev/null -sSL -H "${AUTH_HEADER}" -H "${API_HEADER}" "${URI}/repos/${GITHUB_REPOSITORY}" || { echo "Error: Invalid repo, token or network issue!";  exit 1; }

  PR_NUMBER=$(jq --raw-output .number "$GITHUB_EVENT_PATH")

  body=$(curl -sSL -H "${AUTH_HEADER}" -H "${API_HEADER}" -H "Content-Type: application/json" "${URI}/repos/${GITHUB_REPOSITORY}/pulls/${PR_NUMBER}/commits")
	commits=$(echo "$body" | jq --raw-output '.[] | {message: .commit.message, id: .sha}  | @base64')
	bad_commit_messages=""
  for c in $commits; do
  	 commit="$(echo "$c" | base64 --decode)"
		 message=$(echo "$commit" | jq --raw-output '.message')
		 id=$(echo "$commit" | jq --raw-output '.id')

		 if [[ ! "$message" =~ $MSG_REGEX ]]; then
		 	echo "$message doesn't match regex = $MSG_REGEX"
		 	bad_commit_messages+=" - $message \n"
		 fi
	done
	if [[ ! -z "$bad_commit_messages" ]]; then
		delete_comment_if_exists
	  post_comment "$bad_commit_messages"
	  exit 1
  fi

}

main