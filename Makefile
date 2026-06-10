PORT ?= 4000

dev-deps:
	docker compose up -d mongo

dev-down:
	docker compose down

dev:
	cd unpub_web && UPLOADER_EMAIL=test@local.dev dart run jaspr_cli:jaspr serve -i bin/unpub.server.dart --port $(PORT)

build-web:
	cd unpub_web && dart run jaspr_cli:jaspr build

build:
	$(MAKE) build-web

test:
	dart test unpub/test unpub_aws/test
