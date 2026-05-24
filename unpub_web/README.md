# unpub_web

Unpub web UI built with [Jaspr](https://docs.jaspr.site/) (SSR integrated into the unpub shelf server).

## Development

From the monorepo root:

```sh
dart pub get
make dev-deps   # starts MongoDB via Docker
make build-web  # builds Jaspr client bundle (required once)
make dev        # or: PORT=4001 make dev
```

The web UI is served from the same process as the API via Jaspr SSR.
