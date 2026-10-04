enum SalaryType { monthly, daily, hourly }

extension SalaryTypeValue on SalaryType {
  String get value {
    switch (this) {
      case SalaryType.monthly:
        return 'MONTHLY';
      case SalaryType.daily:
        return 'DAILY';
      case SalaryType.hourly:
        return 'HOURLY';
    }
  }

  static SalaryType fromValue(String? value) {
    switch (value) {
      case 'MONTHLY':
        return SalaryType.monthly;
      case 'DAILY':
        return SalaryType.daily;
      case 'HOURLY':
        return SalaryType.hourly;
      default:
        return SalaryType.monthly;
    }
  }
}

enum AttendanceStatus { present, absent, leave, offDay, partial }

extension AttendanceStatusValue on AttendanceStatus {
  String get value {
    switch (this) {
      case AttendanceStatus.present:
        return 'PRESENT';
      case AttendanceStatus.absent:
        return 'ABSENT';
      case AttendanceStatus.leave:
        return 'LEAVE';
      case AttendanceStatus.offDay:
        return 'OFF_DAY';
      case AttendanceStatus.partial:
        return 'PARTIAL';
    }
  }

  static AttendanceStatus fromValue(String? value) {
    switch (value) {
      case 'PRESENT':
        return AttendanceStatus.present;
      case 'ABSENT':
        return AttendanceStatus.absent;
      case 'LEAVE':
        return AttendanceStatus.leave;
      case 'OFF_DAY':
        return AttendanceStatus.offDay;
      case 'PARTIAL':
        return AttendanceStatus.partial;
      default:
        return AttendanceStatus.absent;
    }
  }
}

enum LeaveType { annual, sick, unpaid, other }

extension LeaveTypeValue on LeaveType {
  String get value {
    switch (this) {
      case LeaveType.annual:
        return 'ANNUAL';
      case LeaveType.sick:
        return 'SICK';
      case LeaveType.unpaid:
        return 'UNPAID';
      case LeaveType.other:
        return 'OTHER';
    }
  }

  static LeaveType fromValue(String? value) {
    switch (value) {
      case 'ANNUAL':
        return LeaveType.annual;
      case 'SICK':
        return LeaveType.sick;
      case 'UNPAID':
        return LeaveType.unpaid;
      case 'OTHER':
        return LeaveType.other;
      default:
        return LeaveType.other;
    }
  }
}

enum LeaveStatus { pending, approved, rejected, cancelled }

extension LeaveStatusValue on LeaveStatus {
  String get value {
    switch (this) {
      case LeaveStatus.pending:
        return 'PENDING';
      case LeaveStatus.approved:
        return 'APPROVED';
      case LeaveStatus.rejected:
        return 'REJECTED';
      case LeaveStatus.cancelled:
        return 'CANCELLED';
    }
  }

  static LeaveStatus fromValue(String? value) {
    switch (value) {
      case 'PENDING':
        return LeaveStatus.pending;
      case 'APPROVED':
        return LeaveStatus.approved;
      case 'REJECTED':
        return LeaveStatus.rejected;
      case 'CANCELLED':
        return LeaveStatus.cancelled;
      default:
        return LeaveStatus.pending;
    }
  }
}

enum DeductionType { late, absence, manual, other }

extension DeductionTypeValue on DeductionType {
  String get value {
    switch (this) {
      case DeductionType.late:
        return 'LATE';
      case DeductionType.absence:
        return 'ABSENCE';
      case DeductionType.manual:
        return 'MANUAL';
      case DeductionType.other:
        return 'OTHER';
    }
  }

  static DeductionType fromValue(String? value) {
    switch (value) {
      case 'LATE':
        return DeductionType.late;
      case 'ABSENCE':
        return DeductionType.absence;
      case 'MANUAL':
        return DeductionType.manual;
      case 'OTHER':
        return DeductionType.other;
      default:
        return DeductionType.other;
    }
  }
}

enum DeductionStatus { pending, approved, rejected }

extension DeductionStatusValue on DeductionStatus {
  String get value {
    switch (this) {
      case DeductionStatus.pending:
        return 'PENDING';
      case DeductionStatus.approved:
        return 'APPROVED';
      case DeductionStatus.rejected:
        return 'REJECTED';
    }
  }

  static DeductionStatus fromValue(String? value) {
    switch (value) {
      case 'PENDING':
        return DeductionStatus.pending;
      case 'APPROVED':
        return DeductionStatus.approved;
      case 'REJECTED':
        return DeductionStatus.rejected;
      default:
        return DeductionStatus.pending;
    }
  }
}

enum PayrollPeriodStatus { draft, calculated, approved, paid }

