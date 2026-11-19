-- Extracted from sqlite_master after Furnexa migrations 1-41.
-- Source: FurnexaDatabase.migrate on a disposable version-0 database.
-- This schema contains no business records.
PRAGMA foreign_keys = ON;
PRAGMA user_version = 41;

-- table: accounting_periods
-- Source migration: version 10
CREATE TABLE accounting_periods (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL UNIQUE,
            startDate INTEGER NOT NULL,
            endDate INTEGER NOT NULL,
            status TEXT NOT NULL CHECK(status IN ('OPEN','CLOSED')),
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            CHECK(endDate >= startDate)
          )
;

-- table: accounts
-- Source migration: version 10
CREATE TABLE accounts (
            id TEXT PRIMARY KEY,
            code TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            type TEXT NOT NULL CHECK(type IN ('ASSET','LIABILITY','EQUITY','REVENUE','EXPENSE')),
            parentId TEXT,
            description TEXT,
            active INTEGER NOT NULL DEFAULT 1,
            systemAccount INTEGER NOT NULL DEFAULT 0,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            FOREIGN KEY (parentId) REFERENCES accounts(id) ON DELETE RESTRICT
          )
;

-- table: app_setup_state
-- Source migration: version 26
CREATE TABLE app_setup_state (
            id INTEGER PRIMARY KEY CHECK(id = 1),
            completed INTEGER NOT NULL CHECK(completed IN (0, 1))
          )
;

-- table: attendance_records
-- Source migration: version 9
CREATE TABLE attendance_records (
            id TEXT PRIMARY KEY,
            workerId TEXT NOT NULL,
            shiftId TEXT NOT NULL,
            workDate INTEGER NOT NULL,
            checkIn INTEGER,
            checkOut INTEGER,
            regularHours REAL NOT NULL DEFAULT 0 CHECK(regularHours >= 0),
            overtimeHours REAL NOT NULL DEFAULT 0 CHECK(overtimeHours >= 0),
            overtimeRate REAL NOT NULL DEFAULT 0 CHECK(overtimeRate >= 0),
            overtimeAmount REAL NOT NULL DEFAULT 0 CHECK(overtimeAmount >= 0),
            lateMinutes INTEGER NOT NULL DEFAULT 0 CHECK(lateMinutes >= 0),
            earlyLeaveMinutes INTEGER NOT NULL DEFAULT 0 CHECK(earlyLeaveMinutes >= 0),
            status TEXT NOT NULL CHECK(status IN ('PRESENT','ABSENT','LEAVE','OFF_DAY','PARTIAL')),
            notes TEXT,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(workerId, workDate),
            FOREIGN KEY (workerId) REFERENCES workers(id) ON DELETE RESTRICT,
            FOREIGN KEY (shiftId) REFERENCES shifts(id) ON DELETE RESTRICT
          )
;

-- table: audit_logs
-- Source migration: version 11
CREATE TABLE audit_logs (
            id TEXT PRIMARY KEY,
            userId TEXT,
            usernameSnapshot TEXT NOT NULL,
            action TEXT NOT NULL,
            module TEXT NOT NULL,
            entityType TEXT NOT NULL,
            entityId TEXT,
            timestamp INTEGER NOT NULL,
            oldValue TEXT,
            newValue TEXT,
            description TEXT,
            FOREIGN KEY (userId) REFERENCES users(id) ON DELETE SET NULL
          )
;

-- table: bank_accounts
-- Source migration: version 10
CREATE TABLE bank_accounts (
            id TEXT PRIMARY KEY,
            bankName TEXT NOT NULL,
            accountName TEXT NOT NULL,
            accountNumber TEXT NOT NULL,
            accountId TEXT NOT NULL,
            openingBalance REAL NOT NULL DEFAULT 0 CHECK(openingBalance >= 0),
            active INTEGER NOT NULL DEFAULT 1,
            notes TEXT,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            FOREIGN KEY (accountId) REFERENCES accounts(id) ON DELETE RESTRICT
          )
;

-- table: cashboxes
-- Source migration: version 10
CREATE TABLE cashboxes (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            code TEXT NOT NULL UNIQUE,
            accountId TEXT NOT NULL,
            openingBalance REAL NOT NULL DEFAULT 0 CHECK(openingBalance >= 0),
            active INTEGER NOT NULL DEFAULT 1,
            notes TEXT,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            FOREIGN KEY (accountId) REFERENCES accounts(id) ON DELETE RESTRICT
          )
;

-- table: categories
-- Source migration: version 3
CREATE TABLE categories (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            code TEXT NOT NULL UNIQUE,
            description TEXT,
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          )
;

-- table: colors
-- Source migration: version 3
CREATE TABLE colors (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            code TEXT NOT NULL UNIQUE,
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          )
;

-- table: commercial_discount_rules
-- Source migration: version 15
CREATE TABLE commercial_discount_rules (
            id TEXT PRIMARY KEY,
            customerId TEXT,
            productId TEXT,
            variantId TEXT,
            type TEXT NOT NULL CHECK(type IN ('percentage', 'amount')),
            value REAL NOT NULL CHECK(value >= 0),
            minimumQuantity REAL NOT NULL DEFAULT 0 CHECK(minimumQuantity >= 0),
            validFrom INTEGER,
            validTo INTEGER,
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          )
;

-- table: costing_overhead_rules
-- Source migration: version 18
CREATE TABLE costing_overhead_rules (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            calculationType TEXT NOT NULL CHECK(calculationType IN ('PERCENTAGE')),
            rate REAL NOT NULL DEFAULT 0 CHECK(rate >= 0),
            base TEXT NOT NULL CHECK(base IN ('MATERIAL_COST', 'LABOR_COST', 'MATERIAL_PLUS_LABOR')),
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          )
;

-- table: crm_activities
-- Source migration: version 17
CREATE TABLE crm_activities (
            id TEXT PRIMARY KEY,
            customerId TEXT,
            leadId TEXT,
            type TEXT NOT NULL CHECK(type IN ('CALL','MEETING','WHATSAPP','EMAIL','VISIT','NOTE','OTHER')),
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            activityDate INTEGER NOT NULL,
            createdBy TEXT NOT NULL,
            relatedDocumentId TEXT,
            createdAt INTEGER NOT NULL,
            FOREIGN KEY (customerId) REFERENCES customers(id) ON DELETE RESTRICT,
            FOREIGN KEY (leadId) REFERENCES crm_leads(id) ON DELETE RESTRICT
          )
;

-- table: crm_follow_ups
-- Source migration: version 17
CREATE TABLE crm_follow_ups (
            id TEXT PRIMARY KEY,
            customerId TEXT,
            leadId TEXT,
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            dueDate INTEGER NOT NULL,
            assignedUserId TEXT NOT NULL,
            priority TEXT NOT NULL CHECK(priority IN ('LOW','MEDIUM','HIGH')),
            status TEXT NOT NULL CHECK(status IN ('PENDING','COMPLETED','CANCELLED')),
            completedAt INTEGER,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            FOREIGN KEY (customerId) REFERENCES customers(id) ON DELETE RESTRICT,
            FOREIGN KEY (leadId) REFERENCES crm_leads(id) ON DELETE RESTRICT
          )
;

-- table: crm_leads
-- Source migration: version 17
CREATE TABLE crm_leads (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            phone TEXT,
            email TEXT,
            company TEXT,
            address TEXT,
            source TEXT NOT NULL CHECK(source IN ('WEBSITE','FACEBOOK','INSTAGRAM','REFERRAL','WALK_IN','OTHER')),
            notes TEXT,
            status TEXT NOT NULL CHECK(status IN ('NEW','CONTACTED','QUALIFIED','CONVERTED','LOST')),
            assignedUserId TEXT NOT NULL,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            convertedAt INTEGER,
            convertedCustomerId TEXT
          )
;

-- table: crm_notes
-- Source migration: version 17
CREATE TABLE crm_notes (
            id TEXT PRIMARY KEY,
            customerId TEXT,
            leadId TEXT,
            content TEXT NOT NULL,
            createdBy TEXT NOT NULL,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            FOREIGN KEY (customerId) REFERENCES customers(id) ON DELETE RESTRICT,
            FOREIGN KEY (leadId) REFERENCES crm_leads(id) ON DELETE RESTRICT
          )
;

-- table: crm_tasks
-- Source migration: version 17
CREATE TABLE crm_tasks (
            id TEXT PRIMARY KEY,
            customerId TEXT,
            leadId TEXT,
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            assignedUserId TEXT NOT NULL,
            dueDate INTEGER NOT NULL,
            priority TEXT NOT NULL CHECK(priority IN ('LOW','MEDIUM','HIGH')),
            status TEXT NOT NULL CHECK(status IN ('PENDING','COMPLETED','CANCELLED')),
            completedAt INTEGER,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            FOREIGN KEY (customerId) REFERENCES customers(id) ON DELETE RESTRICT,
            FOREIGN KEY (leadId) REFERENCES crm_leads(id) ON DELETE RESTRICT
          )
;

-- table: customer_payments
-- Source migration: version 10
CREATE TABLE customer_payments (
            id TEXT PRIMARY KEY,
            customerId TEXT NOT NULL,
            date INTEGER NOT NULL,
            amount REAL NOT NULL CHECK(amount > 0),
            cashboxId TEXT,
            bankAccountId TEXT,
            reference TEXT,
            notes TEXT,
            status TEXT NOT NULL CHECK(status IN ('DRAFT','POSTED','REVERSED')),
            createdAt INTEGER NOT NULL, operationKey TEXT,
            FOREIGN KEY (customerId) REFERENCES customers(id) ON DELETE RESTRICT,
            FOREIGN KEY (cashboxId) REFERENCES cashboxes(id) ON DELETE RESTRICT,
            FOREIGN KEY (bankAccountId) REFERENCES bank_accounts(id) ON DELETE RESTRICT,
            CHECK((cashboxId IS NOT NULL AND bankAccountId IS NULL) OR (cashboxId IS NULL AND bankAccountId IS NOT NULL))
          )
;

-- table: customer_price_list_assignments
-- Source migration: version 25
CREATE TABLE customer_price_list_assignments (
            customerId TEXT PRIMARY KEY,
            priceListId TEXT NOT NULL,
            assignedAt INTEGER NOT NULL,
            FOREIGN KEY (customerId) REFERENCES customers(id) ON DELETE RESTRICT,
            FOREIGN KEY (priceListId) REFERENCES pricing_lists(id) ON DELETE RESTRICT
          )
;

-- table: customer_price_overrides
-- Source migration: version 15
CREATE TABLE customer_price_overrides (
            id TEXT PRIMARY KEY,
            customerId TEXT NOT NULL,
            productId TEXT NOT NULL,
            variantId TEXT,
            unitPrice REAL NOT NULL CHECK(unitPrice >= 0),
            currency TEXT NOT NULL DEFAULT 'SAR',
            validFrom INTEGER,
            validTo INTEGER,
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(customerId, productId, variantId),
            FOREIGN KEY (customerId) REFERENCES customers(id) ON DELETE RESTRICT
          )
;

-- table: customer_prices
-- Source migration: version 15
CREATE TABLE customer_prices (
            id TEXT PRIMARY KEY,
            customerId TEXT NOT NULL,
            productId TEXT NOT NULL,
            variantId TEXT,
            unitPrice REAL NOT NULL CHECK(unitPrice >= 0),
            currency TEXT NOT NULL DEFAULT 'SAR',
            validFrom INTEGER,
            validTo INTEGER,
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(customerId, productId, variantId),
            FOREIGN KEY (customerId) REFERENCES customers(id) ON DELETE RESTRICT
          )
;

-- table: customers
-- Source migration: version 7
CREATE TABLE customers (
            id TEXT PRIMARY KEY, name TEXT NOT NULL, code TEXT NOT NULL UNIQUE,
            phone TEXT, email TEXT, address TEXT, taxNumber TEXT, notes TEXT,
            active INTEGER NOT NULL DEFAULT 1, createdAt INTEGER NOT NULL, updatedAt INTEGER NOT NULL
          )
;

-- table: deductions
-- Source migration: version 9
CREATE TABLE deductions (
            id TEXT PRIMARY KEY,
            workerId TEXT NOT NULL,
            date INTEGER NOT NULL,
            type TEXT NOT NULL CHECK(type IN ('LATE','ABSENCE','MANUAL','OTHER')),
            amount REAL NOT NULL CHECK(amount >= 0),
            reason TEXT,
            notes TEXT,
            status TEXT NOT NULL CHECK(status IN ('PENDING','APPROVED','REJECTED')),
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            FOREIGN KEY (workerId) REFERENCES workers(id) ON DELETE RESTRICT
          )
