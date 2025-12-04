# Makefile
#
# Frederico Muñoz <fsmunoz@gmail.com>
#
# I've tried to add most things here, if nothing else because I like
# the way Makefiles work, and how they force me to think about actions
# and dependencies.
#
# Most things use a [OK]/[FAIL]/[INFO]/[...] prefix, plus some mild
# ASCII separators.

.PHONY: all build test bench notebook run stop status run-screen attach-screen stop-screen screen-status docker-up docker-down logs logs-ui clean deps fmt lint vet k8s-build k8s-build-kind k8s-build-k3s k8s-deploy k8s-delete k8s-status k8s-logs k8s-logs-ui k8s-port-forward help

# Variables
#=============================================================================

BINARY_DIR := bin
SERVICES := bubble merge ui
GO := go
DOCKER_COMPOSE := docker-compose

# Ports for local development
BUBBLE_PORT := 8080
MERGE_PORT := 8081
UI_PORT := 8082

# Screen session name
SCREEN_SESSION := big-o-demo

# Kubernetes platform (kind or k3s)
K8S_PLATFORM ?= kind

# Registry configuration
K3S_REGISTRY ?= localhost:5000

# Image names
BUBBLE_IMAGE := bubble-sort:latest
MERGE_IMAGE := merge-sort:latest
UI_IMAGE := ui:latest

# Go build flags
LDFLAGS := -w -s
BUILD_FLAGS := -ldflags "$(LDFLAGS)"


# Default target
#=============================================================================
all: deps build test

# Development
#=============================================================================

# Install/update dependencies
deps:
	@echo "[DEP] Installing dependencies..."
	@$(GO) mod download
	@$(GO) mod tidy
	@$(GO) mod verify
	@echo "[OK] Dependencies installed!"

# Build all services
build:
	@echo "[BUILD] Building services..."
	@mkdir -p $(BINARY_DIR)
	@for service in $(SERVICES); do \
		echo "  Building $$service..."; \
		$(GO) build $(BUILD_FLAGS) -o $(BINARY_DIR)/$$service ./cmd/$$service || exit 1; \
	done
	@echo "[OK] Build complete! Binaries in $(BINARY_DIR)/"

# Testing
#=============================================================================

# Run all tests
test:
	@echo "[TEST] Running tests..."
	@$(GO) test -v -race -coverprofile=coverage.out ./...
	@echo "[OK] Tests passed!"

# Run tests with coverage report
test-coverage: test
	@echo "[INFO] Generating coverage report..."
	@$(GO) tool cover -html=coverage.out -o coverage.html
	@echo "[OK] Coverage report: coverage.html"
	@echo "   Open with: open coverage.html (macOS) or xdg-open coverage.html (Linux)"

# Run benchmarks
bench:
	@echo "[BENCH] Running benchmarks..."
	@$(GO) test -bench=. -benchmem -run=^$$ ./pkg/algorithms
	@echo "[OK] Benchmarks complete!"

# Open Jupyter notebook
notebook:
	@echo "[NOTEBOOK] Opening Jupyter notebook..."
	@if command -v jupyter >/dev/null 2>&1; then \
		jupyter lab docs/notebooks/BigO.ipynb; \
	elif command -v jupyter-lab >/dev/null 2>&1; then \
		jupyter-lab docs/notebooks/BigO.ipynb; \
	else \
		echo "[!!] Jupyter not found. Install with: pip install jupyterlab"; \
		echo ""; \
		echo "[INFO] Alternatively, open in Google Colab:"; \
		echo "   1. Go to https://colab.research.google.com"; \
		echo "   2. File -> Upload notebook"; \
		echo "   3. Select docs/notebooks/BigO.ipynb"; \
		exit 1; \
	fi


# Running Locally (PID-based background processes)
#=============================================================================

