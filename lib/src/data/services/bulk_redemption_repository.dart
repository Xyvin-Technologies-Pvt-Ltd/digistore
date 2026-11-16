import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/bulk_redemption_models.dart';
import '../providers/api_provider.dart';

class BulkRedemptionRepository {
  final ApiProvider _api;

  BulkRedemptionRepository(this._api);

  /// GET /shops/:shopId/redeemable-offers
  Future<ShopOffersBundle> shopOffers(String shopId) async {
    final response = await _api.get(
      '/shops/$shopId/redeemable-offers',
      requireAuth: true,
    );
    final body = response.data;
    if (!response.success || body == null) {
      return const ShopOffersBundle();
    }
    final data = _asMap(body['data']) ?? body;
    return ShopOffersBundle.fromJson(data);
  }

  /// Alias matching Notion naming.
  Future<ShopOffersBundle> getRedeemableOffers(String shopId) =>
      shopOffers(shopId);

  /// PUT /cart/offers — attach / update / clear selected offers on shop cart.
  Future<CartOffersUpdateResult> updateCartOffers({
    required String partnerId,
    String? cartId,
    List<String>? offerIds,
    bool redeemAll = false,
  }) async {
    final payload = <String, dynamic>{
      'partnerId': partnerId,
      if (cartId != null && cartId.isNotEmpty) 'cartId': cartId,
      if (offerIds != null) 'offerIds': offerIds,
      'redeemAll': redeemAll,
    };
    final response = await _api.put('/cart/offers', payload, requireAuth: true);
    final body = response.data;
    if (!response.success || body == null) {
      throw _apiException(response, 'Could not update cart offers');
    }
    final data = _asMap(body['data']) ?? body;
    return CartOffersUpdateResult.fromJson(
      data,
      message: body['message']?.toString(),
    );
  }

  /// POST /cart/send-inquiry — optional offerIds / redeemAll preserved if omitted.
  Future<Map<String, dynamic>> sendCartInquiry({
    String? cartId,
    String? partnerId,
    List<String>? offerIds,
    bool? redeemAll,
    Map<String, dynamic>? extra,
  }) async {
    final payload = <String, dynamic>{
      if (cartId != null && cartId.isNotEmpty) 'cartId': cartId,
      if (partnerId != null && partnerId.isNotEmpty) 'partnerId': partnerId,
      if (offerIds != null) 'offerIds': offerIds,
      if (redeemAll != null) 'redeemAll': redeemAll,
      if (extra != null) ...extra,
    };
    final response = await _api.post(
      '/cart/send-inquiry',
      payload,
      requireAuth: true,
    );
    final body = response.data;
    if (!response.success || body == null) {
      throw _apiException(response, 'Could not send cart inquiry');
    }
    return _asMap(body['data']) ?? body;
  }

  /// POST /offers/bulk/redeem
  Future<BulkRedeemInitResult> initiateBulkRedeem({
    String? partnerId,
    String? cartId,
    List<String>? offerIds,
    List<BulkOfferSaleAmount>? offers,
    bool redeemAll = false,
    double? saleAmount,
    String? voucherCode,
  }) async {
    final payload = _buildSelectionPayload(
      partnerId: partnerId,
      cartId: cartId,
      offerIds: offerIds,
      offers: offers,
      redeemAll: redeemAll,
      saleAmount: saleAmount,
      voucherCode: voucherCode,
    );
    final response = await _api.post(
      '/offers/bulk/redeem',
      payload,
      requireAuth: true,
    );
    return _parseInit(response, 'Could not start bulk redemption');
  }

