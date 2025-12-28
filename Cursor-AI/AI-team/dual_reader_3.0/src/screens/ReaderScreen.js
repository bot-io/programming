import React, { useState } from 'react';
import { View, Text, StyleSheet, ScrollView } from 'react-native';

/**
 * Dual-Panel Reader Screen
 * Shows original text on left, translated text on right
 */
export default function ReaderScreen({ route }) {
  const { bookId } = route.params;
  const [currentPage, setCurrentPage] = useState(1);

  return (
    <View style={styles.container}>
      <View style={styles.panelContainer}>
        <View style={styles.panel}>
          <ScrollView style={styles.scrollView}>
            <Text style={styles.text}>
              {/* Original text will go here */}
            </Text>
          </ScrollView>
        </View>
        <View style={styles.panel}>
          <ScrollView style={styles.scrollView}>
            <Text style={styles.text}>
              {/* Translated text will go here */}
            </Text>
          </ScrollView>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000000',
  },
  panelContainer: {
    flex: 1,
    flexDirection: 'row',
  },
  panel: {
    flex: 1,
    borderRightWidth: 1,
    borderRightColor: '#333333',
  },
  scrollView: {
    flex: 1,
  },
  text: {
    color: '#FFFFFF',
    fontSize: 16,
    padding: 16,
    lineHeight: 24,
  },
});
