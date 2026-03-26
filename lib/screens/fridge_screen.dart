import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../recipe_model.dart';
import '../ai_service.dart';
import '../product_model.dart';
import '../translations.dart';
import '../notification_service.dart';
import '../subscription_service.dart';
import '../ad_service.dart';
import '../global.dart';
import '../error_handler.dart';
import '../utils/snackbar_utils.dart';
import 'recipe_detail_screen.dart';

import 'fridge_dialogs.dart';
import '../widgets/product_list_item.dart';
import 'receipt_scanner.dart';

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

class FridgeContent extends StatefulWidget {
  const FridgeContent({super.key});

  @override
  State<FridgeContent> createState() => _FridgeContentState();
}

class _FridgeContentState extends State<FridgeContent> with TickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser!;
  final Set<String> _selectedProductIds = {};
  String _selectedCategoryFilter = 'all';

  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;
  String _selectedDiet = 'standard';

  StreamSubscription<QuerySnapshot>? _productSubscription;

  // --- ДОПОМІЖНА ЛОГІКА ДЛЯ ЗЛИТТЯ ПРОДУКТІВ ---
  bool _isSameProduct(String name1, String name2) {
    String n1 = name1.toLowerCase().trim().replaceAll(RegExp(r'[^\w\sа-яА-ЯіІїЇєЄ]'), '');
    String n2 = name2.toLowerCase().trim().replaceAll(RegExp(r'[^\w\sа-яА-ЯіІїЇєЄ]'), '');
    if (n1.isEmpty || n2.isEmpty) return false;
    return n1 == n2 || n1.contains(n2) || n2.contains(n1);
  }
  String _getUnitType(String unit) {
    if (unit == 'g' || unit == 'kg') return 'weight';
    if (unit == 'ml' || unit == 'l') return 'volume';
    return 'count';
  }
  double _getBaseQty(double qty, String unit) {
    if (unit == 'kg' || unit == 'l') return qty * 1000;
    return qty;
  }
  Map<String, dynamic> _formatQtyAndUnit(double baseQty, String type) {
    if (type == 'weight') {
      if (baseQty >= 1000) return {'qty': baseQty / 1000, 'unit': 'kg'};
      return {'qty': baseQty, 'unit': 'g'};
    }
    if (type == 'volume') {
      if (baseQty >= 1000) return {'qty': baseQty / 1000, 'unit': 'l'};
      return {'qty': baseQty, 'unit': 'ml'};
    }
    return {'qty': baseQty, 'unit': 'pcs'};
  }

  @override
  void initState() {
    super.initState();
    _initAds();
    _setupNotifications();
  }

  void _setupNotifications() {
    FirebaseFirestore.instance.collection('users').doc(user.uid).get().then((doc) {
      if (!mounted) return;
      String? householdId = (doc.exists && doc.data() != null) ? (doc.data() as Map)['householdId'] : null;
      final collectionRef = _getProductsCollection(householdId);

      _productSubscription = collectionRef.snapshots().listen((snapshot) {
        _scheduleAllNotifications(snapshot.docs);
      });
    });
  }

  void _scheduleAllNotifications(List<QueryDocumentSnapshot> docs) async {
    await NotificationService.cancelAll();
    List<String> urgentItems = [];
    final now = DateTime.now();

    for (var doc in docs) {
      final product = Product.fromFirestore(doc);
      if (product.category == 'trash') continue;

      if (product.expirationDate.difference(now).inDays <= 0) {
        urgentItems.add(product.name);
      }
    }

    if (urgentItems.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final String todayDate = "${now.year}-${now.month}-${now.day}";
      if (prefs.getString('last_expired_alert_date') != todayDate) {
        await NotificationService.showNotification(id: 99999, title: AppText.get('notif_instant_title'), body: "${AppText.get('notif_instant_body')}: ${urgentItems.join(', ')}", payload: 'fridge');
        await prefs.setString('last_expired_alert_date', todayDate);
      }
    } else {
      await NotificationService.cancelNotification(99999);
    }
  }

  void _initAds() {
    AdService().init();
    if (!SubscriptionService().hasProOrHigher) _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(adUnitId: AdService().bannerAdUnitId, size: AdSize.banner, request: const AdRequest(), listener: BannerAdListener(onAdLoaded: (_) { if (mounted) setState(() => _isBannerLoaded = true); }, onAdFailedToLoad: (ad, error) { ad.dispose(); }))
      ..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _productSubscription?.cancel();
    super.dispose();
  }

  CollectionReference _getProductsCollection(String? householdId) {
    return householdId != null ? FirebaseFirestore.instance.collection('households').doc(householdId).collection('products') : FirebaseFirestore.instance.collection('users').doc(user.uid).collection('products');
  }

  CollectionReference _getListCollection(String? householdId) {
    return householdId != null ? FirebaseFirestore.instance.collection('households').doc(householdId).collection('shopping_list') : FirebaseFirestore.instance.collection('users').doc(user.uid).collection('shopping_list');
  }

  Future<void> _recordHistory(String productName, String action) async {
    try { await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('history').add({'product': productName, 'action': action, 'date': Timestamp.now()}); } catch (_) {}
  }

  void _toggleSelection(String id) {
    setState(() { _selectedProductIds.contains(id) ? _selectedProductIds.remove(id) : _selectedProductIds.add(id); });
  }

  void _deleteProductForever(Product product, CollectionReference collection) {
    NotificationService.cancelForProduct(product.id);
    collection.doc(product.id).delete();
  }

  void _moveToTrash(Product product, CollectionReference collection) {
    collection.doc(product.id).update({'category': 'trash'});
    NotificationService.cancelForProduct(product.id);
  }

  // 🔥 ЗЛИТТЯ ПРИ ВІДНОВЛЕННІ ЗІ СМІТНИКА В СПИСОК ПОКУПОК
  Future<void> _moveFromTrashToShopList(Product product, CollectionReference fridgeCollection, CollectionReference listCollection) async {
    try {
      final existingDocs = await listCollection.get();
      QueryDocumentSnapshot? matchDoc;
      for (var doc in existingDocs.docs) {
        final d = doc.data() as Map<String, dynamic>;
        if (_isSameProduct(d['name'], product.name) && _getUnitType(d['unit']) == _getUnitType(product.unit)) {
          matchDoc = doc; break;
        }
      }

      if (matchDoc != null) {
        final matchData = matchDoc.data() as Map<String, dynamic>;
        final baseExt = _getBaseQty((matchData['quantity'] as num).toDouble(), matchData['unit']);
        final baseNew = _getBaseQty(product.quantity, product.unit);
        final formatted = _formatQtyAndUnit(baseExt + baseNew, _getUnitType(product.unit));

        await listCollection.doc(matchDoc.id).update({
          'quantity': formatted['qty'],
          'unit': formatted['unit']
        });
      } else {
        await listCollection.add({'name': product.name, 'quantity': product.quantity, 'unit': product.unit, 'isBought': false, 'addedDate': Timestamp.now()});
      }

      _deleteProductForever(product, fridgeCollection);
      if (mounted) { Navigator.pop(context); SnackbarUtils.showSuccess(context, "🛒 ${product.name} ${AppText.get('yes_list')}"); }
    } catch (e) { if (mounted) SnackbarUtils.showError(context, ErrorHandler.getMessage(e)); }
  }

  Future<void> _emptyTrashBin(List<Product> trashProducts, CollectionReference collection) async {
    if (trashProducts.isEmpty) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), backgroundColor: Theme.of(context).cardColor,
        title: Row(children: [const Icon(Icons.warning_amber_rounded, color: Colors.red), const SizedBox(width: 10), Text(AppText.get('trash_title'), style: const TextStyle(fontWeight: FontWeight.bold))]),
        content: Text(AppText.get('dialog_clear_trash_desc'), style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade700, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppText.get('cancel'), style: const TextStyle(color: Colors.grey))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: Text(AppText.get('btn_delete_forever'), style: const TextStyle(fontWeight: FontWeight.bold)))
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (var p in trashProducts) { batch.delete(collection.doc(p.id)); NotificationService.cancelForProduct(p.id); }
      await batch.commit();
      if (mounted) { Navigator.pop(context); SnackbarUtils.showSuccess(context, AppText.get('msg_trash_cleared')); }
    } catch (e) { if (mounted) SnackbarUtils.showError(context, ErrorHandler.getMessage(e)); }
  }

  void _confirmDeleteFromTrash(Product product, CollectionReference collection) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), backgroundColor: Theme.of(context).cardColor,
        title: Text(AppText.get('btn_delete_forever'), style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(AppText.get('no_delete')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppText.get('cancel'), style: const TextStyle(color: Colors.grey))),
          ElevatedButton(onPressed: () { _deleteProductForever(product, collection); Navigator.pop(ctx); SnackbarUtils.showWarning(context, AppText.get('msg_deleted_forever')); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: Text(AppText.get('btn_ok'), style: const TextStyle(fontWeight: FontWeight.bold)))
        ],
      ),
    );
  }

  void _handleRestore(Product product, CollectionReference collection) {
    if (product.daysLeft <= 0) {
      SnackbarUtils.showWarning(context, AppText.get('msg_change_date'));
      FridgeDialogs.showProductDialog(context: context, productToEdit: product, collection: collection, categories: appCategories, cancelNotification: (id) => NotificationService.cancelNotification(id));
    } else {
      collection.doc(product.id).update({'category': 'other'});
      Navigator.pop(context);
      SnackbarUtils.showSuccess(context, AppText.get('msg_restored'));
    }
  }

  void _openTrashBin(CollectionReference collection, CollectionReference shopCollection) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6, maxChildSize: 0.9,
        builder: (_, controller) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final textColor = Theme.of(context).textTheme.bodyLarge?.color;
          final subTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

          return Container(
            decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            padding: const EdgeInsets.only(top: 20, left: 16, right: 16),
            child: StreamBuilder<QuerySnapshot>(
              stream: collection.orderBy('expirationDate').snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final allDocs = snap.data!.docs.map((doc) => Product.fromFirestore(doc)).toList();
                final trashProducts = allDocs.where((p) => p.category == 'trash' || p.daysLeft <= 0).toList();

                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 48),
                        Row(children: [const Icon(Icons.delete_sweep, color: Colors.red, size: 28), const SizedBox(width: 10), Text(AppText.get('trash_title'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor))]),
                        trashProducts.isNotEmpty ? IconButton(icon: const Icon(Icons.cleaning_services_rounded, color: Colors.red), tooltip: AppText.get('tooltip_clear_all'), onPressed: () => _emptyTrashBin(trashProducts, collection)) : const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 5), Text(AppText.get('trash_sub'), style: TextStyle(color: subTextColor)), const SizedBox(height: 20),
                    Expanded(
                      child: trashProducts.isEmpty
                          ? Center(child: Text(AppText.get('trash_empty'), style: TextStyle(color: subTextColor, fontSize: 16)))
                          : ListView.builder(
                        controller: controller, itemCount: trashProducts.length,
                        itemBuilder: (ctx, i) {
                          final product = trashProducts[i];
                          bool isManualDelete = product.category == 'trash';
                          Color bg = isManualDelete ? (isDark ? Colors.grey.shade800 : Colors.grey.shade200) : (isDark ? Colors.red.withValues(alpha: 0.15) : Colors.red.shade50.withValues(alpha: 0.5));
                          Color iconColor = isManualDelete ? (isDark ? Colors.grey.shade400 : Colors.grey) : Colors.red;
                          return Card(
                            color: bg, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: iconColor.withValues(alpha: 0.3))), margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: Icon(isManualDelete ? Icons.delete_outline : Icons.warning_amber_rounded, color: iconColor),
                              title: Text(product.name, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, decoration: TextDecoration.lineThrough)),
                              subtitle: Text(isManualDelete ? AppText.get('status_deleted') : "${AppText.get('status_rotten')} ${product.daysLeft.abs()} ${AppText.get('u_days')} ${AppText.get('ago_suffix')}", style: TextStyle(color: iconColor)),
                              trailing: PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: Colors.grey),
                                onSelected: (val) { if (val == 'shop') _moveFromTrashToShopList(product, collection, shopCollection); if (val == 'delete') _confirmDeleteFromTrash(product, collection); if (val == 'restore') _handleRestore(product, collection); },
                                itemBuilder: (ctx) => [
                                  PopupMenuItem(value: 'shop', child: Row(children: [const Icon(Icons.refresh, color: Colors.orange), const SizedBox(width: 8), Text(AppText.get('btn_buy'), style: TextStyle(color: textColor))])),
                                  PopupMenuItem(value: 'restore', child: Row(children: [const Icon(Icons.restore, color: Colors.blue), const SizedBox(width: 8), Text(AppText.get('btn_restore'), style: TextStyle(color: textColor))])),
                                  PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.delete_forever, color: Colors.red), const SizedBox(width: 8), Text(AppText.get('btn_delete_forever'), style: TextStyle(color: textColor))])),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _confirmSoftDelete(Product product, CollectionReference collection) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(AppText.get('trash_title')),
        content: Text("${AppText.get('no_delete')}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppText.get('cancel'))),
          ElevatedButton(
            onPressed: () { _moveToTrash(product, collection); _recordHistory(product.name, 'wasted'); Navigator.pop(ctx); SnackbarUtils.showWarning(context, "${AppText.get('status_deleted')} 🗑"); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: Text(AppText.get('btn_ok')),
          )
        ],
      ),
    );
  }

  Future<void> _checkLimitAndSearch(List<Product> allProducts) async {
    if (_selectedProductIds.isEmpty) { SnackbarUtils.showWarning(context, AppText.get('msg_select_products')); return; }
    List<String> detailedIngredients = [];
    for (var p in allProducts) { if (_selectedProductIds.contains(p.id)) detailedIngredients.add("${p.name} (${p.quantity} ${p.unit})"); }

    try { final result = await InternetAddress.lookup('google.com'); if (result.isEmpty) throw SocketException(''); }
    on SocketException catch (_) { SnackbarUtils.showError(context, "${AppText.get('err_no_internet_short')} 🔌"); return; }

    bool canContinue = await AdService().checkAndShowAd(context);
    if (canContinue) _showDietSelectionDialog(detailedIngredients);
  }

  void _showDietSelectionDialog(List<String> detailedIngredients) {
    final diets = [
      {'id': 'standard', 'label': 'diet_standard', 'icon': Icons.restaurant}, {'id': 'vegetarian', 'label': 'diet_vegetarian', 'icon': Icons.eco},
      {'id': 'vegan', 'label': 'diet_vegan', 'icon': Icons.spa}, {'id': 'healthy', 'label': 'diet_healthy', 'icon': Icons.monitor_heart},
      {'id': 'keto', 'label': 'diet_keto', 'icon': Icons.fitness_center},
    ];

    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (ctx) {
        final safeBottom = MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 15 : 40.0;
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return Container(
                decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
                padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: safeBottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(AppText.get('diet_title'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 20),
                    Wrap(
                      spacing: 12, runSpacing: 12, alignment: WrapAlignment.center,
                      children: diets.map((diet) {
                        final isSelected = _selectedDiet == diet['id'];
                        return ChoiceChip(
                          label: Text(AppText.get(diet['label'] as String)), avatar: Icon(diet['icon'] as IconData, size: 18, color: isSelected ? Colors.white : Colors.green), selected: isSelected, selectedColor: Colors.green, backgroundColor: Theme.of(context).scaffoldBackgroundColor, labelStyle: TextStyle(color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color),
                          onSelected: (val) { setModalState(() { _selectedDiet = diet['id'] as String; }); setState(() { _selectedDiet = diet['id'] as String; }); },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity, height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () { Navigator.pop(ctx); _searchRecipes(detailedIngredients); },
                        icon: const Icon(Icons.search, color: Colors.white), label: Text("${AppText.get('find_recipes')} 🚀", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      ),
                    )
                  ],
                ),
              );
            }
        );
      },
    );
  }

  Future<void> _searchRecipes(List<String> detailedIngredients) async {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(padding: const EdgeInsets.all(20), width: 150, child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(color: Colors.green), const SizedBox(height: 16), Text(AppText.get('msg_ai_thinking'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))])),
      ),
    );

    try {
      final recipes = await AiRecipeService().getRecipes(ingredients: detailedIngredients, userLanguage: languageNotifier.value, dietType: _selectedDiet);
      if (!mounted) return;
      Navigator.pop(context);
      setState(() { _selectedProductIds.clear(); });
      _showResults(recipes);
    } catch (e) {
      if (mounted) { Navigator.pop(context); SnackbarUtils.showError(context, e.toString()); }
    }
  }

  void _showResults(List<Recipe> recipes) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.9, minChildSize: 0.5, maxChildSize: 0.95,
        builder: (_, controller) {
          final cardColor = Theme.of(context).cardColor;
          final textColor = Theme.of(context).textTheme.bodyLarge?.color;

          return Container(
            decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              children: [
                Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 15), Text(AppText.get('recipe_title'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)), const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    controller: controller, padding: const EdgeInsets.all(16), itemCount: recipes.length,
                    itemBuilder: (ctx, i) {
                      final recipe = recipes[i];
                      String dietLabelKey = 'tag_standard'; Color badgeColor = Colors.orange;
                      if (_selectedDiet == 'vegetarian' || recipe.isVegetarian) { dietLabelKey = 'tag_vegetarian'; badgeColor = Colors.green; }
                      else if (_selectedDiet == 'vegan') { dietLabelKey = 'tag_vegan'; badgeColor = Colors.lightGreen; }
                      else if (_selectedDiet == 'keto') { dietLabelKey = 'tag_keto'; badgeColor = Colors.purple; }
                      else if (_selectedDiet == 'healthy') { dietLabelKey = 'tag_healthy'; badgeColor = Colors.teal; }

                      return GestureDetector(
                        onTap: () { Navigator.push(context, MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipe, dietLabelKey: dietLabelKey))); },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 15, offset: const Offset(0, 5))]), clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  SizedBox(height: 200, width: double.infinity, child: Image.network(recipe.imageUrl, fit: BoxFit.cover, errorBuilder: (ctx, err, stack) => Container(color: Colors.grey.shade200, child: const Center(child: Icon(Icons.restaurant, size: 40, color: Colors.grey))))),
                                  Positioned(top: 10, right: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.eco, color: Colors.white, size: 14), const SizedBox(width: 4), Text(AppText.get(dietLabelKey), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))]))),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(recipe.title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor, height: 1.2)), const SizedBox(height: 8),
                                    Row(children: [Icon(Icons.timer_outlined, size: 16, color: Colors.grey[600]), const SizedBox(width: 4), Text(recipe.time, style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.bold)), const SizedBox(width: 15), Icon(Icons.local_fire_department, size: 16, color: Colors.orange), const SizedBox(width: 4), Text("${recipe.kcal} ${AppText.get('rec_kcal')}", style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.bold))]),
                                    if (recipe.missingIngredients.isNotEmpty) ...[const SizedBox(height: 10), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Text("${AppText.get('missing_title')} ${recipe.missingIngredients.length}", style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.bold)))],
                                    const SizedBox(height: 10), Text(recipe.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: textColor?.withValues(alpha: 0.7), fontSize: 14)),
                                  ],
                                ),
                              )
                            ],
                          ),
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

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final cardColor = Theme.of(context).cardColor;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnap) {
        final householdId = userSnap.data?.data() != null ? (userSnap.data!.data() as Map)['householdId'] : null;
        final collection = _getProductsCollection(householdId);
        final shopListCollection = _getListCollection(householdId);

        return StreamBuilder<QuerySnapshot>(
          stream: collection.orderBy('expirationDate').snapshots(),
          builder: (ctx, productSnap) {
            if (productSnap.hasError) return const Center(child: CircularProgressIndicator());
            if (!productSnap.hasData) return Scaffold(backgroundColor: bgColor, appBar: AppBar(title: Text(AppText.get('my_fridge'))), body: const Center(child: CircularProgressIndicator()));

            final allProducts = productSnap.data!.docs.map((doc) => Product.fromFirestore(doc)).toList();
            final trashProducts = allProducts.where((p) => p.category == 'trash' || p.daysLeft <= 0).toList();
            final freshProducts = allProducts.where((p) => p.category != 'trash' && p.daysLeft > 0).toList();
            final visibleProducts = _selectedCategoryFilter == 'all' ? freshProducts : freshProducts.where((p) => p.category == _selectedCategoryFilter).toList();

            return Scaffold(
              backgroundColor: bgColor,
              appBar: AppBar(
                leading: IconButton(
                    icon: const Icon(Icons.receipt_long, color: Colors.blue, size: 28),
                    tooltip: "Сканувати чек",
                    onPressed: () => ReceiptScanner.startScan(context, collection, languageNotifier.value)
                ),
                title: Text(AppText.get('my_fridge')),
                backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
                centerTitle: true,
                actions: [
                  IconButton(icon: Icon(Icons.delete_sweep_outlined, color: trashProducts.isEmpty ? Colors.grey.withValues(alpha: 0.5) : Colors.red), onPressed: () => trashProducts.isEmpty ? SnackbarUtils.showWarning(context, AppText.get('trash_empty')) : _openTrashBin(collection, shopListCollection)),
                ],
              ),
              body: Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(children: [_filterChip('all', AppText.get('cat_all'), Icons.grid_view, textColor, cardColor), ...appCategories.map((cat) => _filterChip(cat.id, AppText.get(cat.labelKey), cat.icon, cat.color, cardColor))]),
                  ),
                  Expanded(
                    child: visibleProducts.isEmpty
                        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.kitchen_outlined, size: 80, color: Colors.green.shade300), const SizedBox(height: 10), Text(AppText.get('empty_fridge'), style: TextStyle(color: Colors.grey))]))
                        : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100), itemCount: visibleProducts.length,
                      itemBuilder: (ctx, i) {
                        final product = visibleProducts[i];
                        return SlideInAnimation(
                          delay: i * 50,
                          child: ProductListItem(
                            product: product,
                            isSelected: _selectedProductIds.contains(product.id),
                            cardColor: cardColor,
                            textColor: textColor,
                            categoryData: appCategories.firstWhere((c) => c.id == product.category, orElse: () => appCategories[0]),
                            onTap: () => _toggleSelection(product.id),
                            onEdit: (p) => FridgeDialogs.showProductDialog(context: context, productToEdit: p, collection: collection, categories: appCategories, cancelNotification: (id) => NotificationService.cancelNotification(id)),
                            onShop: (p) async { await shopListCollection.add({'name': p.name, 'isBought': false, 'addedDate': Timestamp.now(), 'quantity': p.quantity, 'unit': p.unit}); _deleteProductForever(p, collection); },
                            onEaten: (p) => FridgeDialogs.showConsumeDialog(context: context, product: p, collection: collection, recordHistory: _recordHistory, onDeleteForever: () => _deleteProductForever(p, collection)),
                            onDelete: (p) => _confirmSoftDelete(p, collection),
                          ),
                        );
                      },
                    ),
                  ),
                  if (_bannerAd != null && _isBannerLoaded && !SubscriptionService().hasProOrHigher) Container(alignment: Alignment.center, width: _bannerAd!.size.width.toDouble(), height: _bannerAd!.size.height.toDouble(), child: AdWidget(ad: _bannerAd!)),
                ],
              ),
              floatingActionButton: _selectedProductIds.isNotEmpty
                  ? FloatingActionButton.extended(onPressed: () => _checkLimitAndSearch(allProducts), label: Text(AppText.get('cook_btn'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), icon: const Icon(Icons.restaurant_menu, size: 28), backgroundColor: Colors.deepOrange, foregroundColor: Colors.white, elevation: 4)
                  : SizedBox(width: 65, height: 65, child: FloatingActionButton(onPressed: () => FridgeDialogs.showProductDialog(context: context, collection: collection, categories: appCategories, cancelNotification: (id) => NotificationService.cancelNotification(id)), backgroundColor: Colors.green.shade600, foregroundColor: Colors.white, elevation: 4, shape: const CircleBorder(), child: const Icon(Icons.add, size: 36))),
            );
          },
        );
      },
    );
  }

  Widget _filterChip(String id, String label, IconData icon, Color textColor, Color bgColor) {
    final isSelected = _selectedCategoryFilter == id;
    return Padding(
        padding: const EdgeInsets.only(right: 10),
        child: InkWell(
            onTap: () => setState(() => _selectedCategoryFilter = id), borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: isSelected ? Colors.green : (bgColor), borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? Colors.green : Colors.grey.shade300), boxShadow: isSelected ? [BoxShadow(color: Colors.green.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 3))] : []), child: Row(children: [Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.grey), const SizedBox(width: 8), Text(label, style: TextStyle(color: isSelected ? Colors.white : textColor, fontWeight: FontWeight.bold))]))));
  }
}

class SlideInAnimation extends StatefulWidget {
  final Widget child; final int delay;
  const SlideInAnimation({super.key, required this.child, required this.delay});
  @override State<SlideInAnimation> createState() => _SlideInAnimationState();
}

class _SlideInAnimationState extends State<SlideInAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller; late Animation<Offset> _offsetAnim;
  @override void initState() { super.initState(); _controller = AnimationController(duration: const Duration(milliseconds: 500), vsync: this); _offsetAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut)); Future.delayed(Duration(milliseconds: widget.delay), () { if(mounted) _controller.forward(); }); }
  @override void dispose() { _controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) { return FadeTransition(opacity: _controller, child: SlideTransition(position: _offsetAnim, child: widget.child)); }
}