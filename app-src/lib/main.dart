import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';

void main() => runApp(const RetroBudgetApp());

class RetroBudgetApp extends StatelessWidget {
  const RetroBudgetApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark(useMaterial3: true);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ретро-бюджет',
      theme: base.copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0E17),
        colorScheme: base.colorScheme.copyWith(
          primary: const Color(0xFFFFC94A),
          secondary: const Color(0xFF5B8CFF),
        ),
        appBarTheme: base.appBarTheme.copyWith(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          titleTextStyle: const TextStyle(
            fontWeight: FontWeight.w700, fontSize: 20, color: Colors.white),
        ),
        floatingActionButtonTheme:
            const FloatingActionButtonThemeData(backgroundColor: Color(0xFFFFC94A)),
      ),
      home: const HomePage(),
    );
  }
}

class Expense {
  final String title;
  final double amount;
  final String category; // можна "Інше" за замовчуванням
  Expense({required this.title, required this.amount, this.category = 'Інше'});

  Map<String, dynamic> toJson() =>
      {'t': title, 'a': amount, 'c': category};
  factory Expense.fromJson(Map<String, dynamic> m) =>
      Expense(title: m['t'], amount: (m['a'] as num).toDouble(), category: m['c'] ?? 'Інше');
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Expense> items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString('expenses') ?? '[]';
    final list = (jsonDecode(raw) as List).cast<Map>().map((e) => Expense.fromJson(e.cast<String, dynamic>())).toList();
    setState(() {
      items = list;
      loading = false;
    });
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('expenses', jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  Future<void> _addExpense() async {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final categoryCtrl = TextEditingController(text: 'Інше');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новий витрата'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Назва')),
            TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Сума')),
            TextField(controller: categoryCtrl, decoration: const InputDecoration(labelText: 'Категорія')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Відміна')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Додати')),
        ],
      ),
    );

    if (ok == true) {
      final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0;
      if (amount > 0 && titleCtrl.text.trim().isNotEmpty) {
        setState(() => items.add(Expense(title: titleCtrl.text.trim(), amount: amount, category: categoryCtrl.text.trim())));
        await _save();
      }
    }
  }

  void _removeAt(int index) async {
    setState(() => items.removeAt(index));
    await _save();
  }

  Map<String, double> get _byCategory {
    final map = <String, double>{};
    for (final e in items) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final total = items.fold<double>(0, (s, e) => s + e.amount);

    return Scaffold(
      appBar: AppBar(
        title: Text('Ретро-бюджет • ${total.toStringAsFixed(2)}'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addExpense,
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Кругова діаграма
                if (_byCategory.isNotEmpty)
                  SizedBox(
                    height: 220,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 32,
                        sections: _byCategory.entries.map((e) {
                          final value = total == 0 ? 0 : (e.value / total) * 100;
                          return PieChartSectionData(
                            title: '${e.key}\n${value.toStringAsFixed(0)}%',
                            value: e.value,
                            radius: 70,
                            titleStyle: const TextStyle(color: Colors.white, fontSize: 12),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                const Divider(height: 1),
                // Список витрат
                Expanded(
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final e = items[i];
                      return Dismissible(
                        key: ValueKey('${e.title}-$i'),
                        background: Container(color: Colors.red),
                        onDismissed: (_) => _removeAt(i),
                        child: ListTile(
                          title: Text(e.title),
                          subtitle: Text(e.category),
                          trailing: Text(e.amount.toStringAsFixed(2)),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
