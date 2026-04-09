# syntax=docker/dockerfile:1.4

# Dependencies Stage
FROM golang:1.26.2 AS base-deps

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download && go mod verify

COPY . .

# Production Build Stage
FROM base-deps AS base-build

RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -v -o /server cmd/main.go

# Production Release Stage
FROM gcr.io/distroless/static-debian12 AS base-release

WORKDIR /

COPY --from=base-build /server /server
COPY --from=base-build /app/db/ /db/

EXPOSE 8080

USER nonroot:nonroot
ENTRYPOINT ["/server"]

# Debug Build Stage
FROM base-deps AS debug-build

RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -gcflags="all=-N -l" -v -o /server cmd/main.go
RUN go install github.com/go-delve/delve/cmd/dlv@v1.26.2

# Debug Release Stage
FROM gcr.io/distroless/base-debian12 AS debug-release

WORKDIR /

COPY --from=debug-build /go/bin/dlv /dlv
COPY --from=debug-build /server /server
COPY --from=debug-build /app/configs/ /configs/
COPY --from=debug-build /app/db/ /db/

EXPOSE 8080 2345

ENTRYPOINT ["/dlv", "exec", "/server", "--headless", "--listen=:2345", "--api-version=2", "--accept-multiclient"]