  /// Customer: POST /offers/redemptions/bulk/:batchId/verify
  Future<BulkVerifyResult> customerVerifyBulk({
    required String batchId,
    required String otp,
    String? userPhone,
    double? saleAmount,
    List<BulkOfferSaleAmount>? offers,
    int? pointsToUse,
    String? voucherCode,
    String? billNo,
  }) async {
    final payload = <String, dynamic>{
      'otp': otp,
      if (userPhone != null && userPhone.isNotEmpty) 'userPhone': userPhone,
      'batchId': batchId,
      if (saleAmount != null) 'saleAmount': saleAmount,
      if (offers != null) 'offers': offers.map((e) => e.toJson()).toList(),
      if (pointsToUse != null) 'pointsToUse': pointsToUse,
      if (voucherCode != null && voucherCode.trim().isNotEmpty)
        'voucherCode': voucherCode.trim(),
      if (billNo != null && billNo.trim().isNotEmpty) 'billNo': billNo.trim(),
    };
    final response = await _api.post(
      '/offers/redemptions/bulk/$batchId/verify',
      payload,
      requireAuth: true,
    );
    return _parseVerify(response, 'Bulk verification failed');
  }

  /// Customer: POST /offers/bulk/redeem-qr
  Future<BulkRedeemInitResult> initiateBulkQr({
    String? partnerId,
    String? cartId,
    List<String>? offerIds,
    List<BulkOfferSaleAmount>? offers,
    bool redeemAll = false,
    double? saleAmount,
    String? voucherCode,
  }) async {
    final payload = _buildSelectionPayload(
      partnerId: partnerId,
      cartId: cartId,
      offerIds: offerIds,
      offers: offers,
      redeemAll: redeemAll,
      saleAmount: saleAmount,
      voucherCode: voucherCode,
    );
    final response = await _api.post(
      '/offers/bulk/redeem-qr',
      payload,
      requireAuth: true,
    );
    return _parseInit(response, 'Could not create bulk QR');
  }

  /// Partner: POST /offers/redemptions/bulk/:batchId/scan-qr
  Future<BulkVerifyResult> partnerScanBulkQr({
    required String batchId,
    String? qrToken,
    double? saleAmount,
    List<BulkOfferSaleAmount>? offers,
    int? pointsToUse,
    String? voucherCode,
    String? billNo,
  }) async {
    final payload = <String, dynamic>{
      if (qrToken != null && qrToken.isNotEmpty) 'qrToken': qrToken,
      if (saleAmount != null) 'saleAmount': saleAmount,
      if (offers != null) 'offers': offers.map((e) => e.toJson()).toList(),
      if (pointsToUse != null) 'pointsToUse': pointsToUse,
      if (voucherCode != null && voucherCode.trim().isNotEmpty)
        'voucherCode': voucherCode.trim(),
      if (billNo != null && billNo.trim().isNotEmpty) 'billNo': billNo.trim(),
    };
    final response = await _api.post(
      '/offers/redemptions/bulk/$batchId/scan-qr',
      payload,
      requireAuth: true,
    );
    return _parseVerify(response, 'Bulk QR scan failed');
  }

  /// Customer: POST /offers/bulk/redeem-with-bill
  /// multipart (bill file) or JSON when bill image is optional.
  Future<BulkVerifyResult> redeemWithBill({
    required String partnerId,
    String? cartId,
    List<String>? offerIds,
    List<BulkOfferSaleAmount>? offers,
    bool redeemAll = false,
    double? saleAmount,
    int? pointsToUse,
    String? billNo,
    String? voucherCode,
    String? billFilePath,
    String billFieldName = 'bill',
  }) async {
    if (billFilePath != null && billFilePath.isNotEmpty) {
      final fields = <String, String>{
        'partnerId': partnerId,
        if (cartId != null && cartId.isNotEmpty) 'cartId': cartId,
        if (offerIds != null) 'offerIds': jsonEncode(offerIds),
        if (offers != null)
          'offers': jsonEncode(offers.map((e) => e.toJson()).toList()),
        'redeemAll': redeemAll.toString(),
        if (saleAmount != null) 'saleAmount': saleAmount.toString(),
        if (pointsToUse != null) 'pointsToUse': pointsToUse.toString(),
        if (billNo != null && billNo.trim().isNotEmpty) 'billNo': billNo.trim(),
        if (voucherCode != null && voucherCode.trim().isNotEmpty)
          'voucherCode': voucherCode.trim(),
      };
      final file = await http.MultipartFile.fromPath(
        billFieldName,
        billFilePath,
      );
      final response = await _api.postMultipart(
        '/offers/bulk/redeem-with-bill',
        fields,
        files: [file],
        requireAuth: true,
      );
      return _parseVerify(response, 'Bill redemption failed');
    }

    final payload = _buildSelectionPayload(
      partnerId: partnerId,
      cartId: cartId,
      offerIds: offerIds,
      offers: offers,
      redeemAll: redeemAll,
      saleAmount: saleAmount,
      voucherCode: voucherCode,
    );
    if (pointsToUse != null) payload['pointsToUse'] = pointsToUse;
    if (billNo != null && billNo.trim().isNotEmpty) {
      payload['billNo'] = billNo.trim();
    }
    final response = await _api.post(
      '/offers/bulk/redeem-with-bill',
      payload,
      requireAuth: true,
    );
    return _parseVerify(response, 'Bill redemption failed');
  }

