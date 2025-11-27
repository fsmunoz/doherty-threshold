# Build stage
FROM golang:1.24-bookworm AS builder

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source
COPY . .

# Build static binary with stripped debug info
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /sort-ui ./cmd/ui

# Runtime stage, Google Distroless 
FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=builder /sort-ui /sort-ui

EXPOSE 8080

ENTRYPOINT ["/sort-ui"]