extension PayrollPeriodStatusValue on PayrollPeriodStatus {
  String get value {
    switch (this) {
      case PayrollPeriodStatus.draft:
        return 'DRAFT';
      case PayrollPeriodStatus.calculated:
        return 'CALCULATED';
      case PayrollPeriodStatus.approved:
        return 'APPROVED';
      case PayrollPeriodStatus.paid:
        return 'PAID';
    }
  }

  static PayrollPeriodStatus fromValue(String? value) {
    switch (value) {
      case 'DRAFT':
        return PayrollPeriodStatus.draft;
      case 'CALCULATED':
        return PayrollPeriodStatus.calculated;
      case 'APPROVED':
        return PayrollPeriodStatus.approved;
      case 'PAID':
        return PayrollPeriodStatus.paid;
      default:
        return PayrollPeriodStatus.draft;
    }
  }
}

enum PayrollRecordStatus { draft, calculated, approved, paid }

extension PayrollRecordStatusValue on PayrollRecordStatus {
  String get value {
    switch (this) {
      case PayrollRecordStatus.draft:
        return 'DRAFT';
      case PayrollRecordStatus.calculated:
        return 'CALCULATED';
      case PayrollRecordStatus.approved:
        return 'APPROVED';
      case PayrollRecordStatus.paid:
        return 'PAID';
    }
  }

  static PayrollRecordStatus fromValue(String? value) {
    switch (value) {
      case 'DRAFT':
        return PayrollRecordStatus.draft;
      case 'CALCULATED':
        return PayrollRecordStatus.calculated;
      case 'APPROVED':
        return PayrollRecordStatus.approved;
      case 'PAID':
        return PayrollRecordStatus.paid;
      default:
        return PayrollRecordStatus.draft;
    }
  }
}

class Worker {
  Worker({
    required this.id,
    required this.employeeCode,
    required this.name,
    this.phone,
    this.email,
    this.address,
    required this.hireDate,
    this.sectionId,
    this.workshopId,
    this.productionStageId,
    this.active = true,
    required this.basicSalary,
    required this.salaryType,
    this.overtimeEnabled = false,
    this.overtimeRateOverride,
    this.notes,
    this.annualLeaveAllowance = 0,
    required this.createdAt,
    required this.updatedAt,
  }) {
    if (name.trim().isEmpty) throw ArgumentError('اسم العامل مطلوب');
    if (employeeCode.trim().isEmpty) throw ArgumentError('رمز الموظف مطلوب');
    if (basicSalary < 0)
      throw ArgumentError('الراتب الأساسي لا يمكن أن يكون سالباً');
  }

  final String id;
  final String employeeCode;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final DateTime hireDate;
  final String? sectionId;
  final String? workshopId;
  final String? productionStageId;
  final bool active;
  final double basicSalary;
  final SalaryType salaryType;
  final bool overtimeEnabled;
  final double? overtimeRateOverride;
  final String? notes;
  final double annualLeaveAllowance;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'employeeCode': employeeCode.trim(),
    'name': name.trim(),
    'phone': phone?.trim(),
    'email': email?.trim(),
    'address': address?.trim(),
    'hireDate': hireDate.millisecondsSinceEpoch,
    'sectionId': sectionId,
    'workshopId': workshopId,
    'productionStageId': productionStageId,
    'active': active ? 1 : 0,
    'basicSalary': basicSalary,
    'salaryType': salaryType.value,
    'overtimeEnabled': overtimeEnabled ? 1 : 0,
    'overtimeRateOverride': overtimeRateOverride,
    'notes': notes?.trim(),
    'annualLeaveAllowance': annualLeaveAllowance,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  factory Worker.fromMap(Map<String, Object?> map) => Worker(
    id: map['id'] as String,
    employeeCode: map['employeeCode'] as String,
    name: map['name'] as String,
    phone: map['phone'] as String?,
    email: map['email'] as String?,
    address: map['address'] as String?,
    hireDate: DateTime.fromMillisecondsSinceEpoch(map['hireDate'] as int),
    sectionId: map['sectionId'] as String?,
    workshopId: map['workshopId'] as String?,
    productionStageId: map['productionStageId'] as String?,
    active: (map['active'] as int? ?? 1) == 1,
    basicSalary: (map['basicSalary'] as num?)?.toDouble() ?? 0,
    salaryType: SalaryTypeValue.fromValue(map['salaryType'] as String?),
    overtimeEnabled: (map['overtimeEnabled'] as int? ?? 0) == 1,
    overtimeRateOverride: (map['overtimeRateOverride'] as num?)?.toDouble(),
    notes: map['notes'] as String?,
    annualLeaveAllowance:
        (map['annualLeaveAllowance'] as num?)?.toDouble() ?? 0,
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
  );
}

