const STORE_KEY = "store";

const CLIENT_COLLECTIONS = new Set([
  "settings",
  "habits",
  "dailyTasks",
  "mealRecords",
  "workoutRecords",
  "sleepRecords",
  "waterRecords",
  "weightRecords",
  "supplementRecords",
  "measurementRecords",
  "dailyStrategies",
  "weeklyReviews",
  "trainingCycles",
]);

const DEFAULT_STORE = {
  users: [
    {
      id: "usr_demo_001",
      name: "Maya",
      email: "maya@example.com",
      locale: "zh-Hans",
      plan: "531 Carb Step-down",
      mode: "lifestyle",
      status: "active",
      subscription: "pro_monthly",
      registeredAt: "2026-06-16T00:00:00Z",
      deletedAt: null,
      deleteReason: null,
      createdAt: "2026-06-16T00:00:00Z",
      updatedAt: "2026-06-16T00:00:00Z",
      lastSeenAt: "2026-06-16T08:00:00Z",
    },
  ],
  plans: [
    {
      id: "lifestyleCut",
      name: "Lifestyle Cut",
      nameZh: "生活化减脂",
      dailyDeficit: 450,
      engine: {
        bmrFormula: "mifflin_st_jeor",
        activityMultiplierMin: 1.2,
        activityMultiplierMax: 1.55,
        safetyFloorCalories: 1200,
        targetDeficitTolerance: 120,
      },
      macroRules: { proteinPerKg: 1.5, fatRatio: 0.28, carbFloorGrams: 80 },
      guardrails: ["Prioritize protein", "Keep dinner light", "Save leftovers if full"],
      difficulty: 1,
      enabled: true,
    },
    {
      id: "carbStepDown",
      name: "531 Carb Step-down",
      nameZh: "531 碳水渐降",
      dailyDeficit: 520,
      engine: {
        bmrFormula: "mifflin_st_jeor",
        activityMultiplierMin: 1.18,
        activityMultiplierMax: 1.5,
        safetyFloorCalories: 1200,
        targetDeficitTolerance: 120,
      },
      macroRules: { proteinPerKg: 1.7, fatRatio: 0.32, carbFloorGrams: 70 },
      guardrails: ["Protein first", "Half rice at dinner", "Keep sauces light"],
      difficulty: 3,
      enabled: true,
    },
    {
      id: "highProtein",
      name: "High Protein",
      nameZh: "高蛋白控热量",
      dailyDeficit: 400,
      engine: {
        bmrFormula: "mifflin_st_jeor",
        activityMultiplierMin: 1.22,
        activityMultiplierMax: 1.65,
        safetyFloorCalories: 1200,
        targetDeficitTolerance: 120,
      },
      macroRules: { proteinPerKg: 1.9, fatRatio: 0.27, carbFloorGrams: 90 },
      guardrails: ["Finish protein", "Add vegetables", "Keep snacks simple"],
      difficulty: 2,
      enabled: true,
    },
  ],
  subscriptions: [
    {
      id: "free",
      name: "Free",
      productId: "com.mealkind.free",
      price: 0,
      currency: "USD",
      period: "none",
      features: ["basic_scan", "daily_gap"],
      enabled: true,
    },
    {
      id: "pro_monthly",
      name: "MealKind Pro Monthly",
      productId: "com.mealkind.pro.monthly",
      price: 4.99,
      currency: "USD",
      period: "monthly",
      features: ["macro_tracking", "ai_chat", "weekly_review"],
      enabled: true,
    },
    {
      id: "pro_yearly",
      name: "MealKind Pro Yearly",
      productId: "com.mealkind.pro.yearly",
      price: 39.99,
      currency: "USD",
      period: "yearly",
      features: ["macro_tracking", "ai_chat", "weekly_review"],
      enabled: true,
    },
  ],
  aiModels: [
    {
      id: "vision_food_default",
      name: "Food Vision Default",
      provider: "openai-compatible",
      model: "gpt-4.1-mini",
      purpose: "food_analysis",
      temperature: 0.2,
      timeoutSeconds: 18,
      enabled: true,
    },
    {
      id: "coach_chat_default",
      name: "Coach Chat Default",
      provider: "openai-compatible",
      model: "gpt-4.1-mini",
      purpose: "coach_chat",
      temperature: 0.5,
      timeoutSeconds: 20,
      enabled: true,
    },
  ],
  settings: {
    aiProvider: "mock-json",
    maxImageBytes: 5242880,
    defaultLocale: "zh-Hans",
    maintenanceMode: false,
    registrationEnabled: true,
    accountDeletionEnabled: true,
    supportEmail: "support@mealkind.app",
    minimumSupportedAppVersion: "0.1.0",
  },
  analysisLogs: [],
  systemLogs: [
    {
      id: "evt_demo_001",
      level: "info",
      source: "backend",
      message: "MealKind Cloudflare backend initialized",
      createdAt: "2026-06-16T00:00:00Z",
    },
  ],
  issues: [
    {
      id: "iss_demo_001",
      title: "AI 分析结果偏保守",
      status: "open",
      severity: "medium",
      owner: "ops",
      createdAt: "2026-06-16T00:00:00Z",
      updatedAt: "2026-06-16T00:00:00Z",
    },
  ],
  notifications: [
    {
      id: "ntf_demo_001",
      title: "欢迎使用 MealKind",
      body: "后台通知中心已启用。",
      audience: "all",
      status: "draft",
      createdAt: "2026-06-16T00:00:00Z",
      updatedAt: "2026-06-16T00:00:00Z",
    },
  ],
  clientTokens: {},
  adminTokens: {},
  clientData: {},
};

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === "OPTIONS") return empty(204);

    try {
      const context = { request, env, url };
      if (url.pathname === "/health") {
        return json({ ok: true, service: "MealKind Cloudflare Backend", time: utcNow() });
      }
      if (url.pathname.startsWith("/data/uploads/")) {
        return serveUpload(url.pathname, env);
      }
      if (url.pathname.startsWith("/assets/")) {
        return serveAsset(request, env);
      }
      if (url.pathname.startsWith("/api/")) {
        if (request.method === "GET") return handleGet(context);
        if (request.method === "POST") return handlePost(context);
        if (request.method === "PATCH") return handlePatch(context);
        if (request.method === "DELETE") return handleDelete(context);
        return error(405, "Method not allowed");
      }
      if (isAdminRequest(url)) {
        return serveAdminAsset(request, env);
      }
      if (url.pathname === "/") {
        return html(apiLandingHtml(request.url));
      }
      return error(405, "Method not allowed");
    } catch (err) {
      return error(500, err?.message || "Internal server error");
    }
  },
};

