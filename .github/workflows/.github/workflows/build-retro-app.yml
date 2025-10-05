name: Build Retro Budget (debug, ready app)

on:
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      # 1) Отримати репозиторій (обов'язково)
      - name: Checkout
        uses: actions/checkout@v4

      # 2) Java 17
      - name: Setup Java
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'

      # 3) Flutter
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'

      # 4) Створити мінімальний проєкт Android
      - name: Create Flutter project
        run: |
          flutter create . --platforms=android --project-name retro_budget --org com.rb.unique12

      # 5) Додати залежності, які потрібні додатку
      - name: Add dependencies
        run: |
          flutter pub add shared_preferences

      # 6) Покласти наш готовий додаток у lib/main.dart
      - name: Inject app code
        shell: bash
        run: |
          cat > lib/main.dart <<'EOF'
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
          secondary: const Color(0xFFFB5B47),
        ),
        appBarTheme: base.appBarTheme.copyWith(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          titleTextStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFFFC94A),
          foregroundColor: Colors.black,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF1B2A24),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF324139)),
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        cardTheme: const CardTheme(
          color: Color(0xFF15231D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

/// ====== МОДЕЛІ ===============================================================
class Expense {
  final String category;
  final double amount;
  final DateTime date;
  final String note;

  Expense({
    required this.category,
    required this.amount,
    required this.date,
    required this.note,
  });

  Map<String, dynamic> toJson() => {
        'category': category,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        category: j['category'] as String,
        amount: (j['amount'] as num).toDouble(),
        date: DateTime.parse(j['date'] as String),
        note: j['note'] as String? ?? '',
      );
}

/// ====== СХОВИЩЕ (SharedPreferences) ==========================================
class ExpenseStore {
  static const _key = 'expenses_v1';

  Future<List<Expense>> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(Expense.fromJson).toList();
  }

  Future<void> save(List<Expense> items) async {
    final sp = await SharedPreferences.getInstance();
    final raw = jsonEncode(items.map((e) => e.toJson()).toList());
    await sp.setString(_key, raw);
  }
}

/// ====== ГОЛОВНИЙ ЕКРАН =======================================================
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _store = ExpenseStore();
  final _categories = const [
    'Продукти',
    'Транспорт',
    'Кафе',
    'Дім',
    'Здоровʼя',
    'Подарунки',
    'Інше',
  ];

  List<Expense> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _store.load();
    setState(() {
      _items = data..sort((a, b) => b.date.compareTo(a.date));
      _loading = false;
    });
  }

  Future<void> _addExpense() async {
    final result = await showModalBottomSheet<Expense>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F1E17),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: _ExpenseForm(categories: _categories),
      ),
    );

    if (result != null) {
      setState(() {
        _items.insert(0, result);
      });
      await _store.save(_items);
    }
  }

  Future<void> _deleteAt(int index) async {
    setState(() {
      _items.removeAt(index);
    });
    await _store.save(_items);
  }

  double get _total =>
      _items.fold(0.0, (sum, e) => sum + e.amount);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ретро-бюджет'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExpense,
        icon: const Icon(Icons.add),
        label: const Text('Додати витрату'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const SizedBox(height: 12),
                _TotalCard(total: _total),
                const SizedBox(height: 8),
                Expanded(
                  child: _items.isEmpty
                      ? const Center(
                          child: Text(
                            'Поки що порожньо. Додай першу витрату ➕',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _items.length,
                          itemBuilder: (context, i) {
                            final e = _items[i];
                            return Dismissible(
                              key: ValueKey('${e.date.millisecondsSinceEpoch}-$i'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade700,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              onDismissed: (_) => _deleteAt(i),
                              child: Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                child: ListTile(
                                  title: Text(
                                    '${e.category} — ${e.amount.toStringAsFixed(2)} ₴',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${_fmtDate(e.date)}${e.note.isNotEmpty ? " · ${e.note}" : ""}',
                                    style: const TextStyle(color: Colors.white70),
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

  String _two(int n) => n.toString().padLeft(2, '0');
  String _fmtDate(DateTime d) => '${_two(d.day)}.${_two(d.month)}.${d.year}';
}

/// ====== ВІДЖЕТИ ==============================================================
class _TotalCard extends StatelessWidget {
  final double total;
  const _TotalCard({required this.total});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.account_balance_wallet_outlined),
            const SizedBox(width: 12),
            const Text('Баланс (сума витрат): ',
                style: TextStyle(fontSize: 16, color: Colors.white70)),
            const Spacer(),
            Text(
              '${total.toStringAsFixed(2)} ₴',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseForm extends StatefulWidget {
  final List<String> categories;
  const _ExpenseForm({required this.categories});

  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  final _form = GlobalKey<FormState>();
  String _category = '';
  String _amountStr = '';
  String _note = '';
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _category = widget.categories.first;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _category,
            items: widget.categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _category = v ?? _category),
            decoration: const InputDecoration(labelText: 'Категорія'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Сума (₴)'),
            validator: (v) {
              final d = double.tryParse((v ?? '').replaceAll(',', '.'));
              if (d == null || d <= 0) return 'Вкажи суму більше 0';
              return null;
            },
            onSaved: (v) => _amountStr = v!.replaceAll(',', '.'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Нотатка (необов’язково)'),
            onSaved: (v) => _note = v?.trim() ?? '',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Дата: ${_two(_date.day)}.${_two(_date.month)}.${_date.year}',
                style: const TextStyle(color: Colors.white70),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    initialDate: _date,
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: Theme.of(context).colorScheme.copyWith(
                              primary: const Color(0xFFFFC94A),
                            ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: const Text('Змінити'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                if (_form.currentState?.validate() ?? false) {
                  _form.currentState?.save();
                  final amount = double.parse(_amountStr);
                  Navigator.pop(
                    context,
                    Expense(
                      category: _category,
                      amount: amount,
                      date: _date,
                      note: _note,
                    ),
                  );
                }
              },
              child: const Text('Зберегти'),
            ),
          ),
        ],
      ),
    );
  }

  String _two(int n) => n.toString().padLeft(2, '0');
}
EOF

      # 7) Зібрати APK (debug)
      - name: Build APK (debug)
        run: flutter build apk --debug

      # 8) Вивантажити APK
      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: retro_apk_debug
          path: build/app/outputs/flutter-apk/app-debug.apk
