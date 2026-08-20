const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();
const db = getFirestore();
const auth = getAuth();
const messaging = getMessaging();

const openAIKey = defineSecret("OPENAI_API_KEY");
const OPENAI_RESPONSES_URL = "https://api.openai.com/v1/responses";
const DEFAULT_MODEL = "gpt-5-mini";
const VALID_SLOTS = new Set(["아침", "점심", "저녁"]);
const VALID_ACTIONS = new Set(["replace", "add"]);
const REPORT_REASONS = new Set(["욕설·괴롭힘", "광고·도배", "위험한 만남·거래", "개인정보 노출", "기타"]);
const BLOCKED_TERMS = ["ㅅㅂ", "씨발", "병신", "죽여", "마약", "성매매"];

const responseSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    reply: { type: "string" },
    suggestions: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          recipeID: { type: "string" },
          reason: { type: "string" },
          action: { type: "string", enum: ["replace", "add"] },
          targetDate: { type: "string" },
          targetMealSlot: { type: "string", enum: ["", "아침", "점심", "저녁"] }
        },
        required: ["recipeID", "reason", "action", "targetDate", "targetMealSlot"]
      }
    }
  },
  required: ["reply", "suggestions"]
};

function text(value, maxLength) {
  if (typeof value !== "string") return "";
  return value.trim().slice(0, maxLength);
}

function array(value) {
  return Array.isArray(value) ? value : [];
}

function safeDate(value) {
  const candidate = text(value, 10);
  return /^\d{4}-\d{2}-\d{2}$/.test(candidate) ? candidate : "";
}

function sanitizeHistory(value) {
  return array(value)
    .filter((item) => item && (item.role === "user" || item.role === "assistant"))
    .slice(-12)
    .map((item) => ({
      role: item.role,
      text: text(item.text, 600)
    }))
    .filter((item) => item.text.length > 0);
}

function sanitizePlan(value) {
  const plan = value && typeof value === "object" ? value : {};
  const meals = array(plan.meals)
    .slice(0, 21)
    .map((meal) => ({
      date: safeDate(meal?.date),
      slot: VALID_SLOTS.has(meal?.slot) ? meal.slot : "",
      recipeID: text(meal?.recipeID, 120),
      title: text(meal?.title, 120)
    }))
    .filter((meal) => meal.date && meal.slot && meal.title);

  return {
    title: text(plan.title, 120),
    startDate: safeDate(plan.startDate),
    days: Math.min(Math.max(Number.isFinite(plan.days) ? Math.floor(plan.days) : 0, 0), 7),
    targetBudget: Math.min(Math.max(Number.isFinite(plan.targetBudget) ? Math.floor(plan.targetBudget) : 0, 0), 10000000),
    meals
  };
}

function sanitizeCandidates(value) {
  const candidates = new Map();
  for (const item of array(value).slice(0, 100)) {
    const id = text(item?.id, 120);
    const title = text(item?.title, 120);
    if (!id || !title || candidates.has(id)) continue;
    candidates.set(id, {
      id,
      title,
      description: text(item?.description, 240),
      mealSlots: array(item?.mealSlots).filter((slot) => VALID_SLOTS.has(slot)).slice(0, 3),
      cookTime: Math.min(Math.max(Number.isFinite(item?.cookTime) ? Math.floor(item.cookTime) : 0, 0), 240),
      isLightBreakfast: item?.isLightBreakfast === true,
      ingredients: array(item?.ingredients).map((name) => text(name, 60)).filter(Boolean).slice(0, 20),
      tags: array(item?.tags).map((tag) => text(tag, 40)).filter(Boolean).slice(0, 12)
    });
  }
  return candidates;
}

function sanitizePreferences(value) {
  const preferences = value && typeof value === "object" ? value : {};
  return {
    disliked: array(preferences.disliked).map((item) => text(item, 40)).filter(Boolean).slice(0, 40),
    allergies: array(preferences.allergies).map((item) => text(item, 40)).filter(Boolean).slice(0, 40),
    tools: array(preferences.tools).map((item) => text(item, 40)).filter(Boolean).slice(0, 20)
  };
}

function sanitizeInventory(value) {
  return array(value)
    .slice(0, 50)
    .map((item) => ({
      name: text(item?.name, 60),
      quantity: text(item?.quantity, 40),
      unit: text(item?.unit, 20)
    }))
    .filter((item) => item.name);
}