# Run services locally in background
run: build
	@echo ">>> Starting services locally..."
	@echo "  Starting bubble-sort on :$(BUBBLE_PORT)..."
	@$(BINARY_DIR)/bubble & echo $$! > $(BINARY_DIR)/bubble.pid
	@echo "  Starting merge-sort on :$(MERGE_PORT)..."
	@PORT=$(MERGE_PORT) $(BINARY_DIR)/merge & echo $$! > $(BINARY_DIR)/merge.pid
	@sleep 2
	@echo "[OK] Services running!"
	@echo ""
	@echo "[INFO] Metrics endpoints:"
	@echo "   Bubble: http://localhost:$(BUBBLE_PORT)/metrics"
	@echo "   Merge:  http://localhost:$(MERGE_PORT)/metrics"
	@echo ""
	@echo "[STOP] To stop: make stop"

# Stop locally running services
stop:
	@echo "[STOP] Stopping services..."
	@if [ -f $(BINARY_DIR)/bubble.pid ]; then \
		kill `cat $(BINARY_DIR)/bubble.pid` 2>/dev/null || true; \
		rm $(BINARY_DIR)/bubble.pid; \
		echo "  Stopped bubble-sort"; \
	fi
	@if [ -f $(BINARY_DIR)/merge.pid ]; then \
		kill `cat $(BINARY_DIR)/merge.pid` 2>/dev/null || true; \
		rm $(BINARY_DIR)/merge.pid; \
		echo "  Stopped merge-sort"; \
	fi
	@echo "[OK] Services stopped!"

# Check if services are running
status:
	@echo "[INFO] Service status:"
	@if [ -f $(BINARY_DIR)/bubble.pid ]; then \
		if ps -p `cat $(BINARY_DIR)/bubble.pid` > /dev/null; then \
			echo "  [OK] bubble-sort: RUNNING (PID: `cat $(BINARY_DIR)/bubble.pid`)"; \
		else \
			echo "  [!!] bubble-sort: STOPPED (stale PID file)"; \
		fi \
	else \
		echo "  [!!] bubble-sort: STOPPED"; \
	fi
	@if [ -f $(BINARY_DIR)/merge.pid ]; then \
		if ps -p `cat $(BINARY_DIR)/merge.pid` > /dev/null; then \
			echo "  [OK] merge-sort: RUNNING (PID: `cat $(BINARY_DIR)/merge.pid`)"; \
		else \
			echo "  [!!] merge-sort: STOPPED (stale PID file)"; \
		fi \
	else \
		echo "  [!!] merge-sort: STOPPED"; \
	fi


# Running Locally (GNU Screen-based with visible logs)
#=============================================================================

# Run services in GNU screen session
#
#It uses GNU screen, and not tmux: GNU screen comes with Ctrl-a
# prefix, and tmux Ctrl-b: a comes before b, hence screen is better,
# QED.

run-screen: build
	@echo "[SCREEN] Starting services in screen session..."
	@if screen -list | grep -q $(SCREEN_SESSION); then \
		echo "[WARN] Screen session '$(SCREEN_SESSION)' already exists!"; \
		echo "  Attach: make attach-screen"; \
		echo "  Stop: make stop-screen"; \
		exit 1; \
	fi
	@screen -dmS $(SCREEN_SESSION) -t bubble sh -c '$(BINARY_DIR)/bubble; echo "Press Enter to close"; read'
	@screen -S $(SCREEN_SESSION) -X screen -t merge sh -c 'PORT=$(MERGE_PORT) $(BINARY_DIR)/merge; echo "Press Enter to close"; read'
	@screen -S $(SCREEN_SESSION) -X screen -t ui sh -c 'PORT=$(UI_PORT) $(BINARY_DIR)/ui; echo "Press Enter to close"; read'
	@sleep 1
	@echo "[OK] Screen session started!"
	@echo ""
	@echo "[INFO] Services running in screen:"
	@echo "   Window 0 (bubble): bubble-sort on port $(BUBBLE_PORT)"
	@echo "   Window 1 (merge):  merge-sort on port $(MERGE_PORT)"
	@echo "   Window 2 (ui):     ui on port $(UI_PORT)"
	@echo ""
	@echo "[INFO] Access points:"
	@echo "   UI:           http://localhost:$(UI_PORT)"
	@echo "   Bubble Sort:  http://localhost:$(BUBBLE_PORT)/metrics"
	@echo "   Merge Sort:   http://localhost:$(MERGE_PORT)/metrics"
	@echo ""
	@echo "[INFO] Commands:"
	@echo "   Attach:       make attach-screen"
	@echo "   Status:       make screen-status"
	@echo "   Stop:         make stop-screen"
	@echo ""
	@echo "   Inside screen:"
	@echo "   - Switch windows: Ctrl+a 0 | Ctrl+a 1 | Ctrl+a 2"
	@echo "   - Detach: Ctrl+a d"
	@echo "   - Help: Ctrl+a ?"

