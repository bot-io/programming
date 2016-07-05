import java.io.*;
import java.util.*;

public class Solution {
    
    private class Node{
        public List<Node> children = new LinkedList<>();
        public boolean visited = false;
    }

    
    private static long solution(int[] a) {
        long result = 0L;
        return result;
    }

    public static void main(String[] args) {
        Scanner in = new Scanner(System.in);
        int t = in.nextInt();
        for (int i = 0; i < t; i++) {
            int n = in.nextInt();
            int[] a = new int[n];
            System.out.println(solution(a));
        }
    }
}
