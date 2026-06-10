PORT ?= 4000

dev-deps:
	docker compose up -d mongo

dev-down:
	docker compose down

dev:
	@test -f unpub_web/web/main.client.dart.js || $(MAKE) build-web
	UPLOADER_EMAIL=test@local.dev dart run unpub/bin/unpub.dart -p $(PORT)

build-web:
	cd unpub_web && dart run build_runner build && dart run tool/build_client_js.dart

build:
	$(MAKE) build-web

fmt:
	dart format --line-length=120 .

lint:
	dart analyze

test:
	dart test unpub/test unpub_aws/test
