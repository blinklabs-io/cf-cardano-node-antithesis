#!/usr/bin/env bash
# The Antithesis result wait must outlast a slow run.
#
# Run 38854225999 (1 h test, 2026-10-16) completed after 2h43m wall time, but
# the "Wait for results" step was bounded at duration + 1 hour, so it exited
# 124 and the daily controller recorded a failed launch. The bound is
# duration + 3 hours, and every job that holds a launched run must hold it.
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

node_workflow=.github/workflows/cardano-node.yaml
amaru_workflow=.github/workflows/daily-amaru.yaml
head_workflow=.github/workflows/daily-cardano-node-head.yaml
slack_hours=3
# 2h43m observed for a one-hour test, in seconds.
observed_slow_run=$((2 * 3600 + 43 * 60))

fail() {
  printf 'FAIL %s\n' "$*" >&2
  exit 1
}
pass() { printf 'PASS %s\n' "$1"; }

# The command line of the named step.
step_run() {
  awk -v header="    - name: $2" '
    $0 == header { inside = 1; next }
    inside && /^    - (name|uses):/ { exit }
    inside && /^      run:/ { sub(/^      run: */, ""); print; exit }
  ' "$1"
}

# timeout-minutes of the named job.
job_timeout() {
  awk -v header="  $2:" '
    $0 == header { inside = 1; next }
    inside && /^  [^ ]/ { exit }
    inside && /^    timeout-minutes:/ { print $2; exit }
  ' "$1"
}

# Evaluate the bound the step really passes to `timeout`, for a given DURATION.
step_bound_seconds() {
  local command bound
  command=$(step_run "$node_workflow" 'Wait for results')
  [ -n "$command" ] || fail 'Wait for results step not found'
  bound=$(sed -n 's/^timeout \(\$((.*))\) .*/\1/p' <<<"$command")
  [ -n "$bound" ] || fail "no arithmetic timeout bound in: $command"
  DURATION=$1 bash -c "echo $bound"
}

for duration in 1 2 3 4; do
  bound=$(step_bound_seconds "$duration")
  expected=$(((duration + slack_hours) * 3600))
  [ "$bound" -eq "$expected" ] ||
    fail "duration $duration: wait bound is ${bound}s, expected ${expected}s"
done
[ "$(step_bound_seconds 1)" -gt "$observed_slow_run" ] ||
  fail 'the one-hour wait bound does not outlast the observed 2h43m run'
pass wait-bound-is-duration-plus-3-hours

# The Daily Amaru controller launches a one-hour run and watches it.
amaru_duration=$(sed -n 's/^receipt\[launch_duration\]=\([0-9]*\)$/\1/p' scripts/daily-amaru.sh)
[[ "$amaru_duration" =~ ^[0-9]+$ ]] || fail 'daily-amaru launch duration not found'
amaru_job=$(job_timeout "$amaru_workflow" daily-amaru-scheduled)
[[ "$amaru_job" =~ ^[0-9]+$ ]] || fail 'daily-amaru-scheduled timeout-minutes not found'
[ "$((amaru_job * 60))" -ge "$(step_bound_seconds "$amaru_duration")" ] ||
  fail "daily-amaru-scheduled holds ${amaru_job} min, less than its launched run's wait"
pass daily-amaru-job-holds-the-launched-wait

# The HEAD controller launches a three-hour run (one hour in validation).
head_duration=$(sed -n '/^    daily)/,/;;/s/^ *duration=\([0-9]*\)$/\1/p' scripts/daily-cardano-node-head.sh)
[[ "$head_duration" =~ ^[0-9]+$ ]] || fail 'head daily duration not found'
for job in daily-head-run validation-head-run; do
  minutes=$(job_timeout "$head_workflow" "$job")
  [[ "$minutes" =~ ^[0-9]+$ ]] || fail "$job timeout-minutes not found"
  [ "$((minutes * 60))" -ge "$(step_bound_seconds 1)" ] ||
    fail "$job holds ${minutes} min, less than a one-hour run's wait"
done
daily_minutes=$(job_timeout "$head_workflow" daily-head-run)
[ "$((daily_minutes * 60))" -ge "$(step_bound_seconds "$head_duration")" ] ||
  fail "daily-head-run holds ${daily_minutes} min, less than its launched run's wait"
pass head-jobs-hold-the-launched-wait