  /// Partner: POST /partner/offers/bulk/generate-otp
  Future<BulkRedeemInitResult> partnerGenerateBulkOtp({
    required String userPhone,
    String? cartId,
    List<String>? offerIds,
    List<BulkOfferSaleAmount>? offers,
    bool redeemAll = false,
    double? saleAmount,
    String? voucherCode,
  }) async {
    final payload = <String, dynamic>{
      'userPhone': userPhone,
      if (cartId != null && cartId.isNotEmpty) 'cartId': cartId,
      if (offerIds != null) 'offerIds': offerIds,
      if (offers != null) 'offers': offers.map((e) => e.toJson()).toList(),
      'redeemAll': redeemAll,
      if (saleAmount != null) 'saleAmount': saleAmount,
      if (voucherCode != null && voucherCode.trim().isNotEmpty)
        'voucherCode': voucherCode.trim(),
    };
    final response = await _api.post(
      '/partner/offers/bulk/generate-otp',
      payload,
      requireAuth: true,
    );
    return _parseInit(response, 'Could not generate bulk OTP');
  }

  /// Partner: POST /partner/offers/bulk/verify-otp
  Future<BulkVerifyResult> partnerVerifyBulk({
    required String userPhone,
    required String otp,
    String? batchId,
    double? saleAmount,
    List<BulkOfferSaleAmount>? offers,
    int? pointsToUse,
    String? voucherCode,
    String? billNo,
    String? billImagePath,
  }) async {
    if (billImagePath != null && billImagePath.isNotEmpty) {
      final fields = <String, String>{
        'userPhone': userPhone,
        'otp': otp,
        if (batchId != null && batchId.isNotEmpty) 'batchId': batchId,
        if (saleAmount != null) 'saleAmount': saleAmount.toString(),
        if (offers != null)
          'offers': jsonEncode(offers.map((e) => e.toJson()).toList()),
        if (pointsToUse != null) 'pointsToUse': pointsToUse.toString(),
        if (voucherCode != null && voucherCode.trim().isNotEmpty)
          'voucherCode': voucherCode.trim(),
        if (billNo != null && billNo.trim().isNotEmpty) 'billNo': billNo.trim(),
      };
      final file = await http.MultipartFile.fromPath(
        'billImage',
        billImagePath,
      );
      final response = await _api.postMultipart(
        '/partner/offers/bulk/verify-otp',
        fields,
        files: [file],
        requireAuth: true,
      );
      return _parseVerify(response, 'Bulk verification failed');
    }

    final payload = <String, dynamic>{
      'userPhone': userPhone,
      'otp': otp,
      if (batchId != null && batchId.isNotEmpty) 'batchId': batchId,
      if (saleAmount != null) 'saleAmount': saleAmount,
      if (offers != null) 'offers': offers.map((e) => e.toJson()).toList(),
      if (pointsToUse != null) 'pointsToUse': pointsToUse,
      if (voucherCode != null && voucherCode.trim().isNotEmpty)
        'voucherCode': voucherCode.trim(),
      if (billNo != null && billNo.trim().isNotEmpty) 'billNo': billNo.trim(),
    };
    final response = await _api.post(
      '/partner/offers/bulk/verify-otp',
      payload,
      requireAuth: true,
    );
    return _parseVerify(response, 'Bulk verification failed');
  }

