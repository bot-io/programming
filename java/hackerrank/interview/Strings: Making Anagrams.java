import java.io.*;
import java.util.*;
import java.text.*;
import java.math.*;
import java.util.regex.*;
public class Solution {
    
    public static int numberNeeded(String first, String second) {
        HashMap<String,Integer> firstMap = new HashMap<>();
        HashMap<String,Integer> secondMap = new HashMap<>();
        for(int i = 0; i < first.length(); i++){
            String char = new String(first.charAt(i));
            if (!firstMap.containsKey(char)){
                firstMap.put(char, 1);
            }
            else{
                map.put(char, map.get(char) + 1);
            }
                
        }
        return 0;
    }
  
    public static void main(String[] args) {
        Scanner in = new Scanner(System.in);
        String a = in.next();
        String b = in.next();
        System.out.println(numberNeeded(a, b));
    }
}
