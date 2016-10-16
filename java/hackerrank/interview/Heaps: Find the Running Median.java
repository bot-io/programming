import java.io.*;
import java.util.*;
import java.text.*;
import java.math.*;
import java.util.regex.*;

/** Heap of ints **/
abstract class Heap {
    /** Current array length **/
    protected int capacity;
    /** Current number of elements in Heap **/
    protected int size;
    /** Array of Heap elements **/
    protected int[] items;

    public Heap() {
        this.capacity = 10;
        this.size = 0;
        this.items = new int[capacity];
    }
    
    /** @param parentIndex The index of the parent element.
        @return The index of the left child.
    **/
    public int getLeftChildIndex(int parentIndex) {
        return 2 * parentIndex + 1;
    }
    
    /** @param parentIndex The index of the parent element.
        @return The index of the right child.
    **/
    public int getRightChildIndex(int parentIndex) {
        return 2 * parentIndex + 2;
    }
    
    /** @param childIndex The index of the child element.
        @return The index of the parent element.
    **/
    public int getParentIndex(int childIndex) {
        return (childIndex - 1) / 2;
    }
    
    /** @param index The index of the element you are checking.
        @return true if the Heap contains enough elements to fill the left child index, 
                false otherwise.
    **/
    public boolean hasLeftChild(int index) {
        return getLeftChildIndex(index) < size;
    }
    
    /** @param index The index of the element you are checking.
        @return true if the Heap contains enough elements to fill the right child index, 
                false otherwise.
    **/
    public boolean hasRightChild(int index) {
        return getRightChildIndex(index) < size;
    }
    
    /** @param index The index of the element you are checking.
        @return true if the calculated parent index exists within array bounds
                false otherwise.
    **/
    public boolean hasParent(int index) {
        return getParentIndex(index) >= 0;
    }
    
    /** @param index The index of the element whose child you want.
        @return the value in the left child.
    **/
    public int leftChild(int index) {
        return items[getLeftChildIndex(index)];
    }
    
    /** @param index The index of the element whose child you want.
        @return the value in the right child.
    **/
    public int rightChild(int index) {
        return items[getRightChildIndex(index)];
    }
    
    /** @param index The index of the element you are checking.
        @return the value in the parent element.
    **/
    public int parent(int index) {
        return items[getParentIndex(index)];
    }
    
    /** @param indexOne The first index for the pair of elements being swapped.
        @param indexTwo The second index for the pair of elements being swapped.
    **/
    public void swap(int indexOne, int indexTwo) {
        int temp = items[indexOne];
        items[indexOne] = items[indexTwo];
        items[indexTwo] = temp;
    }
    
    /** Doubles underlying array if capacity is reached. **/
    public void ensureCapacity() {
        if(size == capacity) {
            capacity = capacity << 1;
            items = Arrays.copyOf(items, capacity);
        }
    }
    
    /** @throws IllegalStateException if Heap is empty.
        @return The value at the top of the Heap.
     **/
    public int peek() {
        isEmpty("peek");
        
        return items[0];
    }
    
    /** @throws IllegalStateException if Heap is empty. **/
    public boolean isEmpty(String methodName) {
        if(isEmpty()) {
            throw new IllegalStateException(
                "You cannot perform '" + methodName + "' on an empty Heap."
            );
        }
        return false;
    }
    
    /** @throws IllegalStateException if Heap is empty. **/
    public boolean isEmpty() {
        if(size == 0) {
            return true;
        }
        return false;
    }
    
    /** Extracts root element from Heap.
        @throws IllegalStateException if Heap is empty.
    **/
    public int poll() {
        // Throws an exception if empty.
        isEmpty("poll");
        
        // Else, not empty
        int item = items[0];
        items[0] = items[size - 1];
        size--;
        heapifyDown();
        return item;
    }
    
    /** @param item The value to be inserted into the Heap. **/
    public void add(int item) {
        // Resize underlying array if it's not large enough for insertion
        ensureCapacity();
        
        // Insert value at the next open location in heap
        items[size] = item;
        size++;
        
        // Correct order property
        heapifyUp();
    }
    
    /** Prints heap **/
    public void print(){
        System.out.print("{");
        for(int i = 0; i < size ; i++){
            System.out.print(items[i]+" ");
        }
        System.out.println("}");
    }
    
    /** Swap values down the Heap. **/
    public abstract void heapifyDown();
    
    /** Swap values up the Heap. **/
    public abstract void heapifyUp();
}

class MaxHeap extends Heap {
    
    public void heapifyDown() {
        int index = 0;
        while(hasLeftChild(index)) {
            int smallerChildIndex = getLeftChildIndex(index);
            
            if(    hasRightChild(index) 
                && rightChild(index) > leftChild(index)
            ) {
                smallerChildIndex = getRightChildIndex(index);
            }
            
            if(items[index] > items[smallerChildIndex]) {
                break;
            }
            else {
                swap(index, smallerChildIndex);
            }
            index = smallerChildIndex;
        }
    }
    
    public void heapifyUp() {
        int index = size - 1;
        
        while(    hasParent(index)
             &&   parent(index) < items[index] 
            ) {
            swap(getParentIndex(index), index);
            index = getParentIndex(index);
        }
    }
}

class MinHeap extends Heap {
    
    public void heapifyDown() {
        int index = 0;
        while(hasLeftChild(index)) {
            int smallerChildIndex = getLeftChildIndex(index);
            
            if(    hasRightChild(index) 
                && rightChild(index) < leftChild(index)
            ) {
                smallerChildIndex = getRightChildIndex(index);
            }
            
            if(items[index] < items[smallerChildIndex]) {
                break;
            }
            else {
                swap(index, smallerChildIndex);
            }
            index = smallerChildIndex;
        }
    }
    
    public void heapifyUp() {
        int index = size - 1;
        
        while(    hasParent(index)
             &&   parent(index) > items[index] 
            ) {
            swap(getParentIndex(index), index);
            index = getParentIndex(index);
        }
    }
}

public class Solution {

    public static void main(String[] args) {
        MinHeap minHeap = new MinHeap();
        MaxHeap maxHeap = new MaxHeap();
        Scanner in = new Scanner(System.in);
        int n = in.nextInt();
        //int a[] = new int[n];
        for(int a_i=0; a_i < n; a_i++){
            int next = in.nextInt();
            
            maxHeap.add(next);
            
            if((!minHeap.isEmpty() && minHeap.peek() > maxHeap.peek())){
                int temp = minHeap.poll();
                minHeap.add(maxHeap.poll());
                maxHeap.add(temp);
            } else {
                minHeap.add(maxHeap.poll());
            }
            
            minHeap.print();
            maxHeap.print();
            if(a_i % 2 == 0){
                System.out.println(minHeap.peek() / 1.0);
            } else {
                System.out.println((maxHeap.peek() + minHeap.peek()) / 2.0);
            }
        }
    }
}