class Shift {
  Shift({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.graceMinutes,
    required this.overtimeEnabled,
    required this.overtimeStartAfterMinutes,
    required this.overtimeRate,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  }) {
    if (name.trim().isEmpty) throw ArgumentError('اسم الشيفت مطلوب');
    if (graceMinutes < 0)
      throw ArgumentError('فترة السماح لا يمكن أن تكون سالبة');
    if (overtimeRate < 0)
      throw ArgumentError('سعر الإضافي لا يمكن أن يكون سالباً');
  }

  final String id;
  final String name;
  final String startTime;
  final String endTime;
  final int graceMinutes;
  final bool overtimeEnabled;
  final int overtimeStartAfterMinutes;
  final double overtimeRate;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name.trim(),
    'startTime': startTime,
    'endTime': endTime,
    'graceMinutes': graceMinutes,
    'overtimeEnabled': overtimeEnabled ? 1 : 0,
    'overtimeStartAfterMinutes': overtimeStartAfterMinutes,
    'overtimeRate': overtimeRate,
    'active': active ? 1 : 0,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  factory Shift.fromMap(Map<String, Object?> map) => Shift(
    id: map['id'] as String,
    name: map['name'] as String,
    startTime: map['startTime'] as String,
    endTime: map['endTime'] as String,
    graceMinutes: (map['graceMinutes'] as int?) ?? 0,
    overtimeEnabled: (map['overtimeEnabled'] as int? ?? 0) == 1,
    overtimeStartAfterMinutes: (map['overtimeStartAfterMinutes'] as int?) ?? 0,
    overtimeRate: (map['overtimeRate'] as num?)?.toDouble() ?? 0,
    active: (map['active'] as int? ?? 1) == 1,
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
  );
}

