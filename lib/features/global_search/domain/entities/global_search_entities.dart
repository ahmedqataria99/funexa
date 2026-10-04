enum GlobalSearchEntityType {
  product,
  customer,
  salesOrder,
  productionOrder,
  worker,
  warehouse,
  section,
  workshop,
  productionStage,
}

enum GlobalSearchEntityCategory {
  all,
  products,
  customers,
  salesOrders,
  productionOrders,
  workers,
  warehouses,
  sections,
  workshops,
  stages,
}

class GlobalSearchResultItem {
  const GlobalSearchResultItem({
    required this.id,
    required this.entityType,
    required this.category,
    required this.title,
    this.subtitle,
    this.codeOrNumber,
    this.navigationTarget,
    this.match,
  });

  final String id;
  final GlobalSearchEntityType entityType;
  final GlobalSearchEntityCategory category;
  final String title;
  final String? subtitle;
  final String? codeOrNumber;
  final String? navigationTarget;
  final String? match;
}
