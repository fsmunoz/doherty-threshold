// Server component
// This manages the server interface, allowing the algorithm code to stay simple.

package server

import (
    "fmt"
    "log"
    "net/http"
    "os"
    "strconv"
    "strings"
    "time"
    
    "github.com/fsmunoz/doherty-threshold/pkg/metrics"
    "github.com/fsmunoz/doherty-threshold/pkg/testdata"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

// Config holds server configuration
type Config struct {
    Port        string
    Sizes       []int
    AlgorithmName string
}

// DefaultConfig returns sensible defaults
func DefaultConfig() Config {
    return Config{
        Port:  ":8080",
        Sizes: []int{100, 1000, 10000, 50000, 100000},
    }
}

// Load configuration from environment variables
func LoadConfigFromEnv() Config {
    cfg := DefaultConfig()
    
    if port := os.Getenv("PORT"); port != "" {
        cfg.Port = ":" + port
    }
    
    if sizesEnv := os.Getenv("ARRAY_SIZES"); sizesEnv != "" {
        if sizes := parseSizes(sizesEnv); len(sizes) > 0 {
            cfg.Sizes = sizes
        }
    }
    
    return cfg
}

// Starts the benchmark server with the given sorting algorithm
func Run(algorithmName string, sortFunc func([]int) []int) {
    cfg := LoadConfigFromEnv()
    cfg.AlgorithmName = algorithmName
    
    // Start metrics endpoint
    http.Handle("/metrics", promhttp.Handler())
    http.HandleFunc("/health", healthHandler)
    
    go func() {
        log.Printf("Starting %s sort metrics server on %s", algorithmName, cfg.Port)
        if err := http.ListenAndServe(cfg.Port, nil); err != nil {
            log.Fatalf("Failed to start metrics server: %v", err)
        }
    }()
    
    // Run all benchmarks
    runBenchmarks(cfg, sortFunc)
    
    // Keep running for Prometheus 
    log.Println("All benchmarks complete. Keeping metrics endpoint alive...")
    select {}
}

func runBenchmarks(cfg Config, sortFunc func([]int) []int) {
    log.Printf("Starting %s sort benchmarks...", cfg.AlgorithmName)
    
    for _, size := range cfg.Sizes {
        arr := testdata.GenerateRandomArray(size)
        log.Printf("[%s] Sorting %d elements...", cfg.AlgorithmName, size)
        
        metrics.MeasureSort(cfg.AlgorithmName, arr, sortFunc)
        
        log.Printf("[%s] Completed sorting %d elements", cfg.AlgorithmName, size)
        time.Sleep(1 * time.Second) // Breathing room between benchmarks
    }
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
    w.WriteHeader(http.StatusOK)
    fmt.Fprintln(w, "OK")
}

func parseSizes(sizesEnv string) []int {
    parts := strings.Split(sizesEnv, ",")
    sizes := make([]int, 0, len(parts))
    
    for _, part := range parts {
        size, err := strconv.Atoi(strings.TrimSpace(part))
        if err != nil {
            log.Printf("Warning: invalid size '%s', skipping", part)
            continue
        }
        sizes = append(sizes, size)
    }
    
    return sizes
}
