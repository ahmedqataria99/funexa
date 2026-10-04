import 'dart:math' as math;

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/hr/domain/entities/hr_entities.dart';
import 'package:furnexa/features/accounting/data/datasources/accounting_local_data_source.dart';
import 'package:furnexa/features/accounting/domain/entities/accounting_entities.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';

class HrLocalDataSource {
  static int _sequence = 0;
  final AccountingLocalDataSource _accounting;

  HrLocalDataSource([AccountingLocalDataSource? accounting])
    : _accounting = accounting ?? AccountingLocalDataSource();

  Future<Database> get _db async => FurnexaDatabase.instance.database;

  String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';

  Future<Worker> createWorker({
    required String employeeCode,
    required String name,
    String? phone,
    String? email,
    String? address,
    DateTime? hireDate,
    String? sectionId,
    String? workshopId,
    String? productionStageId,
    bool active = true,
    required double basicSalary,
    required SalaryType salaryType,
    bool overtimeEnabled = false,
    double? overtimeRateOverride,
    String? notes,
    double annualLeaveAllowance = 0,
  }) async {
    final security = SecurityLocalDataSource();
    await security.requireFresh('HR_EDIT');
    final db = await _db;
    final code = employeeCode.trim();
    final cleanName = name.trim();
    if (code.isEmpty) throw Exception('رمز الموظف مطلوب');
    if (cleanName.isEmpty) throw Exception('اسم العامل مطلوب');
    if (basicSalary < 0)
      throw Exception('الراتب الأساسي لا يمكن أن يكون سالباً');
    if (overtimeRateOverride != null && overtimeRateOverride <= 0) {
      throw Exception('سعر الإضافي يجب أن يكون أكبر من صفر');
    }

    final existing = await db.query(
      'workers',
      where: 'employeeCode = ?',
      whereArgs: [code],
      limit: 1,
    );
    if (existing.isNotEmpty) throw Exception('رمز الموظف مكرر');

    final worker = Worker(
      id: _id('worker'),
      employeeCode: code,
      name: cleanName,
      phone: phone?.trim(),
      email: email?.trim(),
      address: address?.trim(),
      hireDate: hireDate ?? DateTime.now(),
      sectionId: sectionId,
      workshopId: workshopId,
      productionStageId: productionStageId,
      active: active,
      basicSalary: basicSalary,
      salaryType: salaryType,
      overtimeEnabled: overtimeEnabled,
      overtimeRateOverride: overtimeRateOverride,
      notes: notes,
      annualLeaveAllowance: annualLeaveAllowance,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await db.insert('workers', worker.toMap());
    if (sectionId != null || workshopId != null || productionStageId != null) {
      await assignWorker(
        workerId: worker.id,
        sectionId: sectionId,
        workshopId: workshopId,
        productionStageId: productionStageId,
      );
    }
    return getWorker(worker.id);
  }

  Future<Worker> getWorker(String id) async {
    final db = await _db;
    final rows = await db.query(
      'workers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('الموظف غير موجود');
    return Worker.fromMap(rows.first);
  }

  Future<List<Worker>> workers({String query = ''}) async {
    final db = await _db;
    final text = query.trim();
    final rows = text.isEmpty
        ? await db.query('workers', orderBy: 'name ASC')
        : await db.query(
            'workers',
            where: 'LOWER(name) LIKE ? OR LOWER(employeeCode) LIKE ?',
            whereArgs: ['%${text.toLowerCase()}%', '%${text.toLowerCase()}%'],
            orderBy: 'name ASC',
          );
    return rows.map(Worker.fromMap).toList();
  }

  Future<void> deactivateWorker(String id) async {
    final security = SecurityLocalDataSource();
    await security.requireFresh('HR_EDIT');
    final db = await _db;
    await db.update(
      'workers',
      {'active': 0, 'updatedAt': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
    await security.audit(
      action: 'DEACTIVATE',
      module: 'HR',
      entityType: 'Worker',
      entityId: id,
      description: 'Worker deactivated',
    );
  }

  Future<void> assignWorker({
    required String workerId,
    String? sectionId,
    String? workshopId,
    String? productionStageId,
  }) async {
    SecurityLocalDataSource().require('HR_EDIT');
    final db = await _db;
    final workerRows = await db.query(
      'workers',
      where: 'id = ?',
      whereArgs: [workerId],
      limit: 1,
    );
    if (workerRows.isEmpty) throw Exception('الموظف غير موجود');
    final worker = Worker.fromMap(workerRows.first);
    if (!worker.active) throw Exception('لا يمكن تعيين موظف غير نشط');

    if (sectionId != null) {
      final section = await db.query(
        'sections',
        where: 'id = ? AND active = 1',
        whereArgs: [sectionId],
        limit: 1,
      );
      if (section.isEmpty) throw Exception('القسم غير موجود أو غير نشط');
    }

    if (workshopId != null) {
      if (sectionId == null) throw Exception('يجب تحديد القسم للورشة');
      final workshopRows = await db.query(
        'workshops',
        where: 'id = ? AND active = 1',
        whereArgs: [workshopId],
        limit: 1,
      );
      if (workshopRows.isEmpty)
        throw Exception('الورشة غير موجودة أو غير نشطة');
      if (workshopRows.first['sectionId'] != sectionId) {
        throw Exception('العلاقة بين القسم والورشة غير صحيحة');
      }
    }

    if (productionStageId != null) {
      final stageRows = await db.query(
        'production_stages',
        where: 'id = ? AND active = 1',
        whereArgs: [productionStageId],
        limit: 1,
      );
      if (stageRows.isEmpty)
        throw Exception('مرحلة الإنتاج غير موجودة أو غير نشطة');
    }

    await db.insert('worker_assignments', {
      'id': _id('assignment'),
      'workerId': workerId,
      'sectionId': sectionId,
      'workshopId': workshopId,
      'productionStageId': productionStageId,
      'active': 1,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await db.update(
      'workers',
      {
        'sectionId': sectionId,
        'workshopId': workshopId,
        'productionStageId': productionStageId,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [workerId],
    );
  }

  Future<Shift> createShift({
    required String name,
    required String startTime,
    required String endTime,
    int graceMinutes = 0,
    bool overtimeEnabled = false,
    int overtimeStartAfterMinutes = 0,
    double overtimeRate = 0,
    bool active = true,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) throw Exception('اسم الشيفت مطلوب');
    if (startTime.trim().isEmpty || endTime.trim().isEmpty) {
      throw Exception('يجب تحديد وقت البدء والانتهاء');
    }
    if (graceMinutes < 0) throw Exception('فترة السماح لا يمكن أن تكون سالبة');
    if (overtimeRate < 0) throw Exception('سعر الإضافة لا يمكن أن يكون سالباً');

    final shift = Shift(
      id: _id('shift'),
      name: cleanName,
      startTime: startTime,
      endTime: endTime,
      graceMinutes: graceMinutes,
      overtimeEnabled: overtimeEnabled,
      overtimeStartAfterMinutes: overtimeStartAfterMinutes,
      overtimeRate: overtimeRate,
      active: active,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await (await _db).insert('shifts', shift.toMap());
    return shift;
  }

  Future<List<Shift>> shifts() async {
    final db = await _db;
    final rows = await db.query('shifts', orderBy: 'name ASC');
    return rows.map(Shift.fromMap).toList();
  }

  Future<AttendanceRecord> saveAttendance({
    required String workerId,
    required String shiftId,
    required DateTime workDate,
    DateTime? checkIn,
    DateTime? checkOut,
    required AttendanceStatus status,
    String? notes,
  }) async {
    final db = await _db;
    final worker = await getWorker(workerId);
    if (!worker.active) throw Exception('لا يمكن تسجيل حضور موظف غير نشط');

    final shiftRows = await db.query(
      'shifts',
      where: 'id = ? AND active = 1',
      whereArgs: [shiftId],
      limit: 1,
    );
    if (shiftRows.isEmpty) throw Exception('الشيفت غير موجود أو غير نشط');
    final shift = Shift.fromMap(shiftRows.first);

    final dayStart = _dayStart(workDate);
    final duplicate = await db.query(
      'attendance_records',
      where: 'workerId = ? AND workDate = ?',
      whereArgs: [workerId, dayStart.millisecondsSinceEpoch],
      limit: 1,
    );
    if (duplicate.isNotEmpty)
      throw Exception('تم تسجيل حضور هذا الموظف لهذا التاريخ مسبقاً');

    final now = DateTime.now();
    final record = _calculateAttendance(
      worker: worker,
      shift: shift,
      workDate: dayStart,
      checkIn: checkIn,
      checkOut: checkOut,
      status: status,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
    await db.insert('attendance_records', record.toMap());
    return record;
  }

  Future<AttendanceRecord?> getAttendance(
    String workerId,
    DateTime workDate,
  ) async {
    final db = await _db;
    final day = _dayStart(workDate);
    final rows = await db.query(
      'attendance_records',
      where: 'workerId = ? AND workDate = ?',
      whereArgs: [workerId, day.millisecondsSinceEpoch],
      limit: 1,
    );
    if (rows.isEmpty) {
      final leave = await _approvedLeaveForDate(workerId, day);
      if (leave == null) return null;
      return AttendanceRecord(
        id: 'leave-${DateTime.now().microsecondsSinceEpoch}',
        workerId: workerId,
        shiftId: 'leave',
        workDate: day,
        status: AttendanceStatus.leave,
        checkIn: null,
        checkOut: null,
        notes: leave.reason,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    return AttendanceRecord.fromMap(rows.first);
  }

  Future<List<AttendanceRecord>> attendanceHistory(String workerId) async {
    final db = await _db;
    final rows = await db.query(
      'attendance_records',
      where: 'workerId = ?',
      whereArgs: [workerId],
      orderBy: 'workDate DESC',
    );
    return rows.map(AttendanceRecord.fromMap).toList();
  }

  Future<Map<String, int>> attendanceOverview({
    String? sectionId,
    String? workshopId,
    String? shiftId,
    AttendanceStatus? status,
  }) async {
    final db = await _db;
    final todaysEpoch = _dayStart(DateTime.now()).millisecondsSinceEpoch;
    final rows = await db.rawQuery('''
      SELECT ar.status, COUNT(*) as count
      FROM attendance_records ar
      LEFT JOIN workers w ON w.id = ar.workerId
      WHERE ar.workDate = ?
      ${sectionId != null ? 'AND w.sectionId = ?' : ''}
      ${workshopId != null ? 'AND w.workshopId = ?' : ''}
      ${shiftId != null ? 'AND ar.shiftId = ?' : ''}
      ${status != null ? 'AND ar.status = ?' : ''}
      GROUP BY ar.status
      ''', _overviewArgs(todaysEpoch, sectionId, workshopId, shiftId, status));

    final map = <String, int>{
      'totalActiveWorkers': (await db.query(
        'workers',
        where: 'active = 1',
      )).length,
      'present': 0,
      'absent': 0,
      'onLeave': 0,
      'partial': 0,
      'lateWorkers': 0,
      'overtimeWorkers': 0,
      'notCheckedIn': 0,
    };
    for (final row in rows) {
      final key = (row['status'] as String).toLowerCase();
      map[key] = (row['count'] as int?) ?? 0;
    }
    map['notCheckedIn'] = math.max(
      0,
      map['totalActiveWorkers']! -
          ((map['present'] ?? 0) +
              (map['partial'] ?? 0) +
              (map['absent'] ?? 0) +
              (map['onLeave'] ?? 0)),
    );
    return {
      'totalActiveWorkers': map['totalActiveWorkers'] ?? 0,
      'present': map['present'] ?? 0,
      'absent': map['absent'] ?? 0,
      'onLeave': map['onLeave'] ?? 0,
      'partial': map['partial'] ?? 0,
      'notCheckedIn': map['notCheckedIn'] ?? 0,
      'lateWorkers': map['lateWorkers'] ?? 0,
      'overtimeWorkers': map['overtimeWorkers'] ?? 0,
    };
  }

  Future<LeaveRecord> createLeave({
    required String workerId,
    required LeaveType leaveType,
    required DateTime startDate,
    required DateTime endDate,
    String? reason,
    required LeaveStatus status,
    String? notes,
  }) async {
    final db = await _db;
    final worker = await getWorker(workerId);
    if (!worker.active) throw Exception('لا يمكن إنشاء إجازة لموظف غير نشط');
    final start = _dayStart(startDate);
    final end = _dayStart(endDate);
    if (end.isBefore(start))
      throw Exception('تاريخ النهاية لا يمكن أن يكون قبل البداية');
    final days = end.difference(start).inDays + 1;

    if (status == LeaveStatus.approved) {
      final overlap = await db.query(
        'leave_records',
        where:
            'workerId = ? AND status = ? AND startDate <= ? AND endDate >= ?',
        whereArgs: [
          workerId,
          LeaveStatus.approved.value,
          end.millisecondsSinceEpoch,
          start.millisecondsSinceEpoch,
        ],
      );
      if (overlap.isNotEmpty) throw Exception('يوجد إجازة معتمدة متداخلة');
    }

    final model = LeaveRecord(
      id: _id('leave'),
      workerId: workerId,
      leaveType: leaveType,
      startDate: start,
      endDate: end,
      days: days,
      reason: reason,
      status: status,
      notes: notes,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await db.insert('leave_records', model.toMap());

    if (status == LeaveStatus.approved) {
      final leaveShiftId = await _resolveLeaveShiftId(db);
      final dates = _datesBetween(start, end);
      for (final date in dates) {
        final existing = await db.query(
          'attendance_records',
          where: 'workerId = ? AND workDate = ?',
          whereArgs: [workerId, date.millisecondsSinceEpoch],
          limit: 1,
        );
        if (existing.isEmpty) {
          await db.insert('attendance_records', {
            'id': _id('attendance-leave'),
            'workerId': workerId,
            'shiftId': leaveShiftId,
            'workDate': date.millisecondsSinceEpoch,
            'status': AttendanceStatus.leave.value,
            'checkIn': null,
            'checkOut': null,
            'regularHours': 0,
            'overtimeHours': 0,
            'overtimeRate': 0,
            'overtimeAmount': 0,
            'lateMinutes': 0,
            'earlyLeaveMinutes': 0,
            'notes': 'إجازة',
            'createdAt': DateTime.now().millisecondsSinceEpoch,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          });
        } else {
          await db.update(
            'attendance_records',
            {
              'status': AttendanceStatus.leave.value,
              'updatedAt': DateTime.now().millisecondsSinceEpoch,
            },
            where: 'workerId = ? AND workDate = ?',
            whereArgs: [workerId, date.millisecondsSinceEpoch],
          );
        }
      }
    }
    return model;
  }

  Future<List<LeaveRecord>> leaveHistory(String workerId) async {
    final db = await _db;
    final rows = await db.query(
      'leave_records',
      where: 'workerId = ?',
      whereArgs: [workerId],
      orderBy: 'startDate DESC',
    );
    return rows.map(LeaveRecord.fromMap).toList();
  }

  Future<LeaveBalance> getEmployeeLeaveBalance(String workerId) async {
    final db = await _db;
    final workerRows = await db.query(
      'workers',
      where: 'id = ?',
      whereArgs: [workerId],
      limit: 1,
    );
    if (workerRows.isEmpty) throw Exception('الموظف غير موجود');
    final worker = Worker.fromMap(workerRows.first);
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(days), 0) AS used
      FROM leave_records
      WHERE workerId = ? AND leaveType = ? AND status = ?
      ''',
      [workerId, LeaveType.annual.value, LeaveStatus.approved.value],
    );
    final used = (rows.first['used'] as num?)?.toDouble() ?? 0;
    return LeaveBalance(
      workerId: workerId,
      annualLeaveAllowance: worker.annualLeaveAllowance,
      usedLeave: used,
      remaining: worker.annualLeaveAllowance - used,
    );
  }

  Future<Deduction> createDeduction({
    required String workerId,
    required DateTime date,
    required DeductionType type,
    required double amount,
    String? reason,
    String? notes,
    required DeductionStatus status,
  }) async {
    if (amount < 0) throw Exception('مبلغ الخصم لا يمكن أن يكون سالباً');
    final db = await _db;
    final deduction = Deduction(
      id: _id('deduction'),
      workerId: workerId,
      date: _dayStart(date),
      type: type,
      amount: amount,
      reason: reason,
      notes: notes,
      status: status,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await db.insert('deductions', deduction.toMap());
    return deduction;
  }

  Future<List<Deduction>> deductionsForWorker(String workerId) async {
    final db = await _db;
    final rows = await db.query(
      'deductions',
      where: 'workerId = ?',
      whereArgs: [workerId],
      orderBy: 'date DESC',
    );
    return rows.map(Deduction.fromMap).toList();
  }

  Future<PayrollPeriod> createPayrollPeriod({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    await SecurityLocalDataSource().requireFresh('HR_PAYROLL_APPROVE');
    final db = await _db;
    final existing = await db.query(
      'payroll_periods',
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    if (existing.isNotEmpty) throw Exception('فترة المرتبات موجودة مسبقاً');

    final period = PayrollPeriod(
      id: _id('payroll-period'),
      name: name,
      startDate: _dayStart(startDate),
      endDate: _dayStart(endDate),
      status: PayrollPeriodStatus.draft,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await db.insert('payroll_periods', period.toMap());
    return period;
  }

  Future<List<PayrollPeriod>> payrollPeriods() async {
    final db = await _db;
    final rows = await db.query('payroll_periods', orderBy: 'startDate DESC');
    return rows.map(PayrollPeriod.fromMap).toList();
  }

  Future<PayrollRecord> calculatePayroll({
    required String payrollPeriodId,
    required String workerId,
  }) async {
    await SecurityLocalDataSource().requireFresh('HR_PAYROLL_APPROVE');
    final db = await _db;
    final worker = await getWorker(workerId);
    if (!worker.active) throw Exception('لا يمكن احتساب مرتب موظف غير نشط');

    final periods = await db.query(
      'payroll_periods',
      where: 'id = ?',
      whereArgs: [payrollPeriodId],
      limit: 1,
    );
    if (periods.isEmpty) throw Exception('فترة المرتبات غير موجودة');

    final payrollExists = await db.query(
      'payroll_records',
      where: 'payrollPeriodId = ? AND workerId = ?',
      whereArgs: [payrollPeriodId, workerId],
      limit: 1,
    );
    if (payrollExists.isNotEmpty)
      throw Exception('تم احتساب المرتب لهذا الموظف لهذه الفترة مسبقاً');

    final period = PayrollPeriod.fromMap(periods.first);
    final attendanceRows = await db.query(
      'attendance_records',
      where: 'workerId = ? AND workDate >= ? AND workDate <= ?',
      whereArgs: [
        workerId,
        _dayStart(period.startDate).millisecondsSinceEpoch,
        _dayStart(period.endDate).millisecondsSinceEpoch,
      ],
    );
    final items = attendanceRows.map(AttendanceRecord.fromMap).toList();
    final regularHours = items.fold<double>(
      0,
      (sum, item) => sum + item.regularHours,
    );
    final overtimeHours = items.fold<double>(
      0,
      (sum, item) => sum + item.overtimeHours,
    );
    final overtimeAmount = items.fold<double>(
      0,
      (sum, item) => sum + item.overtimeAmount,
    );

    final deductionsRows = await db.query(
      'deductions',
      where: 'workerId = ? AND date >= ? AND date <= ? AND status = ?',
      whereArgs: [
        workerId,
        _dayStart(period.startDate).millisecondsSinceEpoch,
        _dayStart(period.endDate).millisecondsSinceEpoch,
        DeductionStatus.approved.value,
      ],
    );
    final deductionsAmount = deductionsRows.fold<double>(
      0,
      (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0),
    );

    double regularEarnings = 0;
    switch (worker.salaryType) {
      case SalaryType.monthly:
        regularEarnings = worker.basicSalary;
        break;
      case SalaryType.daily:
        final workingDays = _workingDaysBetween(
          period.startDate,
          period.endDate,
        );
        regularEarnings = workingDays == 0
            ? 0
            : worker.basicSalary * (items.length / workingDays);
        break;
      case SalaryType.hourly:
        regularEarnings = worker.basicSalary * (regularHours / 160);
        break;
    }

    final grossSalary = regularEarnings + overtimeAmount;
    final netSalary = grossSalary - deductionsAmount;
    final record = PayrollRecord(
      id: _id('payroll'),
      payrollPeriodId: payrollPeriodId,
      workerId: workerId,
      basicSalary: worker.basicSalary,
      regularEarnings: regularEarnings,
      overtimeHours: overtimeHours,
      overtimeAmount: overtimeAmount,
      deductionsAmount: deductionsAmount,
      grossSalary: grossSalary,
      netSalary: netSalary,
      notes: 'محسوب تلقائياً',
      status: PayrollRecordStatus.calculated,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await db.insert('payroll_records', record.toMap());
    return record;
  }

  Future<PayrollRecord?> getPayroll(
    String workerId,
    String payrollPeriodId,
  ) async {
    final db = await _db;
    final rows = await db.query(
      'payroll_records',
      where: 'workerId = ? AND payrollPeriodId = ?',
      whereArgs: [workerId, payrollPeriodId],
      limit: 1,
    );
    return rows.isEmpty ? null : PayrollRecord.fromMap(rows.first);
  }

  Future<PayrollRecord> approvePayroll(String payrollRecordId) async {
    await SecurityLocalDataSource().requireFresh('HR_PAYROLL_APPROVE');
    final db = await _db;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'payroll_records',
        where: 'id = ?',
        whereArgs: [payrollRecordId],
        limit: 1,
      );
      if (rows.isEmpty) throw Exception('سجل المرتب غير موجود');
      final record = PayrollRecord.fromMap(rows.first);
      if (record.status == PayrollRecordStatus.approved ||
          record.status == PayrollRecordStatus.paid) {
        return record;
      }
      if (record.status != PayrollRecordStatus.calculated) {
        throw Exception('لا يمكن اعتماد سجل المرتب في حالته الحالية');
      }
      final salary =
          (await txn.query(
                'accounts',
                columns: ['id'],
                where: 'code = ? AND active = 1',
                whereArgs: ['5100'],
                limit: 1,
              )).single['id']
              as String;
      final payable =
          (await txn.query(
                'accounts',
                columns: ['id'],
                where: 'code = ? AND active = 1',
                whereArgs: ['2010'],
                limit: 1,
              )).single['id']
              as String;
      await _accounting.postJournalWithinTransaction(
        executor: txn,
        date: record.updatedAt,
        description: 'اعتماد راتب ${record.id}',
        referenceType: 'PAYROLL_APPROVAL',
        referenceId: record.id,
        partyType: 'WORKER',
        partyId: record.workerId,
        lines: [
          JournalLineInput(accountId: salary, debit: record.grossSalary),
          JournalLineInput(accountId: payable, credit: record.grossSalary),
        ],
      );
      await txn.update(
        'payroll_records',
        {
          'status': PayrollRecordStatus.approved.value,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [record.id],
      );
      return PayrollRecord.fromMap(
        (await txn.query(
          'payroll_records',
          where: 'id = ?',
          whereArgs: [record.id],
          limit: 1,
        )).single,
      );
    });
  }

  Future<PayrollRecord> payPayroll({
    required String payrollRecordId,
    String? cashboxId,
    String? bankAccountId,
  }) async {
    await SecurityLocalDataSource().requireFresh('HR_PAYROLL_APPROVE');
    if ((cashboxId == null) == (bankAccountId == null)) {
      throw Exception('اختر خزينة أو حساباً بنكياً واحداً');
    }
    final db = await _db;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'payroll_records',
        where: 'id = ?',
        whereArgs: [payrollRecordId],
        limit: 1,
      );
      if (rows.isEmpty) throw Exception('سجل المرتب غير موجود');
      final record = PayrollRecord.fromMap(rows.first);
      if (record.status == PayrollRecordStatus.paid) return record;
      if (record.status != PayrollRecordStatus.approved)
        throw Exception('يجب اعتماد المرتب أولاً');
      final table = cashboxId == null ? 'bank_accounts' : 'cashboxes';
      final moneyId = cashboxId ?? bankAccountId!;
      final moneyAccount =
          (await txn.query(
                table,
                columns: ['accountId'],
                where: 'id = ? AND active = 1',
                whereArgs: [moneyId],
                limit: 1,
              )).single['accountId']
              as String;
      final payable =
          (await txn.query(
                'accounts',
                columns: ['id'],
                where: 'code = ? AND active = 1',
                whereArgs: ['2010'],
                limit: 1,
              )).single['id']
              as String;
      await _accounting.postJournalWithinTransaction(
        executor: txn,
        date: DateTime.now(),
        description: 'صرف راتب ${record.id}',
        referenceType: 'PAYROLL_PAYMENT',
        referenceId: record.id,
        partyType: 'WORKER',
        partyId: record.workerId,
        lines: [
          JournalLineInput(accountId: payable, debit: record.netSalary),
          JournalLineInput(accountId: moneyAccount, credit: record.netSalary),
        ],
      );
      await txn.update(
        'payroll_records',
        {
          'status': PayrollRecordStatus.paid.value,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [record.id],
      );
      return PayrollRecord.fromMap(
        (await txn.query(
          'payroll_records',
          where: 'id = ?',
          whereArgs: [record.id],
          limit: 1,
        )).single,
      );
    });
  }

  Future<List<PayrollRecord>> payrollHistory(String workerId) async {
    final db = await _db;
    final rows = await db.query(
      'payroll_records',
      where: 'workerId = ?',
      whereArgs: [workerId],
      orderBy: 'createdAt DESC',
    );
    return rows.map(PayrollRecord.fromMap).toList();
  }

  AttendanceRecord _calculateAttendance({
    required Worker worker,
    required Shift shift,
    required DateTime workDate,
    DateTime? checkIn,
    DateTime? checkOut,
    required AttendanceStatus status,
    String? notes,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    final finalStatus =
        status == AttendanceStatus.absent ||
            status == AttendanceStatus.offDay ||
            status == AttendanceStatus.leave
        ? status
        : status;

    if (finalStatus == AttendanceStatus.absent ||
        finalStatus == AttendanceStatus.offDay ||
        finalStatus == AttendanceStatus.leave) {
      return AttendanceRecord(
        id: _id('attendance'),
        workerId: worker.id,
        shiftId: shift.id,
        workDate: workDate,
        status: finalStatus,
        checkIn: null,
        checkOut: null,
        regularHours: 0,
        overtimeHours: 0,
        overtimeRate: 0,
        overtimeAmount: 0,
        lateMinutes: 0,
        earlyLeaveMinutes: 0,
        notes: notes,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
    }

    if (checkIn == null || checkOut == null)
      throw Exception('تاريخ الحضور غير مكتمل');
    if (checkOut.isBefore(checkIn))
      throw Exception('تاريخ الخروج لا يمكن أن يكون قبل الدخول');

    final shiftStart = _combineDateAndTime(workDate, shift.startTime);
    final shiftEnd = _combineDateAndTime(workDate, shift.endTime);
    final totalShiftMinutes = shiftEnd.difference(shiftStart).inMinutes;
    final workedMinutes = checkOut.difference(checkIn).inMinutes;
    final graceCutoff = shiftStart.add(Duration(minutes: shift.graceMinutes));
    final lateMinutes = checkIn.isAfter(graceCutoff)
        ? checkIn.difference(graceCutoff).inMinutes
        : 0;
    final earlyLeaveMinutes = checkOut.isBefore(shiftEnd)
        ? shiftEnd.difference(checkOut).inMinutes
        : 0;
    final regularMinutes = math
        .min(totalShiftMinutes, workedMinutes)
        .clamp(0, totalShiftMinutes);
    final overtimeMinutes = shift.overtimeEnabled
        ? math.max(0, workedMinutes - totalShiftMinutes)
        : 0;
    final effectiveRate =
        worker.overtimeEnabled && worker.overtimeRateOverride != null
        ? worker.overtimeRateOverride!
        : shift.overtimeRate;
    final overtimeHours = overtimeMinutes / 60;
    final overtimeAmount = overtimeHours * effectiveRate;

    return AttendanceRecord(
      id: _id('attendance'),
      workerId: worker.id,
      shiftId: shift.id,
      workDate: workDate,
      status: status,
      checkIn: checkIn,
      checkOut: checkOut,
      regularHours: regularMinutes / 60,
      overtimeHours: overtimeHours,
      overtimeRate: effectiveRate,
      overtimeAmount: overtimeAmount,
      lateMinutes: lateMinutes,
      earlyLeaveMinutes: earlyLeaveMinutes,
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Future<LeaveRecord?> _approvedLeaveForDate(
    String workerId,
    DateTime date,
  ) async {
    final db = await _db;
    final rows = await db.query(
      'leave_records',
      where: 'workerId = ? AND status = ? AND startDate <= ? AND endDate >= ?',
      whereArgs: [
        workerId,
        LeaveStatus.approved.value,
        date.millisecondsSinceEpoch,
        date.millisecondsSinceEpoch,
      ],
    );
    return rows.isEmpty ? null : LeaveRecord.fromMap(rows.first);
  }

  List<DateTime> _datesBetween(DateTime start, DateTime end) {
    final list = <DateTime>[];
    var current = _dayStart(start);
    final finalDate = _dayStart(end);
    while (!current.isAfter(finalDate)) {
      list.add(current);
      current = current.add(const Duration(days: 1));
    }
    return list;
  }

  Future<String> _resolveLeaveShiftId(Database db) async {
    final rows = await db.query(
      'shifts',
      where: 'active = 1',
      orderBy: 'createdAt DESC',
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first['id'] as String;

    final leaveShiftId = _id('shift-leave');
    await db.insert('shifts', {
      'id': leaveShiftId,
      'name': 'إجازة عامة',
      'startTime': '00:00',
      'endTime': '00:00',
      'graceMinutes': 0,
      'overtimeEnabled': 0,
      'overtimeStartAfterMinutes': 0,
      'overtimeRate': 0,
      'active': 1,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
    return leaveShiftId;
  }

  DateTime _dayStart(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  DateTime _combineDateAndTime(DateTime date, String time) {
    final parts = time.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  int _workingDaysBetween(DateTime startDate, DateTime endDate) {
    var count = 0;
    var current = _dayStart(startDate);
    final finalDate = _dayStart(endDate);
    while (!current.isAfter(finalDate)) {
      if (current.weekday >= DateTime.monday &&
          current.weekday <= DateTime.friday) {
        count++;
      }
      current = current.add(const Duration(days: 1));
    }
    return count;
  }

  List<Object?> _overviewArgs(
    int todaysEpoch,
    String? sectionId,
    String? workshopId,
    String? shiftId,
    AttendanceStatus? status,
  ) {
    final args = <Object?>[todaysEpoch];
    if (sectionId != null) args.add(sectionId);
    if (workshopId != null) args.add(workshopId);
    if (shiftId != null) args.add(shiftId);
    if (status != null) args.add(status.value);
    return args;
  }
}
