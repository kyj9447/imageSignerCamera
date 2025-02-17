// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:imagesignercamera/string_cryptor.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
   
    String testString = 'Hello, World!';
    String encryptedString = await stringCryptor(testString);

    // 암호화된 문자열이 비어있지 않은지 확인합니다.
    expect(encryptedString, isNotEmpty);

    // 암호화된 문자열이 원래 문자열과 다른지 확인합니다.
    expect(encryptedString, isNot(equals(testString)));
  });
}
