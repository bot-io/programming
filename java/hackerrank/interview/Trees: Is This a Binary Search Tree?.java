/* Hidden stub code will pass a root argument to the function below. Complete the function to solve the challenge. Hint: you may want to write one or more helper functions.  

The Node class is defined as follows:
    class Node {
        int data;
        Node left;
        Node right;
     }
*/

    boolean _checkBST(Node root, Integer min, Integer max) {
        if(root == null){
            return true;
        }

        if(max != null && root.data >= max){
            return false;
        }
        
        if(min != null && root.data <= min){
            return false;
        }
        
        return _checkBST(root.left, min, root.data) && _checkBST(root.right, root.data, max); 
    }

    boolean checkBST(Node root) {
        return _checkBST(root, null, null);
        
    }
