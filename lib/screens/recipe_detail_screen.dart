import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../recipe_model.dart';
import '../translations.dart';
import '../utils/snackbar_utils.dart';
import '../secrets.dart';
import '../subscription_service.dart';
import '../ad_service.dart'; // ✅ НЕ ЗАБУДЬ ЦЕЙ ІМПОРТ

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;
  final String dietLabelKey;

  const RecipeDetailScreen({
    super.key,
    required this.recipe,
    required this.dietLabelKey
  });

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  bool _isSaved = false;
  final user = FirebaseAuth.instance.currentUser;

  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  @override
  void initState() {
    super.initState();
    _checkIfSaved();
    if (!SubscriptionService().isPremium) {
      _loadBannerAd();
    }
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      // 🔥 ВИПРАВЛЕНО ТУТ
      adUnitId: AdService().bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _isBannerLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('❌ Recipe Banner failed: $error');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _checkIfSaved() async {
    if (user == null) return;
    final docId = widget.recipe.title.hashCode.toString();
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('saved_recipes')
        .doc(docId)
        .get();

    if (mounted) {
      setState(() {
        _isSaved = doc.exists;
      });
    }
  }

  Future<void> _toggleSave() async {
    if (user == null) return;
    final docId = widget.recipe.title.hashCode.toString();
    final collection = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('saved_recipes');

    if (_isSaved) {
      await collection.doc(docId).delete();
      if (mounted) {
        setState(() => _isSaved = false);
        SnackbarUtils.showWarning(context, AppText.get('msg_recipe_removed'));
      }
    } else {
      final recipeMap = {
        'title': widget.recipe.title,
        'description': widget.recipe.description,
        'time': widget.recipe.time,
        'kcal': widget.recipe.kcal,
        'imageUrl': widget.recipe.imageUrl,
        'isVegetarian': widget.recipe.isVegetarian,
        'ingredients': widget.recipe.ingredients,
        'steps': widget.recipe.steps,
        'missingIngredients': widget.recipe.missingIngredients,
        'dietLabelKey': widget.dietLabelKey,
        'savedAt': Timestamp.now(),
      };

      await collection.doc(docId).set(recipeMap);
      if (mounted) {
        setState(() => _isSaved = true);
        SnackbarUtils.showSuccess(context, AppText.get('msg_recipe_saved'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final cardColor = Theme.of(context).cardColor;

    Color badgeColor = Colors.orange;
    IconData badgeIcon = Icons.restaurant;

    if (widget.dietLabelKey.contains('veg')) {
      badgeColor = Colors.green;
      badgeIcon = Icons.eco;
    } else if (widget.dietLabelKey.contains('keto')) {
      badgeColor = Colors.purple;
      badgeIcon = Icons.fitness_center;
    } else if (widget.dietLabelKey.contains('healthy')) {
      badgeColor = Colors.teal;
      badgeIcon = Icons.favorite;
    }

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 300.0,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      widget.recipe.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                      ),
                      textScaler: const TextScaler.linear(0.8),
                    ),
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          widget.recipe.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                              color: Colors.grey,
                              child: const Icon(Icons.restaurant, size: 50)
                          ),
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black54],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    Container(
                      margin: const EdgeInsets.only(right: 10),
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black26
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isSaved ? Icons.favorite : Icons.favorite_border,
                          color: _isSaved ? Colors.red : Colors.white,
                          size: 28,
                        ),
                        onPressed: _toggleSave,
                      ),
                    )
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 8)
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _InfoItem(
                                  icon: Icons.timer,
                                  text: widget.recipe.time,
                                  color: Colors.blue
                              ),
                              _InfoItem(
                                  icon: Icons.local_fire_department,
                                  text: "${widget.recipe.kcal} ${AppText.get('rec_kcal')}",
                                  color: Colors.orange
                              ),
                              _InfoItem(
                                icon: badgeIcon,
                                text: AppText.get(widget.dietLabelKey),
                                color: badgeColor,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 25),
                        Text(
                          widget.recipe.description,
                          style: TextStyle(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey[600]
                          ),
                        ),
                        const SizedBox(height: 25),
                        if (widget.recipe.missingIngredients.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 25),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.red.withOpacity(0.15) : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: isDark ? Colors.red.shade900 : Colors.red.shade100,
                                  width: 1.5
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                        Icons.shopping_cart_checkout,
                                        color: isDark ? Colors.red.shade300 : Colors.red.shade700
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      AppText.get('missing_title'),
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                                          fontSize: 18
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: widget.recipe.missingIngredients.map((item) => Chip(
                                    label: Text(
                                        item,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13
                                        )
                                    ),
                                    backgroundColor: Colors.red.shade400,
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    side: BorderSide.none,
                                  )).toList(),
                                ),
                              ],
                            ),
                          ),
                        Text(
                          AppText.get('ingredients_title'),
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: textColor
                          ),
                        ),
                        const SizedBox(height: 10),
                        Column(
                          children: widget.recipe.ingredients.map((ing) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green.shade600),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Text(
                                        ing,
                                        style: TextStyle(fontSize: 16, color: textColor)
                                    )
                                ),
                              ],
                            ),
                          )).toList(),
                        ),
                        const SizedBox(height: 30),
                        Text(
                          AppText.get('recipe_steps'),
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: textColor
                          ),
                        ),
                        const SizedBox(height: 15),
                        if (widget.recipe.steps.isEmpty)
                          const Text(
                              "No steps provided.",
                              style: TextStyle(color: Colors.grey)
                          )
                        else
                          Column(
                            children: widget.recipe.steps.asMap().entries.map((entry) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 30,
                                      height: 30,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                          color: Colors.orange.shade100,
                                          shape: BoxShape.circle
                                      ),
                                      child: Text(
                                        "${entry.key + 1}",
                                        style: TextStyle(
                                            color: Colors.orange.shade900,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Text(
                                        entry.value,
                                        style: TextStyle(
                                            fontSize: 16,
                                            height: 1.5,
                                            color: textColor
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_bannerAd != null && _isBannerLoaded && !SubscriptionService().isPremium)
            Container(
              alignment: Alignment.center,
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoItem({
    required this.icon,
    required this.text,
    required this.color
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}