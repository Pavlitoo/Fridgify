import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 👇 НЕ ЗАБУДЬ

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
import '../secrets.dart';
import 'recipe_detail_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _initAds();
    _setupNotifications();
  }

  void _setupNotifications() {
    FirebaseFirestore.instance.collection('users').doc(user.uid).get().then((doc) {
      if (!mounted) return;

      String? householdId;
      if (doc.exists && doc.data() != null) {
        householdId = (doc.data() as Map)['householdId'];
      }

      final collectionRef = householdId != null
          ? FirebaseFirestore.instance.collection('households').doc(householdId).collection('products')
          : FirebaseFirestore.instance.collection('users').doc(user.uid).collection('products');

      _productSubscription = collectionRef.snapshots().listen((snapshot) {
        _scheduleAllNotifications(snapshot.docs);
      });
    });
  }

  // 🔥 ОНОВЛЕНИЙ МЕТОД З "АНТИ-СПАМОМ"
  void _scheduleAllNotifications(List<QueryDocumentSnapshot> docs) async {
    // Скасовуємо старі таймери (щоб не було дублів)
    await NotificationService.cancelAll();

    List<String> expiredItems = [];
    final now = DateTime.now();

    for (var doc in docs) {
      final product = Product.fromFirestore(doc);
      if (product.category == 'trash') continue;

      // 1. Плануємо майбутні сповіщення (таймери)
      // Ми ставимо таймер ТІЛЬКИ якщо дата ще попереду.
      // NotificationService сам розбереться з zonedSchedule
      if (product.expirationDate.isAfter(now)) {
        await NotificationService.scheduleNotification(
            product.id.hashCode,
            product.name,
            product.expirationDate
        );
      }

      // 2. Збираємо те, що ВЖЕ прострочено або псується завтра
      final daysLeft = product.expirationDate.difference(now).inDays;
      if (daysLeft <= 1) {
        expiredItems.add(product.name);
      }
    }

    // 3. РОЗУМНЕ ВІДОБРАЖЕННЯ (Тільки 1 раз на день)
    if (expiredItems.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final String todayDate = "${now.year}-${now.month}-${now.day}";
      final String? lastShownDate = prefs.getString('last_expired_alert_date');

      // Якщо сьогодні ще НЕ показували сповіщення - показуємо
      if (lastShownDate != todayDate) {
        String title = AppText.get('notif_instant_title');
        String bodyPrefix = AppText.get('notif_instant_body');
        String listString = expiredItems.join(', ');

        await NotificationService.showNotification(
            id: 99999,
            title: title,
            body: "$bodyPrefix: $listString",
            payload: 'fridge' // Щоб при кліку відкрило холодильник
        );

        // Запам'ятовуємо, що сьогодні ми вже попередили користувача
        await prefs.setString('last_expired_alert_date', todayDate);
      }
    }
  }

  void _initAds() {
    AdService().init();
    if (!SubscriptionService().isPremium) {
      _loadBannerAd();
    }
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: Secrets.adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _isBannerLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('❌ Banner failed to load: $error');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _productSubscription?.cancel();
    super.dispose();
  }

  CollectionReference _getProductsCollection(String? householdId) {
    return (householdId != null)
        ? FirebaseFirestore.instance.collection('households').doc(householdId).collection('products')
        : FirebaseFirestore.instance.collection('users').doc(user.uid).collection('products');
  }

  CollectionReference _getListCollection(String? householdId) {
    return (householdId != null)
        ? FirebaseFirestore.instance.collection('households').doc(householdId).collection('shopping_list')
        : FirebaseFirestore.instance.collection('users').doc(user.uid).collection('shopping_list');
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedProductIds.contains(id)) {
        _selectedProductIds.remove(id);
      } else {
        _selectedProductIds.add(id);
      }
    });
  }

  void _deleteProductForever(Product product, CollectionReference collection) {
    NotificationService.cancelNotification(product.id.hashCode);
    collection.doc(product.id).delete();
  }

  void _moveToTrash(Product product, CollectionReference collection) {
    collection.doc(product.id).update({'category': 'trash'});
    NotificationService.cancelNotification(product.id.hashCode);
  }

  Future<void> _moveFromTrashToShopList(Product product, CollectionReference fridgeCollection, CollectionReference listCollection) async {
    try {
      await listCollection.add({
        'name': product.name,
        'quantity': product.quantity,
        'unit': product.unit,
        'isBought': false,
        'addedDate': Timestamp.now(),
      });
      _deleteProductForever(product, fridgeCollection);

      if (mounted) {
        Navigator.pop(context);
        SnackbarUtils.showSuccess(context, "🛒 ${product.name} ${AppText.get('yes_list')}");
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, ErrorHandler.getMessage(e));
      }
    }
  }

  void _confirmDeleteFromTrash(Product product, CollectionReference collection) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(AppText.get('btn_delete_forever')),
        content: Text(AppText.get('no_delete')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppText.get('cancel'))),
          ElevatedButton(
            onPressed: () {
              _deleteProductForever(product, collection);
              Navigator.pop(ctx);
              SnackbarUtils.showWarning(context, AppText.get('msg_deleted_forever'));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  void _handleRestore(Product product, CollectionReference collection) {
    if (product.daysLeft <= 0) {
      SnackbarUtils.showWarning(context, AppText.get('msg_change_date'));
      _showProductDialog(productToEdit: product, collection: collection);
    } else {
      collection.doc(product.id).update({'category': 'other'});
      Navigator.pop(context);
      SnackbarUtils.showSuccess(context, AppText.get('msg_restored'));
    }
  }

  void _openTrashBin(CollectionReference collection, CollectionReference shopCollection) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, controller) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final textColor = Theme.of(context).textTheme.bodyLarge?.color;
          final subTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.only(top: 20, left: 16, right: 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.delete_sweep, color: Colors.red, size: 28),
                    const SizedBox(width: 10),
                    Text(AppText.get('trash_title'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
                  ],
                ),
                const SizedBox(height: 5),
                Text(AppText.get('trash_sub'), style: TextStyle(color: subTextColor)),
                const SizedBox(height: 20),

                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: collection.orderBy('expirationDate').snapshots(),
                    builder: (ctx, snap) {
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator());

                      final allDocs = snap.data!.docs.map((doc) => Product.fromFirestore(doc)).toList();
                      final trashProducts = allDocs.where((p) => p.category == 'trash' || p.daysLeft <= 0).toList();

                      if (trashProducts.isEmpty) {
                        return Center(child: Text(AppText.get('trash_empty'), style: TextStyle(color: subTextColor, fontSize: 16)));
                      }

                      return ListView.builder(
                        controller: controller,
                        itemCount: trashProducts.length,
                        itemBuilder: (ctx, i) {
                          final product = trashProducts[i];
                          bool isManualDelete = product.category == 'trash';
                          Color bg = isManualDelete ? (isDark ? Colors.grey.shade800 : Colors.grey.shade200) : (isDark ? Colors.red.withOpacity(0.15) : Colors.red.shade50.withOpacity(0.5));
                          Color iconColor = isManualDelete ? (isDark ? Colors.grey.shade400 : Colors.grey) : Colors.red;
                          return Card(
                            color: bg,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: iconColor.withOpacity(0.3))),
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: Icon(isManualDelete ? Icons.delete_outline : Icons.warning_amber_rounded, color: iconColor),
                              title: Text(product.name, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, decoration: TextDecoration.lineThrough)),
                              subtitle: Text(
                                  isManualDelete ? AppText.get('status_deleted') : "${AppText.get('status_rotten')} ${product.daysLeft.abs()} ${AppText.get('ago_suffix')}",
                                  style: TextStyle(color: iconColor)
                              ),
                              trailing: PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: Colors.grey),
                                onSelected: (val) {
                                  if (val == 'shop') _moveFromTrashToShopList(product, collection, shopCollection);
                                  if (val == 'delete') _confirmDeleteFromTrash(product, collection);
                                  if (val == 'restore') _handleRestore(product, collection);
                                },
                                itemBuilder: (ctx) => [
                                  PopupMenuItem(value: 'shop', child: Row(children: [const Icon(Icons.refresh, color: Colors.orange), const SizedBox(width: 8), Text(AppText.get('btn_buy'), style: TextStyle(color: textColor))])),
                                  PopupMenuItem(value: 'restore', child: Row(children: [const Icon(Icons.restore, color: Colors.blue), const SizedBox(width: 8), Text(AppText.get('btn_restore'), style: TextStyle(color: textColor))])),
                                  PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.delete_forever, color: Colors.red), const SizedBox(width: 8), Text(AppText.get('btn_delete_forever'), style: TextStyle(color: textColor))])),
                                ],
                              ),
                            ),
                          );
                        },
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

  void _showConsumeDialog(Product product, CollectionReference collection) {
    final TextEditingController consumeController = TextEditingController();
    bool isPcs = product.unit == 'pcs';
    final dialogBg = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final inputFill = Theme.of(context).scaffoldBackgroundColor;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBg,
        title: Text(AppText.get('action_eaten'), textAlign: TextAlign.center, style: TextStyle(color: textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("${product.quantity} ${AppText.get('u_${product.unit}')}", style: TextStyle(fontSize: 14, color: textColor?.withOpacity(0.7))),
            const SizedBox(height: 10),
            TextField(
              controller: consumeController,
              keyboardType: TextInputType.numberWithOptions(decimal: !isPcs),
              inputFormatters: isPcs ? [FilteringTextInputFormatter.digitsOnly] : [],
              style: TextStyle(color: textColor),
              decoration: InputDecoration(hintText: "???", filled: true, fillColor: inputFill, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppText.get('cancel'))),
          ElevatedButton(
            onPressed: () {
              double consumed;
              if (isPcs) {
                consumed = int.tryParse(consumeController.text)?.toDouble() ?? 0;
              } else {
                consumed = double.tryParse(consumeController.text.replaceAll(',', '.')) ?? 0;
              }
              if (consumed <= 0) return;

              if (consumed >= product.quantity) {
                _deleteProductForever(product, collection);
              } else {
                double newQty = product.quantity - consumed;
                newQty = (newQty * 100).round() / 100;
                collection.doc(product.id).update({'quantity': newQty});
              }
              Navigator.pop(ctx);
              SnackbarUtils.showSuccess(context, "😋 ${AppText.get('action_eaten')}");
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: Text(AppText.get('save')),
          ),
        ],
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
            onPressed: () {
              _moveToTrash(product, collection);
              Navigator.pop(ctx);
              SnackbarUtils.showWarning(context, "${AppText.get('status_deleted')} 🗑");
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("OK"),
          )
        ],
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
    if (selectedCategory == 'trash') selectedCategory = 'other';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          String formattedDate = "${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}";
          final dialogBg = Theme.of(context).cardColor;
          final textColor = Theme.of(context).textTheme.bodyLarge?.color;
          final inputFill = Theme.of(context).scaffoldBackgroundColor;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: dialogBg,
            contentPadding: const EdgeInsets.all(24),
            title: Text(isEditing ? AppText.get('edit_product') : AppText.get('add_product'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: textColor), textAlign: TextAlign.center),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameController, style: TextStyle(fontSize: 18, color: textColor), decoration: InputDecoration(hintText: AppText.get('product_name'), hintStyle: const TextStyle(color: Colors.grey), prefixIcon: const Icon(Icons.edit, color: Colors.green), filled: true, fillColor: inputFill, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)), autofocus: true),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: TextField(controller: qtyController, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: textColor), decoration: InputDecoration(hintText: AppText.get('quantity'), hintStyle: const TextStyle(color: Colors.grey), filled: true, fillColor: inputFill, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)))),
                      const SizedBox(width: 12),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: inputFill, borderRadius: BorderRadius.circular(16)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(dropdownColor: dialogBg, value: selectedUnit, style: TextStyle(color: textColor), onChanged: (val) => setDialogState(() => selectedUnit = val!), items: ['pcs', 'kg', 'g', 'l', 'ml'].map((unit) { return DropdownMenuItem(value: unit, child: Text(AppText.get('u_$unit'), style: TextStyle(color: textColor))); }).toList())))
                    ]),
                    const SizedBox(height: 24),
                    Text(AppText.get('category_label'), style: TextStyle(color: textColor?.withOpacity(0.7), fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 10, children: appCategories.map((cat) { final isSelected = selectedCategory == cat.id; return InkWell(onTap: () => setDialogState(() => selectedCategory = cat.id), child: Column(mainAxisSize: MainAxisSize.min, children: [AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isSelected ? cat.color : inputFill, shape: BoxShape.circle, boxShadow: isSelected ? [BoxShadow(color: cat.color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))] : []), child: Icon(cat.icon, color: isSelected ? Colors.white : Colors.grey, size: 28)), const SizedBox(height: 4), Text(AppText.get(cat.labelKey), style: TextStyle(fontSize: 10, color: isSelected ? cat.color : Colors.grey, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))])); }).toList()),
                    const SizedBox(height: 30),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(AppText.get('days_valid'), style: TextStyle(fontSize: 16, color: textColor?.withOpacity(0.7))),
                      InkWell(onTap: () async { final DateTime? picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365 * 10)), locale: getAppLocale(languageNotifier.value)); if (picked != null && picked != selectedDate) { setDialogState(() { selectedDate = picked; }); } }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: Colors.green.shade50.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green)), child: Row(children: [const Icon(Icons.calendar_today, size: 18, color: Colors.green), const SizedBox(width: 8), Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16))]))),
                    ])
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(AppText.get('cancel'), style: TextStyle(fontSize: 16, color: textColor))),
              ElevatedButton(onPressed: () async { if (nameController.text.isNotEmpty) { final qty = double.tryParse(qtyController.text) ?? 1.0; final data = {'name': nameController.text.trim(), 'expirationDate': Timestamp.fromDate(selectedDate), 'category': selectedCategory, 'quantity': qty, 'unit': selectedUnit}; if (isEditing) { await collection.doc(productToEdit.id).update(data); NotificationService.cancelNotification(productToEdit.id.hashCode); NotificationService.scheduleNotification(productToEdit.id.hashCode, nameController.text.trim(), selectedDate); } else { final docRef = await collection.add({...data, 'addedDate': Timestamp.now()}); NotificationService.scheduleNotification(docRef.id.hashCode, nameController.text.trim(), selectedDate); } Navigator.pop(context); } }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(isEditing ? AppText.get('save') : AppText.get('add'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))
            ],
          );
        });
      },
    );
  }

  // 🔥 МЕНЮ ВИБОРУ ДІЄТИ
  Future<void> _checkLimitAndSearch(List<Product> allProducts) async {
    if (_selectedProductIds.isEmpty) {
      SnackbarUtils.showWarning(context, AppText.get('msg_select_products'));
      return;
    }

    List<String> detailedIngredients = [];
    for (var p in allProducts) {
      if (_selectedProductIds.contains(p.id)) {
        detailedIngredients.add("${p.name} (${p.quantity} ${p.unit})");
      }
    }

    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {}
    } on SocketException catch (_) {
      SnackbarUtils.showError(context, "${AppText.get('err_no_internet_short')} 🔌");
      return;
    }

    bool canContinue = await AdService().checkAndShowAd(context);
    if (canContinue) {
      _showDietSelectionDialog(detailedIngredients);
    }
  }

  void _showDietSelectionDialog(List<String> detailedIngredients) {
    final diets = [
      {'id': 'standard', 'label': 'diet_standard', 'icon': Icons.restaurant},
      {'id': 'vegetarian', 'label': 'diet_vegetarian', 'icon': Icons.eco},
      {'id': 'vegan', 'label': 'diet_vegan', 'icon': Icons.spa},
      {'id': 'healthy', 'label': 'diet_healthy', 'icon': Icons.monitor_heart},
      {'id': 'keto', 'label': 'diet_keto', 'icon': Icons.fitness_center},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppText.get('diet_title'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: diets.map((diet) {
                final isSelected = _selectedDiet == diet['id'];
                return ChoiceChip(
                  label: Text(AppText.get(diet['label'] as String)),
                  avatar: Icon(diet['icon'] as IconData, size: 18, color: isSelected ? Colors.white : Colors.green),
                  selected: isSelected,
                  selectedColor: Colors.green,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  labelStyle: TextStyle(color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color),
                  onSelected: (val) {
                    setState(() => _selectedDiet = diet['id'] as String);
                    Navigator.pop(context);
                    _showDietSelectionDialog(detailedIngredients);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _searchRecipes(detailedIngredients);
                },
                icon: const Icon(Icons.search, color: Colors.white),
                label: Text(AppText.get('btn_start_cooking'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              ),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _searchRecipes(List<String> detailedIngredients) async {
    // 🔥 МАЛЕНЬКИЙ КВАДРАТНИЙ ДІАЛОГ
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          width: 150,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.green),
              const SizedBox(height: 16),
              Text(
                  AppText.get('msg_ai_thinking'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final recipes = await AiRecipeService().getRecipes(
        ingredients: detailedIngredients,
        userLanguage: languageNotifier.value,
        dietType: _selectedDiet,
      );

      if (!mounted) return;
      Navigator.pop(context);
      _showResults(recipes);

    } catch (e) {
      if (mounted) {
        Navigator.pop(context);

        // 🔥 Обробка помилок
        if (e.toString().contains('INVALID_INGREDIENTS')) {
          SnackbarUtils.showWarning(context, AppText.get('err_invalid_ingredients'));
        } else if (e.toString().contains('401')) {
          SnackbarUtils.showError(context, "Помилка авторизації (401). Перевірте ключ API.");
        } else if (e is SocketException || e.toString().contains('No Internet')) {
          SnackbarUtils.showError(context, "${AppText.get('err_no_internet_short')} 🔌");
        } else if (e is TimeoutException || e.toString().contains('TIMEOUT')) {
          SnackbarUtils.showError(context, "Час вийшов! Спробуйте пізніше.");
        } else {
          SnackbarUtils.showError(context, "${AppText.get('err_general')}: ${e.toString()}");
        }
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
                      final bool hasMissing = recipe.missingIngredients.isNotEmpty;

                      String dietLabelKey = 'tag_standard';
                      Color badgeColor = Colors.orange;

                      if (_selectedDiet == 'vegetarian') { dietLabelKey = 'tag_vegetarian'; badgeColor = Colors.green; }
                      else if (_selectedDiet == 'vegan') { dietLabelKey = 'tag_vegan'; badgeColor = Colors.lightGreen; }
                      else if (_selectedDiet == 'keto') { dietLabelKey = 'tag_keto'; badgeColor = Colors.purple; }
                      else if (_selectedDiet == 'healthy') { dietLabelKey = 'tag_healthy'; badgeColor = Colors.teal; }
                      else if (recipe.isVegetarian) { dietLabelKey = 'tag_vegetarian'; badgeColor = Colors.green; }

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipe, dietLabelKey: dietLabelKey)));
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))]
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  SizedBox(
                                    height: 200,
                                    width: double.infinity,
                                    child: Image.network(
                                      recipe.imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey.shade200, child: const Center(child: Icon(Icons.restaurant, size: 40, color: Colors.grey))),
                                    ),
                                  ),
                                  Positioned(
                                    top: 10, right: 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(8)),
                                      child: Row(children: [
                                        const Icon(Icons.eco, color: Colors.white, size: 14),
                                        const SizedBox(width: 4),
                                        Text(AppText.get(dietLabelKey), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))
                                      ]),
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(recipe.title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor, height: 1.2)),
                                    const SizedBox(height: 8),
                                    Row(children: [
                                      Icon(Icons.timer_outlined, size: 16, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text(recipe.time, style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 15),
                                      Icon(Icons.local_fire_department, size: 16, color: Colors.orange),
                                      const SizedBox(width: 4),
                                      Text("${recipe.kcal} ${AppText.get('rec_kcal')}", style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.bold)),
                                    ]),
                                    if (hasMissing) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                        child: Text("${AppText.get('missing_title')} ${recipe.missingIngredients.length}", style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    Text(recipe.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: textColor?.withOpacity(0.7), fontSize: 14)),
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
                if (_bannerAd != null && _isBannerLoaded && !SubscriptionService().isPremium)
                  Container(alignment: Alignment.center, width: _bannerAd!.size.width.toDouble(), height: _bannerAd!.size.height.toDouble(), child: AdWidget(ad: _bannerAd!)),
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
                title: Text(AppText.get('my_fridge')),
                backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
                centerTitle: true,
                actions: [
                  IconButton(
                    icon: Icon(Icons.delete_sweep_outlined, color: trashProducts.isEmpty ? Colors.grey.withOpacity(0.5) : Colors.red),
                    onPressed: () => trashProducts.isEmpty ? SnackbarUtils.showWarning(context, AppText.get('trash_empty')) : _openTrashBin(collection, shopListCollection),
                  ),
                ],
              ),
              body: Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(children: [
                      _filterChip('all', AppText.get('cat_all'), Icons.grid_view, textColor, cardColor),
                      ...appCategories.map((cat) => _filterChip(cat.id, AppText.get(cat.labelKey), cat.icon, cat.color, cardColor))
                    ]),
                  ),
                  Expanded(
                    child: visibleProducts.isEmpty
                        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.kitchen_outlined, size: 80, color: Colors.green.shade300), const SizedBox(height: 10), Text(AppText.get('empty_fridge'), style: TextStyle(color: Colors.grey))]))
                        : ListView.builder(
                      itemCount: visibleProducts.length,
                      itemBuilder: (ctx, i) {
                        final product = visibleProducts[i];
                        final isSelected = _selectedProductIds.contains(product.id);
                        Color statusColor = product.daysLeft < 3 ? Colors.orange : Colors.green;
                        String timeLeftText = product.daysLeft < 30 ? "${product.daysLeft} ${AppText.get('u_days')}" : "${(product.daysLeft / 30).floor()} ${AppText.get('u_months')}";
                        final catData = appCategories.firstWhere((c) => c.id == product.category, orElse: () => appCategories[0]);

                        return SlideInAnimation(
                          delay: i * 50,
                          child: Card(
                            color: isSelected ? Colors.green.shade100 : cardColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: isSelected ? const BorderSide(color: Colors.green, width: 2) : BorderSide.none),
                            elevation: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: InkWell(
                              onTap: () => _toggleSelection(product.id),
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: catData.color.withOpacity(0.15), shape: BoxShape.circle), child: Icon(catData.icon, color: catData.color, size: 28)),
                                  title: Row(children: [Expanded(child: Text(product.name, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isSelected ? Colors.black : textColor))), const SizedBox(width: 8), Text("(${product.quantity} ${AppText.get('u_${product.unit}')})", style: const TextStyle(color: Colors.grey, fontSize: 14))]),
                                  subtitle: Row(children: [Icon(Icons.timer_outlined, size: 16, color: statusColor), const SizedBox(width: 4), Text(timeLeftText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 14))]),
                                  trailing: PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                    color: cardColor,
                                    onSelected: (value) async {
                                      if (value == 'edit') _showProductDialog(productToEdit: product, collection: collection);
                                      else if (value == 'shop') { await shopListCollection.add({'name': product.name, 'isBought': false, 'addedDate': Timestamp.now(), 'quantity': product.quantity, 'unit': product.unit}); _deleteProductForever(product, collection); }
                                      else if (value == 'eaten') _showConsumeDialog(product, collection);
                                      else if (value == 'delete') _confirmSoftDelete(product, collection);
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(value: 'edit', child: Row(children: [const Icon(Icons.edit, color: Colors.blue), const SizedBox(width: 10), Text(AppText.get('edit_product'), style: TextStyle(color: textColor))])),
                                      PopupMenuItem(value: 'eaten', child: Row(children: [const Icon(Icons.restaurant, color: Colors.green), const SizedBox(width: 10), Text(AppText.get('action_eaten'), style: TextStyle(color: textColor))])),
                                      PopupMenuItem(value: 'shop', child: Row(children: [const Icon(Icons.shopping_cart, color: Colors.orange), const SizedBox(width: 10), Text(AppText.get('yes_list'), style: TextStyle(color: textColor))])),
                                      const PopupMenuDivider(),
                                      PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.delete_outline, color: Colors.red), const SizedBox(width: 10), Text(AppText.get('no_delete'), style: TextStyle(color: textColor))])),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (_bannerAd != null && _isBannerLoaded && !SubscriptionService().isPremium)
                    Container(alignment: Alignment.center, width: _bannerAd!.size.width.toDouble(), height: _bannerAd!.size.height.toDouble(), child: AdWidget(ad: _bannerAd!)),
                ],
              ),
              floatingActionButton: _selectedProductIds.isNotEmpty
                  ? FloatingActionButton.extended(
                  onPressed: () => _checkLimitAndSearch(allProducts),
                  label: Text(AppText.get('cook_btn'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  icon: const Icon(Icons.restaurant_menu, size: 28),
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  elevation: 4)
                  : SizedBox(width: 65, height: 65, child: FloatingActionButton(onPressed: () => _showProductDialog(collection: collection, productToEdit: null), backgroundColor: Colors.green.shade600, foregroundColor: Colors.white, elevation: 4, shape: const CircleBorder(), child: const Icon(Icons.add, size: 36))),
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
            onTap: () => setState(() => _selectedCategoryFilter = id),
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: isSelected ? Colors.green : (bgColor), borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? Colors.green : Colors.grey.shade300), boxShadow: isSelected ? [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))] : []),
                child: Row(children: [Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.grey), const SizedBox(width: 8), Text(label, style: TextStyle(color: isSelected ? Colors.white : textColor, fontWeight: FontWeight.bold))]))));
  }
}

class SlideInAnimation extends StatefulWidget {
  final Widget child;
  final int delay;
  const SlideInAnimation({super.key, required this.child, required this.delay});
  @override State<SlideInAnimation> createState() => _SlideInAnimationState();
}

class _SlideInAnimationState extends State<SlideInAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnim;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _offsetAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: widget.delay), () { if(mounted) _controller.forward(); });
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) { return FadeTransition(opacity: _controller, child: SlideTransition(position: _offsetAnim, child: widget.child)); }
}