;

-- table: discount_rules
-- Source migration: version 15
CREATE TABLE discount_rules (
            id TEXT PRIMARY KEY,
            customerId TEXT,
            productId TEXT,
            variantId TEXT,
            type TEXT NOT NULL CHECK(type IN ('percentage', 'amount')),
            value REAL NOT NULL CHECK(value >= 0),
            minimumQuantity REAL NOT NULL DEFAULT 0 CHECK(minimumQuantity >= 0),
            validFrom INTEGER,
            validTo INTEGER,
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          )
;

-- table: document_records
-- Source migration: version 13
CREATE TABLE document_records (
            documentId TEXT PRIMARY KEY,
            documentType TEXT NOT NULL,
            documentNumber TEXT NOT NULL UNIQUE,
            issueDate INTEGER NOT NULL,
            title TEXT NOT NULL,
            language TEXT NOT NULL CHECK(language IN ('ar', 'en')),
            templateType TEXT NOT NULL CHECK(templateType IN ('STANDARD', 'COMPACT', 'THERMAL')),
            status TEXT NOT NULL CHECK(status IN ('DRAFT', 'POSTED', 'CANCELLED')),
            sourceEntityType TEXT,
            sourceEntityId TEXT,
            factoryId TEXT,
            createdBy TEXT,
            createdAt INTEGER NOT NULL,
            metadata TEXT NOT NULL
          )
;

-- table: document_sequences
-- Source migration: version 13
CREATE TABLE document_sequences (
            id TEXT PRIMARY KEY,
            documentType TEXT NOT NULL,
            year INTEGER NOT NULL,
            lastNumber INTEGER NOT NULL DEFAULT 0 CHECK(lastNumber >= 0),
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(documentType, year)
          )
;

-- table: expenses
-- Source migration: version 10
CREATE TABLE expenses (
            id TEXT PRIMARY KEY,
            expenseNumber TEXT NOT NULL UNIQUE,
            date INTEGER NOT NULL,
            accountId TEXT NOT NULL,
            amount REAL NOT NULL CHECK(amount > 0),
            cashboxId TEXT,
            bankAccountId TEXT,
            description TEXT NOT NULL,
            reference TEXT,
            status TEXT NOT NULL CHECK(status IN ('DRAFT','POSTED','REVERSED')),
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            FOREIGN KEY (accountId) REFERENCES accounts(id) ON DELETE RESTRICT,
            FOREIGN KEY (cashboxId) REFERENCES cashboxes(id) ON DELETE RESTRICT,
            FOREIGN KEY (bankAccountId) REFERENCES bank_accounts(id) ON DELETE RESTRICT,
            CHECK((cashboxId IS NOT NULL AND bankAccountId IS NULL) OR (cashboxId IS NULL AND bankAccountId IS NOT NULL))
          )
;

-- table: factories
-- Source migration: version 2
CREATE TABLE factories (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            code TEXT NOT NULL UNIQUE,
            phone TEXT,
            email TEXT,
            address TEXT,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          )
;

-- table: inventory_valuations
-- Source migration: version 10
CREATE TABLE inventory_valuations (
            id TEXT PRIMARY KEY,
            warehouseId TEXT NOT NULL,
            itemId TEXT NOT NULL,
            itemType TEXT NOT NULL CHECK(itemType IN ('RAW_MATERIAL','PRODUCT')),
            quantity REAL NOT NULL DEFAULT 0 CHECK(quantity >= 0),
            averageCost REAL NOT NULL DEFAULT 0 CHECK(averageCost >= 0),
            updatedAt INTEGER NOT NULL, "productId" TEXT, "variantId" TEXT, "inventoryIdentityKind" TEXT NOT NULL DEFAULT 'BASE', "unitId" TEXT,
            UNIQUE(warehouseId, itemId, itemType),
            FOREIGN KEY (warehouseId) REFERENCES warehouses(id) ON DELETE RESTRICT
          )
;

-- table: journal_entries
-- Source migration: version 10
CREATE TABLE journal_entries (
            id TEXT PRIMARY KEY,
            entryNumber TEXT NOT NULL UNIQUE,
            date INTEGER NOT NULL,
            description TEXT NOT NULL,
            referenceType TEXT,
            referenceId TEXT,
            status TEXT NOT NULL CHECK(status IN ('DRAFT','POSTED','REVERSED')),
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(referenceType, referenceId)
          )
;

-- table: journal_lines
-- Source migration: version 10
CREATE TABLE journal_lines (
            id TEXT PRIMARY KEY,
            journalEntryId TEXT NOT NULL,
            accountId TEXT NOT NULL,
            debit REAL NOT NULL DEFAULT 0 CHECK(debit >= 0),
            credit REAL NOT NULL DEFAULT 0 CHECK(credit >= 0),
            description TEXT,
            FOREIGN KEY (journalEntryId) REFERENCES journal_entries(id) ON DELETE RESTRICT,
            FOREIGN KEY (accountId) REFERENCES accounts(id) ON DELETE RESTRICT,
            CHECK((debit > 0 AND credit = 0) OR (credit > 0 AND debit = 0))
          )
;

-- table: journal_parties
-- Source migration: version 10
CREATE TABLE journal_parties (
            journalEntryId TEXT PRIMARY KEY,
            partyType TEXT NOT NULL CHECK(partyType IN ('CUSTOMER','SUPPLIER','WORKER')),
            partyId TEXT NOT NULL,
            FOREIGN KEY (journalEntryId) REFERENCES journal_entries(id) ON DELETE RESTRICT
          )
;

-- table: leave_records
-- Source migration: version 9
CREATE TABLE leave_records (
            id TEXT PRIMARY KEY,
            workerId TEXT NOT NULL,
            leaveType TEXT NOT NULL CHECK(leaveType IN ('ANNUAL','SICK','UNPAID','OTHER')),
            startDate INTEGER NOT NULL,
            endDate INTEGER NOT NULL,
            days INTEGER NOT NULL CHECK(days >= 0),
            reason TEXT,
            status TEXT NOT NULL CHECK(status IN ('PENDING','APPROVED','REJECTED','CANCELLED')),
            notes TEXT,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            FOREIGN KEY (workerId) REFERENCES workers(id) ON DELETE RESTRICT
          )
;

-- table: notifications
-- Source migration: version 12
CREATE TABLE notifications (
            id TEXT PRIMARY KEY,
            userId TEXT NOT NULL,
            type TEXT NOT NULL,
            category TEXT NOT NULL,
            severity TEXT NOT NULL CHECK(severity IN ('INFO', 'SUCCESS', 'WARNING', 'CRITICAL')),
            title TEXT NOT NULL,
            message TEXT NOT NULL,
            isRead INTEGER NOT NULL DEFAULT 0,
            isArchived INTEGER NOT NULL DEFAULT 0,
            createdAt INTEGER NOT NULL,
            readAt INTEGER,
            archivedAt INTEGER,
            relatedEntityType TEXT,
            relatedEntityId TEXT,
            actionKey TEXT,
            deduplicationKey TEXT NOT NULL,
            UNIQUE(userId, deduplicationKey),
            FOREIGN KEY (userId) REFERENCES users(id) ON DELETE RESTRICT
          )
;

-- table: payroll_periods
-- Source migration: version 9
CREATE TABLE payroll_periods (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL UNIQUE,
            startDate INTEGER NOT NULL,
            endDate INTEGER NOT NULL,
            status TEXT NOT NULL CHECK(status IN ('DRAFT','CALCULATED','APPROVED','PAID')) DEFAULT 'DRAFT',
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          )
;

-- table: payroll_records
-- Source migration: version 9
CREATE TABLE payroll_records (
            id TEXT PRIMARY KEY,
            payrollPeriodId TEXT NOT NULL,
            workerId TEXT NOT NULL,
            basicSalary REAL NOT NULL CHECK(basicSalary >= 0),
            regularEarnings REAL NOT NULL CHECK(regularEarnings >= 0),
            overtimeHours REAL NOT NULL DEFAULT 0 CHECK(overtimeHours >= 0),
            overtimeAmount REAL NOT NULL DEFAULT 0 CHECK(overtimeAmount >= 0),
            deductionsAmount REAL NOT NULL DEFAULT 0 CHECK(deductionsAmount >= 0),
            grossSalary REAL NOT NULL CHECK(grossSalary >= 0),
            netSalary REAL NOT NULL CHECK(netSalary >= 0),
            notes TEXT,
            status TEXT NOT NULL CHECK(status IN ('DRAFT','CALCULATED','APPROVED','PAID')),
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(payrollPeriodId, workerId),
            FOREIGN KEY (payrollPeriodId) REFERENCES payroll_periods(id) ON DELETE RESTRICT,
            FOREIGN KEY (workerId) REFERENCES workers(id) ON DELETE RESTRICT
          )
;

-- table: permissions
-- Source migration: version 11
CREATE TABLE permissions (
            id TEXT PRIMARY KEY,
            code TEXT NOT NULL UNIQUE,
            module TEXT NOT NULL,
            action TEXT NOT NULL,
            description TEXT
          )
;

-- table: price_history
-- Source migration: version 15
CREATE TABLE price_history (
            id TEXT PRIMARY KEY,
            entityType TEXT NOT NULL,
            entityId TEXT NOT NULL,
            productId TEXT NOT NULL,
            variantId TEXT,
            unitPrice REAL NOT NULL CHECK(unitPrice >= 0),
            discountAmount REAL NOT NULL DEFAULT 0,
            finalPrice REAL NOT NULL CHECK(finalPrice >= 0),
            effectiveAt INTEGER NOT NULL,
            createdAt INTEGER NOT NULL
          )
;

-- table: price_lists
-- Source migration: version 15
CREATE TABLE price_lists (
            id TEXT PRIMARY KEY,
            code TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            description TEXT,
            validFrom INTEGER,
            validTo INTEGER,
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          , isDefault INTEGER NOT NULL DEFAULT 0 CHECK(isDefault IN (0, 1)))
;

-- table: price_tiers
-- Source migration: version 15
CREATE TABLE price_tiers (
            id TEXT PRIMARY KEY,
            priceListId TEXT,
            productId TEXT NOT NULL,
            variantId TEXT,
            minimumQuantity REAL NOT NULL CHECK(minimumQuantity >= 0),
            unitPrice REAL NOT NULL CHECK(unitPrice >= 0),
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(priceListId, productId, variantId, minimumQuantity)
          )
;

-- table: pricing_history
-- Source migration: version 15
CREATE TABLE pricing_history (
            id TEXT PRIMARY KEY,
            entityType TEXT NOT NULL,
            entityId TEXT NOT NULL,
            productId TEXT NOT NULL,
            variantId TEXT,
            unitPrice REAL NOT NULL CHECK(unitPrice >= 0),
            discountAmount REAL NOT NULL DEFAULT 0,
            finalPrice REAL NOT NULL CHECK(finalPrice >= 0),
            effectiveAt INTEGER NOT NULL,
            createdAt INTEGER NOT NULL
          )
;

-- table: pricing_lists
-- Source migration: version 15
CREATE TABLE pricing_lists (
            id TEXT PRIMARY KEY,
            code TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            description TEXT,
            validFrom INTEGER,
            validTo INTEGER,
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          , isDefault INTEGER NOT NULL DEFAULT 0 CHECK(isDefault IN (0, 1)))
;

-- table: pricing_product_prices
-- Source migration: version 15
CREATE TABLE pricing_product_prices (
            id TEXT PRIMARY KEY,
            priceListId TEXT NOT NULL,
            productId TEXT NOT NULL,
            variantId TEXT,
            unitPrice REAL NOT NULL CHECK(unitPrice >= 0),
            currency TEXT NOT NULL DEFAULT 'SAR',
            validFrom INTEGER,
            validTo INTEGER,
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(priceListId, productId, variantId),
            FOREIGN KEY (priceListId) REFERENCES pricing_lists(id) ON DELETE RESTRICT
          )
;

-- table: pricing_tiers
-- Source migration: version 15
CREATE TABLE pricing_tiers (
            id TEXT PRIMARY KEY,
            priceListId TEXT,
            productId TEXT NOT NULL,
            variantId TEXT,
            minimumQuantity REAL NOT NULL CHECK(minimumQuantity >= 0),
            unitPrice REAL NOT NULL CHECK(unitPrice >= 0),
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(priceListId, productId, variantId, minimumQuantity)
          )
