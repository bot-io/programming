import java.io.*;
import java.util.*;
import java.text.*;
import java.math.*;
import java.util.regex.*;

public class Solution {

    public static void main(String[] args) {
        Scanner in = new Scanner(System.in);
        int m = in.nextInt();
        int n = in.nextInt();
        
        HashMap<String,Integer> magazineMap = new HashMap<>();
        for(int i = 0; i < m; i++){
            String word = in.next();
            if (!magazineMap.containsKey(word)){
                magazineMap.put(word, 1);
            }
            else{
                magazineMap.put(word, magazineMap.get(word) + 1);
            }
        }
        
        for(int i = 0; i < n; i++){
            String word = in.next();
            Integer val = magazineMap.get(word);
            if(val==null || val == 0){
                System.out.print("No");
                return;
            } else{
                magazineMap.put(word, magazineMap.get(word) - 1);
            }
        }
        
        System.out.print("Yes");
    }
}
