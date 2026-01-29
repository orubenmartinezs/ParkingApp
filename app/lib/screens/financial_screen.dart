import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../database/database_helper.dart';
import '../models/expense.dart';
import '../models/parking_record.dart';
import '../models/pension_payment.dart';
import '../models/config_models.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';

class FinancialScreen extends StatefulWidget {
  const FinancialScreen({super.key});

  @override
  State<FinancialScreen> createState() => _FinancialScreenState();
}

class _FinancialScreenState extends State<FinancialScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Finanzas'),
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.attach_money), text: 'Gastos'),
              Tab(icon: Icon(Icons.analytics), text: 'Reporte'),
            ],
          ),
        ),
        body: Container(
          color: Colors.grey.shade100,
          child: const TabBarView(
            children: [ExpensesListTab(), FinancialReportTab()],
          ),
        ),
      ),
    );
  }
}

// -------------------- PESTAÑA LISTA DE GASTOS --------------------

class ExpensesListTab extends StatefulWidget {
  const ExpensesListTab({super.key});

  @override
  State<ExpensesListTab> createState() => _ExpensesListTabState();
}

class _ExpensesListTabState extends State<ExpensesListTab> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Expense> _expenses = [];
  List<ExpenseCategory> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final expenses = await _dbHelper.getExpenses();
    final categories = await _dbHelper.getActiveExpenseCategories();
    if (mounted) {
      setState(() {
        _expenses = expenses;
        _categories = categories;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadExpenses() async {
    // Mantenido para refrescar después de agregar/eliminar
    final expenses = await _dbHelper.getExpenses();
    if (mounted) {
      setState(() {
        _expenses = expenses;
      });
    }
  }

  Future<void> _addExpense() async {
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    final categoryController = TextEditingController();
    String? selectedCategoryName;

    // Preseleccionar primera categoría si está disponible
    if (_categories.isNotEmpty) {
      selectedCategoryName = _categories.first.name;
    }

    DateTime selectedDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Registrar Gasto'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Monto',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_categories.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: selectedCategoryName,
                      decoration: const InputDecoration(
                        labelText: 'Categoría',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      items: _categories.map((c) {
                        return DropdownMenuItem(
                          value: c.name,
                          child: Text(c.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedCategoryName = value;
                        });
                      },
                    )
                  else
                    Autocomplete<String>(
                      optionsBuilder:
                          (TextEditingValue textEditingValue) async {
                            if (textEditingValue.text.length < 2) {
                              return const Iterable<String>.empty();
                            }
                            return await _dbHelper
                                .getExpenseCategorySuggestions(
                                  textEditingValue.text,
                                );
                          },
                      onSelected: (String selection) {
                        categoryController.text = selection;
                      },
                      fieldViewBuilder:
                          (
                            context,
                            fieldTextEditingController,
                            focusNode,
                            onFieldSubmitted,
                          ) {
                            return TextField(
                              controller: fieldTextEditingController,
                              focusNode: focusNode,
                              decoration: const InputDecoration(
                                labelText: 'Categoría (Ej. Luz, Agua)',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                              textCapitalization: TextCapitalization.sentences,
                              onChanged: (value) {
                                categoryController.text = value;
                              },
                            );
                          },
                    ),

                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Text('Fecha: '),
                      TextButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 18),
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() => selectedDate = date);
                          }
                        },
                        label: Text(
                          DateFormat('dd/MM/yyyy').format(selectedDate),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final category = _categories.isNotEmpty
                      ? selectedCategoryName
                      : categoryController.text;

                  if (descriptionController.text.isNotEmpty &&
                      amountController.text.isNotEmpty &&
                      (category?.isNotEmpty ?? false)) {
                    final amount =
                        double.tryParse(amountController.text) ?? 0.0;
                    final newExpense = Expense(
                      id: const Uuid().v4(),
                      description: descriptionController.text,
                      amount: amount,
                      category: category!,
                      expenseDate: selectedDate,
                      userId: AuthService.instance.currentUser?.id,
                      createdAt: DateTime.now(),
                    );

                    await _dbHelper.insertExpense(newExpense);

                    if (context.mounted) {
                      Navigator.pop(context);
                      _loadExpenses();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Gasto registrado')),
                      );
                      // Trigger sync
                      context.read<SyncService>().syncData();
                    }
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _addExpense,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _expenses.isEmpty
          ? const Center(child: Text('No hay gastos registrados'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _expenses.length,
              itemBuilder: (context, index) {
                final expense = _expenses[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red.shade700,
                      child: const Icon(Icons.money_off_rounded),
                    ),
                    title: Text(
                      expense.description,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${DateFormat('dd/MM/yyyy').format(expense.expenseDate)} • ${expense.category}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                    trailing: Text(
                      '\$${expense.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.red,
                      ),
                    ),
                    onLongPress: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Eliminar Gasto'),
                          content: Text('¿Eliminar "${expense.description}"?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text(
                                'Eliminar',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await _dbHelper.deleteExpense(expense.id);
                        _loadExpenses();
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}

// -------------------- PESTAÑA REPORTE --------------------

class FinancialReportTab extends StatefulWidget {
  const FinancialReportTab({super.key});

  @override
  State<FinancialReportTab> createState() => _FinancialReportTabState();
}

class _FinancialReportTabState extends State<FinancialReportTab> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  double _totalIncomeParking = 0;
  double _totalIncomePensions = 0;
  double _totalExpenses = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Por defecto mes actual
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0); // Last day of month
    _generateReport();
  }

  Future<void> _generateReport() async {
    setState(() => _isLoading = true);

    // Normalizar fechas para consulta (inicio del día, fin del día)
    final start = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      0,
      0,
      0,
    );
    final end = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      23,
      59,
      59,
    );

    final parkingRecords = await _dbHelper.getParkingRecordsByDateRange(
      start,
      end,
    );
    final pensionPayments = await _dbHelper.getPensionPaymentsByDateRange(
      start,
      end,
    );
    final expenses = await _dbHelper.getExpensesByDateRange(start, end);

    // Calcular Totales
    double parkingSum = 0;
    for (var r in parkingRecords) {
      // Solo sumar si salió dentro del rango (El ingreso se realiza al salir)
      // y coincidir con lógica del backend que suma 'costo' basado en exit_time
      if (r.exitTime != null &&
          !r.exitTime!.isBefore(start) &&
          !r.exitTime!.isAfter(end)) {
        parkingSum += (r.cost ?? 0);
      }
    }

    double pensionSum = pensionPayments.fold(0, (sum, p) => sum + p.amount);
    double expenseSum = expenses.fold(0, (sum, e) => sum + e.amount);

    if (mounted) {
      setState(() {
        _totalIncomeParking = parkingSum;
        _totalIncomePensions = pensionSum;
        _totalExpenses = expenseSum;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _generateReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalIncome = _totalIncomeParking + _totalIncomePensions;
    final netBalance = totalIncome - _totalExpenses;
    final primaryColor = Theme.of(context).primaryColor;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Selector de Fecha
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap: _selectDateRange,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.calendar_today, color: primaryColor),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Periodo',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            // Tarjeta de Balance Neto
            Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: primaryColor,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text(
                      'Balance Neto',
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$${netBalance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Desglose
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    title: 'Ingresos',
                    amount: totalIncome,
                    color: Colors.green,
                    icon: Icons.arrow_downward_rounded,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _SummaryCard(
                    title: 'Gastos',
                    amount: _totalExpenses,
                    color: Colors.red,
                    icon: Icons.arrow_upward_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Detailed Income
            const Text(
              'Detalle de Ingresos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.local_parking_rounded,
                        color: Colors.blue,
                      ),
                    ),
                    title: const Text(
                      'Estacionamiento',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: Text(
                      '\$${_totalIncomeParking.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.directions_car_rounded,
                        color: Colors.orange,
                      ),
                    ),
                    title: const Text(
                      'Pensiones',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: Text(
                      '\$${_totalIncomePensions.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text(
              '\$${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
