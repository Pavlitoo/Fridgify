import 'global.dart';

class AppText {
  static String get(String key) {
    String lang = languageNotifier.value;
    return _localizedValues[lang]?[key] ?? _localizedValues['English']?[key] ?? key;
  }

  static final Map<String, Map<String, String>> _localizedValues = {
    // 🇺🇦 УКРАЇНСЬКА
    'Українська': {
      'login_title': 'Вхід', 'signup_title': 'Реєстрація', 'login_btn': 'Увійти', 'signup_btn': 'Створити акаунт',
      'name_field': 'Ім\'я', 'password_field': 'Пароль', 'no_account': 'Немає акаунту? Реєстрація', 'has_account': 'Вже є акаунт? Вхід',

      'my_fridge': 'Мій Холодильник',
      'empty_fridge': 'Холодильник порожній 😔',
      'empty_fridge_sub': 'Саме час поповнити запаси! 🍎', // Є
      'add_product': 'Додати', 'cook_btn': 'ШУКАТИ РЕЦЕПТИ 🍳',
      'cat_all': 'Всі', 'cat_other': 'Інше', 'cat_meat': 'М\'ясо', 'cat_veg': 'Овочі', 'cat_fruit': 'Фрукти', 'cat_dairy': 'Молочка', 'cat_bakery': 'Випічка', 'cat_sweet': 'Солодощі', 'cat_drink': 'Напої',
      'u_pcs': 'шт', 'u_kg': 'кг', 'u_g': 'g', 'u_l': 'l', 'u_ml': 'мл', 'days_left': 'Залишилось:', 'u_days': 'дн.', 'u_months': 'міс.',
      'edit_product': 'Редагувати', 'product_name': 'Назва продукту', 'quantity': 'Кількість', 'category_label': 'Категорія', 'days_valid': 'Придатний до:',
      'cancel': 'Відміна', 'save': 'Зберегти', 'add': 'Додати', 'action_eaten': 'З\'їли', 'yes_list': 'У список', 'no_delete': 'Видалити',
      'recipe_title': 'Що приготувати? 🥗', 'req_sent': 'Запит надіслано!',

      'my_profile': 'Мій Профіль', 'select_lang': 'Оберіть мову', 'map_btn': 'Моє місцезнаходження 📍', 'searching_loc': 'Шукаємо тебе...',
      'stats_title': 'Еко-Статистика', 'faq_title': 'Допомога (FAQ)', 'family_settings': 'Моя Сім\'я',
      'theme_dark': 'Темна тема', 'language': 'Мова', 'loading': 'Завантаження...',
      'chat_title': 'Сімейний Чат 💬', 'chat_hint': 'Повідомлення...',

      'shopping_title': 'Список покупок 🛒', 'shopping_hint': 'Що треба купити?',
      'list_empty': 'Список порожній',
      'list_empty_sub': 'Додайте, що плануєте купити 📝', // Є

      'stat_history': 'Загальна історія', 'stat_products': 'Продуктів оброблено', 'stat_efficiency': 'Ефективність',
      'stat_success': 'Рівень успіху', 'stat_saved': 'Врятовано', 'stat_wasted': 'Втрачено', 'stat_no_data': 'Немає даних',

      'fam_code': 'Ваш код запрошення:', 'fam_copy': 'Натисніть на код, щоб скопіювати', 'fam_members': 'Учасники',
      'fam_admin': 'Адміністратор сім\'ї 👑', 'fam_member': 'Учасник', 'fam_leave': 'Вийти з сім\'ї', 'fam_create': 'Створити сім\'ю', 'fam_join': 'Приєднатися', 'fam_not_in': 'Ви ще не в сім\'ї',
      'fam_requests': '🔔 Запити на вступ:', 'fam_me': ' (Я)',

      'faq_q1': 'Як працює пошук рецептів?', 'faq_a1': 'Оберіть продукти в холодильнику (натисніть на них) і натисніть кнопку з ковпаком шефа.',
      'faq_q2': 'Коли приходять сповіщення?', 'faq_a2': 'За 2 дні до закінчення терміну придатності продукта.',
      'faq_q3': 'Як перенести продукт у список?', 'faq_a3': 'Натисніть три крапки біля продукта -> "У список".',
      'faq_q4': 'Де зберігаються дані?', 'faq_a4': 'Усі дані надійно захищені в хмарі Google Firebase.',
      'faq_q5': 'Що таке Premium?', 'faq_a5': 'Безлімітний пошук рецептів, відсутність реклами та підтримка розробки.',
    },

    // 🇺🇸 ENGLISH
    'English': {
      'login_title': 'Login', 'signup_title': 'Sign Up', 'login_btn': 'Login', 'signup_btn': 'Create Account',
      'name_field': 'Name', 'password_field': 'Password', 'no_account': 'No account? Sign Up', 'has_account': 'Has account? Login',
      'my_fridge': 'My Fridge',
      'empty_fridge': 'Fridge is empty 😔',
      'empty_fridge_sub': 'Time to restock! 🍎', // Added
      'add_product': 'Add', 'cook_btn': 'FIND RECIPES 🍳',
      'cat_all': 'All', 'cat_other': 'Other', 'cat_meat': 'Meat', 'cat_veg': 'Veggie', 'cat_fruit': 'Fruit', 'cat_dairy': 'Dairy', 'cat_bakery': 'Bakery', 'cat_sweet': 'Sweets', 'cat_drink': 'Drinks',
      'u_pcs': 'pcs', 'u_kg': 'kg', 'u_g': 'g', 'u_l': 'l', 'u_ml': 'ml', 'days_left': 'Left:', 'u_days': 'd.', 'u_months': 'mo.',
      'edit_product': 'Edit', 'product_name': 'Product Name', 'quantity': 'Quantity', 'category_label': 'Category', 'days_valid': 'Valid until:',
      'cancel': 'Cancel', 'save': 'Save', 'add': 'Add', 'action_eaten': 'Eaten', 'yes_list': 'To List', 'no_delete': 'Delete',
      'recipe_title': 'What to cook? 🥗', 'req_sent': 'Request sent!',
      'my_profile': 'My Profile', 'select_lang': 'Select Language', 'map_btn': 'My Location 📍', 'searching_loc': 'Locating you...',
      'stats_title': 'Eco-Statistics', 'faq_title': 'Help (FAQ)', 'family_settings': 'My Family',
      'theme_dark': 'Dark Mode', 'language': 'Language', 'loading': 'Loading...',
      'chat_title': 'Family Chat 💬', 'chat_hint': 'Message...',
      'shopping_title': 'Shopping List 🛒', 'shopping_hint': 'What to buy?',
      'list_empty': 'List is empty',
      'list_empty_sub': 'Add what you plan to buy 📝', // Added
      'stat_history': 'Overall History', 'stat_products': 'Products processed', 'stat_efficiency': 'Efficiency',
      'stat_success': 'Success level', 'stat_saved': 'Saved', 'stat_wasted': 'Wasted', 'stat_no_data': 'No data',
      'fam_code': 'Your invite code:', 'fam_copy': 'Tap code to copy', 'fam_members': 'Members',
      'fam_admin': 'Family Admin 👑', 'fam_member': 'Member', 'fam_leave': 'Leave Family', 'fam_create': 'Create Family', 'fam_join': 'Join Family', 'fam_not_in': 'You are not in a family',
      'fam_requests': '🔔 Join Requests:', 'fam_me': ' (Me)',
      'faq_q1': 'How does recipe search work?', 'faq_a1': 'Select products and press chef hat button.',
      'faq_q2': 'When do notifications arrive?', 'faq_a2': '2 days before expiration.',
      'faq_q3': 'How to move to list?', 'faq_a3': 'Tap three dots -> "To List".',
      'faq_q4': 'Where is data stored?', 'faq_a4': 'Securely on Google Firebase.',
      'faq_q5': 'What is Premium?', 'faq_a5': 'Full access without ads.',
    },

    // 🇪🇸 ESPAÑOL (ДОДАНО ПЕРЕКЛАДИ ТУТ)
    'Español': {
      'login_title': 'Acceso', 'signup_title': 'Registro', 'login_btn': 'Entrar', 'signup_btn': 'Crear Cuenta',
      'name_field': 'Nombre', 'password_field': 'Contraseña', 'no_account': '¿No tienes cuenta? Regístrate', 'has_account': '¿Ya tienes cuenta? Entrar',
      'my_fridge': 'Mi Nevera',
      'empty_fridge': 'La nevera está vacía 😔',
      'empty_fridge_sub': '¡Es hora de reponer! 🍎', // Перекладено
      'add_product': 'Añadir', 'cook_btn': 'BUSCAR RECETAS 🍳',
      'cat_all': 'Todo', 'cat_other': 'Otro', 'cat_meat': 'Carne', 'cat_veg': 'Verduras', 'cat_fruit': 'Frutas', 'cat_dairy': 'Lácteos', 'cat_bakery': 'Panadería', 'cat_sweet': 'Dulces', 'cat_drink': 'Bebidas',
      'u_pcs': 'pz', 'u_kg': 'kg', 'u_g': 'g', 'u_l': 'l', 'u_ml': 'ml', 'days_left': 'Quedan:', 'u_days': 'd.', 'u_months': 'ms.',
      'edit_product': 'Editar', 'product_name': 'Nombre del producto', 'quantity': 'Cantidad', 'category_label': 'Categoría', 'days_valid': 'Válido hasta:',
      'cancel': 'Cancelar', 'save': 'Guardar', 'add': 'Añadir', 'action_eaten': 'Comido', 'yes_list': 'A la lista', 'no_delete': 'Eliminar',
      'recipe_title': '¿Qué cocinar? 🥗', 'req_sent': '¡Solicitud enviada!',
      'my_profile': 'Mi Perfil', 'select_lang': 'Seleccionar idioma', 'map_btn': 'Mi Ubicación 📍', 'searching_loc': 'Buscándote...',
      'stats_title': 'Eco-Estadísticas', 'faq_title': 'Ayuda (FAQ)', 'family_settings': 'Mi Familia',
      'theme_dark': 'Modo Oscuro', 'language': 'Idioma', 'loading': 'Cargando...',
      'chat_title': 'Chat Familiar 💬', 'chat_hint': 'Mensaje...',
      'shopping_title': 'Lista de Compras 🛒', 'shopping_hint': '¿Qué comprar?',
      'list_empty': 'La lista está vacía',
      'list_empty_sub': 'Añade lo que planeas comprar 📝', // Перекладено
      'stat_history': 'Historial General', 'stat_products': 'Productos procesados', 'stat_efficiency': 'Eficiencia',
      'stat_success': 'Nivel de éxito', 'stat_saved': 'Salvado', 'stat_wasted': 'Desperdiciado', 'stat_no_data': 'Sin datos',
      'fam_code': 'Tu código:', 'fam_copy': 'Toca para copiar', 'fam_members': 'Miembros',
      'fam_admin': 'Admin de Familia 👑', 'fam_member': 'Miembro', 'fam_leave': 'Salir de familia', 'fam_create': 'Crear Familia', 'fam_join': 'Unirse', 'fam_not_in': 'No estás en familia',
      'fam_requests': '🔔 Solicitudes:', 'fam_me': ' (Yo)',
      'faq_q1': '¿Cómo añadir producto?', 'faq_a1': 'Presiona el botón "+" en la pantalla principal.',
      'faq_q2': '¿Cómo buscar recetas?', 'faq_a2': 'Selecciona productos y presiona el botón del chef.',
      'faq_q3': '¿Cómo crear familia?', 'faq_a3': 'Perfil -> Mi Familia -> Crear.',
      'faq_q4': '¿Cómo eliminar producto?', 'faq_a4': 'Toca los tres puntos -> Eliminar.',
      'faq_q5': '¿Qué es Premium?', 'faq_a5': 'Acceso total sin anuncios.',
    },

    // 🇫🇷 FRANÇAIS (ДОДАНО ПЕРЕКЛАДИ ТУТ)
    'Français': {
      'login_title': 'Connexion', 'signup_title': 'S\'inscrire', 'login_btn': 'Entrer', 'signup_btn': 'Créer un compte',
      'name_field': 'Nom', 'password_field': 'Mot de passe', 'no_account': 'Pas de compte? S\'inscrire', 'has_account': 'Déjà un compte? Entrer',
      'my_fridge': 'Mon Frigo',
      'empty_fridge': 'Le frigo est vide 😔',
      'empty_fridge_sub': 'Il est temps de se réapprovisionner! 🍎', // Перекладено
      'add_product': 'Ajouter', 'cook_btn': 'TROUVER RECETTES 🍳',
      'cat_all': 'Tout', 'cat_other': 'Autre', 'cat_meat': 'Viande', 'cat_veg': 'Légumes', 'cat_fruit': 'Fruits', 'cat_dairy': 'Laitier', 'cat_bakery': 'Boulangerie', 'cat_sweet': 'Sucreries', 'cat_drink': 'Boissons',
      'u_pcs': 'pc', 'u_kg': 'kg', 'u_g': 'g', 'u_l': 'l', 'u_ml': 'ml', 'days_left': 'Reste:', 'u_days': 'j.', 'u_months': 'ms.',
      'edit_product': 'Modifier', 'product_name': 'Nom du produit', 'quantity': 'Quantité', 'category_label': 'Catégorie', 'days_valid': 'Valable jusqu\'au:',
      'cancel': 'Annuler', 'save': 'Enregistrer', 'add': 'Ajouter', 'action_eaten': 'Mangé', 'yes_list': 'À la liste', 'no_delete': 'Supprimer',
      'recipe_title': 'Quoi cuisiner? 🥗', 'req_sent': 'Demande envoyée!',
      'my_profile': 'Mon Profil', 'select_lang': 'Choisir la langue', 'map_btn': 'Ma Localisation 📍', 'searching_loc': 'Localisation...',
      'stats_title': 'Éco-Statistiques', 'faq_title': 'Aide (FAQ)', 'family_settings': 'Ma Famille',
      'theme_dark': 'Mode Sombre', 'language': 'Langue', 'loading': 'Chargement...',
      'chat_title': 'Chat de Famille 💬', 'chat_hint': 'Message...',
      'shopping_title': 'Liste de Courses 🛒', 'shopping_hint': 'Quoi acheter?',
      'list_empty': 'Liste vide',
      'list_empty_sub': 'Ajoutez ce que vous prévoyez d\'acheter 📝', // Перекладено
      'stat_history': 'Historique Global', 'stat_products': 'Produits traités', 'stat_efficiency': 'Efficacité',
      'stat_success': 'Niveau de succès', 'stat_saved': 'Sauvé', 'stat_wasted': 'Gaspillé', 'stat_no_data': 'Pas de données',
      'fam_code': 'Votre code:', 'fam_copy': 'Touchez pour copier', 'fam_members': 'Membres',
      'fam_admin': 'Admin Famille 👑', 'fam_member': 'Membre', 'fam_leave': 'Quitter la famille', 'fam_create': 'Créer Famille', 'fam_join': 'Rejoindre', 'fam_not_in': 'Pas de famille',
      'fam_requests': '🔔 Demandes:', 'fam_me': ' (Moi)',
      'faq_q1': 'Comment ajouter un produit?', 'faq_a1': 'Appuyez sur le bouton "+" sur l\'écran principal.',
      'faq_q2': 'Comment chercher des recettes?', 'faq_a2': 'Sélectionnez les produits et appuyez sur le bouton toque.',
      'faq_q3': 'Comment créer une famille?', 'faq_a3': 'Profil -> Ma Famille -> Créer.',
      'faq_q4': 'Comment supprimer un produit?', 'faq_a4': 'Appuyez sur les trois points -> Supprimer.',
      'faq_q5': 'C\'est quoi Premium?', 'faq_a5': 'Accès complet sans publicité.',
    },

    // 🇩🇪 DEUTSCH (ДОДАНО ПЕРЕКЛАДИ ТУТ)
    'Deutsch': {
      'login_title': 'Anmelden', 'signup_title': 'Registrieren', 'login_btn': 'Einloggen', 'signup_btn': 'Konto erstellen',
      'name_field': 'Name', 'password_field': 'Passwort', 'no_account': 'Kein Konto? Registrieren', 'has_account': 'Bereits ein Konto? Einloggen',
      'my_fridge': 'Mein Kühlschrank',
      'empty_fridge': 'Kühlschrank ist leer 😔',
      'empty_fridge_sub': 'Zeit zum Nachfüllen! 🍎', // Перекладено
      'add_product': 'Hinzufügen', 'cook_btn': 'REZEPTE FINDEN 🍳',
      'cat_all': 'Alle', 'cat_other': 'Andere', 'cat_meat': 'Fleisch', 'cat_veg': 'Gemüse', 'cat_fruit': 'Obst', 'cat_dairy': 'Milch', 'cat_bakery': 'Bäckerei', 'cat_sweet': 'Süßigkeiten', 'cat_drink': 'Getränke',
      'u_pcs': 'stk', 'u_kg': 'kg', 'u_g': 'g', 'u_l': 'l', 'u_ml': 'ml', 'days_left': 'Übrig:', 'u_days': 't.', 'u_months': 'mon.',
      'edit_product': 'Bearbeiten', 'product_name': 'Produktname', 'quantity': 'Menge', 'category_label': 'Kategorie', 'days_valid': 'Gültig bis:',
      'cancel': 'Abbrechen', 'save': 'Speichern', 'add': 'Hinzufügen', 'action_eaten': 'Gegessen', 'yes_list': 'Zur Liste', 'no_delete': 'Löschen',
      'recipe_title': 'Was kochen? 🥗', 'req_sent': 'Anfrage gesendet!',
      'my_profile': 'Mein Profil', 'select_lang': 'Sprache wählen', 'map_btn': 'Mein Standort 📍', 'searching_loc': 'Standortbestimmung...',
      'stats_title': 'Öko-Statistik', 'faq_title': 'Hilfe (FAQ)', 'family_settings': 'Meine Familie',
      'theme_dark': 'Dunkelmodus', 'language': 'Sprache', 'loading': 'Laden...',
      'chat_title': 'Familien-Chat 💬', 'chat_hint': 'Nachricht...',
      'shopping_title': 'Einkaufsliste 🛒', 'shopping_hint': 'Was kaufen?',
      'list_empty': 'Liste ist leer',
      'list_empty_sub': 'Fügen Sie hinzu, was Sie kaufen möchten 📝', // Перекладено
      'stat_history': 'Gesamtverlauf', 'stat_products': 'Produkte verarbeitet', 'stat_efficiency': 'Effizienz',
      'stat_success': 'Erfolgsquote', 'stat_saved': 'Gerettet', 'stat_wasted': 'Verschwendet', 'stat_no_data': 'Keine Daten',
      'fam_code': 'Ihr Code:', 'fam_copy': 'Zum Kopieren tippen', 'fam_members': 'Mitglieder',
      'fam_admin': 'Familien-Admin 👑', 'fam_member': 'Mitglied', 'fam_leave': 'Familie verlassen', 'fam_create': 'Familie erstellen', 'fam_join': 'Beitreten', 'fam_not_in': 'Keine Familie',
      'fam_requests': '🔔 Anfragen:', 'fam_me': ' (Ich)',
      'faq_q1': 'Wie füge ich ein Produkt hinzu?', 'faq_a1': 'Drücken Sie den "+" Knopf auf dem Hauptbildschirm.',
      'faq_q2': 'Wie sucht man Rezepte?', 'faq_a2': 'Produkte auswählen und den Knopf drücken.',
      'faq_q3': 'Wie erstelle ich eine Familie?', 'faq_a3': 'Profil -> Meine Familie -> Erstellen.',
      'faq_q4': 'Wie lösche ich ein Produkt?', 'faq_a4': 'Drei Punkte drücken -> Löschen.',
      'faq_q5': 'Was ist Premium?', 'faq_a5': 'Voller Zugriff ohne Werbung.',
    },
  };
}