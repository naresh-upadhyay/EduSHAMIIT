import 'package:flutter/material.dart';
import 'bulk_and_scheduled_invoice_dialog.dart';

class BulkStudentInvoiceDialog extends StatelessWidget {
  const BulkStudentInvoiceDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return const BulkAndScheduledInvoiceDialog(initialTab: 0);
  }
}
