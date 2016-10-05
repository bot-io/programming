/*
Detect a cycle in a linked list. Note that the head pointer may be 'null' if the list is empty.

A Node is defined as: 
    class Node {
        int data;
        Node next;
    }
*/
HashMap<Node, Boolean> map;
boolean hasCycle(Node head) {
    map = new HashMap<>();
    boolean result = _hasCycle(head);
    return result;
}

boolean _hasCycle(Node head) {
    if(head == null){
        return false;
    }
    if(map.containsKey(head)){
        return true;
    }
    map.put(head, true);
    return false||_hasCycle(head.next);
}
