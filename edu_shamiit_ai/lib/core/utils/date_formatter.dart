import 'package:intl/intl.dart';  
  
class DateFormatter {  
  DateFormatter._();  
  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy');  
  static final DateFormat _timeFormat = DateFormat('hh:mm a');  
  static String formatDate(DateTime d) => _dateFormat.format(d);  
  static String formatTime(DateTime d) => _timeFormat.format(d);  
}  
