import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';

void main() => runApp(BmiApp());

class BmiApp extends StatefulWidget {
  @override
  _BmiAppState createState() => _BmiAppState();
}

class _BmiAppState extends State<BmiApp> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  Future<void> _saveThemePreference(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
  }

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    _saveThemePreference(_isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BMI Calculator',
      theme: _isDarkMode ? ThemeData.dark() : ThemeData.light(),
      home: BmiCalculator(onToggleTheme: _toggleTheme, isDarkMode: _isDarkMode),
    );
  }
}

class BmiCalculator extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  BmiCalculator({required this.onToggleTheme, required this.isDarkMode});

  @override
  _BmiCalculatorState createState() => _BmiCalculatorState();
}

class _BmiCalculatorState extends State<BmiCalculator> with SingleTickerProviderStateMixin {
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  List<Map<String, dynamic>> _bmiRecords = [];
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  double? _bmi;
  String? _status;

  @override
  void initState() {
    super.initState();
    _loadBmiRecords();
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _loadBmiRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final records = prefs.getString('bmiRecords');
    if (records != null) {
      setState(() {
        _bmiRecords = List<Map<String, dynamic>>.from(json.decode(records));
      });
    }
  }

  Future<void> _saveBmiRecords() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('bmiRecords', json.encode(_bmiRecords));
  }

  Future<void> _clearBmiRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('bmiRecords');
    setState(() {
      _bmiRecords.clear();
    });
    Navigator.pop(context); // Return to the main screen after clearing
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BmiHistoryScreen(
          bmiRecords: _bmiRecords,
          onClearRecords: _clearBmiRecords,
        ),
      ),
    );
  }

  void _calculateBmi() {
    final double heightCm = double.tryParse(_heightController.text) ?? 0;
    final double weight = double.tryParse(_weightController.text) ?? 0;
    final double height = heightCm / 100;

    if (height > 0 && weight > 0) {
      final bmi = weight / (height * height);
      setState(() {
        _bmi = bmi;
        if (bmi < 18.5) {
          _status = 'Underweight';
        } else if (bmi >= 18.5 && bmi < 24.9) {
          _status = 'Normal';
        } else if (bmi >= 25 && bmi < 29.9) {
          _status = 'Overweight';
        } else {
          _status = 'Obese';
        }
        _bmiRecords.insert(0, {
          'bmi': _bmi,
          'height': heightCm,
          'weight': weight,
          'date': DateTime.now().toString(),
        });
        _saveBmiRecords();
        _animationController.reset();
        _animationController.forward();
      });
    }
  }

  void _navigateToHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BmiHistoryScreen(
          bmiRecords: _bmiRecords,
          onClearRecords: _clearBmiRecords,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('BMI Calculator'),
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.wb_sunny : Icons.nights_stay),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _heightController,
              decoration: InputDecoration(labelText: 'Height (cm)'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _weightController,
              decoration: InputDecoration(labelText: 'Weight (kg)'),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _calculateBmi,
              child: Text('Calculate BMI'),
            ),
            FadeTransition(
              opacity: _fadeAnimation,
              child: _bmi != null
                  ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 16),
                  Text(
                    'Your BMI: ${_bmi!.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Status: $_status',
                    style: TextStyle(fontSize: 18),
                  ),
                ],
              )
                  : SizedBox.shrink(),
            ),
            ElevatedButton(
              onPressed: () => _navigateToHistory(context),
              child: Text('View BMI History'),
            ),
          ],
        ),
      ),
    );
  }
}

class BmiHistoryScreen extends StatelessWidget {
  final List<Map<String, dynamic>> bmiRecords;
  final VoidCallback onClearRecords;

  BmiHistoryScreen({required this.bmiRecords, required this.onClearRecords});

  List<FlSpot> _generateData() {
    final reversedRecords = bmiRecords.reversed.toList(); // 將紀錄反轉
    return reversedRecords.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(), // 使用反轉後的索引
        (entry.value['bmi'] as double),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('BMI History (Chart)'),
        leading: BackButton(),
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () {
              onClearRecords();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: LineChart(
          LineChartData(
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipColor: (touchedSpot) => Colors.blueAccent,
                  getTooltipItems: (touchedSpots) {
                    final reversedRecords = bmiRecords.reversed.toList(); // 確保與生成資料的順序一致
                    return touchedSpots.map((spot) {
                      final record = reversedRecords[spot.x.toInt()];
                      return LineTooltipItem(
                        'BMI: ${record['bmi'].toStringAsFixed(2)}\nHeight: ${record['height']} cm\nWeight: ${record['weight']} kg\nDate: ${record['date']}',
                        TextStyle(color: Colors.white),
                      );
                    }).toList();
                  }
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: _generateData(),
                isCurved: true,
                barWidth: 3,
                color: Colors.blue,
                dotData: FlDotData(show: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
