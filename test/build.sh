#!/bin/sh
# Builds the action image against three source stages and checks the result:
#   seed:    the committed Dockerfile (alpine placeholder) builds and prints the stub line;
#   bumped:  a scratch image with /app/mock-agent builds and runs that binary;
#   missing: a scratch image without /app/mock-agent fails the build.
# The bumped and missing cases rewrite only the source FROM line, as ccf-bump does.
set -eu

repo=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
tag="mock-agent-action-test-$$"
trap 'rm -rf "$work"; docker image rm -f "$tag:seed" "$tag:bumped" "$tag:src-bin" "$tag:src-empty" >/dev/null 2>&1 || true' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

# Build the action with the source stage replaced by $1.
build_with_source() {
  sed "s#^FROM alpine:3.20 AS source\$#FROM $1 AS source#" "$repo/Dockerfile" > "$work/Dockerfile.$2"
  grep -q "^FROM $1 AS source\$" "$work/Dockerfile.$2" || fail "source FROM line not found in Dockerfile"
  docker build -q -f "$work/Dockerfile.$2" -t "$tag:$2" "$repo"
}

echo "== seed"
docker build -q -t "$tag:seed" "$repo" >/dev/null
out=$(docker run --rm -e INPUT_MESSAGE=seed-msg "$tag:seed")
echo "$out" | grep -q '^message: seed-msg$' || fail "seed: message not printed: $out"
echo "$out" | grep -q 'mock-agent binary not present' || fail "seed: stub line not printed: $out"

echo "== bumped"
mkdir -p "$work/src-bin" "$work/src-empty"
printf '#!/bin/sh\necho fake-mock-agent\n' > "$work/src-bin/mock-agent"
printf 'FROM scratch\nCOPY --chmod=0755 mock-agent /app/mock-agent\n' > "$work/src-bin/Dockerfile"
docker build -q -t "$tag:src-bin" "$work/src-bin" >/dev/null
build_with_source "$tag:src-bin" bumped >/dev/null
out=$(docker run --rm -e INPUT_MESSAGE=bumped-msg "$tag:bumped")
echo "$out" | grep -q '^message: bumped-msg$' || fail "bumped: message not printed: $out"
echo "$out" | grep -q '^fake-mock-agent$' || fail "bumped: binary not run: $out"

echo "== missing"
printf 'placeholder\n' > "$work/src-empty/README"
printf 'FROM scratch\nCOPY README /README\n' > "$work/src-empty/Dockerfile"
docker build -q -t "$tag:src-empty" "$work/src-empty" >/dev/null
if build_with_source "$tag:src-empty" missing >/dev/null 2>&1; then
  fail "missing: build succeeded without /app/mock-agent"
fi

echo "PASS"
