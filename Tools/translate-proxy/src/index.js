/**
 * Dual Reader Translation Proxy — Cloudflare Worker
 *
 * Multi-provider translation with automatic fallback:
 *   Primary: Google Gemini 2.5 Flash (free tier, 250 RPD)
 *   Fallback: Z.AI GLM-4.7-Flash (free, unlimited)
 *
 * API keys live server-side — never exposed in the APK.
 * Rate limits enforced per-IP using Cloudflare Cache API.
 */

import { formatBatchPages, parseBatchResponse } from './batch-utils.js';

// ─── Config ──────────────────────────────────────────────────────────────────

const CONFIG = {
  // Rate limiting (per IP)
  maxTextLength: 10000,         // chars per single-page request
  maxBatchChars: 10000,         // total chars per batch request (sum of all pages)
  maxBatchPages: 3,             // max pages per batch call (reduced for timeout safety)
  dailyLimitPerIp: 500,        // requests per IP per day
  cooldownMs: 3000,            // min 3s between requests from same IP

  // Provider timeouts (CF Workers have 30s total)
  geminiTimeoutMs: 15000,
  glmTimeoutMs: 15000,

  // Provider endpoints
  geminiApiUrl: 'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent',
  gemini25ApiUrl: 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent',
  glmApiUrl: 'https://open.bigmodel.cn/api/paas/v4/chat/completions',

  // Models
  geminiModel: 'gemini-3.5-flash',
  gemini25Model: 'gemini-2.5-flash',
  glmModel: 'glm-4.7-flash',

  // CORS
  allowedOrigins: ['*'],
};

// ─── Main Handler ────────────────────────────────────────────────────────────

