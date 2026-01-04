class Recipe {
  final String title;
  final String description;
  final String time;
  final String kcal;
  final List<String> ingredients;
  final List<String> steps;
  final String imageUrl;

  Recipe({
    required this.title,
    required this.description,
    required this.time,
    required this.kcal,
    required this.ingredients,
    required this.steps,
    required this.imageUrl,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    // 👇 Беремо повний опис для фото (наприклад "Cream soup with pomelo and coconut")
    String query = json['img_key'] ?? json['title_en'] ?? 'delicious food';

    // Чистимо, але залишаємо пробіли
    query = query.replaceAll(RegExp(r'[^a-zA-Z\s]'), '');
    if (query.isEmpty) query = "meal";

    // Кодуємо для URL
    String encodedQuery = Uri.encodeComponent(query);
    int seed = query.hashCode;

    return Recipe(
      title: json['title'] ?? 'Страва',
      description: json['desc'] ?? '',
      time: json['time'] ?? '30 хв',
      kcal: json['kcal'] ?? '-',
      ingredients: List<String>.from(json['ing'] ?? []),
      steps: List<String>.from(json['steps'] ?? []),
      // 👇 Посилання тепер генерує точнішу картинку
      imageUrl: "https://image.pollinations.ai/prompt/delicious $encodedQuery food photography?width=512&height=512&model=flux&seed=$seed",
    );
  }
}