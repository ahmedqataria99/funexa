# Business Workflows

Furnexa connects factory master data, inventory, operations, documents, and accounting rather than treating each module as an isolated application.

## Purchasing

`Supplier -> Purchase Request -> Purchase Order -> Receiving -> Stock`

Supplier and item validation precede order operations. Receiving updates quantities, warehouse stock, and related valuation/status information.

## Sales

`Customer -> Quotation -> Sales Order -> Delivery -> Stock Out`

Quotation conversion and delivery use active customers, items, and warehouses. Delivery quantities update order state and stock, with valuation/accounting integration where implemented.

## Production

`Product -> BOM -> Production Route -> Production Order -> Material Consumption -> Production Stages -> Finished Product -> Warehouse`

BOM and route data define requirements. Consumption, waste, stage transitions, output, stock, and valuation are coordinated transactionally.

## Returns and Quality

`Delivery / Receiving -> Return -> Quality Control -> Accepted / Rejected -> Stock Action`

Sales and purchase returns validate their source entities. Approved return operations and quality outcomes drive the applicable stock movement. The repository layer contains these operations; a complete dedicated approval UI is not claimed.

## Costing

`Materials + Labor + Overhead + Other Costs + Waste / Scrap -> Production Cost -> Unit Cost -> Margin`

Costing combines material valuation, labor, overhead rules, other costs, scrap recovery, actual unit cost, variance, and gross margin. Labor calculation boundaries are documented in `features.md`.

## CRM

`Lead -> Activities / Follow-up -> Conversion -> Customer -> Quotation -> Sales Order`

Leads support statuses, activities, notes, follow-ups, tasks, and conversion. Conversion can reuse a matching customer by phone, email, or name.

## Integration

Products, raw materials, warehouses, customers, suppliers, workers, and factory structure provide shared master data. Purchasing, sales, production, returns, costing, notifications, documents, reports, audit, and accounting consume the resulting transactions. Global Search exposes selected permission-filtered records across operational modules.