export default {
  async fetch(request, env) {
    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return corsResponse(new Response(null, { status: 204 }));
    }

    const url = new URL(request.url);
    const clientIp = request.headers.get('CF-Connecting-IP') || 'unknown';

    // POST /translate/batch — multi-page batch translation
    if (request.method === 'POST' && url.pathname === '/translate/batch') {
      return corsResponse(await handleBatchTranslate(request, clientIp, env));
    }

    // POST /translate — single page translation
    if (request.method !== 'POST' || !url.pathname.startsWith('/translate')) {
      return corsResponse(jsonResponse(404, { error: 'Not found. Use POST /translate or POST /translate/batch' }));
    }

    try {
      // 1. Rate limit check
      const rateLimitResult = await checkRateLimit(request, clientIp, env);
      if (rateLimitResult) return corsResponse(rateLimitResult);

      // 2. Parse and validate request body
      let body;
      try {
        body = await request.json();
      } catch {
        return corsResponse(jsonResponse(400, { error: 'Invalid JSON body' }));
      }

      const { text, source_lang, target_lang } = body;

      if (!text || typeof text !== 'string') {
        return corsResponse(jsonResponse(400, { error: 'Missing "text" field' }));
      }
      if (!target_lang || typeof target_lang !== 'string') {
        return corsResponse(jsonResponse(400, { error: 'Missing "target_lang" field' }));
      }
      if (text.length > CONFIG.maxTextLength) {
        return corsResponse(jsonResponse(413, {
          error: `Text too long (${text.length} chars). Max ${CONFIG.maxTextLength}.`
        }));
      }

      const systemPrompt = buildTranslationPrompt(source_lang || 'auto', target_lang);

      // 3. Try Gemini first, fall back to GLM
      let translatedText = null;
      let usedModel = null;
      let geminiError = null;

      // ── Attempt 1: Gemini 3.5 Flash (free, best quality) ──────────────
      const geminiKey = env.GEMINI_API_KEY;
      if (geminiKey) {
        // Try Gemini 3.5 Flash with one retry on 503 (high demand is temporary)
        for (let attempt = 0; attempt < 2 && !translatedText; attempt++) {
          try {
            const geminiResult = await callGemini(geminiKey, systemPrompt, text, CONFIG.geminiApiUrl);
            if (geminiResult) {
              translatedText = geminiResult;
              usedModel = CONFIG.geminiModel;
            }
          } catch (err) {
            geminiError = err.message || 'Unknown Gemini error';
            const is503 = geminiError.includes('503') || geminiError.includes('UNAVAILABLE');
            if (is503 && attempt === 0) {
              console.warn(`Gemini 3.5 unavailable (503), retrying in 1s...`);
              await new Promise(r => setTimeout(r, 1000));
              continue;
            }
            // If 3.5 failed after retry (or non-503 error), try 2.5 Flash
            if (!translatedText) {
              try {
                console.warn(`Gemini 3.5 failed (${geminiError}), trying Gemini 2.5 Flash...`);
                const gemini25Result = await callGemini(geminiKey, systemPrompt, text, CONFIG.gemini25ApiUrl);
                if (gemini25Result) {
                  translatedText = gemini25Result;
                  usedModel = CONFIG.gemini25Model;
                }
              } catch (err25) {
                geminiError += ` | 2.5: ${err25.message}`;
                console.warn(`Gemini 2.5 also failed: ${err25.message}`);
              }
            }
          }
        }
      } else {
        console.info('GEMINI_API_KEY not set, using GLM directly');
      }

      // ── Attempt 2: GLM-4.7-Flash (free, unlimited) ────────────────────
      if (!translatedText) {
        const glmKey = env.GLM_API_KEY;
        if (!glmKey) {
          console.error('No translation API keys configured');
          return corsResponse(jsonResponse(500, {
            error: 'No translation service configured. Set GEMINI_API_KEY or GLM_API_KEY.'
          }));
        }

        try {
          const glmResult = await callGlm(glmKey, systemPrompt, text);
          if (glmResult) {
            translatedText = glmResult;
            usedModel = CONFIG.glmModel;
          }
        } catch (err) {
          console.error(`GLM also failed: ${err.message}`);
          // Both providers failed
          const geminiMsg = geminiError ? `Gemini: ${geminiError}. ` : '';
          return corsResponse(jsonResponse(502, {
            error: `${geminiMsg}GLM: ${err.message || 'Translation failed'}`
          }));
        }
      }

      if (!translatedText) {
        return corsResponse(jsonResponse(502, { error: 'Empty translation response from all providers' }));
      }

      // 4. Record this request for rate limiting
      await recordRequest(request, clientIp, env);

      return corsResponse(jsonResponse(200, {
        translated_text: translatedText,
        model: usedModel,
        source_lang: source_lang || 'auto',
        target_lang,
      }));

    } catch (err) {
      console.error('Worker error:', err);
      const msg = err?.message || 'Internal server error';
      return corsResponse(jsonResponse(500, { error: `Worker error: ${msg}` }));
    }
  },
};

// ─── Batch Translation Handler ───────────────────────────────────────────────

