.PHONY: dev lint fmt test build

init:
	go mod download
	go install github.com/air-verse/air@latest
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

dev:
	air

lint:
	golangci-lint-v2 run

test:
	go test -v ./...

build:
	go build -o bin/app cmd/main.go
