# 🍎 Fridgify: Your AI-Powered Smart Kitchen Assistant

<div align="center">
  <img src="https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Firebase-039BE5?style=for-the-badge&logo=Firebase&logoColor=white" alt="Firebase" />
  <img src="https://img.shields.io/badge/Gemini_AI-8E75B2?style=for-the-badge&logo=googlebard&logoColor=white" alt="Gemini AI" />
  <img src="https://img.shields.io/badge/Cloud_Functions-4285F4?style=for-the-badge&logo=googlecloud&logoColor=white" alt="Cloud Functions" />
  <img src="https://img.shields.io/badge/AdMob-EA4335?style=for-the-badge&logo=googleadmob&logoColor=white" alt="AdMob" />
  <img src="https://img.shields.io/badge/license-MIT-green?style=for-the-badge" alt="License" />
</div>

<br/>

**Fridgify** — це сучасний кросплатформний додаток, створений для керування продуктами, зменшення харчових відходів та економії грошей. Завдяки інтеграції передового штучного інтелекту (**Google Gemini**) та хмарних технологій, додаток не лише нагадує про терміни придатності, але й буквально бачить ваші продукти через камеру та самостійно придумує, що з них приготувати.

---

## ✨ Головні інновації (Що нового)

### 📸 AI Vision: Розумний сканер холодильника
* **Scan & Go:** Більше не потрібно вводити продукти вручну. Просто зробіть фото вмісту холодильника.
* **Аналіз зображень:** Штучний інтелект (Gemini 2.5 Flash Vision) миттєво розпізнає продукти на фото, визначає їхню категорію та приблизну кількість/вагу.
* **Автоматизація:** Розпізнані продукти одним кліком додаються до вашого цифрового холодильника.

### 🧠 AI Chef: Генерація рецептів (Powered by Gemini)
* **Smart Context:** Алгоритм аналізує наявні продукти і пропонує **5 унікальних рецептів**, мінімізуючи потребу йти в магазин.
* **Підтримка дієт:** Генерація страв адаптується під ваші потреби (Вегетаріанська, Веганська, Кето, Здорове харчування).
* **Повна деталізація:** Кожен рецепт містить калорійність (Ккал), час приготування, покрокову інструкцію та список інгредієнтів, яких не вистачає.

### 🔒 Сучасна Auth-система
* **Оновлений UI/UX:** Плавні анімації, динамічні форми та інтуїтивно зрозумілий дизайн авторизації.
* **Безпека:** Залізобетонна логіка перевірки email (Verification Link) та ізольований `AuthService`.
* **Social Login:** Інтегрований вхід через Google та GitHub.

### ☁️ Serverless Архітектура (Firebase Cloud Functions)
Уся важка логіка винесена на безпечний бекенд:
* **Cron Jobs (Планувальники):** Автоматична щоденна перевірка термінів придатності.
* **Smart Push Notifications:** Сервер сам аналізує ваш холодильник і надсилає таргетовані FCM-сповіщення (наприклад, *"З'їжте сир, він псується завтра!"* або вечірнє нагадування згенерувати рецепт).
* **Secure API:** API ключі ШІ надійно сховані на сервері (через `.env`), додаток взаємодіє з ними лише через авторизовані `onCall` функції.

---

## 👨‍👩‍👧‍👦 Базовий функціонал

* **Облік продуктів:** Зручне додавання, кольорова індикація свіжості (🟢 свіже, 🟠 скоро зіпсується, 🔴 прострочено).
* **Кошик / Смітник:** Система "м'якого видалення" з можливістю відновити продукт або перенести його у Список покупок.
* **Синхронізований Список Покупок:** Швидкі свайпи для управління (купив/видалив), підтримка метричної системи (кг, г, л, мл, шт).
* **Сімейний доступ (Premium):** Спільний холодильник, списки покупок та внутрішній **Family Messenger** (голосові повідомлення, фото, реплай, реакції ❤️).
* **Deep Linking:** Клік на пуш-сповіщення відкриває конкретний екран або чат у додатку.
* **Еко-Статистика:** Наочні графіки (FlChart) врятованої та зіпсованої їжі.
* **Мультомовність:** Повна локалізація 5-ма мовами (🇺🇦 UA, 🇺🇸 EN, 🇪🇸 ES, 🇫🇷 FR, 🇩🇪 DE).

---

## 💎 Монетизація (Freemium Model)

Додаток використовує гібридну модель для забезпечення найкращого користувацького досвіду:

1.  **Free Tier:** Базовий облік, перегляд реклами (AdMob Banner & Interstitial) для доступу до AI-генерації рецептів.
2.  **Premium (In-App Purchases):**
    * 🚫 Повна відсутність реклами.
    * ♾️ Безлімітне використання ШІ-сканера та генератора рецептів.
    * 👨‍👩‍👧‍👦 Створення та управління "Сім'єю".

---

## 🛠 Технологічний стек

**Mobile App:**
* **Фреймворк:** Flutter (Dart)
* **UI/UX:** Custom animations (`AnimatedSize`, `SlideTransition`), Material 3.
* **Пакетна база:** `flutter_local_notifications`, `app_links`, `flutter_sound`, `fl_chart`, `in_app_purchase`, `google_mobile_ads`.

**Backend & Cloud (Firebase):**
* **База даних:** Cloud Firestore (Real-time sync).
* **Сховище:** Firebase Storage (для голосових повідомлень та фото чату).
* **Автентифікація:** Firebase Auth (Email Link, Google, GitHub).
* **Бекенд-логіка:** Cloud Functions for Firebase (Node.js).
* **Сповіщення:** Firebase Cloud Messaging (FCM HTTP v1 API).

**Artificial Intelligence:**
* **Text & Vision:** `@google/generative-ai` (Gemini 2.5 Flash & Gemini Vision) інтегрований через безпечні Cloud Functions.

---

## 👨‍💻 Розробник

Цей проект розроблено та підтримується **Pavlo Lugovy (Pavlitoo)** — Frontend & Mobile Developer.

* **GitHub:** [Pavlitoo](https://github.com/Pavlitoo)
* **Email:** pasalugovij@gmail.com
* **Landing Page:** [fridgify-website.vercel.app](https://fridgify-website.vercel.app)

---

<div align="center">
  <sub>Розроблено з ❤️ в Україні 🇺🇦 | Clean Code & Modern Architecture</sub>
</div>