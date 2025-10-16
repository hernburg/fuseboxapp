import 'package:flutter/material.dart';
import 'package:flutter/material.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

/// Простой рекурсивный парсер
/// expr := term (('+'|'-') term)*
/// term := factor (('*'|'/') factor)*
/// factor := number | '(' expr ')' | ('+'|'-') factor
class _Parser {
  _Parser(String raw) : s = raw.replaceAll(' ', '');
  final String s;
  int i = 0;

  double parse() {
    final v = _parseExpr();
    if (i != s.length) {
      throw Exception('Лишний ввод');
    }
    return v;
  }

  double _parseExpr() {
    var x = _parseTerm();
    while (i < s.length && (s[i] == '+' || s[i] == '-')) {
      final op = s[i++];
      final t = _parseTerm();
      x = (op == '+') ? (x + t) : (x - t);
    }
    return x;
  }

  double _parseTerm() {
    var x = _parseFactor();
    while (i < s.length && (s[i] == '*' || s[i] == '/')) {
      final op = s[i++];
      final f = _parseFactor();
      x = (op == '*') ? (x * f) : (x / f);
    }
    return x;
  }

  double _parseFactor() {
    if (i >= s.length) throw Exception('Ожидался операнд');

    // унарный +/-
    if (s[i] == '+' || s[i] == '-') {
      final sign = s[i++];
      final v = _parseFactor();
      return (sign == '-') ? -v : v;
    }

    // скобки
    if (s[i] == '(') {
      i++; // '('
      final v = _parseExpr();
      if (i >= s.length || s[i] != ')') throw Exception('Нет закрывающей скобки');
      i++; // ')'
      return v;
    }

    // число
    final start = i;
    var hasDot = false;
    while (i < s.length) {
      final c = s[i];
      final isDigit = c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;
      if (c == '.') {
        if (hasDot) break;
        hasDot = true;
        i++;
      } else if (isDigit) {
        i++;
      } else {
        break;
      }
    }
    if (start == i) throw Exception('Ожидалось число');
    return double.parse(s.substring(start, i));
  }
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _expr = '';
  String _result = '0';

  double _evaluateExpression(String raw) => _Parser(raw).parse();

  void _press(String key) {
    setState(() {
      switch (key) {
        case 'C':
          _expr = '';
          _result = '0';
          break;
        case '⌫':
          if (_expr.isNotEmpty) _expr = _expr.substring(0, _expr.length - 1);
          break;
        case '=':
          if (_expr.trim().isEmpty) return;
          try {
            final v = _evaluateExpression(_expr);
            final pretty = (v - v.roundToDouble()).abs() < 1e-12
                ? v.roundToDouble().toString()
                : v.toString();
            _result = pretty;
          } catch (_) {
            _result = 'Ошибка';
          }
          break;
        default:
          _expr += key;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const keys = <List<String>>[
      ['7', '8', '9', '/'],
      ['4', '5', '6', '*'],
      ['1', '2', '3', '-'],
      ['0', '.', '(', '+'],
      ['C', '⌫', ')', '='],
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Калькулятор')),
      body: SafeArea(
        child: Column(
          children: [
            // Экран
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                alignment: Alignment.bottomRight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SingleChildScrollView(
                      reverse: true,
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        _expr.isEmpty ? '0' : _expr,
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      reverse: true,
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        _result,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Кнопки
            Expanded(
              flex: 3,
              child: LayoutBuilder(
                builder: (context, cs) {
                  final w = cs.maxWidth;
                  final h = cs.maxHeight;
                  const gap = 8.0;
                  const cols = 4;
                  const rows = 5;

                  final cellW = (w - gap * (cols + 1)) / cols;
                  final cellH = (h - gap * (rows + 1)) / rows;

                  return Padding(
                    padding: const EdgeInsets.all(gap),
                    child: Column(
                      children: [
                        for (int r = 0; r < rows; r++) ...[
                          Row(
                            children: [
                              for (int c = 0; c < cols; c++) ...[
                                Padding(
                                  padding: EdgeInsets.only(
                                    right: c == cols - 1 ? 0 : gap,
                                  ),
                                  child: _KeyButton(
                                    label: keys[r][c],
                                    width: cellW,
                                    height: cellH,
                                    isAccent: _isOp(keys[r][c]),
                                    isWarn: keys[r][c] == 'C',
                                    onTap: () => _press(keys[r][c]),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (r != rows - 1) const SizedBox(height: gap),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isOp(String s) =>
      s == '+' || s == '-' || s == '*' || s == '/' || s == '=';
}

class _KeyButton extends StatelessWidget {
  final String label;
  final double width;
  final double height;
  final bool isAccent;
  final bool isWarn;
  final VoidCallback onTap;

  const _KeyButton({
    super.key,
    required this.label,
    required this.width,
    required this.height,
    required this.onTap,
    this.isAccent = false,
    this.isWarn = false,
  });

  @override
  Widget build(BuildContext context) {
    final kWhite = Theme.of(context).colorScheme.onSurface;

    return SizedBox(
      width: width,
      height: height,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: isAccent
                ? LinearGradient(
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                    colors: [
                      const Color(0xFFF54B64).withOpacity(.45),
                      const Color(0xFFF78361).withOpacity(.45),
                    ],
                  )
                : null,
            color: isAccent ? null : Colors.white.withOpacity(0.08),
            border: Border.all(
              color: isAccent ? Colors.transparent : kWhite.withOpacity(.18),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isWarn ? Colors.redAccent : kWhite,
              ),
            ),
          ),
        ),
      ),
    );
  }
}