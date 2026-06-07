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

// ─── Config ──────────────────────────────────────────────────────────────────

const CONFIG = {
  // Rate limiting (per IP)
  maxTextLength: 10000,         // chars per request
  dailyLimitPerIp: 500,        // requests per IP per day
  cooldownMs: 3000,            // min 3s between requests from same IP

  // Provider timeouts (CF Workers have 30s total)
  geminiTimeoutMs: 25000,
  glmTimeoutMs: 20000,

  // Provider endpoints
  geminiApiUrl: 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent',
  glmApiUrl: 'https://open.bigmodel.cn/api/paas/v4/chat/completions',

  // Models
  geminiModel: 'gemini-2.5-flash',
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

    // Only accept POST on /translate
    if (request.method !== 'POST' || !new URL(request.url).pathname.startsWith('/translate')) {
      return corsResponse(jsonResponse(404, { error: 'Not found. Use POST /translate' }));
    }

    const clientIp = request.headers.get('CF-Connecting-IP') || 'unknown';

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

      // ── Attempt 1: Gemini 2.5 Flash (free, high quality) ──────────────
      const geminiKey = env.GEMINI_API_KEY;
      if (geminiKey) {
        try {
          const geminiResult = await callGemini(geminiKey, systemPrompt, text);
          if (geminiResult) {
            translatedText = geminiResult;
            usedModel = CONFIG.geminiModel;
          }
        } catch (err) {
          geminiError = err.message || 'Unknown Gemini error';
          console.warn(`Gemini failed, falling back to GLM: ${geminiError}`);
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

// ─── Gemini Provider ─────────────────────────────────────────────────────────

async function callGemini(apiKey, systemPrompt, userText) {
  const url = `${CONFIG.geminiApiUrl}?key=${apiKey}`;

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
        temperature: 0.4,
        maxOutputTokens: 8192,
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
  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text?.trim();
  if (!text) {
    // Check if blocked by safety
    const reason = data?.candidates?.[0]?.finishReason;
    if (reason === 'SAFETY') {
      throw new Error('Gemini blocked by safety filter');
    }
    throw new Error(`Gemini returned empty response: ${JSON.stringify(data).slice(0, 300)}`);
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
    `You are an expert literary translator specializing in ${srcName} to ${tgtName}.`,
    `You have deep knowledge of both literary traditions and a gift for preserving the author's voice across languages.`,
    ``,
    `TRANSLATION PRINCIPLES:`,
    `1. Prioritize natural, flowing ${tgtName} over word-for-word accuracy`,
    `2. Preserve the author's tone — whether poetic, spare, humorous, or lyrical`,
    `3. Adapt idioms and cultural references to ${tgtName} equivalents where a literal rendering would sound foreign`,
    `4. Maintain the rhythm, cadence, and pacing of the original prose`,
    `5. Use register and vocabulary appropriate to the text's literary genre and era`,
    `6. When the original uses deliberate repetition, alliteration, or sound devices, recreate the effect in ${tgtName}`,
    `7. Preserve ambiguity and subtext — do not over-explain or simplify`,
    ``,
    `OUTPUT: ONLY the translated text. No commentary, no notes, no quotation marks around the result. Same paragraph structure as the source.`,
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
