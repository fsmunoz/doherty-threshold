// Algorithm tests
//
//
package algorithms_test

import (
    "reflect"
    "testing"
    "github.com/fsmunoz/doherty-threshold/pkg/algorithms"
    "github.com/fsmunoz/doherty-threshold/pkg/testdata"
)

func TestBubbleSort(t *testing.T) {
    tests := []struct{
        name string
        input []int
        want []int
    }{
        {"empty", []int{}, []int{}},
        {"single", []int{1}, []int{1}},
        {"sorted", []int{1,2,3}, []int{1,2,3}},
        {"reversed", []int{3,2,1}, []int{1,2,3}},
        {"duplicates", []int{3,1,2,1}, []int{1,1,2,3}},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Make a copy to avoid modifying test data
            input := make([]int, len(tt.input))
            copy(input, tt.input)

            got := algorithms.BubbleSort(input)
            if !reflect.DeepEqual(got, tt.want) {
                t.Errorf("BubbleSort(%v) = %v, want %v", tt.input, got, tt.want)
            }
        })
    }
}

func TestMergeSort(t *testing.T) {
    tests := []struct{
        name string
        input []int
        want []int
    }{
        {"empty", []int{}, []int{}},
        {"single", []int{1}, []int{1}},
        {"sorted", []int{1,2,3}, []int{1,2,3}},
        {"reversed", []int{3,2,1}, []int{1,2,3}},
        {"duplicates", []int{3,1,2,1}, []int{1,1,2,3}},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Make a copy to avoid modifying test data
            input := make([]int, len(tt.input))
            copy(input, tt.input)

            got := algorithms.MergeSort(input)
            if !reflect.DeepEqual(got, tt.want) {
                t.Errorf("MergeSort(%v) = %v, want %v", tt.input, got, tt.want)
            }
        })
    }
}

func BenchmarkBubbleSort(b *testing.B) {
    arr := testdata.GenerateRandomArray(1000)
    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        // Make a copy for each iteration
        input := make([]int, len(arr))
        copy(input, arr)
        algorithms.BubbleSort(input)
    }
}

func BenchmarkMergeSort(b *testing.B) {
    arr := testdata.GenerateRandomArray(1000)
    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        // Make a copy for each iteration
        input := make([]int, len(arr))
        copy(input, arr)
        algorithms.MergeSort(input)
    }
}
