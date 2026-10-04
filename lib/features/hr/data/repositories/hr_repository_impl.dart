import 'package:furnexa/features/hr/data/datasources/hr_local_data_source.dart';
import 'package:furnexa/features/hr/domain/entities/hr_entities.dart';
import 'package:furnexa/features/hr/domain/repositories/hr_repository.dart';

class HrRepositoryImpl implements HrRepository {
  HrRepositoryImpl([HrLocalDataSource? dataSource])
    : _dataSource = dataSource ?? HrLocalDataSource();

  final HrLocalDataSource _dataSource;

  @override
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
  }) => _dataSource.createWorker(
    employeeCode: employeeCode,
    name: name,
    phone: phone,
    email: email,
    address: address,
    hireDate: hireDate,
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
  );

  @override
  Future<Worker> getWorker(String id) => _dataSource.getWorker(id);

  @override
  Future<List<Worker>> workers({String query = ''}) =>
      _dataSource.workers(query: query);

  @override
  Future<void> deactivateWorker(String id) => _dataSource.deactivateWorker(id);

  @override
  Future<void> assignWorker({
    required String workerId,
    String? sectionId,
    String? workshopId,
    String? productionStageId,
  }) => _dataSource.assignWorker(
    workerId: workerId,
    sectionId: sectionId,
    workshopId: workshopId,
    productionStageId: productionStageId,
  );

  @override
  Future<Shift> createShift({
    required String name,
    required String startTime,
    required String endTime,
    int graceMinutes = 0,
    bool overtimeEnabled = false,
    int overtimeStartAfterMinutes = 0,
    double overtimeRate = 0,
    bool active = true,
  }) => _dataSource.createShift(
    name: name,
    startTime: startTime,
    endTime: endTime,
    graceMinutes: graceMinutes,
    overtimeEnabled: overtimeEnabled,
    overtimeStartAfterMinutes: overtimeStartAfterMinutes,
    overtimeRate: overtimeRate,
    active: active,
  );

  @override
  Future<List<Shift>> shifts() => _dataSource.shifts();

  @override
  Future<AttendanceRecord> saveAttendance({
    required String workerId,
    required String shiftId,
    required DateTime workDate,
    DateTime? checkIn,
    DateTime? checkOut,
    required AttendanceStatus status,
    String? notes,
  }) => _dataSource.saveAttendance(
    workerId: workerId,
    shiftId: shiftId,
    workDate: workDate,
    checkIn: checkIn,
    checkOut: checkOut,
    status: status,
    notes: notes,
  );

  @override
  Future<AttendanceRecord?> getAttendance(String workerId, DateTime workDate) =>
      _dataSource.getAttendance(workerId, workDate);

  @override
  Future<List<AttendanceRecord>> attendanceHistory(String workerId) =>
      _dataSource.attendanceHistory(workerId);

  @override
  Future<Map<String, int>> attendanceOverview({
    String? sectionId,
    String? workshopId,
    String? shiftId,
    AttendanceStatus? status,
  }) => _dataSource.attendanceOverview(
    sectionId: sectionId,
    workshopId: workshopId,
    shiftId: shiftId,
    status: status,
  );

  @override
  Future<LeaveRecord> createLeave({
    required String workerId,
    required LeaveType leaveType,
    required DateTime startDate,
    required DateTime endDate,
    String? reason,
    required LeaveStatus status,
    String? notes,
  }) => _dataSource.createLeave(
    workerId: workerId,
    leaveType: leaveType,
    startDate: startDate,
    endDate: endDate,
    reason: reason,
    status: status,
    notes: notes,
  );

  @override
  Future<List<LeaveRecord>> leaveHistory(String workerId) =>
      _dataSource.leaveHistory(workerId);

  @override
  Future<LeaveBalance> getEmployeeLeaveBalance(String workerId) =>
      _dataSource.getEmployeeLeaveBalance(workerId);

  @override
  Future<Deduction> createDeduction({
    required String workerId,
    required DateTime date,
    required DeductionType type,
    required double amount,
    String? reason,
    String? notes,
    required DeductionStatus status,
  }) => _dataSource.createDeduction(
    workerId: workerId,
    date: date,
    type: type,
    amount: amount,
    reason: reason,
    notes: notes,
    status: status,
  );

  @override
  Future<List<Deduction>> deductionsForWorker(String workerId) =>
      _dataSource.deductionsForWorker(workerId);

  @override
  Future<PayrollPeriod> createPayrollPeriod({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
  }) => _dataSource.createPayrollPeriod(
    name: name,
    startDate: startDate,
    endDate: endDate,
  );

  @override
  Future<List<PayrollPeriod>> payrollPeriods() => _dataSource.payrollPeriods();

  @override
  Future<PayrollRecord> calculatePayroll({
    required String payrollPeriodId,
    required String workerId,
  }) => _dataSource.calculatePayroll(
    payrollPeriodId: payrollPeriodId,
    workerId: workerId,
  );

  @override
  Future<PayrollRecord?> getPayroll(String workerId, String payrollPeriodId) =>
      _dataSource.getPayroll(workerId, payrollPeriodId);

  @override
  Future<List<PayrollRecord>> payrollHistory(String workerId) =>
      _dataSource.payrollHistory(workerId);

  @override
  Future<PayrollRecord> approvePayroll(String payrollRecordId) =>
      _dataSource.approvePayroll(payrollRecordId);

  @override
  Future<PayrollRecord> payPayroll({
    required String payrollRecordId,
    String? cashboxId,
    String? bankAccountId,
  }) => _dataSource.payPayroll(
    payrollRecordId: payrollRecordId,
    cashboxId: cashboxId,
    bankAccountId: bankAccountId,
  );
}
