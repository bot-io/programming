import java.io.*;
import java.util.*;

public class Solution {
    
    private static void solutionON(int n) {
        long result = 0L;
        int candidate = 3;
        int[] jx = {2,1,3,1,2,3,3};
        int j = 0;
        while(candidate<n){
            //System.out.println("C: "+candidate);
            result+=candidate;
            candidate += jx[j];
            j = (j+1)%7;
        }
        
        System.out.println(result);
    }
    
    private static void solutionO1(int num) {
        long three,five,fifteen, result=0;
        
        three=(num-1)/3;
        five=(num-1)/5;
        fifteen=(num-1)/15;
        
        result = 3*(three*(three+1)/2)+5*(five*(five+1)/2)-15*(fifteen*(fifteen+1)/2);
        
        System.out.println(result);
    }

    public static void main(String[] args) {
        Scanner in = new Scanner(System.in);
        int t = in.nextInt();
        for (int i = 0; i < t; i++) {
            int n = in.nextInt();
            solutionO1(n);
            //System.out.println(solution(n));
        }
    }
}
