import java.io.*;
import java.util.*;
import java.text.*;
import java.math.*;
import java.util.regex.*;

public class Solution {

    public static void bubbleSort(int[] x) {
        int endPosition = x.length - 1;
        int swapPosition;
        // Track number of elements swapped during sorting
        int numberOfSwaps = 0;
        
        while( endPosition > 0 ) {
            swapPosition = 0;
            
            for(int i = 0; i < endPosition; i++) {
                
                if( x[i] > x[i + 1] ){
                    // Swap elements 'i' and 'i + 1':
                    int tmp = x[i];
                    x[i] = x[i + 1];
                    x[i + 1] = tmp;
                    
                    swapPosition = i;
                    numberOfSwaps++;
                } // end if
                
            } // end for
            
            endPosition = swapPosition;
        } // end while
        System.out.println("Array is sorted in "+numberOfSwaps+" swaps.");
        System.out.println("First Element: "+x[0]);
        System.out.println("Last Element: "+x[x.length-1]);
    } 
    
    public static void main(String[] args) {
        Scanner in = new Scanner(System.in);
        int n = in.nextInt();
        int a[] = new int[n];
        for(int a_i=0; a_i < n; a_i++){
            a[a_i] = in.nextInt();
        }
        bubbleSort(a);
    }
}