function buildInstructions(plan, preferences, inventory, candidates) {
  const candidateText = Array.from(candidates.values()).map((candidate) => ({
    id: candidate.id,
    title: candidate.title,
    mealSlots: candidate.mealSlots,
    cookTime: candidate.cookTime,
    lightBreakfast: candidate.isLightBreakfast,
    ingredients: candidate.ingredients,
    tags: candidate.tags,
    description: candidate.description
  }));

  return [
    "너는 한끼로그의 식단 수정 도우미다. 사용자가 고른 식단을 존중하면서 레시피 교체와 추가를 돕는다.",
    "답변은 반드시 지정된 JSON Schema만 따른다. recipeID는 아래 후보 목록의 id만 사용할 수 있다. 후보에 없는 메뉴를 만들어내거나 새 레시피 id를 발명하지 않는다.",
    "사용자가 수량, 가격, 예산 계산을 물어도 추측하지 않는다. 앱의 결정론적 계산 결과가 필요하다고 짧게 안내하고, 레시피 제안의 근거로만 현재 재료와 조리 시간을 사용한다.",
    "현재 식단의 특정 날짜·끼니가 언급되면 targetDate와 targetMealSlot에 정확히 넣고 action은 replace로 둔다. 비어 있는 날짜·끼니에 새 식사를 넣어 달라는 요청이면 action은 add로 둔다. 대상이 불명확하면 현재 식단의 첫 끼니를 기본 대상으로 삼는다.",
    "사용자가 더 가볍고 간단한 메뉴를 원하면 조리 시간이 짧고 재료가 적은 후보를 우선한다. 아침 후보의 isLightBreakfast는 아침에만 보조 기준으로 사용한다.",
    "reply는 한국어로 1~3문장, suggestions는 가장 관련 높은 후보 최대 3개만 넣는다. 조건에 맞는 후보가 없으면 suggestions를 빈 배열로 두고 이유를 설명한다.",
    "현재 식단:",
    JSON.stringify(plan),
    "사용자 선호 및 보유 조리도구:",
    JSON.stringify(preferences),
    "기록된 보유 재료(수량 미상은 추측하지 않음):",
    JSON.stringify(inventory),
    "선택 가능한 후보 레시피:",
    JSON.stringify(candidateText)
  ].join("\n");
}

function buildTranscript(history, message) {
  const prior = history.map((item) => `${item.role === "user" ? "사용자" : "한끼로그 AI"}: ${item.text}`);
  prior.push(`사용자: ${message}`);
  return prior.join("\n");
}

function extractOutputText(response) {
  if (typeof response?.output_text === "string" && response.output_text.trim()) {
    return response.output_text.trim();
  }

  const chunks = [];
  for (const item of array(response?.output)) {
    if (item?.type !== "message") continue;
    for (const content of array(item.content)) {
      if (content?.type === "output_text" && typeof content.text === "string") {
        chunks.push(content.text);
      }
    }
  }
  return chunks.join("\n").trim();
}

function parseModelJSON(value) {
  const raw = text(value, 20000);
  const withoutFence = raw.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/i, "");
  try {
    return JSON.parse(withoutFence);
  } catch {
    throw new HttpsError("internal", "AI 응답을 읽지 못했어요.");
  }
}

function normalizeSuggestions(value, candidates, plan) {
  const firstMeal = plan.meals[0] || { date: plan.startDate, slot: "저녁" };
  return array(value)
    .slice(0, 3)
    .map((suggestion) => {
      const candidate = candidates.get(text(suggestion?.recipeID, 120));
      if (!candidate) return null;
      const requestedSlot = VALID_SLOTS.has(suggestion?.targetMealSlot) ? suggestion.targetMealSlot : firstMeal.slot;
      // 서버가 다른 끼니로 몰래 바꾸지 않는다. 지원하지 않는 조합은 앱에 보내지 않는다.
      if (!candidate.mealSlots.includes(requestedSlot)) return null;
      return {
        recipeID: candidate.id,
        title: candidate.title,
        reason: text(suggestion?.reason, 180) || "현재 식단 조건에 맞는 후보예요.",
        action: VALID_ACTIONS.has(suggestion?.action) ? suggestion.action : "replace",
        targetDate: safeDate(suggestion?.targetDate) || firstMeal.date,
        targetMealSlot: requestedSlot,
        cookTimeMinutes: candidate.cookTime,
        ingredientCount: candidate.ingredients.length
      };
    })
    .filter(Boolean);
}

function normalizeResponse(value, candidates, plan) {
  const reply = text(value?.reply, 1000) || "조건에 맞는 메뉴를 찾아볼게요.";
  return {
    reply,
    suggestions: normalizeSuggestions(value?.suggestions, candidates, plan)
  };
}

