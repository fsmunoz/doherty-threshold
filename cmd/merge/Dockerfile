# Build stage
FROM golang:1.24-bookworm AS builder

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source
COPY . .

# Build static binary with stripped debug info
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /sort-merge ./cmd/merge

# Runtime stage, changed to Google Distroless for minimal attack surface etc
# Could use Alpine and the go-specific images
FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=builder /sort-merge /sort-merge

EXPOSE 8080

ENTRYPOINT ["/sort-merge"]
