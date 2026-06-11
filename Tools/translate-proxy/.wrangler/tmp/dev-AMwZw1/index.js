var __defProp = Object.defineProperty;
var __name = (target, value) => __defProp(target, "name", { value, configurable: true });

// src/batch-utils.js
function formatBatchPages(pages) {
  return pages.map((p) => `[Page ${p.index}]
${p.text}`).join("\n\n");
}
__name(formatBatchPages, "formatBatchPages");
function parseBatchResponse(text, pages) {
  const expectedCount = pages.length;
  const results = [];
  const validIndices = new Set(pages.map((p) => p.index));
  const pageRegex = /\[Page\s+(\d+)\]\s*\n([\s\S]*?)(?=\n\[Page\s+\d+\]|$)/gi;
  let match;
  const found = /* @__PURE__ */ new Map();
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
  const cleanText = text.replace(/\[Page\s+\d+\]\s*\n?/gi, "").trim();
  const chunks = cleanText.split(/\n{2,}/).filter((c) => c.trim());
  if (chunks.length === expectedCount) {
    return pages.map((p, i) => ({ index: p.index, translated_text: chunks[i].trim() }));
  }
  if (expectedCount === 1) {
    return [{ index: pages[0].index, translated_text: cleanText }];
  }
  console.warn(`Batch parse failed: expected ${expectedCount} pages, found ${found.size} markers, ${chunks.length} chunks`);
  return [];
}
__name(parseBatchResponse, "parseBatchResponse");

// src/translation-cache.js
var CACHE_TTL_MS = 90 * 24 * 60 * 60 * 1e3;
async function getCachedTranslation(db, sourceText, targetLang) {
  if (!db) return null;
  const cacheKey = await computeCacheKey(sourceText, targetLang);
  try {
    const row = await db.prepare(
      "SELECT translated_text, model, cached_at FROM translation_cache WHERE cache_key = ?"
    ).bind(cacheKey).first();
    if (!row) return null;
    const cachedAt = new Date(row.cached_at).getTime();
    if (Date.now() - cachedAt > CACHE_TTL_MS) {
      await db.prepare("DELETE FROM translation_cache WHERE cache_key = ?").bind(cacheKey).run();
      return null;
    }
    return row;
  } catch (err) {
    console.error(`[cache] Lookup error: ${err.message}`);
    return null;
  }
}
__name(getCachedTranslation, "getCachedTranslation");
async function getCachedTranslations(db, pages, targetLang) {
  const result = /* @__PURE__ */ new Map();
  if (!db || pages.length === 0) return result;
  try {
    const keys = await Promise.all(
      pages.map(async (p) => ({
        index: p.index,
        key: await computeCacheKey(p.text, targetLang)
      }))
    );
    const placeholders = keys.map(() => "?").join(",");
    const stmt = db.prepare(
      `SELECT cache_key, translated_text, model, cached_at FROM translation_cache WHERE cache_key IN (${placeholders})`
    ).bind(...keys.map((k) => k.key));
    const rows = await stmt.all();
    const keyToIndex = new Map(keys.map((k) => [k.key, k.index]));
    const expiredKeys = [];
    for (const row of rows.results) {
      const idx = keyToIndex.get(row.cache_key);
      if (idx === void 0) continue;
      const cachedAt = new Date(row.cached_at).getTime();
      if (Date.now() - cachedAt > CACHE_TTL_MS) {
        expiredKeys.push(row.cache_key);
        continue;
      }
      result.set(idx, {
        translated_text: row.translated_text,
        model: row.model
      });
    }
    if (expiredKeys.length > 0) {
      const delPlaceholders = expiredKeys.map(() => "?").join(",");
      await db.prepare(
        `DELETE FROM translation_cache WHERE cache_key IN (${delPlaceholders})`
      ).bind(...expiredKeys).run();
    }
  } catch (err) {
    console.error(`[cache] Batch lookup error: ${err.message}`);
  }
  return result;
}
__name(getCachedTranslations, "getCachedTranslations");
async function storeCachedTranslation(db, sourceText, targetLang, translatedText, model) {
  if (!db) return;
  const cacheKey = await computeCacheKey(sourceText, targetLang);
  try {
    await db.prepare(
      `INSERT OR REPLACE INTO translation_cache (cache_key, source_hash, target_lang, translated_text, model, cached_at)
       VALUES (?, ?, ?, ?, ?, ?)`
    ).bind(
      cacheKey,
      await computeHash(sourceText),
      targetLang,
      translatedText,
      model,
      (/* @__PURE__ */ new Date()).toISOString()
    ).run();
  } catch (err) {
    console.error(`[cache] Store error: ${err.message}`);
  }
}
__name(storeCachedTranslation, "storeCachedTranslation");
async function storeCachedTranslations(db, translations) {
  if (!db || translations.length === 0) return;
  try {
    const stmts = await Promise.all(translations.map(async (t) => {
      const cacheKey = await computeCacheKey(t.sourceText, t.targetLang);
      return db.prepare(
        `INSERT OR REPLACE INTO translation_cache (cache_key, source_hash, target_lang, translated_text, model, cached_at)
         VALUES (?, ?, ?, ?, ?, ?)`
      ).bind(
        cacheKey,
        await computeHash(t.sourceText),
        t.targetLang,
        t.translatedText,
        t.model,
        (/* @__PURE__ */ new Date()).toISOString()
      );
    }));
    await db.batch(stmts);
  } catch (err) {
    console.error(`[cache] Batch store error: ${err.message}`);
  }
}
__name(storeCachedTranslations, "storeCachedTranslations");
async function getCacheStats(db) {
  if (!db) return null;
  try {
    const [totalResult, expiredResult, langResult] = await db.batch([
      db.prepare("SELECT COUNT(*) as count FROM translation_cache"),
      db.prepare("SELECT COUNT(*) as count FROM translation_cache WHERE cached_at < ?").bind(new Date(Date.now() - CACHE_TTL_MS).toISOString()),
      db.prepare("SELECT DISTINCT target_lang FROM translation_cache")
    ]);
    return {
      total_entries: totalResult.results[0]?.count ?? 0,
      expired_entries: expiredResult.results[0]?.count ?? 0,
      languages: langResult.results.map((r) => r.target_lang)
    };
  } catch (err) {
    console.error(`[cache] Stats error: ${err.message}`);
    return null;
  }
}
__name(getCacheStats, "getCacheStats");
async function computeCacheKey(sourceText, targetLang) {
  const combined = `${targetLang}:${sourceText}`;
  return computeHash(combined);
}
__name(computeCacheKey, "computeCacheKey");
async function computeHash(text) {
  const encoder = new TextEncoder();
  const data = encoder.encode(text);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}
