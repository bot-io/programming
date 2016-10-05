import java.io.*;
import java.util.*;
import java.text.*;
import java.math.*;
import java.util.regex.*;

public class Solution {
    public static boolean isBalanced(String expression) {
        Deque<String> stack = new ArrayDeque<>();
        for(int i = 0; i < expression.length(); i++){
            String item = String.valueOf(expression.charAt(i));
            if (item.equals("{")||item.equals("[")||item.equals("(")){
                stack.push(item);
            } else {
                String top = stack.peek();
                
                if(top == null){
                    return false;
                }
                
                if(top.equals("{")&&item.equals("}")||
                  top.equals("(")&&item.equals(")")||
                  top.equals("[")&&item.equals("]")){
                    stack.pop();
                } else {
                    return false;
                }
            }
        }
        if(!stack.isEmpty()){
            return false;
        }
        return true;
     }
  
    public static void main(String[] args) {
        Scanner in = new Scanner(System.in);
        int t = in.nextInt();
        for(int a0 = 0; a0 < t; a0++) {
            String expression = in.next();
            boolean answer = isBalanced(expression);
            if(answer)
                System.out.println("YES");
            else System.out.println("NO");
        }
    }
}
