package main

import (
    "github.com/fsmunoz/doherty-threshold/pkg/algorithms"
    "github.com/fsmunoz/doherty-threshold/pkg/server"
)

func main() {
    server.Run("merge", algorithms.MergeSort)
}

