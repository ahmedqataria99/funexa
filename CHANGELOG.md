# Changelog

## Furnexa v1.0.0

Initial documented product baseline for the furniture-factory ERP.

### Added

- Factory structure, materials, products, warehouses, purchasing, production, sales, delivery, HR, accounting, CRM, costing, pricing, returns and quality control.
- Users, roles, permissions, scope restrictions, audit logs, dashboard reports, documents, global search, import/export, notifications, and backup/restore.
- Offline-first SQLite persistence with versioned migrations.

### Improved

- Arabic-first RTL and English LTR support.
- Light and dark themes, Wood & Navy branding, Cairo typography, reusable tables/forms/detail pages, and desktop app shell.

### Security

- Login, salted password hashing, permission checks, scoped access, audit events, and protected backup/restore operations.

### Reporting

- Dashboard totals and operational, financial, inventory, production, HR, attendance, and audit report surfaces.

### UI/UX

- Documents, PDF generation, global search, loading/empty/error states, and backup/restore screens.

### Backup

- `.furnexa` packages, metadata, SHA-256 validation, backup history, safety backup before restore, compatibility checks, and recovery handling.

### Known Limitations

- Final Windows release verification is blocked by Flutter native `sqlite3.dll` asset installation (`PathExistsException`, Windows errno 183) before the full regression suite executes.
- The final Windows release executable and smoke test are not verified.
- No license has been defined for the repository.
