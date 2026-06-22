/**
 * Dual Reader Translation Proxy — Cloudflare Worker
 *
 * Multi-provider translation with automatic fallback:
 *   Primary: Google Gemini 3.5 Flash → 2.5 Flash (free tier, 250 RPD per key)
 *   Fallback: Z.AI GLM-4.7-Flash (free, unlimited)
 *
 * Multi-key pool: set GEMINI_KEYS (JSON array) or individual GEMINI_KEY_1..N.
 * Each key gets 250 RPD free — rotating across N keys gives N×250 RPD.
 *
 * API keys live server-side — never exposed in the APK.
 * Rate limits enforced per-IP using Cloudflare Cache API.
 */

import { formatBatchPages, parseBatchResponse } from './batch-utils.js';
import {
  getCachedTranslation,
  getCachedTranslations,
  storeCachedTranslation,
  storeCachedTranslations,
  deleteCachedTranslation,
  getCacheStats,
} from './translation-cache.js';
import {
  checkDeviceQuota,
  incrementDeviceQuota,
  getDeviceQuotaStatus,
  cleanupOldQuotaRows,
} from './quota.js';
import {
  incrementKeyUsage,
  getKeyUsageToday,
  cleanupOldKeyUsage,
  getGlmUsageToday,
  GLM_KEY_INDEX,
} from './key-usage.js';

// ─── Config ──────────────────────────────────────────────────────────────────

const CONFIG = {
  // Rate limiting (per IP)
  maxTextLength: 10000,         // chars per single-page request
  maxBatchChars: 30000,         // total chars per batch request (Gemini handles 1M+ context)
  maxBatchPages: 15,            // max pages per batch call (1 API call regardless of page count)
  dailyLimitPerIp: 500,        // requests per IP per day
  cooldownMs: 1500,            // min 1.5s between requests from same IP (batching reduces request count)

  // Provider timeouts (CF Workers subrequest I/O wait, not CPU)
  gemini25TimeoutMs: 15000,       // Gemini 2.5 Flash — PRIMARY (fast, reliable)
  gemini20TimeoutMs: 12000,       // Gemini 2.0 Flash — fallback (cheaper, faster)
  geminiTimeoutMs: 8000,          // Gemini 3.5 Flash — last resort (often rate-limited/timing out)
  glmTimeoutMs: 15000,            // GLM-4.7-Flash — China-based, higher latency

  // Provider endpoints
  gemini25ApiUrl: 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent',
  gemini20ApiUrl: 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent',
  geminiApiUrl: 'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent',
  glmApiUrl: 'https://open.bigmodel.cn/api/paas/v4/chat/completions',

  // Models
  gemini25Model: 'gemini-2.5-flash',
  gemini20Model: 'gemini-2.0-flash',
  geminiModel: 'gemini-3.5-flash',
  glmModel: 'glm-4.7-flash',

  // CORS
  allowedOrigins: ['*'],

  // Per-device quota
  dailyQuotaPerDevice: 50,       // free pages per device per day
};

// ─── Multi-Key Pool ─────────────────────────────────────────────────────────

/**
 * Resolve available Gemini API keys from env secrets.
 * Supports two formats:
 *   1. GEMINI_KEYS: JSON string '["key1","key2","key3"]'  (preferred)
 *   2. GEMINI_KEY_1, GEMINI_KEY_2, ..., GEMINI_KEY_N      (fallback)
 *   3. GEMINI_API_KEY                                       (legacy single key)
 *
 * Returns { keys: string[], pickKey: (clientIp: string) => { key: string, index: number } | null }
 */
function resolveGeminiKeys(env) {
  const keys = [];

  // 1. Try GEMINI_KEYS (JSON array)
  if (env.GEMINI_KEYS) {
    try {
      const parsed = JSON.parse(env.GEMINI_KEYS);
      if (Array.isArray(parsed)) {
        keys.push(...parsed.filter(k => typeof k === 'string' && k.length > 0));
      }
    } catch { /* not JSON, ignore */ }
  }

  // 2. Try numbered keys GEMINI_KEY_1..GEMINI_KEY_20
  if (keys.length === 0) {
    for (let i = 1; i <= 20; i++) {
      const key = env[`GEMINI_KEY_${i}`];
      if (key && typeof key === 'string' && key.length > 0) {
        keys.push(key);
      }
    }
  }

  // 3. Legacy: single GEMINI_API_KEY
  if (keys.length === 0 && env.GEMINI_API_KEY) {
    keys.push(env.GEMINI_API_KEY);
  }

  /**
   * Pick a key deterministically based on client IP + current date.
   * Returns { key, index } or null if no keys.
   */
  function pickKey(clientIp) {
    if (keys.length === 0) return null;
    if (keys.length === 1) return { key: keys[0], index: 0 };
    const daySeed = new Date().toISOString().slice(0, 10); // "2026-06-10"
    const hash = simpleHash(`${clientIp}:${daySeed}`);
    const index = Math.abs(hash) % keys.length;
    return { key: keys[index], index };
  }

  return { keys, pickKey };
}