;

-- table: product_alternatives
-- Source migration: version 27
CREATE TABLE product_alternatives (
            id TEXT PRIMARY KEY,
            sourceProductId TEXT NOT NULL,
            targetProductId TEXT NOT NULL,
            priority INTEGER NOT NULL CHECK(priority > 0),
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(sourceProductId, targetProductId),
            UNIQUE(sourceProductId, priority),
            CHECK(sourceProductId != targetProductId),
            FOREIGN KEY (sourceProductId) REFERENCES products(id) ON DELETE RESTRICT,
            FOREIGN KEY (targetProductId) REFERENCES products(id) ON DELETE RESTRICT
          )
;

-- table: product_bom_items
-- Source migration: version 3
CREATE TABLE product_bom_items (
            id TEXT PRIMARY KEY,
            productId TEXT NOT NULL,
            rawMaterialId TEXT NOT NULL,
            quantity REAL NOT NULL CHECK(quantity > 0),
            notes TEXT,
            UNIQUE(productId, rawMaterialId),
            FOREIGN KEY (productId) REFERENCES products(id) ON DELETE RESTRICT,
            FOREIGN KEY (rawMaterialId) REFERENCES raw_materials(id) ON DELETE RESTRICT
          )
;

-- table: product_dimensions
-- Source migration: version 3
CREATE TABLE product_dimensions (
            id TEXT PRIMARY KEY,
            productId TEXT NOT NULL,
            variantId TEXT,
            length REAL,
            width REAL,
            height REAL,
            unit TEXT,
            UNIQUE(productId, variantId),
            FOREIGN KEY (productId) REFERENCES products(id) ON DELETE RESTRICT,
            FOREIGN KEY (variantId) REFERENCES product_variants(id) ON DELETE RESTRICT
          )
;

-- table: product_prices
-- Source migration: version 15
CREATE TABLE product_prices (
            id TEXT PRIMARY KEY,
            priceListId TEXT NOT NULL,
            productId TEXT NOT NULL,
            variantId TEXT,
            unitPrice REAL NOT NULL CHECK(unitPrice >= 0),
            currency TEXT NOT NULL DEFAULT 'SAR',
            validFrom INTEGER,
            validTo INTEGER,
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(priceListId, productId, variantId),
            FOREIGN KEY (priceListId) REFERENCES pricing_lists(id) ON DELETE RESTRICT
          )
;

-- table: product_unit_conversions
-- Source migration: version 34
CREATE TABLE product_unit_conversions (
            id TEXT PRIMARY KEY,
            productId TEXT NOT NULL,
            unitId TEXT NOT NULL,
            factorToBase REAL NOT NULL CHECK(factorToBase > 0),
            active INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0, 1)),
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(productId, unitId),
            FOREIGN KEY (productId) REFERENCES products(id) ON DELETE RESTRICT,
            FOREIGN KEY (unitId) REFERENCES units(id) ON DELETE RESTRICT
          )
;

-- table: product_variants
-- Source migration: version 3
CREATE TABLE product_variants (
            id TEXT PRIMARY KEY,
            productId TEXT NOT NULL,
            name TEXT NOT NULL,
            code TEXT NOT NULL,
            colorId TEXT,
            description TEXT,
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(productId, code),
            FOREIGN KEY (productId) REFERENCES products(id) ON DELETE RESTRICT,
            FOREIGN KEY (colorId) REFERENCES colors(id) ON DELETE RESTRICT
          )
;

-- table: production_batch_costs
-- Source migration: version 18
CREATE TABLE production_batch_costs (
            id TEXT PRIMARY KEY,
            productionOrderId TEXT NOT NULL UNIQUE,
            productId TEXT NOT NULL,
            plannedQuantity REAL NOT NULL DEFAULT 0 CHECK(plannedQuantity >= 0),
            goodFinishedQuantity REAL NOT NULL DEFAULT 0 CHECK(goodFinishedQuantity >= 0),
            materialCost REAL NOT NULL DEFAULT 0,
            laborCost REAL NOT NULL DEFAULT 0,
            overheadCost REAL NOT NULL DEFAULT 0,
            otherCost REAL NOT NULL DEFAULT 0,
            scrapRecovery REAL NOT NULL DEFAULT 0,
            totalCost REAL NOT NULL DEFAULT 0,
            actualUnitCost REAL NOT NULL DEFAULT 0,
            estimatedCost REAL NOT NULL DEFAULT 0,
            estimatedUnitCost REAL NOT NULL DEFAULT 0,
            status TEXT NOT NULL CHECK(status IN ('DRAFT', 'CALCULATED', 'FINALIZED')) DEFAULT 'DRAFT',
            calculatedAt INTEGER,
            finalizedAt INTEGER,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            FOREIGN KEY (productionOrderId) REFERENCES production_orders(id) ON DELETE RESTRICT,
            FOREIGN KEY (productId) REFERENCES products(id) ON DELETE RESTRICT
          )
;

-- table: production_cost_adjustments
-- Source migration: version 18
CREATE TABLE production_cost_adjustments (
            id TEXT PRIMARY KEY,
            productionOrderId TEXT NOT NULL,
            productId TEXT NOT NULL,
            adjustmentType TEXT NOT NULL CHECK(adjustmentType IN ('INCREASE', 'DECREASE')),
            amount REAL NOT NULL CHECK(amount >= 0),
            reason TEXT NOT NULL,
            createdBy TEXT,
            createdAt INTEGER NOT NULL,
            FOREIGN KEY (productionOrderId) REFERENCES production_orders(id) ON DELETE RESTRICT,
            FOREIGN KEY (productId) REFERENCES products(id) ON DELETE RESTRICT
          )
;

-- table: production_material_consumptions
-- Source migration: version 8
CREATE TABLE production_material_consumptions (
            id TEXT PRIMARY KEY,
            productionOrderId TEXT NOT NULL,
            rawMaterialId TEXT NOT NULL,
            warehouseId TEXT NOT NULL,
            quantity REAL NOT NULL CHECK(quantity > 0),
            unitId TEXT NOT NULL,
            consumptionDate INTEGER NOT NULL,
            notes TEXT,
            createdAt INTEGER NOT NULL, unitCost REAL NOT NULL DEFAULT 0 CHECK(unitCost >= 0), operationId TEXT,
            FOREIGN KEY (productionOrderId) REFERENCES production_orders(id) ON DELETE RESTRICT,
            FOREIGN KEY (rawMaterialId) REFERENCES raw_materials(id) ON DELETE RESTRICT,
            FOREIGN KEY (warehouseId) REFERENCES warehouses(id) ON DELETE RESTRICT,
            FOREIGN KEY (unitId) REFERENCES units(id) ON DELETE RESTRICT
          )
;

-- table: production_order_bom_items
-- Source migration: version 21
CREATE TABLE production_order_bom_items (
            id TEXT PRIMARY KEY,
            productionOrderId TEXT NOT NULL,
            rawMaterialId TEXT NOT NULL,
            unitId TEXT NOT NULL,
            quantity REAL NOT NULL CHECK(quantity > 0),
            notes TEXT,
            UNIQUE(productionOrderId, rawMaterialId),
            FOREIGN KEY (productionOrderId) REFERENCES production_orders(id) ON DELETE RESTRICT,
            FOREIGN KEY (rawMaterialId) REFERENCES raw_materials(id) ON DELETE RESTRICT,
            FOREIGN KEY (unitId) REFERENCES units(id) ON DELETE RESTRICT
          )
;

-- table: production_order_labor_allocations
-- Source migration: version 21
CREATE TABLE production_order_labor_allocations (
            id TEXT PRIMARY KEY,
            productionOrderId TEXT NOT NULL,
            attendanceId TEXT NOT NULL,
            regularHours REAL NOT NULL CHECK(regularHours >= 0),
            overtimeHours REAL NOT NULL CHECK(overtimeHours >= 0),
            createdAt INTEGER NOT NULL,
            FOREIGN KEY (productionOrderId) REFERENCES production_orders(id) ON DELETE RESTRICT,
            FOREIGN KEY (attendanceId) REFERENCES attendance_records(id) ON DELETE RESTRICT
          )
;

-- table: production_order_stages
-- Source migration: version 8
CREATE TABLE production_order_stages (
            id TEXT PRIMARY KEY,
            productionOrderId TEXT NOT NULL,
            productionStageId TEXT NOT NULL,
            sequence INTEGER NOT NULL CHECK(sequence > 0),
            status TEXT NOT NULL CHECK(status IN ('PENDING','IN_PROGRESS','COMPLETED','SKIPPED')),
            startedAt INTEGER,
            completedAt INTEGER,
            notes TEXT,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(productionOrderId, productionStageId),
            UNIQUE(productionOrderId, sequence),
            FOREIGN KEY (productionOrderId) REFERENCES production_orders(id) ON DELETE RESTRICT,
            FOREIGN KEY (productionStageId) REFERENCES production_stages(id) ON DELETE RESTRICT
          )
;

-- table: production_orders
-- Source migration: version 8
CREATE TABLE production_orders (
            id TEXT PRIMARY KEY,
            orderNumber TEXT NOT NULL UNIQUE,
            productId TEXT NOT NULL,
            variantId TEXT,
            routeId TEXT NOT NULL,
            plannedQuantity REAL NOT NULL CHECK(plannedQuantity > 0),
            producedQuantity REAL NOT NULL DEFAULT 0 CHECK(producedQuantity >= 0),
            status TEXT NOT NULL CHECK(status IN ('DRAFT','PLANNED','IN_PROGRESS','COMPLETED','CANCELLED')),
            startDate INTEGER,
            completionDate INTEGER,
            notes TEXT,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL, "unitId" TEXT REFERENCES units(id) ON DELETE RESTRICT, "baseUnitId" TEXT REFERENCES units(id) ON DELETE RESTRICT, "unitConversionFactor" REAL CHECK(unitConversionFactor IS NULL OR unitConversionFactor > 0), "plannedBaseQuantity" REAL CHECK(plannedBaseQuantity IS NULL OR plannedBaseQuantity > 0), "unitSnapshotStatus" TEXT NOT NULL DEFAULT 'UNVERIFIED' CHECK(unitSnapshotStatus IN ('VERIFIED', 'UNVERIFIED') AND (unitSnapshotStatus != 'VERIFIED' OR (unitId IS NOT NULL AND baseUnitId IS NOT NULL AND unitConversionFactor IS NOT NULL AND plannedBaseQuantity IS NOT NULL))),
            FOREIGN KEY (productId) REFERENCES products(id) ON DELETE RESTRICT,
            FOREIGN KEY (variantId) REFERENCES product_variants(id) ON DELETE RESTRICT,
            FOREIGN KEY (routeId) REFERENCES production_routes(id) ON DELETE RESTRICT
          )
;

-- table: production_other_costs
-- Source migration: version 18
CREATE TABLE production_other_costs (
            id TEXT PRIMARY KEY,
            productionOrderId TEXT NOT NULL,
            description TEXT NOT NULL,
            amount REAL NOT NULL CHECK(amount >= 0),
            date INTEGER NOT NULL,
            createdBy TEXT,
            createdAt INTEGER NOT NULL,
            FOREIGN KEY (productionOrderId) REFERENCES production_orders(id) ON DELETE RESTRICT
          )
;

-- table: production_outputs
-- Source migration: version 8
CREATE TABLE production_outputs (
            id TEXT PRIMARY KEY,
            productionOrderId TEXT NOT NULL,
            warehouseId TEXT NOT NULL,
            quantity REAL NOT NULL CHECK(quantity > 0),
            unitId TEXT NOT NULL,
            outputDate INTEGER NOT NULL,
            notes TEXT,
            createdAt INTEGER NOT NULL, operationId TEXT, "productId" TEXT, "variantId" TEXT, "baseUnitId" TEXT, "unitConversionFactor" REAL NOT NULL DEFAULT 1, "baseQuantity" REAL NOT NULL DEFAULT 0, "inventoryIdentityKind" TEXT NOT NULL DEFAULT 'BASE', "identitySnapshotStatus" TEXT NOT NULL DEFAULT 'UNVERIFIED',
            FOREIGN KEY (productionOrderId) REFERENCES production_orders(id) ON DELETE RESTRICT,
            FOREIGN KEY (warehouseId) REFERENCES warehouses(id) ON DELETE RESTRICT,
            FOREIGN KEY (unitId) REFERENCES units(id) ON DELETE RESTRICT
          )
