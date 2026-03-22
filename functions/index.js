/* eslint-disable */
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { GoogleGenerativeAI, SchemaType } = require("@google/generative-ai");

initializeApp();

// 🔥 ВСТАВ СВІЙ СКОПІЙОВАНИЙ КЛЮЧ GEMINI ОСЬ ТУТ:
const GEMINI_API_KEY = process.env.GEMINI_API_KEY;

const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);

const translations = {
  uk: { morningTitle: "Увага! Продукти псуються ⏰", expiringSoon: "Скоро зіпсується: ", expired: "Вже зіпсувалося: ", eveningTitle: "Час готувати вечерю! 🍳", eveningBody: "Загляньте у додаток — ми підберемо крутий рецепт з того, що є у вас вдома!" },
  en: { morningTitle: "Attention! Food is spoiling ⏰", expiringSoon: "Expiring soon: ", expired: "Already spoiled: ", eveningTitle: "Time to cook dinner! 🍳", eveningBody: "Check the app — we'll find a great recipe from what you have at home!" },
  es: { morningTitle: "¡Atención! La comida se estropea ⏰", expiringSoon: "Caduca pronto: ", expired: "Ya caducado: ", eveningTitle: "¡Hora de preparar la cena! 🍳", eveningBody: "Revisa la aplicación — ¡encontraremos una gran receta con lo que tienes en casa!" },
  fr: { morningTitle: "Attention ! La nourriture se gâte ⏰", expiringSoon: "Expire bientôt : ", expired: "Déjà gâté : ", eveningTitle: "L'heure de préparer le dîner ! 🍳", eveningBody: "Consultez l'application — nous trouverons une super recette avec ce que vous avez chez vous !" },
  de: { morningTitle: "Achtung! Essen verdirbt ⏰", expiringSoon: "Läuft bald ab: ", expired: "Bereits verdorben: ", eveningTitle: "Zeit zum Abendessen kochen! 🍳", eveningBody: "Schau in die App — wir finden ein tolles Rezept aus dem, was du zu Hause hast!" }
};

// ============================================================================
// СХЕМА 1: ДЛЯ РЕЦЕПТІВ
// ============================================================================
const recipeSchema = {
  type: SchemaType.OBJECT,
  properties: {
    error: { type: SchemaType.STRING, description: "Set to 'INVALID_INGREDIENTS' ONLY if non-food items are found." },
    recipes: {
      type: SchemaType.ARRAY,
      items: {
        type: SchemaType.OBJECT,
        properties: {
          title: { type: SchemaType.STRING }, description: { type: SchemaType.STRING }, time: { type: SchemaType.STRING }, kcal: { type: SchemaType.STRING }, isVegetarian: { type: SchemaType.BOOLEAN }, searchQuery: { type: SchemaType.STRING }, ingredients: { type: SchemaType.ARRAY, items: { type: SchemaType.STRING } }, missingIngredients: { type: SchemaType.ARRAY, items: { type: SchemaType.STRING } }, steps: { type: SchemaType.ARRAY, items: { type: SchemaType.STRING } }
        },
        required: ["title", "description", "time", "kcal", "isVegetarian", "searchQuery", "ingredients", "missingIngredients", "steps"]
      }
    }
  }
};

// ============================================================================
// СХЕМА 2: ДЛЯ ФОТО ХОЛОДИЛЬНИКА
// ============================================================================
const visionSchema = {
  type: SchemaType.ARRAY,
  items: {
    type: SchemaType.OBJECT,
    properties: {
      name: { type: SchemaType.STRING, description: "Name of the food product" },
      quantity: { type: SchemaType.NUMBER, description: "Estimated quantity (e.g. 1, 0.5, 200, 500)" },
      unit: { type: SchemaType.STRING, description: "ONLY use one of these: pcs, kg, g, l, ml" },
      category: { type: SchemaType.STRING, description: "ONLY use one of these: meat, veg, fruit, dairy, bakery, sweet, drink, other" }
    },
    required: ["name", "quantity", "unit", "category"]
  }
};

// ============================================================================
// ФУНКЦІЯ: ГЕНЕРАЦІЯ РЕЦЕПТІВ
// ============================================================================
exports.generateRecipes = onCall({ maxInstances: 10, memory: "512MiB" }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'The function must be called while authenticated.');
  const { ingredients, userLanguage, dietType } = request.data;
  let dietInstruction = "Standard tasty food.";
  switch (dietType) { case 'vegetarian': dietInstruction = "Vegetarian (no meat)."; break; case 'vegan': dietInstruction = "Vegan (no animal products)."; break; case 'healthy': dietInstruction = "Healthy balanced diet (PP)."; break; case 'keto': dietInstruction = "Keto (low carb)."; break; }

  const prompt = `📋 USER'S INPUT: ${ingredients.join(', ')}\n🗣️ TARGET LANGUAGE: ${userLanguage}\n🥗 DIET TYPE: ${dietInstruction}\n\nPHASE 1: VALIDATION\nCheck if ANY item in USER'S INPUT is garbage/non-food. If yes, ONLY set error = "INVALID_INGREDIENTS".\n\nPHASE 2: RECIPES\nIf valid, create EXACTLY 5 diverse recipes. "ingredients" array MUST contain ONLY items the user provided. "missingIngredients" array MUST contain all other required items. Use metric units. Translate everything to ${userLanguage}.`;

  try {
    const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });
    const chatSession = model.startChat({ generationConfig: { temperature: 0.7, responseMimeType: "application/json", responseSchema: recipeSchema } });
    const result = await chatSession.sendMessage(prompt);
    return { result: result.response.text() };
  } catch (error) { throw new HttpsError('internal', 'AI generation failed.'); }
});

