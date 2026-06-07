var __defProp = Object.defineProperty;
var __name = (target, value) => __defProp(target, "name", { value, configurable: true });

// src/index.js
var CONFIG = {
  // Z.AI API endpoint (GLM-4.7-Flash = free tier)
  glmApiUrl: "https://open.bigmodel.cn/api/paas/v4/chat/completions",
  glmModel: "glm-4.7-flash",
  // Rate limiting
  maxTextLength: 5e3,
  // chars per request
  dailyLimitPerIp: 200,
  // requests per IP per day
  cooldownMs: 2e3,
  // min 2s between requests from same IP
  // CORS
  allowedOrigins: ["*"]
  // Android app doesn't send Origin, but be safe
};
var src_default = {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return corsResponse(new Response(null, { status: 204 }));
    }
    if (request.method !== "POST" || !new URL(request.url).pathname.startsWith("/translate")) {
      return corsResponse(jsonResponse(404, { error: "Not found. Use POST /translate" }));
    }
    const clientIp = request.headers.get("CF-Connecting-IP") || "unknown";
    try {
      const rateLimitResult = await checkRateLimit(request, clientIp, env);
      if (rateLimitResult) return corsResponse(rateLimitResult);
      let body;
      try {
        body = await request.json();
      } catch {
        return corsResponse(jsonResponse(400, { error: "Invalid JSON body" }));
      }
      const { text, source_lang, target_lang } = body;
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
      const apiKey = env.GLM_API_KEY;
      if (!apiKey) {
        console.error("GLM_API_KEY not configured");
        return corsResponse(jsonResponse(500, { error: "Translation service not configured" }));
      }
      const systemPrompt = buildTranslationPrompt(source_lang || "auto", target_lang);
      const glmResponse = await fetch(CONFIG.glmApiUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${apiKey}`
        },
        body: JSON.stringify({
          model: CONFIG.glmModel,
          messages: [
            { role: "system", content: systemPrompt },
            { role: "user", content: text }
          ],
          temperature: 0.3,
          max_tokens: 4096
        })
      });
      if (!glmResponse.ok) {
        const errorText = await glmResponse.text();
        console.error(`Z.AI API error ${glmResponse.status}: ${errorText}`);
        return corsResponse(jsonResponse(502, { error: "Translation API error" }));
      }
      const glmData = await glmResponse.json();
      const message = glmData?.choices?.[0]?.message;
      let translatedText = message?.content?.trim();
      if (!translatedText && message?.reasoning_content) {
        const reasoning = message.reasoning_content;
        const lastLine = reasoning.split("\\n").filter((l) => l.trim()).pop() || "";
        translatedText = lastLine.replace(/\*\*/g, "").replace(/^[-*]\s*/, "").trim();
      }
      if (!translatedText) {
        console.error("Empty translation response:", JSON.stringify(glmData).slice(0, 500));
        return corsResponse(jsonResponse(502, { error: "Empty translation response" }));
      }
      await recordRequest(request, clientIp, env);
      return corsResponse(jsonResponse(200, {
        translated_text: translatedText,
        model: CONFIG.glmModel,
        source_lang: source_lang || "auto",
        target_lang
      }));
    } catch (err) {
      console.error("Worker error:", err);
      return corsResponse(jsonResponse(500, { error: "Internal server error" }));
    }
  }
};
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
    `You are a professional literary translator.`,
    `Translate the following text from ${srcName} to ${tgtName}.`,
    `Preserve the tone, style, and literary quality of the original.`,
    `Output ONLY the translation \u2014 no explanations, no notes, no quotation marks around the result.`
  ].join(" ");
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
      // 24 hours
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
function corsResponse(response) {
  response.headers.set("Access-Control-Allow-Origin", "*");
  response.headers.set("Access-Control-Allow-Methods", "POST, OPTIONS");
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

// .wrangler/tmp/bundle-bKREO2/middleware-insertion-facade.js
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

// .wrangler/tmp/bundle-bKREO2/middleware-loader.entry.ts
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
