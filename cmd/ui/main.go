// Datastar UI for sorting comparison
//
// Frederico Munoz <fsmunoz@gmail.com>
//
// Uses the Go SDK

package main

import (
	"embed"
	"fmt"
	"html/template"
	"io/fs"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/fsmunoz/doherty-threshold/pkg/algorithms"
	"github.com/fsmunoz/doherty-threshold/pkg/testdata"
	"github.com/starfederation/datastar-go/datastar"
)

//go:embed templates/*
var templatesFS embed.FS

//go:embed static/*
var staticFS embed.FS

// Available array sizes for the UI
// Since this runs in the server, consider not going overboard...
var availableSizes = []int{100, 1000, 10000, 50000}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	mux := http.NewServeMux()

	// Serve static files
	staticContent, err := fs.Sub(staticFS, "static")
	if err != nil {
		log.Fatal(err)
	}
	mux.Handle("/static/", http.StripPrefix("/static/", http.FileServer(http.FS(staticContent))))

	// Serve the index
	mux.HandleFunc("/", indexHandler)

	// SSE endpoint for running the different sorting algos
	mux.HandleFunc("/sort", sortHandler)

	// Health check, useful for k8s etc
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	log.Printf("* Starting UI server on port %s", port)
	log.Printf("* Access at http://localhost:%s", port)

	if err := http.ListenAndServe(":"+port, mux); err != nil {
		log.Fatal(err)
	}
}

func indexHandler(w http.ResponseWriter, r *http.Request) {
	tmpl, err := template.ParseFS(templatesFS, "templates/index.html")
	if err != nil {
		http.Error(w, "Failed to load template: "+err.Error(), http.StatusInternalServerError)
		return
	}

	data := struct {
		Sizes []int
	}{
		Sizes: availableSizes,
	}

	if err := tmpl.Execute(w, data); err != nil {
		http.Error(w, "Failed to render template: "+err.Error(), http.StatusInternalServerError)
	}
}

func sortHandler(w http.ResponseWriter, r *http.Request) {
	// Parse form values
	algorithm := r.URL.Query().Get("algorithm")
	sizeStr := r.URL.Query().Get("size")

	if algorithm == "" || sizeStr == "" {
		http.Error(w, "Missing algorithm or size parameter", http.StatusBadRequest)
		return
	}

	size, err := strconv.Atoi(sizeStr)
	if err != nil {
		http.Error(w, "Invalid size parameter", http.StatusBadRequest)
		return
	}

	// Select the algorithm
	var sortFunc func([]int) []int
	var algorithmName string

	switch algorithm {
	case "bubble":
		sortFunc = algorithms.BubbleSort
		algorithmName = "Bubble Sort"
	case "merge":
		sortFunc = algorithms.MergeSort
		algorithmName = "Merge Sort"
	default:
		// We shouldn't reach this but...
		http.Error(w, "Invalid algorithm", http.StatusBadRequest)
		return
	}

	// Create SSE connection
	sse := datastar.NewSSE(w, r)

	// Send loading message
	sse.PatchElements(
		fmt.Sprintf(`<div id="result" class="result loading">
			<p>Running %s on %d elements...</p>
			<div class="spinner"></div>
		</div>`, algorithmName, size),
		datastar.WithSelectorID("result"),
	)

	// Generate a random array of the appropriate size
	arr := testdata.GenerateRandomArray(size)

	// Run the sort and measure time
	start := time.Now()
	sortFunc(arr)
	duration := time.Since(start)

	// Format the duration in a more meaningful way
        // there is likely a better way for this...
	var durationStr string
	if duration < time.Second {
		durationStr = fmt.Sprintf("%.3f ms", float64(duration.Microseconds())/1000)
	} else if duration < time.Minute {
		durationStr = fmt.Sprintf("%.3f s", duration.Seconds())
	} else {
		durationStr = fmt.Sprintf("%.1f min", duration.Minutes())
	}

	// Determine result class based on duration
        // Needs tweaking if other things change
	resultClass := "result success"
	if duration > 10*time.Second {
		resultClass = "result slow"
	} else if duration > 1*time.Second {
		resultClass = "result medium"
	}

	// Send the result
	sse.PatchElements(
		fmt.Sprintf(`<div id="result" class="%s">
			<h3>%s</h3>
			<p class="size">%d elements</p>
			<p class="duration">%s</p>
		</div>`, resultClass, algorithmName, size, durationStr),
		datastar.WithSelectorID("result"),
	)
}
