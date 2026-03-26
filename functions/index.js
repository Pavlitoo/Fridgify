/* eslint-disable */
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { GoogleGenerativeAI, SchemaType } = require("@google/generative-ai");

initializeApp();

// Беремо ключ із прихованого файлу .env
const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);

const translations = {
  uk: { morningTitle: "Увага! Продукти псуються ⏰", expiringSoon: "Скоро зіпсується: ", expired: "Вже зіпсувалося: ", eveningTitle: "Час готувати вечерю! 🍳", eveningBody: "Загляньте у додаток — ми підберемо крутий рецепт з того, що є у вас вдома!" },
  en: { morningTitle: "Attention! Food is spoiling ⏰", expiringSoon: "Expiring soon: ", expired: "Already spoiled: ", eveningTitle: "Time to cook dinner! 🍳", eveningBody: "Check the app — we'll find a great recipe from what you have at home!" },
  es: { morningTitle: "¡Atención! La comida se estropea ⏰", expiringSoon: "Caduca pronto: ", expired: "Ya caducado: ", eveningTitle: "¡Hora de preparar la cena! 🍳", eveningBody: "Revisa la aplicación — ¡encontraremos una gran receta con lo que tienes en casa!" },
  fr: { morningTitle: "Attention ! La nourriture se gâte ⏰", expiringSoon: "Expire bientôt : ", expired: "Déjà gâté : ", eveningTitle: "L'heure de préparer le dîner ! 🍳", eveningBody: "Consultez l'application — nous trouverons une super recette avec ce que vous avez chez vous !" },
  de: { morningTitle: "Achtung! Essen verdirbt ⏰", expiringSoon: "Läuft bald ab: ", expired: "Bereits verdorben: ", eveningTitle: "Zeit zum Abendessen kochen! 🍳", eveningBody: "Schau in die App — wir finden ein tolles Rezept aus dem, was du zu Hause hast!" }
};

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

const receiptSchema = {
  type: SchemaType.ARRAY,
  items: {
    type: SchemaType.OBJECT,
    properties: {
      name: { type: SchemaType.STRING, description: "Clean, human-readable name of the food product" },
      quantity: { type: SchemaType.NUMBER, description: "Quantity from the receipt (e.g. 1, 0.5, 200)" },
      unit: { type: SchemaType.STRING, description: "ONLY use one of these: pcs, kg, g, l, ml" },
      category: { type: SchemaType.STRING, description: "ONLY use one of these: meat, veg, fruit, dairy, bakery, sweet, drink, other" },
      estimatedDaysToExpire: { type: SchemaType.NUMBER, description: "AI's best guess for how many days until this specific food goes bad if kept in a fridge (e.g. Milk=7, Meat=3, Pasta=365)" }
    },
    required: ["name", "quantity", "unit", "category", "estimatedDaysToExpire"]
  }
};

exports.generateRecipes = onCall({ maxInstances: 10, memory: "512MiB" }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'The function must be called while authenticated.');
  const { ingredients, userLanguage, dietType } = request.data;
  let dietInstruction = "Standard tasty food.";
  switch (dietType) { case 'vegetarian': dietInstruction = "Vegetarian (no meat)."; break; case 'vegan': dietInstruction = "Vegan (no animal products)."; break; case 'healthy': dietInstruction = "Healthy balanced diet (PP)."; break; case 'keto': dietInstruction = "Keto (low carb)."; break; }

  const prompt = `📋 USER'S INPUT: ${ingredients.join(', ')}
🗣️ TARGET LANGUAGE: ${userLanguage}
🥗 DIET TYPE: ${dietInstruction}

PHASE 1: VALIDATION
Check if ANY item in USER'S INPUT is garbage/non-food. If yes, ONLY set error = "INVALID_INGREDIENTS".

PHASE 2: RECIPES
If valid, create EXACTLY 5 diverse recipes.
"ingredients" array MUST contain ONLY items the user provided.
"missingIngredients" array MUST contain all other required items.
Translate everything to ${userLanguage}.

🔥 CRITICAL FORMATTING RULES:
1. FOR INGREDIENTS ARRAYS ("ingredients" and "missingIngredients"):
   Every single item MUST start with a number and a unit! Strictly use ONLY these units: g, kg, ml, l, pcs.
   Format: "NUMBER UNIT NAME" (e.g., "200 g Chicken", "2 pcs Tomato", "5 g Salt"). NEVER return just the ingredient name.
2. FOR INSTRUCTIONS ARRAY ("steps"):
   Write the recipe steps in natural, conversational ${userLanguage}.
   DO NOT use strict technical codes like "pcs" or "g" in the text. Translate quantities and product names into natural, grammatically correct language (e.g., instead of "0.5 pcs Капуста", write "половину капусти"; instead of "300 g Огірки", write "300 грамів огірків").`;

  try {
    const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });
    const chatSession = model.startChat({ generationConfig: { temperature: 0.7, responseMimeType: "application/json", responseSchema: recipeSchema } });
    const result = await chatSession.sendMessage(prompt);
    return { result: result.response.text() };
  } catch (error) { throw new HttpsError('internal', 'AI generation failed.'); }
});

