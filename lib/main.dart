import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const RetroBudgetApp());

/// ===== ТЕМА + ОБГОРТКА ===================================================
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
          secondary: const Color(0xFF8FB8C0),
        ),
        appBarTheme: base.appBarTheme.copyWith(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          titleTextStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFFFC94A),
          foregroundColor: Colors.black,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const HomePage(),
    );
  }
}

/// ===== МОДЕЛЬ =============================================================
class Expense {
  final String id;
  final String category;
  final String title;
  final double amount;
  final DateTime date;

  Expense({
    required this.id,
    required this.category,
    required this.title,
    required this.amount,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'title': title,
        'amount': amount,
        'date': date.toIso8601String(),
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        category: json['category'] as String,
        title: json['title'] as String,
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.parse(json['date'] as String),
      );
}

/// ===== СХОВИЩЕ (SharedPreferences) =======================================
class ExpenseStorage {
  static const _kKey = 'expenses';
  static const _kLimitKey = 'monthly_limit';

  Future<List<Expense>> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kKey);
    if (raw == null || raw.isEmpty) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(Expense.fromJson).toList();
  }

  Future<void> save(List<Expense> items) async {
    final sp = await SharedPreferences.getInstance();
    final raw = jsonEncode(items.map((e) => e.toJson()).toList());
    await sp.setString(_kKey, raw);
  }

  Future<double> getMonthlyLimit() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getDouble(_kLimitKey) ?? 0.0;
  }

  Future<void> setMonthlyLimit(double value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setDouble(_kLimitKey, value);
  }
}

/// ===== ДОПОМОЖНІ ==========================================================
String fmtCurrency(double v) =>
    NumberFormat.currency(locale: 'uk_UA', symbol: '₴').format(v);

String fmtDate(DateTime d) => DateFormat('dd.MM.yyyy').format(d);

Map<String, double> sumByCategory(List<Expense> items, DateTime month) {
  final map = <String, double>{};
  for (final e in items) {
    if (e.date.year == month.year && e.date.month == month.month) {
      map.update(e.category, (v) => v + e.amount, ifAbsent: () => e.amount);
    }
  }
  return map;
}

