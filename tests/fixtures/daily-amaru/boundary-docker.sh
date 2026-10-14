#!/usr/bin/env bash
set -euo pipefail
[ "$#" -eq 6 ] && [ "$1" = buildx ] && [ "$2" = imagetools ] &&
  [ "$3" = inspect ] && [ "$5" = --format ] &&
  [ "$6" = '{{json .Manifest.Digest}}' ] || exit 64
printf 'boundary-docker diagnostic\n' >&2
# The registry answers "not found" for the first N inspections of a tag that is
# still being published, then serves it. Each inspection is appended to the
# counter file, which the scenario reads back as the number of attempts made.
if [ -n "${DAILY_AMARU_BOUNDARY_DOCKER_COUNTER:-}" ]; then
  printf 'inspect\n' >>"$DAILY_AMARU_BOUNDARY_DOCKER_COUNTER"
  attempts=$(grep -c inspect "$DAILY_AMARU_BOUNDARY_DOCKER_COUNTER")
  if [ "$attempts" -le "${DAILY_AMARU_BOUNDARY_DOCKER_MISSING_POLLS:-0}" ]; then
    printf 'ERROR: %s: not found\n' "$4" >&2
    exit 1
  fi
fi
printf '"sha256:%064d"\n' 0