# Attach to running screen session
attach-screen:
	@if screen -list | grep -q $(SCREEN_SESSION); then \
		screen -r $(SCREEN_SESSION); \
	else \
		echo "[!!] No screen session found. Start with: make run-screen"; \
		exit 1; \
	fi

# Stop screen session
stop-screen:
	@echo "[STOP] Stopping screen session..."
	@screen -S $(SCREEN_SESSION) -X quit 2>/dev/null || echo "[WARN] No screen session to stop"
	@echo "[OK] Screen session stopped!"

# Show screen session status
screen-status:
	@echo "[INFO] Screen sessions:"
	@screen -list | grep $(SCREEN_SESSION) || echo "  No session running"


# Docker Operations
#=============================================================================

# Start everything with Docker Compose
docker-up:
	@echo "[DOCKER] Starting Docker Compose..."
	@$(DOCKER_COMPOSE) up --build -d
	@echo ""
	@echo "[OK] Services started!"
	@echo ""
	@echo "[INFO] Access points:"
	@echo "   UI:           http://localhost:13001 (Interactive demo)"
	@echo "   Grafana:      http://localhost:13000 (admin/admin)"
	@echo "   Bubble Sort:  http://localhost:18080/metrics"
	@echo "   Merge Sort:   http://localhost:18081/metrics"
	@echo "   Prometheus:   http://localhost:19090"
	@echo ""
	@echo "[INFO] Useful commands:"
	@echo "   View logs:    make logs"
	@echo "   Stop all:     make docker-down"
	@echo "   Restart:      make docker-restart"

# Stop Docker Compose
docker-down:
	@echo "[DOCKER] Stopping Docker Compose..."
	@$(DOCKER_COMPOSE) down -v
	@echo "[OK] Services stopped!"

# Restart Docker Compose
docker-restart: docker-down docker-up

# View Docker logs (follow)
logs:
	@echo "[INFO] Showing logs (Ctrl+C to exit)..."
	@$(DOCKER_COMPOSE) logs -f

# View logs for specific service
logs-bubble:
	@$(DOCKER_COMPOSE) logs -f bubble-sort

logs-merge:
	@$(DOCKER_COMPOSE) logs -f merge-sort

logs-prometheus:
	@$(DOCKER_COMPOSE) logs -f prometheus

logs-grafana:
	@$(DOCKER_COMPOSE) logs -f grafana

logs-ui:
	@$(DOCKER_COMPOSE) logs -f ui

# Check Docker Compose status
docker-status:
	@$(DOCKER_COMPOSE) ps


# Code Quality
#=============================================================================
#
# Go as a lot of these, so I went overboard, perhaps :/

# Format code
fmt:
	@echo "[FMT] Formatting code..."
	@$(GO) fmt ./...
	@echo "[OK] Code formatted!"

# Run linter (requires golangci-lint)
lint:
	@echo "[CHK] Running linter..."
	@if command -v golangci-lint >/dev/null 2>&1; then \
		golangci-lint run ./...; \
		echo "[OK] Linting complete!"; \
	else \
		echo "[WARN] golangci-lint not installed. Install with:"; \
		echo "   go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest"; \
	fi

# Run go vet
vet:
	@echo "[CHK] Running go vet..."
	@$(GO) vet ./...
	@echo "[OK] Vet complete!"

# Cleanup
#=============================================================================

# Clean build artifacts
clean:
	@echo "[CLEAN] Cleaning..."
	@rm -rf $(BINARY_DIR)
	@rm -f coverage.out coverage.html bench.txt
	@$(DOCKER_COMPOSE) down -v 2>/dev/null || true
	@echo "[OK] Clean complete!"

