class Recipe {
  final String title;
  final String description;
  final String imageUrl;
  final String time;        // Напр: "30 хв"
  final String kcal;        // Напр: "450"
  final bool isVegetarian;
  final List<String> ingredients;
  final List<String> missingIngredients; // Що треба докупити
  final List<String> steps;              // Інструкція

  Recipe({
    required this.title,
    required this.description,
    required this.imageUrl,
    this.time = '---',
    this.kcal = '---',
    this.isVegetarian = false,
    this.ingredients = const [],
    this.missingIngredients = const [],
    this.steps = const [],
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      title: json['title'] ?? 'Без назви',
      description: json['description'] ?? '',
      imageUrl: json['imageUrl'] ?? 'https://via.placeholder.com/300',
      time: json['time'] ?? json['cookingTime'] ?? '???',
      kcal: json['kcal']?.toString() ?? json['calories']?.toString() ?? '???',
      isVegetarian: json['isVegetarian'] ?? false,
      // Читаємо списки безпечно
      ingredients: List<String>.from(json['ingredients'] ?? []),
      missingIngredients: List<String>.from(json['missingIngredients'] ?? []),
      steps: List<String>.from(json['steps'] ?? json['instructions'] ?? []),
    );
  }
}