# Repository instructions

- Work locally unless the user explicitly authorizes a push. Do not submit contest forms automatically.
- All new commits and pushes must use the repository creator's GitHub account `Wchwch777` only. Use `Wchwch777 <300403626+Wchwch777@users.noreply.github.com>` for both author and committer; never add an AI or other account as co-author. Preserve historical commits.
- Before every commit inspect the effective `git var GIT_AUTHOR_IDENT` and `git var GIT_COMMITTER_IDENT`. Before every push verify `gh api user --jq .login` is `Wchwch777` and inspect the remote. If authentication differs, switch to the saved owner account and verify it; if unavailable or invalid, start interactive owner login and let the user complete it. Never push using another identity.
- November work starts from `1e63972`. Describe October work as historical foundation; do not count it again as November development. Keep actual verification separate from planned work and historical CI evidence.
- Keep application drafts and personal review records outside the repository. Do not invent owner sign-off, external users, adoption, contest approval, or remote CI results.
