import java.io.*;
import java.util.*;
import java.text.*;
import java.math.*;
import java.util.regex.*;
public class Solution {
    
    public static int numberNeeded(String first, String second) {
        int result = 0;
        HashMap<String,Integer> firstMap = new HashMap<>();
        HashMap<String,Integer> secondMap = new HashMap<>();
        for(int i = 0; i < first.length(); i++){
            String _char = String.valueOf(first.charAt(i));
            if (!firstMap.containsKey(_char)){
                firstMap.put(_char, 1);
            }
            else{
                firstMap.put(_char, firstMap.get(_char) + 1);
            }
        }
        
        for(int i = 0; i < second.length(); i++){
            String _char = String.valueOf(second.charAt(i));
            Integer val = firstMap.get(_char);
            if(val==null || val == 0){
                result++;
            } else {
                firstMap.put(_char, firstMap.get(_char) - 1);
            }
        }
        Collection<Integer> values = firstMap.values();
        for (Integer val : values){
            result+=val;
        }
        return result;
    }
  
    public static void main(String[] args) {
        Scanner in = new Scanner(System.in);
        String a = in.next();
        String b = in.next();
        System.out.println(numberNeeded(a, b));
    }
}
