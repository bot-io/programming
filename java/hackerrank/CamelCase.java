import java.io.*;
import java.util.*;
import java.text.*;
import java.math.*;
import java.util.regex.*;

public class Solution {

    public static void main(String[] args) {
        Scanner in = new Scanner(System.in);
        String s = in.next();
        char[] c = s.toCharArray();
        int res = 0;
        if (c.length > 0){
            res++;
            for (int i = 0; i < c.length; i++){
                if (Character.isUpperCase(c[i])){
                    res++;
                }
            }
        }
        
        System.out.print(res);
    }
}
