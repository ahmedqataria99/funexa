import 'package:material_ui/material_ui.dart';
import 'package:flutter/painting.dart' as flutter_painting;

class DemandForecastPanel extends StatelessWidget {
  const DemandForecastPanel({
    super.key,
    required this.response,
    required this.horizonDays,
    required this.loading,
    this.error,
    this.onDismissError,
  });

  final Map<String, dynamic>? response;
  final int horizonDays;
  final bool loading;
  final String? error;
  final VoidCallback? onDismissError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (error != null) {
      return _MessageState(
        key: const ValueKey('forecast-error-state'),
        icon: Icons.error_outline,
        message: error!,
        action: onDismissError == null
            ? null
            : TextButton(onPressed: onDismissError, child: const Text('إغلاق')),
      );
    }
    if (loading && response == null) {
      return const _MessageState(
        key: ValueKey('forecast-loading-state'),
        icon: Icons.auto_graph_outlined,
        message: 'جارٍ استلام التوقعات وعرضها...',
        loading: true,
      );
    }
    if (response == null) {
      return const _MessageState(
        key: ValueKey('forecast-empty-state'),
        icon: Icons.insights_outlined,
        message: 'حدد عوامل التصفية ثم شغّل التوقعات.',
      );
    }

    final parsed = _ForecastData.parse(response!, horizonDays);
    if (parsed.state == _ForecastDataState.invalid) {
      return const _MessageState(
        key: ValueKey('forecast-invalid-state'),
        icon: Icons.warning_amber_outlined,
        message: 'تعذر قراءة بيانات التوقع. أعد تشغيل التوقعات.',
      );
    }
    if (parsed.state == _ForecastDataState.insufficient) {
      return const _MessageState(
        key: ValueKey('forecast-insufficient-state'),
        icon: Icons.info_outline,
        message: 'لا توجد بيانات تاريخية أو توقعات كافية لعرض الرسم البياني.',
      );
    }

    final data = parsed.data!;
    final total = data.forecast.fold<double>(
      0,
      (sum, point) => sum + (point['forecast'] as num).toDouble(),
    );
    final average = total / data.forecast.length;
    final firstDate = data.forecast.first['date'].toString();
    final lastDate = data.forecast.last['date'].toString();

    Widget summaryItem(String title, String value, IconData icon) => SizedBox(
      width: 220,
      child: Container(
        constraints: const BoxConstraints(minWidth: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(child: Text(title, style: theme.textTheme.bodySmall)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            summaryItem(
              'إجمالي الطلب المتوقع خلال الفترة',
              total.toStringAsFixed(1),
              Icons.summarize_outlined,
            ),
            summaryItem(
              'متوسط الطلب اليومي المتوقع',
              average.toStringAsFixed(1),
              Icons.equalizer_outlined,
            ),
            summaryItem(
              'فترة التوقع',
              '$firstDate ← $lastDate',
              Icons.date_range_outlined,
            ),
            summaryItem(
              'النموذج المستخدم',
              data.model,
              Icons.psychology_outlined,
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 340,
          child: DemandForecastChart(
            historical: data.historical,
            forecast: data.forecast,
            loading: loading,
          ),
        ),
      ],
    );
  }
}

class DemandForecastChart extends StatefulWidget {
  const DemandForecastChart({
    super.key,
    required this.historical,
    required this.forecast,
    this.loading = false,
  });

  final List<Map<String, dynamic>> historical;
  final List<Map<String, dynamic>> forecast;
  final bool loading;