# Deep clean (including Go cache and Docker images)
clean-all: clean
	@echo "[CLEAN] Deep cleaning..."
	@$(GO) clean -cache -testcache -modcache
	@docker system prune -af --volumes 2>/dev/null || true
	@echo "[OK] Deep clean complete!"


# Kubernetes Operations
#=============================================================================

# Build Docker images for kind (local load)
k8s-build-kind:
	@echo "[K8S-KIND] Building Docker images..."
	@echo "  Building $(BUBBLE_IMAGE)..."
	@docker build -t $(BUBBLE_IMAGE) -f cmd/bubble/Dockerfile . || exit 1
	@echo "  Building $(MERGE_IMAGE)..."
	@docker build -t $(MERGE_IMAGE) -f cmd/merge/Dockerfile . || exit 1
	@echo "  Building $(UI_IMAGE)..."
	@docker build -t $(UI_IMAGE) -f cmd/ui/Dockerfile . || exit 1
	@echo "[OK] Images built!"
	@echo ""
	@echo "[K8S-KIND] Loading images into kind..."
	@kind load docker-image $(BUBBLE_IMAGE) || { echo "[FAIL] Failed to load image. Is kind running?"; exit 1; }
	@kind load docker-image $(MERGE_IMAGE) || { echo "[FAIL] Failed to load image. Is kind running?"; exit 1; }
	@kind load docker-image $(UI_IMAGE) || { echo "[FAIL] Failed to load image. Is kind running?"; exit 1; }
	@echo "[OK] Images loaded into kind!"

# Build Docker images for k3s (push to registry)
k8s-build-k3s:
	@echo "[K8S-K3S] Building and pushing Docker images..."
	@echo "  Building $(K3S_REGISTRY)/$(BUBBLE_IMAGE)..."
	@docker build -t $(K3S_REGISTRY)/$(BUBBLE_IMAGE) -f cmd/bubble/Dockerfile . || exit 1
	@echo "  Building $(K3S_REGISTRY)/$(MERGE_IMAGE)..."
	@docker build -t $(K3S_REGISTRY)/$(MERGE_IMAGE) -f cmd/merge/Dockerfile . || exit 1
	@echo "  Building $(K3S_REGISTRY)/$(UI_IMAGE)..."
	@docker build -t $(K3S_REGISTRY)/$(UI_IMAGE) -f cmd/ui/Dockerfile . || exit 1
	@echo "[OK] Images built!"
	@echo ""
	@echo "[K8S-K3S] Pushing images to $(K3S_REGISTRY)..."
	@docker push $(K3S_REGISTRY)/$(BUBBLE_IMAGE) || { echo "[FAIL] Failed to push. Is registry running?"; exit 1; }
	@docker push $(K3S_REGISTRY)/$(MERGE_IMAGE) || { echo "[FAIL] Failed to push. Is registry running?"; exit 1; }
	@docker push $(K3S_REGISTRY)/$(UI_IMAGE) || { echo "[FAIL] Failed to push. Is registry running?"; exit 1; }
	@echo "[OK] Images pushed!"

# Platform-agnostic build wrapper
k8s-build:
	@$(MAKE) k8s-build-$(K8S_PLATFORM)

# Deploy to Kubernetes (platform-aware)
k8s-deploy: k8s-build
	@echo "[K8S] Deploying to Kubernetes ($(K8S_PLATFORM))..."
	@kubectl apply -k deployments/kubernetes/overlays/$(K8S_PLATFORM)
	@echo ""
	@echo "[OK] Deployment submitted!"
	@echo ""
	@echo "[WAIT] Waiting for pods to be ready..."
	@kubectl wait --for=condition=ready pod -l component=sorting-service -n big-o-demo --timeout=60s || true
	@kubectl wait --for=condition=ready pod -l app=prometheus -n big-o-demo --timeout=60s || true
	@kubectl wait --for=condition=ready pod -l app=grafana -n big-o-demo --timeout=60s || true
	@kubectl wait --for=condition=ready pod -l app=ui -n big-o-demo --timeout=60s || true
	@echo ""
	@if [ "$(K8S_PLATFORM)" = "kind" ]; then \
		echo "[INFO] Access points (kind - NodePort):"; \
		echo "   UI:      http://localhost:30301"; \
		echo "   Grafana: http://localhost:30300 (admin/admin)"; \
	elif [ "$(K8S_PLATFORM)" = "k3s" ]; then \
		echo "[INFO] Access points (k3s - Ingress):"; \
		echo "   UI:         http://ui.localhost"; \
		echo "   Grafana:    http://grafana.localhost (admin/admin)"; \
		echo "   Prometheus: http://prom.localhost"; \
	fi
	@echo ""
	@echo "[INFO] Useful commands:"
	@echo "   Check status:     make k8s-status"
	@echo "   View logs:        make k8s-logs"
	@echo "   Port-forward:     make k8s-port-forward"
	@echo "   Delete all:       make k8s-delete"