function isAdminRequest(url) {
  return url.hostname === "admin.mefitai.fit" || url.pathname === "/admin" || url.pathname.startsWith("/admin/");
}

function serveAdminAsset(request, env) {
  if (!env.ASSETS) return html(apiLandingHtml(request.url));
  const url = new URL(request.url);
  if (url.pathname === "/" || url.pathname === "/admin" || url.pathname === "/admin/") {
    url.pathname = "/admin.html";
  }
  return env.ASSETS.fetch(new Request(url, request));
}

function serveAsset(request, env) {
  if (!env.ASSETS) return error(404, "Asset not found");
  const url = new URL(request.url);
  if (url.pathname.startsWith("/assets/")) {
    url.pathname = "/" + url.pathname.slice("/assets/".length);
  }
  return env.ASSETS.fetch(new Request(url, request));
}

async function handleGet(context) {
  const { url } = context;
  const path = url.pathname;
  if (path === "/api/client/me") return withClient(context, (userId) => clientMe(context, userId));
  if (path === "/api/client/export") return withClient(context, (userId) => clientExport(context, userId));
  if (path.startsWith("/api/client/records/")) {
    const collection = path.split("/").pop();
    return withClient(context, (userId) => listClientRecords(context, userId, collection));
  }
  if (path === "/api/admin/overview") return withAdmin(context, () => adminOverview(context));
  if (path === "/api/admin/users") return withAdmin(context, async () => json((await loadStore(context.env)).users.map(safeUser)));
  if (path === "/api/admin/plans") return withAdmin(context, async () => json((await loadStore(context.env)).plans));
  if (path === "/api/admin/subscriptions") return withAdmin(context, async () => json((await loadStore(context.env)).subscriptions));
  if (path === "/api/admin/ai-models") return withAdmin(context, async () => json((await loadStore(context.env)).aiModels));
  if (path === "/api/admin/settings") return withAdmin(context, async () => json((await loadStore(context.env)).settings));
  if (path === "/api/admin/analysis-logs") {
    return withAdmin(context, async () => json((await loadStore(context.env)).analysisLogs.slice(-80).reverse()));
  }
  if (path === "/api/admin/system-logs") {
    return withAdmin(context, async () => json((await loadStore(context.env)).systemLogs.slice(-120).reverse()));
  }
  if (path === "/api/admin/issues") return withAdmin(context, async () => json((await loadStore(context.env)).issues));
  if (path === "/api/admin/notifications") return withAdmin(context, async () => json((await loadStore(context.env)).notifications));
  return error(404, "Not found");
}

async function handlePost(context) {
  const body = await readJson(context.request);
  const path = context.url.pathname;
  if (path === "/api/auth/login") return login(context, body);
  if (path === "/api/client/register") return clientRegister(context, body);
  if (path === "/api/client/login") return clientLogin(context, body);
  if (path === "/api/client/session") return clientSession(context, body);
  if (path === "/api/client/sync") return withClient(context, (userId) => clientSync(context, userId, body));
  if (path === "/api/client/clear") return withClient(context, (userId) => clientClear(context, userId));
  if (path === "/api/client/delete-account") {
    return withClient(context, (userId) => clientDeleteAccount(context, userId, body));
  }
  if (path.startsWith("/api/client/records/")) {
    const collection = path.split("/").pop();
    return withClient(context, (userId) => upsertClientRecord(context, userId, collection, body));
  }
  if (path === "/api/ai/food-analysis") return foodAnalysis(context, body);
  if (path === "/api/ai/smart-scan") return smartScan(body);
  if (path === "/api/admin/users") return withAdmin(context, () => createUser(context, body));
  if (path === "/api/admin/plans") return withAdmin(context, () => replaceCollection(context, "plans", body));
  if (path === "/api/admin/subscriptions") return withAdmin(context, () => replaceCollection(context, "subscriptions", body));
  if (path === "/api/admin/ai-models") return withAdmin(context, () => replaceCollection(context, "aiModels", body));
  if (path === "/api/admin/settings") return withAdmin(context, () => replaceSettings(context, body));
  if (path === "/api/admin/issues") return withAdmin(context, () => createRecord(context, "issues", body, "iss"));
  if (path === "/api/admin/notifications") return withAdmin(context, () => createRecord(context, "notifications", body, "ntf"));
  return error(404, "Not found");
}