  Map<String, dynamic> _buildSelectionPayload({
    String? partnerId,
    String? cartId,
    List<String>? offerIds,
    List<BulkOfferSaleAmount>? offers,
    bool redeemAll = false,
    double? saleAmount,
    String? voucherCode,
  }) {
    return <String, dynamic>{
      if (partnerId != null && partnerId.isNotEmpty) 'partnerId': partnerId,
      if (cartId != null && cartId.isNotEmpty) 'cartId': cartId,
      if (offerIds != null) 'offerIds': offerIds,
      if (offers != null) 'offers': offers.map((e) => e.toJson()).toList(),
      'redeemAll': redeemAll,
      if (saleAmount != null) 'saleAmount': saleAmount,
      if (voucherCode != null && voucherCode.trim().isNotEmpty)
        'voucherCode': voucherCode.trim(),
    };
  }

  BulkRedeemInitResult _parseInit(
    ApiResponse<Map<String, dynamic>> response,
    String fallback,
  ) {
    final body = response.data;
    if (!response.success || body == null) {
      throw _apiException(response, fallback);
    }
    if (body['success'] == false) {
      throw Exception(
        bulkRedemptionErrorMessage(
          errorCode: extractBulkErrorCode(body),
          fallback: body['message']?.toString() ?? fallback,
        ),
      );
    }
    final data = _asMap(body['data']) ?? body;
    final result = BulkRedeemInitResult.fromJson(data);
    if (result.batchId.isEmpty) {
      throw Exception(body['message']?.toString() ?? 'Missing batch id');
    }
    return result;
  }

  BulkVerifyResult _parseVerify(
    ApiResponse<Map<String, dynamic>> response,
    String fallbackMessage,
  ) {
    final body = response.data;
    if (!response.success || body == null) {
      throw _apiException(response, fallbackMessage);
    }
    if (body['success'] == false) {
      throw Exception(
        bulkRedemptionErrorMessage(
          errorCode: extractBulkErrorCode(body),
          fallback: body['message']?.toString() ?? fallbackMessage,
        ),
      );
    }
    final data = _asMap(body['data']) ?? body;
    final result = BulkVerifyResult.fromJson(data);
    // Prefer top-level message when data omits it.
    if (result.message == null && body['message'] != null) {
      return BulkVerifyResult(
        batchId: result.batchId,
        redemptionIds: result.redemptionIds,
        offersCount: result.offersCount,
        cartId: result.cartId,
        pointsEarned: result.pointsEarned,
        pointsUsed: result.pointsUsed,
        voucherId: result.voucherId,
        voucherCode: result.voucherCode,
        voucherDiscount: result.voucherDiscount,
        saleAmount: result.saleAmount,
        netSaleAmount: result.netSaleAmount,
        cashAmount: result.cashAmount,
        paymentMode: result.paymentMode,
        pointsBalance: result.pointsBalance,
        redeemedAt: result.redeemedAt,
        tier: result.tier,
        redemptions: result.redemptions,
        billNo: result.billNo,
        billImage: result.billImage,
        status: result.status,
        message: body['message']?.toString(),
        skippedOffers: result.skippedOffers,
        spinUnlocked: result.spinUnlocked,
      );
    }
    return result;
  }

  Exception _apiException(
    ApiResponse<Map<String, dynamic>> response,
    String fallback,
  ) {
    final body = response.data;
    final code = extractBulkErrorCode(body);
    final message = bulkRedemptionErrorMessage(
      errorCode: code,
      fallback: response.message ?? body?['message']?.toString() ?? fallback,
    );
    return Exception(message);
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }
}
