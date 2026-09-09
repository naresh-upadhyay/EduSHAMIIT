import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

void submitPayUHostedCheckout({
  required String checkoutUrl,
  required Map<String, dynamic> params,
}) async {
  try {
    final uri = Uri.parse(checkoutUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (e) {
    debugPrint('[PayU Mobile Checkout Error]: $e');
  }
}
