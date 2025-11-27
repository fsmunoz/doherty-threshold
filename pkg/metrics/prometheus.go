// Prometheus support

package metrics

import (
    "fmt"
    "time"
    
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promauto"
)

var (
    SortDuration = promauto.NewHistogramVec(
        prometheus.HistogramOpts{
            Name: "sort_duration_seconds",
            Help: "Time taken to sort arrays of various sizes",
            Buckets: prometheus.ExponentialBuckets(0.0001, 2, 20),
        },
        []string{"algorithm", "size"},
    )
    
    SortCompleted = promauto.NewCounterVec(
        prometheus.CounterOpts{
            Name: "sort_completed_total",
            Help: "Number of sort operations completed",
        },
        []string{"algorithm", "size"},
    )
)

// MeasureSort wraps a sorting function with specific timing metrics
//
func MeasureSort(algorithmName string, arr []int, sortFunc func([]int) []int) []int {
    size := fmt.Sprintf("%d", len(arr))
    
    start := time.Now()
    result := sortFunc(arr)
    duration := time.Since(start).Seconds()
    
    SortDuration.WithLabelValues(algorithmName, size).Observe(duration)
    SortCompleted.WithLabelValues(algorithmName, size).Inc()
    
    return result
}
