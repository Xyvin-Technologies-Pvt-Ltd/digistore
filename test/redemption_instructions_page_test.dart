import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setgo/src/data/providers/screen_size_provider.dart';
import 'package:setgo/src/interfaces/main_pages/offer_pages/redemption_instructions_page.dart';

void main() {
  testWidgets('RedemptionInstructionsPage renders cleanly without Stack Overflow', (tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(1080, 2400);
    tester.binding.window.devicePixelRatioTestValue = 2.0;
    addTearDown(() {
      tester.binding.window.clearPhysicalSizeTestValue();
      tester.binding.window.clearDevicePixelRatioTestValue();
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ScreenSizeScope(
            child: RedemptionInstructionsPage(
              args: {
                'id': 'offer_999',
                'title': 'Test 50% Off Deal',
                'pointsCost': 200,
                'pointsToUse': 100,
                'paymentMode': 'partial',
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(RedemptionInstructionsPage), findsOneWidget);
    expect(find.text('Redemption Payment Mode'), findsOneWidget);
    expect(find.text('Full Points'), findsOneWidget);
    expect(find.text('Full Cash'), findsOneWidget);
  });

  testWidgets('RedemptionInstructionsPage renders with null args without Stack Overflow', (tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(1080, 2400);
    tester.binding.window.devicePixelRatioTestValue = 2.0;
    addTearDown(() {
      tester.binding.window.clearPhysicalSizeTestValue();
      tester.binding.window.clearDevicePixelRatioTestValue();
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ScreenSizeScope(
            child: RedemptionInstructionsPage(args: null),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(RedemptionInstructionsPage), findsOneWidget);
  });
}
