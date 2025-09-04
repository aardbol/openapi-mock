# syntax=docker/dockerfile:1.10

FROM --platform=$BUILDPLATFORM golang:1.25-alpine AS build

ARG APP_VERSION=""
ARG BUILD_TIME=""
ARG TARGETOS
ARG TARGETARCH

RUN adduser -D -u 65532 -g '' openapi

WORKDIR /src

# Copy dependency files first for better caching
COPY --link go.mod go.sum ./

# Download dependencies with cache mount
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go mod download

COPY --link . .

# Build with optimizations and cache mounts
WORKDIR /src/cmd/openapi-mock
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -trimpath -ldflags="-w -s -X 'main.version=${APP_VERSION}' -X 'main.buildTime=${BUILD_TIME}'" \
    -o /out/openapi-mock

FROM gcr.io/distroless/static-debian12:nonroot AS runtime

LABEL org.opencontainers.image.title="OpenAPI Mock" \
      org.opencontainers.image.description="Mock server for OpenAPI specifications" \
      org.opencontainers.image.maintainer="Igor Lazarev <strider2038@yandex.ru>" \
      org.opencontainers.image.url="https://github.com/muonsoft/openapi-mock" \
      org.opencontainers.image.source="https://github.com/muonsoft/openapi-mock" \
      org.opencontainers.image.vendor="muonsoft" \
      org.opencontainers.image.licenses="MIT"

WORKDIR /app

COPY --from=build --chown=65532:65532 --chmod=755 /out/openapi-mock /app/openapi-mock

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD /app/openapi-mock healthcheck || exit 1

ENTRYPOINT ["/app/openapi-mock"]
CMD [
 "serve",
 "--specification-url",
 "https://raw.githubusercontent.com/OAI/OpenAPI-Specification/master/examples/v3.0/petstore.yaml"
]
