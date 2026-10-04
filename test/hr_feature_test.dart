import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/factory_structure/data/datasources/factory_structure_local_data_source.dart';
import 'package:furnexa/features/hr/data/datasources/hr_local_data_source.dart';
import 'package:furnexa/features/hr/domain/entities/hr_entities.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'test_helpers/database_test_helper.dart';

void main() {
  group('HR Feature', () {
    late HrLocalDataSource dataSource;
    late String factoryId;
    late String sectionId;
    late String workshopId;
    late String stageId;
    late String shiftId;
    late DateTime workDate;

    setUp(() async {
      await DatabaseTestHelper.reset();
      await SecurityLocalDataSource().login(
        'admin',
        'Furnexa-Test-Admin-2026!',
      );
      dataSource = HrLocalDataSource();
      final factoryDataSource = FactoryStructureLocalDataSource();
      await factoryDataSource.clearAll();
      final db = await FurnexaDatabase.instance.database;

      final stamp = DateTime(2026, 9, 1).millisecondsSinceEpoch;
      factoryId = 'factory-hr-${DateTime.now().microsecondsSinceEpoch}';
      sectionId = 'section-hr-${DateTime.now().microsecondsSinceEpoch}';
      workshopId = 'workshop-hr-${DateTime.now().microsecondsSinceEpoch}';
      stageId = 'stage-hr-${DateTime.now().microsecondsSinceEpoch}';
      shiftId = 'shift-hr-${DateTime.now().microsecondsSinceEpoch}';
      workDate = DateTime(2026, 9, 17);

      await db.insert('factories', {
        'id': factoryId,
        'name': 'مصنع اختبار',
        'code': 'FACT-HR-${DateTime.now().microsecondsSinceEpoch}',
        'createdAt': stamp,
        'updatedAt': stamp,
      });
      await db.insert('sections', {
        'id': sectionId,
        'factoryId': factoryId,
        'name': 'قسم الإنتاج',
        'code': 'SEC-HR',
        'active': 1,
        'createdAt': stamp,
        'updatedAt': stamp,
      });
      await db.insert('workshops', {
        'id': workshopId,
        'factoryId': factoryId,
        'sectionId': sectionId,
        'name': 'ورشة النجارة',
        'code': 'WS-HR',
        'active': 1,
        'createdAt': stamp,
        'updatedAt': stamp,
      });
      await db.insert('production_stages', {
        'id': stageId,
        'factoryId': factoryId,
        'name': 'مرحلة التشكيل',
        'code': 'STG-HR',
        'sequence': 1,
        'active': 1,
        'createdAt': stamp,
        'updatedAt': stamp,
      });
      await db.insert('shifts', {
        'id': shiftId,
        'name': 'الوردية 08-16',
        'startTime': '08:00',
        'endTime': '16:00',
        'graceMinutes': 15,
        'overtimeEnabled': 1,
        'overtimeStartAfterMinutes': 480,
        'overtimeRate': 50,
        'active': 1,
        'createdAt': stamp,
        'updatedAt': stamp,
      });
    });

    tearDown(() async {
      SecurityLocalDataSource().logout();
      await DatabaseTestHelper.reset();
    });

    test('worker creation, duplicate code and deactivation', () async {
      final worker = await dataSource.createWorker(
        employeeCode: 'EMP-001',
        name: 'أحمد علي',
        phone: '01000000000',
        email: 'ahmed@example.com',
        address: 'القاهرة',
        hireDate: DateTime(2024, 1, 1),
        basicSalary: 5000,
        salaryType: SalaryType.monthly,
        sectionId: sectionId,
        workshopId: workshopId,
        productionStageId: stageId,
      );
      expect(worker.employeeCode, 'EMP-001');
      expect(
        () => dataSource.createWorker(
          employeeCode: 'EMP-001',
          name: 'اسم آخر',
          basicSalary: 4000,
          salaryType: SalaryType.monthly,
        ),
        throwsException,
      );
      await dataSource.deactivateWorker(worker.id);
      expect((await dataSource.getWorker(worker.id)).active, isFalse);
      final logs = await SecurityLocalDataSource().auditLogs(module: 'HR');
      expect(
        logs.any(
          (log) =>
              log.action == 'DEACTIVATE' &&
              log.entityType == 'Worker' &&
              log.entityId == worker.id,
        ),
        isTrue,
      );
    });

    test(
      'valid assignment and invalid workshop/section relationship',
      () async {
        final worker = await dataSource.createWorker(
          employeeCode: 'EMP-002',
          name: 'سارة محمد',
          basicSalary: 4200,
          salaryType: SalaryType.monthly,
        );
        await dataSource.assignWorker(
          workerId: worker.id,
          sectionId: sectionId,
          workshopId: workshopId,
          productionStageId: stageId,
        );
        final saved = await dataSource.getWorker(worker.id);
        expect(saved.sectionId, sectionId);
        expect(saved.workshopId, workshopId);
        expect(saved.productionStageId, stageId);

        final otherSection =
            'section-other-${DateTime.now().microsecondsSinceEpoch}';
        await FurnexaDatabase.instance.database.then(
          (db) => db.insert('sections', {
            'id': otherSection,
            'factoryId': factoryId,
            'name': 'قسم آخر',
            'code': 'SEC-OTHER',
            'active': 1,
            'createdAt': DateTime.now().millisecondsSinceEpoch,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          }),
        );
        expect(
          () => dataSource.assignWorker(
            workerId: worker.id,
            sectionId: otherSection,
            workshopId: workshopId,
            productionStageId: stageId,
          ),
          throwsException,
        );
      },
    );

    test('attendance validation, late and early leave calculation', () async {
      final worker = await dataSource.createWorker(
        employeeCode: 'EMP-003',
        name: 'محمود حسن',
        basicSalary: 4500,
        salaryType: SalaryType.monthly,
      );
      final attendance = await dataSource.saveAttendance(
        workerId: worker.id,
        shiftId: shiftId,
        workDate: workDate,
        checkIn: DateTime(2026, 9, 17, 8, 20),
        checkOut: DateTime(2026, 9, 17, 16, 30),
        status: AttendanceStatus.present,
      );
      expect(attendance.lateMinutes, 5);
      expect(attendance.earlyLeaveMinutes, 0);

      final partial = await dataSource.saveAttendance(
        workerId: worker.id,
        shiftId: shiftId,
        workDate: workDate.add(const Duration(days: 1)),
        checkIn: DateTime(2026, 9, 18, 8, 0),
        checkOut: DateTime(2026, 9, 18, 15, 30),
        status: AttendanceStatus.partial,
      );
      expect(partial.earlyLeaveMinutes, 30);

      expect(
        () => dataSource.saveAttendance(
          workerId: worker.id,
          shiftId: shiftId,
          workDate: workDate,
          checkIn: DateTime(2026, 9, 17, 9, 0),
          checkOut: DateTime(2026, 9, 17, 8, 0),
          status: AttendanceStatus.present,
        ),
        throwsException,
      );
    });

    test('overtime hours and amount with worker override', () async {
      final worker = await dataSource.createWorker(
        employeeCode: 'EMP-004',
        name: 'إيمان ياسر',
        basicSalary: 6000,
        salaryType: SalaryType.monthly,
        overtimeEnabled: true,
        overtimeRateOverride: 75,
      );
      final attendance = await dataSource.saveAttendance(
        workerId: worker.id,
        shiftId: shiftId,
        workDate: workDate,
        checkIn: DateTime(2026, 9, 17, 8, 0),
        checkOut: DateTime(2026, 9, 17, 18, 0),
        status: AttendanceStatus.present,
      );
      expect(attendance.regularHours, closeTo(8, 0.1));
      expect(attendance.overtimeHours, closeTo(2, 0.1));
      expect(attendance.overtimeRate, 75);
      expect(attendance.overtimeAmount, 150);

      final worker2 = await dataSource.createWorker(
        employeeCode: 'EMP-005',
        name: 'عبدالله علي',
        basicSalary: 5000,
        salaryType: SalaryType.monthly,
      );
      final historical = await dataSource.saveAttendance(
        workerId: worker2.id,
        shiftId: shiftId,
        workDate: workDate.add(const Duration(days: 2)),
        checkIn: DateTime(2026, 9, 19, 8, 0),
        checkOut: DateTime(2026, 9, 19, 17, 0),
        status: AttendanceStatus.present,
      );
      expect(historical.overtimeHours, 1);
    });

    test('leave and leave balance', () async {
      final worker = await dataSource.createWorker(
        employeeCode: 'EMP-006',
        name: 'نور الدين',
        basicSalary: 5200,
        salaryType: SalaryType.monthly,
        annualLeaveAllowance: 21,
      );
      final leave = await dataSource.createLeave(
        workerId: worker.id,
        leaveType: LeaveType.annual,
        startDate: DateTime(2026, 9, 20),
        endDate: DateTime(2026, 9, 21),
        reason: 'إجازة سنوية',
        status: LeaveStatus.approved,
      );
      expect(leave.days, 2);
      expect(
        (await dataSource.getEmployeeLeaveBalance(worker.id)).remaining,
        19,
      );
      final attendance = await dataSource.getAttendance(
        worker.id,
        DateTime(2026, 9, 20),
      );
      expect(attendance?.status, AttendanceStatus.leave);
      expect(
        () => dataSource.createLeave(
          workerId: worker.id,
          leaveType: LeaveType.annual,
          startDate: DateTime(2026, 9, 20),
          endDate: DateTime(2026, 9, 22),
          reason: 'تداخل',
          status: LeaveStatus.approved,
        ),
        throwsException,
      );
    });

    test('deduction and payroll snapshot', () async {
      final worker = await dataSource.createWorker(
        employeeCode: 'EMP-007',
        name: 'مريم عبد الله',
        basicSalary: 6000,
        salaryType: SalaryType.monthly,
      );
      await dataSource.saveAttendance(
        workerId: worker.id,
        shiftId: shiftId,
        workDate: DateTime(2026, 9, 22),
        checkIn: DateTime(2026, 9, 22, 8, 0),
        checkOut: DateTime(2026, 9, 22, 18, 0),
        status: AttendanceStatus.present,
      );
      await dataSource.createDeduction(
        workerId: worker.id,
        date: DateTime(2026, 9, 22),
        type: DeductionType.manual,
        amount: 200,
        reason: 'خصم تجريبي',
        status: DeductionStatus.approved,
      );
      final period = await dataSource.createPayrollPeriod(
        name: 'September 2026',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 30),
      );
      final payroll = await dataSource.calculatePayroll(
        payrollPeriodId: period.id,
        workerId: worker.id,
      );
      expect(payroll.grossSalary, 6100);
      expect(payroll.deductionsAmount, 200);
      expect(payroll.netSalary, 5900);
      await dataSource.createWorker(
        employeeCode: 'EMP-008',
        name: 'مهندس جديد',
        basicSalary: 7000,
        salaryType: SalaryType.monthly,
      );
      final stored = await dataSource.getPayroll(worker.id, period.id);
      expect(stored?.workerId, worker.id);
    });

    test('payroll mutations require payroll approval permission', () async {
      final security = SecurityLocalDataSource();
      final role = await security.createRole(name: 'HR Editor');
      await security.setRolePermissions(role.id, ['HR_EDIT']);
      final user = await security.createUser(
        username: 'hr-editor',
        displayName: 'HR Editor',
        password: 'secret123',
        roleId: role.id,
      );
      security.logout();
      await security.login(user.username, 'secret123');
      expect(
        () => dataSource.calculatePayroll(
          payrollPeriodId: 'missing-period',
          workerId: 'missing-worker',
        ),
        throwsException,
      );
      expect(
        () => dataSource.approvePayroll('missing-payroll'),
        throwsException,
      );
      expect(
        () => dataSource.payPayroll(
          payrollRecordId: 'missing-payroll',
          cashboxId: 'cashbox',
        ),
        throwsException,
      );
    });

    test('HR mutation requires authentication', () async {
      final security = SecurityLocalDataSource();
      security.logout();
      expect(
        () => dataSource.createWorker(
          employeeCode: 'UNAUTH',
          name: 'غير مصرح',
          basicSalary: 1,
          salaryType: SalaryType.hourly,
        ),
        throwsException,
      );
      expect(
        () => dataSource.calculatePayroll(
          payrollPeriodId: 'missing-period',
          workerId: 'missing-worker',
        ),
        throwsException,
      );
      await security.login('admin', 'Furnexa-Test-Admin-2026!');
    });
  });
}
