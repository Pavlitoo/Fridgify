import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:dio/dio.dart';

import '../recipe_model.dart';
import '../translations.dart';
import '../utils/snackbar_utils.dart';
import '../subscription_service.dart';
import '../ad_service.dart';
import '../chat_service.dart';
import '../smart_avatar.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;
  final String dietLabelKey;

  const RecipeDetailScreen({super.key, required this.recipe, required this.dietLabelKey});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  bool _isSaved = false;
  final user = FirebaseAuth.instance.currentUser;
  final Set<String> _addedToCart = {};
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  List<String> _dynamicAvailableIngredients = [];
  List<String> _dynamicMissingIngredients = [];

  @override
  void initState() {
    super.initState();
    _checkIfSaved();

    // 🔥 БЕРЕМО ДАНІ ПРЯМО ВІД ШІ (БЕЗ ЗАЙВИХ ПЕРЕВІРОК)
    _dynamicAvailableIngredients = widget.recipe.ingredients;
    _dynamicMissingIngredients = widget.recipe.missingIngredients;

    if (!SubscriptionService().isPremium) _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
        adUnitId: AdService().bannerAdUnitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
            onAdLoaded: (_) { if (mounted) setState(() => _isBannerLoaded = true); },
            onAdFailedToLoad: (ad, error) { ad.dispose(); }
        )
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  String _translateRawIngredient(String raw) {
    final parsed = _parseIngredient(raw);

    // Перекладаємо назву продукту, якщо вона є у словнику
    String translatedName = AppText.get(parsed['name'].toString().toLowerCase());
    if (translatedName == parsed['name'].toString().toLowerCase()) {
      translatedName = parsed['name']; // Залишаємо оригінал, якщо немає перекладу
    }

    // Перекладаємо одиницю виміру (наприклад, 'pcs' -> 'шт', 'g' -> 'г')
    String translatedUnit = AppText.get('u_${parsed['unit']}');
    if (translatedUnit == 'u_${parsed['unit']}') {
      translatedUnit = parsed['unit'];
    }

    // Якщо ШІ не дав числа, просто повертаємо текст
    if (parsed['hasNumber'] != true) {
      return translatedName;
    }

    // Форматуємо кількість: якщо це 1.0 -> робимо 1, якщо 1.5 -> залишаємо 1.5
    double qty = parsed['quantity'];
    String qtyStr = (qty == qty.toInt()) ? qty.toInt().toString() : qty.toString();

    return "$qtyStr $translatedUnit $translatedName".trim();
  }

  Map<String, dynamic> _parseIngredient(String raw) {
    String name = raw.toLowerCase().trim();
    double quantity = 1.0;
    String unit = 'pcs';
    bool hasNumber = false;

    // Регулярка шукає число на початку, потім пробіл, потім одиницю виміру
    final regex = RegExp(r'^([\d.,]+)\s*(г|гр|g|кг|kg|мл|ml|л|l|шт|pcs|ст\.л|ч\.л)?\s*(.*)$');
    final match = regex.firstMatch(name);

    if (match != null && match.group(1) != null) {
      quantity = double.tryParse(match.group(1)!.replaceAll(',', '.')) ?? 1.0;
      unit = _normalizeUnit(match.group(2) ?? 'pcs');
      name = match.group(3) ?? name;
      hasNumber = true; // Ми знайшли реальне число
    }

    // Прибираємо зайві тире чи крапки на початку, якщо ШІ їх додав
    name = name.replaceAll(RegExp(r'^[-*•xх]\s*'), '').trim();
    // Робимо першу літеру великою для краси
    if (name.isNotEmpty) {
      name = name[0].toUpperCase() + name.substring(1);
    }

    return {'name': name, 'quantity': quantity, 'unit': unit, 'hasNumber': hasNumber};
  }

  bool _isSameProduct(String name1, String name2) {
    String n1 = name1.toLowerCase().trim().replaceAll(RegExp(r'[^\w\sа-яА-ЯіІїЇєЄ]'), '');
    String n2 = name2.toLowerCase().trim().replaceAll(RegExp(r'[^\w\sа-яА-ЯіІїЇєЄ]'), '');
    if (n1.isEmpty || n2.isEmpty) return false;
    return n1 == n2 || n1.contains(n2) || n2.contains(n1);
  }

  Future<void> _checkIfSaved() async {
    if (user == null) return;
    final docId = widget.recipe.title.hashCode.toString();
    final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('saved_recipes').doc(docId).get();
    if (mounted) setState(() => _isSaved = doc.exists);
  }

  Future<void> _toggleSave() async {
    if (user == null) return;
    final docId = widget.recipe.title.hashCode.toString();
    final collection = FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('saved_recipes');
    if (_isSaved) {
      await collection.doc(docId).delete();
      if (mounted) { setState(() => _isSaved = false); SnackbarUtils.showWarning(context, AppText.get('msg_recipe_removed')); }
    } else {
      final recipeMap = { 'title': widget.recipe.title, 'description': widget.recipe.description, 'time': widget.recipe.time, 'kcal': widget.recipe.kcal, 'imageUrl': widget.recipe.imageUrl, 'isVegetarian': widget.recipe.isVegetarian, 'ingredients': widget.recipe.ingredients, 'missingIngredients': widget.recipe.missingIngredients, 'steps': widget.recipe.steps, 'dietLabelKey': widget.dietLabelKey, 'savedAt': Timestamp.now() };
      await collection.doc(docId).set(recipeMap);
      if (mounted) { setState(() => _isSaved = true); SnackbarUtils.showSuccess(context, AppText.get('msg_recipe_saved')); }
    }
  }

  Future<void> _shareWithImage() async {
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator()));
    try {
      String ingredientsTitle = AppText.get('rec_ingredients');
      String healthyTag = AppText.get('tag_healthy');

      List<String> allShareIngs = [...widget.recipe.ingredients, ...widget.recipe.missingIngredients];
      String ingredientsText = allShareIngs.map((e) => "• ${_translateRawIngredient(e)}").join('\n');

      String text = "🍳 ${widget.recipe.title}\n⏱ ${widget.recipe.time} | 🔥 ${widget.recipe.kcal} kcal\n";
      if (widget.dietLabelKey == 'tag_healthy') text += "🥗 $healthyTag\n";
      text += "\n🛒 $ingredientsTitle:\n$ingredientsText\n\n🍏 Знайдено в Fridgify!\nЗавантажуй безкоштовно: https://play.google.com/store/apps/details?id=com.pavlo.smart_fridge";

      final dio = Dio();
      final tempDir = await getTemporaryDirectory();
      final filePath = p.join(tempDir.path, 'recipe_${widget.recipe.imageUrl.hashCode}.jpg');
      await dio.download(widget.recipe.imageUrl, filePath);
      final xFile = XFile(filePath);

      if (mounted) Navigator.pop(context);
      await Share.shareXFiles([xFile], text: text);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      SnackbarUtils.showError(context, AppText.get('err_share_failed'));
    }
  }

  Future<void> _shareRecipeToChat() async {
    if (user == null) return;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      final String? householdId = userDoc.data()?['householdId'];

      QuerySnapshot? membersSnap;
      if (householdId != null && householdId.isNotEmpty) {
        membersSnap = await FirebaseFirestore.instance.collection('users').where('householdId', isEqualTo: householdId).get();
      }

      if (!mounted) return;

      showModalBottomSheet(
        context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.5, minChildSize: 0.3, maxChildSize: 0.8, expand: false,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(25))),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 15),
                  Text(AppText.get('share_recipe'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        ListTile(
                          leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.orange.shade100, shape: BoxShape.circle), child: Icon(Icons.share, color: Colors.orange.shade800, size: 22)),
                          title: Text(AppText.get('share_external'), style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(AppText.get('share_external_sub'), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          onTap: () { Navigator.pop(ctx); _shareWithImage(); },
                        ),
                        const Divider(),
                        if (householdId != null && householdId.isNotEmpty) ...[
                          Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text(AppText.get('fam_members'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade500))),
                          ListTile(leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.family_restroom, color: Colors.white)), title: Text(AppText.get('chat_title')), onTap: () { Navigator.pop(ctx); _executeSend(householdId, isDirect: false); }),
                          if (membersSnap != null)
                            ...membersSnap.docs.where((d) => d.id != user!.uid).map((doc) {
                              final mData = doc.data() as Map<String, dynamic>;
                              return ListTile(
                                leading: SmartAvatar(userId: doc.id, radius: 20),
                                title: Text(mData['displayName'] ?? 'User'),
                                onTap: () { Navigator.pop(ctx); String dmId = ChatService().getDmChatId(user!.uid, doc.id); _executeSend(dmId, isDirect: true); },
                              );
                            }),
                        ] else ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
                            child: Column(children: [Icon(Icons.group_add, size: 50, color: Colors.grey.shade300), const SizedBox(height: 12), Text(AppText.get('no_family_share'), textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 14))]),
                          )
                        ]
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    } catch (e) { SnackbarUtils.showError(context, "Error: $e"); }
  }

  Future<void> _executeSend(String id, {required bool isDirect}) async {
    showDialog(context: context, builder: (ctx) => const Center(child: CircularProgressIndicator()));
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      final myName = userDoc.data()?['displayName'] ?? 'User';

      final msg = {
        'type': 'recipe', 'senderId': user!.uid, 'senderName': myName, 'timestamp': FieldValue.serverTimestamp(), 'readBy': [user!.uid],
        'recipeTitle': widget.recipe.title, 'recipeTime': widget.recipe.time, 'recipeKcal': widget.recipe.kcal, 'imageUrl': widget.recipe.imageUrl, 'description': widget.recipe.description,
        'isVegetarian': widget.recipe.isVegetarian, 'ingredients': widget.recipe.ingredients, 'missingIngredients': widget.recipe.missingIngredients, 'steps': widget.recipe.steps, 'dietLabelKey': widget.dietLabelKey,
      };

      if (isDirect) {
        await FirebaseFirestore.instance.collection('chats').doc(id).collection('messages').add(msg);
        await FirebaseFirestore.instance.collection('chats').doc(id).set({'lastMessage': "${AppText.get('chat_recipe_msg')}: ${widget.recipe.title}", 'lastTimestamp': FieldValue.serverTimestamp(), 'participants': id.split('_')}, SetOptions(merge: true));
      } else {
        await FirebaseFirestore.instance.collection('households').doc(id).collection('messages').add(msg);
      }
      if (mounted) { Navigator.pop(context); SnackbarUtils.showSuccess(context, AppText.get('msg_sent')); }
    } catch (e) { if (mounted) Navigator.pop(context); SnackbarUtils.showError(context, "Error: $e"); }
  }

  String _normalizeUnit(String rawUnit) {
    String u = rawUnit.toLowerCase().trim();
    if (['г', 'g', 'гр', 'gram'].contains(u)) return 'g';
    if (['кг', 'kg', 'kilo'].contains(u)) return 'kg';
    if (['мл', 'ml'].contains(u)) return 'ml';
    if (['л', 'l'].contains(u)) return 'l';
    return 'pcs';
  }

  String _getUnitType(String unit) { if (unit == 'g' || unit == 'kg') return 'weight'; if (unit == 'ml' || unit == 'l') return 'volume'; return 'count'; }
  double _getBaseQty(double qty, String unit) { if (unit == 'kg' || unit == 'l') return qty * 1000; return qty; }
  Map<String, dynamic> _formatQtyAndUnit(double baseQty, String type) {
    if (type == 'weight') { if (baseQty >= 1000) return {'qty': baseQty / 1000, 'unit': 'kg'}; return {'qty': baseQty, 'unit': 'g'}; }
    if (type == 'volume') { if (baseQty >= 1000) return {'qty': baseQty / 1000, 'unit': 'l'}; return {'qty': baseQty, 'unit': 'ml'}; }
    return {'qty': baseQty, 'unit': 'pcs'};
  }

  Future<void> _processItemSaving(String rawItemName, CollectionReference collection) async {
    final parsedData = _parseIngredient(rawItemName);
    final pName = parsedData['name']; final pQty = parsedData['quantity']; final pUnit = parsedData['unit']; final newType = _getUnitType(pUnit);
    final existingQuery = await collection.where('isBought', isEqualTo: false).get();
    QueryDocumentSnapshot? matchDoc;

    for (var doc in existingQuery.docs) {
      final docData = doc.data() as Map<String, dynamic>;
      if (_isSameProduct(docData['name'], pName) && _getUnitType(docData['unit']) == newType) { matchDoc = doc; break; }
    }

    if (matchDoc != null) {
      final matchData = matchDoc.data() as Map<String, dynamic>;
      final baseExt = _getBaseQty((matchData['quantity'] ?? 0.0) as double, matchData['unit'] as String);
      final formatted = _formatQtyAndUnit(baseExt + _getBaseQty(pQty as double, pUnit as String), newType);
      await collection.doc(matchDoc.id).update({'quantity': formatted['qty'], 'unit': formatted['unit']});
    } else {
      final formatted = _formatQtyAndUnit(_getBaseQty(pQty as double, pUnit as String), newType);
      await collection.add({'name': pName, 'quantity': formatted['qty'], 'unit': formatted['unit'], 'isBought': false, 'addedDate': Timestamp.now()});
    }
    setState(() { _addedToCart.add(rawItemName); });
  }

  Future<void> _addToShoppingList(String rawItemName) async {
    if (user == null) return;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      final householdId = userData?['householdId'];
      final collection = householdId != null && householdId.toString().isNotEmpty ? FirebaseFirestore.instance.collection('households').doc(householdId).collection('shopping_list') : FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('shopping_list');
      await _processItemSaving(rawItemName, collection);
      if (mounted) SnackbarUtils.showSuccess(context, "🛒");
    } catch (e) { if (mounted) SnackbarUtils.showError(context, "Error: $e"); }
  }

  Future<void> _addAllToShoppingList() async {
    if (user == null) return;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      final householdId = userData?['householdId'];
      final collection = householdId != null && householdId.toString().isNotEmpty ? FirebaseFirestore.instance.collection('households').doc(householdId).collection('shopping_list') : FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('shopping_list');
      int addedCount = 0;
      for (var rawItem in _dynamicMissingIngredients) { if (!_addedToCart.contains(rawItem)) { await _processItemSaving(rawItem, collection); addedCount++; } }
      if (addedCount > 0 && mounted) SnackbarUtils.showSuccess(context, "🛒");
    } catch (e) { if (mounted) SnackbarUtils.showError(context, "Error: $e"); }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardColor = Theme.of(context).cardColor;

    Color badgeColor = Colors.orange; IconData badgeIcon = Icons.restaurant;
    if (widget.dietLabelKey.contains('veg')) { badgeColor = Colors.green; badgeIcon = Icons.eco; }
    else if (widget.dietLabelKey.contains('keto')) { badgeColor = Colors.purple; badgeIcon = Icons.fitness_center; }
    else if (widget.dietLabelKey.contains('healthy')) { badgeColor = Colors.teal; badgeIcon = Icons.favorite; }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 300.0, pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(widget.recipe.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 10, color: Colors.black)]), textScaler: const TextScaler.linear(0.8)),
                    background: Stack(children: [Image.network(widget.recipe.imageUrl, fit: BoxFit.cover, width: double.infinity, errorBuilder: (c, e, s) => Container(color: Colors.grey, child: const Icon(Icons.restaurant, size: 50))), const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black54])))]),
                  ),
                  actions: [
                    Container(margin: const EdgeInsets.only(right: 8), decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black26), child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: _shareRecipeToChat)),
                    Container(margin: const EdgeInsets.only(right: 10), decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black26), child: IconButton(icon: Icon(_isSaved ? Icons.favorite : Icons.favorite_border, color: _isSaved ? Colors.red : Colors.white, size: 28), onPressed: _toggleSave))
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_InfoItem(icon: Icons.timer, text: widget.recipe.time, color: Colors.blue), _InfoItem(icon: Icons.local_fire_department, text: "${widget.recipe.kcal} ${AppText.get('rec_kcal')}", color: Colors.orange), _InfoItem(icon: badgeIcon, text: AppText.get(widget.dietLabelKey), color: badgeColor)])),
                        const SizedBox(height: 25),
                        Text(widget.recipe.description, style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.grey.shade600)),
                        const SizedBox(height: 25),

                        // ЧЕРВОНИЙ БЛОК: ТРЕБА ДОКУПИТИ
                        if (_dynamicMissingIngredients.isNotEmpty)
                          Container(
                            width: double.infinity, padding: const EdgeInsets.all(20), margin: const EdgeInsets.only(bottom: 25),
                            decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))], border: Border(left: BorderSide(color: Colors.red.shade400, width: 6))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [Icon(Icons.shopping_cart_checkout, color: isDark ? Colors.red.shade300 : Colors.red.shade700), const SizedBox(width: 10), Text(AppText.get('missing_title'), style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.red.shade300 : Colors.red.shade800, fontSize: 18))]),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 10, runSpacing: 10,
                                  children: _dynamicMissingIngredients.map((item) {
                                    final isAdded = _addedToCart.contains(item);
                                    return InkWell(
                                      onTap: isAdded ? null : () => _addToShoppingList(item),
                                      borderRadius: BorderRadius.circular(14),
                                      child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 300), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 80),
                                          decoration: BoxDecoration(color: isAdded ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: isAdded ? Colors.green.shade300 : Colors.red.shade200)),
                                          child: Row(mainAxisSize: MainAxisSize.min, children: [Flexible(child: Text(_translateRawIngredient(item), style: TextStyle(color: isAdded ? (isDark ? Colors.green.shade300 : Colors.green.shade700) : (isDark ? Colors.red.shade300 : Colors.red.shade700), fontWeight: FontWeight.bold, fontSize: 13), softWrap: true)), const SizedBox(width: 8), Icon(isAdded ? Icons.check_circle : Icons.add_shopping_cart, size: 18, color: isAdded ? (isDark ? Colors.green.shade300 : Colors.green.shade700) : (isDark ? Colors.red.shade300 : Colors.red.shade700))])
                                      ),
                                    );
                                  }).toList(),
                                ),
                                if (_dynamicMissingIngredients.length > 1 && _addedToCart.length < _dynamicMissingIngredients.length)
                                  Padding(padding: const EdgeInsets.only(top: 20), child: SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _addAllToShoppingList, icon: const Icon(Icons.playlist_add_check), label: Text(AppText.get('btn_add_all'), style: const TextStyle(fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.red.shade800 : Colors.red.shade50, foregroundColor: isDark ? Colors.white : Colors.red.shade800, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)))))
                              ],
                            ),
                          ),

                        // ЗЕЛЕНИЙ БЛОК: Є У ХОЛОДИЛЬНИКУ
                        Container(
                          width: double.infinity, padding: const EdgeInsets.all(20), margin: const EdgeInsets.only(bottom: 25),
                          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))], border: Border(left: BorderSide(color: Colors.green.shade400, width: 6))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [Icon(Icons.kitchen, color: isDark ? Colors.green.shade300 : Colors.green.shade700), const SizedBox(width: 10), Text(AppText.get('ingredients_fridge'), style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.green.shade300 : Colors.green.shade800, fontSize: 18))]),
                              const SizedBox(height: 16),
                              if (_dynamicAvailableIngredients.isEmpty)
                                Text(AppText.get('list_empty'), style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
                              else
                                Column(children: _dynamicAvailableIngredients.map((ing) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [Icon(Icons.check_circle, color: isDark ? Colors.green.shade400 : Colors.green.shade600, size: 22), const SizedBox(width: 12), Expanded(child: Text(_translateRawIngredient(ing), style: TextStyle(fontSize: 15, color: textColor, fontWeight: FontWeight.w500)))]))).toList()),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),
                        Text(AppText.get('instructions'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
                        const SizedBox(height: 16),

                        if (widget.recipe.steps.isEmpty) const Text("...", style: TextStyle(color: Colors.grey))
                        else Column(children: widget.recipe.steps.asMap().entries.map((entry) => Padding(padding: const EdgeInsets.only(bottom: 24), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 32, height: 32, alignment: Alignment.center, decoration: BoxDecoration(color: Colors.orange.shade100, shape: BoxShape.circle), child: Text("${entry.key + 1}", style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold, fontSize: 15))), const SizedBox(width: 16), Expanded(child: Text(entry.value, style: TextStyle(fontSize: 16, height: 1.6, color: textColor)))]))).toList()),
                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_bannerAd != null && _isBannerLoaded && !SubscriptionService().isPremium) Container(alignment: Alignment.center, width: _bannerAd!.size.width.toDouble(), height: _bannerAd!.size.height.toDouble(), child: AdWidget(ad: _bannerAd!)),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon; final String text; final Color color;
  const _InfoItem({required this.icon, required this.text, required this.color});
  @override Widget build(BuildContext context) { return Column(children: [Icon(icon, color: color, size: 28), const SizedBox(height: 6), Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center)]); }
}