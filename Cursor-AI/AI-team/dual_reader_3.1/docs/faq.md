# Frequently Asked Questions (FAQ)

## General Questions

### What file formats does Dual Reader support?
Dual Reader supports **EPUB** and **MOBI** ebook formats. These are the most common ebook formats available.

### Is Dual Reader free?
Yes! Dual Reader 3.1 is completely free and open-source. There are no in-app purchases or subscriptions.

### Does Dual Reader require an internet connection?
Books can be read offline once imported. However, **initial translations require an internet connection**. After translation, content is cached locally for offline reading.

### Is my data private?
Yes! All data is stored locally on your device. No user data is collected, tracked, or sent to external servers. Translations use free APIs but don't store your content.

## Importing Books

### How do I import books?
**Mobile:** Tap the "Import Book" button and select a file from your device.
**Web:** Click "Import Book" or drag and drop EPUB/MOBI files onto the library screen.

### Can I import books from cloud storage?
Yes, if your device supports it. On mobile, you can access files from cloud storage apps through the file picker.

### Why can't I import a specific book?
Possible reasons:
- File format not supported (only EPUB and MOBI)
- File is corrupted
- File is too large (very rare)
- Insufficient storage space

Try importing a different book to verify the app is working correctly.

### Can I delete books?
Yes! Long-press a book card (or use the delete option) to remove it from your library. This action cannot be undone.

## Translation

### How accurate are translations?
Translation accuracy depends on:
- Source and target languages
- Text complexity
- Translation service used

For best results, use languages with good translation support (major languages like Spanish, French, German, etc.).

### Which translation service is used?
Dual Reader uses free translation services:
- **LibreTranslate** (primary, open-source)
- **MyMemory Translation API** (fallback)

### Can I change the translation language?
Yes! Go to Settings → Translation → Translation Language and select your preferred language.

### Why is translation slow?
- First translation requires internet connection
- Complex text takes longer to translate
- Translation service may be busy

Subsequent pages use cached translations and load faster.

### Can I translate offline?
Yes, if the content was previously translated and cached. Initial translations require an internet connection.

### How much can I translate?
Translation limits depend on the free service tiers:
- LibreTranslate: Generally unlimited for personal use
- MyMemory: 10,000 words per day (free tier)

For most users, these limits are sufficient.

## Reading Experience

### How does pagination work?
Smart pagination automatically calculates page breaks based on:
- Screen size
- Font size
- Line height
- Margins

Pages are calculated to fit text perfectly without scrolling.

### Can I adjust page breaks?
Page breaks are automatic, but you can influence them by adjusting:
- Font size (Settings → Font)
- Line height (Settings → Font)
- Margins (Settings → Layout)

### Why do pages change when I adjust settings?
Pagination recalculates when you change font size, line height, or margins to ensure text fits properly on each page.

### How do bookmarks work?
- Tap the bookmark icon to add/remove a bookmark
- View all bookmarks via the bookmarks button
- Tap a bookmark to jump to that page
- Bookmarks are saved per book

### Can I navigate by chapters?
Yes, if the book includes chapter information. Use the chapters button in reader controls to navigate.

### How do I go back to the library?
Tap the back button in reader controls or use your device's back button.

## Customization

### What themes are available?
- **Dark**: Default dark theme
- **Light**: Bright theme
- **Sepia**: Warm sepia tone

Change themes in Settings → Appearance.

### Can I customize fonts?
Yes! Choose from 7 font families and adjust size (12-24) and line height (1.0-2.5) in Settings → Font.

### What is panel ratio?
Panel ratio controls the width distribution between original and translated panels in landscape mode. Adjust it in Settings → Layout.

### Can I change text alignment?
Yes! Choose left, center, or justify alignment in Settings → Layout.

### How do I reset settings?
Currently, you need to manually adjust settings back to defaults. Settings export/import can help you restore previous configurations.

## Technical Questions

### What platforms are supported?
- **Android**: API 21+ (Android 5.0+)
- **iOS**: 12.0+
- **Web**: Modern browsers (Chrome, Firefox, Safari, Edge)

### Does it work on tablets?
Yes! Dual Reader works great on tablets and adapts to different screen sizes.

### Can I use it offline?
Yes! Books and cached translations work offline. Only initial translations require internet.

### How is data stored?
All data is stored locally on your device:
- Books: Device storage
- Settings: Local preferences
- Progress: Local database
- Bookmarks: Local database
- Translations: Local cache

### Can I export my reading progress?
Currently, progress is stored locally only. Future versions may include export functionality.

### Why does the app crash sometimes?
Possible causes:
- Very large books (rare)
- Insufficient memory
- Corrupted book file

Try:
- Restarting the app
- Deleting and re-importing the problematic book
- Clearing app cache (platform dependent)

## Troubleshooting