async function handleBatchTranslate(request, clientIp, env) {
  // Rate limit
  const rateLimitResult = await checkRateLimit(request, clientIp, env);
  if (rateLimitResult) return rateLimitResult;

  let body;
  try {
    body = await request.json();
  } catch {
    return jsonResponse(400, { error: 'Invalid JSON body' });
  }

  const { pages, source_lang, target_lang } = body;
  if (!Array.isArray(pages) || pages.length === 0) {
    return jsonResponse(400, { error: 'Missing "pages" array' });
  }
  if (!target_lang) {
    return jsonResponse(400, { error: 'Missing "target_lang"' });
  }
  if (pages.length > CONFIG.maxBatchPages) {
    return jsonResponse(413, { error: `Too many pages (${pages.length}). Max ${CONFIG.maxBatchPages}.` });
  }

  // Validate pages
  const totalChars = pages.reduce((sum, p, i) => {
    if (!p.text || typeof p.text !== 'string') {
      throw new Error(`Page ${i} missing "text" field`);
    }
    return sum + p.text.length;
  }, 0);

  if (totalChars > CONFIG.maxBatchChars) {
    return jsonResponse(413, {
      error: `Total text too long (${totalChars} chars). Max ${CONFIG.maxBatchChars}.`
    });
  }

  const systemPrompt = buildBatchTranslationPrompt(source_lang || 'auto', target_lang, pages.length);
  const userText = formatBatchPages(pages);

  // Try providers with same fallback chain as single translate
  let translatedText = null;
  let usedModel = null;
  let geminiError = null;

  const geminiKey = env.GEMINI_API_KEY;
  if (geminiKey) {
    // Try Gemini 3.5 Flash (with thinking) — one attempt only
    try {
      const result = await callGemini(geminiKey, systemPrompt, userText, CONFIG.geminiApiUrl);
      if (result) { translatedText = result; usedModel = CONFIG.geminiModel; }
    } catch (err) {
      geminiError = err.message || 'Unknown error';
    }

    // Fallback to Gemini 2.5 Flash (no thinking, faster)
    if (!translatedText) {
      try {
        const r2 = await callGemini(geminiKey, systemPrompt, userText, CONFIG.gemini25ApiUrl);
        if (r2) { translatedText = r2; usedModel = CONFIG.gemini25Model; }
      } catch (err25) {
        geminiError += ` | 2.5: ${err25.message}`;
      }
    }
  }

  if (!translatedText) {
    const glmKey = env.GLM_API_KEY;
    if (!glmKey) {
      return jsonResponse(500, { error: 'No translation service configured.' });
    }
    try {
      const glmResult = await callGlm(glmKey, systemPrompt, userText);
      if (glmResult) { translatedText = glmResult; usedModel = CONFIG.glmModel; }
    } catch (err) {
      return jsonResponse(502, { error: `${geminiError ? 'Gemini: ' + geminiError + '. ' : ''}GLM: ${err.message}` });
    }
  }

  if (!translatedText) {
    return jsonResponse(502, { error: 'Empty response from all providers' });
  }

  // Parse the structured response into individual translations
  const parsed = parseBatchResponse(translatedText, pages);

  await recordRequest(request, clientIp, env);

  return jsonResponse(200, {
    translations: parsed,
    model: usedModel,
    source_lang: source_lang || 'auto',
    target_lang,
  });
}

/**
 * Build a prompt specifically for batch translation.
 * Instructs the model to maintain the numbered page structure.
 */
function buildBatchTranslationPrompt(sourceLang, targetLang, pageCount) {
  const langNames = {
    en: 'English', es: 'Spanish', fr: 'French', de: 'German',
    it: 'Italian', pt: 'Portuguese', ru: 'Russian', zh: 'Chinese',
    ja: 'Japanese', ko: 'Korean', ar: 'Arabic', bg: 'Bulgarian',
    nl: 'Dutch', sv: 'Swedish', pl: 'Polish', tr: 'Turkish',
    cs: 'Czech', ro: 'Romanian', el: 'Greek', da: 'Danish',
    fi: 'Finnish', no: 'Norwegian', hu: 'Hungarian', uk: 'Ukrainian',
  };

  const srcName = sourceLang === 'auto'
    ? 'the source language (auto-detect)'
    : (langNames[sourceLang] || sourceLang);
  const tgtName = langNames[targetLang] || targetLang;

  return [
    `You are a professional literary translator translating from ${srcName} to ${tgtName}.`,
    `You produce publication-quality translations that read as if originally written in ${tgtName}.`,
    ``,
    `CORE RULES:`,
    `1. Translate the MEANING and INTENT, never word-by-word. Reconstruct sentences in ${tgtName} naturally.`,
    `2. Match the author's register, tone, and voice — whether literary, colloquial, formal, or poetic.`,
    `3. Every sentence must be grammatically perfect in ${tgtName}: correct gender agreement, case, number, articles, prepositions, verb tense and aspect.`,
    `4. Idioms and culture-specific expressions must be adapted to ${tgtName} equivalents, not translated literally.`,
    `5. Maintain paragraph breaks exactly as the source.`,
    `6. Preserve ambiguity and subtext — do not explain or simplify.`,
    `7. Character names: use the standard ${tgtName} transcription/transliteration convention.`,
    `8. Maintain CONTINUITY across pages — the same name, term, or style on page 1 must be consistent on page ${pageCount}.`,
    ``,
    `IMPORTANT: You will receive ${pageCount} pages marked with [Page N] headers.`,
    `You MUST output exactly ${pageCount} translations with matching [Page N] headers.`,
    `Format your output EXACTLY like this:`,
    ``,
    `[Page 1]`,
    `(translation of page 1)`,
    ``,
    `[Page 2]`,
    `(translation of page 2)`,
    ``,
    `Do NOT add any commentary, notes, or quotation marks. Only the translations with page markers.`,
  ].join('\n');
}

