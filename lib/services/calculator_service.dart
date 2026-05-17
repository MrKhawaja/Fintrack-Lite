class CalculatorService {
  /// Parses and evaluates a simple arithmetic expression string.
  /// Supports: +, -, *, / and parentheses.
  /// Returns the result as a [double].
  double evaluate(String expression) {
    if (expression.trim().isEmpty) return 0.0;

    // Remove all whitespace
    final cleaned = expression.replaceAll(RegExp(r'\s+'), '');

    // Validate characters
    if (RegExp(r'[^0-9+\-*/().]').hasMatch(cleaned)) {
      throw FormatException('Expression contains invalid characters');
    }

    try {
      return _parseExpression(cleaned, 0).value;
    } catch (e) {
      throw FormatException('Invalid expression: $expression');
    }
  }

  _ParseResult _parseExpression(String expr, int index) {
    var result = _parseTerm(expr, index);
    index = result.index;

    while (index < expr.length && (expr[index] == '+' || expr[index] == '-')) {
      final op = expr[index];
      index++;
      final next = _parseTerm(expr, index);
      if (op == '+') {
        result = _ParseResult(result.value + next.value, next.index);
      } else {
        result = _ParseResult(result.value - next.value, next.index);
      }
      index = result.index;
    }

    return _ParseResult(result.value, index);
  }

  _ParseResult _parseTerm(String expr, int index) {
    var result = _parseFactor(expr, index);
    index = result.index;

    while (index < expr.length && (expr[index] == '*' || expr[index] == '/')) {
      final op = expr[index];
      index++;
      final next = _parseFactor(expr, index);
      if (op == '*') {
        result = _ParseResult(result.value * next.value, next.index);
      } else {
        if (next.value == 0) {
          throw FormatException('Division by zero');
        }
        result = _ParseResult(result.value / next.value, next.index);
      }
      index = result.index;
    }

    return _ParseResult(result.value, index);
  }

  _ParseResult _parseFactor(String expr, int index) {
    if (index >= expr.length) {
      throw FormatException('Unexpected end of expression');
    }

    if (expr[index] == '(') {
      index++;
      final result = _parseExpression(expr, index);
      if (result.index >= expr.length || expr[result.index] != ')') {
        throw FormatException('Missing closing parenthesis');
      }
      return _ParseResult(result.value, result.index + 1);
    }

    if (expr[index] == '-') {
      index++;
      final factor = _parseFactor(expr, index);
      return _ParseResult(-factor.value, factor.index);
    }

    return _parseNumber(expr, index);
  }

  _ParseResult _parseNumber(String expr, int index) {
    var start = index;
    var hasDecimal = false;

    while (index < expr.length) {
      final ch = expr[index];
      if (ch == '.' && !hasDecimal) {
        hasDecimal = true;
        index++;
      } else if (_isDigit(ch)) {
        index++;
      } else {
        break;
      }
    }

    if (start == index) {
      throw FormatException('Expected number at position $start');
    }

    final value = double.parse(expr.substring(start, index));
    return _ParseResult(value, index);
  }

  bool _isDigit(String ch) {
    return ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57;
  }
}

class _ParseResult {
  final double value;
  final int index;
  const _ParseResult(this.value, this.index);
}
