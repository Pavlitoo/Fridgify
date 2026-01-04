import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';

import '../recipe_model.dart';
import '../ai_service.dart';
import '../product_model.dart';
import '../translations.dart';
import '../notification_service.dart';
import '../subscription_service.dart';
import '../premium_screen.dart';
import '../ad_service.dart';
import '../global.dart';

class CategoryData {
  final String id;
  final IconData icon;
  final Color color;
  final String labelKey;
  CategoryData(this.id, this.icon, this.color, this.labelKey);
}

final List<CategoryData> appCategories = [
  CategoryData('other', Icons.fastfood, Colors.grey, 'cat_other'),
  CategoryData('meat', Icons.set_meal, Colors.red, 'cat_meat'),
  CategoryData('veg', Icons.eco, Colors.green, 'cat_veg'),
  CategoryData('fruit', Icons.apple, Colors.orange, 'cat_fruit'),
  CategoryData('dairy', Icons.egg, Colors.blueGrey, 'cat_dairy'),
  CategoryData('bakery', Icons.breakfast_dining, Colors.brown, 'cat_bakery'),
  CategoryData('sweet', Icons.cake, Colors.pink, 'cat_sweet'),
  CategoryData('drink', Icons.local_drink, Colors.blue, 'cat_drink'),
];

Locale getAppLocale(String langName) {
  switch (langName) {
    case 'Українська': return const Locale('uk', 'UA');
    case 'Español': return const Locale('es', 'ES');
    case 'Français': return const Locale('fr', 'FR');
    case 'Deutsch': return const Locale('de', 'DE');
    default: return const Locale('en', 'US');
  }
}

class FridgeContent extends StatefulWidget { const FridgeContent({super.key}); @override State<FridgeContent> createState() => _FridgeContentState(); }

class _FridgeContentState extends State<FridgeContent> {
  final user = FirebaseAuth.instance.currentUser!;
  final Set<String> _selectedProductIds = {};
  final List<String> _selectedProductNames = [];
  String _selectedCategoryFilter = 'all';

  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    if (SubscriptionService().isPremium) return;

    final ad = AdService().createBannerAd(
        onLoaded: () {
          if(mounted) setState(() => _isAdLoaded = true);
        }
    );