# Delete Kubernetes resources (platform-aware)
k8s-delete:
	@echo "[K8S] Deleting Kubernetes resources ($(K8S_PLATFORM))..."
	@kubectl delete -k deployments/kubernetes/overlays/$(K8S_PLATFORM) --ignore-not-found=true
	@echo "[OK] Resources deleted!"

# Check Kubernetes deployment status
k8s-status:
	@echo "[K8S] Kubernetes Status:"
	@echo ""
	@echo "--- Pods ---"
	@kubectl get pods -n big-o-demo -o wide || echo "No pods found"
	@echo ""
	@echo "--- Services ---"
	@kubectl get services -n big-o-demo || echo "No services found"
	@echo ""
	@echo "--- Deployments ---"
	@kubectl get deployments -n big-o-demo || echo "No deployments found"

# View logs for all services
k8s-logs:
	@echo "[K8S] Kubernetes Logs:"
	@echo ""
	@echo "--- Bubble Sort ---"
	@kubectl logs -l app=bubble-sort -n big-o-demo --tail=20 || echo "No bubble-sort pods"
	@echo ""
	@echo "--- Merge Sort ---"
	@kubectl logs -l app=merge-sort -n big-o-demo --tail=20 || echo "No merge-sort pods"
	@echo ""
	@echo "--- UI ---"
	@kubectl logs -l app=ui -n big-o-demo --tail=20 || echo "No ui pods"
	@echo ""
	@echo "--- Prometheus ---"
	@kubectl logs -l app=prometheus -n big-o-demo --tail=20 || echo "No prometheus pods"
	@echo ""
	@echo "--- Grafana ---"
	@kubectl logs -l app=grafana -n big-o-demo --tail=20 || echo "No grafana pods"

# View logs for specific service
k8s-logs-bubble:
	@kubectl logs -l app=bubble-sort -n big-o-demo --tail=50 -f

k8s-logs-merge:
	@kubectl logs -l app=merge-sort -n big-o-demo --tail=50 -f

k8s-logs-prometheus:
	@kubectl logs -l app=prometheus -n big-o-demo --tail=50 -f

k8s-logs-grafana:
	@kubectl logs -l app=grafana -n big-o-demo --tail=50 -f

k8s-logs-ui:
	@kubectl logs -l app=ui -n big-o-demo --tail=50 -f

# Port-forward to Grafana (useful for kind where NodePort isn't easily accessible)
# This is the case with KIND, for example
k8s-port-forward:
	@echo "[K8S] Starting port-forward to Grafana..."
	@echo "   Grafana: http://localhost:3000"
	@echo "   Login: admin/admin"
	@echo ""
	@echo "[STOP] Press Ctrl+C to stop port-forwarding"
	@kubectl port-forward -n big-o-demo svc/grafana 3000:3000

# Restart Kubernetes deployment
k8s-restart: k8s-delete k8s-deploy

# Quick Actions
#=============================================================================

# Quick demo (build + run with Docker)
demo: docker-up
	@echo ""
	@echo "[DEMO] Demo running!"
	@echo "   Open UI: http://localhost:13001"
	@echo "   Open Grafana: http://localhost:13000"
	@echo "   Login: admin/admin"

# Quick local demo with screen
demo-screen: run-screen
	@echo ""
	@echo "[DEMO] Local demo running in screen!"
	@echo "   Open UI: http://localhost:$(UI_PORT)"

