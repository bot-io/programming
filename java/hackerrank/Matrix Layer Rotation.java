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
    
    public static void goDown(int[][]a, int x, int y, int maxM) {
        for (int i = x; i < maxM; i++){
            System.out.print(""+a[i][y]+" ");
        }
    }
    
    public static void goRight(int[][]a, int x, int y, int maxN) {
        for (int j = y; j < maxN; j++){
            System.out.print(""+a[x][j]+" ");
        }
    }
    
    public static void goUp(int[][]a, int x, int y, int minM) {
        for (int i = x; i > minM; i--){
            System.out.print(""+a[i][y]+" ");
        }
    }
    
    public static void goLeft(int[][]a, int x, int y, int minN) {
        for (int j = y; j > minN; j--){
            System.out.print(""+a[x][j]+" ");
        }
    }
    
    public static void printmSpirally(int[][]a, int m, int n) {
        int x=0,y=0;
        while(x <= m/2 && y <= n/2){
            goDown(a, x, y, m-1-x);
            goRight(a, m-1-x, y, n-1-y);
            goUp(a, m-1-x, n-1-y, y);
            goLeft(a, x, n-1-y, x);
            x++;
            y++;
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
        printmSpirally(a, m, n);
    }
}
