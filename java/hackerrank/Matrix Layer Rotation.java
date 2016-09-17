import java.io.*;
import java.util.*;

public class Solution {
    
    public static void printm(int[][]a, int m, int n) {
        for (int i = 0; i < m; i++){
            for(int j = 0; j < n; j++){
                System.out.print(""+a[i][j]+" ");
            }
            System.out.print("\n");
        }
    }
    
    public static void printmSpirally(int[][]a, int m, int n) {
        for (int i = 0; i < m; i++){
            for(int j = 0; j < n; j++){
                System.out.print(""+a[i][j]+" ");
            }
            System.out.print("\n");
        }
    }
    
    public static void main(String[] args) {
        Scanner in = new Scanner(System.in);
        int m = in.nextInt();
        int n = in.nextInt();
        int r = in.nextInt();
        int[][] a = new int[m][n];
        for (int i = 0; i < m; i++){
            for(int j = 0; j < n; j++){
                a[i][j] = in.nextInt();
            }
        }
        printm(a, m, n);
    }
}
