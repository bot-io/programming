import java.io.*;
import java.util.*;
import java.text.*;
import java.math.*;
import java.util.regex.*;

class TrieNode {
    public HashMap <Character, TrieNode> childen;
    public boolean isWord;
    
    public void print(){
        printNode(this, '+', 0);
    }
    
    private void printNode(TrieNode node, Character c, int level){
        if (node.childen != null){
            Set<Character> keySet = node.childen.keySet();
            for(Character cc : keySet){
                TrieNode child = node.childen.get(cc);
                printNode(child, cc, level+1);
            }
        }
        
        for(int i = 0; i < level; i++){
            System.out.print("====");
        }
        System.out.print(c+(node.isWord?"*\n":"\n"));
    }
}

public class Solution {
    
    private static TrieNode trie = new TrieNode();
    
    private static void addWord(String word){
        char[] chars = word.toCharArray();
        List<Character> listC = new ArrayList<Character>();
        for (char c : chars) {
            listC.add(c);
        }
        
        ArrayDeque<Character> arrayC = new ArrayDeque<>(listC);
        addWord(arrayC, trie);
    }
    
    private static void addWord(ArrayDeque<Character> arrayC, TrieNode node){
        if (arrayC.isEmpty()){
            node.isWord = true;
            return;
        }
        
        Character c = arrayC.pollFirst();
        if(node.childen == null){
            node.childen = new HashMap<>();
        }
        
        TrieNode child = node.childen.get(c);
        if (child == null){
            child = new TrieNode();
            node.childen.put(c, child);
        }
        
        addWord(arrayC, child);
    }
    
    private static int searchWord(String word){
        char[] chars = word.toCharArray();
        List<Character> listC = new ArrayList<Character>();
        for (char c : chars) {
            listC.add(c);
        }
        
        ArrayDeque<Character> arrayC = new ArrayDeque<>(listC);
        return searchWord(arrayC, trie);
    }
    
    private static int searchWord(ArrayDeque<Character> arrayC, TrieNode node){
        if (arrayC.isEmpty()){
            return countWords(node);
        }
        
        Character c = arrayC.pollFirst();
        if(node.childen == null){
            return 0;
        }
        
        TrieNode child = node.childen.get(c);
        if (child == null){
            return 0;
        }
        
        return searchWord(arrayC, child);
    }
    
    private static int countWords(TrieNode node){
        int result = _countWords(node);
        return result;
    }
    
    private static int _countWords(TrieNode node){
        int result = (node.isWord ? 1 : 0);
        
        if(node.childen == null){
            return result;
        }
        
        Set<Character> keySet = node.childen.keySet();
        for(Character cc : keySet){
            TrieNode child = node.childen.get(cc);
            result += _countWords(child);
        }
        
        return result;
    }
    
    public static void main(String[] args) {
        Scanner in = new Scanner(System.in);
        int n = in.nextInt();
        for(int a0 = 0; a0 < n; a0++){
            String operation = in.next();
            String word = in.next();
            if (operation.equals("add")){
                addWord(word);
            }
            else{
                System.out.println(searchWord(word));
            }
        }
    }
}
