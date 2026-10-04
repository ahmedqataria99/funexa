import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';

class DatabaseTestHelper {
  static const adminPassword = 'Furnexa-Test-Admin-2026!';

  static Future<void> reset({bool createInitialAdmin = true}) async {
    await FurnexaDatabase.instance.close();
    await FurnexaDatabase.instance.resetForTesting();
    if (createInitialAdmin) {
      await SecurityLocalDataSource().setupInitialAdmin(
        username: 'admin',
        displayName: 'System Admin',
        password: adminPassword,
      );
    }
  }
}