    if (ad != null) {
      setState(() => _bannerAd = ad);
      _bannerAd!.load();
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  CollectionReference _getProductsCollection(String? householdId) { return (householdId != null) ? FirebaseFirestore.instance.collection('households').doc(householdId).collection('products') : FirebaseFirestore.instance.collection('users').doc(user.uid).collection('products'); }
  CollectionReference _getListCollection(String? householdId) { return (householdId != null) ? FirebaseFirestore.instance.collection('households').doc(householdId).collection('shopping_list') : FirebaseFirestore.instance.collection('users').doc(user.uid).collection('shopping_list'); }

  void _toggleSelection(String id, String name) { setState(() { if (_selectedProductIds.contains(id)) { _selectedProductIds.remove(id); _selectedProductNames.remove(name); } else { _selectedProductIds.add(id); _selectedProductNames.add(name); } }); }
  Future<void> _logHistory(String action, String productName) async { await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('history').add({'action': action, 'product': productName, 'date': Timestamp.now()}); }
  void _deleteProduct(Product product, CollectionReference collection) { NotificationService().cancelNotification(product.id.hashCode); collection.doc(product.id).delete(); }

  void _showConsumeDialog(Product product, CollectionReference collection) {
    final TextEditingController consumeController = TextEditingController();
    bool isPcs = product.unit == 'pcs';
    final dialogBg = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final inputFill = Theme.of(context).scaffoldBackgroundColor;

    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: dialogBg,
      title: Text("Скільки з'їли?", textAlign: TextAlign.center, style: TextStyle(color: textColor)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text("Всього: ${product.quantity} ${AppText.get('u_${product.unit}')}", style: TextStyle(fontSize: 14, color: textColor?.withOpacity(0.7))),
        const SizedBox(height: 10),
        TextField(
          controller: consumeController,
          keyboardType: TextInputType.numberWithOptions(decimal: !isPcs),
          inputFormatters: isPcs ? [FilteringTextInputFormatter.digitsOnly] : [],
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
              hintText: isPcs ? "Кількість (ціле число)" : "Кількість (можна з комою)",
              hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              filled: true,
              fillColor: inputFill,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
          ),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppText.get('cancel'), style: TextStyle(color: textColor))),
        ElevatedButton(onPressed: () {
          double consumed;
          if (isPcs) {
            consumed = int.tryParse(consumeController.text)?.toDouble() ?? 0;
          } else {
            consumed = double.tryParse(consumeController.text.replaceAll(',', '.')) ?? 0;
          }
          if (consumed <= 0) return;
          if (consumed >= product.quantity) { _logHistory('eaten', product.name); _deleteProduct(product, collection); }
          else { double newQty = product.quantity - consumed; newQty = (newQty * 100).round() / 100; collection.doc(product.id).update({'quantity': newQty}); _logHistory('eaten', "${product.name} ($consumed ${product.unit})"); }
          Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Смачного!"), backgroundColor: Colors.green));
        }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), child: const Text("Зберегти")),
      ],
    ));
  }

  void _confirmSimpleDelete(Product product, CollectionReference collection) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      title: Text("Видалити?", textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
      content: Text("Продукт буде видалено назавжди.", textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Ні")), ElevatedButton(onPressed: () { _logHistory('wasted', product.name); _deleteProduct(product, collection); Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Видалено"), backgroundColor: Colors.red)); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: Text("Так"))],
    ));
  }

  Future<void> _checkLimitAndSearch() async {
    final subService = SubscriptionService();
    if (subService.isPremium) {
      _searchRecipes();
      return;
    }

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final limitDoc = await userDocRef.collection('usage').doc('daily_limit').get();

    int count = 0;
    if (limitDoc.exists) {
      final data = limitDoc.data()!;
      if (data['date'] == todayStr) {
        count = data['count'] ?? 0;
      }
    }

    if (count >= 3) {
      showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Ліміт вичерпано 🔒"),
            content: const Text("Ви використали 3 безкоштовні пошуки на сьогодні. Перейдіть на Premium для безліміту!"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("ОК")),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                  onPressed: () async {
                    Navigator.pop(context);
                    bool bought = await Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen())) ?? false;
                    if (bought) {
                      _searchRecipes();
                    }
                  },
                  child: const Text("Купити Premium")
              )
            ],
          )
      );
    } else {
      await userDocRef.collection('usage').doc('daily_limit').set({
        'date': todayStr,
        'count': count + 1
      });
      _searchRecipes();
    }
  }

  Future<void> _searchRecipes() async {
    if (_selectedProductNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Оберіть продукти!"), backgroundColor: Colors.orange));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20)),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.green),
              SizedBox(height: 20),
              Text("Шеф-кухар думає... 👨‍🍳", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text("Генеруємо 5 рецептів...", style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );

    try {
      final recipes = await AiRecipeService().getRecipes(
        ingredients: _selectedProductNames,
        userLanguage: languageNotifier.value,
      );

      if (!mounted) return;

      await Future.wait(recipes.map((recipe) => precacheImage(NetworkImage(recipe.imageUrl), context).catchError((_) {})));

      if (!mounted) return;

      Navigator.pop(context);
      _showResults(recipes);

    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Помилка: $e"), backgroundColor: Colors.red));
      }
    }
  }

  void _showResults(List<Recipe> recipes) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final cardColor = Theme.of(context).cardColor;
          final textColor = Theme.of(context).textTheme.bodyLarge?.color;

          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              children: [
                Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 15),
                Text(AppText.get('recipe_title'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 10),

                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.all(16),
                    itemCount: recipes.length,
                    itemBuilder: (ctx, i) {
                      final recipe = recipes[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 220,
                              width: double.infinity,
                              child: Image.network(
                                recipe.imageUrl,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    height: 220,
                                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                            : null,
                                        color: Colors.green,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) => Container(
                                    height: 220,
                                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.fastfood, size: 50, color: Colors.green), const SizedBox(height: 8), const Text("Смачного!", style: TextStyle(color: Colors.grey))])
                                ),
                              ),
                            ),

                            Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: Text(recipe.title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor, height: 1.2))),
                                      const SizedBox(width: 10),
                                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Column(children: [const Icon(Icons.local_fire_department, size: 20, color: Colors.orange), Text(recipe.kcal, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12))])),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(children: [const Icon(Icons.access_time, size: 18, color: Colors.green), const SizedBox(width: 6), Text(recipe.time, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))]),
                                  const SizedBox(height: 12),
                                  Text(recipe.description, style: TextStyle(color: textColor?.withOpacity(0.7), fontSize: 15)),
                                  const Divider(height: 30),
                                  const Text("🛒 Інгредієнти:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 10),
                                  Wrap(spacing: 8, runSpacing: 8, children: recipe.ingredients.map((ing) => Chip(label: Text(ing), backgroundColor: isDark ? Colors.grey.shade800 : Colors.green.shade50, labelStyle: TextStyle(color: isDark ? Colors.white : Colors.green.shade800), side: BorderSide.none, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)))).toList()),
                                  const SizedBox(height: 20),
                                  ExpansionTile(
                                    tilePadding: EdgeInsets.zero,
                                    shape: Border.all(color: Colors.transparent),
                                    title: const Text("🍳 Як готувати?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                    children: recipe.steps.asMap().entries.map((entry) => Padding(padding: const EdgeInsets.only(bottom: 16.0), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [CircleAvatar(radius: 12, backgroundColor: Colors.green, child: Text("${entry.key + 1}", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))), const SizedBox(width: 12), Expanded(child: Text(entry.value, style: TextStyle(fontSize: 16, color: textColor, height: 1.4)))],))).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showProductDialog({Product? productToEdit, required CollectionReference collection}) {
    final nameController = TextEditingController(text: productToEdit?.name ?? '');
    final qtyController = TextEditingController(text: productToEdit?.quantity.toString() ?? '1');
    String selectedUnit = productToEdit?.unit ?? 'pcs';
    DateTime selectedDate = productToEdit?.expirationDate ?? DateTime.now().add(const Duration(days: 7));
    final isEditing = productToEdit != null;
    String selectedCategory = productToEdit?.category ?? 'other';

    showDialog(context: context, builder: (context) { return StatefulBuilder(builder: (context, setDialogState) {
      String formattedDate = "${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}";
      final dialogBg = Theme.of(context).cardColor;
      final textColor = Theme.of(context).textTheme.bodyLarge?.color;
      final inputFill = Theme.of(context).scaffoldBackgroundColor;

      return AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), backgroundColor: dialogBg, contentPadding: const EdgeInsets.all(24),
          title: Text(isEditing ? AppText.get('edit_product') : AppText.get('add_product'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: textColor), textAlign: TextAlign.center),
          content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameController, style: TextStyle(fontSize: 18, color: textColor), decoration: InputDecoration(hintText: AppText.get('product_name'), hintStyle: TextStyle(color: Colors.grey), prefixIcon: const Icon(Icons.edit, color: Colors.green), filled: true, fillColor: inputFill, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)), autofocus: true),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: TextField(controller: qtyController, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: textColor), decoration: InputDecoration(hintText: AppText.get('quantity'), hintStyle: TextStyle(color: Colors.grey), filled: true, fillColor: inputFill, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)))),
              const SizedBox(width: 12),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: inputFill, borderRadius: BorderRadius.circular(16)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(dropdownColor: dialogBg, value: selectedUnit, style: TextStyle(color: textColor), onChanged: (val) => setDialogState(() => selectedUnit = val!), items: ['pcs', 'kg', 'g', 'l', 'ml'].map((unit) { return DropdownMenuItem(value: unit, child: Text(AppText.get('u_$unit'), style: TextStyle(color: textColor))); }).toList())))]),
            const SizedBox(height: 24),
            Text(AppText.get('category_label'), style: TextStyle(color: textColor?.withOpacity(0.7), fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 10, children: appCategories.map((cat) { final isSelected = selectedCategory == cat.id; return InkWell(onTap: () => setDialogState(() => selectedCategory = cat.id), child: Column(mainAxisSize: MainAxisSize.min, children: [AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isSelected ? cat.color : inputFill, shape: BoxShape.circle, boxShadow: isSelected ? [BoxShadow(color: cat.color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))] : []), child: Icon(cat.icon, color: isSelected ? Colors.white : Colors.grey, size: 28)), const SizedBox(height: 4), Text(AppText.get(cat.labelKey), style: TextStyle(fontSize: 10, color: isSelected ? cat.color : Colors.grey, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))])); }).toList()),
            const SizedBox(height: 30),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(AppText.get('days_valid'), style: TextStyle(fontSize: 16, color: textColor?.withOpacity(0.7))), InkWell(onTap: () async { final DateTime? picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365 * 10)), locale: getAppLocale(languageNotifier.value)); if (picked != null && picked != selectedDate) { setDialogState(() { selectedDate = picked; }); } }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: Colors.green.shade50.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green)), child: Row(children: [const Icon(Icons.calendar_today, size: 18, color: Colors.green), const SizedBox(width: 8), Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16))])))] )]))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(AppText.get('cancel'), style: TextStyle(fontSize: 16, color: textColor))), ElevatedButton(onPressed: () async { if (nameController.text.isNotEmpty) { final qty = double.tryParse(qtyController.text) ?? 1.0; final data = {'name': nameController.text.trim(), 'expirationDate': Timestamp.fromDate(selectedDate), 'category': selectedCategory, 'quantity': qty, 'unit': selectedUnit}; if (isEditing) { await collection.doc(productToEdit.id).update(data); NotificationService().cancelNotification(productToEdit.id.hashCode); NotificationService().scheduleNotification(productToEdit.id.hashCode, nameController.text.trim(), selectedDate); } else { final docRef = await collection.add({...data, 'addedDate': Timestamp.now()}); NotificationService().scheduleNotification(docRef.id.hashCode, nameController.text.trim(), selectedDate); } Navigator.pop(context); } }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(isEditing ? AppText.get('save') : AppText.get('add'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))] ); }); });
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final cardColor = Theme.of(context).cardColor;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return StreamBuilder<DocumentSnapshot>(stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(), builder: (context, userSnap) {
      final householdId = userSnap.data?.data() != null ? (userSnap.data!.data() as Map)['householdId'] : null;
      final collection = _getProductsCollection(householdId);
      return Scaffold(
        backgroundColor: bgColor, appBar: AppBar(title: Text(AppText.get('my_fridge')), backgroundColor: Theme.of(context).appBarTheme.backgroundColor, centerTitle: true),
        body: Column(children: [
          SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Row(children: [_filterChip('all', AppText.get('cat_all'), Icons.grid_view, textColor, cardColor), ...appCategories.map((cat) => _filterChip(cat.id, AppText.get(cat.labelKey), cat.icon, cat.color, cardColor))])),
          Expanded(child: StreamBuilder<QuerySnapshot>(stream: collection.orderBy('expirationDate').snapshots(), builder: (ctx, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());

            final allProducts = snap.data!.docs.map((doc) => Product.fromFirestore(doc)).toList();
            final docs = _selectedCategoryFilter == 'all'
                ? allProducts
                : allProducts.where((p) => p.category == _selectedCategoryFilter).toList();

            // 👇 ОНОВЛЕНИЙ ГАРНИЙ ДИЗАЙН ПУСТОГО СТАНУ
            if (docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(Icons.kitchen_outlined, size: 80, color: Colors.green.shade300),
                    ),
                    const SizedBox(height: 20),
                    Text(AppText.get('empty_fridge'), textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 10),
                    Text(AppText.get('empty_fridge_sub'), style: TextStyle(fontSize: 14, color: Colors.grey.shade400)), // ПРАВИЛЬНИЙ ТЕКСТ
                  ],
                ),
              );
            }

            return ListView.builder(itemCount: docs.length, itemBuilder: (ctx, i) {
              final product = docs[i]; final isSelected = _selectedProductIds.contains(product.id); Color statusColor = product.daysLeft < 3 ? Colors.red : (product.daysLeft < 7 ? Colors.orange : Colors.green); String timeLeftText = product.daysLeft < 30 ? "${product.daysLeft} ${AppText.get('u_days')}" : "${(product.daysLeft / 30).floor()} ${AppText.get('u_months')}"; final catData = appCategories.firstWhere((c) => c.id == product.category, orElse: () => appCategories[0]);
              return SlideInAnimation(delay: i * 50, child: Card(color: isSelected ? Colors.green.shade100 : cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: isSelected ? const BorderSide(color: Colors.green, width: 2) : BorderSide.none), elevation: 4, margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: InkWell(onTap: () => _toggleSelection(product.id, product.name), borderRadius: BorderRadius.circular(20), child: Padding(padding: const EdgeInsets.all(12.0), child: ListTile(contentPadding: EdgeInsets.zero, leading: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: catData.color.withOpacity(0.15), shape: BoxShape.circle), child: Icon(catData.icon, color: catData.color, size: 28)), title: Row(children: [Expanded(child: Text(product.name, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isSelected ? Colors.black : textColor))), const SizedBox(width: 8), Text("(${product.quantity} ${AppText.get('u_${product.unit}')})", style: const TextStyle(color: Colors.grey, fontSize: 14))]), subtitle: Row(children: [Icon(Icons.timer_outlined, size: 16, color: statusColor), const SizedBox(width: 4), Text("${AppText.get('days_left')} $timeLeftText", style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 14))]), trailing: PopupMenuButton<String>(icon: const Icon(Icons.more_vert, color: Colors.grey), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), color: cardColor, onSelected: (value) async { if (value == 'edit') { _showProductDialog(productToEdit: product, collection: collection); } else if (value == 'shop') { _logHistory('moved_to_list', product.name); await _getListCollection(householdId).add({'name': product.name, 'isBought': false, 'addedDate': Timestamp.now(), 'quantity': product.quantity, 'unit': product.unit}); _deleteProduct(product, collection); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${AppText.get('yes_list')}! 🛒"), backgroundColor: Colors.blue)); } else if (value == 'eaten') { _showConsumeDialog(product, collection); } else if (value == 'delete') { _confirmSimpleDelete(product, collection); } }, itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Colors.blue), SizedBox(width: 10), Text(AppText.get('edit_product'), style: TextStyle(color: textColor))])), PopupMenuItem(value: 'eaten', child: Row(children: [Icon(Icons.restaurant, color: Colors.green), SizedBox(width: 10), Text(AppText.get('action_eaten'), style: TextStyle(color: textColor))])), PopupMenuItem(value: 'shop', child: Row(children: [Icon(Icons.shopping_cart, color: Colors.orange), SizedBox(width: 10), Text(AppText.get('yes_list'), style: TextStyle(color: textColor))])), const PopupMenuDivider(), PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, color: Colors.red), SizedBox(width: 10), Text(AppText.get('no_delete'), style: TextStyle(color: textColor))]))]))))));
            });
          })),
          if (_bannerAd != null && _isAdLoaded) Container(alignment: Alignment.center, width: _bannerAd!.size.width.toDouble(), height: _bannerAd!.size.height.toDouble(), child: AdWidget(ad: _bannerAd!)),
        ]),
        // 👇 ОНОВЛЕНА КНОПКА (Маленька кругла +, коли нічого не вибрано)
        floatingActionButton: StreamBuilder<DocumentSnapshot>(stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(), builder: (context, snapshot) { final householdId = (snapshot.data?.data() as Map<String, dynamic>?)?['householdId']; final collection = _getProductsCollection(householdId);
        if (_selectedProductIds.isNotEmpty) {
          return FloatingActionButton.extended(onPressed: _checkLimitAndSearch, label: Text(AppText.get('cook_btn'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), icon: Icon(Icons.restaurant_menu, size: 28), backgroundColor: Colors.deepOrange, foregroundColor: Colors.white, elevation: 4);
        } else {
          return SizedBox(width: 65, height: 65, child: FloatingActionButton(onPressed: () => _showProductDialog(collection: collection, productToEdit: null), backgroundColor: Colors.green.shade600, foregroundColor: Colors.white, elevation: 4, shape: const CircleBorder(), child: const Icon(Icons.add, size: 36)));
        }
        }),
      );
    });
  }

  Widget _filterChip(String id, String label, IconData icon, Color textColor, Color bgColor) {
    final isSelected = _selectedCategoryFilter == id;
    return Padding(padding: const EdgeInsets.only(right: 10), child: InkWell(onTap: () => setState(() => _selectedCategoryFilter = id), borderRadius: BorderRadius.circular(20), child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: isSelected ? Colors.green : (bgColor), borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? Colors.green : Colors.grey.shade300), boxShadow: isSelected ? [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))] : []), child: Row(children: [Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.grey), const SizedBox(width: 8), Text(label, style: TextStyle(color: isSelected ? Colors.white : textColor, fontWeight: FontWeight.bold))]))));
  }
}

class SlideInAnimation extends StatefulWidget { final Widget child; final int delay; const SlideInAnimation({super.key, required this.child, required this.delay}); @override State<SlideInAnimation> createState() => _SlideInAnimationState(); }
class _SlideInAnimationState extends State<SlideInAnimation> with SingleTickerProviderStateMixin { late AnimationController _controller; late Animation<Offset> _offsetAnim; @override void initState() { super.initState(); _controller = AnimationController(duration: const Duration(milliseconds: 500), vsync: this); _offsetAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut)); Future.delayed(Duration(milliseconds: widget.delay), () { if(mounted) _controller.forward(); }); } @override void dispose() { _controller.dispose(); super.dispose(); } @override Widget build(BuildContext context) { return FadeTransition(opacity: _controller, child: SlideTransition(position: _offsetAnim, child: widget.child)); } }