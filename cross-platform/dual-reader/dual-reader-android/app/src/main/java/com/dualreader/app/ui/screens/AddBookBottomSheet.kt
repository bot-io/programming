package com.dualreader.app.ui.screens

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch

/**
 * Curated list of free legal ebook sources.
 */
data class FreeBookSource(
    val name: String,
    val url: String,
    val description: String,
    val icon: androidx.compose.ui.graphics.vector.ImageVector,
)

val FREE_BOOK_SOURCES = listOf(
    FreeBookSource(
        name = "Project Gutenberg",
        url = "https://www.gutenberg.org/ebooks/search/?sort_order=downloads&format=epub",
        description = "70,000+ free public domain eBooks",
        icon = Icons.Default.LibraryBooks,
    ),
    FreeBookSource(
        name = "Standard Ebooks",
        url = "https://standardebooks.org/ebooks",
        description = "Carefully formatted, high-quality classics",
        icon = Icons.Default.Book,
    ),
    FreeBookSource(
        name = "Internet Archive",
        url = "https://archive.org/details/books?and%5B%5D=mediatype%3A%22texts%22&sort=-downloads",
        description = "Millions of free books, movies, software, music",
        icon = Icons.Default.Public,
    ),
    FreeBookSource(
        name = "Open Library",
        url = "https://openlibrary.org/subjects/accessible_book?sort=readinglog",
        description = "An open, editable library catalog",
        icon = Icons.Default.LocalLibrary,
    ),
    FreeBookSource(
        name = "ManyBooks",
        url = "https://manybooks.net/categories",
        description = "Free and discounted bestsellers",
        icon = Icons.Default.Book,
    ),
    FreeBookSource(
        name = "Feedbooks",
        url = "https://www.feedbooks.com/publicdomain",
        description = "Public domain and original titles",
        icon = Icons.Default.RssFeed,
    ),
)

/**
 * Bottom sheet shown when user taps the "Add Book" FAB.
 * Offers file import + curated free ebook sources.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddBookBottomSheet(
    onDismiss: () -> Unit,
    onImportFromFile: () -> Unit,
) {
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
    ) {
        Column(modifier = Modifier.padding(bottom = 24.dp)) {
            Text(
                text = "Add a Book",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(horizontal = 24.dp, vertical = 8.dp),
            )

            // Option 1: Import from file
            ListItem(
                headlineContent = { Text("Import from file") },
                supportingContent = { Text("Choose an EPUB from your device") },
                leadingContent = {
                    Icon(Icons.Default.UploadFile, contentDescription = null)
                },
                modifier = Modifier.clickable {
                    scope.launch { sheetState.hide() }
                    onDismiss()
                    onImportFromFile()
                },
            )

            HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))

            Text(
                text = "Browse Free eBooks",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(horizontal = 24.dp, vertical = 4.dp),
            )

            Text(
                text = "These sites offer free legal EPUB downloads. Tap to open in your browser, then download and import the file.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 24.dp, vertical = 4.dp),
            )

            // Free ebook sources
            LazyColumn {
                items(FREE_BOOK_SOURCES) { source ->
                    ListItem(
                        headlineContent = { Text(source.name) },
                        supportingContent = { Text(source.description) },
                        leadingContent = { Icon(source.icon, contentDescription = null) },
                        trailingContent = {
                            Icon(Icons.Default.OpenInBrowser, contentDescription = "Open")
                        },
                        modifier = Modifier.clickable {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(source.url))
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            context.startActivity(intent)
                        },
                    )
                }

                // Google search option
                item {
                    ListItem(
                        headlineContent = { Text("Search Google") },
                        supportingContent = { Text("Search \"download epub books\"") },
                        leadingContent = { Icon(Icons.Default.Search, contentDescription = null) },
                        trailingContent = {
                            Icon(Icons.Default.OpenInBrowser, contentDescription = "Open")
                        },
                        modifier = Modifier.clickable {
                            val intent = Intent(
                                Intent.ACTION_VIEW,
                                Uri.parse("https://www.google.com/search?q=download+epub+books")
                            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            context.startActivity(intent)
                        },
                    )
                }
            }
        }
    }
}
