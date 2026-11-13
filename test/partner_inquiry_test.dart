import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setgo/src/data/models/app_notification_model.dart';
import 'package:setgo/src/data/models/partner_inquiry_model.dart';
import 'package:setgo/src/data/services/deep_link_service.dart';

void main() {
  group('PartnerInquiryModel', () {
    test('parses multi-item inquiry payload from API', () {
      final json = {
        '_id': '6724abc',
        'customer': {
          'name': 'Anirudh K Manoj',
          'phone': '8606154706',
          'avatar': null,
        },
        'items': [
          {
            'title': 'CCTV Installation',
            'quantity': 1,
            'effectivePrice': 349,
            'price': 699,
            'image': 'https://example.com/cctv.png',
          },
          {
            'title': 'Networking Setup',
            'quantity': 2,
            'effectivePrice': 500,
            'price': 500,
          },
        ],
        'totalQuantity': 3,
        'subtotal': 1349,
        'inquiryStatus': 'pending',
        'lastInquirySentAt': '2026-11-05T04:20:00.000Z',
      };

      final inquiry = PartnerInquiryModel.fromJson(json);
      expect(inquiry.id, '6724abc');
      expect(inquiry.customer.name, 'Anirudh K Manoj');
      expect(inquiry.customer.phone, '8606154706');
      expect(inquiry.items.length, 2);
      expect(inquiry.items.first.title, 'CCTV Installation');
      expect(inquiry.items.first.effectivePrice, 349);
      expect(inquiry.items.first.price, 699);
      expect(inquiry.items[1].quantity, 2);
      expect(inquiry.totalQuantity, 3);
      expect(inquiry.subtotal, 1349);
      expect(inquiry.inquiryStatus, 'pending');
      expect(inquiry.lastInquirySentAt, isNotNull);
      expect(inquiry.itemCount, 2);
    });

    test('computes totals when API omits totalQuantity/subtotal', () {
      final inquiry = PartnerInquiryModel.fromJson({
        '_id': 'x1',
        'items': [
          {'title': 'A', 'quantity': 2, 'effectivePrice': 100},
          {'title': 'B', 'quantity': 1, 'price': 50},
        ],
      });
      expect(inquiry.totalQuantity, 3);
      expect(inquiry.subtotal, 250);
    });

    test('handles missing customer and empty items safely', () {
      final inquiry = PartnerInquiryModel.fromJson({'_id': 'empty'});
      expect(inquiry.id, 'empty');
      expect(inquiry.items, isEmpty);
      expect(inquiry.customer.name, isNull);
      expect(inquiry.inquiryStatus, 'pending');
    });
  });

  group('AppNotificationModel inquiry action parsing', () {
    test('parses nested open_product_inquiry action with targetId', () {
      final model = AppNotificationModel.fromJson({
        '_id': 'n1',
        'title': 'New inquiry',
        'message': 'Customer inquired',
        'action': {
          'type': 'open_product_inquiry',
          'targetId': 'inq_123',
        },
      });
      expect(model.action?.type, 'open_product_inquiry');
      expect(model.action?.targetId, 'inq_123');
      expect(model.action?.isNavigable, isTrue);
    });

    test('uses metadata.cartId when flattened action has no targetId', () {
      final model = AppNotificationModel.fromJson({
        'title': 'Inquiry',
        'body': 'New products inquired',
        'actionType': 'open_product_inquiry',
        'metadata': {'cartId': 'cart_456'},
      });
      expect(model.action?.type, 'open_product_inquiry');
      expect(model.action?.targetId, 'cart_456');
    });

    test('prefers actionTargetId over cartId for flattened FCM payload', () {
      final model = AppNotificationModel.fromJson({
        'actionType': 'open_product_inquiry',
        'actionTargetId': 'inq_789',
        'cartId': 'cart_should_not_win',
        'metadata': {'cartId': 'cart_meta'},
      });
      expect(model.action?.targetId, 'inq_789');
    });

    test('fills targetId from metadata.cartId when nested action omits it', () {
      final model = AppNotificationModel.fromJson({
        '_id': 'notif_only',
        'title': 'Inquiry',
        'message': 'New inquiry',
        'action': {'type': 'open_product_inquiry'},
        'metadata': {'cartId': 'cart_from_meta'},
      });
      expect(model.action?.type, 'open_product_inquiry');
      expect(model.action?.targetId, 'cart_from_meta');
    });
  });

  group('DeepLinkService inquiry deep links', () {
    test('generateDeepLink builds partner inquiry URL', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final service = container.read(deepLinkServiceProvider);
      expect(
        service.generateDeepLink('partnerinquirydetail', id: 'inq_99'),
        'https://setgo.in/app/partnerinquirydetail/inq_99',
      );
      expect(
        service.generateDeepLink('partner-inquiry-detail', id: 'cart_1'),
        'https://setgo.in/app/partnerinquirydetail/cart_1',
      );
    });
  });
}
