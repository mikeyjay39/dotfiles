#!/usr/bin/env bash
# Usage: watch-pr.sh <pr-number> [owner-login] [repo]
# Exits when the PR gets a review, review comment or comment from anyone but the owner account,
# or when its state or review decision changes. The owner is skipped because the agents post as it;
# bots are skipped because CI and deploy bots comment on every push.
pr=$1
owner=${2:-$(gh api user --jq .login)}
repo=${3:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}
poll_seconds=${POLL_SECONDS:-120}

# A snapshot fails when any call fails (for example a GitHub 503 or 504), so a partial
# snapshot never looks like a change.
snapshot() {
  set -o pipefail
  {
    gh api "repos/$repo/pulls/$pr/reviews" --paginate --jq ".[]|select(.user.login!=\"$owner\" and .user.type!=\"Bot\")|\"review \(.id) \(.state)\"" &&
    gh api "repos/$repo/pulls/$pr/comments" --paginate --jq ".[]|select(.user.login!=\"$owner\" and .user.type!=\"Bot\")|\"rc \(.id)\"" &&
    gh api "repos/$repo/issues/$pr/comments" --paginate --jq ".[]|select(.user.login!=\"$owner\" and .user.type!=\"Bot\")|\"ic \(.id)\"" &&
    gh pr view "$pr" --repo "$repo" --json state,reviewDecision --jq '"state \(.state) \(.reviewDecision)"'
  } 2>/dev/null | sort
}

until base=$(snapshot); do sleep "$poll_seconds"; done
while sleep "$poll_seconds"; do
  # A failed poll (network, rate limit) is skipped, so it does not look like new feedback.
  now=$(snapshot) || continue
  if [[ "$now" != "$base" ]]; then
    comm -13 <(echo "$base") <(echo "$now")
    exit 0
  fi
done