### Books won't import
- Check file format (EPUB or MOBI only)
- Verify file isn't corrupted
- Ensure sufficient storage space
- Try a different book to test

### Translation not working
- Check internet connection
- Verify translation language is set
- Try a different language
- Restart the app

### Pages not displaying correctly
- Adjust font size or margins
- Try a different theme
- Restart the app
- Re-import the book

### App is slow
- Large books may take time to load initially
- First translation is slower
- Try reducing font size
- Close other apps to free memory

### Settings not saving
- Ensure app has storage permissions
- Restart the app
- Check available storage space

### Can't find a feature
- Check Settings screen
- Review Features documentation
- Look for help icons (ℹ️) in the app

## Getting Help

### Where can I get more help?
- Check the **Getting Started** guide
- Review the **Features** documentation
- Read the **User Manual** for detailed information
- Look for help icons (ℹ️) throughout the app

### How do I report bugs?
Since this is an open-source project, you can report issues through the project repository or contact the development team.

### Can I request features?
Feature requests can be submitted through the project repository or development channels.

### Is there a user manual?
Yes! Check the User Manual section in the help/documentation area of the app.

## Privacy & Security

### Is my reading data private?
Yes! All data stays on your device. Nothing is sent to external servers except translation requests (which don't include personal information).

### Are translations stored securely?
Translations are cached locally on your device. They're not shared with other users or services.

### Does the app track me?
No! Dual Reader doesn't collect analytics, track usage, or gather personal information.

### Can I use it without internet?
Yes, for reading books and cached translations. Only initial translations require internet.

### How do I know if a book has chapters?
Chapters are available if the book file includes a table of contents. Tap the chapters button in reader controls - if chapters are available, you'll see a list. If not, you'll see a message indicating no chapters are available.

### Can I read multiple books at once?
You can have multiple books in your library, but you read one book at a time. Your progress is saved automatically, so you can switch between books and resume where you left off.

### What happens if I delete a book?
Deleting a book removes it from your library and deletes the file from your device. This action cannot be undone. Your reading progress and bookmarks for that book are also deleted.

### Can I share my settings with others?
Yes! Export your settings (Settings → Settings Management → Export Settings) and share the file with others. They can import it to use your configuration.

### Why don't I see translations immediately?
- First-time translation requires an internet connection
- Translation may take a few seconds depending on text length
- Check your internet connection if translation is slow
- Verify translation language is set in Settings

### Can I change the translation language while reading?
Yes! Go to Settings → Translation → Translation Language and select a different language. The current page will be retranslated automatically.

### How accurate are translations?
Translation accuracy varies by:
- Language pair (some combinations translate better than others)
- Text complexity (simple text translates better than technical content)
- Translation service availability

For best results, use major languages (Spanish, French, German, etc.) and simple, clear text.

### What if translation fails?
If translation fails:
1. Check your internet connection
2. Try a different translation language
3. Restart the app
4. Check if the translation service is available
5. Try again later if the service is busy

### Can I customize the panel layout?
Yes! In landscape mode, you can adjust the panel ratio (Settings → Layout → Panel Ratio) to control how much space each panel takes. Portrait mode always stacks panels vertically.

### How do I know my reading progress?
Reading progress is shown:
- On book cards in the library (progress bar and percentage)
- In reader controls (current page / total pages)
- Automatically saved as you read

### Can I export my reading progress?
Currently, reading progress is stored locally only. Future versions may include export functionality.

### What's the difference between themes?
- **Dark**: Black background, white text - best for low-light reading
- **Light**: White background, black text - best for bright environments
- **Sepia**: Warm brown tones - reduces eye strain, comfortable for extended reading

### Can I use custom fonts?
Currently, you can choose from 7 pre-installed font families. Custom font support may be added in future versions.

### Why does the page count change?
Page count changes when you adjust:
- Font size (larger fonts = more pages)
- Line height (more spacing = more pages)
- Margins (larger margins = more pages)

This ensures text fits properly on each page.

### How do I reset everything?
To reset settings:
1. Manually adjust each setting back to default
2. Or export your current settings first, then reset manually
3. Delete and reinstall the app (removes all data)

### Can I use Dual Reader for language learning?
Yes! Dual Reader is excellent for language learning:
- Compare original and translated text side-by-side
- See translations in context
- Bookmark difficult sections
- Read at your own pace

### Is there a limit to how many books I can import?
No hard limit, but limited by your device storage space. Each book file is stored locally on your device.

### Can I organize books into folders or collections?
Currently, books are displayed in a single library view. You can use search and sorting to organize them. Folder/collection support may be added in future versions.

### How do I report bugs or suggest features?
Since this is an open-source project, you can:
- Report bugs through the project repository
- Submit feature requests through development channels
- Contact the development team

---

**Still have questions?** Check the User Manual or Getting Started guide for more detailed information.
