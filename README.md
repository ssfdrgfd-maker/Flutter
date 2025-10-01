name: Build Android APK (debug, MVP)

on:
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'

      # 1) Створюємо Flutter-проєкт у підпапці app/
      - name: Create Flutter project in subdir
        run: flutter create app --platforms=android --project-name retrobudget --org com.rb.mvp --overwrite

      # 2) Унікальний applicationId, щоб встановлювався як новий додаток
      - name: Set unique applicationId
        run: |
          sed -i 's/applicationId "[^"]*"/applicationId "com.rb.mvp.retrobudget.${{ github.run_id }}"/' app/android/app/build.gradle

      # 3) Назва застосунку в лаунчері
      - name: Set launcher label
        run: |
          sed -i 's/android:label="retrobudget"/android:label="Бюджет MVP"/' app/android/app/src/main/AndroidManifest.xml

      # 4) pubspec із залежностями
      - name: Inject pubspec.yaml
        run: |
          cat > app/pubspec.yaml << 'EOF'
          name: retrobudget
          description: MVP бюджету з локальним збереженням
          publish_to: "none"
          version: 0.1.0+1
          environment:
            sdk: ">=3.4.0 <4.0.0"

          dependencies:
            flutter:
              sdk: flutter
            shared_preferences: ^2.2.2
            intl: ^0.19.0
            cupertino_icons: ^1.0.6

          dev_dependencies:
            flutter_test:
              sdk: flutter
            flutter_lints: ^4.0.0

          flutter:
            uses-material-design: true
          EOF

      # 5) Робочий main.dart (сітка категорій, додавання витрат, деталі)
      - name: Inject main.dart (MVP)
        run: |
          cat > app/lib/main.dart << 'EOF'
          import 'dart:convert';
          import 'package:flutter/material.dart';
          import 'package:intl/intl.dart';
          import 'package:shared_preferences/shared_preferences.dart';

          void main() => runApp(const BudgetApp());

          class Expense {
            final String id; final String categoryId; final int epoch; final double amount; final String note;
            Expense({required this.id, required this.categoryId, required this.epoch, required this.amount, required this.note});
            Map<String, dynamic> toJson()=>{'id':id,'categoryId':categoryId,'epoch':epoch,'amount':amount,'note':note};
            static Expense fromJson(Map<String,dynamic> j)=>Expense(id:j['id'],categoryId:j['categoryId'],epoch:j['epoch'],amount:(j['amount'] as num).toDouble(),note:j['note']??'');
          }
          class Category { final String id; final String name; final IconData icon; Category(this.id,this.name,this.icon); }
          final kCategories=<Category>[
            Category('food','Їжа',Icons.restaurant),
            Category('transport','Транспорт',Icons.directions_bus),
            Category('home','Житло',Icons.home),
            Category('health','Здоровʼя',Icons.local_hospital),
            Category('fun','Дозвілля',Icons.local_bar),
            Category('sport','Спорт',Icons.fitness_center),
            Category('auto','Авто',Icons.directions_car),
            Category('other','Інше',Icons.category),
          ];

          class Store{
            final SharedPreferences prefs; Store(this.prefs);
            static Future<Store> open()async=>Store(await SharedPreferences.getInstance());
            String _keyBudgets(String ym)=>'budgets_$ym'; String _keyExp(String ym)=>'expenses_$ym';
            String currentYm()=>DateFormat('yyyy-MM').format(DateTime.now());
            Map<String,double> loadBudgets(String ym){ final raw=prefs.getString(_keyBudgets(ym)); if(raw==null)return{}; return (jsonDecode(raw) as Map).map((k,v)=>MapEntry(k,(v as num).toDouble())); }
            Future<void> saveBudgets(String ym,Map<String,double> m)=>prefs.setString(_keyBudgets(ym),jsonEncode(m));
            List<Expense> loadExpenses(String ym){ final raw=prefs.getString(_keyExp(ym)); if(raw==null)return[]; return (jsonDecode(raw) as List).map((e)=>Expense.fromJson(e)).toList(); }
            Future<void> addExpense(String ym,Expense e)async{ final list=loadExpenses(ym)..add(e); await prefs.setString(_keyExp(ym),jsonEncode(list.map((e)=>e.toJson()).toList())); }
          }

          class BudgetApp extends StatelessWidget{
            const BudgetApp({super.key});
            @override Widget build(BuildContext c)=>MaterialApp(
              title:'Бюджет', debugShowCheckedModeBanner:false,
              theme: ThemeData.dark(useMaterial3:true).copyWith(
                colorScheme: const ColorScheme.dark(primary:Color(0xFFC49A41),secondary:Color(0xFF88A37F)),
                scaffoldBackgroundColor: const Color(0xFF0F1E17),
              ),
              home: const HomeScreen(),
            );
          }

          class HomeScreen extends StatefulWidget{ const HomeScreen({super.key}); @override State<HomeScreen> createState()=>_HomeScreenState(); }
          class _HomeScreenState extends State<HomeScreen>{
            Store? store; String ym=''; Map<String,double> budgets={}; List<Expense> expenses=[];
            @override void initState(){ super.initState(); _init(); }
            Future<void> _init() async{ final s=await Store.open(); final m=s.currentYm(); setState((){store=s;ym=m;budgets=s.loadBudgets(m);expenses=s.loadExpenses(m);}); }
            double spentFor(String id)=>expenses.where((e)=>e.categoryId==id).fold(0.0,(a,b)=>a+b.amount);

            void _openAdd([String? id]){
              if(store==null)return;
              showModalBottomSheet(context: context,isScrollControlled:true,builder:(_)=>AddExpenseSheet(
                initialCategoryId:id??'food',
                onSave:(cat,amount,note,date){
                  final e=Expense(id:DateTime.now().microsecondsSinceEpoch.toString(),categoryId:cat,epoch:date.millisecondsSinceEpoch,amount:amount,note:note);
                  store!.addExpense(ym,e).then((_){ setState(()=>expenses=store!.loadExpenses(ym)); });
                },
              ));
            }
            void _setBudget(String id){
              final c=TextEditingController(text:(budgets[id]??0).toStringAsFixed(0));
              showDialog(context:context,builder:(ctx)=>AlertDialog(
                title: const Text('Запланувати суму'),
                content: TextField(controller:c,keyboardType: const TextInputType.numberWithOptions(decimal:true),decoration: const InputDecoration(prefixText:'₴ ')),
                actions:[ TextButton(onPressed:()=>Navigator.pop(ctx),child: const Text('Скасувати')),
                  FilledButton(onPressed:(){ final v=double.tryParse(c.text.replaceAll(',', '.'))??0; budgets[id]=v; store!.saveBudgets(ym,budgets); setState((){}); Navigator.pop(ctx); }, child: const Text('Зберегти')) ],
              ));
            }

            @override Widget build(BuildContext c){
              if(store==null) return const Scaffold(body: Center(child:CircularProgressIndicator()));
              return Scaffold(
                appBar: AppBar(title: const Text('Розподіл коштів')),
                body: GridView.count(padding: const EdgeInsets.all(16), crossAxisCount:2, mainAxisSpacing:12, crossAxisSpacing:12, children:[
                  for(final cat in kCategories) _CategoryCard(
                    category:cat, planned:budgets[cat.id]??0, spent:spentFor(cat.id),
                    onTap:(){ Navigator.push(context,MaterialPageRoute(builder:(_)=>CategoryDetails(category:cat,ym:ym,store:store!))).then((_){ setState((){budgets=store!.loadBudgets(ym);expenses=store!.loadExpenses(ym);}); }); },
                    onLongPress:()=>_setBudget(cat.id),
                    onAdd:()=>_openAdd(cat.id),
                  ),
                ]),
                floatingActionButton: FloatingActionButton.extended(onPressed:_openAdd, icon: const Icon(Icons.add), label: const Text('Додати')),
              );
            }
          }

          class _CategoryCard extends StatelessWidget{
            final Category category; final double planned; final double spent; final VoidCallback onTap; final VoidCallback onLongPress; final VoidCallback onAdd;
            const _CategoryCard({super.key,required this.category,required this.planned,required this.spent,required this.onTap,required this.onLongPress,required this.onAdd});
            @override Widget build(BuildContext c){
              final pct = planned>0 ? (spent/planned).clamp(0.0,1.0) : 0.0; final pctText = planned>0 ? '${(pct*100).toStringAsFixed(0)}%' : '0%'; final remain = planned-spent;
              return GestureDetector(onTap:onTap,onLongPress:onLongPress,child: Container(
                decoration: BoxDecoration(color: const Color(0xFF15251C), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black26)),
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                  Row(children:[ Icon(category.icon,size:28,color:Theme.of(c).colorScheme.primary), const Spacer(), IconButton(onPressed:onAdd, icon: const Icon(Icons.add_circle_outline)) ]),
                  const SizedBox(height:8),
                  Text(category.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  LinearProgressIndicator(value: pct, minHeight:8),
                  const SizedBox(height:8),
                  Text('Заплановано: ₴${planned.toStringAsFixed(0)}', style: const TextStyle(fontSize:12)),
                  Text('Витрачено: ₴${spent.toStringAsFixed(0)}  ($pctText)', style: const TextStyle(fontSize:12)),
                  Text('Залишок: ₴${remain.toStringAsFixed(0)}', style: const TextStyle(fontSize:12)),
                ]),
              ));
            }
          }

          class CategoryDetails extends StatefulWidget{ final Category category; final String ym; final Store store; const CategoryDetails({super.key,required this.category,required this.ym,required this.store}); @override State<CategoryDetails> createState()=>_CategoryDetailsState(); }
          class _CategoryDetailsState extends State<CategoryDetails>{
            late Map<String,double> budgets; late List<Expense> expenses;
            @override void initState(){ super.initState(); budgets=widget.store.loadBudgets(widget.ym); expenses=widget.store.loadExpenses(widget.ym).where((e)=>e.categoryId==widget.category.id).toList()..sort((a,b)=>b.epoch.compareTo(a.epoch)); }
            @override Widget build(BuildContext c){
              final planned=budgets[widget.category.id]??0; final spent=expenses.fold<double>(0,(a,b)=>a+b.amount); final remain=planned-spent;
              return Scaffold(
                appBar: AppBar(title: Text(widget.category.name)),
                body: Column(children:[
                  Padding(padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
                    _kv('Заплановано','₴${planned.toStringAsFixed(0)}'), _kv('Витрачено','₴${spent.toStringAsFixed(0)}'), _kv('Залишок','₴${remain.toStringAsFixed(0)}'),
                  ])),
                  const Divider(height:0),
                  Expanded(child: expenses.isEmpty? const Center(child: Text('Поки що без витрат')): ListView.builder(
                    itemCount: expenses.length, itemBuilder:(_,i){ final e=expenses[i]; final dt=DateFormat('dd.MM.yyyy').format(DateTime.fromMillisecondsSinceEpoch(e.epoch));
                      return ListTile(leading: const Icon(Icons.receipt_long), title: Text('₴${e.amount.toStringAsFixed(2)}'), subtitle: Text('${e.note.isEmpty?'Без примітки':e.note} · $dt')); })),
                ]),
                floatingActionButton: FloatingActionButton.extended(onPressed:(){
                  showModalBottomSheet(context:c,isScrollControlled:true,builder:(_)=>AddExpenseSheet(initialCategoryId:widget.category.id,onSave:(cat,amount,note,date) async{
                    final e=Expense(id:DateTime.now().microsecondsSinceEpoch.toString(),categoryId:cat,amount:amount,note:note,epoch:date.millisecondsSinceEpoch);
                    await widget.store.addExpense(widget.ym,e); setState(()=>expenses.insert(0,e));
                  }));
                }, icon: const Icon(Icons.add), label: const Text('Додати витрату')),
              );
            }
            Widget _kv(String k,String v)=>Column(crossAxisAlignment: CrossAxisAlignment.start,children:[ Text(k,style: const TextStyle(fontSize:12,color:Colors.white70)), const SizedBox(height:2), Text(v,style: const TextStyle(fontWeight: FontWeight.w600)), ]);
          }

          class AddExpenseSheet extends StatefulWidget{
            final String initialCategoryId; final void Function(String,double,String,DateTime) onSave; const AddExpenseSheet({super.key,required this.initialCategoryId,required this.onSave});
            @override State<AddExpenseSheet> createState()=>_AddExpenseSheetState();
          }
          class _AddExpenseSheetState extends State<AddExpenseSheet>{
            late String catId; final amountCtrl=TextEditingController(); final noteCtrl=TextEditingController(); DateTime date=DateTime.now();
            @override void initState(){ super.initState(); catId=widget.initialCategoryId; }
            @override Widget build(BuildContext c){
              final bottom=MediaQuery.of(c).viewInsets.bottom;
              return Padding(padding: EdgeInsets.only(left:16,right:16,bottom:bottom+16,top:16), child: Column(mainAxisSize: MainAxisSize.min, children:[
                Row(children:[ const Text('Нова витрата',style:TextStyle(fontSize:16,fontWeight:FontWeight.w600)), const Spacer(), IconButton(onPressed:()=>Navigator.pop(c), icon: const Icon(Icons.close)) ]),
                const SizedBox(height:8),
                DropdownButtonFormField<String>(value:catId, items:[
                  for(final cc in kCategories) DropdownMenuItem(value:cc.id, child: Row(children:[Icon(cc.icon), const SizedBox(width:8), Text(cc.name)])),
                ], onChanged:(v){ if(v!=null) setState(()=>catId=v); }, decoration: const InputDecoration(labelText:'Категорія')),
                const SizedBox(height:8),
                TextField(controller:amountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal:true), decoration: const InputDecoration(labelText:'Сума, ₴')),
                const SizedBox(height:8),
                TextField(controller:noteCtrl, decoration: const InputDecoration(labelText:'Примітка (необовʼязково)')),
                const SizedBox(height:8),
                Row(children:[ Text(DateFormat('dd.MM.yyyy').format(date)), const Spacer(), TextButton.icon(onPressed:() async{
                  final p=await showDatePicker(context:c, initialDate:date, firstDate:DateTime.now().subtract(const Duration(days:365)), lastDate:DateTime.now().add(const Duration(days:365)));
                  if(p!=null) setState(()=>date=p);
                }, icon: const Icon(Icons.event), label: const Text('Змінити дату')) ]),
                const SizedBox(height:12),
                SizedBox(width:double.infinity, child: FilledButton.icon(onPressed:(){
                  final amount=double.tryParse(amountCtrl.text.replaceAll(',', '.'))??0; if(amount<=0){ Navigator.pop(c); return; }
                  widget.onSave(catId, amount, noteCtrl.text.trim(), date); Navigator.pop(c);
                }, icon: const Icon(Icons.check), label: const Text('Зберегти'))),
              ]));
            }
          }
          EOF

      - name: flutter pub get
        working-directory: app
        run: flutter pub get

      - name: Build split APKs (debug)
        working-directory: app
        run: flutter build apk --debug --split-per-abi

      - name: Upload APKs
        uses: actions/upload-artifact@v4
        with:
          name: retro_apk_debug_split
          path: app/build/app/outputs/flutter-apk/*.apk
