import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/big_button.dart';
import 'parent_screen.dart';

/// 親画面に入る前の簡単なゲート。
/// 子ども画面に難しい設定を見せないため、かんたんな計算で大人だけ通します。
class ParentGateScreen extends StatefulWidget {
  const ParentGateScreen({super.key});

  @override
  State<ParentGateScreen> createState() => _ParentGateScreenState();
}

class _ParentGateScreenState extends State<ParentGateScreen> {
  late int _a;
  late int _b;
  final _controller = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    final rnd = Random();
    _a = 3 + rnd.nextInt(7); // 3〜9
    _b = 4 + rnd.nextInt(6); // 4〜9
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _check() {
    final answer = int.tryParse(_controller.text.trim());
    if (answer == _a * _b) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ParentScreen()),
      );
    } else {
      setState(() => _error = 'もういちど ためしてください');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('おうちのひと かくにん')),
      body: Container(
        decoration: AppTheme.backgroundGradient,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline,
                    size: 56, color: AppTheme.textDark),
                const SizedBox(height: 16),
                const Text('保護者の方へ：下の計算をしてください',
                    style: TextStyle(fontSize: 16)),
                const SizedBox(height: 16),
                Text('$_a × $_b = ?',
                    style: const TextStyle(
                        fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    errorText: _error,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _check(),
                ),
                const SizedBox(height: 24),
                BigButton(
                    label: 'すすむ',
                    width: double.infinity,
                    onPressed: _check),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