;

-- table: production_route_stages
-- Source migration: version 8
CREATE TABLE production_route_stages (
            id TEXT PRIMARY KEY,
            routeId TEXT NOT NULL,
            productionStageId TEXT NOT NULL,
            sequence INTEGER NOT NULL CHECK(sequence > 0),
            notes TEXT,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(routeId, productionStageId),
            UNIQUE(routeId, sequence),
            FOREIGN KEY (routeId) REFERENCES production_routes(id) ON DELETE RESTRICT,
            FOREIGN KEY (productionStageId) REFERENCES production_stages(id) ON DELETE RESTRICT
          )
;

-- table: production_routes
-- Source migration: version 8
CREATE TABLE production_routes (
            id TEXT PRIMARY KEY,
            productId TEXT NOT NULL UNIQUE,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            FOREIGN KEY (productId) REFERENCES products(id) ON DELETE RESTRICT
          )
;

-- table: production_stages
-- Source migration: version 2
CREATE TABLE production_stages (
            id TEXT PRIMARY KEY,
            factoryId TEXT NOT NULL,
            name TEXT NOT NULL,
            code TEXT NOT NULL,
            description TEXT,
            sequence INTEGER NOT NULL,
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(factoryId, code),
            FOREIGN KEY (factoryId) REFERENCES factories(id) ON DELETE RESTRICT
          )
;

-- table: production_waste
-- Source migration: version 8
CREATE TABLE production_waste (
            id TEXT PRIMARY KEY,
            productionOrderId TEXT NOT NULL,
            rawMaterialId TEXT NOT NULL,
            warehouseId TEXT NOT NULL,
            quantity REAL NOT NULL CHECK(quantity > 0),
            unitId TEXT NOT NULL,
            reason TEXT NOT NULL,
            notes TEXT,
            wasteDate INTEGER NOT NULL,
            createdAt INTEGER NOT NULL,
            FOREIGN KEY (productionOrderId) REFERENCES production_orders(id) ON DELETE RESTRICT,
            FOREIGN KEY (rawMaterialId) REFERENCES raw_materials(id) ON DELETE RESTRICT,
            FOREIGN KEY (warehouseId) REFERENCES warehouses(id) ON DELETE RESTRICT,
            FOREIGN KEY (unitId) REFERENCES units(id) ON DELETE RESTRICT
          )
;

-- table: products
-- Source migration: version 3
CREATE TABLE products (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            code TEXT NOT NULL UNIQUE,
            categoryId TEXT NOT NULL,
            unitId TEXT NOT NULL,
            description TEXT,
            productState TEXT NOT NULL DEFAULT 'unfinished',
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            FOREIGN KEY (categoryId) REFERENCES categories(id) ON DELETE RESTRICT,
            FOREIGN KEY (unitId) REFERENCES units(id) ON DELETE RESTRICT
          )
;

-- table: purchase_order_items
-- Source migration: version 6
CREATE TABLE "purchase_order_items" (
            id TEXT PRIMARY KEY,
            purchaseOrderId TEXT NOT NULL,
            itemId TEXT NOT NULL,
            itemType TEXT NOT NULL CHECK(itemType IN ('RAW_MATERIAL','PRODUCT')),
            quantity REAL NOT NULL CHECK(quantity > 0),
            unitId TEXT NOT NULL,
            unitPrice REAL NOT NULL CHECK(unitPrice >= 0),
            discount REAL NOT NULL DEFAULT 0,
            tax REAL NOT NULL DEFAULT 0,
            lineTotal REAL NOT NULL DEFAULT 0,
            receivedQuantity REAL NOT NULL DEFAULT 0 CHECK(receivedQuantity >= 0),
            notes TEXT, "productId" TEXT, "variantId" TEXT, "baseUnitId" TEXT, "unitConversionFactor" REAL NOT NULL DEFAULT 1, "baseQuantity" REAL NOT NULL DEFAULT 0, "inventoryIdentityKind" TEXT NOT NULL DEFAULT 'BASE', "identitySnapshotStatus" TEXT NOT NULL DEFAULT 'UNVERIFIED', "receivedBaseQuantity" REAL NOT NULL DEFAULT 0,
            UNIQUE(purchaseOrderId, itemId, itemType),
            FOREIGN KEY (purchaseOrderId) REFERENCES "purchase_orders"(id) ON DELETE RESTRICT,
            FOREIGN KEY (unitId) REFERENCES units(id) ON DELETE RESTRICT
          )
;

-- table: purchase_orders
-- Source migration: version 6
CREATE TABLE "purchase_orders" (
            id TEXT PRIMARY KEY,
            orderNumber TEXT NOT NULL UNIQUE,
            supplierId TEXT NOT NULL,
            purchaseRequestId TEXT,
            orderDate INTEGER NOT NULL,
            expectedDeliveryDate INTEGER,
            status TEXT NOT NULL CHECK(status IN ('DRAFT','APPROVED','PARTIALLY_RECEIVED','FULLY_RECEIVED','CANCELLED')),
            subtotal REAL NOT NULL DEFAULT 0,
            discount REAL NOT NULL DEFAULT 0,
            tax REAL NOT NULL DEFAULT 0,
            grandTotal REAL NOT NULL DEFAULT 0,
            notes TEXT,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            FOREIGN KEY (supplierId) REFERENCES suppliers(id) ON DELETE RESTRICT,
            FOREIGN KEY (purchaseRequestId) REFERENCES purchase_requests(id) ON DELETE RESTRICT
          )
;

-- table: purchase_receipt_items
-- Source migration: version 6
CREATE TABLE "purchase_receipt_items" (
            id TEXT PRIMARY KEY,
            purchaseReceiptId TEXT NOT NULL,
            purchaseOrderItemId TEXT NOT NULL,
            receivedQuantity REAL NOT NULL CHECK(receivedQuantity > 0),
            unitId TEXT NOT NULL,
            notes TEXT, "productId" TEXT, "variantId" TEXT, "baseUnitId" TEXT, "unitConversionFactor" REAL NOT NULL DEFAULT 1, "baseQuantity" REAL NOT NULL DEFAULT 0, "inventoryIdentityKind" TEXT NOT NULL DEFAULT 'BASE', "identitySnapshotStatus" TEXT NOT NULL DEFAULT 'UNVERIFIED',
            FOREIGN KEY (purchaseReceiptId) REFERENCES "purchase_receipts"(id) ON DELETE RESTRICT,
            FOREIGN KEY (purchaseOrderItemId) REFERENCES "purchase_order_items"(id) ON DELETE RESTRICT,
            FOREIGN KEY (unitId) REFERENCES units(id) ON DELETE RESTRICT
          )
;

-- table: purchase_receipts
-- Source migration: version 6
CREATE TABLE "purchase_receipts" (
            id TEXT PRIMARY KEY,
            receiptNumber TEXT NOT NULL UNIQUE,
            purchaseOrderId TEXT NOT NULL,
            warehouseId TEXT NOT NULL,
            receiptDate INTEGER NOT NULL,
            notes TEXT,
            createdAt INTEGER NOT NULL,
            receivedBy TEXT,
            FOREIGN KEY (purchaseOrderId) REFERENCES "purchase_orders"(id) ON DELETE RESTRICT,
            FOREIGN KEY (warehouseId) REFERENCES warehouses(id) ON DELETE RESTRICT
          )
;

-- table: purchase_request_items
-- Source migration: version 6
CREATE TABLE purchase_request_items (
            id TEXT PRIMARY KEY,
            purchaseRequestId TEXT NOT NULL,
            itemId TEXT NOT NULL,
            itemType TEXT NOT NULL CHECK(itemType IN ('RAW_MATERIAL','PRODUCT')),
            quantity REAL NOT NULL CHECK(quantity > 0),
            unitId TEXT NOT NULL,
            notes TEXT, "productId" TEXT, "variantId" TEXT, "baseUnitId" TEXT, "unitConversionFactor" REAL NOT NULL DEFAULT 1, "baseQuantity" REAL NOT NULL DEFAULT 0, "inventoryIdentityKind" TEXT NOT NULL DEFAULT 'BASE', "identitySnapshotStatus" TEXT NOT NULL DEFAULT 'UNVERIFIED',
            UNIQUE(purchaseRequestId, itemId, itemType),
            FOREIGN KEY (purchaseRequestId) REFERENCES purchase_requests(id) ON DELETE RESTRICT,
            FOREIGN KEY (unitId) REFERENCES units(id) ON DELETE RESTRICT
          )
;

-- table: purchase_requests
-- Source migration: version 6
CREATE TABLE purchase_requests (
            id TEXT PRIMARY KEY,
            requestNumber TEXT NOT NULL UNIQUE,
            requestDate INTEGER NOT NULL,
            supplierId TEXT NOT NULL,
            requestedBy TEXT NOT NULL,
            notes TEXT,
            status TEXT NOT NULL CHECK(status IN ('DRAFT','PENDING','APPROVED','REJECTED','CONVERTED','CANCELLED')),
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            FOREIGN KEY (supplierId) REFERENCES suppliers(id) ON DELETE RESTRICT
          )
;

-- table: purchase_return_handover_items
-- Source migration: version 39
CREATE TABLE purchase_return_handover_items (
            id TEXT PRIMARY KEY,
            handoverId TEXT NOT NULL,
            purchaseReturnItemId TEXT NOT NULL,
            purchaseReturnReceiptItemId TEXT NOT NULL,
            quantity REAL NOT NULL CHECK(quantity > 0),
            baseQuantity REAL NOT NULL CHECK(baseQuantity > 0),
            movementReference TEXT NOT NULL UNIQUE,
            createdAt INTEGER NOT NULL,
            FOREIGN KEY (handoverId) REFERENCES purchase_return_handovers(id) ON DELETE CASCADE,
            FOREIGN KEY (purchaseReturnItemId) REFERENCES purchase_return_items(id) ON DELETE RESTRICT,
            FOREIGN KEY (purchaseReturnReceiptItemId) REFERENCES purchase_return_receipt_items(id) ON DELETE RESTRICT
          )
;

-- table: purchase_return_handovers
-- Source migration: version 39
CREATE TABLE purchase_return_handovers (
            id TEXT PRIMARY KEY,
            handoverNumber TEXT NOT NULL UNIQUE,
            purchaseReturnId TEXT NOT NULL,
            supplierId TEXT NOT NULL,
            warehouseId TEXT NOT NULL,
            handoverDate INTEGER NOT NULL,
            performedBy TEXT,
            notes TEXT,
            journalEntryId TEXT UNIQUE,
            createdAt INTEGER NOT NULL,
            FOREIGN KEY (purchaseReturnId) REFERENCES purchase_returns(id) ON DELETE RESTRICT,
            FOREIGN KEY (supplierId) REFERENCES suppliers(id) ON DELETE RESTRICT,
            FOREIGN KEY (warehouseId) REFERENCES warehouses(id) ON DELETE RESTRICT,
            FOREIGN KEY (journalEntryId) REFERENCES journal_entries(id) ON DELETE RESTRICT
          )
;

-- table: purchase_return_items
-- Source migration: version 16
CREATE TABLE "purchase_return_items" (
            id TEXT PRIMARY KEY,
            purchaseReturnId TEXT NOT NULL,
            itemId TEXT NOT NULL,
            itemType TEXT NOT NULL CHECK(itemType IN ('PRODUCT', 'RAW_MATERIAL')),
            quantity REAL NOT NULL CHECK(quantity >= 0),
            unitId TEXT NOT NULL,
            unitPrice REAL NOT NULL DEFAULT 0,
            reason TEXT,
            qualityStatus TEXT NOT NULL CHECK(qualityStatus IN ('PENDING', 'APPROVED', 'REJECTED', 'QUARANTINED')) DEFAULT 'PENDING',
            createdAt INTEGER NOT NULL, "productId" TEXT, "variantId" TEXT, "baseUnitId" TEXT, "unitConversionFactor" REAL NOT NULL DEFAULT 1, "baseQuantity" REAL NOT NULL DEFAULT 0, "inventoryIdentityKind" TEXT NOT NULL DEFAULT 'BASE', "identitySnapshotStatus" TEXT NOT NULL DEFAULT 'UNVERIFIED', "purchaseOrderItemId" TEXT, "sourceReceiptId" TEXT,
            FOREIGN KEY (purchaseReturnId) REFERENCES "purchase_returns"(id) ON DELETE CASCADE
          )