async function callOpenAI({ apiKey, model, instructions, transcript }) {
  const response = await fetch(OPENAI_RESPONSES_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`
    },
    body: JSON.stringify({
      model,
      store: false,
      instructions,
      input: transcript,
      text: {
        format: {
          type: "json_schema",
          name: "onelog_ai_plan_chat",
          strict: true,
          schema: responseSchema
        }
      }
    })
  });

  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    console.error("OpenAI Responses API request failed", response.status, body?.error?.code || "unknown");
    throw new HttpsError("unavailable", "AI 서버가 잠시 바빠요. 잠시 후 다시 시도해 주세요.");
  }
  return body;
}

function containsBlockedContent(value) {
  const normalized = text(value, 1000).toLowerCase().replace(/\s/g, "");
  return BLOCKED_TERMS.some((term) => normalized.includes(term));
}

async function enforceRateLimit(uid, scope, hourlyLimit, dailyLimit) {
  const now = new Date();
  const hourBucket = now.toISOString().slice(0, 13);
  const dayBucket = now.toISOString().slice(0, 10);
  const ref = db.collection("rateLimits").doc(`${uid}_${scope}`);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const current = snapshot.data() || {};
    const hourlyCount = current.hourBucket === hourBucket ? Number(current.hourlyCount || 0) : 0;
    const dailyCount = current.dayBucket === dayBucket ? Number(current.dailyCount || 0) : 0;
    if (hourlyCount >= hourlyLimit || dailyCount >= dailyLimit) {
      throw new HttpsError("resource-exhausted", "요청이 너무 많아요. 잠시 후 다시 시도해 주세요.");
    }
    transaction.set(ref, {
      uid, scope, hourBucket, hourlyCount: hourlyCount + 1,
      dayBucket, dailyCount: dailyCount + 1,
      updatedAt: FieldValue.serverTimestamp()
    });
  });
}

async function tokensForUsers(userIDs) {
  const tokens = [];
  for (const uid of [...new Set(userIDs.filter(Boolean))]) {
    const snapshot = await db.collection("users").doc(uid).collection("devices").limit(10).get();
    for (const doc of snapshot.docs) {
      const token = text(doc.data()?.token, 500);
      if (token) tokens.push({ token, ref: doc.ref });
    }
  }
  return tokens;
}

async function sendPush(userIDs, title, body, data = {}) {
  const destinations = await tokensForUsers(userIDs);
  if (!destinations.length) return;
  const response = await messaging.sendEachForMulticast({
    tokens: destinations.map((item) => item.token),
    notification: { title, body },
    data: Object.fromEntries(Object.entries(data).map(([key, value]) => [key, String(value)])),
    apns: { payload: { aps: { sound: "default" } } }
  });
  const invalidCodes = new Set([
    "messaging/registration-token-not-registered",
    "messaging/invalid-registration-token"
  ]);
  await Promise.all(response.responses.map((item, index) => {
    if (!item.success && invalidCodes.has(item.error?.code)) return destinations[index].ref.delete();
    return Promise.resolve();
  }));
}

exports.aiChat = onCall(
  {
    region: "us-central1",
    timeoutSeconds: 60,
    memory: "256MiB",
    maxInstances: 5,
    secrets: [openAIKey],
    enforceAppCheck: true
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인 후 AI 채팅을 사용할 수 있어요.");
    }
    await enforceRateLimit(request.auth.uid, "aiChat", 20, 60);

    const message = text(request.data?.message, 600);
    if (!message) {
      throw new HttpsError("invalid-argument", "메시지를 입력해 주세요.");
    }

    const history = sanitizeHistory(request.data?.history);
    const plan = sanitizePlan(request.data?.plan);
    const preferences = sanitizePreferences(request.data?.preferences);
    const inventory = sanitizeInventory(request.data?.inventory);
    const candidates = sanitizeCandidates(request.data?.candidateRecipes);
    if (candidates.size === 0) {
      throw new HttpsError("invalid-argument", "추천할 수 있는 후보 레시피가 없어요.");
    }

    const apiKey = openAIKey.value();
    if (!apiKey) {
      console.error("OPENAI_API_KEY secret is not configured");
      throw new HttpsError("failed-precondition", "AI 서버 설정이 아직 끝나지 않았어요.");
    }

    const instructions = buildInstructions(plan, preferences, inventory, candidates);
    const transcript = buildTranscript(history, message);
    const response = await callOpenAI({
      apiKey,
      model: text(process.env.OPENAI_MODEL, 80) || DEFAULT_MODEL,
      instructions,
      transcript
    });
    const parsed = parseModelJSON(extractOutputText(response));
    return normalizeResponse(parsed, candidates, plan);
  }
);

exports.submitReport = onCall(
  { region: "us-central1", enforceAppCheck: true },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "로그인이 필요해요.");
    await enforceRateLimit(request.auth.uid, "report", 10, 30);
    const targetType = text(request.data?.targetType, 20);
    const targetID = text(request.data?.targetID, 160);
    const targetUserID = text(request.data?.targetUserID, 128);
    const reason = text(request.data?.reason, 40);
    if (!new Set(["post", "message", "user"]).has(targetType) || !targetID || !targetUserID || !REPORT_REASONS.has(reason)) {
      throw new HttpsError("invalid-argument", "신고 항목을 확인해 주세요.");
    }
    const ref = db.collection("reports").doc();
    await ref.set({
      id: ref.id, reporterID: request.auth.uid, targetType, targetID, targetUserID,
      reason, status: "pending", createdAt: FieldValue.serverTimestamp()
    });
    return { reportID: ref.id };
  }
);

exports.submitSupportTicket = onCall(
  { region: "us-central1", enforceAppCheck: true },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "로그인이 필요해요.");
    await enforceRateLimit(request.auth.uid, "support", 5, 10);
    const category = text(request.data?.category, 40);
    const message = text(request.data?.message, 1000);
    if (!category || !message || containsBlockedContent(message)) {
      throw new HttpsError("invalid-argument", "문의 내용을 확인해 주세요.");
    }
    const ref = db.collection("supportTickets").doc();
    await ref.set({
      id: ref.id, userID: request.auth.uid, category, message, status: "pending",
      createdAt: FieldValue.serverTimestamp()
    });
    return { ticketID: ref.id };
  }
);

exports.deleteSharePost = onCall(
  { region: "us-central1", enforceAppCheck: true },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "로그인이 필요해요.");
    const postID = text(request.data?.postID, 160);
    if (!postID) throw new HttpsError("invalid-argument", "삭제할 글을 확인해 주세요.");
    const ref = db.collection("sharePosts").doc(postID);
    const snapshot = await ref.get();
    if (!snapshot.exists) return { deleted: true };
    if (snapshot.data()?.authorID !== request.auth.uid) throw new HttpsError("permission-denied", "작성자만 삭제할 수 있어요.");
    await db.recursiveDelete(ref);
    const requests = await db.collection("shareRequests").where("postID", "==", postID).get();
    const batch = db.batch();
    requests.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    return { deleted: true };
  }
);

exports.respondShareRequest = onCall(
  { region: "us-central1", enforceAppCheck: true },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "로그인이 필요해요.");
    await enforceRateLimit(request.auth.uid, "shareResponse", 30, 100);
    const requestID = text(request.data?.requestID, 160);
    const decision = text(request.data?.decision, 20);
    if (!requestID || !new Set(["accepted", "rejected"]).has(decision)) {
      throw new HttpsError("invalid-argument", "요청 처리 값을 확인해 주세요.");
    }
    const requestRef = db.collection("shareRequests").doc(requestID);
    await db.runTransaction(async (transaction) => {
      const requestSnapshot = await transaction.get(requestRef);
      const shareRequest = requestSnapshot.data();
      if (!shareRequest || shareRequest.authorID !== request.auth.uid) {
        throw new HttpsError("permission-denied", "글 작성자만 요청을 처리할 수 있어요.");
      }
      if (shareRequest.status !== "pending") {
        throw new HttpsError("failed-precondition", "이미 처리된 요청이에요.");
      }
      if (decision === "rejected") {
        transaction.update(requestRef, { status: "rejected", updatedAt: FieldValue.serverTimestamp() });
        return;
      }
      const postRef = db.collection("sharePosts").doc(shareRequest.postID);
      const postSnapshot = await transaction.get(postRef);
      const post = postSnapshot.data();
      if (!post || post.authorID !== request.auth.uid || post.status !== "open" || post.expiresAt.toDate() <= new Date()) {
        throw new HttpsError("failed-precondition", "마감되었거나 처리할 수 없는 글이에요.");
      }
      const participants = Array.isArray(post.participantIDs) ? post.participantIDs : [];
      if (participants.includes(shareRequest.requesterID)) {
        throw new HttpsError("already-exists", "이미 참여 중인 이웃이에요.");
      }
      if (participants.length + 1 >= Number(post.capacity || 0)) {
        throw new HttpsError("resource-exhausted", "정원이 이미 마감됐어요.");
      }
      const nextParticipants = [...participants, shareRequest.requesterID];
      transaction.update(postRef, {
        participantIDs: nextParticipants,
        status: nextParticipants.length + 1 >= post.capacity ? "matched" : "open"
      });
      transaction.update(requestRef, { status: "accepted", updatedAt: FieldValue.serverTimestamp() });
    });
    return { status: decision };
  }
);

exports.deleteAccount = onCall(
  { region: "us-central1", enforceAppCheck: true, timeoutSeconds: 120 },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "로그인이 필요해요.");
    const uid = request.auth.uid;
    const authored = await db.collection("sharePosts").where("authorID", "==", uid).get();
    for (const doc of authored.docs) await db.recursiveDelete(doc.ref);

    const joined = await db.collection("sharePosts").where("participantIDs", "array-contains", uid).get();
    await Promise.all(joined.docs.map((doc) => doc.ref.update({
      participantIDs: FieldValue.arrayRemove(uid),
      status: "open"
    })));

    const [authoredRequests, requestedRequests, reports, tickets] = await Promise.all([
      db.collection("shareRequests").where("authorID", "==", uid).get(),
      db.collection("shareRequests").where("requesterID", "==", uid).get(),
      db.collection("reports").where("reporterID", "==", uid).get(),
      db.collection("supportTickets").where("userID", "==", uid).get()
    ]);
    const batch = db.batch();
    const unique = new Map();
    [...authoredRequests.docs, ...requestedRequests.docs, ...reports.docs, ...tickets.docs]
      .forEach((doc) => unique.set(doc.ref.path, doc.ref));
    unique.forEach((ref) => batch.delete(ref));
    await batch.commit();
    await db.recursiveDelete(db.collection("users").doc(uid));
    await auth.deleteUser(uid);
    return { deleted: true };
  }
);

exports.onShareRequestCreated = onDocumentCreated(
  { document: "shareRequests/{requestID}", region: "asia-northeast3" },
  async (event) => {
    const value = event.data?.data();
    if (!value || value.status !== "pending") return;
    if (containsBlockedContent(value.message) || containsBlockedContent(value.requesterNickname)) {
      await event.data.ref.update({ status: "rejected", updatedAt: FieldValue.serverTimestamp() });
      return;
    }
    await sendPush([value.authorID], "새 소분 요청", `${text(value.requesterNickname, 20)}님이 참여를 요청했어요.`, {
      category: "share", postID: value.postID, requestID: event.params.requestID
    });
  }
);

exports.onShareRequestUpdated = onDocumentUpdated(
  { document: "shareRequests/{requestID}", region: "asia-northeast3" },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!after || before?.status === after.status || !["accepted", "rejected"].includes(after.status)) return;
    await sendPush([after.requesterID], after.status === "accepted" ? "소분 요청 수락" : "소분 요청 결과",
      after.status === "accepted" ? "요청이 수락됐어요. 이제 채팅에서 약속을 정해 보세요." : "이번 요청은 성사되지 않았어요.",
      { category: "share", postID: after.postID });
  }
);

exports.onMessageCreated = onDocumentCreated(
  { document: "sharePosts/{postID}/messages/{messageID}", region: "asia-northeast3" },
  async (event) => {
    const message = event.data?.data();
    if (!message) return;
    if (containsBlockedContent(message.text) || containsBlockedContent(message.senderNickname)) {
      await event.data.ref.delete();
      const report = db.collection("reports").doc();
      await report.set({
        id: report.id, reporterID: "system", targetType: "message", targetID: event.params.messageID,
        targetUserID: message.senderID, reason: "자동 필터", status: "pending",
        createdAt: FieldValue.serverTimestamp()
      });
      return;
    }
    const post = (await db.collection("sharePosts").doc(event.params.postID).get()).data();
    if (!post) return;
    const recipients = [post.authorID, ...(post.participantIDs || [])].filter((uid) => uid !== message.senderID);
    await sendPush(recipients, text(message.senderNickname, 20) || "이웃", text(message.text, 120), {
      category: "chat", postID: event.params.postID
    });
  }
);

exports.cleanupExpiredShares = onSchedule(
  { schedule: "every day 03:00", timeZone: "Asia/Seoul", region: "us-central1", timeoutSeconds: 300 },
  async () => {
    const expired = await db.collection("sharePosts").where("expiresAt", "<=", new Date()).limit(200).get();
    for (const doc of expired.docs) await db.recursiveDelete(doc.ref);
    const staleRequests = await db.collection("shareRequests")
      .where("updatedAt", "<=", new Date(Date.now() - 90 * 24 * 60 * 60 * 1000)).limit(500).get();
    const batch = db.batch();
    staleRequests.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
  }
);