// ─── Gemini Provider ─────────────────────────────────────────────────────────

async function callGemini(apiKey, systemPrompt, userText, apiUrl) {
  const url = `${apiUrl || CONFIG.geminiApiUrl}?key=${apiKey}`;

  const resp = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      systemInstruction: {
        parts: [{ text: systemPrompt }]
      },
      contents: [{
        parts: [{ text: userText }]
      }],
      generationConfig: {
        temperature: 1.0,
        maxOutputTokens: 16384,
        thinkingConfig: {
          thinkingBudget: 2048,
        },
      },
    }),
    signal: AbortSignal.timeout(CONFIG.geminiTimeoutMs),
  });

  if (resp.status === 429) {
    throw new Error('Gemini rate limited (free tier: 250 RPD)');
  }

  if (!resp.ok) {
    const errText = await resp.text().catch(() => '');
    throw new Error(`Gemini API ${resp.status}: ${errText.slice(0, 200)}`);
  }

  const data = await resp.json();

  // Extract text from Gemini response structure
  // With thinking enabled, response contains both thought and text parts.
  // We only want the non-thought (final answer) text.
  const candidates = data?.candidates;
  if (!candidates?.length) {
    throw new Error(`Gemini returned no candidates: ${JSON.stringify(data).slice(0, 300)}`);
  }

  const parts = candidates[0].content?.parts;
  if (!parts?.length) {
    const reason = candidates[0].finishReason;
    if (reason === 'SAFETY') throw new Error('Gemini blocked by safety filter');
    throw new Error(`Gemini returned empty parts: ${JSON.stringify(data).slice(0, 300)}`);
  }

  // Find the last non-thought part (the actual translation)
  // Note: Gemini 3.5 Flash uses "thoughtSignature" field on thought parts,
  // and "thought: true" on explicit thought text parts. Either way, we want
  // the part that has actual text without thought markers.
  let text = null;
  for (let i = parts.length - 1; i >= 0; i--) {
    const part = parts[i];
    if (part.text && !part.thought) {
      text = part.text.trim();
      break;
    }
  }

  if (!text) {
    throw new Error(`Gemini returned no text output: ${JSON.stringify(data).slice(0, 300)}`);
  }

  return text;
}

// ─── GLM Provider ────────────────────────────────────────────────────────────

async function callGlm(apiKey, systemPrompt, userText) {
  const resp = await fetch(CONFIG.glmApiUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: CONFIG.glmModel,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userText },
      ],
      temperature: 0.4,
      max_tokens: 8192,
    }),
    signal: AbortSignal.timeout(CONFIG.glmTimeoutMs),
  });

  if (resp.status === 429) {
    throw new Error('GLM rate limited');
  }

  if (!resp.ok) {
    const errText = await resp.text().catch(() => '');
    throw new Error(`GLM API ${resp.status}: ${errText.slice(0, 200)}`);
  }

  const data = await resp.json();
  let text = data?.choices?.[0]?.message?.content?.trim();

  // GLM-4.7-Flash may put output in reasoning_content if content is empty
  if (!text && data?.choices?.[0]?.message?.reasoning_content) {
    const reasoning = data.choices[0].message.reasoning_content;
    const lastLine = reasoning.split('\n').filter(l => l.trim()).pop() || '';
    text = lastLine.replace(/\*\*/g, '').replace(/^[-*]\s*/, '').trim();
  }

  if (!text) {
    throw new Error(`GLM returned empty response: ${JSON.stringify(data).slice(0, 300)}`);
  }

  return text;
}

