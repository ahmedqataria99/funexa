import 'package:intl/intl.dart';

class DateTimeUtils {
  const DateTimeUtils._();

  static String formatDate(DateTime date, {String pattern = 'dd/MM/yyyy'}) {
    return DateFormat(pattern).format(date);
  }

  static String formatDateTime(DateTime date, {String pattern = 'dd/MM/yyyy HH:mm'}) {
    return DateFormat(pattern).format(date);
  }

  static DateTime? parseDate(String value, {String pattern = 'dd/MM/yyyy'}) {
    try {
      return DateFormat(pattern).parseStrict(value);
    } on FormatException {
      return null;
    }
  }
}
