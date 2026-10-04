# Architecture

Furnexa is organized as a feature-based Flutter application with shared cross-cutting services in `lib/core/`.

## Request Flow

```text
UI
 -> State / Controller
 -> UseCase
 -> Repository
 -> Local DataSource
 -> SQLite
```

- **UI** renders pages, forms, tables, detail views, loading states, empty states, and errors.
- **State / Controller** coordinates user actions and presentation state.
- **UseCase** expresses an application operation without binding it to widgets or storage.
- **Repository** defines the domain-facing contract and coordinates data operations.
- **Local DataSource** performs SQLite reads, writes, transactions, validation, and integration effects.
- **SQLite** is the local source of truth.

## Source Layout

```text
lib/
  core/
    constants/ database/ error/ localization/ result/ shared/
    theme/ usecase/ utils/ widgets/
  features/
    <feature>/data/
    <feature>/domain/
    <feature>/presentation/
```

Feature modules commonly contain `data/` for local data sources and repository implementations, `domain/` for entities, repository contracts, and use cases, and `presentation/` for pages and widgets. Some smaller modules expose their data source directly where that is the existing implementation.

The architecture remains local-first and does not introduce a cloud service or alternate database layer.
