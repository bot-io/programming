import java.io.*;
import java.util.*;

public class Solution {
    
    public static boolean nextPermutation(char[] array) {
        // Find non-increasing suffix
        int i = array.length - 1;
        while (i > 0 && array[i - 1] >= array[i]){
            i--;
        }
            
        if (i <= 0){
            return false;
        }

        // Find element to pivot
        int j = array.length - 1;
        while (array[j] <= array[i - 1]){
            j--;
        }
        char temp = array[i - 1];
        array[i - 1] = array[j];
        array[j] = temp;

        // Reverse suffix
        j = array.length - 1;
        while (i < j) {
            temp = array[i];
            array[i] = array[j];
            array[j] = temp;
            i++;
            j--;
        }
        return true;
    }
    
    private static void solution(String s) {
        char[] c = s.toCharArray();
        String res = "no answer";
        if (nextPermutation(c)){
            res = new String(c);
        }
        
        System.out.println(res);
    }

    public static void main(String[] args) {
        Scanner in = new Scanner(System.in);
        int t = in.nextInt();
        
        for (int i = 0; i < t; i++){
            String s = in.next();
            solution(s);
        }
    }
}
