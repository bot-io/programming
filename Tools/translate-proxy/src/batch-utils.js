/**
 * Batch page formatting and parsing utilities.
 * Shared between the worker and tests.
 */

/**
 * Format pages into a structured prompt string with [Page N] markers.
 * @param {Array<{index: number, text: string}>} pages
 * @returns {string}
 */
export function formatBatchPages(pages) {
  return pages.map((p) => `[Page ${p.index}]\n${p.text}`).join('\n\n');
}

/**
 * Parse the model's structured response back into individual translations.
 * @param {string} text - The raw model response
 * @param {Array<{index: number, text: string}>} pages - Original page descriptors
 * @returns {Array<{index: number, translated_text: string}>}
 */
export function parseBatchResponse(text, pages) {
  const expectedCount = pages.length;
  const results = [];

  const validIndices = new Set(pages.map(p => p.index));

  const pageRegex = /\[Page\s+(\d+)\]\s*\n([\s\S]*?)(?=\n\[Page\s+\d+\]|$)/gi;
  let match;
  const found = new Map();

  while ((match = pageRegex.exec(text)) !== null) {
    const pageNum = parseInt(match[1], 10);
    const content = match[2].trim();
    if (validIndices.has(pageNum)) {
      found.set(pageNum, content);
    }
  }

  if (found.size === expectedCount) {
    for (const [idx, content] of found) {
      results.push({ index: idx, translated_text: content });
    }
    return results;
  }

  // Fallback: split by double newlines, strip markers
  const cleanText = text.replace(/\[Page\s+\d+\]\s*\n?/gi, '').trim();
  const chunks = cleanText.split(/\n{2,}/).filter(c => c.trim());

  if (chunks.length === expectedCount) {
    return pages.map((p, i) => ({ index: p.index, translated_text: chunks[i].trim() }));
  }

  if (expectedCount === 1) {
    return [{ index: pages[0].index, translated_text: cleanText }];
  }

  console.warn(`Batch parse failed: expected ${expectedCount} pages, found ${found.size} markers, ${chunks.length} chunks`);
  return [];
}