  @override
  State<DemandForecastChart> createState() => _DemandForecastChartState();
}

class _DemandForecastChartState extends State<DemandForecastChart> {
  static const _actualColor = Color(0xFF3B82F6);
  static const _forecastColor = Color(0xFFF97316);
  int? _hoverIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final historical = widget.historical.length > 90
        ? widget.historical.sublist(widget.historical.length - 90)
        : widget.historical;
    final count = historical.length + widget.forecast.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 20,
          children: const [
            _LegendItem(
              key: ValueKey('historical-demand-legend'),
              color: _actualColor,
              label: 'الطلب الفعلي',
            ),
            _LegendItem(
              key: ValueKey('forecast-demand-legend'),
              color: _forecastColor,
              label: 'الطلب المتوقع',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              String tooltip = '';
              if (_hoverIndex != null && count > 0) {
                final index = _hoverIndex!.clamp(0, count - 1);
                if (index < historical.length) {
                  final point = historical[index];
                  tooltip = '${point['date']}: ${_quantity(point['actual'])}';
                } else {
                  final point = widget.forecast[index - historical.length];
                  tooltip = '${point['date']}: ${_quantity(point['forecast'])}';
                }
              }
              return MouseRegion(
                onHover: (event) {
                  const leftInset = 62.0;
                  const rightInset = 16.0;
                  final plotWidth =
                      constraints.maxWidth - leftInset - rightInset;
                  if (plotWidth <= 0 || count < 2) return;
                  final ratio =
                      ((event.localPosition.dx - leftInset) / plotWidth).clamp(
                        0.0,
                        1.0,
                      );
                  setState(() => _hoverIndex = (ratio * (count - 1)).round());
                },
                onExit: (_) => setState(() => _hoverIndex = null),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border.all(color: theme.dividerColor),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: RepaintBoundary(
                    key: const ValueKey('demand-forecast-chart'),
                    child: ClipRect(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Semantics(
                            key: const ValueKey('demand-series-semantics'),
                            label:
                                'الطلب الفعلي خط أزرق، والطلب المتوقع خط برتقالي',
                            child: CustomPaint(
                              painter: _ForecastChartPainter(
                                historical: historical,
                                forecast: widget.forecast,
                                actualColor: _actualColor,
                                forecastColor: _forecastColor,
                                gridColor: theme.dividerColor,
                                textColor: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (widget.loading)
                            const Align(
                              alignment: Alignment.topCenter,
                              child: LinearProgressIndicator(minHeight: 2),
                            ),
                          if (tooltip.isNotEmpty)
                            Positioned(
                              top: 8,
                              left: 70,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.inverseSurface,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  tooltip,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onInverseSurface,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _quantity(Object? value) =>
      value is num ? value.toStringAsFixed(1) : '-';
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({super.key, required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(key: ValueKey(label), width: 14, height: 3, color: color),
      const SizedBox(width: 7),
      Text(label),
    ],
  );
}

class _ForecastChartPainter extends CustomPainter {
  const _ForecastChartPainter({
    required this.historical,
    required this.forecast,
    required this.actualColor,
    required this.forecastColor,
    required this.gridColor,
    required this.textColor,
  });

  final List<Map<String, dynamic>> historical;
  final List<Map<String, dynamic>> forecast;
  final Color actualColor;
  final Color forecastColor;
  final Color gridColor;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    const leftInset = 62.0;
    const rightInset = 16.0;
    const topInset = 16.0;
    const bottomInset = 42.0;
    final plot = Rect.fromLTWH(
      leftInset,
      topInset,
      size.width - leftInset - rightInset,
      size.height - topInset - bottomInset,
    );
    if (plot.width <= 0 || plot.height <= 0) return;

    final values = <double>[];
    for (final point in historical) {
      final value = point['actual'];
      if (value is num && value.isFinite && value >= 0) {
        values.add(value.toDouble());
      }
    }
    for (final point in forecast) {
      final value = point['forecast'];
      if (value is num && value.isFinite && value >= 0) {
        values.add(value.toDouble());
      }
    }
    if (values.isEmpty) return;
    final maximum = values.reduce((a, b) => a > b ? a : b);
    final ceiling = maximum > 0 ? maximum * 1.1 : 1.0;
    final count = historical.length + forecast.length;
    if (count < 2) return;

    Offset pointAt(int index, double value) => Offset(
      plot.left + plot.width * index / (count - 1),
      plot.bottom - plot.height * value / ceiling,
    );

    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.72)
      ..strokeWidth = 1;
    for (var index = 0; index < 4; index++) {
      final ratio = index / 3;
      final y = plot.top + plot.height * ratio;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      final labelValue = ceiling * (1 - ratio);
      _paintText(
        canvas,
        labelValue.toStringAsFixed(labelValue >= 10 ? 0 : 1),
        TextStyle(color: textColor, fontSize: 10),
        TextDirection.ltr,
        Offset(4, y - 7),
        maxWidth: 48,
      );
    }
    canvas.save();
    canvas.translate(13, plot.center.dy + 20);
    canvas.rotate(-3.141592653589793 / 2);
    _paintText(
      canvas,
      'الكمية',
      TextStyle(color: textColor, fontSize: 10),
      TextDirection.rtl,
      Offset.zero,
    );
    canvas.restore();

    final historicalEnd = pointAt(historical.length - 1, 0).dx;
    final forecastStart = pointAt(historical.length, 0).dx;
    final dividerX = (historicalEnd + forecastStart) / 2;
    final dividerPaint = Paint()
      ..color = forecastColor
      ..strokeWidth = 1.5;
    for (var y = plot.top; y < plot.bottom; y += 8) {
      canvas.drawLine(
        Offset(dividerX, y),
        Offset(dividerX, (y + 4).clamp(plot.top, plot.bottom)),
        dividerPaint,
      );
    }

    final tickIndexes = <int>{
      for (var tick = 0; tick <= 4; tick++) (tick * (count - 1) / 4).round(),
    };
    for (final index in tickIndexes) {
      final point = index < historical.length
          ? historical[index]
          : forecast[index - historical.length];
      final date = point['date'].toString();
      final x = pointAt(index, 0).dx;
      _paintText(
        canvas,
        _dateLabel(date),
        TextStyle(color: textColor, fontSize: 9),
        TextDirection.ltr,
        Offset(x - 35, plot.bottom + 10),
        maxWidth: 70,
      );
    }

    void drawSeries({
      required List<Map<String, dynamic>> points,
      required String key,
      required int offset,
      required Color color,
    }) {
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      Path? path;
      Offset? previous;
      for (var index = 0; index < points.length; index++) {
        final value = points[index][key];
        if (value is! num || !value.isFinite || value < 0) {
          if (path != null) canvas.drawPath(path, linePaint);
          path = null;
          previous = null;
          continue;
        }
        final current = pointAt(index + offset, value.toDouble());
        if (previous == null) {
          path = Path()..moveTo(current.dx, current.dy);
        } else {
          path!.lineTo(current.dx, current.dy);
        }
        canvas.drawCircle(current, 2.2, dotPaint);
        previous = current;
      }
      if (path != null) canvas.drawPath(path, linePaint);
    }

    drawSeries(
      points: historical,
      key: 'actual',
      offset: 0,
      color: actualColor,
    );
    drawSeries(
      points: forecast,
      key: 'forecast',
      offset: historical.length,
      color: forecastColor,
    );
  }

  static String _dateLabel(String value) => value.length >= 10
      ? '${value.substring(8, 10)}/${value.substring(5, 7)}/${value.substring(0, 4)}'
      : value;

      static void _paintText(
        Canvas canvas,
        String value,
        TextStyle style,
        TextDirection direction,
        Offset offset, {
        double maxWidth = 120,
      }) {
      final painter = flutter_painting.TextPainter(
        text: flutter_painting.TextSpan(
          text: value,
          style: style,
        ),
        maxLines: 1,
      )
        ..textDirection = direction
        ..ellipsis = '…'
        ..layout(maxWidth: maxWidth);

      painter.paint(canvas, offset);
      painter.dispose();
  }

  @override
  bool shouldRepaint(covariant _ForecastChartPainter oldDelegate) =>
      !identical(historical, oldDelegate.historical) ||
      !identical(forecast, oldDelegate.forecast) ||
      actualColor != oldDelegate.actualColor ||
      forecastColor != oldDelegate.forecastColor ||
      gridColor != oldDelegate.gridColor ||
      textColor != oldDelegate.textColor;
}

enum _ForecastDataState { ready, insufficient, invalid }

class _ForecastParseResult {
  const _ForecastParseResult(this.state, [this.data]);

  final _ForecastDataState state;
  final _ForecastData? data;
}

class _ForecastData {
  const _ForecastData({
    required this.historical,
    required this.forecast,
    required this.model,
  });

  final List<Map<String, dynamic>> historical;
  final List<Map<String, dynamic>> forecast;
  final String model;

  static _ForecastParseResult parse(
    Map<String, dynamic> response,
    int horizonDays,
  ) {
    final status = response['status'];
    final declaredHorizon = response['horizon_days'];
    final rawHistorical = response['historical'];
    final rawForecast = response['forecast'];
    if ((status != 'ok' && status != 'insufficient_data') ||
        declaredHorizon != horizonDays ||
        rawHistorical is! List ||
        rawForecast is! List) {
      return const _ForecastParseResult(_ForecastDataState.invalid);
    }

    final historical = <Map<String, dynamic>>[];
    for (final item in rawHistorical) {
      if (item is! Map ||
          !item.containsKey('date') ||
          !item.containsKey('actual')) {
        return const _ForecastParseResult(_ForecastDataState.invalid);
      }
      final point = Map<String, dynamic>.from(item);
      if (!_validDate(point['date']) ||
          (point['actual'] != null && !_validQuantity(point['actual']))) {
        return const _ForecastParseResult(_ForecastDataState.invalid);
      }
      historical.add(point);
    }

    final forecast = <Map<String, dynamic>>[];
    for (final item in rawForecast) {
      if (item is! Map ||
          !item.containsKey('date') ||
          !item.containsKey('forecast')) {
        return const _ForecastParseResult(_ForecastDataState.invalid);
      }
      final point = Map<String, dynamic>.from(item);
      if (!_validDate(point['date']) || !_validQuantity(point['forecast'])) {
        return const _ForecastParseResult(_ForecastDataState.invalid);
      }
      forecast.add(point);
    }

    if (status == 'insufficient_data') {
      return forecast.isEmpty
          ? const _ForecastParseResult(_ForecastDataState.insufficient)
          : const _ForecastParseResult(_ForecastDataState.invalid);
    }
    if (forecast.length > horizonDays) {
      return const _ForecastParseResult(_ForecastDataState.invalid);
    }
    if (historical.isEmpty ||
        !historical.any((point) => point['actual'] is num) ||
        forecast.length < horizonDays) {
      return const _ForecastParseResult(_ForecastDataState.insufficient);
    }
    final model = response['selected_model'];
    if (model is! String || model.isEmpty) {
      return const _ForecastParseResult(_ForecastDataState.invalid);
    }
    return _ForecastParseResult(
      _ForecastDataState.ready,
      _ForecastData(historical: historical, forecast: forecast, model: model),
    );
  }

  static bool _validDate(Object? value) {
    if (value is! String) return false;
    return DateTime.tryParse(value) != null;
  }

  static bool _validQuantity(Object? value) =>
      value is num && value.isFinite && value >= 0;
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    super.key,
    required this.icon,
    required this.message,
    this.loading = false,
    this.action,
  });

  final IconData icon;
  final String message;
  final bool loading;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const CircularProgressIndicator()
            else
              Icon(icon, size: 30, color: theme.colorScheme.secondary),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            ?action,
          ],
        ),
      ),
    );
  }
}
