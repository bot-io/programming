import React from 'react';
import { View, TouchableOpacity, Text, Slider, StyleSheet } from 'react-native';

/**
 * Navigation Controls Component
 * Previous/Next buttons, page slider, page number display
 */
export default function NavigationControls({ currentPage, totalPages, onPageChange }) {
  return (
    <View style={styles.container}>
      <TouchableOpacity
        style={styles.button}
        onPress={() => onPageChange(Math.max(1, currentPage - 1))}
      >
        <Text style={styles.buttonText}>Previous</Text>
      </TouchableOpacity>
      <Text style={styles.pageNumber}>{currentPage} / {totalPages}</Text>
      <TouchableOpacity
        style={styles.button}
        onPress={() => onPageChange(Math.min(totalPages, currentPage + 1))}
      >
        <Text style={styles.buttonText}>Next</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 16,
  },
  button: {
    padding: 8,
    backgroundColor: '#333333',
    borderRadius: 4,
  },
  buttonText: {
    color: '#FFFFFF',
  },
  pageNumber: {
    color: '#FFFFFF',
  },
});
