import 'global.dart';

class AppText {
  static String get(String key) {
    String lang = languageNotifier.value;
    if (lang.isEmpty) {
      lang = 'Українська';
    }
    return _localizedValues[lang]?[key] ?? _localizedValues['English']?[key] ?? key;
  }

  static final Map<String, Map<String, String>> _localizedValues = {
    // 🇺🇦 УКРАЇНСЬКА
    'Українська': {
      'err_login_bad': 'Невірна пошта або пароль', 'err_email_bad': 'Невірний формат пошти', 'err_pass_weak': 'Пароль занадто слабкий', 'err_user_exists': 'Ця пошта вже використовується', 'err_too_many_requests': 'Забагато спроб. Спробуйте пізніше',
      "no_internet_title": "Немає з'єднання", "no_internet_desc": "Здається, ви не підключені до інтернету. Будь ласка, перевірте налаштування мережі та спробуйте ще раз.", "retry_btn": "Повторити спробу",
      'notif_family': 'Сім\'я', 'notif_reply_to': '↪️ Відповідь для', 'notif_liked': 'вподобав(ла)', 'notif_new_msg': 'Нове повідомлення', 'notif_someone': 'Хтось', 'notif_batch_title': 'Увага! Продукти псуються ⏰', 'notif_batch_body': 'Треба з\'їсти:',
      'msg_name_changed': 'Ім\'я змінено! ✅', 'notif_instant_title': 'Зіпсовані продукти', 'notif_instant_body': 'Важливо! Продукти, які вже треба викинути', 'notif_warn_title': 'З\'їж мене! ⏰', 'notif_warn_body': 'закінчується через 2 дні!', 'notif_channel_name': 'Нагадування', 'notif_channel_desc': 'Нагадування про продукти',
      'chat_title': 'Сімейний чат', 'chat_hold_to_record': 'Утримуйте, щоб записати 🎤', 'msg_ai_thinking': 'Шеф складає меню... 👨‍🍳', 'err_invalid_ingredients': 'Це не схоже на їжу 🤔 Оберіть справжні продукти!', 'ingredients_title': 'Інгредієнти (з холодильника):', 'missing_title': 'Треба докупити (або спеції):', 'recipe_steps': 'Інструкція приготування', 'recipe_title': 'Рецепт ШІ', 'err_recipe_failed': 'Не вдалося створити рецепт. Спробуйте ще раз.',
      'tag_healthy': 'Здорове харчування', 'prem_sub_active': 'Ваша підписка активна. Насолоджуйтесь усіма перевагами!', 'prem_congrats': 'Вітаємо! Ви Premium! 🎉', 'prem_btn_buy': 'Купити Premium', 'prem_active': 'Premium Активний 👑', 'prem_title': 'Premium Доступ', 'prem_desc': 'Всі функції без обмежень', 'prem_btn_manage': 'Керувати підпискою', 'prem_btn_restore': 'Відновити покупки', 'ben_1': 'Повна відсутність реклами', 'ben_2': 'Безлімітні рецепти', 'ben_3': 'Сімейний доступ', 'ben_4': 'Розумніша модель GPT-4', 'err_store': 'Помилка магазину', 'msg_buy_error': 'Покупку скасовано',
      'err_user_not_found': 'Користувача не знайдено', 'err_wrong_pass': 'Невірний пароль', 'err_email_exist': 'Цей Email вже використовується', 'err_invalid_email': 'Некоректний формат Email', 'err_weak_pass': 'Пароль занадто слабкий', 'err_min_pass_length': 'Пароль має містити мінімум 8 символів', 'err_access_denied': 'Доступ заборонено', 'err_too_many': 'Забагато спроб. Спробуйте пізніше', 'err_no_internet': 'Немає інтернету 🔌', 'err_no_internet_short': 'Відсутній інтернет 🔌', 'err_general': 'Сталася помилка', 'err_canceled': 'Дію скасовано', 'err_fill_all': 'Заповніть усі поля', 'err_enter_email': 'Введіть Email', 'err_enter_name': 'Введіть ваше Ім\'я', 'req_sent': 'Запит надіслано!', 'err_check_internet': 'Перевірте з\'єднання', 'err_unknown': 'Невідома помилка', 'msg_email_sent': 'Лист для відновлення паролю надіслано!', 'msg_account_created': 'Акаунт успішно створено!', 'msg_welcome': 'З поверненням!',
      'login_title': 'Вхід', 'signup_title': 'Реєстрація', 'login_btn': 'Увійти', 'signup_btn': 'Створити акаунт', 'name_field': 'Ім\'я', 'email_field': 'Електронна пошта', 'password_field': 'Пароль', 'forgot_pass': 'Забули пароль?', 'no_account': 'Немає акаунту?', 'create_one': 'Створити', 'has_account': 'Вже є акаунт?', 'enter_one': 'Увійти', 'or_continue': 'Або увійти через', 'saved_title': 'Збережені рецепти 📖', 'saved_empty': 'Ви ще нічого не зберегли', 'msg_recipe_saved': 'Рецепт збережено! ❤️', 'msg_recipe_removed': 'Рецепт видалено з улюблених', 'btn_saved_recipes': 'Мої Рецепти', 'limit_title': 'Ліміт на сьогодні 🛑', 'limit_content': 'Ви використали 10 безкоштовних пошуків.\nЩоб готувати без обмежень, перейдіть на Premium!', 'btn_premium': 'Premium', 'btn_ok': 'ОК', 'msg_select_products': 'Спочатку оберіть продукти зі списку!', 'msg_code_copied': 'Код скопійовано! ✅', 'fam_wants_join': 'Хоче приєднатися', 'fam_you_tag': 'Я', 'diet_title': 'Який режим харчування? 🥗', 'diet_standard': 'Звичайний (Все їм)', 'diet_vegetarian': 'Вегетаріанське (Без м\'яса)', 'diet_vegan': 'Веганське (Тільки рослинне)', 'diet_healthy': 'ПП (Здорове)', 'diet_keto': 'Кето (Без вуглеводів)', 'tag_standard': 'Смачно', 'tag_vegetarian': 'Вегетаріанське', 'tag_vegan': 'Веган', 'tag_keto': 'Кето', 'btn_start_cooking': 'Знайти рецепти! 🚀', 'btn_yes': 'Так', 'btn_no': 'Ні', 'dialog_delete_title': 'Видалити?', 'dialog_delete_content': 'Цю дію не можна скасувати.', 'dialog_delete_confirm': 'Ви впевнені?',
      'my_fridge': 'Мій Холодильник', 'add_product': 'Додати', 'edit_product': 'Редагувати', 'product_name': 'Назва продукту', 'quantity': 'Кількість', 'days_valid': 'Придатний до:', 'category_label': 'Категорія', 'save': 'Зберегти', 'add': 'Додати', 'cancel': 'Скасувати', 'cook_btn': 'Готувати 🍳', 'empty_fridge': 'Холодильник порожній', 'cat_all': 'Всі', 'cat_other': 'Інше', 'cat_meat': 'М\'ясо', 'cat_veg': 'Овочі', 'cat_fruit': 'Фрукти', 'cat_dairy': 'Молочка', 'cat_bakery': 'Випічка', 'cat_sweet': 'Солодощі', 'cat_drink': 'Напої', 'u_pcs': 'шт', 'u_kg': 'кг', 'u_g': 'г', 'u_l': 'л', 'u_ml': 'мл', 'u_days': 'дн.', 'u_months': 'міс.', 'action_eaten': 'З\'їдено 😋', 'btn_buy': 'Купити знову', 'btn_restore': 'Відновити', 'btn_delete_forever': 'Видалити', 'no_delete': 'Видалити цей продукт?', 'yes_list': '-> Холодильник', 'trash_title': 'Смітник', 'trash_sub': 'Зіпсовані / Видалені', 'trash_empty': 'Пусто', 'status_deleted': 'Видалено', 'status_rotten': 'Зіпсувалося', 'ago_suffix': 'тому', 'msg_deleted_forever': 'Видалено назавжди', 'msg_restored': 'Відновлено', 'msg_change_date': 'Будь ласка, змініть дату!', 'shopping_title': 'Список покупок 🛒', 'shopping_hint': 'Що треба купити?', 'list_empty': 'Список порожній', 'list_empty_sub': 'Додайте сюди щось', 'rec_time': 'Час', 'rec_kcal': 'ккал', 'rec_veg': 'Вегетаріанське', 'rec_non_veg': 'З м\'ясом', 'rec_ingredients': 'Інгредієнти', 'rec_steps': 'Кроки', 'rec_missing': 'Не вистачає:', 'rec_cooking': 'Готуємо...', 'rec_step': 'Крок', 'rec_full_desc': 'Детальний опис', 'stats_title': 'Еко-Статистика 📊', 'stat_no_data': 'Немає даних', 'stat_filter_week': 'Тиждень', 'stat_filter_month': 'Місяць', 'stat_filter_all': 'Все', 'stat_eco_rating': 'Ефективність', 'stat_great': 'Чудово!', 'stat_average': 'Норм', 'stat_bad': 'Погано', 'stat_total': 'Всього', 'stat_saved': 'Врятовано', 'stat_wasted': 'Втрачено', 'stat_efficiency': 'Ефект.', 'stat_history': 'Історія дій', 'stat_empty_history': 'Історія порожня', 'my_profile': 'Мій Профіль', 'select_lang': 'Мова', 'theme_dark': 'Темна тема', 'family_settings': 'Моя Сім\'я', 'faq_title': 'FAQ (Допомога)', 'map_btn': 'Ваше місцезнаходження 📍', 'searching_loc': 'Шукаю вашу локацію...', 'fam_create': 'Створити сім\'ю 🏠', 'fam_join': 'Приєднатися 🔗', 'fam_code': 'Код сім\'ї:', 'fam_copy': 'Копіювати', 'fam_members': 'Учасники', 'fam_leave': 'Покинути сім\'ю', 'fam_admin': 'Адміністратор 👑', 'fam_member': 'Учасник', 'fam_me': ' (Я)', 'fam_requests': 'Запити на вступ', 'fam_welcome_title': 'Об\'єднайтеся з родиною!', 'fam_welcome_desc': 'Створіть спільний простір для продуктів.',
      'find_recipes': 'Знайти рецепти!', 'ingredients_fridge': 'Інгредієнти (з холодильника)', 'instructions': 'Інструкції', 'btn_add_all': 'Додати всі у список', 'msg_sent': 'Надіслано ✅', 'milk': 'Молоко', 'flour': 'Борошно', 'egg': 'Яйце', 'salt': 'Сіль', 'sugar': 'Цукор', 'water': 'Вода',
      'chat_change_bg': 'Змінити фон', 'chat_remove_bg': 'Видалити фон', 'chat_color': 'Колір повідомлень', 'chat_font_size': 'Розмір тексту', 'chat_font_sample': 'Приклад тексту', 'chat_media_only': 'Тільки медіа', 'chat_stats': 'Статистика чату', 'chat_clear_history': 'Очистити історію', 'chat_pinned': 'Закріплене повідомлення', 'chat_recipe_offer': 'Пропонує рецепт', 'chat_open_recipe': 'Відкрити рецепт', 'chat_total_votes': 'Всього голосів:', 'poll_create': 'Створити опитування', 'poll_question_hint': 'Запитання (напр. Що на вечерю?)', 'poll_option': 'Варіанти відповідей', 'poll_add_option': 'Додати варіант', 'poll_cancel': 'Скасувати', 'poll_send': 'Створити', 'chat_uploading': 'Завантаження медіа...', 'chat_copy': 'Скопіювати', 'chat_pin': 'Закріпити', 'chat_save_gallery': 'Зберегти в галерею', 'chat_download_file': 'Завантажити файл', 'chat_attachment_gallery': 'Галерея', 'chat_attachment_file': 'Документ / Файл', 'chat_attachment_poll': 'Опитування', 'chat_stats_total': 'Всього повідомлень', 'chat_stats_text': 'Текст', 'chat_stats_photo': 'Фото', 'chat_stats_voice': 'Голосові', 'chat_stats_file': 'Файли', 'chat_stats_ok': 'Зрозуміло', 'chat_voice_msg': 'Голосове повідомлення', 'chat_photo_msg': 'Фото', 'chat_poll_msg': 'Опитування', 'chat_recipe_msg': 'Рецепт', 'chat_search': 'Пошук...', 'chat_nothing_found': 'Нічого не знайдено', 'chat_release_to_send': 'Відпустіть для відправки', 'chat_silent_send': 'Відправити без звуку', 'chat_silent_desc': 'Отримувач не отримає push-сповіщення зі звуком', 'chat_seen_by': 'Переглянули', 'chat_nobody_seen': 'Ще ніхто не переглянув', 'msg_saved_gallery': 'Збережено в галерею!', 'msg_copied': 'Скопійовано', 'msg_pinned': 'Закріплено', 'msg_cleared': 'Очищено', 'msg_error': 'Помилка', 'chat_reply': 'Відповісти', 'chat_edit': 'Редагувати', 'chat_delete': 'Видалити', 'chat_personal': 'Особисті', 'chat_hint': 'Написати повідомлення...', 'chat_no_messages': 'Поки немає повідомлень', 'dialog_clear_title': 'Очистити?', 'dialog_clear_content': 'Видалити усі повідомлення?', 'chat_option_text': 'Варіант',
      'faq_q1': 'Як додати продукт?', 'faq_a1': 'Натисніть кнопку "+" внизу праворуч у вкладці "Мій Холодильник". Введіть назву, категорію та дату.', 'faq_q2': 'Як видалити продукт?', 'faq_a2': 'Натисніть на три крапки на картці продукту та оберіть "Видалити", або перемістіть його у Смітник.', 'faq_q3': 'Як працює ШІ?', 'faq_a3': 'Оберіть галочками продукти, які у вас є, та натисніть кнопку "Готувати". ШІ підбере найкращі рецепти, враховуючи ваші інгредієнти та їх кількість.', 'faq_q4': 'Як змінити мову?', 'faq_a4': 'Перейдіть у вкладку "Профіль", прокрутіть вниз до розділу налаштувань і натисніть "Мова". Оберіть бажану мову зі списку.', 'faq_q5': 'Як відновити видалений продукт?', 'faq_a5': 'Відкрийте "Смітник" (іконка у верхньому правому куті холодильника). Знайдіть продукт, натисніть меню та оберіть "Відновити".', 'faq_q6': 'Що дає Premium?', 'faq_a6': 'Premium відкриває доступ до сімейного режиму, прибирає рекламу, дає безлімітний пошук рецептів та доступ до розумнішої моделі GPT-4.', 'faq_q7': 'Як зв\'язатися з підтримкою?', 'faq_a7': 'Якщо у вас виникли питання, напишіть нам на email: pasalugovij@gmail.com. Мі з радістю допоможемо!',
      'share_recipe': 'Поділитися рецептом', 'share_external': 'Надіслано в інші додатки', 'share_external_sub': 'Telegram, Viber, Instagram...', 'no_family_share': "Створіть сім'ю в профілі, щоб ділитися рецептами у внутрішньому чаті.", 'err_share_failed': 'Не вдалося поділитися. Перевірте підключення.',
      'scan_title': '📸 Сканувати холодильник', 'scan_camera': 'Камера', 'scan_gallery': 'Галерея', 'scan_analyzing': 'ШІ аналізує фото...\nЦе займе кілька секунд 🪄', 'scan_not_found': 'Продуктів не знайдено 🤔', 'scan_found': 'Знайдено продуктів', 'scan_remove_extra': 'Видаліть зайве перед збереженням', 'scan_no_items': 'Немає продуктів для додавання', 'scan_save_all': 'Зберегти в холодильник', 'scan_success': '✅ Продукти успішно додано!', 'scan_error': 'Помилка збереження:',

      // 🔥 АВТОРИЗАЦІЯ ТА ПЕРЕВІРКА ПОШТИ
      'verify_email_title': 'Підтвердіть пошту 📩',
      'verify_email_desc': 'Ми надіслали лист із посиланням на',
      'btn_logout': 'Вийти з акаунту',
      'btn_i_verified': 'Я вже підтвердив',
      'btn_resend_email': 'Надіслати лист знову',
      'msg_email_verified': 'Пошту успішно підтверджено! ✅',
      'msg_email_resent': 'Лист надіслано повторно 📧',

      // 🔥 КОШИК (СМІТНИК)
      'dialog_clear_trash_desc': 'Ви впевнені, що хочете назавжди видалити всі продукти зі смітника? Цю дію неможливо скасувати.',
      'msg_trash_cleared': 'Смітник повністю очищено! 🧹',
      'tooltip_clear_all': 'Очистити все',
      'err_eat_too_much': 'Не можна з\'їсти більше, ніж є!',

      // 🔥 СКАНЕР ШТРИХКОДІВ
      'scan_barcode_tooltip': 'Сканувати штрихкод',
      'barcode_searching': 'Шукаю продукт в базі...',
      'barcode_not_found': 'Продукт не знайдено 😔. Введіть назву вручну.',
      'barcode_error': 'Помилка сканування',
      'barcode_success': 'Продукт знайдено! ✅',

      // 🔥 НОВИЙ ЕКРАН ПІДПИСКИ (PAYWALL)
      'prem_choose_plan': 'Оберіть свій план',
      'prem_your_sub': 'Ваша Підписка',
      'prem_subtitle': 'Готуйте розумніше, зберігайте більше, діліться з родиною.',
      'prem_per_month': '/ міс.',
      'prem_pro_ben_3': 'Для одного користувача',
      'prem_btn_included': 'Включено у Family',
      'prem_btn_choose_pro': 'Обрати PRO',
      'prem_fam_ben_1': 'Усі можливості Premium PRO',
      'prem_fam_ben_2': 'Доступ для 5 членів сім\'ї',
      'prem_fam_ben_3': 'Спільний чат та списки покупок',
      'prem_fam_ben_4': 'Синхронізація холодильника',
      'prem_btn_upgrade_fam': 'Оновити до Family',
      'prem_btn_choose_fam': 'Обрати FAMILY',
      'prem_badge_best': 'НАЙКРАЩИЙ ВИБІР',
    },

    // 🇺🇸 ENGLISH
    'English': {
      'err_login_bad': 'Incorrect email or password', 'err_email_bad': 'Invalid email format', 'err_pass_weak': 'Password is too weak', 'err_user_exists': 'Email already in use', 'err_too_many_requests': 'Too many attempts. Try later',
      "no_internet_title": "No Internet Connection", "no_internet_desc": "It seems you are not connected to the internet. Please check your network settings and try again.", "retry_btn": "Try Again",
      'notif_family': 'Family', 'notif_reply_to': '↪️ Reply to', 'notif_liked': 'liked', 'notif_new_msg': 'New message', 'notif_someone': 'Someone', 'notif_batch_title': 'Attention! Food is spoiling ⏰', 'notif_batch_body': 'Need to eat:',
      'msg_name_changed': 'Name changed! ✅', 'notif_instant_title': 'Rotten items', 'notif_instant_body': 'Important! Throw these away', 'notif_warn_title': 'Eat me! ⏰', 'notif_warn_body': 'expires in 2 days!', 'notif_channel_name': 'Reminders', 'notif_channel_desc': 'Product expiration reminders',
      'chat_title': 'Family Chat', 'chat_hold_to_record': 'Hold to record 🎤', 'msg_ai_thinking': 'Chef is thinking... 👨‍🍳', 'err_invalid_ingredients': 'Doesn\'t look like food 🤔 Use real ingredients!', 'ingredients_title': 'Ingredients (From Fridge):', 'missing_title': 'Pantry / Missing Items:', 'recipe_steps': 'Instructions', 'recipe_title': 'AI Recipe', 'err_recipe_failed': 'Failed to generate recipe.',
      'tag_healthy': 'Healthy', 'prem_sub_active': 'Your subscription is active. Enjoy all benefits!', 'prem_congrats': 'Congratulations! You are Premium! 🎉', 'prem_btn_buy': 'Go Premium', 'prem_active': 'Premium Active 👑', 'prem_title': 'Get Premium', 'prem_desc': 'Unlock full potential', 'prem_btn_manage': 'Manage Subscription', 'prem_btn_restore': 'Restore Purchases', 'ben_1': 'No Ads', 'ben_2': 'Unlimited Recipes', 'ben_3': 'Family Sharing', 'ben_4': 'Better AI (GPT-4)', 'err_store': 'Store unavailable', 'msg_buy_error': 'Purchase failed',
      'err_user_not_found': 'User not found', 'err_wrong_pass': 'Wrong password', 'err_email_exist': 'Email already in use', 'err_invalid_email': 'Invalid email', 'err_weak_pass': 'Password too weak', 'err_access_denied': 'Access denied', 'err_too_many': 'Too many attempts', 'err_no_internet': 'No Internet connection', 'err_no_internet_short': 'No internet 🔌', 'err_general': 'Something went wrong', 'err_canceled': 'Canceled', 'err_fill_all': 'Please fill all fields', 'err_enter_email': 'Enter Email', 'err_enter_name': 'Enter Name', 'req_sent': 'Sent!', 'err_check_internet': 'Check connection', 'err_unknown': 'Unknown error', 'msg_email_sent': 'Recovery email sent!', 'msg_account_created': 'Account created!', 'msg_welcome': 'Welcome back!',
      'login_title': 'Login', 'signup_title': 'Sign Up', 'login_btn': 'Login', 'signup_btn': 'Create Account', 'name_field': 'Name', 'email_field': 'Email', 'password_field': 'Password', 'forgot_pass': 'Forgot Password?', 'no_account': 'No account?', 'create_one': 'Create', 'has_account': 'Have account?', 'enter_one': 'Login', 'or_continue': 'Or continue with', 'saved_title': 'Saved Recipes 📖', 'saved_empty': 'No saved recipes yet', 'msg_recipe_saved': 'Recipe saved! ❤️', 'msg_recipe_removed': 'Recipe removed from favorites', 'btn_saved_recipes': 'My Recipes', 'limit_title': 'Daily Limit Reached 🛑', 'limit_content': 'To cook without limits, go Premium!', 'btn_premium': 'Premium', 'btn_ok': 'OK', 'msg_select_products': 'Select products first!', 'msg_code_copied': 'Copied! ✅', 'fam_wants_join': 'Wants to join', 'fam_you_tag': 'YOU', 'diet_title': 'Choose Diet Type 🥗', 'diet_standard': 'Standard', 'diet_vegetarian': 'Vegetarian', 'diet_vegan': 'Vegan', 'diet_healthy': 'Healthy', 'diet_keto': 'Keto', 'tag_standard': 'Tasty', 'tag_vegetarian': 'Vegetarian', 'tag_vegan': 'Vegan', 'tag_keto': 'Keto', 'btn_start_cooking': 'Find Recipes! 🚀', 'btn_yes': 'Yes', 'btn_no': 'No', 'dialog_delete_title': 'Delete?', 'dialog_delete_content': 'Cannot be undone.', 'dialog_delete_confirm': 'Sure?',
      'my_fridge': 'My Fridge', 'add_product': 'Add Product', 'edit_product': 'Edit Product', 'product_name': 'Product Name', 'quantity': 'Quantity', 'days_valid': 'Valid until:', 'category_label': 'Category', 'save': 'Save', 'add': 'Add', 'cancel': 'Cancel', 'cook_btn': 'Cook 🍳', 'empty_fridge': 'Fridge is empty', 'cat_all': 'All', 'cat_other': 'Other', 'cat_meat': 'Meat', 'cat_veg': 'Veggie', 'cat_fruit': 'Fruit', 'cat_dairy': 'Dairy', 'cat_bakery': 'Bakery', 'cat_sweet': 'Sweet', 'cat_drink': 'Drink', 'u_pcs': 'pcs', 'u_kg': 'kg', 'u_g': 'g', 'u_l': 'l', 'u_ml': 'ml', 'u_days': 'd.', 'u_months': 'mo.', 'action_eaten': 'Eaten 😋', 'btn_buy': 'Buy again', 'btn_restore': 'Restore', 'btn_delete_forever': 'Delete Forever', 'no_delete': 'Delete this item?', 'yes_list': '-> Fridge', 'trash_title': 'Trash Bin', 'trash_sub': 'Rotten / Deleted', 'trash_empty': 'Trash is empty', 'status_deleted': 'Deleted', 'status_rotten': 'Rotten', 'ago_suffix': 'ago', 'msg_deleted_forever': 'Deleted forever', 'msg_restored': 'Product restored', 'msg_change_date': 'Please change date!', 'shopping_title': 'Shopping List 🛒', 'shopping_hint': 'What to buy?', 'list_empty': 'List is empty', 'list_empty_sub': 'Add items here', 'rec_time': 'Time', 'rec_kcal': 'kcal', 'rec_veg': 'Vegetarian', 'rec_non_veg': 'Non-Veg', 'rec_ingredients': 'Ingredients', 'rec_steps': 'Steps', 'rec_missing': 'Missing:', 'rec_cooking': 'Cooking...', 'rec_step': 'Step', 'rec_full_desc': 'Details', 'stats_title': 'Eco-Statistics 📊', 'stat_no_data': 'No data available', 'stat_filter_week': '7 Days', 'stat_filter_month': 'Month', 'stat_filter_all': 'All Time', 'stat_eco_rating': 'Efficiency', 'stat_great': 'Great job!', 'stat_average': 'Could be better', 'stat_bad': 'Too much waste', 'stat_total': 'Total', 'stat_saved': 'Saved', 'stat_wasted': 'Wasted', 'stat_efficiency': 'Efficiency', 'stat_history': 'History', 'stat_empty_history': 'Empty', 'my_profile': 'My Profile', 'select_lang': 'Language', 'language': 'Language', 'theme_dark': 'Dark Mode', 'family_settings': 'My Family', 'faq_title': 'Help & FAQ', 'map_btn': 'Your Location 📍', 'searching_loc': 'Locating...', 'fam_create': 'Create Family', 'fam_join': 'Join Family', 'fam_code': 'Family Code:', 'fam_copy': 'Copy', 'fam_members': 'Members', 'fam_leave': 'Leave', 'fam_admin': 'Admin', 'fam_member': 'Member', 'fam_me': ' (Me)', 'fam_requests': 'Requests', 'fam_welcome_title': 'Unite!', 'fam_welcome_desc': 'Share products.',
      'find_recipes': 'Find Recipes!', 'ingredients_fridge': 'Ingredients (from fridge)', 'instructions': 'Instructions', 'btn_add_all': 'Add all to list', 'msg_sent': 'Sent ✅', 'milk': 'Milk', 'flour': 'Flour', 'egg': 'Egg', 'salt': 'Salt', 'sugar': 'Sugar', 'water': 'Water',
      'chat_change_bg': 'Change Background', 'chat_remove_bg': 'Remove Background', 'chat_color': 'Message Color', 'chat_font_size': 'Text Size', 'chat_font_sample': 'Text Sample', 'chat_media_only': 'Media Only', 'chat_stats': 'Chat Statistics', 'chat_clear_history': 'Clear History', 'chat_pinned': 'Pinned Message', 'chat_recipe_offer': 'Suggests a recipe', 'chat_open_recipe': 'Open Recipe', 'chat_total_votes': 'Total votes:', 'poll_create': 'Create Poll', 'poll_question_hint': 'Question (e.g. What\'s for dinner?)', 'poll_option': 'Options', 'poll_add_option': 'Add Option', 'poll_cancel': 'Cancel', 'poll_send': 'Create', 'chat_uploading': 'Uploading media...', 'chat_copy': 'Copy', 'chat_pin': 'Pin', 'chat_save_gallery': 'Save to Gallery', 'chat_download_file': 'Download File', 'chat_attachment_gallery': 'Gallery', 'chat_attachment_file': 'Document / File', 'chat_attachment_poll': 'Poll', 'chat_stats_total': 'Total Messages', 'chat_stats_text': 'Text', 'chat_stats_photo': 'Photo', 'chat_stats_voice': 'Voice', 'chat_stats_file': 'Files', 'chat_stats_ok': 'Got it', 'chat_voice_msg': 'Voice message', 'chat_photo_msg': 'Photo', 'chat_poll_msg': 'Poll', 'chat_recipe_msg': 'Recipe', 'chat_search': 'Search...', 'chat_nothing_found': 'Nothing found', 'chat_release_to_send': 'Release to send', 'chat_silent_send': 'Send silently', 'chat_silent_desc': 'Recipient will not get a sound notification', 'chat_seen_by': 'Viewed by', 'chat_nobody_seen': 'Nobody viewed yet', 'msg_saved_gallery': 'Saved to gallery!', 'msg_copied': 'Copied!', 'msg_pinned': 'Pinned!', 'msg_cleared': 'Cleared!', 'msg_error': 'Error', 'chat_reply': 'Reply', 'chat_edit': 'Edit', 'chat_delete': 'Delete', 'chat_personal': 'Personal', 'chat_hint': 'Type a message...', 'chat_no_messages': 'No messages yet', 'dialog_clear_title': 'Clear?', 'dialog_clear_content': 'Delete all messages?', 'chat_option_text': 'Option',
      'faq_q1': 'How to add a product?', 'faq_a1': 'Go to the "My Fridge" tab and tap the "+" button in the bottom right. Enter the name, category, and expiry date.', 'faq_q2': 'How to delete a product?', 'faq_a2': 'Tap the three dots on the product card and select "Delete", or move it to the Trash Bin.', 'faq_q3': 'How does AI work?', 'faq_a3': 'Check the boxes for the products you have and tap "Cook". AI will find the best recipes based on your ingredients.', 'faq_q4': 'How to change language?', 'faq_a4': 'Go to the "Profile" tab, scroll down to settings, and tap "Language". Select your preferred language.', 'faq_q5': 'How to restore a product?', 'faq_a5': 'Open "Trash Bin" (top right icon in Fridge). Find the item, tap the menu, and select "Restore".', 'faq_q6': 'What does Premium give?', 'faq_a6': 'Premium unlocks family mode, removes ads, provides unlimited recipe searches, and access to the smarter GPT-4 model.', 'faq_q7': 'How to contact support?', 'faq_a7': 'If you have questions, email us at: pasalugovij@gmail.com. We are happy to help!',
      'share_recipe': 'Share Recipe', 'share_external': 'Share to other apps', 'share_external_sub': 'Telegram, Viber, Instagram...', 'no_family_share': "Create a family in your profile to share recipes in the internal chat.", 'chat_recipe_msg': 'Recipe', 'err_share_failed': 'Share failed. Check connection.',
      'scan_title': '📸 Scan Fridge', 'scan_camera': 'Camera', 'scan_gallery': 'Gallery', 'scan_analyzing': 'AI is analyzing...\nThis will take a few seconds 🪄', 'scan_not_found': 'No products found 🤔', 'scan_found': 'Products found', 'scan_remove_extra': 'Remove extra items before saving', 'scan_no_items': 'No items to add', 'scan_save_all': 'Save to Fridge', 'scan_success': '✅ Items added successfully!', 'scan_error': 'Save error:',

      // 🔥 АВТОРИЗАЦІЯ ТА ПЕРЕВІРКА ПОШТИ
      'verify_email_title': 'Verify Email 📩',
      'verify_email_desc': 'We sent a verification link to',
      'btn_logout': 'Log Out',
      'btn_i_verified': 'I have verified',
      'btn_resend_email': 'Resend Email',
      'msg_email_verified': 'Email successfully verified! ✅',
      'msg_email_resent': 'Email resent 📧',

      // 🔥 КОШИК (СМІТНИК)
      'dialog_clear_trash_desc': 'Are you sure you want to permanently delete all items from the trash bin? This cannot be undone.',
      'msg_trash_cleared': 'Trash bin cleared! 🧹',
      'tooltip_clear_all': 'Clear all',
      'err_eat_too_much': 'Cannot eat more than you have!',

      // 🔥 СКАНЕР ШТРИХКОДІВ
      'scan_barcode_tooltip': 'Scan barcode',
      'barcode_searching': 'Searching product database...',
      'barcode_not_found': 'Product not found 😔. Please enter manually.',
      'barcode_error': 'Scan error',
      'barcode_success': 'Product found! ✅',

      // 🔥 НОВИЙ ЕКРАН ПІДПИСКИ (PAYWALL)
      'prem_choose_plan': 'Choose your plan',
      'prem_your_sub': 'Your Subscription',
      'prem_subtitle': 'Cook smarter, save more, share with family.',
      'prem_per_month': '/ mo.',
      'prem_pro_ben_3': 'For one user',
      'prem_btn_included': 'Included in Family',
      'prem_btn_choose_pro': 'Choose PRO',
      'prem_fam_ben_1': 'All Premium PRO features',
      'prem_fam_ben_2': 'Access for 5 family members',
      'prem_fam_ben_3': 'Shared chat & shopping lists',
      'prem_fam_ben_4': 'Fridge synchronization',
      'prem_btn_upgrade_fam': 'Upgrade to Family',
      'prem_btn_choose_fam': 'Choose FAMILY',
      'prem_badge_best': 'BEST VALUE',
    },

    // 🇪🇸 ESPAÑOL
    'Español': {
      'err_login_bad': 'Correo o contraseña incorrectos', 'err_email_bad': 'Formato de correo inválido', 'err_pass_weak': 'La contraseña es demasiado débil', 'err_user_exists': 'El correo ya está en uso', 'err_too_many_requests': 'Demasiados intentos. Intenta más tarde',
      'cat_dairy': 'Lácteos', 'cat_bakery': 'Pan', 'cat_sweet': 'Dulces', 'cat_drink': 'Bebidas',
      'share_recipe': 'Compartir receta', 'share_external': 'Compartir en otras aplicaciones', 'share_external_sub': 'Telegram, Viber, Instagram...', 'no_family_share': "Crea una familia en tu perfil para compartir recetas en el chat interno.", 'chat_recipe_msg': 'Receta', 'msg_sent': 'Enviado ✅', 'err_share_failed': 'Error al compartir. Revisa tu conexión.',
      'scan_title': '📸 Escanear Nevera', 'scan_camera': 'Cámara', 'scan_gallery': 'Galería', 'scan_analyzing': 'La IA está analizando...\nEsto tomará unos segundos 🪄', 'scan_not_found': 'No se encontraron productos 🤔', 'scan_found': 'Productos encontrados', 'scan_remove_extra': 'Elimina elementos extra antes de guardar', 'scan_no_items': 'No hay elementos para agregar', 'scan_save_all': 'Guardar en Nevera', 'scan_success': '✅ ¡Artículos agregados!', 'scan_error': 'Error al guardar:',

      // 🔥 АВТОРИЗАЦІЯ ТА ПЕРЕВІРКА ПОШТИ
      'verify_email_title': 'Verificar correo 📩',
      'verify_email_desc': 'Enviamos un enlace a',
      'btn_logout': 'Cerrar sesión',
      'btn_i_verified': 'Ya lo verifiqué',
      'btn_resend_email': 'Reenviar correo',
      'msg_email_verified': '¡Correo verificado! ✅',
      'msg_email_resent': 'Correo reenviado 📧',

      // 🔥 КОШИК (СМІТНИК)
      'dialog_clear_trash_desc': '¿Estás seguro de que quieres eliminar permanentemente todos los artículos de la papelera? Esta acción no se puede deshacer.',
      'msg_trash_cleared': '¡Papelera vaciada! 🧹',
      'tooltip_clear_all': 'Borrar todo',
      'err_eat_too_much': '¡No puedes comer más de lo que tienes!',

      // 🔥 СКАНЕР ШТРИХКОДІВ
      'scan_barcode_tooltip': 'Escanear código de barras',
      'barcode_searching': 'Buscando en la base de datos...',
      'barcode_not_found': 'Producto no encontrado 😔. Ingrese manualmente.',
      'barcode_error': 'Error de escaneo',
      'barcode_success': '¡Producto encontrado! ✅',

      // 🔥 НОВИЙ ЕКРАН ПІДПИСКИ (PAYWALL)
      'prem_choose_plan': 'Elige tu plan',
      'prem_your_sub': 'Tu Suscripción',
      'prem_subtitle': 'Cocina más inteligente, ahorra más, comparte en familia.',
      'prem_per_month': '/ mes',
      'prem_pro_ben_3': 'Para un usuario',
      'prem_btn_included': 'Incluido en Family',
      'prem_btn_choose_pro': 'Elegir PRO',
      'prem_fam_ben_1': 'Todas las funciones de Premium PRO',
      'prem_fam_ben_2': 'Acceso para 5 miembros de la familia',
      'prem_fam_ben_3': 'Chat y listas de compras compartidas',
      'prem_fam_ben_4': 'Sincronización de nevera',
      'prem_btn_upgrade_fam': 'Mejorar a Family',
      'prem_btn_choose_fam': 'Elegir FAMILY',
      'prem_badge_best': 'MEJOR VALOR',
    },

    // 🇫🇷 FRANÇAIS
    'Français': {
      'err_login_bad': 'Email ou mot de passe incorrect', 'err_email_bad': 'Format d\'email invalide', 'err_pass_weak': 'Le mot de passe est trop faible',
      'cat_bakery': 'Pain', 'cat_sweet': 'Douceur', 'cat_drink': 'Boisson',
      'share_recipe': 'Partager la recette', 'share_external': 'Partager vers d\'autres applications', 'share_external_sub': 'Telegram, Viber, Instagram...', 'no_family_share': "Créez une famille dans votre profil pour partager des recettes.", 'chat_recipe_msg': 'Receta', 'msg_sent': 'Envoyé ✅', 'err_share_failed': 'Échec du partage. Vérifiez votre connexion.',
      'scan_title': '📸 Scanner le Frigo', 'scan_camera': 'Caméra', 'scan_gallery': 'Galerie', 'scan_analyzing': 'L\'IA analyse...\nCela prendra quelques secondes 🪄', 'scan_not_found': 'Aucun produit trouvé 🤔', 'scan_found': 'Produits trouvés', 'scan_remove_extra': 'Retirez les éléments en trop avant d\'enregistrer', 'scan_no_items': 'Aucun élément à ajouter', 'scan_save_all': 'Enregistrer dans le Frigo', 'scan_success': '✅ Articles ajoutés avec succès!', 'scan_error': 'Erreur de sauvegarde:',

      // 🔥 АВТОРИЗАЦІЯ ТА ПЕРЕВІРКА ПОШТИ
      'verify_email_title': 'Vérifier l\'email 📩',
      'verify_email_desc': 'Nous avons envoyé un lien à',
      'btn_logout': 'Déconnexion',
      'btn_i_verified': 'J\'ai vérifié',
      'btn_resend_email': 'Renvoyer l\'email',
      'msg_email_verified': 'Email vérifié avec succès ! ✅',
      'msg_email_resent': 'Email renvoyé 📧',

      // 🔥 КОШИК (СМІТНИК)
      'dialog_clear_trash_desc': 'Êtes-vous sûr de vouloir supprimer définitivement tous les articles de la corbeille ? Cette action est irréversible.',
      'msg_trash_cleared': 'Corbeille vidée ! 🧹',
      'tooltip_clear_all': 'Tout effacer',
      'err_eat_too_much': 'Impossible de manger plus que ce que vous avez !',

      // 🔥 СКАНЕР ШТРИХКОДІВ
      'scan_barcode_tooltip': 'Scanner le code-barres',
      'barcode_searching': 'Recherche dans la base de données...',
      'barcode_not_found': 'Produit introuvable 😔. Veuillez entrer manuellement.',
      'barcode_error': 'Erreur de numérisation',
      'barcode_success': 'Produit trouvé ! ✅',

      // 🔥 НОВИЙ ЕКРАН ПІДПИСКИ (PAYWALL)
      'prem_choose_plan': 'Choisissez votre plan',
      'prem_your_sub': 'Votre Abonnement',
      'prem_subtitle': 'Cuisinez plus intelligemment, économisez plus, partagez.',
      'prem_per_month': '/ mois',
      'prem_pro_ben_3': 'Pour un utilisateur',
      'prem_btn_included': 'Inclus dans Family',
      'prem_btn_choose_pro': 'Choisir PRO',
      'prem_fam_ben_1': 'Toutes les fonctions Premium PRO',
      'prem_fam_ben_2': 'Accès pour 5 membres de la famille',
      'prem_fam_ben_3': 'Chat et listes de courses partagés',
      'prem_fam_ben_4': 'Synchronisation du frigo',
      'prem_btn_upgrade_fam': 'Passer à Family',
      'prem_btn_choose_fam': 'Choisir FAMILY',
      'prem_badge_best': 'MEILLEUR CHOIX',
    },

    // 🇩🇪 DEUTSCH
    'Deutsch': {
      'err_login_bad': 'Falsche E-Mail oder falsches Passwort', 'err_email_bad': 'Ungültiges E-Mail-Format',
      'cat_bakery': 'Bäckerei', 'cat_sweet': 'Süßes', 'cat_drink': 'Getränke',
      'share_recipe': 'Rezept teilen', 'share_external': 'Mit anderen Apps teilen', 'share_external_sub': 'Telegram, Viber, Instagram...', 'no_family_share': "Erstellen Sie eine Familie in Ihrem Profil, um Rezepte zu teilen.", 'chat_recipe_msg': 'Rezept', 'msg_sent': 'Gesendet ✅', 'err_share_failed': 'Teilen fehlgeschlagen. Verbindung prüfen.',
      'scan_title': '📸 Kühlschrank Scannen', 'scan_camera': 'Kamera', 'scan_gallery': 'Galerie', 'scan_analyzing': 'KI analysiert...\nDas dauert ein paar Sekunden 🪄', 'scan_not_found': 'Keine Produkte gefunden 🤔', 'scan_found': 'Produkte gefunden', 'scan_remove_extra': 'Entfernen Sie zusätzliche Artikel vor dem Speichern', 'scan_no_items': 'Keine Artikel hinzuzufügen', 'scan_save_all': 'Im Kühlschrank Speichern', 'scan_success': '✅ Artikel erfolgreich hinzugefügt!', 'scan_error': 'Speicherfehler:',

      // 🔥 АВТОРИЗАЦІЯ ТА ПЕРЕВІРКА ПОШТИ
      'verify_email_title': 'E-Mail bestätigen 📩',
      'verify_email_desc': 'Wir haben einen Link gesendet an',
      'btn_logout': 'Abmelden',
      'btn_i_verified': 'Ich habe bestätigt',
      'btn_resend_email': 'E-Mail erneut senden',
      'msg_email_verified': 'E-Mail erfolgreich bestätigt! ✅',
      'msg_email_resent': 'E-Mail erneut gesendet 📧',

      // 🔥 КОШИК (СМІТНИК)
      'dialog_clear_trash_desc': 'Möchten Sie wirklich alle Elemente im Papierkorb endgültig löschen? Dies kann nicht rückgängig gemacht werden.',
      'msg_trash_cleared': 'Papierkorb geleert! 🧹',
      'tooltip_clear_all': 'Alles löschen',
      'err_eat_too_much': 'Du kannst nicht mehr essen, als du hast!',

      // 🔥 СКАНЕР ШТРИХКОДІВ
      'scan_barcode_tooltip': 'Barcode scannen',
      'barcode_searching': 'Produktdatenbank durchsuchen...',
      'barcode_not_found': 'Produkt nicht gefunden 😔. Bitte manuell eingeben.',
      'barcode_error': 'Scanfehler',
      'barcode_success': 'Produkt gefunden! ✅',

      // 🔥 НОВИЙ ЕКРАН ПІДПИСКИ (PAYWALL)
      'prem_choose_plan': 'Wählen Sie Ihren Plan',
      'prem_your_sub': 'Ihr Abonnement',
      'prem_subtitle': 'Clever kochen, mehr sparen, mit der Familie teilen.',
      'prem_per_month': '/ Monat',
      'prem_pro_ben_3': 'Für einen Benutzer',
      'prem_btn_included': 'In Family enthalten',
      'prem_btn_choose_pro': 'PRO wählen',
      'prem_fam_ben_1': 'Alle Premium PRO Funktionen',
      'prem_fam_ben_2': 'Zugang für 5 Familienmitglieder',
      'prem_fam_ben_3': 'Gemeinsamer Chat & Einkaufslisten',
      'prem_fam_ben_4': 'Kühlschrank-Synchronisation',
      'prem_btn_upgrade_fam': 'Auf Family upgraden',
      'prem_btn_choose_fam': 'FAMILY wählen',
      'prem_badge_best': 'BESTER WERT',
    },
  };
}