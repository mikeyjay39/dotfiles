#!/usr/bin/env bash
# Usage: watch-pr.sh <pr-number> [owner-login] [repo]
# Exits when the PR gets a review, review comment or comment from anyone but the owner account,
# or when its state or review decision changes. The owner is skipped because the agents post as it.
pr=$1
owner=${2:-$(gh api user --jq .login)}
repo=${3:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}
poll_seconds=${POLL_SECONDS:-120}

snapshot() {
  {
    gh api "repos/$repo/pulls/$pr/reviews" --paginate --jq ".[]|select(.user.login!=\"$owner\")|\"review \(.id) \(.state)\""
    gh api "repos/$repo/pulls/$pr/comments" --paginate --jq ".[]|select(.user.login!=\"$owner\")|\"rc \(.id)\""
    gh api "repos/$repo/issues/$pr/comments" --paginate --jq ".[]|select(.user.login!=\"$owner\")|\"ic \(.id)\""
    gh pr view "$pr" --repo "$repo" --json state,reviewDecision --jq '"state \(.state) \(.reviewDecision)"'
  } | sort
}

base=$(snapshot) || exit 1
while sleep "$poll_seconds"; do
  # A failed poll (network, rate limit) is skipped, so it does not look like new feedback.
  now=$(snapshot) || continue
  if [[ "$now" != "$base" ]]; then
    comm -13 <(echo "$base") <(echo "$now")
    exit 0
  fi
done
