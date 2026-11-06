import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/constants/color_constants.dart';
import '../../data/constants/style_constants.dart';
import '../../data/models/referral_models.dart';
import '../../data/providers/referral_provider.dart';
import '../../data/utils/referral_code.dart';
import 'primary_text_field.dart';

class ReferralCodeField extends ConsumerStatefulWidget {
  final TextEditingController controller;

  const ReferralCodeField({super.key, required this.controller});

  @override
  ConsumerState<ReferralCodeField> createState() => ReferralCodeFieldState();
}

class ReferralCodeFieldState extends ConsumerState<ReferralCodeField> {
  Timer? _debounce;
  bool _checking = false;
  bool _userEdited = false;
  ReferralValidation? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _userEdited || widget.controller.text.isNotEmpty) return;
      final code = ref.read(pendingReferralProvider);
      if (code == null || code.isEmpty) return;
      widget.controller.text = code;
      _validate(code);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Validates immediately. Empty is allowed. Used by the submit buttons
  /// so a fast tap does not race the 400ms debounce.
  Future<ReferralValidation> resolve() {
    _debounce?.cancel();
    return _validate(widget.controller.text, strict: true);
  }

  void _onChanged(String value) {
    _userEdited = true;
    final upper = value.toUpperCase();
    if (upper != value) {
      widget.controller.value = TextEditingValue(
        text: upper,
        selection: TextSelection.collapsed(offset: upper.length),
      );
    }
    _schedule(upper);
  }

  void _schedule(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _checking = false;
        _result = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _validate(value);
    });
  }

  Future<ReferralValidation> _validate(
    String raw, {
    bool strict = false,
  }) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      const empty = ReferralValidation.empty();
      if (mounted) {
        setState(() {
          _checking = false;
          _result = null;
        });
      }
      return empty;
    }

    // Don't flash an error, or hit the API, while the code is still short.
    if (!strict && trimmed.length < 6) {
      if (mounted) {
        setState(() {
          _checking = false;
          _result = null;
        });
      }
      return const ReferralValidation.empty();
    }

    final normalized = ReferralCode.normalize(trimmed);
    if (normalized == null) {
      const invalid = ReferralValidation.invalid('Invalid referral code');
      if (mounted) {
        setState(() {
          _checking = false;
          _result = invalid;
        });
      }
      return invalid;
    }

    if (mounted) setState(() => _checking = true);
    final result = await ref
        .read(referralRepositoryProvider)
        .validate(normalized);
    if (!mounted || widget.controller.text.trim().toUpperCase() != normalized) {
      return result;
    }
    setState(() {
      _checking = false;
      _result = result;
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(pendingReferralProvider, (previous, next) {
      if (_userEdited || next == null || next.isEmpty) return;
      if (widget.controller.text.isNotEmpty) return;
      widget.controller.text = next;
      _validate(next);
    });

    final result = _result;
    final caption = _checking
        ? 'Checking code...'
        : result == null
        ? null
        : result.valid
        ? 'Code applied (Referred by ${result.referrerName ?? 'a friend'})'
        : result.message;

    final captionColor = _checking
        ? kSecondaryTextColor
        : (result?.valid ?? false)
        ? const Color(0xFF15803D)
        : const Color(0xFFDC2626);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PrimaryTextField(
          label: 'Referral Code (Optional)',
          hint: 'S00001',
          controller: widget.controller,
          maxLength: 6,
          showCounter: false,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
          ],
          suffixIcon: result?.valid == true
              ? const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF15803D),
                  size: 20,
                )
              : null,
          onChanged: _onChanged,
        ),
        if (caption != null) ...[
          const SizedBox(height: 8),
          Text(
            caption,
            style: kSmallerTitleM.copyWith(color: captionColor),
          ),
        ],
      ],
    );
  }
}
