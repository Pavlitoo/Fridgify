import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../recipe_model.dart';
import '../translations.dart';
import '../secrets.dart';
import '../subscription_service.dart';
import '../ad_service.dart'; // ✅ НЕ ЗАБУДЬ ЦЕЙ ІМПОРТ
import 'recipe_detail_screen.dart';

class SavedRecipesScreen extends StatefulWidget {
  const SavedRecipesScreen({super.key});

  @override
  State<SavedRecipesScreen> createState() => _SavedRecipesScreenState();
}

class _SavedRecipesScreenState extends State<SavedRecipesScreen> {
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  @override
  void initState() {
    super.initState();
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
          debugPrint('❌ Saved Recipes Banner failed: $error');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    if (user == null) return const Scaffold(body: Center(child: Text("Error: No User")));

    return Scaffold(
      appBar: AppBar(
        title: Text(AppText.get('saved_title')),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        foregroundColor: textColor,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('saved_recipes')
                  .orderBy('savedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.favorite_border, size: 80, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          AppText.get('saved_empty'),
                          style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;

                    final recipe = Recipe(
                      title: data['title'] ?? '',
                      description: data['description'] ?? '',
                      time: data['time'] ?? '',
                      kcal: data['kcal'] ?? '',
                      imageUrl: data['imageUrl'] ?? '',
                      isVegetarian: data['isVegetarian'] ?? false,
                      ingredients: List<String>.from(data['ingredients'] ?? []),
                      steps: List<String>.from(data['steps'] ?? []),
                      missingIngredients: List<String>.from(data['missingIngredients'] ?? []),
                    );

                    final dietLabelKey = data['dietLabelKey'] ?? 'tag_standard';

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => RecipeDetailScreen(
                                    recipe: recipe,
                                    dietLabelKey: dietLabelKey
                                )
                            )
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                          ],
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                              child: Image.network(
                                recipe.imageUrl,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                errorBuilder: (c,e,s) => Container(width: 100, height: 100, color: Colors.grey, child: const Icon(Icons.restaurant)),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      recipe.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(Icons.timer, size: 14, color: Colors.grey[600]),
                                        const SizedBox(width: 4),
                                        Text(recipe.time, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                        const SizedBox(width: 12),
                                        Icon(Icons.local_fire_department, size: 14, color: Colors.orange),
                                        const SizedBox(width: 4),
                                        Text("${recipe.kcal} kcal", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 16.0),
                              child: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
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