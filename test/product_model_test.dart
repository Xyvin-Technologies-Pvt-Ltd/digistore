import 'package:flutter_test/flutter_test.dart';
import 'package:setgo/src/data/models/product_model.dart';

void main() {
  group('Notion Section 4 Formatting Helpers', () {
    test('getPriceRangeText formats single price correctly', () {
      expect(getPriceRangeText(500, null), '₹500');
      expect(getPriceRangeText(500, 500), '₹500');
      expect(getPriceRangeText(500, 300), '₹500');
    });

    test('getPriceRangeText formats price range correctly', () {
      expect(getPriceRangeText(500, 1000), '₹500 - ₹1000');
    });

    test('getOfferRangeText returns null if no offer or null offerPrice', () {
      expect(getOfferRangeText(false, 400, 700), isNull);
      expect(getOfferRangeText(true, null, 700), isNull);
    });

    test('getOfferRangeText formats single offer price', () {
      expect(getOfferRangeText(true, 400, null), '₹400');
      expect(getOfferRangeText(true, 400, 400), '₹400');
    });

    test('getOfferRangeText formats offer price range', () {
      expect(getOfferRangeText(true, 400, 700), '₹400 - ₹700');
    });

    test('getDiscountBadge formats percentage single and range', () {
      expect(
        getDiscountBadge({
          'hasOffer': true,
          'offerType': 'percentage',
          'offerValue': 20,
        }),
        '20% OFF',
      );

      expect(
        getDiscountBadge({
          'hasOffer': true,
          'offerType': 'percentage',
          'offerValue': 10,
          'maxOfferValue': 20,
        }),
        '10% -20% OFF',
      );
    });

    test('getDiscountBadge formats flat amount', () {
      expect(
        getDiscountBadge({
          'hasOffer': true,
          'offerType': 'amount',
          'offerValue': 100,
        }),
        'Flat ₹100 OFF',
      );
    });

    test('getDiscountBadge returns null when hasOffer is false', () {
      expect(
        getDiscountBadge({
          'hasOffer': false,
          'offerType': 'percentage',
          'offerValue': 20,
        }),
        isNull,
      );
    });
  });

  group('ProductModel JSON Parsing & Backward Compatibility', () {
    test('Parses Section 2.1 response JSON with ranges and displays correctly', () {
      final json = {
        '_id': '673b88921234567890abcdef',
        'partnerId': {
          '_id': '69b5234432646e83fe80e2f6',
          'businessDetails': {
            'businessName': 'City Girls Beauty Parlour',
            'address': 'Link road, Vaikom, Kerala 686141',
          },
          'businessInfo': {
            'businessLogo': 'https://example.com/logo.jpg',
          },
        },
        'title': 'Hair Spa Treatment Kit',
        'description': 'Deep nourishing hair spa cream and serum set.',
        'images': [
          'https://example.com/image1.jpg',
          'https://example.com/image2.jpg',
        ],
        'price': 500,
        'maxPrice': 1000,
        'hasOffer': true,
        'offerType': 'percentage',
        'offerValue': 20,
        'maxOfferValue': 30,
        'offerPrice': 400,
        'maxOfferPrice': 700,
        'priceDisplay': '₹500 - ₹1,000',
        'offerPriceDisplay': '₹400 - ₹700',
        'effectivePrice': 400,
        'effectiveMaxPrice': 700,
        'inStock': true,
        'brand': "L'Oreal",
        'unit': 'kit',
        'weight': '500g',
        'hasVariants': false,
        'variants': [],
        'isFavorite': false,
      };

      final product = ProductModel.fromJson(json);

      expect(product.id, '673b88921234567890abcdef');
      expect(product.price, 500);
      expect(product.maxPrice, 1000);
      expect(product.hasOffer, true);
      expect(product.offerType, 'percentage');
      expect(product.offerValue, 20);
      expect(product.maxOfferValue, 30);
      expect(product.offerPrice, 400);
      expect(product.maxOfferPrice, 700);
      expect(product.priceDisplay, '₹500 - ₹1,000');
      expect(product.offerPriceDisplay, '₹400 - ₹700');
      expect(product.hasPriceRange, true);
      expect(product.hasOfferRange, true);
      expect(product.priceRangeText, '₹500 - ₹1,000');
      expect(product.offerRangeText, '₹400 - ₹700');
      expect(product.discountBadge, '20% -30% OFF');
      expect(product.displayPriceText, '₹400 - ₹700');
      expect(product.showStrikeThrough, true);

      // Verify toJson retains all fields
      final serialized = product.toJson();
      expect(serialized['price'], 500);
      expect(serialized['maxPrice'], 1000);
      expect(serialized['maxOfferPrice'], 700);
      expect(serialized['priceDisplay'], '₹500 - ₹1,000');
      expect(serialized['offerPriceDisplay'], '₹400 - ₹700');
    });

    test('Backward Compatibility: single fixed-price product without maxPrice works cleanly', () {
      final json = {
        '_id': 'old_product_1',
        'title': 'Classic Shampoo',
        'price': 250,
        'hasOffer': false,
      };

      final product = ProductModel.fromJson(json);

      expect(product.price, 250);
      expect(product.maxPrice, isNull);
      expect(product.hasPriceRange, false);
      expect(product.hasOfferRange, false);
      expect(product.priceRangeText, '₹250');
      expect(product.offerRangeText, isNull);
      expect(product.discountBadge, isNull);
      expect(product.displayPriceText, '₹250');
      expect(product.showStrikeThrough, false);
    });

    test('Fallback calculation when priceDisplay or offerPriceDisplay not provided by backend', () {
      final json = {
        '_id': 'calc_product',
        'title': 'Calculated Kit',
        'price': 300,
        'maxPrice': 600,
        'hasOffer': true,
        'offerType': 'amount',
        'offerValue': 50,
        'offerPrice': 250,
        'maxOfferPrice': 550,
      };

      final product = ProductModel.fromJson(json);

      expect(product.priceRangeText, '₹300 - ₹600');
      expect(product.offerRangeText, '₹250 - ₹550');
      expect(product.discountBadge, 'Flat ₹50 OFF');
      expect(product.displayPriceText, '₹250 - ₹550');
    });
  });
}