/// ===== ГОЛОВНА СТОРІНКА ===================================================
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final storage = ExpenseStorage();
  List<Expense> _data = [];
  String _query = '';
  DateTime _selectedMonth = DateTime.now();
  double _monthlyLimit = 0.0;

  // Категорії (можеш редагувати)
  final List<String> categories = const [
    'Продукти',
    'Транспорт',
    'Житло',
    'Одяг',
    'Розваги',
    'Медицина',
    'Інше',
  ];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final loaded = await storage.load();
    final limit = await storage.getMonthlyLimit();
    setState(() {
      _data = loaded;
      _monthlyLimit = limit;
    });
  }

  Future<void> _persist() async {
    await storage.save(_data);
    setState(() {});
  }

  double get _sumThisMonth {
    return _data
        .where((e) =>
            e.date.year == _selectedMonth.year &&
            e.date.month == _selectedMonth.month)
        .fold(0.0, (p, e) => p + e.amount);
  }

  List<Expense> get _filtered {
    final lower = _query.toLowerCase();
    return _data.where((e) {
      final inMonth = e.date.year == _selectedMonth.year &&
          e.date.month == _selectedMonth.month;
      if (!inMonth) return false;
      return e.title.toLowerCase().contains(lower) ||
          e.category.toLowerCase().contains(lower);
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> _addOrEdit([Expense? initial]) async {
    final result = await showDialog<Expense>(
      context: context,
      builder: (ctx) =>
          AddEditDialog(categories: categories, initial: initial),
    );
    if (result == null) return;
    if (initial == null) {
      _data.add(result);
    } else {
      final i = _data.indexWhere((e) => e.id == initial.id);
      if (i != -1) _data[i] = result;
    }
    await _persist();
  }

  Future<void> _delete(Expense e) async {
    _data.removeWhere((x) => x.id == e.id);
    await _persist();
  }

  Future<void> _exportCsv() async {
    // Готуємо CSV
    final rows = <List<String>>[
      ['id', 'date', 'category', 'title', 'amount'],
      ..._filtered.map((e) => [
            e.id,
            e.date.toIso8601String(),
            e.category,
            e.title,
            e.amount.toStringAsFixed(2),
          ])
    ];
    final csv = rows.map((r) => r.join(',')).join('\n');

    // Пишемо файл у Documents/ (app)
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/retro_budget_${DateFormat('yyyyMM').format(_selectedMonth)}.csv');
    await file.writeAsString(csv);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('CSV збережено: ${file.path}')),
    );
  }

  Future<void> _setLimit() async {
    final controller =
        TextEditingController(text: _monthlyLimit == 0 ? '' : '$_monthlyLimit');
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Місячний ліміт'),
        content: TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            hintText: 'Напр., 10000',
            labelText: 'Сума в ₴',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Скасувати')),
          FilledButton(
            onPressed: () {
              final d = double.tryParse(controller.text.replaceAll(',', '.'));
              Navigator.pop(ctx, d);
            },
            child: const Text('Зберегти'),
          ),
        ],
      ),
    );
    if (v == null) return;
    _monthlyLimit = v.isNaN ? 0.0 : v;
    await storage.setMonthlyLimit(_monthlyLimit);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final byCat = sumByCategory(_data, _selectedMonth);
    final over = _monthlyLimit > 0 && _sumThisMonth > _monthlyLimit;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ретро-бюджет'),
        actions: [
          IconButton(
            tooltip: 'Експорт у CSV',
            onPressed: _filtered.isEmpty ? null : _exportCsv,
            icon: const Icon(Icons.download),
          ),
          IconButton(
            tooltip: 'Ліміт місяця',
            onPressed: _setLimit,
            icon: const Icon(Icons.flag),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    cursorColor: Colors.white,
                    decoration: const InputDecoration(
                      hintText: 'Пошук (назва або категорія)',
                      isDense: true,
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    final curr = DateTime(_selectedMonth.year, _selectedMonth.month);
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020, 1),
                      lastDate: DateTime(2100, 12),
                      helpText: 'Оберіть будь-яку дату потрібного місяця',
                    );
                    if (picked != null) {
                      setState(() => _selectedMonth =
                          DateTime(picked.year, picked.month));
                    } else {
                      setState(() => _selectedMonth = curr);
                    }
                  },
                  icon: const Icon(Icons.calendar_month),
                  label: Text(DateFormat('LLLL yyyy', 'uk_UA')
                      .format(_selectedMonth)),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEdit(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          if (_monthlyLimit > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: over ? Colors.red.shade700 : Colors.green.shade700,
              child: Text(
                'Місячний ліміт: ${fmtCurrency(_monthlyLimit)}  •  Витрачено: ${fmtCurrency(_sumThisMonth)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          // «Діаграма»: смуги за категоріями
          if (byCat.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: _CategoryBars(data: byCat),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _filtered.isEmpty
                ? const Center(child: Text('Немає витрат за цей місяць'))
                : ListView.separated(
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: Colors.white12),
                    itemBuilder: (ctx, i) {
                      final e = _filtered[i];
                      return Dismissible(
                        key: ValueKey(e.id),
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 16),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        secondaryBackground: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child:
                              const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _delete(e),
                        child: ListTile(
                          title: Text(e.title),
                          subtitle: Text('${e.category} • ${fmtDate(e.date)}'),
                          trailing: Text(
                            fmtCurrency(e.amount),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700),
                          ),
                          onTap: () => _addOrEdit(e),
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

/// ===== СМУГОВА «ДІАГРАМА» КАТЕГОРІЙ ======================================
class _CategoryBars extends StatelessWidget {
  final Map<String, double> data;
  const _CategoryBars({required this.data});

  @override
  Widget build(BuildContext context) {
    final total = data.values.fold<double>(0, (p, e) => p + e);
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Витрати за категоріями',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ...entries.map((e) {
          final p = total == 0 ? 0.0 : (e.value / total);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: p.clamp(0.0, 1.0),
                        child: Container(
                          height: 16,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFC94A),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: Text(
                    fmtCurrency(e.value),
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

/// ===== ДІАЛОГ ДОДАТИ / РЕДАГУВАТИ ========================================
class AddEditDialog extends StatefulWidget {
  final List<String> categories;
  final Expense? initial;
  const AddEditDialog({super.key, required this.categories, this.initial});

  @override
  State<AddEditDialog> createState() => _AddEditDialogState();
}

class _AddEditDialogState extends State<AddEditDialog> {
  late final TextEditingController _title =
      TextEditingController(text: widget.initial?.title ?? '');
  late final TextEditingController _amount =
      TextEditingController(text: widget.initial?.amount.toString() ?? '');
  late DateTime _date = widget.initial?.date ?? DateTime.now();
  String? _category;

  @override
  void initState() {
    super.initState();
    _category = widget.initial?.category ?? widget.categories.first;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Нова витрата' : 'Редагувати'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _category,
              items: widget.categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v),
              decoration: const InputDecoration(labelText: 'Категорія'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Назва'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Сума, ₴'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    child: Text('Дата: ${fmtDate(_date)}',
                        style: const TextStyle(fontWeight: FontWeight.w600))),
                TextButton.icon(
                  icon: const Icon(Icons.date_range),
                  label: const Text('Змінити'),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020, 1),
                      lastDate: DateTime(2100, 12),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Скасувати')),
        FilledButton(
          onPressed: () {
            final title = _title.text.trim();
            final amount =
                double.tryParse(_amount.text.replaceAll(',', '.')) ?? -1;
            if (title.isEmpty || amount <= 0 || _category == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Заповни правильні дані')),
              );
              return;
            }
            final e = Expense(
              id: widget.initial?.id ?? UniqueKey().toString(),
              category: _category!,
              title: title,
              amount: amount,
              date: _date,
            );
            Navigator.pop(context, e);
          },
          child: const Text('Зберегти'),
        ),
      ],
    );
  }
}
