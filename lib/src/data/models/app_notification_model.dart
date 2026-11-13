class NotificationAction {
  /// Backend enum: open_offer | open_shop | open_reward | open_url |
  /// open_screen | open_profile | open_subscription | open_branch |
  /// open_booking | open_product_inquiry | none
  final String type;
  final String? targetId;
  final String? url;
  final String? screen;

  const NotificationAction({
    required this.type,
    this.targetId,
    this.url,
    this.screen,
  });

  bool get isNavigable => type.isNotEmpty && type != 'none';

  factory NotificationAction.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const NotificationAction(type: 'none');
    }
    return NotificationAction(
      type: (json['type'] ?? 'none').toString().trim().toLowerCase(),
      targetId: json['targetId']?.toString(),
      url: json['url']?.toString(),
      screen: json['screen']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    if (targetId != null) 'targetId': targetId,
    if (url != null) 'url': url,
    if (screen != null) 'screen': screen,
  };
}

class AppNotificationModel {
  final String id;
  final String title;
  final String message;
  final bool read;
  final DateTime createdAt;
  final String? type;
  final String? imageUrl;
  final NotificationAction? action;
  final Map<String, dynamic>? metadata;

  AppNotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.read,
    required this.createdAt,
    this.type,
    this.imageUrl,
    this.action,
    this.metadata,
  });

  AppNotificationModel copyWith({
    String? id,
    String? title,
    String? message,
    bool? read,
    DateTime? createdAt,
    String? type,
    String? imageUrl,
    NotificationAction? action,
    Map<String, dynamic>? metadata,
  }) {
    return AppNotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      read: read ?? this.read,
      createdAt: createdAt ?? this.createdAt,
      type: type ?? this.type,
      imageUrl: imageUrl ?? this.imageUrl,
      action: action ?? this.action,
      metadata: metadata ?? this.metadata,
    );
  }

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? metadata;
    final rawMeta = json['metadata'];
    if (rawMeta is Map) {
      metadata = Map<String, dynamic>.from(rawMeta);
    }

    NotificationAction? action;
    final rawAction = json['action'];
    if (rawAction is Map) {
      action = NotificationAction.fromJson(
        Map<String, dynamic>.from(rawAction),
      );
    }

    String? resolveTargetId() =>
        (json['actionTargetId'] ??
                json['targetId'] ??
                metadata?['inquiryId'] ??
                metadata?['cartId'] ??
                json['inquiryId'] ??
                json['cartId'] ??
                metadata?['offerId'] ??
                metadata?['partnerId'] ??
                metadata?['shopId'] ??
                metadata?['rewardId'] ??
                json['id'])
            ?.toString();

    // FCM / flattened payloads sometimes put action fields at the root.
    if (action == null || !action.isNavigable) {
      final actionType =
          (json['actionType'] ?? json['action_type'] ?? json['type'])
              ?.toString()
              .trim()
              .toLowerCase();
      final looksLikeAction =
          actionType != null &&
          (actionType.startsWith('open_') || actionType == 'none');
      if (looksLikeAction) {
        action = NotificationAction(
          type: actionType,
          targetId: resolveTargetId(),
          url: (json['actionUrl'] ?? json['url'] ?? metadata?['url'])
              ?.toString(),
          screen: (json['actionScreen'] ?? json['screen'] ?? metadata?['screen'])
              ?.toString(),
        );
      }
    } else if (action.targetId == null || action.targetId!.isEmpty) {
      // Nested action may omit targetId while metadata carries cartId/inquiryId.
      final fallbackId = resolveTargetId();
      if (fallbackId != null && fallbackId.isNotEmpty) {
        action = NotificationAction(
          type: action.type,
          targetId: fallbackId,
          url: action.url,
          screen: action.screen,
        );
      }
    }

    return AppNotificationModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? json['body'] ?? '').toString(),
      read: json['read'] == true,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      type: json['type']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      action: action,
      metadata: metadata,
    );
  }
}
