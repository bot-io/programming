import java.util.*;

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
    public void isEmpty(String methodName) {
        if(size == 0) {
            throw new IllegalStateException(
                "You cannot perform '" + methodName + "' on an empty Heap."
            );
        }
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
    
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);
        int range = scanner.nextInt();
        scanner.close();
        
        // Insert random values into heaps:
        Heap minHeap = new MinHeap();
        Heap maxHeap = new MaxHeap();
        System.out.println("Insert Number Sequence:");
        for(int i = 0; i < range; i++) {
            int value = (int) (Math.random() * 100);
            minHeap.add(value);
            maxHeap.add(value);
            System.out.print(+ value + " ");
        }
        
        // Remove values from heaps:
        System.out.println("\n\nPoll Values:\n------------\nMinHeap MaxHeap");
        for(int i = 0; i < range; i++) {
            System.out.format("  %-12d", minHeap.poll());
            System.out.format("%-6d\n", maxHeap.poll());
        }
        try {
            minHeap.peek();
        }
        catch(IllegalStateException e) {
            System.out.println(e.getMessage());
        }
        try {
            maxHeap.poll();
        }
        catch(IllegalStateException e) {
            System.out.println(e.getMessage());
        }
    }
}
