# unpub_web

Unpub web UI built with [Jaspr](https://docs.jaspr.site/) (SSR integrated into the unpub shelf server).

## Development

From the monorepo root:

```sh
dart pub get
make dev-deps   # starts MongoDB via Docker
make dev        # Starts unpub + jaspr dev server (or: PORT=4001 make dev)
```

For production builds, use `make build-web` to generate the client JS bundle.

The web UI is served from the same process as the API via Jaspr SSR.
