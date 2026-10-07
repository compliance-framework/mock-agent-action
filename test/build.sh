#!/bin/sh
# Builds the action image and checks the result for each source stage:
#   committed:   the Dockerfile as committed builds and prints the message input;
#   placeholder: alpine:3.20 (the seed source) builds and prints the stub line;
#   bumped:      a scratch image with /app/mock-agent builds and runs that binary;
#   missing:     a scratch image without /app/mock-agent fails the build.
# The last three rewrite only the source FROM line, as ccf-bump does, so the
# script keeps working after ccf-bump has changed that line.
set -eu

repo=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
tag="mock-agent-action-test-$$"
trap 'rm -rf "$work"; docker image rm -f "$tag:committed" "$tag:placeholder" "$tag:bumped" "$tag:src-bin" "$tag:src-empty" >/dev/null 2>&1 || true' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

# Build the action with the source stage replaced by $1.
build_with_source() {
  sed "s#^FROM [^ ]* AS source\$#FROM $1 AS source#" "$repo/Dockerfile" > "$work/Dockerfile.$2"
  grep -q "^FROM $1 AS source\$" "$work/Dockerfile.$2" || fail "source FROM line not found in Dockerfile"
  docker build -q -f "$work/Dockerfile.$2" -t "$tag:$2" "$repo"
}

echo "== committed"
docker build -q -t "$tag:committed" "$repo" >/dev/null
out=$(docker run --rm -e INPUT_MESSAGE=committed-msg "$tag:committed")
echo "$out" | grep -q '^message: committed-msg$' || fail "committed: message not printed: $out"

echo "== placeholder"
build_with_source alpine:3.20 placeholder >/dev/null
out=$(docker run --rm -e INPUT_MESSAGE=placeholder-msg "$tag:placeholder")
echo "$out" | grep -q '^message: placeholder-msg$' || fail "placeholder: message not printed: $out"
echo "$out" | grep -q 'mock-agent binary not present' || fail "placeholder: stub line not printed: $out"

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
