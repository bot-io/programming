import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { formatBatchPages, parseBatchResponse } from '../src/batch-utils.js';

// ─── formatBatchPages ────────────────────────────────────────────────────────

describe('formatBatchPages', () => {
  it('uses each page index in the [Page N] marker', () => {
    const pages = [
      { index: 5, text: 'alpha' },
      { index: 6, text: 'beta' },
      { index: 7, text: 'gamma' },
    ];
    const result = formatBatchPages(pages);
    assert.match(result, /\[Page 5\]/);
    assert.match(result, /\[Page 6\]/);
    assert.match(result, /\[Page 7\]/);
  });

  it('places page text after its marker on the next line', () => {
    const pages = [{ index: 1, text: 'hello world' }];
    const result = formatBatchPages(pages);
    assert.equal(result, '[Page 1]\nhello world');
  });

  it('separates pages with double newlines', () => {
    const pages = [
      { index: 1, text: 'first' },
      { index: 2, text: 'second' },
    ];
    const result = formatBatchPages(pages);
    assert.equal(result, '[Page 1]\nfirst\n\n[Page 2]\nsecond');
  });

  it('preserves large indices in markers', () => {
    const pages = [{ index: 999, text: 'big' }];
    const result = formatBatchPages(pages);
    assert.equal(result, '[Page 999]\nbig');
  });

  it('handles non-contiguous indices (e.g. 5, 6, 7)', () => {
    const pages = [
      { index: 5, text: 'a' },
      { index: 6, text: 'b' },
      { index: 7, text: 'c' },
    ];
    const result = formatBatchPages(pages);
    assert.equal(result, '[Page 5]\na\n\n[Page 6]\nb\n\n[Page 7]\nc');
  });

  it('handles a single page', () => {
    const result = formatBatchPages([{ index: 1, text: 'only page' }]);
    assert.equal(result, '[Page 1]\nonly page');
  });
});

// ─── parseBatchResponse ──────────────────────────────────────────────────────

describe('parseBatchResponse', () => {
  it('returns original indices when markers are present', () => {
    const pages = [
      { index: 5, text: 'original five' },
      { index: 6, text: 'original six' },
      { index: 7, text: 'original seven' },
    ];
    const response = '[Page 5]\nTranslated five\n\n[Page 6]\nTranslated six\n\n[Page 7]\nTranslated seven';
    const result = parseBatchResponse(response, pages);

    assert.equal(result.length, 3);
    const indices = result.map(r => r.index);
    assert.deepEqual(indices, [5, 6, 7]);
    assert.equal(result.find(r => r.index === 5).translated_text, 'Translated five');
    assert.equal(result.find(r => r.index === 6).translated_text, 'Translated six');
    assert.equal(result.find(r => r.index === 7).translated_text, 'Translated seven');
  });

  it('handles single page with marker preserving index', () => {
    const pages = [{ index: 3, text: 'original' }];
    const response = '[Page 3]\nTranslated text here';
    const result = parseBatchResponse(response, pages);

    assert.equal(result.length, 1);
    assert.equal(result[0].index, 3);
    assert.equal(result[0].translated_text, 'Translated text here');
  });

  it('handles single page without marker (last resort fallback)', () => {
    const pages = [{ index: 42, text: 'original' }];
    const response = 'Just some translated text without markers';
    const result = parseBatchResponse(response, pages);

    assert.equal(result.length, 1);
    assert.equal(result[0].index, 42);
    assert.equal(result[0].translated_text, 'Just some translated text without markers');
  });

  it('fallback splitting preserves original indices', () => {
    // Response without [Page N] markers but correct number of double-newline chunks
    const pages = [
      { index: 10, text: 'original ten' },
      { index: 20, text: 'original twenty' },
    ];
    const response = 'Translated ten\n\nTranslated twenty';
    const result = parseBatchResponse(response, pages);

    assert.equal(result.length, 2);
    assert.equal(result[0].index, 10);
    assert.equal(result[0].translated_text, 'Translated ten');
    assert.equal(result[1].index, 20);
    assert.equal(result[1].translated_text, 'Translated twenty');
  });

  it('fallback strips stray markers before splitting', () => {
    const pages = [
      { index: 1, text: 'a' },
      { index: 2, text: 'b' },
    ];
    // One marker present but not all → fallback path
    const response = '[Page 1]\nTranslated one\n\nTranslated two';
    const result = parseBatchResponse(response, pages);

    assert.equal(result.length, 2);
    assert.equal(result[0].index, 1);
    assert.equal(result[1].index, 2);
  });

  it('preserves non-contiguous indices (5, 6, 7) in parsed output', () => {
    const pages = [
      { index: 5, text: 'a' },
      { index: 6, text: 'b' },
      { index: 7, text: 'c' },
    ];
    const response = '[Page 5]\nAlpha\n\n[Page 6]\nBeta\n\n[Page 7]\nGamma';
    const result = parseBatchResponse(response, pages);

    assert.equal(result.length, 3);
    const indices = result.map(r => r.index);
    assert.ok(indices.includes(5));
    assert.ok(indices.includes(6));
    assert.ok(indices.includes(7));
  });

  it('handles large indices (999, 1000)', () => {
    const pages = [
      { index: 999, text: 'big one' },
      { index: 1000, text: 'big two' },
    ];
    const response = '[Page 999]\nTranslated 999\n\n[Page 1000]\nTranslated 1000';
    const result = parseBatchResponse(response, pages);

    assert.equal(result.length, 2);
    assert.equal(result.find(r => r.index === 999).translated_text, 'Translated 999');
    assert.equal(result.find(r => r.index === 1000).translated_text, 'Translated 1000');
  });

  it('ignores markers for indices not in the original pages', () => {
    const pages = [{ index: 1, text: 'only this' }];
    // Response includes extra page markers that don't belong
    const response = '[Page 1]\nThe right one\n\n[Page 99]\nShould be ignored';
    const result = parseBatchResponse(response, pages);

    // Should NOT match because found.size(1) != expectedCount(2) due to filtering,
    // but pages.length is 1, and found.size is 1 which equals expectedCount
    assert.equal(result.length, 1);
    assert.equal(result[0].index, 1);
    assert.equal(result[0].translated_text, 'The right one');
  });

  it('returns empty array when parsing completely fails for multi-page', () => {
    const pages = [
      { index: 1, text: 'a' },
      { index: 2, text: 'b' },
    ];
    const response = 'One big blob of text without any structure at all';
    const result = parseBatchResponse(response, pages);

    // Only 1 chunk but expected 2 → returns []
    assert.equal(result.length, 0);
  });

  it('trims whitespace from translated content', () => {
    const pages = [
      { index: 1, text: 'a' },
      { index: 2, text: 'b' },
    ];
    const response = '[Page 1]\n  Hello  \n\n[Page 2]\n  World  ';
    const result = parseBatchResponse(response, pages);

    assert.equal(result.find(r => r.index === 1).translated_text, 'Hello');
    assert.equal(result.find(r => r.index === 2).translated_text, 'World');
  });
});