__name(computeHash, "computeHash");

// src/quota.js
var DEFAULT_DAILY_QUOTA = 50;
async function checkDeviceQuota(db, installationId, pagesRequested = 1, dailyLimit) {
  const limit = dailyLimit || DEFAULT_DAILY_QUOTA;
  if (!installationId || !db) {
    return { allowed: true, pagesUsed: 0, dailyLimit: limit, remaining: limit };
  }
  const today = getTodayString();
  try {
    const row = await db.prepare(
      "SELECT pages_used FROM device_quota WHERE installation_id = ? AND quota_date = ?"
    ).bind(installationId, today).first();
    const pagesUsed = row?.pages_used || 0;
    const remaining = Math.max(0, limit - pagesUsed);
    return {
      allowed: pagesUsed + pagesRequested <= limit,
      pagesUsed,
      dailyLimit: limit,
      remaining
    };
  } catch (err) {
    console.error(`[quota] Check error: ${err.message}`);
    return { allowed: true, pagesUsed: 0, dailyLimit: limit, remaining: limit };
  }
}
__name(checkDeviceQuota, "checkDeviceQuota");
async function incrementDeviceQuota(db, installationId, pagesUsed = 1) {
  if (!installationId || !db) return;
  const today = getTodayString();
  try {
    await db.prepare(`
      INSERT INTO device_quota (installation_id, quota_date, pages_used, last_updated)
      VALUES (?, ?, ?, datetime('now'))
      ON CONFLICT(installation_id, quota_date) DO UPDATE SET
        pages_used = pages_used + ?,
        last_updated = datetime('now')
    `).bind(installationId, today, pagesUsed, pagesUsed).run();
  } catch (err) {
    console.error(`[quota] Increment error: ${err.message}`);
  }
}
__name(incrementDeviceQuota, "incrementDeviceQuota");
async function getDeviceQuotaStatus(db, installationId, dailyLimit) {
  const limit = dailyLimit || DEFAULT_DAILY_QUOTA;
  if (!installationId || !db) {
    return { pagesUsed: 0, dailyLimit: limit, remaining: limit, resetAt: getResetTime() };
  }
  const today = getTodayString();
  try {
    const row = await db.prepare(
      "SELECT pages_used FROM device_quota WHERE installation_id = ? AND quota_date = ?"
    ).bind(installationId, today).first();
    const pagesUsed = row?.pages_used || 0;
    const remaining = Math.max(0, limit - pagesUsed);
    return { pagesUsed, dailyLimit: limit, remaining, resetAt: getResetTime() };
  } catch (err) {
    console.error(`[quota] Status error: ${err.message}`);
    return { pagesUsed: 0, dailyLimit: limit, remaining: limit, resetAt: getResetTime() };
  }
}
__name(getDeviceQuotaStatus, "getDeviceQuotaStatus");
async function cleanupOldQuotaRows(db) {
  if (!db) return 0;
  try {
    const twoDaysAgo = new Date(Date.now() - 2 * 24 * 60 * 60 * 1e3).toISOString().slice(0, 10);
    const result = await db.prepare(
      "DELETE FROM device_quota WHERE quota_date < ?"
    ).bind(twoDaysAgo).run();
    return result.meta?.changes || 0;
  } catch (err) {
    console.error(`[quota] Cleanup error: ${err.message}`);
    return 0;
  }
}
__name(cleanupOldQuotaRows, "cleanupOldQuotaRows");
function getTodayString() {
  return (/* @__PURE__ */ new Date()).toISOString().slice(0, 10);
}
__name(getTodayString, "getTodayString");
function getResetTime() {
  const tomorrow = /* @__PURE__ */ new Date();
  tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
  tomorrow.setUTCHours(0, 0, 0, 0);
  return tomorrow.toISOString();
}
__name(getResetTime, "getResetTime");

