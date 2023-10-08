VERBOSE=1
APPNAME=myapp

include main.mk

.PHONY: generate-docs run-release run-debug up-debug generate run-test up down reset start stop format format2 vet coverage lint-golint lint-golangci tidy docker-build-debug docker-build-release

## Generators

generate-mocks: ## generate mock methods
	go generate ./...


## generates swagger documentation
swagger-generate:
	@ if [ -z $(command -v swag) ];then go install github.com/swaggo/swag/cmd/swag@v1.7.6; fi
	swag init -g internal/web/web.go
	@ rm ./docs/docs.go
	@ rm ./docs/swagger.json

## serve swagger documentation
swagger-ui:
	printf '\e[0;32m%-6s\e[m\n' "swagger ui will run on port 80"
	@ docker run -p 80:8080 -e SWAGGER_JSON=/tmp/swagger.yaml -v `pwd`/docs/:/tmp swaggerapi/swagger-ui

## Local docker build

docker-build-debug: ## build test debug docker image
	docker build -t ${APPNAME}:test-debug --build-arg BUILD_TARGET=debug --build-arg BUILD_ENVIRONMENT=development --build-arg VERSION=${CI_COMMIT_SHORT_SHA} .

docker-build-integration: ## build test debug docker image
	docker build -t ${APPNAME}:test-integration --build-arg BUILD_TARGET=debug --build-arg BUILD_ENVIRONMENT=integration --build-arg VERSION=${CI_COMMIT_SHORT_SHA} .

docker-build-release: ## build test release docker image
	docker build -t ${APPNAME}:test-release --build-arg BUILD_TARGET=release --build-arg BUILD_ENVIRONMENT=production --build-arg VERSION=${CI_COMMIT_SHORT_SHA} .

## Local run

up-integration: up delve build-integration run-integration ## Raise environment and start the integration service locally

up-debug: up delve build-debug run-debug ## Raise environment and start the debug service locally

run-debug: export ENVIRONMENT = development
run-debug: ## Run locally the debug version
	cp ./${ENVIRONMENT}.yml ./build/debug/.
	cp -f ./build/debug/${APPNAME} ./build/.
	./build/${APPNAME}

run-integration: export ENVIRONMENT = integration
run-integration: ## Run locally the integration version
	cp ./${ENVIRONMENT}.yml ./build/integration/.
	cp -f ./build/integration/${APPNAME} ./build/.
	./build/${APPNAME}

run-release: export ENVIRONMENT = production
run-release: ## Run locally the release version
	cp ./${ENVIRONMENT}.yml ./build/release/.
	cp -f ./build/release/${APPNAME} ./build/.
	./build/${APPNAME}

delve: ## Prepare delve debug module for local debug run
	@cd /tmp; GOBIN=/app/build/debug; go get github.com/go-delve/delve/cmd/dlv; cd -

## Local environment

up: start ## Set up the development environment

down: clear ## Destroy the development environment
	docker-compose down --volumes --remove-orphans --rmi local
	rm -rf var/docker/volumes/*

reset: down up ## Reset the development environment

docker-compose.override.yml:
	cp docker-compose.override.yml.dist docker-compose.override.yml

start: docker-compose.override.yml ## Start docker development environment
	@ if [ docker-compose.override.yml -ot docker-compose.override.yml.dist ]; then diff -u docker-compose.override.yml docker-compose.override.yml.dist || (echo "!!! The distributed docker-compose.override.yml example changed. Please update your file accordingly (or at least touch it). !!!" && false); fi
	docker-compose up -d

stop: ## Stop docker development environment
	docker-compose stop

################# Tooling ########################

### Tests

run-test: ## Run all tests
	go test -count=1 -v ./...

### Test coverage

coverage:
	go test -cover ./...

### Formatting Code

format: ## Format all files in directory
	gofmt -w -s -d .

format2: ## Format, calles calls gofmt -l -w
	go fmt ./...

### Static Analysis

vet: ## Vet
	go vet ./...

## Linting

lint-golint: ## Lint with go lint
	golint ./...

lint-golangci: ## lint with golangci-lint
	golangci-lint -v run

tidy: ## Tidy
	go mod tidy

## Benchmarks

bench: ## Bench
	go test -bench=. -benchmem ./...
