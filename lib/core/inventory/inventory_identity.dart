enum InventoryIdentityKind { base, variant, legacyUnassigned }

extension InventoryIdentityKindValue on InventoryIdentityKind {
  String get value => switch (this) {
    InventoryIdentityKind.base => 'BASE',
    InventoryIdentityKind.variant => 'VARIANT',
    InventoryIdentityKind.legacyUnassigned => 'LEGACY_UNASSIGNED',
  };

  static InventoryIdentityKind parse(Object? value) => switch (value) {
    'VARIANT' => InventoryIdentityKind.variant,
    'LEGACY_UNASSIGNED' => InventoryIdentityKind.legacyUnassigned,
    _ => InventoryIdentityKind.base,
  };
}
