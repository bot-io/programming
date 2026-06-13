package com.dualreader.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.ImportContacts
import androidx.compose.material.icons.filled.Label
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.AssistChip
import androidx.compose.material3.AssistChipDefaults
import androidx.compose.material3.Button
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.BookCollection
import com.dualreader.app.domain.entities.PaginationStatus
import com.dualreader.app.domain.entities.SortOrder

// ──────────────────────────────────────────────────────────────────────────────
// Main Screen
// ──────────────────────────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LibraryScreen(
    uiState: LibraryUiState,
    onBookClick: (bookId: String) -> Unit,
    onImportClick: () -> Unit,
    onSettingsClick: () -> Unit,
    onRetryPagination: (book: Book) -> Unit,
    onDeleteBook: (bookId: String) -> Unit,
    onExportBookmarks: ((bookId: String) -> Unit)? = null,
    allTags: List<String> = emptyList(),
    selectedTag: String? = null,
    onTagSelected: (String?) -> Unit = {},
    sortOrder: SortOrder = SortOrder.LAST_READ,
    onSortOrderChanged: (SortOrder) -> Unit = {},
    onAddTagToBook: ((bookId: String, tag: String) -> Unit)? = null,
    onRemoveTagFromBook: ((bookId: String, tag: String) -> Unit)? = null,
    onGetTagsForBook: (suspend (String) -> List<String>)? = null,
    collections: List<BookCollection> = emptyList(),
    onCreateCollection: ((String) -> Unit)? = null,
    onDeleteCollection: ((Long) -> Unit)? = null,
    onAddBookToCollection: ((Long, String) -> Unit)? = null,
    onRemoveBookFromCollection: ((Long, String) -> Unit)? = null,
    modifier: Modifier = Modifier,
) {
    var showSortMenu by remember { mutableStateOf(false) }
    var showAddTagDialog by remember { mutableStateOf<String?>(null) }
    var showAddToCollectionDialog by remember { mutableStateOf<String?>(null) }
    var showCreateCollectionDialog by remember { mutableStateOf(false) }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            TopAppBar(
                title = { Text("Dual Reader") },
                actions = {
                    // Sort button
                    Box {
                        IconButton(onClick = { showSortMenu = true }) {
                            Icon(
                                imageVector = Icons.Default.ArrowDropDown,
                                contentDescription = "Sort",
                            )
                        }
                        DropdownMenu(
                            expanded = showSortMenu,
                            onDismissRequest = { showSortMenu = false },
                        ) {
                            SortOrder.entries.forEach { order ->
                                DropdownMenuItem(
                                    text = {
                                        Row(verticalAlignment = Alignment.CenterVertically) {
                                            Text(sortOrderLabel(order))
                                            if (order == sortOrder) {
                                                Spacer(modifier = Modifier.width(8.dp))
                                                Icon(
                                                    Icons.Default.Check,
                                                    contentDescription = null,
                                                    modifier = Modifier.size(16.dp),
                                                )
                                            }
                                        }
                                    },
                                    onClick = {
                                        onSortOrderChanged(order)
                                        showSortMenu = false
                                    },
                                )
                            }
                        }
                    }
                    IconButton(onClick = onSettingsClick) {
                        Icon(
                            imageVector = Icons.Default.Settings,
                            contentDescription = "Settings",
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                ),
            )
        },
        floatingActionButton = {
            if (uiState !is LibraryUiState.Loading) {
                FloatingActionButton(
                    onClick = onImportClick,
                    containerColor = MaterialTheme.colorScheme.primaryContainer,
                    contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
                ) {
                    Icon(
                        imageVector = Icons.Default.Add,
                        contentDescription = "Import EPUB",
                    )
                }
            }
        },
    ) { innerPadding ->
        Column(modifier = Modifier.padding(innerPadding)) {
            // Tag filter chips
            if (allTags.isNotEmpty()) {
                TagFilterRow(
                    tags = allTags,
                    selectedTag = selectedTag,
                    onTagSelected = onTagSelected,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 12.dp, vertical = 4.dp),
                )
            }

            // Main content
            when (uiState) {
                is LibraryUiState.Loading -> LoadingState(modifier = Modifier.fillMaxSize())
                is LibraryUiState.Empty -> EmptyState(
                    onImportClick = onImportClick,
                    modifier = Modifier.fillMaxSize(),
                )
                is LibraryUiState.Success -> {
                    if (uiState.books.isEmpty() && uiState.selectedTag != null) {
                        // Tag selected but no matching books
                        Box(
                            modifier = Modifier.fillMaxSize(),
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(
                                text = "No books with tag \"${uiState.selectedTag}\"",
                                style = MaterialTheme.typography.bodyLarge,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    } else {
                        BookGrid(
                            books = uiState.books,
                            bookTags = uiState.bookTags,
                            onBookClick = onBookClick,
                            onRetryPagination = onRetryPagination,
                            onDeleteBook = onDeleteBook,
                            onExportBookmarks = onExportBookmarks,
                            onAddTagToBook = onAddTagToBook,
                            onRemoveTagFromBook = onRemoveTagFromBook,
                            onAddToCollection = onAddBookToCollection,
                            collections = collections,
                            modifier = Modifier.fillMaxSize(),
                        )
                    }
                }
                is LibraryUiState.Error -> ErrorState(
                    message = uiState.message,
                    onRetry = onImportClick,
                    modifier = Modifier.fillMaxSize(),
                )
            }
        }
    }

    // Add Tag Dialog
    showAddTagDialog?.let { bookId ->
        AddTagDialog(
            existingTags = allTags,
            onDismiss = { showAddTagDialog = null },
            onAdd = { tag ->
                onAddTagToBook?.invoke(bookId, tag)
                showAddTagDialog = null
            },
        )
    }

    // Add to Collection Dialog
    showAddToCollectionDialog?.let { bookId ->
        AddToCollectionDialog(
            collections = collections,
            onCreateNew = {
                showAddToCollectionDialog = null
                showCreateCollectionDialog = true
            },
            onSelect = { collectionId ->
                onAddBookToCollection?.invoke(collectionId, bookId)
                showAddToCollectionDialog = null
            },
            onDismiss = { showAddToCollectionDialog = null },
        )
    }

    // Create Collection Dialog
    if (showCreateCollectionDialog) {
        CreateCollectionDialog(
            onDismiss = { showCreateCollectionDialog = false },
            onCreate = { name ->
                onCreateCollection?.invoke(name)
                showCreateCollectionDialog = false
            },
        )
    }
}

private fun sortOrderLabel(order: SortOrder): String = when (order) {
    SortOrder.LAST_READ -> "Last Read"
    SortOrder.TITLE -> "Title"
    SortOrder.AUTHOR -> "Author"
    SortOrder.DATE_ADDED -> "Date Added"
    SortOrder.PROGRESS -> "Progress"
}

// ──────────────────────────────────────────────────────────────────────────────
// Tag Filter Row
// ──────────────────────────────────────────────────────────────────────────────

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun TagFilterRow(
    tags: List<String>,
    selectedTag: String?,
    onTagSelected: (String?) -> Unit,
    modifier: Modifier = Modifier,
) {
    FlowRow(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        // "All" chip
        FilterChip(
            selected = selectedTag == null,
            onClick = { onTagSelected(null) },
            label = { Text("All") },
            leadingIcon = if (selectedTag == null) {
                { Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(16.dp)) }
            } else null,
        )
        tags.forEach { tag ->
            FilterChip(
                selected = selectedTag == tag,
                onClick = { onTagSelected(if (selectedTag == tag) null else tag) },
                label = { Text(tag) },
            )
        }
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// Loading
// ──────────────────────────────────────────────────────────────────────────────

@Composable
private fun LoadingState(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier,
        contentAlignment = Alignment.Center,
    ) {
        CircularProgressIndicator()
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// Empty
// ──────────────────────────────────────────────────────────────────────────────

@Composable
private fun EmptyState(
    onImportClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier,
        contentAlignment = Alignment.Center,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Icon(
                imageVector = Icons.Default.ImportContacts,
                contentDescription = null,
                modifier = Modifier.size(72.dp),
                tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
            )
            Text(
                text = "No books yet",
                style = MaterialTheme.typography.headlineSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                text = "Import an EPUB to start reading",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f),
            )
            OutlinedButton(onClick = onImportClick) {
                Icon(
                    imageVector = Icons.Default.Add,
                    contentDescription = null,
                    modifier = Modifier.size(18.dp),
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text("Import EPUB")
            }
        }
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// Error
// ──────────────────────────────────────────────────────────────────────────────

@Composable
private fun ErrorState(
    message: String,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier,
        contentAlignment = Alignment.Center,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Icon(
                imageVector = Icons.Default.Error,
                contentDescription = null,
                modifier = Modifier.size(64.dp),
                tint = MaterialTheme.colorScheme.error,
            )
            Text(
                text = message,
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.error,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = 32.dp),
            )
            OutlinedButton(onClick = onRetry) {
                Icon(
                    imageVector = Icons.Default.Refresh,
                    contentDescription = null,
                    modifier = Modifier.size(18.dp),
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text("Retry")
            }
        }
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// Book Grid
// ──────────────────────────────────────────────────────────────────────────────

@Composable
private fun BookGrid(
    books: List<Book>,
    bookTags: Map<String, List<String>> = emptyMap(),
    onBookClick: (bookId: String) -> Unit,
    onRetryPagination: (book: Book) -> Unit,
    onDeleteBook: (bookId: String) -> Unit,
    onExportBookmarks: ((bookId: String) -> Unit)? = null,
    onAddTagToBook: ((bookId: String, tag: String) -> Unit)? = null,
    onRemoveTagFromBook: ((bookId: String, tag: String) -> Unit)? = null,
    onAddToCollection: ((collectionId: Long, bookId: String) -> Unit)? = null,
    collections: List<BookCollection> = emptyList(),
    modifier: Modifier = Modifier,
) {
    var bookToDelete by remember { mutableStateOf<Book?>(null) }

    // Delete confirmation dialog
    if (bookToDelete != null) {
        val book = bookToDelete!!
        AlertDialog(
            onDismissRequest = { bookToDelete = null },
            title = { Text("Delete book?") },
            text = { Text("\"${book.title}\" and all its data (pages, bookmarks, translations) will be permanently deleted.") },
            confirmButton = {
                TextButton(onClick = {
                    onDeleteBook(book.id)
                    bookToDelete = null
                }) { Text("Delete") }
            },
            dismissButton = {
                TextButton(onClick = { bookToDelete = null }) { Text("Cancel") }
            },
        )
    }

    LazyVerticalGrid(
        columns = GridCells.Fixed(2),
        modifier = modifier,
        contentPadding = PaddingValues(
            start = 12.dp,
            end = 12.dp,
            top = 4.dp,
            bottom = 88.dp,
        ),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        items(
            items = books,
            key = { it.id },
        ) { book ->
            BookCard(
                book = book,
                tags = bookTags[book.id] ?: emptyList(),
                onClick = { onBookClick(book.id) },
                onRetryPagination = { onRetryPagination(book) },
                onDeleteRequest = { bookToDelete = book },
                onExportBookmarks = onExportBookmarks?.let { cb -> { cb(book.id) } },
                onAddTag = onAddTagToBook?.let { cb -> { tag -> cb(book.id, tag) } },
                onRemoveTag = onRemoveTagFromBook?.let { cb -> { tag -> cb(book.id, tag) } },
                onAddToCollection = onAddToCollection?.let { cb -> { collectionId -> cb(collectionId, book.id) } },
                collections = collections,
            )
        }
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// Book Card
// ──────────────────────────────────────────────────────────────────────────────

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun BookCard(
    book: Book,
    tags: List<String> = emptyList(),
    onClick: () -> Unit,
    onRetryPagination: () -> Unit,
    onDeleteRequest: () -> Unit,
    onExportBookmarks: (() -> Unit)? = null,
    onAddTag: ((String) -> Unit)? = null,
    onRemoveTag: ((String) -> Unit)? = null,
    onAddToCollection: ((Long) -> Unit)? = null,
    collections: List<BookCollection> = emptyList(),
    modifier: Modifier = Modifier,
) {
    var showMenu by remember { mutableStateOf(false) }
    var showTagManager by remember { mutableStateOf(false) }

    ElevatedCard(
        modifier = modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.medium,
        elevation = CardDefaults.elevatedCardElevation(defaultElevation = 2.dp),
    ) {
        Column {
            // ── Cover image or placeholder ──
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .aspectRatio(3f / 4f)
                    .clip(MaterialTheme.shapes.medium)
                    .clickable(onClick = onClick),
                contentAlignment = Alignment.Center,
            ) {
                if (book.coverPath != null) {
                    AsyncImage(
                        model = book.coverPath,
                        contentDescription = "Cover of ${book.title}",
                        modifier = Modifier.fillMaxSize(),
                        contentScale = ContentScale.Crop,
                    )
                } else {
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .background(MaterialTheme.colorScheme.primaryContainer),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            imageVector = Icons.Default.MenuBook,
                            contentDescription = null,
                            modifier = Modifier.size(48.dp),
                            tint = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.6f),
                        )
                    }
                }

                PaginationBadge(
                    status = book.paginationStatus,
                    progress = book.paginationProgress,
                    onRetry = onRetryPagination,
                    modifier = Modifier
                        .align(Alignment.TopStart)
                        .padding(6.dp),
                )

                // Overflow menu
                Box(
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(2.dp),
                ) {
                    IconButton(
                        onClick = { showMenu = true },
                        modifier = Modifier.size(32.dp),
                    ) {
                        Icon(
                            imageVector = Icons.Default.MoreVert,
                            contentDescription = "Book options",
                            modifier = Modifier.size(20.dp),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    DropdownMenu(
                        expanded = showMenu,
                        onDismissRequest = { showMenu = false },
                    ) {
                        if (onAddTag != null) {
                            DropdownMenuItem(
                                text = { Text("Manage Tags") },
                                onClick = {
                                    showMenu = false
                                    showTagManager = true
                                },
                                leadingIcon = {
                                    Icon(Icons.Default.Label, contentDescription = null)
                                },
                            )
                        }
                        if (onAddToCollection != null && collections.isNotEmpty()) {
                            collections.forEach { collection ->
                                DropdownMenuItem(
                                    text = { Text("Add to: ${collection.name}") },
                                    onClick = {
                                        showMenu = false
                                        onAddToCollection(collection.id)
                                    },
                                    leadingIcon = {
                                        Icon(Icons.Default.Bookmark, contentDescription = null)
                                    },
                                )
                            }
                        }
                        if (onExportBookmarks != null) {
                            DropdownMenuItem(
                                text = { Text("Export Bookmarks") },
                                onClick = {
                                    showMenu = false
                                    onExportBookmarks()
                                },
                                leadingIcon = {
                                    Icon(Icons.Default.Share, contentDescription = null)
                                },
                            )
                        }
                        DropdownMenuItem(
                            text = { Text("Delete") },
                            onClick = {
                                showMenu = false
                                onDeleteRequest()
                            },
                            leadingIcon = {
                                Icon(
                                    Icons.Default.Delete,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.error,
                                )
                            },
                        )
                    }
                }
            }

            // ── Text info ──
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 8.dp, vertical = 6.dp),
            ) {
                Text(
                    text = book.title,
                    style = MaterialTheme.typography.titleSmall,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )

                if (!book.author.isNullOrBlank()) {
                    Text(
                        text = book.author,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }

                Spacer(modifier = Modifier.height(4.dp))

                // Tags
                if (tags.isNotEmpty()) {
                    FlowRow(
                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                        verticalArrangement = Arrangement.spacedBy(2.dp),
                    ) {
                        tags.take(3).forEach { tag ->
                            Text(
                                text = tag,
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.primary,
                                modifier = Modifier
                                    .background(
                                        MaterialTheme.colorScheme.primaryContainer,
                                        MaterialTheme.shapes.extraSmall,
                                    )
                                    .padding(horizontal = 4.dp, vertical = 1.dp),
                            )
                        }
                        if (tags.size > 3) {
                            Text(
                                text = "+${tags.size - 3}",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                    Spacer(modifier = Modifier.height(4.dp))
                }

                // Progress bar
                if (book.totalPages > 0 && book.progressPercent > 0f) {
                    LinearProgressIndicator(
                        progress = { book.progressPercent },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(3.dp)
                            .clip(MaterialTheme.shapes.extraSmall),
                        color = MaterialTheme.colorScheme.primary,
                        trackColor = MaterialTheme.colorScheme.surfaceVariant,
                    )
                    Text(
                        text = "${book.progressLabel} · ${book.currentPage}/${book.totalPages}",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }

    // Tag management bottom sheet
    if (showTagManager) {
        TagManagerSheet(
            bookId = book.id,
            currentTags = tags,
            onAddTag = onAddTag,
            onRemoveTag = onRemoveTag,
            onDismiss = { showTagManager = false },
        )
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// Tag Manager Bottom Sheet
// ──────────────────────────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun TagManagerSheet(
    bookId: String,
    currentTags: List<String>,
    onAddTag: ((String) -> Unit)? = null,
    onRemoveTag: ((String) -> Unit)? = null,
    onDismiss: () -> Unit,
) {
    var newTagText by remember { mutableStateOf("") }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
        ) {
            Text(
                text = "Manage Tags",
                style = MaterialTheme.typography.titleMedium,
            )
            Spacer(modifier = Modifier.height(12.dp))

            // Current tags
            if (currentTags.isNotEmpty()) {
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    currentTags.forEach { tag ->
                        AssistChip(
                            onClick = {
                                onRemoveTag?.invoke(tag)
                            },
                            label = { Text(tag) },
                            trailingIcon = {
                                Icon(
                                    Icons.Default.Close,
                                    contentDescription = "Remove tag",
                                    modifier = Modifier.size(AssistChipDefaults.IconSize),
                                )
                            },
                        )
                    }
                }
                Spacer(modifier = Modifier.height(12.dp))
            }

            // Add tag input
            if (onAddTag != null) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    OutlinedTextField(
                        value = newTagText,
                        onValueChange = { newTagText = it },
                        label = { Text("New tag") },
                        singleLine = true,
                        modifier = Modifier.weight(1f),
                    )
                    IconButton(
                        onClick = {
                            if (newTagText.isNotBlank()) {
                                onAddTag(newTagText.trim())
                                newTagText = ""
                            }
                        },
                        enabled = newTagText.isNotBlank(),
                    ) {
                        Icon(Icons.Default.Add, contentDescription = "Add tag")
                    }
                }
            }
            Spacer(modifier = Modifier.height(32.dp))
        }
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// Add Tag Dialog
// ──────────────────────────────────────────────────────────────────────────────

@Composable
private fun AddTagDialog(
    existingTags: List<String>,
    onDismiss: () -> Unit,
    onAdd: (String) -> Unit,
) {
    var tagText by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Add Tag") },
        text = {
            Column {
                OutlinedTextField(
                    value = tagText,
                    onValueChange = { tagText = it },
                    label = { Text("Tag name") },
                    singleLine = true,
                )
                if (existingTags.isNotEmpty()) {
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "Existing tags:",
                        style = MaterialTheme.typography.labelMedium,
                    )
                    existingTags.take(5).forEach { tag ->
                        TextButton(onClick = { onAdd(tag) }) {
                            Text(tag, style = MaterialTheme.typography.bodySmall)
                        }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = { if (tagText.isNotBlank()) onAdd(tagText.trim()) },
                enabled = tagText.isNotBlank(),
            ) { Text("Add") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        },
    )
}

// ──────────────────────────────────────────────────────────────────────────────
// Add to Collection Dialog
// ──────────────────────────────────────────────────────────────────────────────

@Composable
private fun AddToCollectionDialog(
    collections: List<BookCollection>,
    onCreateNew: () -> Unit,
    onSelect: (Long) -> Unit,
    onDismiss: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Add to Collection") },
        text = {
            Column {
                if (collections.isEmpty()) {
                    Text("No collections yet. Create one first.")
                } else {
                    collections.forEach { collection ->
                        TextButton(onClick = { onSelect(collection.id) }) {
                            Text(
                                "${collection.name} (${collection.bookIds.size} books)",
                                style = MaterialTheme.typography.bodyMedium,
                            )
                        }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onCreateNew) { Text("New Collection") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        },
    )
}

// ──────────────────────────────────────────────────────────────────────────────
// Create Collection Dialog
// ──────────────────────────────────────────────────────────────────────────────

@Composable
private fun CreateCollectionDialog(
    onDismiss: () -> Unit,
    onCreate: (String) -> Unit,
) {
    var name by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Create Collection") },
        text = {
            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                label = { Text("Collection name") },
                singleLine = true,
            )
        },
        confirmButton = {
            TextButton(
                onClick = { if (name.isNotBlank()) onCreate(name.trim()) },
                enabled = name.isNotBlank(),
            ) { Text("Create") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        },
    )
}

// ──────────────────────────────────────────────────────────────────────────────
// Pagination Badge
// ──────────────────────────────────────────────────────────────────────────────

@Composable
private fun PaginationBadge(
    status: PaginationStatus,
    progress: Float,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier,
) {
    when (status) {
        PaginationStatus.COMPLETED -> {
            // No badge needed — book is ready
        }
        PaginationStatus.IN_PROGRESS -> {
            AssistChip(
                onClick = {},
                label = {
                    Text(
                        text = "${(progress * 100).toInt()}%",
                        style = MaterialTheme.typography.labelSmall,
                    )
                },
                leadingIcon = {
                    CircularProgressIndicator(
                        modifier = Modifier.size(AssistChipDefaults.IconSize),
                        strokeWidth = 1.5.dp,
                    )
                },
                modifier = modifier.height(AssistChipDefaults.Height),
                colors = AssistChipDefaults.assistChipColors(
                    containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.85f),
                ),
            )
        }
        PaginationStatus.FAILED -> {
            AssistChip(
                onClick = onRetry,
                label = {
                    Text(
                        text = "Retry",
                        style = MaterialTheme.typography.labelSmall,
                    )
                },
                leadingIcon = {
                    Icon(
                        imageVector = Icons.Default.Refresh,
                        contentDescription = null,
                        modifier = Modifier.size(AssistChipDefaults.IconSize),
                    )
                },
                modifier = modifier.height(AssistChipDefaults.Height),
                colors = AssistChipDefaults.assistChipColors(
                    containerColor = MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.9f),
                    labelColor = MaterialTheme.colorScheme.onErrorContainer,
                    leadingIconContentColor = MaterialTheme.colorScheme.onErrorContainer,
                ),
            )
        }
        PaginationStatus.NOT_STARTED -> {
            AssistChip(
                onClick = {},
                label = {
                    Text(
                        text = "New",
                        style = MaterialTheme.typography.labelSmall,
                    )
                },
                modifier = modifier.height(AssistChipDefaults.Height),
                colors = AssistChipDefaults.assistChipColors(
                    containerColor = MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.85f),
                    labelColor = MaterialTheme.colorScheme.onSecondaryContainer,
                ),
            )
        }
    }
}
