name: Build Android APK (debug, MVP)

on:
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      # 1. Отримати код із репозиторію
      - name: Checkout
        uses: actions/checkout@v4

      # 2. Встановити Java
      - name: Setup Java
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'

      # 3. Встановити Flutter
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'

      # 4. Створити Flutter-проєкт
      - name: Create Flutter project
        run: flutter create . --platforms=android --project-name retrobudget --org com.rb.unique123 --overwrite

      # 5. Вставити код програми
      - name: Inject app with add-expense
        run: |
          cat > lib/main.dart << 'EOF'
          import 'package:flutter/material.dart';

          void main() => runApp(const MyApp());

          class MyApp extends StatelessWidget {
            const MyApp({super.key});

            @override
            Widget build(BuildContext context) {
              return MaterialApp(
                debugShowCheckedModeBanner: false,
                title: 'Ретро-бюджет',
                theme: ThemeData.dark(useMaterial3: true).copyWith(
                  scaffoldBackgroundColor: const Color(0xFF0E1F17),
                  colorScheme: const ColorScheme.dark(
                    primary: Color(0xFFFFC94A),
                    secondary: Color(0xFFFFB347),
                  ),
                ),
                home: const HomePage(),
              );
            }
          }

          class HomePage extends StatefulWidget {
            const HomePage({super.key});
            @override
            State<HomePage> createState() => _HomePageState();
          }

          class _HomePageState extends State<HomePage> {
            int balance = 0;

            void _addExpense() async {
              final controller = TextEditingController();
              final result = await showDialog<int>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Додати витрату"),
                  content: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: "Введіть суму (грн)",
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Скасувати"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        final value = int.tryParse(controller.text);
                        Navigator.pop(context, value);
                      },
                      child: const Text("Додати"),
                    ),
                  ],
                ),
              );

              if (result != null) {
                setState(() {
                  balance -= result;
                });
              }
            }

            @override
            Widget build(BuildContext context) {
              return Scaffold(
                appBar: AppBar(title: const Text('Розподіл коштів')),
                body: Center(
                  child: Text(
                    'Баланс: \$balance грн',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                floatingActionButton: FloatingActionButton.extended(
                  onPressed: _addExpense,
                  label: const Text('Додати'),
                  icon: const Icon(Icons.add),
                ),
              );
            }
          }
          EOF

      # 6. Встановити залежності
      - name: Install dependencies
        run: flutter pub get

      # 7. Зібрати APK (debug)
      - name: Build APK (debug)
        run: flutter build apk --debug

      # 8. Завантажити артефакт
      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: retro_apk
          path: build/app/outputs/flutter-apk/app-debug.apk