class AttendanceRecord {
  AttendanceRecord({
    required this.id,
    required this.workerId,
    required this.shiftId,
    required this.workDate,
    required this.status,
    this.checkIn,
    this.checkOut,
    this.regularHours = 0,
    this.overtimeHours = 0,
    this.overtimeRate = 0,
    this.overtimeAmount = 0,
    this.lateMinutes = 0,
    this.earlyLeaveMinutes = 0,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String workerId;
  final String shiftId;
  final DateTime workDate;
  final AttendanceStatus status;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final double regularHours;
  final double overtimeHours;
  final double overtimeRate;
  final double overtimeAmount;
  final int lateMinutes;
  final int earlyLeaveMinutes;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'workerId': workerId,
    'shiftId': shiftId,
    'workDate': workDate.millisecondsSinceEpoch,
    'status': status.value,
    'checkIn': checkIn?.millisecondsSinceEpoch,
    'checkOut': checkOut?.millisecondsSinceEpoch,
    'regularHours': regularHours,
    'overtimeHours': overtimeHours,
    'overtimeRate': overtimeRate,
    'overtimeAmount': overtimeAmount,
    'lateMinutes': lateMinutes,
    'earlyLeaveMinutes': earlyLeaveMinutes,
    'notes': notes,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  factory AttendanceRecord.fromMap(Map<String, Object?> map) =>
      AttendanceRecord(
        id: map['id'] as String,
        workerId: map['workerId'] as String,
        shiftId: map['shiftId'] as String,
        workDate: DateTime.fromMillisecondsSinceEpoch(map['workDate'] as int),
        status: AttendanceStatusValue.fromValue(map['status'] as String?),
        checkIn: map['checkIn'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['checkIn'] as int),
        checkOut: map['checkOut'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['checkOut'] as int),
        regularHours: (map['regularHours'] as num?)?.toDouble() ?? 0,
        overtimeHours: (map['overtimeHours'] as num?)?.toDouble() ?? 0,
        overtimeRate: (map['overtimeRate'] as num?)?.toDouble() ?? 0,
        overtimeAmount: (map['overtimeAmount'] as num?)?.toDouble() ?? 0,
        lateMinutes: (map['lateMinutes'] as int?) ?? 0,
        earlyLeaveMinutes: (map['earlyLeaveMinutes'] as int?) ?? 0,
        notes: map['notes'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
      );
}

class LeaveRecord {
  LeaveRecord({
    required this.id,
    required this.workerId,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.days,
    this.reason,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String workerId;
  final LeaveType leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final int days;
  final String? reason;
  final LeaveStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'workerId': workerId,
    'leaveType': leaveType.value,
    'startDate': startDate.millisecondsSinceEpoch,
    'endDate': endDate.millisecondsSinceEpoch,
    'days': days,
    'reason': reason,
    'status': status.value,
    'notes': notes,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  factory LeaveRecord.fromMap(Map<String, Object?> map) => LeaveRecord(
    id: map['id'] as String,
    workerId: map['workerId'] as String,
    leaveType: LeaveTypeValue.fromValue(map['leaveType'] as String?),
    startDate: DateTime.fromMillisecondsSinceEpoch(map['startDate'] as int),
    endDate: DateTime.fromMillisecondsSinceEpoch(map['endDate'] as int),
    days: (map['days'] as int?) ?? 0,
    reason: map['reason'] as String?,
    status: LeaveStatusValue.fromValue(map['status'] as String?),
    notes: map['notes'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
  );
}

class LeaveBalance {
  LeaveBalance({
    required this.workerId,
    required this.annualLeaveAllowance,
    required this.usedLeave,
    required this.remaining,
  });

  final String workerId;
  final double annualLeaveAllowance;
  final double usedLeave;
  final double remaining;
}

class Deduction {
  Deduction({
    required this.id,
    required this.workerId,
    required this.date,
    required this.type,
    required this.amount,
    this.reason,
    this.notes,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  }) {
    if (amount < 0) throw ArgumentError('مبلغ الخصم لا يمكن أن يكون سالباً');
  }

  final String id;
  final String workerId;
  final DateTime date;
  final DeductionType type;
  final double amount;
  final String? reason;
  final String? notes;
  final DeductionStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'workerId': workerId,
    'date': date.millisecondsSinceEpoch,
    'type': type.value,
    'amount': amount,
    'reason': reason,
    'notes': notes,
    'status': status.value,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  factory Deduction.fromMap(Map<String, Object?> map) => Deduction(
    id: map['id'] as String,
    workerId: map['workerId'] as String,
    date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
    type: DeductionTypeValue.fromValue(map['type'] as String?),
    amount: (map['amount'] as num?)?.toDouble() ?? 0,
    reason: map['reason'] as String?,
    notes: map['notes'] as String?,
    status: DeductionStatusValue.fromValue(map['status'] as String?),
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
  );
}

class PayrollPeriod {
  PayrollPeriod({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final PayrollPeriodStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'startDate': startDate.millisecondsSinceEpoch,
    'endDate': endDate.millisecondsSinceEpoch,
    'status': status.value,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  factory PayrollPeriod.fromMap(Map<String, Object?> map) => PayrollPeriod(
    id: map['id'] as String,
    name: map['name'] as String,
    startDate: DateTime.fromMillisecondsSinceEpoch(map['startDate'] as int),
    endDate: DateTime.fromMillisecondsSinceEpoch(map['endDate'] as int),
    status: PayrollPeriodStatusValue.fromValue(map['status'] as String?),
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
  );
}

class PayrollRecord {
  PayrollRecord({
    required this.id,
    required this.payrollPeriodId,
    required this.workerId,
    required this.basicSalary,
    required this.regularEarnings,
    required this.overtimeHours,
    required this.overtimeAmount,
    required this.deductionsAmount,
    required this.grossSalary,
    required this.netSalary,
    this.notes,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String payrollPeriodId;
  final String workerId;
  final double basicSalary;
  final double regularEarnings;
  final double overtimeHours;
  final double overtimeAmount;
  final double deductionsAmount;
  final double grossSalary;
  final double netSalary;
  final String? notes;
  final PayrollRecordStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'payrollPeriodId': payrollPeriodId,
    'workerId': workerId,
    'basicSalary': basicSalary,
    'regularEarnings': regularEarnings,
    'overtimeHours': overtimeHours,
    'overtimeAmount': overtimeAmount,
    'deductionsAmount': deductionsAmount,
    'grossSalary': grossSalary,
    'netSalary': netSalary,
    'notes': notes,
    'status': status.value,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  factory PayrollRecord.fromMap(Map<String, Object?> map) => PayrollRecord(
    id: map['id'] as String,
    payrollPeriodId: map['payrollPeriodId'] as String,
    workerId: map['workerId'] as String,
    basicSalary: (map['basicSalary'] as num?)?.toDouble() ?? 0,
    regularEarnings: (map['regularEarnings'] as num?)?.toDouble() ?? 0,
    overtimeHours: (map['overtimeHours'] as num?)?.toDouble() ?? 0,
    overtimeAmount: (map['overtimeAmount'] as num?)?.toDouble() ?? 0,
    deductionsAmount: (map['deductionsAmount'] as num?)?.toDouble() ?? 0,
    grossSalary: (map['grossSalary'] as num?)?.toDouble() ?? 0,
    netSalary: (map['netSalary'] as num?)?.toDouble() ?? 0,
    notes: map['notes'] as String?,
    status: PayrollRecordStatusValue.fromValue(map['status'] as String?),
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
  );
}
