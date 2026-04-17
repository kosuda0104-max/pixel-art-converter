import 'package:flutter_test/flutter_test.dart';

import 'package:pixel_art_converter/main.dart';

void main() {
  testWidgets('app renders converter controls', (WidgetTester tester) async {
    await tester.pumpWidget(const PixelArtConverterApp());

    expect(find.text('ドット絵変換アプリ'), findsOneWidget);
    expect(find.text('画像を選択'), findsOneWidget);
    expect(find.text('変換する'), findsOneWidget);
    expect(find.text('保存する'), findsOneWidget);
    expect(find.text('ここに画像プレビュー'), findsOneWidget);
  });
}