/** Simple deterministic hash (djb2 variant) — no crypto needed. */
function simpleHash(str) {
  let h = 5381;
  for (let i = 0; i < str.length; i++) {
    h = ((h << 5) + h) + str.charCodeAt(i);
    h = h & h; // 32-bit int
  }
  return h;
}

// ─── Main Handler ────────────────────────────────────────────────────────────

export default {
  async fetch(request, env, ctx) {
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

    // GET /quota — check per-device quota status
    if (request.method === 'GET' && url.pathname === '/quota') {
      const installationId = url.searchParams.get('installation_id');
      if (!installationId) {
        return corsResponse(jsonResponse(400, { error: 'Missing installation_id parameter' }));
      }
      const quotaStatus = await getDeviceQuotaStatus(
        env.TRANSLATION_CACHE, installationId, CONFIG.dailyQuotaPerDevice
      );
      // Periodic cleanup (1% chance per quota request)
      if (Math.random() < 0.01) {
        await cleanupOldQuotaRows(env.TRANSLATION_CACHE);
      }
      return corsResponse(jsonResponse(200, quotaStatus));
    }

    // GET /test/glm — diagnostic: test GLM connectivity from CF edge
    if (request.method === 'GET' && url.pathname === '/test/glm') {
      return corsResponse(await testGlm(env));
    }

    // GET /status — pool health check + cache stats
    if (request.method === 'GET' && url.pathname === '/status') {
      const { keys } = resolveGeminiKeys(env);
      const cacheStats = await getCacheStats(env.TRANSLATION_CACHE);
      return corsResponse(jsonResponse(200, {
        status: 'ok',
        geminiKeyCount: keys.length,
        glmKey: !!env.GLM_API_KEY,
        dailyLimitPerIp: CONFIG.dailyLimitPerIp,
        dailyQuotaPerDevice: CONFIG.dailyQuotaPerDevice,
        maxBatchPages: CONFIG.maxBatchPages,
        cache: cacheStats,
      }));
    }

    // GET /key-health — probe each Gemini key + show tracked usage
    if (request.method === 'GET' && url.pathname === '/key-health') {
      const { keys } = resolveGeminiKeys(env);
      const usage = await getKeyUsageToday(env.TRANSLATION_CACHE, keys.length);

      // Probe each key with a lightweight listModels call
      const probes = await Promise.allSettled(
        keys.map(async (key, i) => {
          const start = Date.now();
          try {
            const resp = await fetch(
              `https://generativelanguage.googleapis.com/v1beta/models?key=${key}&pageSize=1`,
              { signal: AbortSignal.timeout(8000) }
            );
            const latencyMs = Date.now() - start;
            const remaining = usage[i] || { callCount: 0, remaining: 250, dailyLimit: 250 };
            if (resp.ok) {
              return {
                keyIndex: i,
                status: 'ok',
                httpCode: resp.status,
                latencyMs,
                trackedUsage: remaining.callCount,
                trackedRemaining: remaining.remaining,
                dailyLimit: remaining.dailyLimit,
              };
            } else if (resp.status === 429) {
              return {
                keyIndex: i,
                status: 'rate_limited',
                httpCode: 429,
                latencyMs,
                trackedUsage: remaining.callCount,
                trackedRemaining: 0,
                dailyLimit: remaining.dailyLimit,
              };
            } else {
              return {
                keyIndex: i,
                status: 'error',
                httpCode: resp.status,
                latencyMs,
                trackedUsage: remaining.callCount,
                trackedRemaining: remaining.remaining,
                dailyLimit: remaining.dailyLimit,
              };
            }
          } catch (err) {
            return {
              keyIndex: i,
              status: 'error',
              httpCode: 0,
              latencyMs: Date.now() - start,
              error: err.message || 'Unknown error',
              trackedUsage: usage[i]?.callCount || 0,
              trackedRemaining: usage[i]?.remaining || 0,
              dailyLimit: usage[i]?.dailyLimit || 250,
            };
          }
        })
      );

      const keyResults = probes.map(p => p.value || p.reason);
      const healthyKeys = keyResults.filter(k => k.status === 'ok').length;
      const totalRemaining = keyResults.reduce((sum, k) => sum + (k.trackedRemaining || 0), 0);
      const totalLimit = keyResults.reduce((sum, k) => sum + (k.dailyLimit || 0), 0);
      const totalUsed = keyResults.reduce((sum, k) => sum + (k.trackedUsage || 0), 0);

      // Periodic cleanup (1% chance)
      if (Math.random() < 0.01) {
        cleanupOldKeyUsage(env.TRANSLATION_CACHE);
      }

      // ── Probe GLM key ──────────────────────────────────────────────────
      let glmResult = null;
      const glmUsage = await getGlmUsageToday(env.TRANSLATION_CACHE);
      if (env.GLM_API_KEY) {
        const glmStart = Date.now();
        try {
          const glmResp = await fetch(CONFIG.glmApiUrl, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${env.GLM_API_KEY}`,
            },
            body: JSON.stringify({
              model: CONFIG.glmModel,
              messages: [{ role: 'user', content: 'ok' }],
              max_tokens: 1,
            }),
            signal: AbortSignal.timeout(8000),
          });
          const glmLatencyMs = Date.now() - glmStart;
          glmResult = {
            provider: 'glm',
            model: CONFIG.glmModel,
            status: glmResp.ok ? 'ok' : glmResp.status === 429 ? 'rate_limited' : 'error',
            httpCode: glmResp.status,
            latencyMs: glmLatencyMs,
            trackedUsage: glmUsage.callCount,
          };
        } catch (err) {
          glmResult = {
            provider: 'glm',
            model: CONFIG.glmModel,
            status: 'error',
            httpCode: 0,
            latencyMs: Date.now() - glmStart,
            error: err.message || 'Unknown error',
            trackedUsage: glmUsage.callCount,
          };
        }
      }

      return corsResponse(jsonResponse(200, {
        timestamp: new Date().toISOString(),
        totalKeys: keys.length,
        healthyKeys,
        totalUsed,
        totalLimit,
        totalRemaining,
        keys: keyResults,
        glm: glmResult,
      }));
    }

    // GET /dashboard — HTML dashboard for monitoring
    if (request.method === 'GET' && url.pathname === '/dashboard') {
      return new Response(DASHBOARD_HTML, {
        headers: { 'Content-Type': 'text/html; charset=utf-8' },
      });
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

      const { text, source_lang, target_lang, installation_id, skip_cache } = body;

      // 2a. Device quota check (before any processing)
      const quotaResult = await checkDeviceQuota(
        env.TRANSLATION_CACHE, installation_id, 1, CONFIG.dailyQuotaPerDevice
      );
      if (!quotaResult.allowed) {
        return corsResponse(jsonResponse(429, {
          error: 'Daily free quota exceeded. Quota resets at midnight UTC.',
          quota: { pages_used: quotaResult.pagesUsed, daily_limit: quotaResult.dailyLimit, remaining: 0 },
          retry_after_hours: 24,
        }));
      }

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
      const tgtName = langName(target_lang);

      // Wrap user text with explicit translation instruction to prevent
      // the model from generating/continuing text instead of translating.
      const instructionalText = `Translate the following text to ${tgtName}. Output ONLY the translation, nothing else.\n\n${text}`;

      // 2b. Check D1 translation cache (cross-user sharing) — unless skip_cache
      let cached = null;
      if (!skip_cache) {
        cached = await getCachedTranslation(env.TRANSLATION_CACHE, text, target_lang);
      }
      if (cached) {
        console.log(`[cache] HIT for single page (${target_lang}, ${cached.model})`);
        // Count cached hits toward quota too
        await incrementDeviceQuota(env.TRANSLATION_CACHE, installation_id, 1);
        await recordRequest(request, clientIp, env);
        const updatedQuota = await checkDeviceQuota(
          env.TRANSLATION_CACHE, installation_id, 0, CONFIG.dailyQuotaPerDevice
        );
        return corsResponse(jsonResponse(200, {
          translated_text: cached.translated_text,
          model: cached.model,
          source_lang: source_lang || 'auto',
          target_lang,
          cached: true,
          quota: { pages_used: updatedQuota.pagesUsed, daily_limit: updatedQuota.dailyLimit, remaining: updatedQuota.remaining },
        }));
      }
      console.log(`[cache] MISS for single page (${target_lang})`);

      // 3. Resolve Gemini key from pool, then try providers
      const { pickKey } = resolveGeminiKeys(env);
      const picked = pickKey(clientIp);
      const geminiKey = picked?.key;
      const geminiKeyIndex = picked?.index ?? -1;
      let translatedText = null;
      let usedModel = null;
      let geminiError = null;

      // ── Attempt 1: Gemini 2.5 Flash (fast, reliable) ───────────────
      if (geminiKey) {
        try {
          const geminiResult = await callGemini(geminiKey, systemPrompt, instructionalText, CONFIG.gemini25ApiUrl);
          if (geminiResult) {
            translatedText = geminiResult;
            usedModel = CONFIG.gemini25Model;
          }
        } catch (err) {
          geminiError = err.message || 'Unknown Gemini error';

          // Fallback to Gemini 2.0 Flash (cheaper, faster)
          if (!translatedText) {
            try {
              console.warn(`Gemini 2.5 failed (${geminiError}), trying Gemini 2.0 Flash...`);
              const gemini20Result = await callGemini(geminiKey, systemPrompt, instructionalText, CONFIG.gemini20ApiUrl);
              if (gemini20Result) {
                translatedText = gemini20Result;
                usedModel = CONFIG.gemini20Model;
              }
            } catch (err20) {
              geminiError += ` | 2.0: ${err20.message}`;
              console.warn(`Gemini 2.0 also failed: ${err20.message}`);
            }
          }

          // Last resort: Gemini 3.5 Flash
          if (!translatedText) {
            try {
              console.warn(`Trying Gemini 3.5 Flash as last resort...`);
              const gemini35Result = await callGemini(geminiKey, systemPrompt, instructionalText, CONFIG.geminiApiUrl);
              if (gemini35Result) {
                translatedText = gemini35Result;
                usedModel = CONFIG.geminiModel;
              }
            } catch (err35) {
              geminiError += ` | 3.5: ${err35.message}`;
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
          const glmResult = await callGlm(glmKey, systemPrompt, instructionalText);
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

      // 3a. Hallucination guard — reject absurdly inflated translations.
      // A valid translation should be roughly the same length as the original.
      // If output word count > 3x input word count AND input is short (< 20 words),
      // the model almost certainly hallucinated creative text instead of translating.
      {
        const inputWords = text.trim().split(/\s+/).length;
        const outputWords = translatedText.trim().split(/\s+/).length;
        if (inputWords < 20 && outputWords > inputWords * 3) {
          console.warn(`[hallucination-guard] REJECTED: input=${inputWords}w output=${outputWords}w. Input: "${text.slice(0, 60)}" Output: "${translatedText.slice(0, 60)}"`);
          // Delete any cached version of this bad translation
          try { await deleteCachedTranslation(env.TRANSLATION_CACHE, text, target_lang); } catch {}
          return corsResponse(jsonResponse(422, {
            error: 'Translation quality check failed: the model generated text instead of translating. Please try re-translate.',
            detail: `Input was ${inputWords} words but output was ${outputWords} words.`,
          }));
        }
      }

      // 4. Store in D1 cache for cross-user sharing
      await storeCachedTranslation(env.TRANSLATION_CACHE, text, target_lang, translatedText, usedModel);

      // 4a. Track API key usage
      if (geminiKeyIndex >= 0 && usedModel && usedModel.startsWith('gemini')) {
        incrementKeyUsage(env.TRANSLATION_CACHE, geminiKeyIndex, 1);
      }
      if (usedModel && usedModel.startsWith('glm')) {
        incrementKeyUsage(env.TRANSLATION_CACHE, GLM_KEY_INDEX, 1);
      }

      // 5. Increment device quota
      await incrementDeviceQuota(env.TRANSLATION_CACHE, installation_id, 1);

      // 6. Record this request for rate limiting
      await recordRequest(request, clientIp, env);

      // 7. Get updated quota for response
      const finalQuota = await checkDeviceQuota(
        env.TRANSLATION_CACHE, installation_id, 0, CONFIG.dailyQuotaPerDevice
      );

      return corsResponse(jsonResponse(200, {
        translated_text: translatedText,
        model: usedModel,
        source_lang: source_lang || 'auto',
        target_lang,
        quota: { pages_used: finalQuota.pagesUsed, daily_limit: finalQuota.dailyLimit, remaining: finalQuota.remaining },
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
  // Batch = 1 API call regardless of page count. Skip per-IP cooldown
  // (rate limiting is for individual-spam protection, not batch efficiency).
  // Still check daily limit:
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
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return jsonResponse(400, { error: 'Invalid JSON body' });
  }

  const { pages, source_lang, target_lang, installation_id, skip_cache } = body;
  if (!Array.isArray(pages) || pages.length === 0) {
    return jsonResponse(400, { error: 'Missing "pages" array' });
  }
  if (!target_lang) {
    return jsonResponse(400, { error: 'Missing "target_lang"' });
  }
  if (pages.length > CONFIG.maxBatchPages) {
    return jsonResponse(413, { error: `Too many pages (${pages.length}). Max ${CONFIG.maxBatchPages}.` });
  }

  // Device quota check (for the full batch)
  const quotaResult = await checkDeviceQuota(
    env.TRANSLATION_CACHE, installation_id, pages.length, CONFIG.dailyQuotaPerDevice
  );
  if (!quotaResult.allowed) {
    return jsonResponse(429, {
      error: 'Daily free quota exceeded. Quota resets at midnight UTC.',
      quota: { pages_used: quotaResult.pagesUsed, daily_limit: quotaResult.dailyLimit, remaining: 0 },
      retry_after_hours: 24,
    });
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

  // Check D1 cache for all pages (cross-user sharing) — unless skip_cache
  let cachedPages = new Map();
  if (!skip_cache) {
    cachedPages = await getCachedTranslations(env.TRANSLATION_CACHE, pages, target_lang || source_lang);
  }

  // If all pages are cached, return immediately
  if (cachedPages.size === pages.length) {
    console.log(`[cache] BATCH HIT — all ${pages.length} pages cached`);
    const cachedResults = pages.map(p => {
      const cached = cachedPages.get(p.index);
      return {
        index: p.index,
        translated_text: cached.translated_text,
        model: cached.model,
        cached: true,
      };
    });
    // Count cached hits toward quota
    await incrementDeviceQuota(env.TRANSLATION_CACHE, installation_id, pages.length);
    await recordRequest(request, clientIp, env);
    const batchQuota = await checkDeviceQuota(
      env.TRANSLATION_CACHE, installation_id, 0, CONFIG.dailyQuotaPerDevice
    );
    return jsonResponse(200, {
      translations: cachedResults,
      model: cachedPages.values().next().value.model,
      source_lang: source_lang || 'auto',
      target_lang,
      cached: true,
      quota: { pages_used: batchQuota.pagesUsed, daily_limit: batchQuota.dailyLimit, remaining: batchQuota.remaining },
    });
  }

  // Filter to only uncached pages for translation
  const uncachedPages = pages.filter(p => !cachedPages.has(p.index));
  console.log(`[cache] BATCH PARTIAL — ${cachedPages.size}/${pages.length} cached, translating ${uncachedPages.length}`);

  const userText = formatBatchPages(uncachedPages);
  const tgtName = langName(target_lang);
  const instructionalText = `Translate the following ${uncachedPages.length} pages to ${tgtName}. Maintain the [Page N] markers in your output. Output ONLY the translations, nothing else.\n\n${userText}`;

  // Resolve Gemini key from pool
  const { pickKey } = resolveGeminiKeys(env);
  const picked = pickKey(clientIp);
  const geminiKey = picked?.key;
  const geminiKeyIndex = picked?.index ?? -1;

  // Try providers with same fallback chain as single translate
  let translatedText = null;
  let usedModel = null;
  let geminiError = null;

  if (geminiKey) {
    // PRIMARY: Gemini 2.5 Flash — fast, reliable, good quality
    console.log(`[batch] Trying Gemini 2.5 Flash (${CONFIG.gemini25TimeoutMs}ms timeout)...`);
    try {
      const result = await callGemini(geminiKey, systemPrompt, instructionalText, CONFIG.gemini25ApiUrl);
      if (result) { translatedText = result; usedModel = CONFIG.gemini25Model; }
    } catch (err) {
      geminiError = err.message || 'Unknown error';
      console.log(`[batch] Gemini 2.5 failed: ${geminiError}`);
    }

    // FALLBACK 1: Gemini 2.0 Flash — cheaper, faster
    if (!translatedText) {
      console.log(`[batch] Trying Gemini 2.0 Flash (${CONFIG.gemini20TimeoutMs}ms timeout)...`);
      try {
        const r2 = await callGemini(geminiKey, systemPrompt, instructionalText, CONFIG.gemini20ApiUrl);
        if (r2) { translatedText = r2; usedModel = CONFIG.gemini20Model; }
      } catch (err20) {
        geminiError += ` | 2.0: ${err20.message}`;
        console.log(`[batch] Gemini 2.0 failed: ${err20.message}`);
      }
    }

    // FALLBACK 2: Gemini 3.5 Flash — last resort (often rate-limited)
    if (!translatedText) {
      console.log(`[batch] Trying Gemini 3.5 Flash (${CONFIG.geminiTimeoutMs}ms timeout)...`);
      try {
        const r3 = await callGemini(geminiKey, systemPrompt, instructionalText, CONFIG.geminiApiUrl);
        if (r3) { translatedText = r3; usedModel = CONFIG.geminiModel; }
      } catch (err35) {
        geminiError += ` | 3.5: ${err35.message}`;
        console.log(`[batch] Gemini 3.5 failed: ${err35.message}`);
      }
    }
  }

  if (!translatedText) {
    const glmKey = env.GLM_API_KEY;
    if (!glmKey) {
      return jsonResponse(500, { error: 'No translation service configured.' });
    }
    console.log(`[batch] Trying GLM (${CONFIG.glmTimeoutMs}ms timeout)...`);
    try {
      const glmResult = await callGlm(glmKey, systemPrompt, instructionalText);
      if (glmResult) { translatedText = glmResult; usedModel = CONFIG.glmModel; }
    } catch (err) {
      return jsonResponse(502, { error: `${geminiError ? 'Gemini: ' + geminiError + '. ' : ''}GLM: ${err.message}` });
    }
  }

  if (!translatedText) {
    return jsonResponse(502, { error: 'Empty response from all providers' });
  }

  // Parse the structured response into individual translations (against uncached pages)
  const parsed = parseBatchResponse(translatedText, uncachedPages);

  // Store newly translated pages in D1 cache
  if (parsed.length > 0) {
    const cacheEntries = parsed.map(p => {
      const originalPage = uncachedPages.find(op => op.index === p.index);
      return {
        sourceText: originalPage ? originalPage.text : '',
        targetLang: target_lang,
        translatedText: p.translated_text,
        model: usedModel,
      };
    }).filter(e => e.sourceText);
    await storeCachedTranslations(env.TRANSLATION_CACHE, cacheEntries);
  }

  // Track API key usage (1 API call per batch)
  if (geminiKeyIndex >= 0 && usedModel && usedModel.startsWith('gemini')) {
    incrementKeyUsage(env.TRANSLATION_CACHE, geminiKeyIndex, 1);
  }
  if (usedModel && usedModel.startsWith('glm')) {
    incrementKeyUsage(env.TRANSLATION_CACHE, GLM_KEY_INDEX, 1);
  }

  // Merge cached + newly translated results
  const allResults = [];
  for (const page of pages) {
    if (cachedPages.has(page.index)) {
      const cached = cachedPages.get(page.index);
      allResults.push({ index: page.index, translated_text: cached.translated_text, model: cached.model });
    } else {
      const fresh = parsed.find(p => p.index === page.index);
      if (fresh) {
        allResults.push({ index: fresh.index, translated_text: fresh.translated_text, model: usedModel });
      }
    }
  }

  // Increment device quota for pages translated (uncached pages cost quota;
  // cached pages were already counted when they were first translated, so only count fresh ones)
  const freshPages = Math.max(parsed.length, uncachedPages.length);
  if (freshPages > 0) {
    await incrementDeviceQuota(env.TRANSLATION_CACHE, installation_id, freshPages);
  }
  // Also count any cached pages from this batch (partial cache hit)
  if (cachedPages.size > 0 && cachedPages.size < pages.length) {
    await incrementDeviceQuota(env.TRANSLATION_CACHE, installation_id, cachedPages.size);
  }

  await recordRequest(request, clientIp, env);

  const batchFinalQuota = await checkDeviceQuota(
    env.TRANSLATION_CACHE, installation_id, 0, CONFIG.dailyQuotaPerDevice
  );

  return jsonResponse(200, {
    translations: allResults,
    model: usedModel,
    source_lang: source_lang || 'auto',
    target_lang,
    quota: { pages_used: batchFinalQuota.pagesUsed, daily_limit: batchFinalQuota.dailyLimit, remaining: batchFinalQuota.remaining },
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

async function callGemini(apiKey, systemPrompt, userText, apiUrl, timeoutMs) {
  const url = `${apiUrl || CONFIG.geminiApiUrl}?key=${apiKey}`;
  const timeout = timeoutMs || (apiUrl === CONFIG.gemini25ApiUrl ? CONFIG.gemini25TimeoutMs : CONFIG.geminiTimeoutMs);

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
        temperature: 0.2,
        maxOutputTokens: 16384,
        // No thinking mode — translation is straightforward, saves 3-5s latency
      },
    }),
    signal: AbortSignal.timeout(timeout),
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
      max_tokens: 4096,
      // Disable thinking/reasoning to get direct translations — no reasoning_content overhead
      thinking: { type: 'disabled' },
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

// ─── Language name helper ────────────────────────────────────────────────────

function langName(code) {
  const names = {
    en: 'English', es: 'Spanish', fr: 'French', de: 'German',
    it: 'Italian', pt: 'Portuguese', ru: 'Russian', zh: 'Chinese',
    ja: 'Japanese', ko: 'Korean', ar: 'Arabic', bg: 'Bulgarian',
    nl: 'Dutch', sv: 'Swedish', pl: 'Polish', tr: 'Turkish',
    cs: 'Czech', ro: 'Romanian', el: 'Greek', da: 'Danish',
    fi: 'Finnish', no: 'Norwegian', hu: 'Hungarian', uk: 'Ukrainian',
  };
  return names[code] || code;
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

// ─── GLM Connectivity Test ─────────────────────────────────────────────────

async function testGlm(env) {
  const key = env.GLM_API_KEY;
  if (!key) return jsonResponse(500, { error: 'No GLM_API_KEY secret' });

  const results = {};
  const endpoints = [
    ['z.ai/paas', 'https://api.z.ai/api/paas/v4/chat/completions'],
    ['bigmodel', 'https://open.bigmodel.cn/api/paas/v4/chat/completions'],
  ];

  for (const [name, url] of endpoints) {
    const start = Date.now();
    try {
      const resp = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${key}`,
        },
        body: JSON.stringify({
          model: 'glm-4.7-flash',
          messages: [{ role: 'user', content: 'Say OK' }],
          max_tokens: 10,
          thinking: { type: 'disabled' },
        }),
        signal: AbortSignal.timeout(10000),
      });
      const text = await resp.text();
      results[name] = {
        status: resp.status,
        time_ms: Date.now() - start,
        body: text.slice(0, 200),
      };
    } catch (err) {
      results[name] = {
        status: 'error',
        time_ms: Date.now() - start,
        error: err.message,
      };
    }
  }

  return jsonResponse(200, { key_prefix: key.slice(0, 8), results });
}