// ============================================================================
// 🔥 НОВА ФУНКЦІЯ: АНАЛІЗ ФОТО ХОЛОДИЛЬНИКА
// ============================================================================
exports.analyzeFridgePhoto = onCall({ maxInstances: 10, memory: "1GiB" }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'The function must be called while authenticated.');

  const { imageBase64, userLanguage } = request.data;
  if (!imageBase64) throw new HttpsError('invalid-argument', 'No image provided.');

  const prompt = `Look at this image of groceries or a fridge inside.
  Identify all edible food items.
  For each item, estimate the quantity and categorize it strictly into one of these: meat, veg, fruit, dairy, bakery, sweet, drink, other.
  Translate the product names to: ${userLanguage}.`;

  const imagePart = {
    inlineData: { data: imageBase64, mimeType: "image/jpeg" }
  };

  try {
    // Використовуємо ту ж модель, вона вміє бачити картинки
    const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });
    const chatSession = model.startChat({
      generationConfig: {
        temperature: 0.4, // Зменшуємо креативність для більшої точності
        responseMimeType: "application/json",
        responseSchema: visionSchema
      }
    });

    const result = await chatSession.sendMessage([prompt, imagePart]);
    return { result: result.response.text() };

  } catch (error) {
    console.error("Gemini Vision Error:", error);
    throw new HttpsError('internal', 'Image analysis failed.');
  }
});

// ============================================================================
// ФУНКЦІЇ ПУШІВ (БЕЗ ЗМІН)
// ============================================================================
exports.checkExpiredProducts = onSchedule({ schedule: "0 9 * * *", timeZone: "Europe/Kyiv", memory: "256MiB" }, async (event) => {
  const db = getFirestore(); const messaging = getMessaging(); const now = new Date(); const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  try {
    const usersSnapshot = await db.collection('users').get();
    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data(); const fcmToken = userData.fcmToken; if (!fcmToken) continue;
      const userLang = userData.language || 'en'; const lang = translations[userLang] ? userLang : 'en'; const t = translations[lang];
      let productsRef = userData.householdId ? db.collection('households').doc(userData.householdId).collection('products') : db.collection('users').doc(userDoc.id).collection('products');
      const productsSnapshot = await productsRef.get();
      let expiringSoon = []; let expired = [];
      productsSnapshot.forEach(doc => {
        const product = doc.data(); if (product.category === 'trash') return;
        const expDate = product.expirationDate.toDate(); const productDay = new Date(expDate.getFullYear(), expDate.getMonth(), expDate.getDate());
        const diffDays = Math.round((productDay.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));
        if (diffDays < 0) expired.push(product.name); else if (diffDays >= 0 && diffDays <= 2) expiringSoon.push(product.name);
      });
      if (expiringSoon.length > 0 || expired.length > 0) {
        let bodyText = "";
        if (expiringSoon.length > 0) bodyText += `${t.expiringSoon}${expiringSoon.join(', ')}. `;
        if (expired.length > 0) bodyText += `${t.expired}${expired.join(', ')}.`;
        try { await messaging.send({ token: fcmToken, notification: { title: t.morningTitle, body: bodyText.trim() }, data: { click_action: "FLUTTER_NOTIFICATION_CLICK", payload: "fridge" } }); } catch (error) {}
      }
    }
  } catch (globalError) { console.error(globalError); }
});

exports.sendEveningRecipeReminder = onSchedule({ schedule: "0 17 * * *", timeZone: "Europe/Kyiv", memory: "256MiB" }, async (event) => {
  const db = getFirestore(); const messaging = getMessaging();
  try {
    const usersSnapshot = await db.collection('users').get();
    const tokensByLang = { uk: [], en: [], es: [], fr: [], de: [] };
    usersSnapshot.docs.forEach((doc) => {
      const userData = doc.data(); if (userData.fcmToken) { const lang = tokensByLang[userData.language] ? userData.language : 'en'; tokensByLang[lang].push(userData.fcmToken); }
    });
    for (const lang of Object.keys(tokensByLang)) {
      const uniqueTokens = [...new Set(tokensByLang[lang])]; if (uniqueTokens.length === 0) continue;
      try { await messaging.sendEachForMulticast({ tokens: uniqueTokens, notification: { title: translations[lang].eveningTitle, body: translations[lang].eveningBody }, data: { payload: 'recipes', click_action: 'FLUTTER_NOTIFICATION_CLICK' } }); } catch (err) {}
    }
  } catch (error) {}
});