import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import '../translations.dart';
import '../global.dart';

class StatsScreen extends StatelessWidget { // Клас StatsScreen
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<String>(
        valueListenable: languageNotifier,
        builder: (context, lang, child) {
          return Scaffold(
            appBar: AppBar(
                title: Text(AppText.get('stats_title')),
                centerTitle: true,
                backgroundColor: isDark ? null : Colors.green.shade100
            ),
            backgroundColor: isDark ? null : Colors.green.shade50,
            body: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user.uid).collection('history').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs;
                int eaten = 0;
                int wasted = 0;

                for (var doc in docs) {
                  final action = doc['action'];
                  if (action == 'eaten') eaten++;
                  else if (action == 'wasted') wasted++;
                }

                int total = eaten + wasted;
                double efficiency = total == 0 ? 0 : (eaten / total) * 100;

                return Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      // Картка з загальною кількістю
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF43A047), Color(0xFF66BB6A)]),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppText.get('stat_history'), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                            const SizedBox(height: 5),
                            Text("$total", style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                            Text(AppText.get('stat_products'), style: const TextStyle(color: Colors.white, fontSize: 16)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Кругова діаграма
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
                        ),
                        child: Column(
                          children: [
                            Text(AppText.get('stat_efficiency'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : Colors.black)),
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 160,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  PieChart(
                                      PieChartData(
                                          sectionsSpace: 0,
                                          centerSpaceRadius: 55,
                                          startDegreeOffset: -90,
                                          sections: [
                                            PieChartSectionData(value: eaten.toDouble(), color: const Color(0xFF4CAF50), radius: 18, showTitle: false),
                                            PieChartSectionData(value: wasted.toDouble(), color: const Color(0xFFEF5350), radius: 18, showTitle: false)
                                          ]
                                      )
                                  ),
                                  Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text("${efficiency.toInt()}%", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50))),
                                        Text(AppText.get('stat_success'), style: const TextStyle(color: Colors.grey, fontSize: 10))
                                      ]
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Маленькі картки
                      _buildSmallCard(AppText.get('stat_saved'), eaten, const Color(0xFF4CAF50), Icons.restaurant, context),
                      const SizedBox(height: 10),
                      _buildSmallCard(AppText.get('stat_wasted'), wasted, const Color(0xFFEF5350), Icons.delete_outline, context),
                    ],
                  ),
                );
              },
            ),
          );
        }
    );
  }

  Widget _buildSmallCard(String title, int count, Color color, IconData icon, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
                children: [
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color)),
                  const SizedBox(width: 15),
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black))
                ]
            ),
            Text("$count", style: TextStyle(fontSize: 20, color: color, fontWeight: FontWeight.bold))
          ]
      ),
    );
  }
}