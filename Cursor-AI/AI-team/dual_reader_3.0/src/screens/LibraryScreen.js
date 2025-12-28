import React, { useState, useEffect } from 'react';
import { View, Text, FlatList, TouchableOpacity, StyleSheet } from 'react-native';

/**
 * Library Screen - Displays all imported books
 */
export default function LibraryScreen({ navigation }) {
  const [books, setBooks] = useState([]);

  useEffect(() => {
    // TODO: Load books from storage
    loadBooks();
  }, []);

  const loadBooks = async () => {
    // TODO: Implement book loading
  };

  const renderBook = ({ item }) => (
    <TouchableOpacity
      style={styles.bookCard}
      onPress={() => navigation.navigate('Reader', { bookId: item.id })}
    >
      <Text style={styles.bookTitle}>{item.title}</Text>
      <Text style={styles.bookAuthor}>{item.author}</Text>
    </TouchableOpacity>
  );

  return (
    <View style={styles.container}>
      <FlatList
        data={books}
        renderItem={renderBook}
        keyExtractor={(item) => item.id}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000000',
  },
  bookCard: {
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#333333',
  },
  bookTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#FFFFFF',
    marginBottom: 4,
  },
  bookAuthor: {
    fontSize: 14,
    color: '#CCCCCC',
  },
});
