// Bubble Sort Implementation
//
// This is an intentionally naive implementation to clearly
// demonstrate O(n^2) complexity.
//
// Bubble sort works by repeatedly "bubbling" the largest unsorted
// element to the end of the array through adjacent comparisons and
// swaps.
//
// Reference: https://www.w3schools.com/dsa/dsa_algo_bubblesort.php
//
// Check the notebook and README for more resources in this project!

package algorithms

// BubbleSort sorts an integer slice in ascending order using the bubble sort algorithm.
//
// Time Complexity: O(n²) - requires n passes over the array, each examining up to n elements
// Space Complexity: O(n) - creates a copy of the input array
//
// How it works:
//  1. Make multiple passes through the array (outer loop)
//  2. On each pass, compare adjacent elements (inner loop)
//  3. Swap them if they're in the wrong order
//  4. After each pass, the largest unsorted element "bubbles" to its final position
//  5. Repeat until all elements are in their correct positions
//
// Example: [5,2,8,1] -> [2,5,1,8] -> [2,1,5,8] -> [1,2,5,8]
//
// NB: This implementation does not include the "already sorted"
// optimization to clearly demonstrate worst-case O(n^2) behaviour and
// avoid making the code more complex / harder to follow.

func BubbleSort(arr []int) []int {
    // Create a copy to avoid modifying the original array
    result := make([]int, len(arr))
    copy(result, arr)

    n := len(result)

    // Outer loop: number of passes needed (n passes for n elements),
    // each pass guarantees one more element is in its final position
    for i := 0; i < n; i++ {
        // Inner loop: compare adjacent pairs
        // we use n-i-1 because, after each pass, the last i elements are already sorted
        // (they've "bubbled" to their final positions, hence the name)
        for j := 0; j < n-i-1; j++ {
            // If current element is larger than next, they're out of order...
            if result[j] > result[j+1] {
                // Swap through multiple assignment
                result[j], result[j+1] = result[j+1], result[j]
            }
        }
        // After this pass, the largest unsorted element is now in position (n-i-1)
    }
    return result
}