# Quick Kubernetes demo (platform-aware)
demo-k8s: k8s-deploy
	@echo ""
	@echo "[DEMO] Kubernetes demo running ($(K8S_PLATFORM))!"
	@if [ "$(K8S_PLATFORM)" = "kind" ]; then \
		echo "   Open UI: http://localhost:30301"; \
		echo "   Open Grafana: http://localhost:30300"; \
	elif [ "$(K8S_PLATFORM)" = "k3s" ]; then \
		echo "   Open UI: http://ui.localhost"; \
		echo "   Open Grafana: http://grafana.localhost"; \
		echo "   Open Prometheus: http://prom.localhost"; \
	fi
	@echo "   Login: admin/admin"


# Help
#=============================================================================

# Show help
# Needs to be updated everytime there is an additional action (or removal)

help:
	@echo "============================================================================="
	@echo "Big-O in Practice - Makefile Commands"
	@echo "============================================================================="
	@echo ""
	@echo "--- Dependencies ---"
	@echo "   make deps              Install dependencies"
	@echo ""
	@echo "--- Building ---"
	@echo "   make build             Build all services"
	@echo ""
	@echo "--- Testing ---"
	@echo "   make test              Run all tests"
	@echo "   make test-coverage     Run tests with coverage report"
	@echo "   make bench             Run benchmarks"
	@echo ""
	@echo "--- Running (Local - Background) ---"
	@echo "   make run               Run services locally (PID files)"
	@echo "   make stop              Stop local services"
	@echo "   make status            Check service status"
	@echo ""
	@echo "--- Running (Local - Screen) ---"
	@echo "   make run-screen        Run in GNU screen (visible logs)"
	@echo "   make attach-screen     Attach to screen session"
	@echo "   make stop-screen       Stop screen session"
	@echo "   make screen-status     Show screen status"
	@echo "   make demo-screen       Quick screen demo"
	@echo ""
	@echo "--- Docker ---"
	@echo "   make docker-up         Start with Docker Compose"
	@echo "   make docker-down       Stop Docker Compose"
	@echo "   make docker-restart    Restart Docker Compose"
	@echo "   make docker-status     Check Docker services"
	@echo "   make logs              View all logs"
	@echo "   make logs-bubble       View bubble-sort logs"
	@echo "   make logs-merge        View merge-sort logs"
	@echo "   make logs-ui           View UI logs"
	@echo "   make demo              Quick Docker demo"
	@echo ""
	@echo "--- Kubernetes ---"
	@echo "   make k8s-build         Build images (platform: $(K8S_PLATFORM))"
	@echo "   make k8s-build-kind    Build images for kind"
	@echo "   make k8s-build-k3s     Build + push images for k3s"
	@echo "   make k8s-deploy        Deploy to Kubernetes"
	@echo "   make k8s-delete        Delete Kubernetes resources"
	@echo "   make k8s-status        Check deployment status"
	@echo "   make k8s-logs          View all pod logs"
	@echo "   make k8s-logs-bubble   View bubble-sort logs (follow)"
	@echo "   make k8s-logs-merge    View merge-sort logs (follow)"
	@echo "   make k8s-logs-ui       View UI logs (follow)"
	@echo "   make k8s-port-forward  Port-forward to Grafana"
	@echo "   make k8s-restart       Restart deployment"
	@echo "   make demo-k8s          Quick Kubernetes demo"
	@echo ""
	@echo "   Platform selection: K8S_PLATFORM=kind (default) or k3s"
	@echo "   Example: K8S_PLATFORM=k3s make k8s-deploy"
	@echo ""
	@echo "--- Code Quality ---"
	@echo "   make fmt               Format code"
	@echo "   make vet               Run go vet"
	@echo "   make lint              Run linter"
	@echo ""
	@echo "--- Cleanup ---"
	@echo "   make clean             Clean build artifacts"
	@echo "   make clean-all         Deep clean (cache + Docker)"
	@echo ""
	@echo "--- Help ---"
	@echo "   make help              Show this help"
	@echo "   make                   Run: deps + build + test"
	@echo ""
	@echo "============================================================================="
