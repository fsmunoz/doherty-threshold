// Test data generator

package testdata

import (
    "math/rand"
)

// Create random integer array of given size
func GenerateRandomArray(n int) []int {
    arr := make([]int, n)
    for i := range arr {
        arr[i] = rand.Intn(10000)
    }
    return arr
}

// Create a sorted array of given size
func GenerateSortedArray(n int) []int {
    arr := make([]int, n)
    for i := range arr {
        arr[i] = i
    }
    return arr
}

// Create a reverse-sorted array
func GenerateReversedArray(n int) []int {
    arr := make([]int, n)
    for i := range arr {
        arr[i] = n - i
    }
    return arr
}
