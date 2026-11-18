# ---- go: needs go (mise) ----
.PHONY: go/init go/tidy go/lint go/test go/audit go/build go/updatedep
go/init:
	go mod download
go/tidy:
	go mod tidy
	go fmt ./...
go/lint:
	go vet ./...
	go run honnef.co/go/tools/cmd/staticcheck@latest ./...
go/test:
	go test -race ./...
go/audit:
	go mod tidy -diff
	go mod verify
	test -z "$$(gofmt -l .)" || { gofmt -l .; echo "run: make tidy"; exit 1; }
	go run golang.org/x/vuln/cmd/govulncheck@latest ./...
go/build:
	CGO_ENABLED=0 go build -trimpath -ldflags='-s -w' -o ./bin/ ./cmd/...
go/updatedep:
	go get -u ./...
	go mod tidy
##run: Run the app (set the main package in the recipe)
.PHONY: run
run:
	go run ./cmd/$(notdir $(CURDIR))