// ─── Translation Prompt ──────────────────────────────────────────────────────

function buildTranslationPrompt(sourceLang, targetLang) {
  const langNames = {
    en: 'English', es: 'Spanish', fr: 'French', de: 'German',
    it: 'Italian', pt: 'Portuguese', ru: 'Russian', zh: 'Chinese',
    ja: 'Japanese', ko: 'Korean', ar: 'Arabic', bg: 'Bulgarian',
    nl: 'Dutch', sv: 'Swedish', pl: 'Polish', tr: 'Turkish',
    cs: 'Czech', ro: 'Romanian', el: 'Greek', da: 'Danish',
    fi: 'Finnish', no: 'Norwegian', hu: 'Hungarian', uk: 'Ukrainian',
  };

  const srcName = sourceLang === 'auto'
    ? 'the source language (auto-detect)'
    : (langNames[sourceLang] || sourceLang);
  const tgtName = langNames[targetLang] || targetLang;

  return [
    `You are a professional literary translator translating from ${srcName} to ${tgtName}.`,
    `You produce publication-quality translations that read as if originally written in ${tgtName}.`,
    ``,
    `CORE RULES:`,
    `1. Translate the MEANING and INTENT, never word-by-word. Reconstruct sentences in ${tgtName} naturally.`,
    `2. Match the author's register, tone, and voice — whether literary, colloquial, formal, or poetic.`,
    `3. Every sentence must be grammatically perfect in ${tgtName}: correct gender agreement, case, number, articles, prepositions, verb tense and aspect.`,
    `4. Idioms and culture-specific expressions must be adapted to ${tgtName} equivalents, not translated literally.`,
    `5. Maintain paragraph breaks exactly as the source.`,
    `6. Preserve ambiguity and subtext — do not explain or simplify.`,
    `7. Character names: use the standard ${tgtName} transcription/transliteration convention.`,
    ``,
    `OUTPUT: ONLY the translated text. No notes, no commentary, no quotation marks around the result.`,
  ].join('\n');
}

// ─── Rate Limiting (Cache API) ───────────────────────────────────────────────

async function checkRateLimit(request, clientIp, env) {
  const cacheKey = getCacheKey(clientIp);
  const cache = caches.default;

  const cached = await cache.match(cacheKey);
  if (cached) {
    const data = await cached.json();
    if (data.count >= CONFIG.dailyLimitPerIp) {
      return jsonResponse(429, {
        error: 'Daily translation limit reached. Try again tomorrow.',
        retry_after_hours: 24,
      });
    }
    const elapsed = Date.now() - data.lastRequest;
    if (elapsed < CONFIG.cooldownMs) {
      return jsonResponse(429, {
        error: 'Too fast. Please wait a moment.',
        retry_after_ms: CONFIG.cooldownMs - elapsed,
      });
    }
  }

  return null; // OK
}

async function recordRequest(request, clientIp, env) {
  const cacheKey = getCacheKey(clientIp);
  const cache = caches.default;

  const cached = await cache.match(cacheKey);
  let count = 1;
  if (cached) {
    const data = await cached.json();
    count = data.count + 1;
  }

  const response = new Response(JSON.stringify({ count, lastRequest: Date.now() }), {
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 's-maxage=86400',
    },
  });

  try { await cache.put(cacheKey, response); } catch {}
}

function getCacheKey(clientIp) {
  const today = new Date().toISOString().slice(0, 10);
  return new Request(`https://rate-limit.dualreader.internal/${today}/${clientIp}`);
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function jsonResponse(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function corsResponse(response) {
  response.headers.set('Access-Control-Allow-Origin', '*');
  response.headers.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  response.headers.set('Access-Control-Allow-Headers', 'Content-Type');
  return response;
}