async function handlePatch(context) {
  const body = await readJson(context.request);
  const path = context.url.pathname;
  if (path.startsWith("/api/admin/users/")) {
    return withAdmin(context, () => patchUser(context, path.split("/").pop(), body));
  }
  if (path.startsWith("/api/client/records/")) {
    const parts = path.split("/");
    return withClient(context, (userId) => patchClientRecord(context, userId, parts.at(-2), parts.at(-1), body));
  }
  if (path.startsWith("/api/admin/issues/")) {
    return withAdmin(context, () => patchRecord(context, "issues", path.split("/").pop(), body));
  }
  if (path.startsWith("/api/admin/notifications/")) {
    return withAdmin(context, () => patchRecord(context, "notifications", path.split("/").pop(), body));
  }
  return error(404, "Not found");
}

async function handleDelete(context) {
  const path = context.url.pathname;
  if (path.startsWith("/api/admin/users/")) {
    return withAdmin(context, () => deleteUser(context, path.split("/").pop()));
  }
  if (path.startsWith("/api/client/records/")) {
    const parts = path.split("/");
    return withClient(context, (userId) => deleteClientRecord(context, userId, parts.at(-2), parts.at(-1)));
  }
  if (path.startsWith("/api/admin/issues/")) {
    return withAdmin(context, () => deleteRecord(context, "issues", path.split("/").pop()));
  }
  if (path.startsWith("/api/admin/notifications/")) {
    return withAdmin(context, () => deleteRecord(context, "notifications", path.split("/").pop()));
  }
  return error(404, "Not found");
}

async function login(context, body) {
  const expectedUser = context.env.MEALKIND_ADMIN_USER || "admin";
  const expectedPassword = context.env.MEALKIND_ADMIN_PASSWORD || "mealkind-admin";
  if ((body.username || "") !== expectedUser || (body.password || "") !== expectedPassword) {
    return error(401, "Invalid credentials");
  }
  const store = await loadStore(context.env);
  const token = randomToken();
  store.adminTokens[token] = utcNow();
  await saveStore(context.env, store);
  return json({ token, role: "super_admin", user: expectedUser });
}

async function withAdmin(context, callback) {
  const token = bearerToken(context.request);
  const store = await loadStore(context.env);
  if (!token || !store.adminTokens[token]) return error(401, "Admin login required");
  return callback();
}

async function withClient(context, callback) {
  const token = bearerToken(context.request);
  const store = await loadStore(context.env);
  const userId = token ? store.clientTokens[token] : null;
  if (!userId) return error(401, "Client session required");
  if (!store.users.some((user) => user.id === userId && user.status === "active")) {
    return error(401, "User is not active");
  }
  return callback(userId);
}

async function clientSession(context, body) {
  const store = await loadStore(context.env);
  const settings = store.settings || {};
  if (settings.registrationEnabled === false) return error(403, "Registration is disabled");

  const installId = String(body.installId || "").trim();
  const email = String(body.email || "").trim().toLowerCase();
  const locale = body.locale || settings.defaultLocale || "zh-Hans";
  const now = utcNow();
  let user = store.users.find((candidate) => {
    if (candidate.status === "deleted") return false;
    return (email && candidate.email === email) || (installId && candidate.installId === installId);
  });

  if (!user) {
    user = {
      id: `usr_${hex(8)}`,
      name: body.name || (email ? email.split("@")[0] : "Guest"),
      email: email || `guest-${hex(4)}@local.mealkind`,
      installId: installId || `install_${hex(8)}`,
      locale,
      plan: body.plan || "Lifestyle Cut",
      mode: body.mode || "lifestyle",
      status: "active",
      subscription: body.subscription || "free",
      registeredAt: now,
      deletedAt: null,
      deleteReason: null,
      createdAt: now,
      updatedAt: now,
      lastSeenAt: now,
    };
    store.users.push(user);
    store.clientData[user.id] = emptyClientData();
    appendSystemLog(store, "info", "client", `Created client user ${user.id}`);
  } else {
    user.lastSeenAt = now;
    user.locale = locale;
    user.updatedAt = now;
  }

  const token = randomToken();
  store.clientTokens[token] = user.id;
  await saveStore(context.env, store);
  return json({ token, user: safeUser(user), createdAt: now });
}

