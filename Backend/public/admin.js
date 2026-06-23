const state = {
  token: localStorage.getItem("mealkind_admin_token") || "",
  plans: [],
  subscriptions: [],
  aiModels: [],
  settings: {},
};

const $ = (id) => document.getElementById(id);

function setStatus(message, isError = false) {
  const node = $("statusText");
  if (!node) return;
  node.textContent = message || "";
  node.style.color = isError ? "#ff8b8b" : "var(--green)";
}

function headers() {
  return {
    "Content-Type": "application/json",
    Authorization: `Bearer ${state.token}`,
  };
}

async function api(path, options = {}) {
  const response = await fetch(path, {
    ...options,
    headers: { ...headers(), ...(options.headers || {}) },
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(data.error || "Request failed");
  return data;
}

function setLoggedIn(isLoggedIn) {
  $("loginPanel").classList.toggle("hidden", isLoggedIn);
  $("adminApp").classList.toggle("hidden", !isLoggedIn);
  $("logoutButton").classList.toggle("hidden", !isLoggedIn);
}

async function login() {
  $("loginError").textContent = "";
  setStatus("");
  try {
    const data = await api("/api/auth/login", {
      method: "POST",
      body: JSON.stringify({
        username: $("usernameInput").value.trim(),
        password: $("passwordInput").value,
      }),
    });
    state.token = data.token;
    localStorage.setItem("mealkind_admin_token", state.token);
    setLoggedIn(true);
    setStatus("登录成功，正在加载后台数据。");
    await loadAll();
  } catch (error) {
    $("loginError").textContent = error.message;
    setStatus("", true);
  }
}

function logout() {
  state.token = "";
  localStorage.removeItem("mealkind_admin_token");
  setLoggedIn(false);
}

async function loadAll() {
  setStatus("正在刷新数据...");
  try {
    const [overview, users, plans, subscriptions, aiModels, settings, logs, systemLogs, issues, notifications] = await Promise.all([
      api("/api/admin/overview"),
      api("/api/admin/users"),
      api("/api/admin/plans"),
      api("/api/admin/subscriptions"),
      api("/api/admin/ai-models"),
      api("/api/admin/settings"),
      api("/api/admin/analysis-logs"),
      api("/api/admin/system-logs"),
      api("/api/admin/issues"),
      api("/api/admin/notifications"),
    ]);
    state.plans = plans;
    state.subscriptions = subscriptions;
    state.aiModels = aiModels;
    state.settings = settings;
    renderOverview(overview);
    renderUsers(users);
    renderPlans(plans);
    renderSubscriptions(subscriptions);
    renderModels(aiModels);
    renderSettings(settings);
    renderLogs(logs);
    renderSystemLogs(systemLogs);
    renderIssues(issues);
    renderNotifications(notifications);
    setStatus("数据已刷新。");
  } catch (error) {
    setStatus(error.message, true);
    throw error;
  }
}

function renderOverview(data) {
  const cards = [
    ["总用户", data.users],
    ["活跃用户", data.activeUsers],
    ["启用方案", data.plans],
    ["订阅套餐", data.subscriptionPlans],
    ["Pro 用户", data.proUsers],
    ["AI 模型", data.aiModels],
    ["AI 分析", data.analysisCount],
    ["开放问题", data.openIssues],
    ["通知", data.notifications],
  ];
  $("dashboard").innerHTML = cards
    .map(([label, value]) => `<article class="statCard"><span>${label}</span><strong>${value}</strong></article>`)
    .join("");
}

function renderUsers(users) {
  $("usersTable").innerHTML = users
    .map(
      (user) => `
        <tr>
          <td><strong>${escapeHtml(user.name)}</strong><br><span>${escapeHtml(user.email)}</span></td>
          <td>${escapeHtml(user.locale)}</td>
          <td>${escapeHtml(user.plan)}</td>
          <td><span class="pill">${escapeHtml(user.mode)} · ${escapeHtml(user.subscription || "free")}</span></td>
          <td>${escapeHtml(user.status)}</td>
          <td>
            <button class="ghost small" data-toggle-user="${escapeHtml(user.id)}">
              ${user.status === "active" ? "禁用" : "启用"}
            </button>
            <button class="ghost small danger" data-delete-user="${escapeHtml(user.id)}">注销</button>
          </td>
        </tr>
      `
    )
    .join("");
  document.querySelectorAll("[data-toggle-user]").forEach((button) => {
    button.addEventListener("click", async () => {
      const id = button.getAttribute("data-toggle-user");
      const rowIsActive = button.textContent.trim() === "禁用";
      await api(`/api/admin/users/${id}`, {
        method: "PATCH",
        body: JSON.stringify({ status: rowIsActive ? "disabled" : "active" }),
      });
      await loadAll();
    });
  });
  document.querySelectorAll("[data-delete-user]").forEach((button) => {
    button.addEventListener("click", async () => {
      const id = button.getAttribute("data-delete-user");
      if (!confirm("确认注销该用户账号？")) return;
      await api(`/api/admin/users/${id}`, { method: "DELETE" });
      await loadAll();
    });
  });
}

function renderPlans(plans) {
  $("plansEditor").value = JSON.stringify({ plans }, null, 2);
}

function renderSubscriptions(subscriptions) {
  $("subscriptionsEditor").value = JSON.stringify({ subscriptions }, null, 2);
}

function renderModels(aiModels) {
  $("modelsEditor").value = JSON.stringify({ aiModels }, null, 2);
}

function renderSettings(settings) {
  $("settingsEditor").value = JSON.stringify({ settings }, null, 2);
}

function renderLogs(logs) {
  $("logsList").innerHTML =
    logs.length === 0
      ? `<p>暂无 AI 分析日志。</p>`
      : logs
          .map(
            (log) => `
              <div class="logItem">
                <div>
                  <strong>${escapeHtml(log.type)}</strong>
                  <span> · ${escapeHtml(log.locale || "-")} · ${escapeHtml(log.plan || "-")}</span>
                  <br />
                  <span>${escapeHtml(log.createdAt)}</span>
                </div>
                <strong>${escapeHtml(String(log.estimatedCalories || 0))} kcal</strong>
              </div>
            `
          )
          .join("");
}

function renderSystemLogs(logs) {
  $("systemLogsList").innerHTML =
    logs.length === 0
      ? `<p>暂无系统日志。</p>`
      : logs
          .map(
            (log) => `
              <div class="logItem">
                <div>
                  <strong>${escapeHtml(log.level)}</strong>
                  <span> · ${escapeHtml(log.source || "-")}</span>
                  <br />
                  <span>${escapeHtml(log.message || "-")}</span>
                </div>
                <span>${escapeHtml(log.createdAt)}</span>
              </div>
            `
          )
          .join("");
}

function renderIssues(issues) {
  $("issuesList").innerHTML =
    issues.length === 0
      ? `<p>暂无问题。</p>`
      : issues
          .map(
            (issue) => `
              <div class="logItem">
                <div>
                  <strong>${escapeHtml(issue.title)}</strong>
                  <span> · ${escapeHtml(issue.severity || "-")} · ${escapeHtml(issue.owner || "-")}</span>
                  <br />
                  <span>${escapeHtml(issue.createdAt || "-")}</span>
                </div>
                <button class="ghost small" data-close-issue="${escapeHtml(issue.id)}">${issue.status === "closed" ? "重开" : "关闭"}</button>
              </div>
            `
          )
          .join("");
  document.querySelectorAll("[data-close-issue]").forEach((button) => {
    button.addEventListener("click", async () => {
      const id = button.getAttribute("data-close-issue");
      const willReopen = button.textContent.trim() === "重开";
      await api(`/api/admin/issues/${id}`, {
        method: "PATCH",
        body: JSON.stringify({ status: willReopen ? "open" : "closed" }),
      });
      await loadAll();
    });
  });
}

function renderNotifications(notifications) {
  $("notificationsList").innerHTML =
    notifications.length === 0
      ? `<p>暂无通知。</p>`
      : notifications
          .map(
            (item) => `
              <div class="logItem">
                <div>
                  <strong>${escapeHtml(item.title)}</strong>
                  <span> · ${escapeHtml(item.audience || "all")} · ${escapeHtml(item.status || "draft")}</span>
                  <br />
                  <span>${escapeHtml(item.body || "")}</span>
                </div>
                <button class="ghost small" data-publish-notification="${escapeHtml(item.id)}">${item.status === "sent" ? "已发送" : "发送"}</button>
              </div>
            `
          )
          .join("");
  document.querySelectorAll("[data-publish-notification]").forEach((button) => {
    button.addEventListener("click", async () => {
      const id = button.getAttribute("data-publish-notification");
      await api(`/api/admin/notifications/${id}`, {
        method: "PATCH",
        body: JSON.stringify({ status: "sent", sentAt: new Date().toISOString() }),
      });
      await loadAll();
    });
  });
}

async function savePlans() {
  await saveJsonEditor("plansEditor", "/api/admin/plans", "方案已保存。");
}

async function saveSubscriptions() {
  await saveJsonEditor("subscriptionsEditor", "/api/admin/subscriptions", "订阅已保存。");
}

async function saveModels() {
  await saveJsonEditor("modelsEditor", "/api/admin/ai-models", "AI 模型已保存。");
}

async function saveSettings() {
  await saveJsonEditor("settingsEditor", "/api/admin/settings", "系统设置已保存。");
}

async function saveJsonEditor(editorId, path, successMessage) {
  try {
    const payload = JSON.parse($(editorId).value);
    await api(path, { method: "POST", body: JSON.stringify(payload) });
    await loadAll();
    setStatus(successMessage);
  } catch (error) {
    setStatus(`保存失败：${error.message}`, true);
  }
}

async function createIssue() {
  const title = prompt("问题标题");
  if (!title) return;
  await api("/api/admin/issues", {
    method: "POST",
    body: JSON.stringify({ title, status: "open", severity: "medium", owner: "ops" }),
  });
  await loadAll();
  setStatus("问题已创建。");
}

async function createNotification() {
  const title = prompt("通知标题");
  if (!title) return;
  const body = prompt("通知内容") || "";
  await api("/api/admin/notifications", {
    method: "POST",
    body: JSON.stringify({ title, body, audience: "all", status: "draft" }),
  });
  await loadAll();
  setStatus("通知草稿已创建。");
}

async function testAnalysis() {
  await api("/api/ai/food-analysis", {
    method: "POST",
    body: JSON.stringify({
      imageBase64: "demo-image-payload",
      remainingCalories: 620,
      locale: "zh-Hans",
      plan: {
        id: "carbStepDown",
        name: "531 Carb Step-down",
        dailyDeficit: 520,
        guardrails: ["Protein first", "Half rice at dinner"],
      },
    }),
  });
  await loadAll();
  setStatus("测试分析日志已生成。");
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

$("loginButton").addEventListener("click", login);
$("logoutButton").addEventListener("click", logout);
$("refreshButton").addEventListener("click", loadAll);
$("savePlansButton").addEventListener("click", savePlans);
$("saveSubscriptionsButton").addEventListener("click", saveSubscriptions);
$("saveModelsButton").addEventListener("click", saveModels);
$("saveSettingsButton").addEventListener("click", saveSettings);
$("testAnalysisButton").addEventListener("click", testAnalysis);
$("createIssueButton").addEventListener("click", createIssue);
$("createNotificationButton").addEventListener("click", createNotification);

if (state.token) {
  setLoggedIn(true);
  loadAll().catch(logout);
} else {
  setLoggedIn(false);
}
