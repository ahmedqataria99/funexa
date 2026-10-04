# Database

Furnexa is an offline-first Windows application. SQLite is the local source of truth and application operations are mediated through repositories, use cases, and local data sources.

## Runtime

- `sqflite`
- `sqflite_common_ffi`
- `sqlite3`
- SQLite FFI is initialized for Windows, Linux, and macOS desktop targets.
- Database filename: `furnexa.db`
- Current database version: `19`

## Integrity

The database uses versioned migrations, foreign-key enforcement, unique constraints, validation, and transactions. Operations that affect stock, numbering, documents, accounting, or imports use transactional behavior where implemented. Database reset helpers are used by tests for isolation.

The database is local and does not imply cloud synchronization, encryption at rest, or multi-device replication.