async function clientRegister(context, body) {
  const store = await loadStore(context.env);
  const settings = store.settings || {};
  if (settings.registrationEnabled === false) return error(403, "Registration is disabled");

  const email = String(body.email || "").trim().toLowerCase();
  const password = String(body.password || "");
  const name = String(body.name || "").trim();
  const locale = body.locale || settings.defaultLocale || "zh-Hans";
  const installId = String(body.installId || "").trim();
  const validationError = validateClientCredentials(email, password);
  if (validationError) return error(400, validationError);
  if (store.users.some((user) => user.status !== "deleted" && user.email === email && user.passwordHash)) {
    return error(409, "Email already registered");
  }

  const now = utcNow();
  let user = store.users.find((candidate) => {
    if (candidate.status === "deleted") return false;
    return candidate.email === email || (installId && candidate.installId === installId);
  });
  if (!user) {
    user = {
      id: `usr_${hex(8)}`,
      name: name || email.split("@")[0],
      email,
      installId: installId || `install_${hex(8)}`,
      locale,
      plan: body.plan || "Lifestyle Cut",
      mode: body.mode || "lifestyle",
      status: "active",
      subscription: body.subscription || "free",
      registeredAt: now,
      deletedAt: null,
      deleteReason: null,
      createdAt: now,
      updatedAt: now,
      lastSeenAt: now,
    };
    store.users.push(user);
    store.clientData[user.id] = emptyClientData();
  }

  user.name = name || user.name || email.split("@")[0];
  user.email = email;
  user.locale = locale;
  user.installId ||= installId || `install_${hex(8)}`;
  user.status = "active";
  user.lastSeenAt = now;
  user.updatedAt = now;
  const credentials = await makePasswordCredentials(password);
  user.passwordSalt = credentials.salt;
  user.passwordHash = credentials.hash;

  const token = randomToken();
  store.clientTokens[token] = user.id;
  appendSystemLog(store, "info", "client", `Registered client user ${user.id}`);
  await saveStore(context.env, store);
  return json({ token, user: safeUser(user), createdAt: now }, 201);
}

async function clientLogin(context, body) {
  const store = await loadStore(context.env);
  const email = String(body.email || "").trim().toLowerCase();
  const password = String(body.password || "");
  if (!email || !password) return error(400, "Email and password are required");

  const user = store.users.find((candidate) => candidate.status !== "deleted" && candidate.email === email);
  if (!user || !user.passwordHash || !user.passwordSalt) return error(401, "Invalid credentials");
  const expectedHash = await passwordHash(password, user.passwordSalt);
  if (expectedHash !== user.passwordHash) return error(401, "Invalid credentials");

  const now = utcNow();
  user.status = "active";
  user.locale = body.locale || user.locale || store.settings?.defaultLocale || "zh-Hans";
  user.lastSeenAt = now;
  user.updatedAt = now;
  const token = randomToken();
  store.clientTokens[token] = user.id;
  appendSystemLog(store, "info", "client", `Signed in client user ${user.id}`);
  await saveStore(context.env, store);
  return json({ token, user: safeUser(user), createdAt: now });
}

async function clientMe(context, userId) {
  const store = await loadStore(context.env);
  const user = userById(store, userId);
  if (!user) return error(404, "User not found");
  return json({ user: safeUser(user) });
}

async function clientExport(context, userId) {
  const store = await loadStore(context.env);
  store.clientData[userId] ||= emptyClientData();
  await saveStore(context.env, store);
  return json({ user: safeUser(userById(store, userId) || {}), data: store.clientData[userId], exportedAt: utcNow() });
}

async function clientSync(context, userId, body) {
  if (!Array.isArray(body.records)) return error(400, "Expected records array");
  const store = await loadStore(context.env);
  const clientData = store.clientData[userId] || emptyClientData();
  if (body.replaceAll === true) {
    for (const collection of CLIENT_COLLECTIONS) clientData[collection] = [];
  }

  let upserted = 0;
  let deleted = 0;
  for (const item of body.records) {
    if (!item || typeof item !== "object" || !CLIENT_COLLECTIONS.has(item.collection)) continue;
    if (!item.payload || typeof item.payload !== "object") continue;
    const collection = item.collection;
    const payload = { ...item.payload, id: String(item.id || item.payload.id || hex(8)) };
    if (item.deleted === true) {
      deleted += removeClientRecord(clientData, collection, payload.id);
      continue;
    }
    await normalizeClientPayload(context, userId, collection, payload);
    payload.updatedAt = item.updatedAt || payload.updatedAt || utcNow();
    clientData[collection] ||= [];
    const existing = clientData[collection].find((record) => record.id === payload.id);
    if (existing) Object.assign(existing, payload);
    else clientData[collection].push({ ...payload, createdAt: payload.createdAt || utcNow() });
    upserted += 1;
  }

  store.clientData[userId] = clientData;
  const user = userById(store, userId);
  if (user) {
    user.lastSeenAt = utcNow();
    user.updatedAt = user.lastSeenAt;
  }
  appendSystemLog(store, "info", "client", `Synced ${upserted} records for ${userId}`);
  await saveStore(context.env, store);
  return json({ ok: true, upserted, deleted, serverTime: utcNow(), dataVersion: "client-sync.v1" });
}

async function clientClear(context, userId) {
  const store = await loadStore(context.env);
  store.clientData[userId] = emptyClientData();
  const user = userById(store, userId);
  if (user) {
    user.updatedAt = utcNow();
    user.lastSeenAt = user.updatedAt;
  }
  appendSystemLog(store, "warning", "client", `Cleared client data for ${userId}`);
  await saveStore(context.env, store);
  return json({ ok: true, cleared: userId, serverTime: utcNow() });
}