;

-- table: purchase_return_receipt_items
-- Source migration: version 39
CREATE TABLE purchase_return_receipt_items (
            id TEXT PRIMARY KEY,
            receiptId TEXT NOT NULL,
            purchaseReturnItemId TEXT NOT NULL,
            quantity REAL NOT NULL CHECK(quantity > 0),
            baseQuantity REAL NOT NULL CHECK(baseQuantity > 0),
            movementReference TEXT NOT NULL UNIQUE,
            UNIQUE(receiptId, purchaseReturnItemId),
            FOREIGN KEY (receiptId) REFERENCES purchase_return_receipts(id) ON DELETE CASCADE,
            FOREIGN KEY (purchaseReturnItemId) REFERENCES purchase_return_items(id) ON DELETE RESTRICT
          )
;

-- table: purchase_return_receipts
-- Source migration: version 39
CREATE TABLE purchase_return_receipts (
            id TEXT PRIMARY KEY,
            receiptNumber TEXT NOT NULL UNIQUE,
            purchaseReturnId TEXT NOT NULL,
            warehouseId TEXT NOT NULL,
            receiptDate INTEGER NOT NULL,
            receivedBy TEXT,
            notes TEXT,
            createdAt INTEGER NOT NULL,
            FOREIGN KEY (purchaseReturnId) REFERENCES purchase_returns(id) ON DELETE RESTRICT,
            FOREIGN KEY (warehouseId) REFERENCES warehouses(id) ON DELETE RESTRICT
          )
;

-- table: purchase_returns
-- Source migration: version 16
CREATE TABLE "purchase_returns" (
            id TEXT PRIMARY KEY,
            returnNumber TEXT NOT NULL UNIQUE,
            purchaseOrderId TEXT NOT NULL,
            purchaseReceiptId TEXT,
            supplierId TEXT NOT NULL,
            warehouseId TEXT NOT NULL,
            returnDate INTEGER NOT NULL,
            reason TEXT,
            status TEXT NOT NULL CHECK(status IN ('DRAFT', 'PENDING', 'APPROVED', 'REJECTED', 'COMPLETED', 'CANCELLED')) DEFAULT 'PENDING',
            notes TEXT,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL, "approvedBy" TEXT, "approvedAt" INTEGER, "approvalNotes" TEXT,
            FOREIGN KEY (purchaseOrderId) REFERENCES "purchase_orders"(id) ON DELETE RESTRICT,
            FOREIGN KEY (supplierId) REFERENCES suppliers(id) ON DELETE RESTRICT,
            FOREIGN KEY (warehouseId) REFERENCES warehouses(id) ON DELETE RESTRICT
          )
;

-- table: quality_inspection_items
-- Source migration: version 16
CREATE TABLE quality_inspection_items (
            id TEXT PRIMARY KEY,
            inspectionId TEXT NOT NULL,
            itemId TEXT NOT NULL,
            itemType TEXT NOT NULL CHECK(itemType IN ('PRODUCT', 'RAW_MATERIAL')),
            requestedQuantity REAL NOT NULL CHECK(requestedQuantity >= 0),
            inspectedQuantity REAL NOT NULL CHECK(inspectedQuantity >= 0),
            acceptedQuantity REAL NOT NULL CHECK(acceptedQuantity >= 0),
            rejectedQuantity REAL NOT NULL CHECK(rejectedQuantity >= 0),
            result TEXT NOT NULL CHECK(result IN ('PASSED', 'FAILED', 'QUARANTINED', 'REJECTED')) DEFAULT 'PASSED',
            notes TEXT,
            createdAt INTEGER NOT NULL, "productId" TEXT, "variantId" TEXT, "inventoryIdentityKind" TEXT NOT NULL DEFAULT 'BASE', "sourceReturnItemId" TEXT, "identitySnapshotStatus" TEXT NOT NULL DEFAULT 'UNVERIFIED', "unitId" TEXT, "baseUnitId" TEXT, "unitConversionFactor" REAL NOT NULL DEFAULT 1, "requestedBaseQuantity" REAL NOT NULL DEFAULT 0, "inspectedBaseQuantity" REAL NOT NULL DEFAULT 0, "acceptedBaseQuantity" REAL NOT NULL DEFAULT 0, "rejectedBaseQuantity" REAL NOT NULL DEFAULT 0, "purchaseReturnReceiptItemId" TEXT REFERENCES purchase_return_receipt_items(id) ON DELETE RESTRICT, "quarantinedQuantity" REAL NOT NULL DEFAULT 0, "quarantinedBaseQuantity" REAL NOT NULL DEFAULT 0,
            FOREIGN KEY (inspectionId) REFERENCES quality_inspections(id) ON DELETE CASCADE
          )
;

-- table: quality_inspections
-- Source migration: version 16
CREATE TABLE quality_inspections (
            id TEXT PRIMARY KEY,
            inspectionNumber TEXT NOT NULL UNIQUE,
            sourceType TEXT NOT NULL,
            sourceId TEXT NOT NULL,
            warehouseId TEXT,
            itemId TEXT NOT NULL,
            itemType TEXT NOT NULL CHECK(itemType IN ('PRODUCT', 'RAW_MATERIAL')),
            inspectedBy TEXT,
            inspectionDate INTEGER NOT NULL,
            status TEXT NOT NULL CHECK(status IN ('PENDING', 'IN_PROGRESS', 'COMPLETED', 'REJECTED', 'QUARANTINED')) DEFAULT 'PENDING',
            result TEXT NOT NULL CHECK(result IN ('PASSED', 'FAILED', 'QUARANTINED', 'REJECTED')) DEFAULT 'PASSED',
            notes TEXT,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          , "productId" TEXT, "variantId" TEXT, "inventoryIdentityKind" TEXT NOT NULL DEFAULT 'BASE', "purchaseReturnReceiptId" TEXT REFERENCES purchase_return_receipts(id) ON DELETE RESTRICT)
;

-- table: quotation_items
-- Source migration: version 7
CREATE TABLE quotation_items (
            id TEXT PRIMARY KEY, quotationId TEXT NOT NULL, itemId TEXT NOT NULL,
            itemType TEXT NOT NULL CHECK(itemType IN ('PRODUCT','RAW_MATERIAL')),
            quantity REAL NOT NULL CHECK(quantity > 0), unitId TEXT NOT NULL, unitPrice REAL NOT NULL CHECK(unitPrice >= 0),
            discount REAL NOT NULL DEFAULT 0, tax REAL NOT NULL DEFAULT 0, lineTotal REAL NOT NULL DEFAULT 0, notes TEXT, "productId" TEXT, "variantId" TEXT, "baseUnitId" TEXT, "unitConversionFactor" REAL NOT NULL DEFAULT 1, "baseQuantity" REAL NOT NULL DEFAULT 0, "inventoryIdentityKind" TEXT NOT NULL DEFAULT 'BASE', "identitySnapshotStatus" TEXT NOT NULL DEFAULT 'UNVERIFIED',
            UNIQUE(quotationId, itemId, itemType), FOREIGN KEY (quotationId) REFERENCES quotations(id) ON DELETE RESTRICT,
            FOREIGN KEY (unitId) REFERENCES units(id) ON DELETE RESTRICT
          )
;

-- table: quotations
-- Source migration: version 7
CREATE TABLE quotations (
            id TEXT PRIMARY KEY, quotationNumber TEXT NOT NULL UNIQUE, customerId TEXT NOT NULL,
            quotationDate INTEGER NOT NULL, validUntil INTEGER,
            status TEXT NOT NULL CHECK(status IN ('DRAFT','SENT','ACCEPTED','REJECTED','EXPIRED','CONVERTED','CANCELLED')),
            subtotal REAL NOT NULL DEFAULT 0, discount REAL NOT NULL DEFAULT 0, tax REAL NOT NULL DEFAULT 0,
            grandTotal REAL NOT NULL DEFAULT 0, notes TEXT, createdAt INTEGER NOT NULL, updatedAt INTEGER NOT NULL,
            FOREIGN KEY (customerId) REFERENCES customers(id) ON DELETE RESTRICT
          )
;

-- table: raw_materials
-- Source migration: version 3
CREATE TABLE raw_materials (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            code TEXT NOT NULL UNIQUE,
            categoryId TEXT NOT NULL,
            unitId TEXT NOT NULL,
            description TEXT,
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            FOREIGN KEY (categoryId) REFERENCES categories(id) ON DELETE RESTRICT,
            FOREIGN KEY (unitId) REFERENCES units(id) ON DELETE RESTRICT
          )
;

-- table: role_permissions
-- Source migration: version 11
CREATE TABLE role_permissions (
            roleId TEXT NOT NULL,
            permissionId TEXT NOT NULL,
            PRIMARY KEY(roleId, permissionId),
            FOREIGN KEY (roleId) REFERENCES roles(id) ON DELETE RESTRICT,
            FOREIGN KEY (permissionId) REFERENCES permissions(id) ON DELETE RESTRICT
          )
;

-- table: roles
-- Source migration: version 11
CREATE TABLE roles (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL UNIQUE,
            description TEXT,
            active INTEGER NOT NULL DEFAULT 1,
            isSystemRole INTEGER NOT NULL DEFAULT 0,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          )
;

-- table: sales_deliveries
-- Source migration: version 7
CREATE TABLE sales_deliveries (
            id TEXT PRIMARY KEY, deliveryNumber TEXT NOT NULL UNIQUE, salesOrderId TEXT NOT NULL, warehouseId TEXT NOT NULL,
            deliveryDate INTEGER NOT NULL, notes TEXT, createdAt INTEGER NOT NULL, status TEXT NOT NULL DEFAULT 'PENDING' CHECK(status IN ('PENDING', 'DISPATCHED', 'IN_TRANSIT', 'DELIVERED', 'CANCELLED')), dispatchDate INTEGER, driverName TEXT, vehicleNumber TEXT, destination TEXT, updatedAt INTEGER, requestKey TEXT, "operationId" TEXT, "operationPayloadHash" TEXT, "inventoryPosted" INTEGER NOT NULL DEFAULT 1 CHECK(inventoryPosted IN (0, 1)),
            FOREIGN KEY (salesOrderId) REFERENCES sales_orders(id) ON DELETE RESTRICT,
            FOREIGN KEY (warehouseId) REFERENCES warehouses(id) ON DELETE RESTRICT
          )
;

-- table: sales_delivery_items
-- Source migration: version 7
CREATE TABLE sales_delivery_items (
            id TEXT PRIMARY KEY, salesDeliveryId TEXT NOT NULL, salesOrderItemId TEXT NOT NULL,
            deliveredQuantity REAL NOT NULL CHECK(deliveredQuantity > 0), unitId TEXT NOT NULL, notes TEXT, unitRevenue REAL NOT NULL DEFAULT 0, unitCogs REAL NOT NULL DEFAULT 0, "productId" TEXT, "variantId" TEXT, "baseUnitId" TEXT, "unitConversionFactor" REAL NOT NULL DEFAULT 1, "baseQuantity" REAL NOT NULL DEFAULT 0, "inventoryIdentityKind" TEXT NOT NULL DEFAULT 'BASE', "identitySnapshotStatus" TEXT NOT NULL DEFAULT 'UNVERIFIED',
            FOREIGN KEY (salesDeliveryId) REFERENCES sales_deliveries(id) ON DELETE RESTRICT,
            FOREIGN KEY (salesOrderItemId) REFERENCES sales_order_items(id) ON DELETE RESTRICT,
            FOREIGN KEY (unitId) REFERENCES units(id) ON DELETE RESTRICT
          )
;

-- table: sales_invoice_items
-- Source migration: version 41
CREATE TABLE sales_invoice_items (
            id TEXT PRIMARY KEY,
            salesInvoiceId TEXT NOT NULL,
            salesOrderItemId TEXT NOT NULL,
            quantity REAL NOT NULL CHECK(quantity > 0),
            unitId TEXT NOT NULL,
            unitPrice REAL NOT NULL CHECK(unitPrice >= 0),
            orderDiscount REAL NOT NULL CHECK(orderDiscount >= 0),
            invoiceDiscount REAL NOT NULL CHECK(invoiceDiscount >= 0),
            tax REAL NOT NULL CHECK(tax >= 0),
            lineTotal REAL NOT NULL CHECK(lineTotal >= 0),
            FOREIGN KEY (salesInvoiceId) REFERENCES sales_invoices(id) ON DELETE RESTRICT,
            FOREIGN KEY (salesOrderItemId) REFERENCES sales_order_items(id) ON DELETE RESTRICT,
            FOREIGN KEY (unitId) REFERENCES units(id) ON DELETE RESTRICT
          )
