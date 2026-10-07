# mock-agent-action

Mock repo for developing CCF release automation. Not a product.

A Docker action that mirrors [agent-action](https://github.com/compliance-framework/agent-action)
in miniature. The `Dockerfile` copies the binary from the mock-agent image (`FROM ... AS source`)
into a small alpine stage that runs it. Until mock-agent publishes an image, the source stage is
`alpine:3.20` and the action only prints its `message` input; `ccf-bump` later rewrites that `FROM`
line to `ghcr.io/compliance-framework/mock-agent:<version>`. The mock-agent image must provide the
binary at `/app/mock-agent`, or the build fails.

```yaml
- uses: compliance-framework/mock-agent-action@v0
  with:
    message: hello
```

`version.txt` holds the current version.