async function clientDeleteAccount(context, userId, body) {
  const store = await loadStore(context.env);
  if (store.settings?.accountDeletionEnabled === false) return error(403, "Account deletion is disabled");
  const user = userById(store, userId);
  if (!user) return error(404, "User not found");
  const now = utcNow();
  user.status = "deleted";
  user.deletedAt = now;
  user.updatedAt = now;
  user.deleteReason = body.reason || "client_request";
  delete store.clientData[userId];
  store.clientTokens = Object.fromEntries(Object.entries(store.clientTokens).filter(([, owner]) => owner !== userId));
  appendSystemLog(store, "warning", "client", `Deleted account ${userId}`);
  await saveStore(context.env, store);
  return json({ ok: true, deleted: userId, serverTime: now });
}

async function listClientRecords(context, userId, collection) {
  if (!CLIENT_COLLECTIONS.has(collection)) return error(404, "Unknown collection");
  const store = await loadStore(context.env);
  const data = store.clientData[userId] || emptyClientData();
  return json({ collection, records: data[collection] || [] });
}

async function upsertClientRecord(context, userId, collection, body) {
  if (!CLIENT_COLLECTIONS.has(collection)) return error(404, "Unknown collection");
  const store = await loadStore(context.env);
  const data = store.clientData[userId] || emptyClientData();
  const payload = body.payload && typeof body.payload === "object" ? { ...body.payload } : { ...body };
  payload.id = String(payload.id || body.id || hex(8));
  payload.updatedAt = utcNow();
  await normalizeClientPayload(context, userId, collection, payload);
  data[collection] ||= [];
  const existing = data[collection].find((record) => record.id === payload.id);
  let status = 201;
  if (existing) {
    Object.assign(existing, payload);
    status = 200;
  } else {
    payload.createdAt ||= utcNow();
    data[collection].push(payload);
  }
  store.clientData[userId] = data;
  await saveStore(context.env, store);
  return json(payload, status);
}

async function patchClientRecord(context, userId, collection, recordId, body) {
  if (!CLIENT_COLLECTIONS.has(collection)) return error(404, "Unknown collection");
  const store = await loadStore(context.env);
  const records = (store.clientData[userId] ||= emptyClientData())[collection] ||= [];
  const record = records.find((item) => item.id === recordId);
  if (!record) return error(404, "Record not found");
  Object.assign(record, body, { updatedAt: utcNow() });
  await normalizeClientPayload(context, userId, collection, record);
  await saveStore(context.env, store);
  return json(record);
}

async function deleteClientRecord(context, userId, collection, recordId) {
  if (!CLIENT_COLLECTIONS.has(collection)) return error(404, "Unknown collection");
  const store = await loadStore(context.env);
  const data = store.clientData[userId] || emptyClientData();
  const deleted = removeClientRecord(data, collection, recordId);
  if (!deleted) return error(404, "Record not found");
  store.clientData[userId] = data;
  await saveStore(context.env, store);
  return json({ ok: true, deleted: recordId });
}

async function normalizeClientPayload(context, userId, collection, payload) {
  payload.userId = userId;
  payload.collection = collection;
  const imageBase64 = payload.imageBase64 || payload.imageData;
  delete payload.imageBase64;
  delete payload.imageData;
  if (!imageBase64) return;
  const saved = await saveImagePayload(context, userId, collection, payload.id, imageBase64);
  if (saved) payload.imageUrl = saved;
}

async function saveImagePayload(context, userId, collection, recordId, imageBase64) {
  const store = await loadStore(context.env);
  const bytes = base64ToBytes(imageBase64);
  const maxBytes = Number(store.settings?.maxImageBytes || 5242880);
  if (!bytes || bytes.byteLength === 0 || bytes.byteLength > maxBytes) return null;
  const key = `${userId}/${collection}/${recordId}.jpg`;
  if (isOssConfigured(context.env)) {
    try {
      await putOssObject(context.env, key, bytes, "image/jpeg");
      return `/data/uploads/${key}`;
    } catch (error) {
      console.warn(`OSS upload failed for ${key}; falling back to KV. ${error?.message || error}`);
    }
  }
  await context.env.MEALKIND_STORE.put(`upload:${key}`, imageBase64);
  return `/data/uploads/${key}`;
}

async function serveUpload(path, env) {
  const key = decodeURIComponent(path.replace("/data/uploads/", ""));
  if (isOssConfigured(env)) {
    try {
      const object = await getOssObject(env, key);
      if (object) return object;
    } catch (error) {
      console.warn(`OSS read failed for ${key}; falling back to KV. ${error?.message || error}`);
    }
  }
  const imageBase64 = await env.MEALKIND_STORE.get(`upload:${key}`);
  const bytes = imageBase64 ? base64ToBytes(imageBase64) : null;
  if (!bytes) return error(404, "File not found");
  return new Response(bytes, { headers: baseHeaders("image/jpeg") });
}

function isOssConfigured(env) {
  return Boolean(env.OSS_ACCESS_KEY_ID && env.OSS_ACCESS_KEY_SECRET && env.OSS_BUCKET && env.OSS_ENDPOINT);
}

