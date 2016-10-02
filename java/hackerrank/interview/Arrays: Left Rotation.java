import java.io.*;
import java.util.*;
import java.text.*;
import java.math.*;
import java.util.regex.*;

public class Solution {

    private static void solution(int[] a, int k) {
        int temp = 0;
        for(int i=0; i < a.length; i++){
            System.out.print(a[i]+" ");
            
        }
    }
    
    public static void main(String[] args) {
        Scanner in = new Scanner(System.in);
        int n = in.nextInt();
        int k = in.nextInt();
        int a[] = new int[n];
        int temp;
        int shift;
        for(int a_i=0; a_i < n; a_i++){
            temp = in.nextInt();
            shift = (a_i-k)%n;
            if(shift<0){
                shift = n+shift;
            }
            a[shift] = temp;
        }
        solution(a, n);
    }
}
