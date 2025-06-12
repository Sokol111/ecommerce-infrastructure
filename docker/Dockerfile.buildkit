# syntax=docker/dockerfile:1.4

# Build Stage
FROM golang:1.24.2 AS base-build

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download && go mod verify && go mod tidy

COPY . .

RUN CGO_ENABLED=1 GOOS=linux go build -v -o /server cmd/main.go

# Release Stage
FROM ubuntu:24.04 AS base-release

WORKDIR /

COPY --from=base-build /server /server
COPY --from=base-build /app/configs/ /configs/

EXPOSE 8080

ENTRYPOINT ["/server"]