;

-- table: sales_invoices
-- Source migration: version 41
CREATE TABLE sales_invoices (
            id TEXT PRIMARY KEY,
            invoiceNumber TEXT NOT NULL UNIQUE,
            salesOrderId TEXT NOT NULL,
            customerId TEXT NOT NULL,
            invoiceDate INTEGER NOT NULL,
            subtotal REAL NOT NULL CHECK(subtotal >= 0),
            discount REAL NOT NULL CHECK(discount >= 0),
            tax REAL NOT NULL CHECK(tax >= 0),
            grandTotal REAL NOT NULL CHECK(grandTotal >= 0),
            status TEXT NOT NULL DEFAULT 'POSTED' CHECK(status IN ('POSTED', 'CANCELLED')),
            operationId TEXT NOT NULL UNIQUE,
            operationPayloadHash TEXT NOT NULL,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            FOREIGN KEY (salesOrderId) REFERENCES sales_orders(id) ON DELETE RESTRICT,
            FOREIGN KEY (customerId) REFERENCES customers(id) ON DELETE RESTRICT
          )
;

-- table: sales_order_items
-- Source migration: version 7
CREATE TABLE sales_order_items (
            id TEXT PRIMARY KEY, salesOrderId TEXT NOT NULL, itemId TEXT NOT NULL,
            itemType TEXT NOT NULL CHECK(itemType IN ('PRODUCT','RAW_MATERIAL')),
            quantity REAL NOT NULL CHECK(quantity > 0), unitId TEXT NOT NULL, unitPrice REAL NOT NULL CHECK(unitPrice >= 0),
            discount REAL NOT NULL DEFAULT 0, tax REAL NOT NULL DEFAULT 0, lineTotal REAL NOT NULL DEFAULT 0,
            deliveredQuantity REAL NOT NULL DEFAULT 0 CHECK(deliveredQuantity >= 0), notes TEXT, "productId" TEXT, "variantId" TEXT, "baseUnitId" TEXT, "unitConversionFactor" REAL NOT NULL DEFAULT 1, "baseQuantity" REAL NOT NULL DEFAULT 0, "inventoryIdentityKind" TEXT NOT NULL DEFAULT 'BASE', "identitySnapshotStatus" TEXT NOT NULL DEFAULT 'UNVERIFIED', "deliveredBaseQuantity" REAL NOT NULL DEFAULT 0, "invoicedQuantity" REAL NOT NULL DEFAULT 0 CHECK(invoicedQuantity >= 0),
            UNIQUE(salesOrderId, itemId, itemType), FOREIGN KEY (salesOrderId) REFERENCES sales_orders(id) ON DELETE RESTRICT,
            FOREIGN KEY (unitId) REFERENCES units(id) ON DELETE RESTRICT
          )
;

-- table: sales_orders
-- Source migration: version 7
CREATE TABLE sales_orders (
            id TEXT PRIMARY KEY, orderNumber TEXT NOT NULL UNIQUE, customerId TEXT NOT NULL, quotationId TEXT,
            orderDate INTEGER NOT NULL, expectedDeliveryDate INTEGER,
            status TEXT NOT NULL CHECK(status IN ('DRAFT','CONFIRMED','PARTIALLY_DELIVERED','FULLY_DELIVERED','CANCELLED')),
            subtotal REAL NOT NULL DEFAULT 0, discount REAL NOT NULL DEFAULT 0, tax REAL NOT NULL DEFAULT 0,
            grandTotal REAL NOT NULL DEFAULT 0, notes TEXT, createdAt INTEGER NOT NULL, updatedAt INTEGER NOT NULL,
            FOREIGN KEY (customerId) REFERENCES customers(id) ON DELETE RESTRICT,
            FOREIGN KEY (quotationId) REFERENCES quotations(id) ON DELETE RESTRICT
          )
;

-- table: sales_return_items
-- Source migration: version 16
CREATE TABLE sales_return_items (
            id TEXT PRIMARY KEY,
            salesReturnId TEXT NOT NULL,
            itemId TEXT NOT NULL,
            itemType TEXT NOT NULL CHECK(itemType IN ('PRODUCT', 'RAW_MATERIAL')),
            quantity REAL NOT NULL CHECK(quantity >= 0),
            unitId TEXT NOT NULL,
            unitPrice REAL NOT NULL DEFAULT 0,
            reason TEXT,
            qualityStatus TEXT NOT NULL CHECK(qualityStatus IN ('PENDING', 'APPROVED', 'REJECTED', 'QUARANTINED')) DEFAULT 'PENDING',
            createdAt INTEGER NOT NULL, sourceDeliveryItemId TEXT, "productId" TEXT, "variantId" TEXT, "baseUnitId" TEXT, "unitConversionFactor" REAL NOT NULL DEFAULT 1, "baseQuantity" REAL NOT NULL DEFAULT 0, "inventoryIdentityKind" TEXT NOT NULL DEFAULT 'BASE', "identitySnapshotStatus" TEXT NOT NULL DEFAULT 'UNVERIFIED',
            FOREIGN KEY (salesReturnId) REFERENCES sales_returns(id) ON DELETE CASCADE
          )
;

-- table: sales_return_receipt_items
-- Source migration: version 38
CREATE TABLE sales_return_receipt_items (
            id TEXT PRIMARY KEY,
            receiptId TEXT NOT NULL,
            salesReturnItemId TEXT NOT NULL,
            quantity REAL NOT NULL CHECK(quantity > 0),
            baseQuantity REAL NOT NULL CHECK(baseQuantity > 0),
            UNIQUE(receiptId, salesReturnItemId),
            FOREIGN KEY (receiptId) REFERENCES sales_return_receipts(id) ON DELETE CASCADE,
            FOREIGN KEY (salesReturnItemId) REFERENCES sales_return_items(id) ON DELETE RESTRICT
          )
;

-- table: sales_return_receipts
-- Source migration: version 38
CREATE TABLE sales_return_receipts (
            id TEXT PRIMARY KEY,
            receiptNumber TEXT NOT NULL UNIQUE,
            salesReturnId TEXT NOT NULL,
            warehouseId TEXT NOT NULL,
            receiptDate INTEGER NOT NULL,
            createdAt INTEGER NOT NULL,
            FOREIGN KEY (salesReturnId) REFERENCES sales_returns(id) ON DELETE RESTRICT,
            FOREIGN KEY (warehouseId) REFERENCES warehouses(id) ON DELETE RESTRICT
          )
;

-- table: sales_returns
-- Source migration: version 16
CREATE TABLE sales_returns (
            id TEXT PRIMARY KEY,
            returnNumber TEXT NOT NULL UNIQUE,
            salesOrderId TEXT NOT NULL,
            salesDeliveryId TEXT,
            customerId TEXT NOT NULL,
            warehouseId TEXT NOT NULL,
            returnDate INTEGER NOT NULL,
            reason TEXT,
            status TEXT NOT NULL CHECK(status IN ('DRAFT', 'PENDING', 'APPROVED', 'REJECTED', 'COMPLETED', 'CANCELLED')) DEFAULT 'PENDING',
            notes TEXT,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            FOREIGN KEY (salesOrderId) REFERENCES sales_orders(id) ON DELETE RESTRICT,
            FOREIGN KEY (customerId) REFERENCES customers(id) ON DELETE RESTRICT,
            FOREIGN KEY (warehouseId) REFERENCES warehouses(id) ON DELETE RESTRICT
          )
;

-- table: sections
-- Source migration: version 2
CREATE TABLE sections (
            id TEXT PRIMARY KEY,
            factoryId TEXT NOT NULL,
            name TEXT NOT NULL,
            code TEXT NOT NULL,
            description TEXT,
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(factoryId, code),
            FOREIGN KEY (factoryId) REFERENCES factories(id) ON DELETE RESTRICT
          )
;

-- table: shifts
-- Source migration: version 9
CREATE TABLE shifts (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            startTime TEXT NOT NULL,
            endTime TEXT NOT NULL,
            graceMinutes INTEGER NOT NULL DEFAULT 0 CHECK(graceMinutes >= 0),
            overtimeEnabled INTEGER NOT NULL DEFAULT 0,
            overtimeStartAfterMinutes INTEGER NOT NULL DEFAULT 0 CHECK(overtimeStartAfterMinutes >= 0),
            overtimeRate REAL NOT NULL DEFAULT 0 CHECK(overtimeRate >= 0),
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          )
;

-- table: stock_balances
-- Source migration: version 4
CREATE TABLE stock_balances (
            id TEXT PRIMARY KEY,
            warehouseId TEXT NOT NULL,
            itemId TEXT NOT NULL,
            itemType TEXT NOT NULL CHECK(itemType IN ('RAW_MATERIAL', 'PRODUCT')),
            quantity REAL NOT NULL CHECK(quantity >= 0),
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL, "productId" TEXT, "variantId" TEXT, "inventoryIdentityKind" TEXT NOT NULL DEFAULT 'BASE', "unitId" TEXT,
            UNIQUE(warehouseId, itemId, itemType),
            FOREIGN KEY (warehouseId) REFERENCES warehouses(id) ON DELETE RESTRICT
          )
;

-- table: stock_minimum_levels
-- Source migration: version 12
CREATE TABLE stock_minimum_levels (
            id TEXT PRIMARY KEY,
            warehouseId TEXT NOT NULL,
            itemId TEXT NOT NULL,
            itemType TEXT NOT NULL CHECK(itemType IN ('RAW_MATERIAL', 'PRODUCT')),
            minimumQuantity REAL NOT NULL CHECK(minimumQuantity >= 0),
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL, "productId" TEXT, "variantId" TEXT, "inventoryIdentityKind" TEXT NOT NULL DEFAULT 'BASE', "unitId" TEXT,
            UNIQUE(warehouseId, itemId, itemType),
            FOREIGN KEY (warehouseId) REFERENCES warehouses(id) ON DELETE RESTRICT
          )
;

-- table: stock_transactions
-- Source migration: version 4
CREATE TABLE stock_transactions (
            id TEXT PRIMARY KEY,
            warehouseId TEXT NOT NULL,
            itemId TEXT NOT NULL,
            itemType TEXT NOT NULL CHECK(itemType IN ('RAW_MATERIAL', 'PRODUCT')),
            transactionType TEXT NOT NULL CHECK(transactionType IN ('STOCK_IN', 'STOCK_OUT', 'TRANSFER_IN', 'TRANSFER_OUT', 'ADJUSTMENT')),
            quantity REAL NOT NULL,
            unitId TEXT NOT NULL,
            reference TEXT,
            notes TEXT,
            transactionDate INTEGER NOT NULL,
            createdAt INTEGER NOT NULL, "productId" TEXT, "variantId" TEXT, "inventoryIdentityKind" TEXT NOT NULL DEFAULT 'BASE',
            FOREIGN KEY (warehouseId) REFERENCES warehouses(id) ON DELETE RESTRICT,
            FOREIGN KEY (unitId) REFERENCES units(id) ON DELETE RESTRICT
          )
;

-- table: supplier_payments
-- Source migration: version 10
CREATE TABLE supplier_payments (
            id TEXT PRIMARY KEY,
            supplierId TEXT NOT NULL,
            date INTEGER NOT NULL,
            amount REAL NOT NULL CHECK(amount > 0),
            cashboxId TEXT,
            bankAccountId TEXT,
            reference TEXT,
            notes TEXT,
            status TEXT NOT NULL CHECK(status IN ('DRAFT','POSTED','REVERSED')),
            createdAt INTEGER NOT NULL, operationKey TEXT,
            FOREIGN KEY (supplierId) REFERENCES suppliers(id) ON DELETE RESTRICT,
            FOREIGN KEY (cashboxId) REFERENCES cashboxes(id) ON DELETE RESTRICT,
            FOREIGN KEY (bankAccountId) REFERENCES bank_accounts(id) ON DELETE RESTRICT,
            CHECK((cashboxId IS NOT NULL AND bankAccountId IS NULL) OR (cashboxId IS NULL AND bankAccountId IS NOT NULL))
          )
;

