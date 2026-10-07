#!/bin/sh
set -eu

# GitHub passes the `message` input as INPUT_MESSAGE.
echo "message: ${INPUT_MESSAGE:-}"

if [ -x /usr/local/bin/mock-agent ]; then
  exec /usr/local/bin/mock-agent
fi

echo "mock-agent binary not present (source stage is the alpine placeholder)"
