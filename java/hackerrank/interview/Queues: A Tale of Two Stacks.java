import java.io.*;
import java.util.*;
import java.text.*;
import java.math.*;
import java.util.regex.*;

public class Solution {
    
     private static class MyQueue<T>{
         Stack<T> stack1 = new Stack<T>();
         Stack<T> stack2 = new Stack<T>();
         boolean reversed = false;
         public void enqueue(T elem){
             stack1.push(elem);
         }
         
         public T dequeue(){
             ensureLastElem();
             
             return stack2.pop();
         }
         
         public T peek(){
             ensureLastElem();
             
             return stack2.peek();
         }
         
         private void ensureLastElem(){
             if (stack2.isEmpty()){
                 while (!stack1.isEmpty()){
                     T elem = stack1.pop();
                     stack2.push(elem);
                }
             }
         }
     }
    
    public static void main(String[] args) {
        MyQueue<Integer> queue = new MyQueue<Integer>();

        Scanner scan = new Scanner(System.in);
        int n = scan.nextInt();

        for (int i = 0; i < n; i++) {
            int operation = scan.nextInt();
            if (operation == 1) { // enqueue
              queue.enqueue(scan.nextInt());
            } else if (operation == 2) { // dequeue
              queue.dequeue();
            } else if (operation == 3) { // print/peek
              System.out.println(queue.peek());
            }
        }
        scan.close();
    }
}
