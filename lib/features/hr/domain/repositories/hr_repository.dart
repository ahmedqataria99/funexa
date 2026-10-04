import 'package:furnexa/features/hr/domain/entities/hr_entities.dart';

abstract class HrRepository {
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
  });

  Future<Worker> getWorker(String id);
  Future<List<Worker>> workers({String query = ''});
  Future<void> deactivateWorker(String id);
  Future<void> assignWorker({
    required String workerId,
    String? sectionId,
    String? workshopId,
    String? productionStageId,
  });

  Future<Shift> createShift({
    required String name,
    required String startTime,
    required String endTime,
    int graceMinutes = 0,
    bool overtimeEnabled = false,
    int overtimeStartAfterMinutes = 0,
    double overtimeRate = 0,
    bool active = true,
  });
  Future<List<Shift>> shifts();

  Future<AttendanceRecord> saveAttendance({
    required String workerId,
    required String shiftId,
    required DateTime workDate,
    DateTime? checkIn,
    DateTime? checkOut,
    required AttendanceStatus status,
    String? notes,
  });
  Future<AttendanceRecord?> getAttendance(String workerId, DateTime workDate);
  Future<List<AttendanceRecord>> attendanceHistory(String workerId);
  Future<Map<String, int>> attendanceOverview({
    String? sectionId,
    String? workshopId,
    String? shiftId,
    AttendanceStatus? status,
  });

  Future<LeaveRecord> createLeave({
    required String workerId,
    required LeaveType leaveType,
    required DateTime startDate,
    required DateTime endDate,
    String? reason,
    required LeaveStatus status,
    String? notes,
  });
  Future<List<LeaveRecord>> leaveHistory(String workerId);
  Future<LeaveBalance> getEmployeeLeaveBalance(String workerId);

  Future<Deduction> createDeduction({
    required String workerId,
    required DateTime date,
    required DeductionType type,
    required double amount,
    String? reason,
    String? notes,
    required DeductionStatus status,
  });
  Future<List<Deduction>> deductionsForWorker(String workerId);

  Future<PayrollPeriod> createPayrollPeriod({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
  });
  Future<List<PayrollPeriod>> payrollPeriods();
  Future<PayrollRecord> calculatePayroll({
    required String payrollPeriodId,
    required String workerId,
  });
  Future<PayrollRecord?> getPayroll(String workerId, String payrollPeriodId);
  Future<List<PayrollRecord>> payrollHistory(String workerId);
  Future<PayrollRecord> approvePayroll(String payrollRecordId);
  Future<PayrollRecord> payPayroll({
    required String payrollRecordId,
    String? cashboxId,
    String? bankAccountId,
  });
}