-- table: suppliers
-- Source migration: version 6
CREATE TABLE suppliers (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            code TEXT NOT NULL UNIQUE,
            phone TEXT,
            email TEXT,
            address TEXT,
            taxNumber TEXT,
            notes TEXT,
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          )
;

-- table: units
-- Source migration: version 3
CREATE TABLE units (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL UNIQUE,
            abbreviation TEXT NOT NULL UNIQUE,
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          )
;

-- table: user_scopes
-- Source migration: version 11
CREATE TABLE user_scopes (
            id TEXT PRIMARY KEY,
            userId TEXT NOT NULL,
            scopeType TEXT NOT NULL CHECK(scopeType IN ('SECTION','WORKSHOP','WAREHOUSE','PRODUCTION_STAGE')),
            scopeId TEXT NOT NULL,
            UNIQUE(userId, scopeType, scopeId),
            FOREIGN KEY (userId) REFERENCES users(id) ON DELETE RESTRICT
          )
;

-- table: users
-- Source migration: version 11
CREATE TABLE users (
            id TEXT PRIMARY KEY,
            username TEXT NOT NULL UNIQUE,
            displayName TEXT NOT NULL,
            phone TEXT,
            email TEXT,
            passwordHash TEXT NOT NULL,
            roleId TEXT NOT NULL,
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            lastLoginAt INTEGER,
            FOREIGN KEY (roleId) REFERENCES roles(id) ON DELETE RESTRICT
          )
;

-- table: warehouses
-- Source migration: version 2
CREATE TABLE warehouses (
            id TEXT PRIMARY KEY,
            factoryId TEXT NOT NULL,
            name TEXT NOT NULL,
            code TEXT NOT NULL,
            type TEXT,
            state TEXT NOT NULL DEFAULT 'active',
            notes TEXT,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL, "purpose" TEXT NOT NULL DEFAULT 'SELLABLE' CHECK(purpose IN ('SELLABLE', 'QUARANTINE', 'REWORK', 'DAMAGED')),
            UNIQUE(factoryId, code),
            FOREIGN KEY (factoryId) REFERENCES factories(id) ON DELETE RESTRICT
          )
;

-- table: worker_assignments
-- Source migration: version 9
CREATE TABLE worker_assignments (
            id TEXT PRIMARY KEY,
            workerId TEXT NOT NULL,
            sectionId TEXT,
            workshopId TEXT,
            productionStageId TEXT,
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(workerId),
            FOREIGN KEY (workerId) REFERENCES workers(id) ON DELETE RESTRICT,
            FOREIGN KEY (sectionId) REFERENCES sections(id) ON DELETE RESTRICT,
            FOREIGN KEY (workshopId) REFERENCES workshops(id) ON DELETE RESTRICT,
            FOREIGN KEY (productionStageId) REFERENCES production_stages(id) ON DELETE RESTRICT
          )
;

-- table: workers
-- Source migration: version 9
CREATE TABLE workers (
            id TEXT PRIMARY KEY,
            employeeCode TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            phone TEXT,
            email TEXT,
            address TEXT,
            hireDate INTEGER NOT NULL,
            sectionId TEXT,
            workshopId TEXT,
            productionStageId TEXT,
            active INTEGER NOT NULL DEFAULT 1,
            basicSalary REAL NOT NULL CHECK(basicSalary >= 0),
            salaryType TEXT NOT NULL CHECK(salaryType IN ('MONTHLY','DAILY','HOURLY')),
            overtimeEnabled INTEGER NOT NULL DEFAULT 0,
            overtimeRateOverride REAL,
            notes TEXT,
            annualLeaveAllowance REAL NOT NULL DEFAULT 0,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            FOREIGN KEY (sectionId) REFERENCES sections(id) ON DELETE RESTRICT,
            FOREIGN KEY (workshopId) REFERENCES workshops(id) ON DELETE RESTRICT,
            FOREIGN KEY (productionStageId) REFERENCES production_stages(id) ON DELETE RESTRICT
          )
;

-- table: workshops
-- Source migration: version 2
CREATE TABLE workshops (
            id TEXT PRIMARY KEY,
            factoryId TEXT NOT NULL,
            sectionId TEXT NOT NULL,
            name TEXT NOT NULL,
            code TEXT NOT NULL,
            description TEXT,
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(sectionId, code),
            FOREIGN KEY (factoryId) REFERENCES factories(id) ON DELETE RESTRICT,
            FOREIGN KEY (sectionId) REFERENCES sections(id) ON DELETE RESTRICT
          )
;

-- index: idx_accounts_parent (extracted after migrations 1-41)
CREATE INDEX idx_accounts_parent ON accounts(parentId)
;

-- index: idx_attendance_worker_date (extracted after migrations 1-41)
CREATE INDEX idx_attendance_worker_date ON attendance_records(workerId, workDate)
;

-- index: idx_audit_timestamp (extracted after migrations 1-41)
CREATE INDEX idx_audit_timestamp ON audit_logs(timestamp DESC)
;

-- index: idx_audit_user_module (extracted after migrations 1-41)
CREATE INDEX idx_audit_user_module ON audit_logs(userId, module, action)
;

-- index: idx_bom_material (extracted after migrations 1-41)
CREATE INDEX idx_bom_material ON product_bom_items(rawMaterialId)
;

-- index: idx_bom_product (extracted after migrations 1-41)
CREATE INDEX idx_bom_product ON product_bom_items(productId)
;

-- index: idx_costing_batch_order (extracted after migrations 1-41)
CREATE INDEX idx_costing_batch_order ON production_batch_costs(productionOrderId, status)
;

-- index: idx_costing_batch_product (extracted after migrations 1-41)
CREATE INDEX idx_costing_batch_product ON production_batch_costs(productId, finalizedAt DESC)
;

-- index: idx_costing_other_order (extracted after migrations 1-41)
CREATE INDEX idx_costing_other_order ON production_other_costs(productionOrderId, date DESC)
;

-- index: idx_costing_overhead_active (extracted after migrations 1-41)
CREATE INDEX idx_costing_overhead_active ON costing_overhead_rules(active, base)
;

-- index: idx_crm_activities_customer (extracted after migrations 1-41)
CREATE INDEX idx_crm_activities_customer ON crm_activities(customerId, activityDate DESC)
;

-- index: idx_crm_follow_ups_due (extracted after migrations 1-41)
CREATE INDEX idx_crm_follow_ups_due ON crm_follow_ups(status, dueDate)
;

-- index: idx_crm_leads_status (extracted after migrations 1-41)
CREATE INDEX idx_crm_leads_status ON crm_leads(status, updatedAt DESC)
;

-- index: idx_crm_tasks_due (extracted after migrations 1-41)
CREATE INDEX idx_crm_tasks_due ON crm_tasks(status, dueDate)
;

-- index: idx_customer_overrides_active_base (extracted after migrations 1-41)
CREATE UNIQUE INDEX idx_customer_overrides_active_base ON customer_price_overrides(customerId, productId) WHERE active = 1 AND variantId IS NULL
;

-- index: idx_customer_payment_operation (extracted after migrations 1-41)
CREATE UNIQUE INDEX idx_customer_payment_operation ON customer_payments(operationKey) WHERE operationKey IS NOT NULL
;

-- index: idx_customer_prices_customer (extracted after migrations 1-41)
CREATE INDEX idx_customer_prices_customer ON customer_price_overrides(customerId, productId, variantId, active)
;

-- index: idx_dimensions_product (extracted after migrations 1-41)
CREATE INDEX idx_dimensions_product ON product_dimensions(productId)
;

-- index: idx_dimensions_product_level (extracted after migrations 1-41)
CREATE UNIQUE INDEX idx_dimensions_product_level ON product_dimensions(productId) WHERE variantId IS NULL
;

-- index: idx_dimensions_variant (extracted after migrations 1-41)
CREATE INDEX idx_dimensions_variant ON product_dimensions(variantId)
;

-- index: idx_discount_rules_scope (extracted after migrations 1-41)
CREATE INDEX idx_discount_rules_scope ON discount_rules(customerId, productId, variantId, minimumQuantity, active)
;

-- index: idx_document_records_source (extracted after migrations 1-41)
CREATE INDEX idx_document_records_source ON document_records(sourceEntityType, sourceEntityId)
;

-- index: idx_document_records_type_date (extracted after migrations 1-41)
CREATE INDEX idx_document_records_type_date ON document_records(documentType, issueDate DESC)
;

-- index: idx_document_sequences_type_year (extracted after migrations 1-41)
CREATE INDEX idx_document_sequences_type_year ON document_sequences(documentType, year)
;

-- index: idx_inventory_valuations_item (extracted after migrations 1-41)
CREATE INDEX idx_inventory_valuations_item ON inventory_valuations(warehouseId, itemId, itemType)
;

-- index: idx_inventory_valuations_variant_identity (extracted after migrations 1-41)
CREATE INDEX idx_inventory_valuations_variant_identity ON inventory_valuations(warehouseId, productId, variantId, inventoryIdentityKind)
;

-- index: idx_journal_entries_date (extracted after migrations 1-41)
CREATE INDEX idx_journal_entries_date ON journal_entries(date, status)
;

-- index: idx_journal_lines_account (extracted after migrations 1-41)
CREATE INDEX idx_journal_lines_account ON journal_lines(accountId, journalEntryId)
;

-- index: idx_journal_parties_party (extracted after migrations 1-41)
CREATE INDEX idx_journal_parties_party ON journal_parties(partyType, partyId, journalEntryId)
;

-- index: idx_labor_allocations_attendance (extracted after migrations 1-41)
CREATE INDEX idx_labor_allocations_attendance ON production_order_labor_allocations(attendanceId)
;

-- index: idx_labor_allocations_order (extracted after migrations 1-41)
CREATE INDEX idx_labor_allocations_order ON production_order_labor_allocations(productionOrderId)
;

-- index: idx_leave_worker_dates (extracted after migrations 1-41)
CREATE INDEX idx_leave_worker_dates ON leave_records(workerId, startDate, endDate)
;

-- index: idx_notifications_created (extracted after migrations 1-41)
CREATE INDEX idx_notifications_created ON notifications(createdAt DESC)
;

-- index: idx_notifications_dedup (extracted after migrations 1-41)
CREATE INDEX idx_notifications_dedup ON notifications(deduplicationKey)
;

-- index: idx_notifications_type (extracted after migrations 1-41)
CREATE INDEX idx_notifications_type ON notifications(type)
;

-- index: idx_notifications_user_read (extracted after migrations 1-41)
CREATE INDEX idx_notifications_user_read ON notifications(userId, isRead, isArchived)
;

-- index: idx_order_bom_items_order (extracted after migrations 1-41)
CREATE INDEX idx_order_bom_items_order ON production_order_bom_items(productionOrderId)
;

-- index: idx_payroll_period_worker (extracted after migrations 1-41)
CREATE INDEX idx_payroll_period_worker ON payroll_records(payrollPeriodId, workerId)
;

-- index: idx_period_dates (extracted after migrations 1-41)
CREATE INDEX idx_period_dates ON accounting_periods(startDate, endDate, status)
;

-- index: idx_price_history_product (extracted after migrations 1-41)
CREATE INDEX idx_price_history_product ON price_history(productId, effectiveAt DESC)
;

-- index: idx_price_tiers_active_base (extracted after migrations 1-41)
CREATE UNIQUE INDEX idx_price_tiers_active_base ON price_tiers(priceListId, productId, minimumQuantity) WHERE active = 1 AND variantId IS NULL
;

-- index: idx_price_tiers_product (extracted after migrations 1-41)
CREATE INDEX idx_price_tiers_product ON price_tiers(productId, variantId, minimumQuantity)
;

-- index: idx_pricing_one_default (extracted after migrations 1-41)
CREATE UNIQUE INDEX idx_pricing_one_default ON pricing_lists(isDefault) WHERE isDefault = 1
;

-- index: idx_product_alternatives_target (extracted after migrations 1-41)
CREATE INDEX idx_product_alternatives_target ON product_alternatives(targetProductId)
;

-- index: idx_product_prices_active_base (extracted after migrations 1-41)
CREATE UNIQUE INDEX idx_product_prices_active_base ON product_prices(priceListId, productId) WHERE active = 1 AND variantId IS NULL
;

-- index: idx_product_prices_list (extracted after migrations 1-41)
CREATE INDEX idx_product_prices_list ON product_prices(priceListId, productId, variantId, active)
;

