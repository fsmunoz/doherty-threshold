// Merge Sort Implementation
//
// A divide-and-conquer algorithm that achieves O(n log n) time complexity by:
//
//  1. Dividing the array into smaller subarrays (divide)
//  2. Recursively sorting those subarrays (conquer)
//  3. Merging the sorted subarrays back together (combine)
//
// This is significantly faster than O(n^2) algorithms like bubble sort for large inputs.
//
// Reference used : https://www.w3schools.com/dsa/dsa_algo_mergesort.php
//
// Check the notebook and README for more resources in this project!

package algorithms

// MergeSort sorts an integer slice in asc. order using the merge sort algorithm.
//
// Time Complexity: O(n log n):
//
//   - log n levels of recursion (dividing array in half repeatedly)
//   - n work at each level (merging elements)
//
// Space Complexity: O(n), requires temporary arrays for merging
//
// How it works:
//
//  1. Base case: arrays of 0 or 1 elements are already sorted
//  2. Divide: split the array into two halves at the midpoint
//  3. Conquer: recursively sort each half
//  4. Combine: merge the two sorted halves into a single sorted array
//
// Example visualization:
//
//	[5,2,8,1] -> split -> [5,2] and [8,1]
//	[5,2] -> split -> [5] and [2] -> merge -> [2,5]
//	[8,1] -> split -> [8] and [1] -> merge -> [1,8]
//	[2,5] and [1,8] -> merge -> [1,2,5,8]
//
// The recursion tree has log n depth (check the notebook for a visual
// explanation), and each level processes all n elements, giving us
// O(n log n) total operations.

func MergeSort(arr []int) []int {
    // Base case: arrays with 0 or 1 elements are already sorted
    if len(arr) <= 1 {
        return arr
    }

	// Divide: find the midpoint to split the array into two halves
	// If odd, this will not be symmetrical
    mid := len(arr) / 2

    // Conquer: recursively sort the left half (from start to mid)
    left := MergeSort(arr[:mid])

    // Conquer: recursively sort the right half (from mid to end)
    right := MergeSort(arr[mid:])

    // Combine: merge the two sorted halves into a single sorted array
    return merge(left, right)
}

// This is the second half of the algorithm: "merge".
// merge combines two sorted slices into a single sorted slice.
//
// This is the "combine" step of the divide-and-conquer strategy.
// Since both input slices are already sorted, we can merge them
// efficiently in O(n) time by comparing their front elements.
//
// Parameters:
//
//	left: sorted slice of integers
//	right: sorted slice of integers
//
// Returns:
//
//	A new sorted slice containing all elements from left and right
//
// Example: merge([2,5], [1,8]) -> [1,2,5,8]

func merge(left, right []int) []int {
    // Pre-allocate result slice with exact capacity needed (optimization, optional)
    result := make([]int, 0, len(left)+len(right))

    // Track current position in each input slice
    i, j := 0, 0

    // Compare and merge while both slices have elements remaining
    // This loop handles the main merging logic using a two-pointer technique
    for i < len(left) && j < len(right) {
        if left[i] <= right[j] {
            // Left element is smaller (or equal), add it first
            result = append(result, left[i])
            i++ // Move to next element in left slice
        } else {
            // Right element is smaller, add it first
            result = append(result, right[j])
            j++ // Move to next element in right slice
        }
    }

    // Append any remaining elements from left slice
    // (if right slice was exhausted first)...
    result = append(result, left[i:]...)

    // ...append any remaining elements from right slice
    // (if left slice was exhausted first)
    result = append(result, right[j:]...)

    return result
}
