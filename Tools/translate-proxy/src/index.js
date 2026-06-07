/**
 * Dual Reader Translation Proxy — Cloudflare Worker
 *
 * Sits between the Android app and Z.AI's GLM API.
 * Keeps the API key server-side so it's never exposed in the APK.
 *
 * Rate limits per IP using Cloudflare Cache API (no Durable Objects needed).
 * GLM-4.7-Flash is free ($0.00), so cost risk is low — this just prevents abuse.
 */

// ─── Config ──────────────────────────────────────────────────────────────────

const CONFIG = {
  // Z.AI API endpoint (GLM-4.7-Flash = free tier)
  glmApiUrl: 'https://open.bigmodel.cn/api/paas/v4/chat/completions',
  glmModel: 'glm-4.7-flash',

  // Rate limiting
  maxTextLength: 5000,        // chars per request
  dailyLimitPerIp: 200,       // requests per IP per day
  cooldownMs: 2000,           // min 2s between requests from same IP

  // CORS
  allowedOrigins: ['*'],      // Android app doesn't send Origin, but be safe
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

      // 3. Call Z.AI API
      const apiKey = env.GLM_API_KEY;
      if (!apiKey) {
        console.error('GLM_API_KEY not configured');
        return corsResponse(jsonResponse(500, { error: 'Translation service not configured' }));
      }

      const systemPrompt = buildTranslationPrompt(source_lang || 'auto', target_lang);

      const glmResponse = await fetch(CONFIG.glmApiUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model: CONFIG.glmModel,
          messages: [
            { role: 'system', content: systemPrompt },
            { role: 'user', content: text },
          ],
          temperature: 0.3,
          max_tokens: 4096,
        }),
      });

      if (!glmResponse.ok) {
        const errorText = await glmResponse.text();
        console.error(`Z.AI API error ${glmResponse.status}: ${errorText}`);
        return corsResponse(jsonResponse(502, { error: 'Translation API error' }));
      }

      const glmData = await glmResponse.json();
      const message = glmData?.choices?.[0]?.message;
      // GLM-4.7-Flash uses reasoning_content for chain-of-thought, content for the answer.
      // If content is empty, the model may have spent all tokens on reasoning — try without CoT.
      let translatedText = message?.content?.trim();
      
      // If content is empty but finish_reason is "length", the reasoning ate all the tokens.
      // Try extracting from reasoning as last resort.
      if (!translatedText && message?.reasoning_content) {
        // The reasoning often contains the translation at the end
        const reasoning = message.reasoning_content;
        const lastLine = reasoning.split('\\n').filter(l => l.trim()).pop() || '';
        // Clean up markdown formatting from reasoning
        translatedText = lastLine.replace(/\*\*/g, '').replace(/^[-*]\s*/, '').trim();
      }

      if (!translatedText) {
        console.error('Empty translation response:', JSON.stringify(glmData).slice(0, 500));
        return corsResponse(jsonResponse(502, { error: 'Empty translation response' }));
      }

      // 4. Record this request for rate limiting
      await recordRequest(request, clientIp, env);

      return corsResponse(jsonResponse(200, {
        translated_text: translatedText,
        model: CONFIG.glmModel,
        source_lang: source_lang || 'auto',
        target_lang,
      }));

    } catch (err) {
      console.error('Worker error:', err);
      return corsResponse(jsonResponse(500, { error: 'Internal server error' }));
    }
  },
};

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
    `You are a professional literary translator.`,
    `Translate the following text from ${srcName} to ${tgtName}.`,
    `Preserve the tone, style, and literary quality of the original.`,
    `Output ONLY the translation — no explanations, no notes, no quotation marks around the result.`,
  ].join(' ');
}

// ─── Rate Limiting (Cache API) ───────────────────────────────────────────────

async function checkRateLimit(request, clientIp, env) {
  const cacheKey = getCacheKey(clientIp);
  const cache = caches.default;

  // Check daily count
  const cached = await cache.match(cacheKey);
  if (cached) {
    const data = await cached.json();
    if (data.count >= CONFIG.dailyLimitPerIp) {
      return jsonResponse(429, {
        error: 'Daily translation limit reached. Try again tomorrow.',
        retry_after_hours: 24,
      });
    }
    // Check cooldown (min 2s between requests)
    const elapsed = Date.now() - data.lastRequest;
    if (elapsed < CONFIG.cooldownMs) {
      return jsonResponse(429, {
        error: 'Too fast. Please wait a moment.',
        retry_after_ms: CONFIG.cooldownMs - elapsed,
      });
    }
  }

  return null; // OK to proceed
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

  // Store for 24 hours (Cache API respects max-age via response headers)
  const response = new Response(JSON.stringify({ count, lastRequest: Date.now() }), {
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 's-maxage=86400', // 24 hours
    },
  });

  // Use waitUntil so it doesn't block the response
  try {
    await cache.put(cacheKey, response);
  } catch {
    // Cache API might not be available in all environments
  }
}

function getCacheKey(clientIp) {
  // Use a fixed date (midnight UTC today) so the key rotates daily
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
