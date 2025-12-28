import AsyncStorage from '@react-native-async-storage/async-storage';

/**
 * Progress Tracking Service
 * Saves and loads reading progress for each book
 */
class ProgressService {
  async saveProgress(bookId, page, timestamp) {
    const progress = {
      bookId,
      currentPage: page,
      lastRead: timestamp || new Date().toISOString(),
    };
    await AsyncStorage.setItem(`progress_${bookId}`, JSON.stringify(progress));
  }

  async loadProgress(bookId) {
    const data = await AsyncStorage.getItem(`progress_${bookId}`);
    return data ? JSON.parse(data) : null;
  }
}

export default new ProgressService();
