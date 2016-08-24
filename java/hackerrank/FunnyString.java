import java.io.*;
import java.util.*;

public class Solution {
    
    private static String solution(String a) {
        String funny = "Funny";
        String not_funny = "Not Funny";
        int l = a.length();
        if (l <= 2){
            return funny;
        }
        for(int i = 0; i < l/2; i++){
            char i1 = a.charAt(i);
            char i2 = a.charAt(i+1);
        }
        
        return a;
    }

    public static void main(String[] args) {
        Scanner in = new Scanner(System.in);
        int t = Integer.parseInt(in.nextLine());
        for (int i = 0; i < t; i++) {
            String n = in.nextLine();
            System.out.println(solution(n));
        }
    }
}
