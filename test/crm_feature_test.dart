import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/crm/data/datasources/crm_local_data_source.dart';
import 'package:furnexa/features/crm/domain/entities/crm_entities.dart';
import 'package:furnexa/features/sales/domain/entities/sales_entities.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'test_helpers/database_test_helper.dart';

void main() {
  late CrmLocalDataSource crm;
  late String suffix;
  late DateTime now;
  late String customerId;
  late String leadId;

  setUp(() async {
    await DatabaseTestHelper.reset();
    await SecurityLocalDataSource().login('admin', 'Furnexa-Test-Admin-2026!');
    suffix = DateTime.now().microsecondsSinceEpoch.toString();
    now = DateTime(2026, 9, 17);
    crm = CrmLocalDataSource();

    final db = await FurnexaDatabase.instance.database;
    await db.delete('crm_follow_ups');
    await db.delete('crm_tasks');
    await db.delete('crm_notes');
    await db.delete('crm_activities');
    await db.delete('crm_leads');
    await db.delete('sales_delivery_items');
    await db.delete('sales_deliveries');
    await db.delete('sales_order_items');
    await db.delete('sales_orders');
    await db.delete('quotation_items');
    await db.delete('quotations');
    await db.delete('customers');
    await db.delete('stock_transactions');
    await db.delete('stock_balances');
    await db.delete('products');
    await db.delete('raw_materials');
    await db.delete('categories');
    await db.delete('units');
    await db.delete('warehouses');
    await db.delete('factories');

    final factoryId = 'crm-factory-$suffix';
    final categoryId = 'crm-category-$suffix';
    final warehouseId = 'crm-warehouse-$suffix';
    final unitId = 'crm-unit-$suffix';
    final productId = 'crm-product-$suffix';

    final stamp = now.millisecondsSinceEpoch;
    await db.insert('factories', {
      'id': factoryId,
      'name': 'مصنع CRM $suffix',
      'code': 'CRM-$suffix',
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('warehouses', {
      'id': warehouseId,
      'factoryId': factoryId,
      'name': 'مخزن CRM $suffix',
      'code': 'WCRM-$suffix',
      'state': 'active',
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('categories', {
      'id': categoryId,
      'name': 'تصنيف CRM $suffix',
      'code': 'CCRM-$suffix',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('units', {
      'id': unitId,
      'name': 'وحدة CRM $suffix',
      'abbreviation': 'UCRM$suffix',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('products', {
      'id': productId,
      'name': 'منتج CRM $suffix',
      'code': 'PCRM-$suffix',
      'categoryId': categoryId,
      'unitId': unitId,
      'productState': 'finished',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    customerId = 'crm-customer-$suffix';
    await db.insert('customers', {
      'id': customerId,
      'name': 'عميل CRM $suffix',
      'code': 'CUS-$suffix',
      'phone': '0500000000',
      'email': 'crm@example.com',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });

    await db.insert('sales_orders', {
      'id': 'crm-order-$suffix',
      'orderNumber': 'SO-CRM-$suffix',
      'customerId': customerId,
      'orderDate': now.millisecondsSinceEpoch,
      'status': 'CONFIRMED',
      'subtotal': 120,
      'discount': 0,
      'tax': 0,
      'grandTotal': 120,
      'createdAt': stamp,
      'updatedAt': stamp,
    });

    leadId = 'crm-lead-$suffix';
  });

  tearDown(() async {
    await DatabaseTestHelper.reset();
  });

  test('lead creation and status update', () async {
    final lead = await crm.saveLead(
      Lead(
        id: leadId,
        name: 'رائد CRM $suffix',
        phone: '0555555555',
        email: 'lead$suffix@example.com',
        company: 'شركة رائدة',
        address: 'الرياض',
        source: LeadSource.website,
        notes: 'مشتري محتمل',
        status: LeadStatus.newLead,
        assignedUserId: 'user-1',
        createdAt: now,
        updatedAt: now,
      ),
    );

    expect(lead.status, LeadStatus.newLead);
    final updated = await crm.updateLeadStatus(lead.id, LeadStatus.qualified);
    expect(updated.status, LeadStatus.qualified);
  });

  test(
    'lead conversion creates customer and preserves conversion metadata',
    () async {
      final lead = await crm.saveLead(
        Lead(
          id: leadId,
          name: 'رائد CRM $suffix',
          phone: '0555555555',
          email: 'lead$suffix@example.com',
          company: 'شركة رائدة',
          address: 'الرياض',
          source: LeadSource.referral,
          notes: 'مشتري محتمل',
          status: LeadStatus.newLead,
          assignedUserId: 'user-1',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final customerData = Customer(
        id: 'generated-customer-$suffix',
        name: lead.name,
        code: 'LEAD-$suffix',
        phone: lead.phone,
        email: lead.email,
        address: lead.address,
        active: true,
        createdAt: now,
        updatedAt: now,
      );
      final converted = await crm.convertLead(
        leadId: lead.id,
        customerData: customerData,
      );

      expect(converted.customerId, isNotNull);
      expect(converted.status, LeadStatus.converted);
      final record = await crm.getLeadById(lead.id);
      expect(record!.convertedAt, isNotNull);
      expect(record.convertedCustomerId, isNotNull);
      final activityCount = (await crm.activities(leadId: lead.id)).length;
      final retried = await crm.convertLead(
        leadId: lead.id,
        customerData: customerData,
      );
      expect(retried.customerId, converted.customerId);
      expect((await crm.activities(leadId: lead.id)).length, activityCount);
    },
  );

  test('lead conversion avoids duplicate customer creation', () async {
    final lead = await crm.saveLead(
      Lead(
        id: 'duplicate-lead-$suffix',
        name: 'عميل CRM $suffix',
        phone: '0500000000',
        email: 'crm@example.com',
        company: 'شركة موجودة',
        address: 'الرياض',
        source: LeadSource.website,
        status: LeadStatus.newLead,
        assignedUserId: 'user-1',
        createdAt: now,
        updatedAt: now,
      ),
    );

    final converted = await crm.convertLead(
      leadId: lead.id,
      customerData: Customer(
        id: 'duplicate-customer-$suffix',
        name: 'عميل CRM $suffix',
        code: 'DUP-$suffix',
        phone: '0500000000',
        email: 'crm@example.com',
        active: true,
        createdAt: now,
        updatedAt: now,
      ),
    );

    expect(converted.convertedCustomerId, customerId);
  });

  test('lead conversion rejects conflicting strong customer matches', () async {
    final db = await FurnexaDatabase.instance.database;
    await db.insert('customers', {
      'id': 'ambiguous-customer-$suffix',
      'name': 'عميل آخر',
      'code': 'AMB-$suffix',
      'phone': '0500000000',
      'email': 'different$suffix@example.com',
      'active': 1,
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    final lead = await crm.saveLead(
      Lead(
        id: 'ambiguous-lead-$suffix',
        name: 'عميل ملتبس',
        phone: '0500000000',
        email: 'crm@example.com',
        source: LeadSource.walkIn,
        status: LeadStatus.qualified,
        assignedUserId: 'user-1',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await expectLater(
      crm.convertLead(
        leadId: lead.id,
        customerData: Customer(
          id: 'ambiguous-new-$suffix',
          name: 'عميل ملتبس',
          code: 'AMB-NEW-$suffix',
          phone: '0500000000',
          email: 'crm@example.com',
          active: true,
          createdAt: now,
          updatedAt: now,
        ),
      ),
      throwsException,
    );
    expect((await crm.getLeadById(lead.id))?.status, LeadStatus.qualified);
  });

  test('activity and notes work for customer and lead', () async {
    final activity = await crm.createActivity(
      CrmActivity(
        id: 'activity-$suffix',
        customerId: customerId,
        leadId: null,
        type: ActivityType.call,
        title: 'مكالمة متابعة',
        description: 'محادثة أولية',
        activityDate: now,
        createdBy: 'user-1',
        relatedDocumentId: null,
        createdAt: now,
      ),
    );
    final note = await crm.addNote(
      CrmNote(
        id: 'note-$suffix',
        customerId: customerId,
        leadId: null,
        content: 'ملاحظة العميل',
        createdBy: 'user-1',
        createdAt: now,
        updatedAt: now,
      ),
    );

    expect(activity.customerId, customerId);
    expect(note.content, 'ملاحظة العميل');
    expect(await crm.customerNotes(customerId), hasLength(1));
  });

  test('follow-up completion, cancellation and overdue detection', () async {
    final followUp = await crm.createFollowUp(
      CrmFollowUp(
        id: 'follow-$suffix',
        customerId: customerId,
        leadId: null,
        title: 'متابعة العميل',
        description: 'نسخة طلب',
        dueDate: now.add(const Duration(days: -2)),
        assignedUserId: 'user-1',
        priority: FollowUpPriority.high,
        status: FollowUpStatus.pending,
        completedAt: null,
        createdAt: now,
        updatedAt: now,
      ),
    );

    expect(await crm.isOverdueFollowUp(followUp.id), isTrue);
    final completed = await crm.completeFollowUp(followUp.id);
    expect(completed.status, FollowUpStatus.completed);
    expect(completed.completedAt, isNotNull);

    final cancelled = await crm.createFollowUp(
      CrmFollowUp(
        id: 'follow-cancel-$suffix',
        customerId: customerId,
        leadId: null,
        title: 'إلغاء',
        description: 'إلغاء متابع',
        dueDate: now.add(const Duration(days: 3)),
        assignedUserId: 'user-1',
        priority: FollowUpPriority.medium,
        status: FollowUpStatus.pending,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final cancelledItem = await crm.cancelFollowUp(cancelled.id);
    expect(cancelledItem.status, FollowUpStatus.cancelled);
  });

  test('task creation and completion and customer 360 timeline', () async {
    final task = await crm.createTask(
      CrmTask(
        id: 'task-$suffix',
        customerId: customerId,
        leadId: null,
        title: 'مراجعة الطلب',
        description: 'مراجعة تفاصيل العرض',
        assignedUserId: 'user-1',
        dueDate: now.add(const Duration(days: 1)),
        priority: TaskPriority.high,
        status: TaskStatus.pending,
        completedAt: null,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final completed = await crm.completeTask(task.id);
    expect(completed.status, TaskStatus.completed);

    final profile = await crm.customer360(customerId);
    expect(profile.customer.id, customerId);
    expect(profile.salesHistory, isNotEmpty);
  });

  test('crm permissions and audit are enforced', () async {
    final security = SecurityLocalDataSource();
    security.logout();
    expect(() => crm.assertPermission('CRM_VIEW'), throwsException);
    await security.login('admin', 'Furnexa-Test-Admin-2026!');
    final lead = await crm.saveLead(
      Lead(
        id: 'audit-lead-$suffix',
        name: 'رائد Audit',
        phone: '0550000000',
        email: 'audit$suffix@example.com',
        source: LeadSource.walkIn,
        status: LeadStatus.newLead,
        assignedUserId: 'user-1',
        createdAt: now,
        updatedAt: now,
      ),
    );
    final audits = await crm.auditLogs();
    expect(audits, isNotEmpty);
    expect(lead.id, 'audit-lead-$suffix');
  });
}