async function putOssObject(env, key, bytes, contentType) {
  const url = ossObjectUrl(env, key);
  const date = new Date().toUTCString();
  const authorization = await ossAuthorization(env, "PUT", key, date, contentType);
  const response = await fetch(url, {
    method: "PUT",
    headers: {
      Authorization: authorization,
      Date: date,
      "Content-Type": contentType,
    },
    body: bytes,
  });
  if (!response.ok) {
    const body = await response.text().catch(() => "");
    throw new Error(`OSS PutObject failed: ${response.status} ${body.slice(0, 160)}`);
  }
}

async function getOssObject(env, key) {
  const date = new Date().toUTCString();
  const authorization = await ossAuthorization(env, "GET", key, date, "");
  const response = await fetch(ossObjectUrl(env, key), {
    method: "GET",
    headers: {
      Authorization: authorization,
      Date: date,
    },
  });
  if (response.status === 404) return null;
  if (!response.ok) {
    const body = await response.text().catch(() => "");
    throw new Error(`OSS GetObject failed: ${response.status} ${body.slice(0, 160)}`);
  }
  return new Response(response.body, {
    headers: baseHeaders(response.headers.get("Content-Type") || "image/jpeg"),
  });
}

async function ossAuthorization(env, method, key, date, contentType) {
  const resource = `/${env.OSS_BUCKET}/${key}`;
  const stringToSign = `${method}\n\n${contentType}\n${date}\n${resource}`;
  const signature = await hmacSha1Base64(env.OSS_ACCESS_KEY_SECRET, stringToSign);
  return `OSS ${env.OSS_ACCESS_KEY_ID}:${signature}`;
}

async function hmacSha1Base64(secret, value) {
  const encoder = new TextEncoder();
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-1" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign("HMAC", cryptoKey, encoder.encode(value));
  return arrayBufferToBase64(signature);
}

