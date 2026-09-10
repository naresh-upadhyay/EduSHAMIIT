// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

void submitPayUHostedCheckout({
  required String checkoutUrl,
  required Map<String, dynamic> params,
}) {
  try {
    debugPrint('[PayU Web Checkout] Submitting POST form to: $checkoutUrl with ${params.length} fields');

    // Remove any existing temporary payu checkout forms
    final existingForms = html.document.querySelectorAll('#edushamiit_payu_checkout_form');
    for (var form in existingForms) {
      form.remove();
    }

    final form = html.FormElement()
      ..id = 'edushamiit_payu_checkout_form'
      ..method = 'POST'
      ..action = checkoutUrl
      ..style.display = 'none';

    params.forEach((key, value) {
      if (value != null) {
        final input = html.InputElement(type: 'hidden')
          ..name = key
          ..value = value.toString();
        form.append(input);
      }
    });

    html.document.body?.append(form);
    form.submit();
  } catch (e) {
    debugPrint('[PayU Web Checkout Error] Form submission failed: $e');
  }
}
