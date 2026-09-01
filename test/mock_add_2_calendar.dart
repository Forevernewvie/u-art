import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void setupMockAdd2Calendar() {
  const channel = MethodChannel('add_2_calendar');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (MethodCall methodCall) async {
    if (methodCall.method == 'add2Cal') {
      return false; // Return false to trigger the failure branch
    }
    return null;
  });
}