// src/index.js
var CONFIG = {
  // Rate limiting (per IP)
  maxTextLength: 1e4,
  // chars per single-page request
  maxBatchChars: 1e4,
  // total chars per batch request (sum of all pages)
  maxBatchPages: 3,
  // max pages per batch call (reduced for timeout safety)
  dailyLimitPerIp: 500,
  // requests per IP per day
  cooldownMs: 3e3,
  // min 3s between requests from same IP
  // Provider timeouts (CF Workers subrequest I/O wait, not CPU)
  geminiTimeoutMs: 25e3,
  // Gemini 3.5 Flash with thinking needs 15-25s for quality
  gemini25TimeoutMs: 1e4,
  // Gemini 2.5 Flash is faster (no thinking mode) — 10s generous
  glmTimeoutMs: 2e4,
  // GLM-4.7-Flash with reasoning needs 12-15s
  // Provider endpoints
  geminiApiUrl: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent",
  gemini25ApiUrl: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent",
  glmApiUrl: "https://open.bigmodel.cn/api/paas/v4/chat/completions",
  // Models
  geminiModel: "gemini-3.5-flash",
  gemini25Model: "gemini-2.5-flash",
  glmModel: "glm-4.7-flash",
  // CORS
  allowedOrigins: ["*"],
  // Per-device quota
  dailyQuotaPerDevice: 50
  // free pages per device per day
};
function resolveGeminiKeys(env) {
  const keys = [];
  if (env.GEMINI_KEYS) {
    try {
      const parsed = JSON.parse(env.GEMINI_KEYS);
      if (Array.isArray(parsed)) {
        keys.push(...parsed.filter((k) => typeof k === "string" && k.length > 0));
      }
    } catch {
    }
  }
  if (keys.length === 0) {
    for (let i = 1; i <= 20; i++) {
      const key = env[`GEMINI_KEY_${i}`];
      if (key && typeof key === "string" && key.length > 0) {
        keys.push(key);
      }
    }
  }
  if (keys.length === 0 && env.GEMINI_API_KEY) {
    keys.push(env.GEMINI_API_KEY);
  }
  function pickKey(clientIp) {
    if (keys.length === 0) return null;
    if (keys.length === 1) return keys[0];
    const daySeed = (/* @__PURE__ */ new Date()).toISOString().slice(0, 10);
    const hash = simpleHash(`${clientIp}:${daySeed}`);
    return keys[Math.abs(hash) % keys.length];
  }
  __name(pickKey, "pickKey");
  return { keys, pickKey };
}
__name(resolveGeminiKeys, "resolveGeminiKeys");
function simpleHash(str) {
  let h = 5381;
  for (let i = 0; i < str.length; i++) {
    h = (h << 5) + h + str.charCodeAt(i);
    h = h & h;
  }
  return h;
}
__name(simpleHash, "simpleHash");
var src_default = {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return corsResponse(new Response(null, { status: 204 }));
    }
    const url = new URL(request.url);
    const clientIp = request.headers.get("CF-Connecting-IP") || "unknown";
    if (request.method === "POST" && url.pathname === "/translate/batch") {
      return corsResponse(await handleBatchTranslate(request, clientIp, env));
    }
    if (request.method === "GET" && url.pathname === "/quota") {
      const installationId = url.searchParams.get("installation_id");
      if (!installationId) {
        return corsResponse(jsonResponse(400, { error: "Missing installation_id parameter" }));
      }
      const quotaStatus = await getDeviceQuotaStatus(
        env.TRANSLATION_CACHE,
        installationId,
        CONFIG.dailyQuotaPerDevice
      );
      if (Math.random() < 0.01) {
        await cleanupOldQuotaRows(env.TRANSLATION_CACHE);
      }
      return corsResponse(jsonResponse(200, quotaStatus));
    }
    if (request.method === "GET" && url.pathname === "/test/glm") {
      return corsResponse(await testGlm(env));
    }
    if (request.method === "GET" && url.pathname === "/status") {
      const { keys } = resolveGeminiKeys(env);
      const cacheStats = await getCacheStats(env.TRANSLATION_CACHE);
      return corsResponse(jsonResponse(200, {
        status: "ok",
        geminiKeyCount: keys.length,
        glmKey: !!env.GLM_API_KEY,
        dailyLimitPerIp: CONFIG.dailyLimitPerIp,
        dailyQuotaPerDevice: CONFIG.dailyQuotaPerDevice,
        maxBatchPages: CONFIG.maxBatchPages,
        cache: cacheStats
      }));
    }
    if (request.method !== "POST" || !url.pathname.startsWith("/translate")) {
      return corsResponse(jsonResponse(404, { error: "Not found. Use POST /translate or POST /translate/batch" }));
    }
    try {
      const rateLimitResult = await checkRateLimit(request, clientIp, env);
      if (rateLimitResult) return corsResponse(rateLimitResult);
      let body;
      try {
        body = await request.json();
      } catch {
        return corsResponse(jsonResponse(400, { error: "Invalid JSON body" }));
      }
      const { text, source_lang, target_lang, installation_id } = body;
      const quotaResult = await checkDeviceQuota(
        env.TRANSLATION_CACHE,
        installation_id,
        1,
        CONFIG.dailyQuotaPerDevice
      );
      if (!quotaResult.allowed) {
        return corsResponse(jsonResponse(429, {
          error: "Daily free quota exceeded. Quota resets at midnight UTC.",
          quota: { pages_used: quotaResult.pagesUsed, daily_limit: quotaResult.dailyLimit, remaining: 0 },
          retry_after_hours: 24
        }));
      }
      if (!text || typeof text !== "string") {
        return corsResponse(jsonResponse(400, { error: 'Missing "text" field' }));
      }
      if (!target_lang || typeof target_lang !== "string") {
        return corsResponse(jsonResponse(400, { error: 'Missing "target_lang" field' }));
      }
      if (text.length > CONFIG.maxTextLength) {
        return corsResponse(jsonResponse(413, {
          error: `Text too long (${text.length} chars). Max ${CONFIG.maxTextLength}.`
        }));
      }
      const systemPrompt = buildTranslationPrompt(source_lang || "auto", target_lang);
      const cached = await getCachedTranslation(env.TRANSLATION_CACHE, text, target_lang);
      if (cached) {
        console.log(`[cache] HIT for single page (${target_lang}, ${cached.model})`);
        await incrementDeviceQuota(env.TRANSLATION_CACHE, installation_id, 1);
        await recordRequest(request, clientIp, env);
        const updatedQuota = await checkDeviceQuota(
          env.TRANSLATION_CACHE,
          installation_id,
          0,
          CONFIG.dailyQuotaPerDevice
        );
        return corsResponse(jsonResponse(200, {
          translated_text: cached.translated_text,
          model: cached.model,
          source_lang: source_lang || "auto",
          target_lang,
          cached: true,
          quota: { pages_used: updatedQuota.pagesUsed, daily_limit: updatedQuota.dailyLimit, remaining: updatedQuota.remaining }
        }));
      }
      console.log(`[cache] MISS for single page (${target_lang})`);
      const { pickKey } = resolveGeminiKeys(env);
      const geminiKey = pickKey(clientIp);
      let translatedText = null;
      let usedModel = null;
      let geminiError = null;
      if (geminiKey) {
        for (let attempt = 0; attempt < 2 && !translatedText; attempt++) {
          try {
            const geminiResult = await callGemini(geminiKey, systemPrompt, text, CONFIG.geminiApiUrl);
            if (geminiResult) {
              translatedText = geminiResult;
              usedModel = CONFIG.geminiModel;
            }
          } catch (err) {
            geminiError = err.message || "Unknown Gemini error";
            const is503 = geminiError.includes("503") || geminiError.includes("UNAVAILABLE");
            if (is503 && attempt === 0) {
              console.warn(`Gemini 3.5 unavailable (503), retrying in 1s...`);
              await new Promise((r) => setTimeout(r, 1e3));
              continue;
            }
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
        console.info("GEMINI_API_KEY not set, using GLM directly");
      }
      if (!translatedText) {
        const glmKey = env.GLM_API_KEY;
        if (!glmKey) {
          console.error("No translation API keys configured");
          return corsResponse(jsonResponse(500, {
            error: "No translation service configured. Set GEMINI_API_KEY or GLM_API_KEY."
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
          const geminiMsg = geminiError ? `Gemini: ${geminiError}. ` : "";
          return corsResponse(jsonResponse(502, {
            error: `${geminiMsg}GLM: ${err.message || "Translation failed"}`
          }));
        }
      }
      if (!translatedText) {
        return corsResponse(jsonResponse(502, { error: "Empty translation response from all providers" }));
      }
      await storeCachedTranslation(env.TRANSLATION_CACHE, text, target_lang, translatedText, usedModel);
      await incrementDeviceQuota(env.TRANSLATION_CACHE, installation_id, 1);
      await recordRequest(request, clientIp, env);
      const finalQuota = await checkDeviceQuota(
        env.TRANSLATION_CACHE,
        installation_id,
        0,
        CONFIG.dailyQuotaPerDevice
      );
      return corsResponse(jsonResponse(200, {
        translated_text: translatedText,
        model: usedModel,
        source_lang: source_lang || "auto",
        target_lang,
        quota: { pages_used: finalQuota.pagesUsed, daily_limit: finalQuota.dailyLimit, remaining: finalQuota.remaining }
      }));
    } catch (err) {
      console.error("Worker error:", err);
      const msg = err?.message || "Internal server error";
      return corsResponse(jsonResponse(500, { error: `Worker error: ${msg}` }));
    }
  }
};
async function handleBatchTranslate(request, clientIp, env) {
  const rateLimitResult = await checkRateLimit(request, clientIp, env);
  if (rateLimitResult) return rateLimitResult;
  let body;
  try {
    body = await request.json();
  } catch {
    return jsonResponse(400, { error: "Invalid JSON body" });
  }
  const { pages, source_lang, target_lang, installation_id } = body;
  if (!Array.isArray(pages) || pages.length === 0) {
    return jsonResponse(400, { error: 'Missing "pages" array' });
  }
  if (!target_lang) {
    return jsonResponse(400, { error: 'Missing "target_lang"' });
  }
  if (pages.length > CONFIG.maxBatchPages) {
    return jsonResponse(413, { error: `Too many pages (${pages.length}). Max ${CONFIG.maxBatchPages}.` });
  }
  const quotaResult = await checkDeviceQuota(
    env.TRANSLATION_CACHE,
    installation_id,
    pages.length,
    CONFIG.dailyQuotaPerDevice
  );
  if (!quotaResult.allowed) {
    return jsonResponse(429, {
      error: "Daily free quota exceeded. Quota resets at midnight UTC.",
      quota: { pages_used: quotaResult.pagesUsed, daily_limit: quotaResult.dailyLimit, remaining: 0 },
      retry_after_hours: 24
    });
  }
  const totalChars = pages.reduce((sum, p, i) => {
    if (!p.text || typeof p.text !== "string") {
      throw new Error(`Page ${i} missing "text" field`);
    }
    return sum + p.text.length;
  }, 0);
  if (totalChars > CONFIG.maxBatchChars) {
    return jsonResponse(413, {
      error: `Total text too long (${totalChars} chars). Max ${CONFIG.maxBatchChars}.`
    });
  }
  const systemPrompt = buildBatchTranslationPrompt(source_lang || "auto", target_lang, pages.length);
  const cachedPages = await getCachedTranslations(env.TRANSLATION_CACHE, pages, target_lang || source_lang);
  if (cachedPages.size === pages.length) {
    console.log(`[cache] BATCH HIT \u2014 all ${pages.length} pages cached`);
    const cachedResults = pages.map((p) => {
      const cached = cachedPages.get(p.index);
      return {
        index: p.index,
        translated_text: cached.translated_text,
        model: cached.model,
        cached: true
      };
    });
    await incrementDeviceQuota(env.TRANSLATION_CACHE, installation_id, pages.length);
    await recordRequest(request, clientIp, env);
    const batchQuota = await checkDeviceQuota(
      env.TRANSLATION_CACHE,
      installation_id,
      0,
      CONFIG.dailyQuotaPerDevice
    );
    return jsonResponse(200, {
      translations: cachedResults,
      model: cachedPages.values().next().value.model,
      source_lang: source_lang || "auto",
      target_lang,
      cached: true,
      quota: { pages_used: batchQuota.pagesUsed, daily_limit: batchQuota.dailyLimit, remaining: batchQuota.remaining }
    });
  }
  const uncachedPages = pages.filter((p) => !cachedPages.has(p.index));
  console.log(`[cache] BATCH PARTIAL \u2014 ${cachedPages.size}/${pages.length} cached, translating ${uncachedPages.length}`);
  const userText = formatBatchPages(uncachedPages);
  const { pickKey } = resolveGeminiKeys(env);
  const geminiKey = pickKey(clientIp);
  let translatedText = null;
  let usedModel = null;
  let geminiError = null;
  if (geminiKey) {
    console.log(`[batch] Trying Gemini 3.5 Flash (${CONFIG.geminiTimeoutMs}ms timeout)...`);
    try {
      const result = await callGemini(geminiKey, systemPrompt, userText, CONFIG.geminiApiUrl);
      if (result) {
        translatedText = result;
        usedModel = CONFIG.geminiModel;
      }
    } catch (err) {
      geminiError = err.message || "Unknown error";
      console.log(`[batch] Gemini 3.5 failed: ${geminiError}`);
    }
    if (!translatedText) {
      console.log(`[batch] Trying Gemini 2.5 Flash (${CONFIG.gemini25TimeoutMs}ms timeout)...`);
      try {
        const r2 = await callGemini(geminiKey, systemPrompt, userText, CONFIG.gemini25ApiUrl);
        if (r2) {
          translatedText = r2;
          usedModel = CONFIG.gemini25Model;
        }
      } catch (err25) {
        geminiError += ` | 2.5: ${err25.message}`;
        console.log(`[batch] Gemini 2.5 failed: ${err25.message}`);
      }
    }
  }
  if (!translatedText) {
    const glmKey = env.GLM_API_KEY;
    if (!glmKey) {
      return jsonResponse(500, { error: "No translation service configured." });
    }
    console.log(`[batch] Trying GLM (${CONFIG.glmTimeoutMs}ms timeout)...`);
    try {
      const glmResult = await callGlm(glmKey, systemPrompt, userText);
      if (glmResult) {
        translatedText = glmResult;
        usedModel = CONFIG.glmModel;
      }
    } catch (err) {
      return jsonResponse(502, { error: `${geminiError ? "Gemini: " + geminiError + ". " : ""}GLM: ${err.message}` });
    }
  }
  if (!translatedText) {
    return jsonResponse(502, { error: "Empty response from all providers" });
  }
  const parsed = parseBatchResponse(translatedText, uncachedPages);
  if (parsed.length > 0) {
    const cacheEntries = parsed.map((p) => {
      const originalPage = uncachedPages.find((op) => op.index === p.index);
      return {
        sourceText: originalPage ? originalPage.text : "",
        targetLang: target_lang,
        translatedText: p.translated_text,
        model: usedModel
      };
    }).filter((e) => e.sourceText);
    await storeCachedTranslations(env.TRANSLATION_CACHE, cacheEntries);
  }
  const allResults = [];
  for (const page of pages) {
    if (cachedPages.has(page.index)) {
      const cached = cachedPages.get(page.index);
      allResults.push({ index: page.index, translated_text: cached.translated_text, model: cached.model });
    } else {
      const fresh = parsed.find((p) => p.index === page.index);
      if (fresh) {
        allResults.push({ index: fresh.index, translated_text: fresh.translated_text, model: usedModel });
      }
    }
  }
  const freshPages = Math.max(parsed.length, uncachedPages.length);
  if (freshPages > 0) {
    await incrementDeviceQuota(env.TRANSLATION_CACHE, installation_id, freshPages);
  }
  if (cachedPages.size > 0 && cachedPages.size < pages.length) {
    await incrementDeviceQuota(env.TRANSLATION_CACHE, installation_id, cachedPages.size);
  }
  await recordRequest(request, clientIp, env);
  const batchFinalQuota = await checkDeviceQuota(
    env.TRANSLATION_CACHE,
    installation_id,
    0,
    CONFIG.dailyQuotaPerDevice
  );
  return jsonResponse(200, {
    translations: allResults,
    model: usedModel,
    source_lang: source_lang || "auto",
    target_lang,
    quota: { pages_used: batchFinalQuota.pagesUsed, daily_limit: batchFinalQuota.dailyLimit, remaining: batchFinalQuota.remaining }
  });
}
__name(handleBatchTranslate, "handleBatchTranslate");
function buildBatchTranslationPrompt(sourceLang, targetLang, pageCount) {
  const langNames = {
    en: "English",
    es: "Spanish",
    fr: "French",
    de: "German",
    it: "Italian",
    pt: "Portuguese",
    ru: "Russian",
    zh: "Chinese",
    ja: "Japanese",
    ko: "Korean",
    ar: "Arabic",
    bg: "Bulgarian",
    nl: "Dutch",
    sv: "Swedish",
    pl: "Polish",
    tr: "Turkish",
    cs: "Czech",
    ro: "Romanian",
    el: "Greek",
    da: "Danish",
    fi: "Finnish",
    no: "Norwegian",
    hu: "Hungarian",
    uk: "Ukrainian"
  };
  const srcName = sourceLang === "auto" ? "the source language (auto-detect)" : langNames[sourceLang] || sourceLang;
  const tgtName = langNames[targetLang] || targetLang;
  return [
    `You are a professional literary translator translating from ${srcName} to ${tgtName}.`,
    `You produce publication-quality translations that read as if originally written in ${tgtName}.`,
    ``,
    `CORE RULES:`,
    `1. Translate the MEANING and INTENT, never word-by-word. Reconstruct sentences in ${tgtName} naturally.`,
    `2. Match the author's register, tone, and voice \u2014 whether literary, colloquial, formal, or poetic.`,
    `3. Every sentence must be grammatically perfect in ${tgtName}: correct gender agreement, case, number, articles, prepositions, verb tense and aspect.`,
    `4. Idioms and culture-specific expressions must be adapted to ${tgtName} equivalents, not translated literally.`,
    `5. Maintain paragraph breaks exactly as the source.`,
    `6. Preserve ambiguity and subtext \u2014 do not explain or simplify.`,
    `7. Character names: use the standard ${tgtName} transcription/transliteration convention.`,
    `8. Maintain CONTINUITY across pages \u2014 the same name, term, or style on page 1 must be consistent on page ${pageCount}.`,
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
    `Do NOT add any commentary, notes, or quotation marks. Only the translations with page markers.`
  ].join("\n");
}
__name(buildBatchTranslationPrompt, "buildBatchTranslationPrompt");
async function callGemini(apiKey, systemPrompt, userText, apiUrl, timeoutMs) {
  const url = `${apiUrl || CONFIG.geminiApiUrl}?key=${apiKey}`;
  const timeout = timeoutMs || (apiUrl === CONFIG.gemini25ApiUrl ? CONFIG.gemini25TimeoutMs : CONFIG.geminiTimeoutMs);
  const resp = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      systemInstruction: {
        parts: [{ text: systemPrompt }]
      },
      contents: [{
        parts: [{ text: userText }]
      }],
      generationConfig: {
        temperature: 1,
        maxOutputTokens: 16384,
        thinkingConfig: {
          thinkingBudget: 2048
        }
      }
    }),
    signal: AbortSignal.timeout(timeout)
  });
  if (resp.status === 429) {
    throw new Error("Gemini rate limited (free tier: 250 RPD)");
  }
  if (!resp.ok) {
    const errText = await resp.text().catch(() => "");
    throw new Error(`Gemini API ${resp.status}: ${errText.slice(0, 200)}`);
  }
  const data = await resp.json();
  const candidates = data?.candidates;
  if (!candidates?.length) {
    throw new Error(`Gemini returned no candidates: ${JSON.stringify(data).slice(0, 300)}`);
  }
  const parts = candidates[0].content?.parts;
  if (!parts?.length) {
    const reason = candidates[0].finishReason;
    if (reason === "SAFETY") throw new Error("Gemini blocked by safety filter");
    throw new Error(`Gemini returned empty parts: ${JSON.stringify(data).slice(0, 300)}`);
  }
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
__name(callGemini, "callGemini");
async function callGlm(apiKey, systemPrompt, userText) {
  const resp = await fetch(CONFIG.glmApiUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${apiKey}`
    },
    body: JSON.stringify({
      model: CONFIG.glmModel,
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userText }
      ],
      temperature: 0.4,
      max_tokens: 4096,
      // Disable thinking/reasoning to get direct translations — no reasoning_content overhead
      thinking: { type: "disabled" }
    }),
    signal: AbortSignal.timeout(CONFIG.glmTimeoutMs)
  });
  if (resp.status === 429) {
    throw new Error("GLM rate limited");
  }
  if (!resp.ok) {
    const errText = await resp.text().catch(() => "");
    throw new Error(`GLM API ${resp.status}: ${errText.slice(0, 200)}`);
  }
  const data = await resp.json();
  let text = data?.choices?.[0]?.message?.content?.trim();
  if (!text && data?.choices?.[0]?.message?.reasoning_content) {
    const reasoning = data.choices[0].message.reasoning_content;
    const lastLine = reasoning.split("\n").filter((l) => l.trim()).pop() || "";
    text = lastLine.replace(/\*\*/g, "").replace(/^[-*]\s*/, "").trim();
  }
  if (!text) {
    throw new Error(`GLM returned empty response: ${JSON.stringify(data).slice(0, 300)}`);
  }
  return text;
}
__name(callGlm, "callGlm");
function buildTranslationPrompt(sourceLang, targetLang) {
  const langNames = {
    en: "English",
    es: "Spanish",
    fr: "French",
    de: "German",
    it: "Italian",
    pt: "Portuguese",
    ru: "Russian",
    zh: "Chinese",
    ja: "Japanese",
    ko: "Korean",
    ar: "Arabic",
    bg: "Bulgarian",
    nl: "Dutch",
    sv: "Swedish",
    pl: "Polish",
    tr: "Turkish",
    cs: "Czech",
    ro: "Romanian",
    el: "Greek",
    da: "Danish",
    fi: "Finnish",
    no: "Norwegian",
    hu: "Hungarian",
    uk: "Ukrainian"
  };
  const srcName = sourceLang === "auto" ? "the source language (auto-detect)" : langNames[sourceLang] || sourceLang;
  const tgtName = langNames[targetLang] || targetLang;
  return [
    `You are a professional literary translator translating from ${srcName} to ${tgtName}.`,
    `You produce publication-quality translations that read as if originally written in ${tgtName}.`,
    ``,
    `CORE RULES:`,
    `1. Translate the MEANING and INTENT, never word-by-word. Reconstruct sentences in ${tgtName} naturally.`,
    `2. Match the author's register, tone, and voice \u2014 whether literary, colloquial, formal, or poetic.`,
    `3. Every sentence must be grammatically perfect in ${tgtName}: correct gender agreement, case, number, articles, prepositions, verb tense and aspect.`,
    `4. Idioms and culture-specific expressions must be adapted to ${tgtName} equivalents, not translated literally.`,
    `5. Maintain paragraph breaks exactly as the source.`,
    `6. Preserve ambiguity and subtext \u2014 do not explain or simplify.`,
    `7. Character names: use the standard ${tgtName} transcription/transliteration convention.`,
    ``,
    `OUTPUT: ONLY the translated text. No notes, no commentary, no quotation marks around the result.`
  ].join("\n");
}
__name(buildTranslationPrompt, "buildTranslationPrompt");
async function checkRateLimit(request, clientIp, env) {
  const cacheKey = getCacheKey(clientIp);
  const cache = caches.default;
  const cached = await cache.match(cacheKey);
  if (cached) {
    const data = await cached.json();
    if (data.count >= CONFIG.dailyLimitPerIp) {
      return jsonResponse(429, {
        error: "Daily translation limit reached. Try again tomorrow.",
        retry_after_hours: 24
      });
    }
    const elapsed = Date.now() - data.lastRequest;
    if (elapsed < CONFIG.cooldownMs) {
      return jsonResponse(429, {
        error: "Too fast. Please wait a moment.",
        retry_after_ms: CONFIG.cooldownMs - elapsed
      });
    }
  }
  return null;
}
__name(checkRateLimit, "checkRateLimit");
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
      "Content-Type": "application/json",
      "Cache-Control": "s-maxage=86400"
    }
  });
  try {
    await cache.put(cacheKey, response);
  } catch {
  }
}
__name(recordRequest, "recordRequest");
function getCacheKey(clientIp) {
  const today = (/* @__PURE__ */ new Date()).toISOString().slice(0, 10);
  return new Request(`https://rate-limit.dualreader.internal/${today}/${clientIp}`);
}
__name(getCacheKey, "getCacheKey");
function jsonResponse(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" }
  });
}
__name(jsonResponse, "jsonResponse");
async function testGlm(env) {
  const key = env.GLM_API_KEY;
  if (!key) return jsonResponse(500, { error: "No GLM_API_KEY secret" });
  const results = {};
  const endpoints = [
    ["z.ai/paas", "https://api.z.ai/api/paas/v4/chat/completions"],
    ["bigmodel", "https://open.bigmodel.cn/api/paas/v4/chat/completions"]
  ];
  for (const [name, url] of endpoints) {
    const start = Date.now();
    try {
      const resp = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${key}`
        },
        body: JSON.stringify({
          model: "glm-4.7-flash",
          messages: [{ role: "user", content: "Say OK" }],
          max_tokens: 10,
          thinking: { type: "disabled" }
        }),
        signal: AbortSignal.timeout(1e4)
      });
      const text = await resp.text();
      results[name] = {
        status: resp.status,
        time_ms: Date.now() - start,
        body: text.slice(0, 200)
      };
    } catch (err) {
      results[name] = {
        status: "error",
        time_ms: Date.now() - start,
        error: err.message
      };
    }
  }
  return jsonResponse(200, { key_prefix: key.slice(0, 8), results });
}
__name(testGlm, "testGlm");
function corsResponse(response) {
  response.headers.set("Access-Control-Allow-Origin", "*");
  response.headers.set("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
  response.headers.set("Access-Control-Allow-Headers", "Content-Type");
  return response;
}
__name(corsResponse, "corsResponse");

// node_modules/wrangler/templates/middleware/middleware-ensure-req-body-drained.ts
var drainBody = /* @__PURE__ */ __name(async (request, env, _ctx, middlewareCtx) => {
  try {
    return await middlewareCtx.next(request, env);
  } finally {
    try {
      if (request.body !== null && !request.bodyUsed) {
        const reader = request.body.getReader();
        while (!(await reader.read()).done) {
        }
      }
    } catch (e) {
      console.error("Failed to drain the unused request body.", e);
    }
  }
}, "drainBody");
var middleware_ensure_req_body_drained_default = drainBody;

// node_modules/wrangler/templates/middleware/middleware-miniflare3-json-error.ts
function reduceError(e) {
  return {
    name: e?.name,
    message: e?.message ?? String(e),
    stack: e?.stack,
    cause: e?.cause === void 0 ? void 0 : reduceError(e.cause)
  };
}
__name(reduceError, "reduceError");
var jsonError = /* @__PURE__ */ __name(async (request, env, _ctx, middlewareCtx) => {
  try {
    return await middlewareCtx.next(request, env);
  } catch (e) {
    const error = reduceError(e);
    return Response.json(error, {
      status: 500,
      headers: { "MF-Experimental-Error-Stack": "true" }
    });
  }
}, "jsonError");
var middleware_miniflare3_json_error_default = jsonError;

// .wrangler/tmp/bundle-p6KxR0/middleware-insertion-facade.js
var __INTERNAL_WRANGLER_MIDDLEWARE__ = [
  middleware_ensure_req_body_drained_default,
  middleware_miniflare3_json_error_default
];
var middleware_insertion_facade_default = src_default;

// node_modules/wrangler/templates/middleware/common.ts
var __facade_middleware__ = [];
function __facade_register__(...args) {
  __facade_middleware__.push(...args.flat());
}
__name(__facade_register__, "__facade_register__");
function __facade_invokeChain__(request, env, ctx, dispatch, middlewareChain) {
  const [head, ...tail] = middlewareChain;
  const middlewareCtx = {
    dispatch,
    next(newRequest, newEnv) {
      return __facade_invokeChain__(newRequest, newEnv, ctx, dispatch, tail);
    }
  };
  return head(request, env, ctx, middlewareCtx);
}
__name(__facade_invokeChain__, "__facade_invokeChain__");
function __facade_invoke__(request, env, ctx, dispatch, finalMiddleware) {
  return __facade_invokeChain__(request, env, ctx, dispatch, [
    ...__facade_middleware__,
    finalMiddleware
  ]);
}
__name(__facade_invoke__, "__facade_invoke__");

// .wrangler/tmp/bundle-p6KxR0/middleware-loader.entry.ts
var __Facade_ScheduledController__ = class ___Facade_ScheduledController__ {
  constructor(scheduledTime, cron, noRetry) {
    this.scheduledTime = scheduledTime;
    this.cron = cron;
    this.#noRetry = noRetry;
  }
  static {
    __name(this, "__Facade_ScheduledController__");
  }
  #noRetry;
  noRetry() {
    if (!(this instanceof ___Facade_ScheduledController__)) {
      throw new TypeError("Illegal invocation");
    }
    this.#noRetry();
  }
};
function wrapExportedHandler(worker) {
  if (__INTERNAL_WRANGLER_MIDDLEWARE__ === void 0 || __INTERNAL_WRANGLER_MIDDLEWARE__.length === 0) {
    return worker;
  }
  for (const middleware of __INTERNAL_WRANGLER_MIDDLEWARE__) {
    __facade_register__(middleware);
  }
  const fetchDispatcher = /* @__PURE__ */ __name(function(request, env, ctx) {
    if (worker.fetch === void 0) {
      throw new Error("Handler does not export a fetch() function.");
    }
    return worker.fetch(request, env, ctx);
  }, "fetchDispatcher");
  return {
    ...worker,
    fetch(request, env, ctx) {
      const dispatcher = /* @__PURE__ */ __name(function(type, init) {
        if (type === "scheduled" && worker.scheduled !== void 0) {
          const controller = new __Facade_ScheduledController__(
            Date.now(),
            init.cron ?? "",
            () => {
            }
          );
          return worker.scheduled(controller, env, ctx);
        }
      }, "dispatcher");
      return __facade_invoke__(request, env, ctx, dispatcher, fetchDispatcher);
    }
  };
}
__name(wrapExportedHandler, "wrapExportedHandler");
function wrapWorkerEntrypoint(klass) {
  if (__INTERNAL_WRANGLER_MIDDLEWARE__ === void 0 || __INTERNAL_WRANGLER_MIDDLEWARE__.length === 0) {
    return klass;
  }
  for (const middleware of __INTERNAL_WRANGLER_MIDDLEWARE__) {
    __facade_register__(middleware);
  }
  return class extends klass {
    #fetchDispatcher = /* @__PURE__ */ __name((request, env, ctx) => {
      this.env = env;
      this.ctx = ctx;
      if (super.fetch === void 0) {
        throw new Error("Entrypoint class does not define a fetch() function.");
      }
      return super.fetch(request);
    }, "#fetchDispatcher");
    #dispatcher = /* @__PURE__ */ __name((type, init) => {
      if (type === "scheduled" && super.scheduled !== void 0) {
        const controller = new __Facade_ScheduledController__(
          Date.now(),
          init.cron ?? "",
          () => {
          }
        );
        return super.scheduled(controller);
      }
    }, "#dispatcher");
    fetch(request) {
      return __facade_invoke__(
        request,
        this.env,
        this.ctx,
        this.#dispatcher,
        this.#fetchDispatcher
      );
    }
  };
}
__name(wrapWorkerEntrypoint, "wrapWorkerEntrypoint");
var WRAPPED_ENTRY;
if (typeof middleware_insertion_facade_default === "object") {
  WRAPPED_ENTRY = wrapExportedHandler(middleware_insertion_facade_default);
} else if (typeof middleware_insertion_facade_default === "function") {
  WRAPPED_ENTRY = wrapWorkerEntrypoint(middleware_insertion_facade_default);
}
var middleware_loader_entry_default = WRAPPED_ENTRY;
export {
  __INTERNAL_WRANGLER_MIDDLEWARE__,
  middleware_loader_entry_default as default
};
//# sourceMappingURL=index.js.map
