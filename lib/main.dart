import 'package:flutter/material.dart';

void main() => runApp(const RetroBudgetApp());

/// ====== ТЕМА + ОБГОРТКА =====================================================
class RetroBudgetApp extends StatelessWidget {
  const RetroBudgetApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark(useMaterial3: true);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ретро-бюджет',
      theme: base.copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F1E17),
        colorScheme: base.colorScheme.copyWith(
          primary: const Color(0xFFFFC94A),
          secondary: const Color(0xFFB8C0AA),
        ),
        appBarTheme: base.appBarTheme.copyWith(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          titleTextStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFFFC94A),
          foregroundColor: Colors.black,
          shape: StadiumBorder(),
        ),
        cardTheme: const CardTheme(
          color: Color(0xFF122019),
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF16261E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

/// ====== МОДЕЛІ ==============================================================
class Expense {
  Expense({
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
  });

  final String title;
  final double amount;
  final String category;
  final DateTime date;
}

/// ====== ГОЛОВНИЙ ЕКРАН ======================================================
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Expense> _items = [];

  double get _total =>
      _items.isEmpty ? 0 : _items.map((e) => e.amount).reduce((a, b) => a + b);

  Map<String, double> get _byCategory {
    final map = <String, double>{};
    for (final e in _items) {
      map.update(e.category, (v) => v + e.amount, ifAbsent: () => e.amount);
    }
    return map;
  }

  Future<void> _openAddDialog() async {
    final newItem = await showDialog<Expense>(
      context: context,
      builder: (ctx) => const _AddExpenseDialog(),
    );
    if (newItem != null) {
      setState(() => _items.add(newItem));
    }
  }

  void _removeAt(int index) {
    setState(() => _items.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Розподіл коштів'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('Додати'),
      ),
      body: Column(
        children: [
          // Баланс
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF122019),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Баланс (сума витрат)',
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Text(
                    '${_total.toStringAsFixed(2)} ₴',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  if (_items.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _byCategory.entries.map((e) {
                        final pct = (_total == 0)
                            ? 0
                            : ((e.value / _total) * 100).round();
                        return Chip(
                          label: Text('${e.key}: ${e.value.toStringAsFixed(0)} ₴ · $pct%'),
                          backgroundColor: cs.secondary.withOpacity(.15),
                          labelStyle: const TextStyle(color: Colors.white),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Список
          Expanded(
            child: _items.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (ctx, i) {
                      final e = _items[i];
                      return Dismissible(
                        key: ValueKey('${e.title}-${e.date.millisecondsSinceEpoch}'),
                        background: Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(.85),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => _removeAt(i),
                        child: Card(
                          child: ListTile(
                            title: Text(
                              e.title,
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${e.category} • ${_fmtDate(e.date)}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            trailing: Text(
                              '-${e.amount.toStringAsFixed(2)} ₴',
                              style: TextStyle(
                                color: Colors.red.shade300,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
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

/// ====== ДІАЛОГ ДОДАВАННЯ =====================================================
class _AddExpenseDialog extends StatefulWidget {
  const _AddExpenseDialog();

  @override
  State<_AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<_AddExpenseDialog> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  DateTime _date = DateTime.now();
  String _category = 'Їжа';

  final _cats = const ['Їжа', 'Транспорт', 'Дім', 'Одяг', 'Здоровʼя', 'Інше'];

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      initialDate: _date,
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    final t = _title.text.trim();
    final a = double.tryParse(_amount.text.replaceAll(',', '.')) ?? -1;
    if (t.isEmpty || a <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Перевір назву та суму')),
      );
      return;
    }
    Navigator.of(context).pop(
      Expense(title: t, amount: a, category: _category, date: _date),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Додати витрату'),
      backgroundColor: const Color(0xFF0F1E17),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Назва (напр. “Хліб”)',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Сума, ₴',
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Категорія'),
              items: _cats
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Дата: ${_fmtDate(_date)}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('Змінити'),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: Navigator.of(context).pop,
          child: const Text('Скасувати'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Зберегти'),
        ),
      ],
    );
  }
}

/// ====== ПУСТИЙ СТАН ==========================================================
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Opacity(
        opacity: .7,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.receipt_long, size: 56, color: Colors.white70),
            SizedBox(height: 8),
            Text('Ще немає витрат.\nНатисни “Додати”.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

/// ====== ДОПОМІЖНЕ ===========================================================
String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