-- index: idx_product_unit_conversions_lookup (extracted after migrations 1-41)
CREATE INDEX idx_product_unit_conversions_lookup ON product_unit_conversions(productId, unitId, active)
;

-- index: idx_production_consumption_operation (extracted after migrations 1-41)
CREATE UNIQUE INDEX idx_production_consumption_operation ON production_material_consumptions(operationId) WHERE operationId IS NOT NULL
;

-- index: idx_production_consumptions_order (extracted after migrations 1-41)
CREATE INDEX idx_production_consumptions_order ON production_material_consumptions(productionOrderId, consumptionDate)
;

-- index: idx_production_order_stages_order (extracted after migrations 1-41)
CREATE INDEX idx_production_order_stages_order ON production_order_stages(productionOrderId, sequence)
;

-- index: idx_production_orders_status (extracted after migrations 1-41)
CREATE INDEX idx_production_orders_status ON production_orders(status, createdAt)
;

-- index: idx_production_output_operation (extracted after migrations 1-41)
CREATE UNIQUE INDEX idx_production_output_operation ON production_outputs(operationId) WHERE operationId IS NOT NULL
;

-- index: idx_production_outputs_order (extracted after migrations 1-41)
CREATE INDEX idx_production_outputs_order ON production_outputs(productionOrderId, outputDate)
;

-- index: idx_production_routes_product (extracted after migrations 1-41)
CREATE INDEX idx_production_routes_product ON production_routes(productId)
;

-- index: idx_production_stages_factory_id (extracted after migrations 1-41)
CREATE INDEX idx_production_stages_factory_id ON production_stages(factoryId)
;

-- index: idx_production_waste_order (extracted after migrations 1-41)
CREATE INDEX idx_production_waste_order ON production_waste(productionOrderId, wasteDate)
;

-- index: idx_products_category (extracted after migrations 1-41)
CREATE INDEX idx_products_category ON products(categoryId)
;

-- index: idx_products_unit (extracted after migrations 1-41)
CREATE INDEX idx_products_unit ON products(unitId)
;

-- index: idx_purchase_orders_supplier (extracted after migrations 1-41)
CREATE INDEX idx_purchase_orders_supplier ON purchase_orders(supplierId, orderDate)
;

-- index: idx_purchase_receipts_order (extracted after migrations 1-41)
CREATE INDEX idx_purchase_receipts_order ON purchase_receipts(purchaseOrderId, receiptDate)
;

-- index: idx_purchase_requests_status (extracted after migrations 1-41)
CREATE INDEX idx_purchase_requests_status ON purchase_requests(status, requestDate)
;

-- index: idx_purchase_return_handover_items_line (extracted after migrations 1-41)
CREATE INDEX idx_purchase_return_handover_items_line ON purchase_return_handover_items(purchaseReturnItemId)
;

-- index: idx_purchase_return_handovers_return (extracted after migrations 1-41)
CREATE INDEX idx_purchase_return_handovers_return ON purchase_return_handovers(purchaseReturnId, handoverDate)
;

-- index: idx_purchase_return_inspections_receipt (extracted after migrations 1-41)
CREATE INDEX idx_purchase_return_inspections_receipt
          ON quality_inspections(purchaseReturnReceiptId, inspectionDate)
          WHERE sourceType = 'PURCHASE_RETURN' AND purchaseReturnReceiptId IS NOT NULL
        
;

-- index: idx_purchase_return_items_return (extracted after migrations 1-41)
CREATE INDEX idx_purchase_return_items_return ON purchase_return_items(purchaseReturnId, qualityStatus)
;

-- index: idx_purchase_return_receipt_items_line (extracted after migrations 1-41)
CREATE INDEX idx_purchase_return_receipt_items_line ON purchase_return_receipt_items(purchaseReturnItemId)
;

-- index: idx_purchase_return_receipts_return (extracted after migrations 1-41)
CREATE INDEX idx_purchase_return_receipts_return ON purchase_return_receipts(purchaseReturnId, receiptDate)
;

-- index: idx_purchase_returns_source_line (extracted after migrations 1-41)
CREATE INDEX idx_purchase_returns_source_line ON purchase_return_items(purchaseOrderItemId)
;

-- index: idx_purchase_returns_supplier (extracted after migrations 1-41)
CREATE INDEX idx_purchase_returns_supplier ON purchase_returns(supplierId, returnDate DESC)
;

-- index: idx_quality_inspection_source_line (extracted after migrations 1-41)
CREATE INDEX idx_quality_inspection_source_line ON quality_inspection_items(sourceReturnItemId)
;

-- index: idx_quality_inspections_source (extracted after migrations 1-41)
CREATE INDEX idx_quality_inspections_source ON quality_inspections(sourceType, sourceId, inspectionDate DESC)
;

-- index: idx_quotations_customer (extracted after migrations 1-41)
CREATE INDEX idx_quotations_customer ON quotations(customerId, quotationDate)
;

-- index: idx_raw_materials_category (extracted after migrations 1-41)
CREATE INDEX idx_raw_materials_category ON raw_materials(categoryId)
;

-- index: idx_raw_materials_unit (extracted after migrations 1-41)
CREATE INDEX idx_raw_materials_unit ON raw_materials(unitId)
;

-- index: idx_sales_deliveries_order (extracted after migrations 1-41)
CREATE INDEX idx_sales_deliveries_order ON sales_deliveries(salesOrderId, deliveryDate)
;

-- index: idx_sales_deliveries_reservation_status (extracted after migrations 1-41)
CREATE INDEX idx_sales_deliveries_reservation_status
          ON sales_deliveries(status, inventoryPosted, warehouseId)
        
;

-- index: idx_sales_deliveries_status (extracted after migrations 1-41)
CREATE INDEX idx_sales_deliveries_status ON sales_deliveries(status, deliveryDate)
;

-- index: idx_sales_delivery_items_reservation_identity (extracted after migrations 1-41)
CREATE INDEX idx_sales_delivery_items_reservation_identity
          ON sales_delivery_items(
            salesDeliveryId,
            productId,
            variantId,
            inventoryIdentityKind,
            baseUnitId,
            salesOrderItemId
          )
        
;

-- index: idx_sales_delivery_operation_id (extracted after migrations 1-41)
CREATE UNIQUE INDEX idx_sales_delivery_operation_id ON sales_deliveries(operationId) WHERE operationId IS NOT NULL
;

-- index: idx_sales_delivery_request_key (extracted after migrations 1-41)
CREATE UNIQUE INDEX idx_sales_delivery_request_key ON sales_deliveries(requestKey) WHERE requestKey IS NOT NULL
;

-- index: idx_sales_invoice_items_order_item (extracted after migrations 1-41)
CREATE INDEX idx_sales_invoice_items_order_item
          ON sales_invoice_items(salesOrderItemId, salesInvoiceId)
        
;

-- index: idx_sales_invoices_order_date (extracted after migrations 1-41)
CREATE INDEX idx_sales_invoices_order_date
          ON sales_invoices(salesOrderId, invoiceDate)
        
;

-- index: idx_sales_orders_customer (extracted after migrations 1-41)
CREATE INDEX idx_sales_orders_customer ON sales_orders(customerId, orderDate)
;

-- index: idx_sales_orders_quotation_id_unique (extracted after migrations 1-41)
CREATE UNIQUE INDEX idx_sales_orders_quotation_id_unique ON sales_orders(quotationId) WHERE quotationId IS NOT NULL
;

-- index: idx_sales_return_items_return (extracted after migrations 1-41)
CREATE INDEX idx_sales_return_items_return ON sales_return_items(salesReturnId, qualityStatus)
;

-- index: idx_sales_return_receipt_items_line (extracted after migrations 1-41)
CREATE INDEX idx_sales_return_receipt_items_line ON sales_return_receipt_items(salesReturnItemId)
;

-- index: idx_sales_return_receipts_return (extracted after migrations 1-41)
CREATE INDEX idx_sales_return_receipts_return ON sales_return_receipts(salesReturnId, receiptDate)
;

-- index: idx_sales_return_source_line (extracted after migrations 1-41)
CREATE INDEX idx_sales_return_source_line ON sales_return_items(sourceDeliveryItemId)
;

-- index: idx_sales_returns_customer (extracted after migrations 1-41)
CREATE INDEX idx_sales_returns_customer ON sales_returns(customerId, returnDate DESC)
;

-- index: idx_sections_factory_id (extracted after migrations 1-41)
CREATE INDEX idx_sections_factory_id ON sections(factoryId)
;

-- index: idx_stock_balances_item (extracted after migrations 1-41)
CREATE INDEX idx_stock_balances_item ON stock_balances(itemId, itemType)
;

-- index: idx_stock_balances_variant_identity (extracted after migrations 1-41)
CREATE INDEX idx_stock_balances_variant_identity ON stock_balances(warehouseId, productId, variantId, inventoryIdentityKind)
;

-- index: idx_stock_balances_warehouse (extracted after migrations 1-41)
CREATE INDEX idx_stock_balances_warehouse ON stock_balances(warehouseId)
;

-- index: idx_stock_minimum_warehouse (extracted after migrations 1-41)
CREATE INDEX idx_stock_minimum_warehouse ON stock_minimum_levels(warehouseId, itemId, itemType)
;

-- index: idx_stock_transactions_item (extracted after migrations 1-41)
CREATE INDEX idx_stock_transactions_item ON stock_transactions(itemId, itemType, transactionDate)
;

-- index: idx_stock_transactions_variant_identity (extracted after migrations 1-41)
CREATE INDEX idx_stock_transactions_variant_identity ON stock_transactions(warehouseId, productId, variantId, inventoryIdentityKind, transactionDate)
;

-- index: idx_stock_transactions_warehouse (extracted after migrations 1-41)
CREATE INDEX idx_stock_transactions_warehouse ON stock_transactions(warehouseId, transactionDate)
;

-- index: idx_supplier_payment_operation (extracted after migrations 1-41)
CREATE UNIQUE INDEX idx_supplier_payment_operation ON supplier_payments(operationKey) WHERE operationKey IS NOT NULL
;

-- index: idx_users_username (extracted after migrations 1-41)
CREATE INDEX idx_users_username ON users(username)
;

-- index: idx_variants_product (extracted after migrations 1-41)
CREATE INDEX idx_variants_product ON product_variants(productId)
;

-- index: idx_warehouses_factory_id (extracted after migrations 1-41)
CREATE INDEX idx_warehouses_factory_id ON warehouses(factoryId)
;

-- index: idx_workers_active (extracted after migrations 1-41)
CREATE INDEX idx_workers_active ON workers(active, name)
;

-- index: idx_workers_section (extracted after migrations 1-41)
CREATE INDEX idx_workers_section ON workers(sectionId)
;

-- index: idx_workers_workshop (extracted after migrations 1-41)
CREATE INDEX idx_workers_workshop ON workers(workshopId)
;

-- index: idx_workshops_factory_id (extracted after migrations 1-41)
CREATE INDEX idx_workshops_factory_id ON workshops(factoryId)
;

-- index: idx_workshops_section_id (extracted after migrations 1-41)
CREATE INDEX idx_workshops_section_id ON workshops(sectionId)
;

-- trigger: prevent_audit_delete (extracted after migrations 1-41)
CREATE TRIGGER prevent_audit_delete BEFORE DELETE ON audit_logs BEGIN SELECT RAISE(ABORT, 'audit logs are immutable'); END
;

-- trigger: prevent_audit_update (extracted after migrations 1-41)
CREATE TRIGGER prevent_audit_update BEFORE UPDATE ON audit_logs BEGIN SELECT RAISE(ABORT, 'audit logs are immutable'); END
;

-- trigger: trg_purchase_requests_supplier_insert (extracted after migrations 1-41)
CREATE TRIGGER trg_purchase_requests_supplier_insert
          BEFORE INSERT ON purchase_requests
          WHEN NEW.supplierId IS NULL OR TRIM(NEW.supplierId) = ''
          BEGIN
            SELECT RAISE(ABORT, 'Purchase request supplier is required');
          END
;

-- trigger: trg_purchase_requests_supplier_update (extracted after migrations 1-41)
CREATE TRIGGER trg_purchase_requests_supplier_update
          BEFORE UPDATE OF supplierId ON purchase_requests
          WHEN NEW.supplierId IS NULL OR TRIM(NEW.supplierId) = ''
          BEGIN
            SELECT RAISE(ABORT, 'Purchase request supplier is required');
          END
;