function corsResponse(response) {
  response.headers.set('Access-Control-Allow-Origin', '*');
  response.headers.set('Access-Control-Allow-Methods', 'POST, GET, OPTIONS');
  response.headers.set('Access-Control-Allow-Headers', 'Content-Type');
  return response;
}

// ─── Dashboard HTML ──────────────────────────────────────────────────────────

const DASHBOARD_HTML = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Gemini Key Monitor</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    background: #0f1117; color: #e0e0e0; min-height: 100vh; padding: 20px;
  }
  .container { max-width: 800px; margin: 0 auto; }
  h1 { font-size: 1.6rem; margin-bottom: 4px; }
  .subtitle { color: #888; font-size: 0.85rem; margin-bottom: 20px; }
  .summary {
    display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
    gap: 12px; margin-bottom: 24px;
  }
  .stat-card {
    background: #1a1d27; border-radius: 10px; padding: 16px; text-align: center;
    border: 1px solid #2a2d3a;
  }
  .stat-value { font-size: 1.8rem; font-weight: 700; margin-bottom: 2px; }
  .stat-label { font-size: 0.75rem; color: #888; text-transform: uppercase; letter-spacing: 0.5px; }
  .green { color: #4ade80; }
  .yellow { color: #fbbf24; }
  .red { color: #f87171; }
  .blue { color: #60a5fa; }
  .key-list { display: flex; flex-direction: column; gap: 10px; }
  .key-card {
    background: #1a1d27; border-radius: 10px; padding: 16px;
    border: 1px solid #2a2d3a; display: flex; align-items: center; gap: 16px;
  }
  .key-icon {
    width: 12px; height: 12px; border-radius: 50%; flex-shrink: 0;
  }
  .key-icon.ok { background: #4ade80; box-shadow: 0 0 8px #4ade8066; }
  .key-icon.rate_limited { background: #f87171; box-shadow: 0 0 8px #f8717166; }
  .key-icon.error { background: #fbbf24; box-shadow: 0 0 8px #fbbf2466; }
  .key-info { flex: 1; }
  .key-name { font-weight: 600; margin-bottom: 4px; }
  .key-details { font-size: 0.8rem; color: #888; display: flex; gap: 12px; flex-wrap: wrap; }
  .key-bar {
    flex: 0 0 120px; height: 8px; background: #2a2d3a; border-radius: 4px; overflow: hidden;
  }
  .key-bar-fill { height: 100%; border-radius: 4px; transition: width 0.5s; }
  .key-bar-fill.green { background: #4ade80; }
  .key-bar-fill.yellow { background: #fbbf24; }
  .key-bar-fill.red { background: #f87171; }
  .refresh-info { text-align: center; margin-top: 16px; font-size: 0.75rem; color: #666; }
  .glm-badge {
    display: inline-block; padding: 2px 8px; border-radius: 4px; font-size: 0.7rem;
    background: #60a5fa22; color: #60a5fa; margin-left: 8px;
  }
  .error-msg { color: #f87171; font-size: 0.75rem; }
</style>
</head>
<body>
<div class="container">
  <h1>🔑 Gemini Key Monitor</h1>
  <p class="subtitle" id="last-update">Loading...</p>

  <div class="summary" id="summary"></div>
  <div class="key-list" id="key-list"></div>

  <p class="refresh-info">Auto-refreshes every 60s · <a href="/key-health" style="color:#60a5fa">JSON API</a></p>
</div>

<script>
const STATUS_LABELS = { ok: 'Healthy', rate_limited: 'Rate Limited', error: 'Error' };

async function fetchData() {
  try {
    const resp = await fetch('/key-health');
    if (!resp.ok) throw new Error('HTTP ' + resp.status);
    const data = await resp.json();
    render(data);
  } catch (err) {
    document.getElementById('last-update').textContent = 'Error: ' + err.message;
  }
}

function render(data) {
  const time = new Date(data.timestamp).toLocaleString();
  const pct = data.totalLimit > 0 ? (data.totalUsed / data.totalLimit * 100) : 0;
  const healthColor = data.healthyKeys === data.totalKeys ? 'green' : data.healthyKeys === 0 ? 'red' : 'yellow';
  const remainingColor = pct < 50 ? 'green' : pct < 80 ? 'yellow' : 'red';

  const glmBadge = data.glm
    ? (data.glm.status === 'ok'
      ? '<span class="glm-badge">GLM ' + data.glm.model + ' ✓</span>'
      : '<span class="glm-badge" style="background:#f8717122;color:#f87171">GLM ' + data.glm.status + '</span>')
    : '<span class="glm-badge" style="background:#f8717122;color:#f87171">No GLM</span>';

  document.getElementById('last-update').innerHTML =
    'Last checked: ' + time + glmBadge;

  document.getElementById('summary').innerHTML = \`
    <div class="stat-card">
      <div class="stat-value \${healthColor}">\${data.healthyKeys}/\${data.totalKeys}</div>
      <div class="stat-label">Gemini Keys</div>
    </div>
    <div class="stat-card">
      <div class="stat-value blue">\${data.totalUsed}</div>
      <div class="stat-label">Used Today</div>
    </div>
    <div class="stat-card">
      <div class="stat-value \${remainingColor}">\${data.totalRemaining}</div>
      <div class="stat-label">Remaining</div>
    </div>
    <div class="stat-card">
      <div class="stat-value" style="color:#888">\${data.totalLimit}</div>
      <div class="stat-label">Daily Limit</div>
    </div>
  \`;

  const geminiCards = data.keys.map(k => {
    const barPct = k.dailyLimit > 0 ? (k.trackedUsage / k.dailyLimit * 100) : 0;
    const barColor = barPct < 50 ? 'green' : barPct < 80 ? 'yellow' : 'red';
    const remainPct = k.dailyLimit > 0 ? Math.round(k.trackedRemaining / k.dailyLimit * 100) : 0;
    return \`
      <div class="key-card">
        <div class="key-icon \${k.status}"></div>
        <div class="key-info">
          <div class="key-name">Gemini Key #\${k.keyIndex + 1} — \${STATUS_LABELS[k.status] || k.status}</div>
          <div class="key-details">
            <span>\${k.trackedUsage}/\${k.dailyLimit} used</span>
            <span>\${k.trackedRemaining} remaining</span>
            <span>\${k.latencyMs}ms</span>
            <span>HTTP \${k.httpCode}</span>
            \${k.error ? '<span class="error-msg">' + k.error + '</span>' : ''}
          </div>
        </div>
        <div class="key-bar"><div class="key-bar-fill \${barColor}" style="width:\${100 - remainPct}%"></div></div>
      </div>
    \`;
  }).join('');

  const glmCard = data.glm ? \`
    <div class="key-card">
      <div class="key-icon \${data.glm.status}"></div>
      <div class="key-info">
        <div class="key-name">GLM (\${data.glm.model}) — \${STATUS_LABELS[data.glm.status] || data.glm.status}</div>
        <div class="key-details">
          <span>\${data.glm.trackedUsage} calls today</span>
          <span>\${data.glm.latencyMs}ms</span>
          <span>HTTP \${data.glm.httpCode}</span>
          \${data.glm.error ? '<span class="error-msg">' + data.glm.error + '</span>' : ''}
        </div>
      </div>
    </div>
  \` : '';

  document.getElementById('key-list').innerHTML = geminiCards + glmCard;
}

fetchData();
setInterval(fetchData, 60000);
</script>
</body>
</html>`;
