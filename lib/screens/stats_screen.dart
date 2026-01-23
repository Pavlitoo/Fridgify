import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../translations.dart';
import '../error_handler.dart'; // 👇 Імпорт обробника помилок

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final user = FirebaseAuth.instance.currentUser!;
  int _touchedIndex = -1;
  String _timeFilter = 'all'; // 'week', 'month', 'all'

  Future<void> _fixGhostFamily() async {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'householdId': FieldValue.delete(),
    });
    if (mounted) setState(() {});
  }

  List<QueryDocumentSnapshot> _filterDocs(List<QueryDocumentSnapshot> docs) {
    if (_timeFilter == 'all') return docs;

    final now = DateTime.now();
    final limitDate = _timeFilter == 'week'
        ? now.subtract(const Duration(days: 7))
        : DateTime(now.year, now.month, 1);

    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['date'] == null) return false;
      final date = (data['date'] as Timestamp).toDate();
      return date.isAfter(limitDate);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(AppText.get('stats_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('history')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {

          // 🔥 ВИКОРИСТАННЯ ERROR HANDLER
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 60),
                    const SizedBox(height: 10),
                    Text(
                      ErrorHandler.getMessage(snapshot.error!), // Переклад помилки
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textColor, fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    TextButton(onPressed: _fixGhostFamily, child: const Text("Fix / Refresh"))
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final allDocs = snapshot.data!.docs;
          final filteredDocs = _filterDocs(allDocs);

          int eaten = 0;
          int wasted = 0;
          for (var doc in filteredDocs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['action'] == 'eaten') eaten++;
            if (data['action'] == 'wasted') wasted++;
          }
          int total = eaten + wasted;
          double successRate = total == 0 ? 0 : (eaten / total) * 100;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              children: [
                // Фільтр
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      _buildFilterBtn(AppText.get('stat_filter_week'), 'week'),
                      _buildFilterBtn(AppText.get('stat_filter_month'), 'month'),
                      _buildFilterBtn(AppText.get('stat_filter_all'), 'all'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Еко-Рейтинг
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: successRate >= 80
                          ? [const Color(0xFF4CAF50), const Color(0xFF81C784)]
                          : (successRate >= 50
                          ? [const Color(0xFFFFA726), const Color(0xFFFFCC80)]
                          : [const Color(0xFFEF5350), const Color(0xFFE57373)]),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
                  ),
                  child: Column(
                    children: [
                      Text(AppText.get('stat_eco_rating'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Text("${successRate.toStringAsFixed(0)}%", style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Text(
                        successRate >= 80
                            ? AppText.get('stat_great')
                            : (successRate >= 50 ? AppText.get('stat_average') : AppText.get('stat_bad')),
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // KPI
                Row(
                  children: [
                    Expanded(child: _buildKpiCard(AppText.get('stat_total'), "$total", Icons.receipt_long, Colors.blue, cardColor, textColor)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildKpiCard(AppText.get('stat_saved'), "$eaten", Icons.thumb_up, Colors.green, cardColor, textColor)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildKpiCard(AppText.get('stat_wasted'), "$wasted", Icons.delete_outline, Colors.red, cardColor, textColor)),
                  ],
                ),

                const SizedBox(height: 30),

                // Діаграма
                if (total > 0)
                  SizedBox(
                    height: 250,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            pieTouchData: PieTouchData(
                              touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                setState(() {
                                  if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                                    _touchedIndex = -1;
                                    return;
                                  }
                                  _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                });
                              },
                            ),
                            borderData: FlBorderData(show: false),
                            sectionsSpace: 4,
                            centerSpaceRadius: 50,
                            sections: [
                              PieChartSectionData(
                                color: const Color(0xFF4CAF50),
                                value: eaten.toDouble(),
                                title: '${((eaten / total) * 100).toStringAsFixed(0)}%',
                                radius: _touchedIndex == 0 ? 65 : 55,
                                titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              PieChartSectionData(
                                color: const Color(0xFFEF5350),
                                value: wasted.toDouble(),
                                title: '${((wasted / total) * 100).toStringAsFixed(0)}%',
                                radius: _touchedIndex == 1 ? 65 : 55,
                                titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(AppText.get('stat_total'), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                            Text("$total", style: TextStyle(color: textColor, fontSize: 28, fontWeight: FontWeight.bold)),
                          ],
                        )
                      ],
                    ),
                  )
                else
                  Container(
                    height: 200,
                    alignment: Alignment.center,
                    child: Text(AppText.get('stat_no_data'), style: TextStyle(color: Colors.grey.shade500)),
                  ),

                const SizedBox(height: 30),

                // Історія
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(AppText.get('stat_history'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                ),
                const SizedBox(height: 10),

                if (filteredDocs.isEmpty)
                  Padding(padding: const EdgeInsets.all(20), child: Text(AppText.get('stat_empty_history'), style: TextStyle(color: Colors.grey.shade500))),

                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredDocs.length > 20 ? 20 : filteredDocs.length,
                  itemBuilder: (ctx, i) {
                    final data = filteredDocs[i].data() as Map<String, dynamic>;
                    bool isSaved = data['action'] == 'eaten';
                    final date = (data['date'] as Timestamp).toDate();
                    final dateStr = DateFormat('dd MMM, HH:mm').format(date);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)],
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSaved ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                          child: Icon(isSaved ? Icons.check : Icons.delete, color: isSaved ? Colors.green : Colors.red, size: 20),
                        ),
                        title: Text(data['product'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        trailing: Text(
                          isSaved ? "+1" : "-1",
                          style: TextStyle(color: isSaved ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterBtn(String title, String value) {
    bool isSelected = _timeFilter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _timeFilter = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)] : [],
          ),
          child: Text(title, style: TextStyle(color: isSelected ? Colors.black : Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color, Color cardColor, Color? textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade500), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}