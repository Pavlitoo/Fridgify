import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'translations.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final user = FirebaseAuth.instance.currentUser!;
  int touchedIndex = -1; // To track which section is touched

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Light grey-blue background
      appBar: AppBar(
        title: Text(AppText.get('stats_title'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).collection('history').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          int eatenCount = 0;
          int wastedCount = 0;

          // Calculate data
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['action'] == 'eaten') eatenCount++;
            if (data['action'] == 'wasted') wastedCount++;
          }

          int total = eatenCount + wastedCount;

          if (total == 0) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text("No data yet", style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // --- HEADER CARD ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.green.shade200, blurRadius: 10, offset: const Offset(0, 5))],
                    ),
                    child: Column(
                      children: [
                        Text(AppText.get('stats_desc'), style: const TextStyle(color: Colors.white70, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text("$total ${AppText.get('st_products')}", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)), // 🆕 Translated
                        Text(AppText.get('st_history'), style: const TextStyle(color: Colors.white, fontSize: 14)), // 🆕 Translated
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- CHART CARD ---
                  Container(
                    height: 400,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 15, offset: const Offset(0, 5))],
                    ),
                    child: Column(
                      children: [
                        Text(AppText.get('st_efficiency'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), // 🆕 Translated
                        const SizedBox(height: 30),

                        // CHART
                        Expanded(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              PieChart(
                                PieChartData(
                                  pieTouchData: PieTouchData(
                                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                      setState(() {
                                        if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                                          touchedIndex = -1;
                                          return;
                                        }
                                        touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                      });
                                    },
                                  ),
                                  borderData: FlBorderData(show: false),
                                  sectionsSpace: 0,
                                  centerSpaceRadius: 60,
                                  sections: showingSections(eatenCount, wastedCount, total),
                                ),
                              ),
                              // Center Text
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    touchedIndex == 0 ? "${((eatenCount/total)*100).toStringAsFixed(0)}%" :
                                    touchedIndex == 1 ? "${((wastedCount/total)*100).toStringAsFixed(0)}%" :
                                    AppText.get('st_rate'), // 🆕 Translated
                                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                                  ),
                                  Text(
                                    touchedIndex == 0 ? AppText.get('st_saved') : // 🆕 Translated
                                    touchedIndex == 1 ? AppText.get('st_lost') : // 🆕 Translated
                                    AppText.get('st_select'), // 🆕 Translated
                                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),

                        // LEGEND
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _Indicator(
                              color: const Color(0xFF4CAF50), // Nice Green
                              text: "${AppText.get('eaten')} 😋",
                              isSquare: false,
                              size: touchedIndex == 0 ? 18 : 16,
                              textColor: touchedIndex == 0 ? Colors.black : Colors.grey,
                            ),
                            _Indicator(
                              color: const Color(0xFFEF5350), // Nice Red
                              text: "${AppText.get('wasted')} 🗑️",
                              isSquare: false,
                              size: touchedIndex == 1 ? 18 : 16,
                              textColor: touchedIndex == 1 ? Colors.black : Colors.grey,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Generate sections for the chart
  List<PieChartSectionData> showingSections(int eaten, int wasted, int total) {
    return List.generate(2, (i) {
      final isTouched = i == touchedIndex;
      final fontSize = isTouched ? 20.0 : 14.0;
      final radius = isTouched ? 70.0 : 60.0;
      const shadows = [Shadow(color: Colors.black12, blurRadius: 2)];

      switch (i) {
        case 0: // Eaten
          return PieChartSectionData(
            color: const Color(0xFF4CAF50),
            value: eaten.toDouble(),
            title: '${((eaten/total)*100).toStringAsFixed(0)}%',
            radius: radius,
            titleStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.white, shadows: shadows),
          );
        case 1: // Wasted
          return PieChartSectionData(
            color: const Color(0xFFEF5350),
            value: wasted.toDouble(),
            title: '${((wasted/total)*100).toStringAsFixed(0)}%',
            radius: radius,
            titleStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.white, shadows: shadows),
          );
        default:
          throw Error();
      }
    });
  }
}

// Custom Widget for Legend
class _Indicator extends StatelessWidget {
  final Color color;
  final String text;
  final bool isSquare;
  final double size;
  final Color? textColor;

  const _Indicator({
    required this.color,
    required this.text,
    required this.isSquare,
    this.size = 16,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: isSquare ? BoxShape.rectangle : BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
        )
      ],
    );
  }
}