exports.analyzeFridgePhoto = onCall({ maxInstances: 10, memory: "1GiB" }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'The function must be called while authenticated.');
  const { imageBase64, userLanguage } = request.data;
  if (!imageBase64) throw new HttpsError('invalid-argument', 'No image provided.');

  const prompt = `Look at this image of groceries or a fridge inside. Identify all edible food items. For each item, estimate the quantity and categorize it strictly into one of these: meat, veg, fruit, dairy, bakery, sweet, drink, other. Translate the product names to: ${userLanguage}.`;
  const imagePart = { inlineData: { data: imageBase64, mimeType: "image/jpeg" } };

  try {
    const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });
    const chatSession = model.startChat({ generationConfig: { temperature: 0.4, responseMimeType: "application/json", responseSchema: visionSchema } });
    const result = await chatSession.sendMessage([prompt, imagePart]);
    return { result: result.response.text() };
  } catch (error) { throw new HttpsError('internal', 'Image analysis failed.'); }
});

exports.analyzeReceiptPhoto = onCall({ maxInstances: 10, memory: "1GiB" }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'The function must be called while authenticated.');
  const { imageBase64, userLanguage } = request.data;
  if (!imageBase64) throw new HttpsError('invalid-argument', 'No image provided.');

  const prompt = `You are a smart AI grocery assistant. Look at this image of a store receipt.
  1. Identify ONLY edible food/grocery items. Ignore non-food items (like bags, taxes, discounts, cleaning supplies).
  2. Clean up the names. Receipts often use weird abbreviations (e.g., "MLK 2.5% YGT" -> "Milk").
  3. Extract the quantity and convert it strictly to one of these units: pcs, kg, g, l, ml.
  4. Categorize it strictly into: meat, veg, fruit, dairy, bakery, sweet, drink, other.
  5. CRITICAL: Estimate 'estimatedDaysToExpire'. Think logically about how long this item typically lasts in a standard fridge before spoiling (e.g., Fresh Meat = 3 days, Milk = 7 days, Apples = 14 days, Canned/Dry goods like Pasta = 365 days).
  6. Translate all clean product names into: ${userLanguage}.`;

  const imagePart = { inlineData: { data: imageBase64, mimeType: "image/jpeg" } };

  try {
    const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });
    const chatSession = model.startChat({ generationConfig: { temperature: 0.1, responseMimeType: "application/json", responseSchema: receiptSchema } });
    const result = await chatSession.sendMessage([prompt, imagePart]);
    return { result: result.response.text() };
  } catch (error) { throw new HttpsError('internal', 'Receipt analysis failed.'); }
});

// ============================================================================
// 🔥 ОНОВЛЕНИЙ РАНКОВИЙ ПУШ (ТЕПЕР РЕАЛЬНО ВИКИДАЄ В СМІТНИК)
// ============================================================================
exports.checkExpiredProducts = onSchedule({ schedule: "0 9 * * *", timeZone: "Europe/Kyiv", memory: "256MiB" }, async (event) => {
  const db = getFirestore();
  const messaging = getMessaging();
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

  try {
    const usersSnapshot = await db.collection('users').get();
    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      const fcmToken = userData.fcmToken;
      if (!fcmToken) continue;

      const userLang = userData.language || 'en';
      const lang = translations[userLang] ? userLang : 'en';
      const t = translations[lang];

      let productsRef = userData.householdId
          ? db.collection('households').doc(userData.householdId).collection('products')
          : db.collection('users').doc(userDoc.id).collection('products');

      const productsSnapshot = await productsRef.get();

      let expiringSoon = [];
      let expired = [];
      let updatePromises = []; // Масив для збереження команд оновлення бази

      productsSnapshot.forEach(doc => {
        const product = doc.data();
        if (product.category === 'trash') return;

        const expDate = product.expirationDate.toDate();
        const productDay = new Date(expDate.getFullYear(), expDate.getMonth(), expDate.getDate());
        const diffDays = Math.round((productDay.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));

        if (diffDays < 0) {
          expired.push(product.name);
          // 🔥 РЕАЛЬНО ЗМІНЮЄМО СТАТУС В БАЗІ НА "СМІТНИК"
          updatePromises.push(doc.ref.update({ category: 'trash' }));
        } else if (diffDays >= 0 && diffDays <= 2) {
          expiringSoon.push(product.name);
        }
      });

      // Чекаємо, поки всі зіпсовані продукти перелетять у смітник
      if (updatePromises.length > 0) {
        await Promise.all(updatePromises);
      }

      // Відправляємо 1 згрупований пуш на користувача
      if (expiringSoon.length > 0 || expired.length > 0) {
        let bodyText = "";
        if (expiringSoon.length > 0) bodyText += `${t.expiringSoon}${expiringSoon.join(', ')}. `;
        if (expired.length > 0) bodyText += `${t.expired}${expired.join(', ')}.`;

        try {
          await messaging.send({
            token: fcmToken,
            notification: { title: t.morningTitle, body: bodyText.trim() },
            data: { click_action: "FLUTTER_NOTIFICATION_CLICK", payload: "fridge" }
          });
        } catch (error) {
          console.error("Push Error:", error);
        }
      }
    }
  } catch (globalError) {
    console.error("CRON Error:", globalError);
  }
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