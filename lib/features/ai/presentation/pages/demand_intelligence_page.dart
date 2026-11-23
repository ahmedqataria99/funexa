import 'dart:async';

import 'package:flutter/material.dart';
import 'package:furnexa/core/localization/app_localizations.dart';
import 'package:furnexa/features/ai/data/local_ai_process_bridge.dart';
import 'package:furnexa/features/ai/data/local_ai_runtime.dart';
import 'package:furnexa/features/ai/data/sales_ai_payload_builder.dart';
import 'package:furnexa/features/ai/presentation/widgets/demand_forecast_panel.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';

class DemandIntelligencePage extends StatefulWidget {
  const DemandIntelligencePage({
    super.key,
    required this.security,
    required this.bridge,
  });

  final SecurityLocalDataSource security;
  final LocalAiProcessBridge bridge;

  @override
  State<DemandIntelligencePage> createState() => _DemandIntelligencePageState();
}

class _DemandIntelligencePageState extends State<DemandIntelligencePage> {
  late final SalesAiPayloadBuilder _payloadBuilder = SalesAiPayloadBuilder(
    security: widget.security,
  );
  List<SalesAiSelectionOption> _options = [];
  final Map<int, Map<String, dynamic>> _forecasts = {};
  String? _warehouseId;
  String? _productId;
  String? _variantKey;
  String? _error;
  int _horizon = 7;
  bool _loadingOptions = true;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadOptions());
  }

  Future<void> _loadOptions() async {
    try {
      final options = await _payloadBuilder.availableSelections();
      if (!mounted) return;
      setState(() {
        _options = options;
        if (options.isNotEmpty) {
          _warehouseId = options.first.warehouseId;
          _productId = options.first.productId;
          _variantKey = _variantValue(options.first.variantId);
        }
        _loadingOptions = false;
      });
      if (options.isNotEmpty) await _ensureService();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _displayError(error);
        _loadingOptions = false;
      });
    }
  }

  Future<void> _ensureService() async {
    if (widget.bridge.isRunning) return;
    await LocalAiRuntime.start(widget.bridge);
  }

  Future<void> _runForecasts() async {
    final selection = _selectedOption;
    if (selection == null || _running) return;
    setState(() {
      _running = true;
      _error = null;
      _forecasts.clear();
    });
    try {
      await _ensureService();
      final end = DateTime.now().toUtc();
      final periodEnd = DateTime.utc(end.year, end.month, end.day);
      final periodStart = periodEnd.subtract(const Duration(days: 364));
      for (final horizon in const [7, 14, 30]) {
        final payload = await _payloadBuilder.build(
          periodStart: periodStart,
          periodEnd: periodEnd,
          horizonDays: horizon,
          warehouseId: selection.warehouseId,
          productId: selection.productId,
          variantId: selection.variantId,
          filterVariant: true,
        );
        final result = await widget.bridge.forecast(payload);
        if (!mounted) return;
        setState(() => _forecasts[horizon] = result);
      }
    } catch (error) {
      if (mounted) setState(() => _error = _displayError(error));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  String _displayError(Object error) {
    final text = error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('LocalAiBridgeException: ', '');
    if (text.contains('readiness timeout') ||
        text.contains('service is unavailable') ||
        text.contains('Connection refused')) {
      return 'الخدمة المحلية غير متاحة حاليًا. انتظر لحظة ثم أعد المحاولة.';
    }
    if (text.contains('insufficient_data') || text.contains('بيانات تاريخية')) {
      return 'البيانات التاريخية غير كافية لإنشاء توقع موثوق.';
    }
    if (text.contains('422') ||
        text.contains('rejected') ||
        text.contains('Invalid')) {
      return 'تعذر إرسال الطلب بسبب بيانات غير صالحة. تحقق من التصفية وحاول مرة أخرى.';
    }
    return 'تعذر تنفيذ التوقع حاليًا. تحقق من اتصالك بالخدمة وأعد المحاولة.';
  }

  String _text(String english, String arabic) =>
      AppLocalizations.of(context).locale.languageCode == 'ar'
      ? arabic
      : english;

  String _variantValue(String? id) => id ?? '__base__';

  SalesAiSelectionOption? get _selectedOption {
    for (final option in _options) {
      if (option.warehouseId == _warehouseId &&
          option.productId == _productId &&
          _variantValue(option.variantId) == _variantKey) {
        return option;
      }
    }
    return null;
  }

  List<SalesAiSelectionOption> get _warehouseOptions {
    final seen = <String>{};
    return _options.where((option) => seen.add(option.warehouseId)).toList();
  }

  List<SalesAiSelectionOption> get _productOptions {
    final seen = <String>{};
    return _options
        .where(
          (option) =>
              option.warehouseId == _warehouseId && seen.add(option.productId),
        )
        .toList();
  }

  List<SalesAiSelectionOption> get _variantOptions => _options
      .where(
        (option) =>
            option.warehouseId == _warehouseId &&
            option.productId == _productId,
      )
      .toList();

  void _clearResults() {
    _forecasts.clear();
    _error = null;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _forecasts[_horizon];
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: _loadingOptions
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'ذكاء الطلب',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'توقع الطلب بناءً على المبيعات التاريخية المعتمدة وسياق المخزن والمنتج.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 14,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        children: [
                          SizedBox(
                            width: 220,
                            child: DropdownButtonFormField<String>(
                              initialValue: _warehouseId,
                              decoration: InputDecoration(
                                labelText: _text('Warehouse', 'المخزن'),
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: _warehouseOptions
                                  .map(
                                    (option) => DropdownMenuItem(
                                      value: option.warehouseId,
                                      child: Text(
                                        option.warehouseName,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                final first = _options.firstWhere(
                                  (option) => option.warehouseId == value,
                                );
                                setState(() {
                                  _warehouseId = value;
                                  _productId = first.productId;
                                  _variantKey = _variantValue(first.variantId);
                                  _clearResults();
                                });
                              },
                            ),
                          ),
                          SizedBox(
                            width: 250,
                            child: DropdownButtonFormField<String>(
                              initialValue: _productId,
                              decoration: InputDecoration(
                                labelText: _text('Product', 'المنتج'),
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: _productOptions
                                  .map(
                                    (option) => DropdownMenuItem(
                                      value: option.productId,
                                      child: Text(
                                        option.productName,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                final first = _options.firstWhere(
                                  (option) =>
                                      option.warehouseId == _warehouseId &&
                                      option.productId == value,
                                );
                                setState(() {
                                  _productId = value;
                                  _variantKey = _variantValue(first.variantId);
                                  _clearResults();
                                });
                              },
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child: DropdownButtonFormField<String>(
                              initialValue: _variantKey,
                              decoration: InputDecoration(
                                labelText: _text('Variant', 'النوع'),
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: _variantOptions
                                  .map(
                                    (option) => DropdownMenuItem(
                                      value: _variantValue(option.variantId),
                                      child: Text(
                                        option.variantName ??
                                            _text(
                                              'Base product',
                                              'المنتج الأساسي',
                                            ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _variantKey = value;
                                  _clearResults();
                                });
                              },
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: _selectedOption == null || _running
                                ? null
                                : _runForecasts,
                            icon: _running
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.auto_graph_outlined),
                            label: Text(
                              _text('Run forecasts', 'تشغيل التوقعات'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (_options.isEmpty)
                        SizedBox(
                          height: 180,
                          child: Center(
                            child: Text(
                              _text(
                                'No posted sales history is available in your authorized warehouses.',
                                'لا توجد مبيعات مرحلة في المخازن المصرح بها.',
                              ),
                            ),
                          ),
                        )
                      else ...[
                        Text(
                          'أفق التوقع',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(value: 7, label: Text('7 أيام')),
                            ButtonSegment(value: 14, label: Text('14 يومًا')),
                            ButtonSegment(value: 30, label: Text('30 يومًا')),
                          ],
                          selected: {_horizon},
                          onSelectionChanged: (value) =>
                              setState(() => _horizon = value.single),
                        ),
                        const SizedBox(height: 12),
                        DemandForecastPanel(
                          key: const ValueKey('demand-forecast-panel'),
                          response: selected,
                          horizonDays: _horizon,
                          loading: _running,
                          error: _error,
                          onDismissError: () => setState(() => _error = null),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
