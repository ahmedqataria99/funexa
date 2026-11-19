# Local Demo Data

The developer seeder uses the normal Furnexa data sources and preserves the existing Windows app database. It targets a separate database:

`%LOCALAPPDATA%\Furnexa\demo\furnexa-demo.db`

The current Windows Release database remains `%LOCALAPPDATA%\Furnexa\furnexa.db`. The seeder prints both paths, refuses an existing unmarked database, asks for the exact confirmation phrase, and creates a timestamped backup under `%LOCALAPPDATA%\Furnexa\demo\backups` before modifying an existing marked demo database. It also refuses to seed while `furnexa.exe` is running.

## Seed

From the repository root, run:

```powershell
dart run tool/seed_demo_data.dart
```

Enter `SEED DEMO DATA <printed-demo-path>` when prompted. On a new demo database, the utility asks you to create its System Administrator account. On a previously seeded database, it asks you to sign in as that administrator. Password input is hidden, is not logged, and is not changed by the seeder. No additional demo users are created.

The seed is idempotent. Stable `DEMO-` IDs and operation IDs prevent duplicate purchases, stock movements, invoices, deliveries, payments, production consumption, and outputs when the utility is run again.

## Launch Windows Release With Demo Data

Build the Windows Release app, then run:

```powershell
.\tool\run_demo_release.ps1
```

The launcher sets `FURNEXA_DATABASE_PATH` only for that Release process. The normal executable continues using `%LOCALAPPDATA%\Furnexa\furnexa.db` unless the environment override is explicitly supplied.

## Seed Contents

The demo includes one factory, three departments, two workshops, three production stages, raw-material, work-in-progress, finished-goods, and quarantine warehouses; four raw materials; three finished products with two sofa variants; sofa and table BOMs; two suppliers and received purchase orders; three customers and three multi-line/differently priced sales orders; a posted partial invoice and payment; one partially delivered order; one pending delivery reservation; a completed production batch, a partially consumed in-progress batch, a planned order; one cashbox; and one balanced demo expense. The script retains the existing System Administrator and uses existing chart-of-accounts records.

The real `%LOCALAPPDATA%\Furnexa\furnexa.db` was inspected and contains existing business data. This work does not seed, migrate, reset, or otherwise modify that file. No demo database was written during implementation; the utility requires the operator’s explicit confirmation at runtime.