function ossObjectUrl(env, key) {
  const endpoint = String(env.OSS_ENDPOINT).replace(/^https?:\/\//, "").replace(/\/+$/, "");
  const encodedKey = key.split("/").map(encodeURIComponent).join("/");
  return `https://${env.OSS_BUCKET}.${endpoint}/${encodedKey}`;
}

async function foodAnalysis(context, body) {
  const response = mockFoodAnalysis(body);
  const store = await loadStore(context.env);
  store.analysisLogs.push({
    id: `log_${hex(6)}`,
    createdAt: utcNow(),
    type: "food-analysis",
    locale: body.locale || "en",
    remainingCalories: body.remainingCalories,
    plan: body.plan?.name,
    estimatedCalories: response.totalCalories,
    confidence: response.foods[0].confidence,
  });
  await saveStore(context.env, store);
  return json(response);
}

function smartScan(body) {
  const size = body.imageBase64 ? base64ToBytes(body.imageBase64)?.byteLength || 0 : 0;
  const kind = size > 2000 ? (size % 5 ? "food" : "workout") : "unknown";
  return json({ kind, confidence: kind === "unknown" ? 0.25 : 0.68, createdAt: utcNow() });
}

async function adminOverview(context) {
  const store = await loadStore(context.env);
  const logs = store.analysisLogs || [];
  const calories = logs.map((item) => item.estimatedCalories || 0);
  const proUsers = store.users.filter((user) => String(user.subscription || "").startsWith("pro"));
  const openIssues = store.issues.filter((issue) => issue.status !== "closed");
  return json({
    users: store.users.length,
    activeUsers: store.users.filter((user) => user.status === "active").length,
    plans: store.plans.filter((plan) => plan.enabled).length,
    subscriptionPlans: store.subscriptions.filter((item) => item.enabled).length,
    proUsers: proUsers.length,
    aiModels: store.aiModels.filter((model) => model.enabled).length,
    analysisCount: logs.length,
    averageCalories: calories.length ? Math.round(calories.reduce((sum, value) => sum + value, 0) / calories.length) : 0,
    openIssues: openIssues.length,
    notifications: store.notifications.length,
    maintenanceMode: Boolean(store.settings?.maintenanceMode),
  });
}

async function replaceCollection(context, key, body) {
  const items = body[key];
  if (!Array.isArray(items)) return error(400, `Expected ${key} array`);
  const store = await loadStore(context.env);
  store[key] = items;
  appendSystemLog(store, "info", "admin", `Replaced ${key} configuration`);
  await saveStore(context.env, store);
  return json(store[key]);
}

async function replaceSettings(context, body) {
  if (!body.settings || typeof body.settings !== "object") return error(400, "Expected settings object");
  const store = await loadStore(context.env);
  store.settings = body.settings;
  appendSystemLog(store, "info", "admin", "Updated system settings");
  await saveStore(context.env, store);
  return json(store.settings);
}

async function createUser(context, body) {
  const email = String(body.email || "").trim();
  if (!email) return error(400, "email is required");
  const store = await loadStore(context.env);
  if (store.users.some((user) => user.email === email && user.status !== "deleted")) return error(409, "email already exists");
  const now = utcNow();
  const user = {
    id: `usr_${hex(6)}`,
    name: body.name || email.split("@")[0],
    email,
    locale: body.locale || store.settings?.defaultLocale || "zh-Hans",
    plan: body.plan || "Lifestyle Cut",
    mode: body.mode || "lifestyle",
    status: "active",
    subscription: body.subscription || "free",
    registeredAt: now,
    deletedAt: null,
    deleteReason: null,
    createdAt: now,
    updatedAt: now,
    lastSeenAt: null,
  };
  store.users.push(user);
  appendSystemLog(store, "info", "admin", `Created user ${email}`);
  await saveStore(context.env, store);
  return json(user, 201);
}

async function patchUser(context, userId, body) {
  const store = await loadStore(context.env);
  const user = userById(store, userId);
  if (!user) return error(404, "User not found");
  for (const key of ["name", "email", "locale", "plan", "mode", "status", "subscription"]) {
    if (key in body) user[key] = body[key];
  }
  user.updatedAt = utcNow();
  appendSystemLog(store, "info", "admin", `Updated user ${user.email}`);
  await saveStore(context.env, store);
  return json(user);
}

async function deleteUser(context, userId) {
  const store = await loadStore(context.env);
  const user = userById(store, userId);
  if (!user) return error(404, "User not found");
  user.status = "deleted";
  user.deletedAt = utcNow();
  user.deleteReason = "admin_action";
  appendSystemLog(store, "warning", "admin", `Deleted user ${user.email}`);
  await saveStore(context.env, store);
  return json(user);
}

async function createRecord(context, key, body, prefix) {
  const store = await loadStore(context.env);
  const now = utcNow();
  const record = { ...body, id: body.id || `${prefix}_${hex(6)}`, createdAt: body.createdAt || now, updatedAt: body.updatedAt || now };
  store[key].push(record);
  appendSystemLog(store, "info", "admin", `Created ${key} record ${record.id}`);
  await saveStore(context.env, store);
  return json(record, 201);
}

async function patchRecord(context, key, recordId, body) {
  const store = await loadStore(context.env);
  const record = store[key].find((item) => item.id === recordId);
  if (!record) return error(404, "Record not found");
  Object.assign(record, body, { updatedAt: utcNow() });
  appendSystemLog(store, "info", "admin", `Updated ${key} record ${recordId}`);
  await saveStore(context.env, store);
  return json(record);
}

async function deleteRecord(context, key, recordId) {
  const store = await loadStore(context.env);
  const before = store[key].length;
  store[key] = store[key].filter((record) => record.id !== recordId);
  if (store[key].length === before) return error(404, "Record not found");
  appendSystemLog(store, "warning", "admin", `Deleted ${key} record ${recordId}`);
  await saveStore(context.env, store);
  return json({ ok: true, deleted: recordId });
}

async function loadStore(env) {
  const stored = await env.MEALKIND_STORE.get(STORE_KEY, "json");
  return ensureStoreShape(stored || structuredClone(DEFAULT_STORE));
}

async function saveStore(env, store) {
  await env.MEALKIND_STORE.put(STORE_KEY, JSON.stringify(ensureStoreShape(store)));
}

function ensureStoreShape(store) {
  store.users ||= [];
  store.plans ||= [];
  store.subscriptions ||= [];
  store.aiModels ||= [];
  store.settings ||= {};
  store.analysisLogs ||= [];
  store.systemLogs ||= [];
  store.issues ||= [];
  store.notifications ||= [];
  store.clientTokens ||= {};
  store.adminTokens ||= {};
  store.clientData ||= {};
  for (const user of store.users) {
    user.updatedAt ||= user.createdAt;
    user.lastSeenAt ??= null;
  }
  return store;
}

function mockFoodAnalysis(body) {
  const locale = body.locale || "en";
  const imageBase64 = body.imageBase64 || "";
  const remaining = Number(body.remainingCalories || 0);
  const imageSize = imageBase64.length;
  const calories = 420 + Math.min(Math.max(Math.floor(imageSize / 18000), 0), 260);
  const protein = Math.max(18, Math.round((calories * 0.2) / 4));
  const carbs = Math.max(32, Math.round((calories * 0.42) / 4));
  const fat = Math.max(10, Math.round((calories * 0.28) / 9));
  const fits = remaining >= calories;
  const zh = locale === "zh-Hans";
  return {
    foods: [
      {
        name: zh ? (imageBase64 ? "AI 识别餐食" : "手动餐食") : imageBase64 ? "AI scanned meal" : "Manual meal",
        portion: "1 serving",
        estimatedCalories: calories,
        protein,
        carbs,
        fat,
        confidence: imageBase64 ? 0.72 : 0.55,
      },
    ],
    totalCalories: calories,
    planFit: fits ? "fits" : "adjust",
    recommendedAction: {
      summary: zh ? (fits ? "这餐可以纳入今日计划。" : "可以吃，但建议缩小主食或留一部分。") : fits ? "This meal can fit today." : "You can eat it, but keep starch smaller or save some.",
      portionStrategy: zh ? ["优先吃蛋白质", "主食按实际分量记录"] : ["Protein first", "Record the actual portion"],
      nextMealAdjustment: zh ? (fits ? "下一餐正常吃，不需要补偿" : "下一餐保持清淡一点") : fits ? "Eat normally next; no compensation needed" : "Keep the next meal lighter",
      wasteAvoidance: "Save leftovers if full",
    },
    safetyFlags: [],
    recordDraft: { mealType: "unknown", calories, protein, carbs, fat },
    meta: { provider: "mock-json", planName: planName(body.plan, locale), createdAt: utcNow() },
  };
}

function planName(plan, locale) {
  if (!plan) return "Scanned meal";
  if (locale === "zh-Hans") {
    return {
      "Lifestyle Cut": "生活化减脂",
      "531 Carb Step-down": "531 碳水渐降",
      "High Protein": "高蛋白控热量",
    }[plan.name] || "当前方案";
  }
  return plan.name || "Current plan";
}

function emptyClientData() {
  return Object.fromEntries([...CLIENT_COLLECTIONS].sort().map((collection) => [collection, []]));
}

function removeClientRecord(clientData, collection, recordId) {
  clientData[collection] ||= [];
  const before = clientData[collection].length;
  clientData[collection] = clientData[collection].filter((record) => record.id !== recordId);
  return before - clientData[collection].length;
}

function userById(store, userId) {
  return store.users.find((user) => user.id === userId);
}

function safeUser(user) {
  const allowed = ["id", "name", "email", "locale", "plan", "mode", "status", "subscription", "registeredAt", "createdAt", "updatedAt", "lastSeenAt"];
  return Object.fromEntries(allowed.filter((key) => key in user).map((key) => [key, user[key]]));
}

function validateClientCredentials(email, password) {
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return "Valid email is required";
  if (password.length < 8) return "Password must be at least 8 characters";
  return "";
}

async function makePasswordCredentials(password) {
  const salt = hex(16);
  return { salt, hash: await passwordHash(password, salt) };
}

async function passwordHash(password, salt) {
  const encoder = new TextEncoder();
  const digest = await crypto.subtle.digest("SHA-256", encoder.encode(`${salt}:${password}`));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function appendSystemLog(store, level, source, message) {
  store.systemLogs.push({ id: `evt_${hex(6)}`, level, source, message, createdAt: utcNow() });
}

async function readJson(request) {
  if (!request.headers.get("content-length") && request.method !== "POST" && request.method !== "PATCH") return {};
  try {
    return await request.json();
  } catch {
    return {};
  }
}

function bearerToken(request) {
  const header = request.headers.get("Authorization") || "";
  return header.startsWith("Bearer ") ? header.slice(7).trim() : "";
}

function base64ToBytes(value) {
  try {
    const binary = atob(String(value));
    const bytes = new Uint8Array(binary.length);
    for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
    return bytes;
  } catch {
    return null;
  }
}

function arrayBufferToBase64(value) {
  const bytes = new Uint8Array(value);
  let binary = "";
  for (let index = 0; index < bytes.length; index += 1) {
    binary += String.fromCharCode(bytes[index]);
  }
  return btoa(binary);
}

function utcNow() {
  return new Date().toISOString();
}

function hex(byteLength) {
  const bytes = new Uint8Array(byteLength);
  crypto.getRandomValues(bytes);
  return [...bytes].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function randomToken() {
  return btoa(hex(24)).replaceAll("=", "");
}

function json(payload, status = 200) {
  return new Response(JSON.stringify(payload), { status, headers: baseHeaders("application/json; charset=utf-8") });
}

function html(body, status = 200) {
  return new Response(body, { status, headers: baseHeaders("text/html; charset=utf-8") });
}

function empty(status = 204) {
  return new Response(null, { status, headers: baseHeaders() });
}

function error(status, message) {
  return json({ error: message }, status);
}

function baseHeaders(contentType = "application/json; charset=utf-8") {
  return {
    "Content-Type": contentType,
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET,POST,PATCH,DELETE,OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type,Authorization",
    "Cache-Control": "no-store",
  };
}

function apiLandingHtml(origin) {
  return `<!doctype html>
<html lang="zh-CN">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>MealKind API</title>
    <style>
      body { margin: 0; font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: #f7f4ed; color: #1f2933; }
      main { max-width: 760px; margin: 0 auto; padding: 56px 20px; }
      h1 { font-size: 36px; margin: 0 0 12px; }
      p, li { color: #56616f; line-height: 1.7; }
      code { background: rgba(35, 85, 72, 0.1); border-radius: 6px; padding: 2px 6px; color: #235548; }
      .panel { background: #fff; border: 1px solid rgba(31, 41, 51, 0.08); border-radius: 8px; padding: 22px; box-shadow: 0 16px 36px rgba(31, 41, 51, 0.08); }
      a { color: #235548; }
    </style>
  </head>
  <body>
    <main>
      <section class="panel">
        <h1>MealKind API</h1>
        <p>Cloudflare Workers backend is running.</p>
        <ul>
          <li>Health: <a href="/health"><code>/health</code></a></li>
          <li>Food analysis: <code>POST /api/ai/food-analysis</code></li>
          <li>Persistence base URL: <code>${new URL(origin).origin}/</code></li>
          <li>Admin API login: <code>POST /api/auth/login</code></li>
        </ul>
      </section>
    </main>
  </body>
</html>`;
}
