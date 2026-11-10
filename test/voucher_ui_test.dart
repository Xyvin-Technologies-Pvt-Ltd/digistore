import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setgo/src/data/models/voucher_models.dart';
import 'package:setgo/src/data/providers/screen_size_provider.dart';
import 'package:setgo/src/data/providers/voucher_provider.dart';
import 'package:setgo/src/interfaces/main_pages/home_pages/my_vouchers_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('My Vouchers shows active voucher card', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myVouchersProvider('active').overrideWith(
            (ref) async => [
              const VoucherModel(
                id: 'v1',
                voucherCode: 'WELCOME-7A2F8B',
                title: 'New User Referral Welcome Voucher',
                rewardType: 'flat_voucher',
                value: 50,
                minOrderValue: 200,
                status: 'active',
                daysLeft: 14,
              ),
            ],
          ),
          myVouchersProvider('redeemed').overrideWith((ref) async => const []),
          myVouchersProvider('expired').overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(
          home: ScreenSizeScope(child: MyVouchersPage()),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('My Vouchers'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('WELCOME-7A2F8B'), findsOneWidget);
    expect(find.text('New User Referral Welcome Voucher'), findsOneWidget);
    expect(find.textContaining('₹50'), findsWidgets);
  });

  testWidgets('My Vouchers empty state for active tab', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myVouchersProvider('active').overrideWith((ref) async => const []),
          myVouchersProvider('redeemed').overrideWith((ref) async => const []),
          myVouchersProvider('expired').overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(
          home: ScreenSizeScope(child: MyVouchersPage()),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('No active vouchers'), findsOneWidget);
  });
}
