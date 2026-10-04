import 'package:flutter/material.dart';
import 'package:furnexa/core/localization/app_localizations.dart';
import 'package:furnexa/core/shared/widgets/detail/furnexa_detail.dart';
import 'package:furnexa/features/purchasing/domain/entities/purchasing_entities.dart';
import 'package:furnexa/features/purchasing/domain/repositories/purchasing_repository.dart';

class SupplierProfilePage extends StatefulWidget {
  const SupplierProfilePage({super.key, required this.repository, required this.supplier});
  final PurchasingRepository repository;
  final Supplier supplier;

  @override
  State<SupplierProfilePage> createState() => _SupplierProfilePageState();
}

class _SupplierProfilePageState extends State<SupplierProfilePage> {
  List<PurchaseOrder> orders = const [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final all = await widget.repository.orders();
      if (!mounted) return;
      setState(() {
        orders = all.where((order) => order.supplierId == widget.supplier.id).toList();
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        error = AppLocalizations.of(context).tableLoadFailed;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.supplier.name)),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : FurnexaDetailPage(
                  header: FurnexaDetailHeader(
                    title: widget.supplier.name,
                    code: widget.supplier.code,
                    status: furnexaActiveStatus(context, widget.supplier.active),
                  ),
                  children: [
                    FurnexaInfoSection(
                      title: localizations.information,
                      items: [
                        FurnexaInfoItem(label: localizations.name, value: widget.supplier.name),
                        FurnexaInfoItem(label: localizations.code, value: widget.supplier.code),
                        FurnexaInfoItem(label: localizations.phone, value: widget.supplier.phone ?? '-'),
                        FurnexaInfoItem(label: localizations.email, value: widget.supplier.email ?? '-'),
                        FurnexaInfoItem(label: localizations.address, value: widget.supplier.address ?? '-'),
                        FurnexaInfoItem(label: localizations.taxNumber, value: widget.supplier.taxNumber ?? '-'),
                      ],
                    ),
                    FurnexaDetailSection(
                      title: localizations.history,
                      empty: orders.isEmpty,
                      emptyTitle: localizations.noRelatedRecords,
                      child: Column(
                        children: orders
                            .map((order) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.shopping_cart_outlined),
                                  title: Text(order.orderNumber),
                                  subtitle: Text(order.status.name),
                                  trailing: Text(order.grandTotal.toStringAsFixed(2)),
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                ),
    );
  }
}
