class Recipe {
  final String title;
  final String description;
  final String imageUrl;
  final String time;
  final String kcal;
  final List<String> ingredients;        // Ті, що є в холодильнику
  final List<String> missingIngredients; // ✅ Ті, що треба докупити
  final List<String> steps;

  Recipe({
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.time,
    required this.kcal,
    required this.ingredients,
    required this.missingIngredients, // ✅ Додано в конструктор
    required this.steps,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      title: json['title'] ?? 'Без назви',
      description: json['description'] ?? '',
      // URL тепер приходить готовим з AI сервісу, тому тут просто беремо рядок
      imageUrl: json['imageUrl'] ?? 'https://via.placeholder.com/300?text=No+Image',
      time: json['time'] ?? '30 хв',
      kcal: json['kcal'] ?? '-',
      ingredients: List<String>.from(json['ingredients'] ?? []),
      // ✅ Читаємо список відсутніх продуктів з JSON
      missingIngredients: List<String>.from(json['missingIngredients'] ?? []),
      steps: List<String>.from(json['steps'] ?? []),
    );
  }
}