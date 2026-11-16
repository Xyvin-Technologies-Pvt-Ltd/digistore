import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/constants/color_constants.dart';
import '../../../data/constants/style_constants.dart';
import '../../../data/providers/screen_size_provider.dart';
import '../../../data/providers/user_provider.dart';
import '../../../data/services/secure_storage_service.dart';
import '../../../data/services/toast_service.dart';
import '../../components/primary_button.dart';
import '../../components/primary_text_field.dart';
import '../../components/location_selection_bottom_sheet.dart';

class MyAccountPage extends ConsumerStatefulWidget {
  final bool isEditMode;
  const MyAccountPage({super.key, this.isEditMode = false});

  @override
  ConsumerState<MyAccountPage> createState() => _MyAccountPageState();
}

class _MyAccountPageState extends ConsumerState<MyAccountPage> {
  late TextEditingController _nameController;
  late TextEditingController _mobileController;
  late TextEditingController _emailController;
  late TextEditingController _locationController;

  double? _lat;
  double? _lng;
  String? _district;
  String? _localBody;

  double? _initialLat;
  double? _initialLng;
  String? _initialDistrict;
  String? _initialLocalBody;

  String? _nameError;
  String? _emailError;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(userProvider);
    _nameController = TextEditingController(text: user?.name ?? '');
    _mobileController = TextEditingController(text: user?.phone ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');

    _district = user?.location?.district;
    _localBody = user?.location?.localBody;
    _lat = user?.location?.coordinates?.lat;
    _lng = user?.location?.coordinates?.lng;

    _initialDistrict = _district;
    _initialLocalBody = _localBody;
    _initialLat = _lat;
    _initialLng = _lng;

    _locationController = TextEditingController(
      text: (_localBody != null && _localBody!.isNotEmpty)
          ? _localBody!.split(' ').first
          : (_district != null && _district!.isNotEmpty)
          ? _district!.split(' ').first
          : '',
    );

    if (_mobileController.text.isEmpty) {
      ref.read(secureStorageServiceProvider).getRegistrationData().then((data) {
        final phone = data?['phone'] as String?;
        if (phone != null &&
            phone.isNotEmpty &&
            mounted &&
            _mobileController.text.isEmpty) {
          setState(() {
            _mobileController.text = phone;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Full name is required';
    }
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      return 'Name must be at least 2 characters';
    }
    if (trimmed.length > 30) {
      return 'Name cannot exceed 30 characters';
    }
    if (RegExp(r'[0-9]').hasMatch(trimmed)) {
      return 'Numbers are not allowed in name';
    }
    final emojiRegex = RegExp(
      r'(\u00a9|\u00ae|[\u2000-\u3300]|\ud83c[\ud000-\udfff]|\ud83d[\ud000-\udfff]|\ud83e[\ud000-\udfff])',
      unicode: true,
    );
    if (emojiRegex.hasMatch(trimmed)) {
      return 'Emojis are not allowed in name';
    }
    if (!RegExp(r"^[a-zA-Z\u00C0-\u024F\s.'-]+$").hasMatch(trimmed)) {
      return 'Special characters are not allowed';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final trimmed = value.trim();
    if (trimmed.contains(' ')) {
      return 'Email cannot contain spaces';
    }
    if (!trimmed.contains('@')) {
      return 'Email must contain an @';
    }
    final parts = trimmed.split('@');
    if (parts.length != 2 || parts[0].isEmpty) {
      return 'Please enter a valid email prefix';
    }
    final domain = parts[1];
    if (domain.isEmpty ||
        !domain.contains('.') ||
        domain.split('.').last.length < 2) {
      return 'Please enter a valid domain (e.g. example.com)';
    }
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(trimmed)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = ref.watch(screenSizeProvider);
    final isEditMode = widget.isEditMode;
    final user = ref.watch(userProvider);
    if (_mobileController.text.isEmpty &&
        user?.phone != null &&
        user!.phone!.isNotEmpty) {
      _mobileController.text = user.phone!;
    }

    return Scaffold(
      backgroundColor: kWhite,
      appBar: AppBar(
        backgroundColor: kWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: kTextColor,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Account',
          style: kSubHeadingM.copyWith(color: kTextColor),
        ),
        centerTitle: false,
        titleSpacing: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(screenSize.responsivePadding(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isEditMode) ...[
                        PrimaryTextField(
                          label: 'Name',
                          hint: 'Enter your name',
                          controller: _nameController,
                          isRequired: true,
                          maxLength: 30,
                          showCounter: false,
                          errorText: _nameError,
                          onChanged: (_) {
                            if (_nameError != null) {
                              setState(() => _nameError = null);
                            }
                          },
                        ),
                        SizedBox(height: screenSize.responsivePadding(24)),
                        PrimaryTextField(
                          label: 'Mobile Number',
                          hint: 'Enter mobile number',
                          controller: _mobileController,
                          readOnly: true,
                        ),
                        SizedBox(height: screenSize.responsivePadding(24)),
                        PrimaryTextField(
                          label: 'Email',
                          hint: 'Enter email',
                          controller: _emailController,
                          type: TextFieldType.email,
                          inputFormatters: [
                            FilteringTextInputFormatter.deny(RegExp(r'\s')),
                          ],
                          errorText: _emailError,
                          onChanged: (_) {
                            if (_emailError != null) {
                              setState(() => _emailError = null);
                            }
                          },
                        ),
                        SizedBox(height: screenSize.responsivePadding(24)),
                        PrimaryTextField(
                          label: 'Location',
                          hint: 'Tap to capture location',
                          controller: _locationController,
                          isRequired: true,
                          readOnly: true,
                          suffixIcon: const Icon(
                            Icons.my_location_rounded,
                            size: 20,
                            color: kPrimaryColor,
                          ),
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) =>
                                  LocationSelectionBottomSheet(
                                    initialLat: _lat,
                                    initialLng: _lng,
                                    initialDistrict: _district,
                                    initialLocalBody: _localBody,
                                    onLocationSelected:
                                        (district, localBody, lat, lng) {
                                          setState(() {
                                            _locationController.text =
                                                localBody.isNotEmpty
                                                ? localBody.split(' ').first
                                                : district.split(' ').first;
                                            _district = district;
                                            _localBody = localBody;
                                            _lat = lat;
                                            _lng = lng;
                                          });
                                        },
                                  ),
                            );
                          },
                        ),
                      ] else ...[
                        _buildReadOnlyField('Name', _nameController.text),
                        _buildReadOnlyField(
                          'Mobile Number',
                          _mobileController.text,
                        ),
                        _buildReadOnlyField('Email', _emailController.text),
                        _buildReadOnlyField(
                          'Location',
                          _locationController.text
                              .split(',')
                              .first
                              .split(' ')
                              .first,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (isEditMode) ...[
                SizedBox(height: screenSize.responsivePadding(16)),
                PrimaryButton(
                  text: 'Save',
                  isLoading: _isLoading,
                  onPressed: () async {
                    final nameErr = _validateName(_nameController.text);
                    final emailErr = _validateEmail(_emailController.text);

                    setState(() {
                      _nameError = nameErr;
                      _emailError = emailErr;
                    });

                    if (nameErr != null || emailErr != null) {
                      return;
                    }

                    // Auto-trim leading/trailing spaces and normalize multiple spaces
                    final cleanedName = _nameController.text.trim().replaceAll(
                      RegExp(r'\s+'),
                      ' ',
                    );
                    _nameController.text = cleanedName;

                    // Auto-trim spaces and convert uppercase email to lowercase
                    final rawEmail = _emailController.text.trim().replaceAll(
                      ' ',
                      '',
                    );
                    final cleanedEmail = rawEmail.toLowerCase();
                    _emailController.text = cleanedEmail;

                    setState(() {
                      _isLoading = true;
                    });

                    try {
                      final success = await ref
                          .read(userProvider.notifier)
                          .updateProfile(
                            name: cleanedName,
                            email: cleanedEmail,
                          );

                      final bool locationChanged = (_lat != null && _lng != null) &&
                          (_lat != _initialLat ||
                              _lng != _initialLng ||
                              _district != _initialDistrict ||
                              _localBody != _initialLocalBody);

                      if (success && locationChanged) {
                        await ref
                            .read(userProvider.notifier)
                            .updateLocation(
                              lat: _lat!,
                              lng: _lng!,
                              district: _district ?? '',
                              localBody: _localBody ?? '',
                            );
                      }

                      if (success && context.mounted) {
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        final errorMsg =
                            e.toString().replaceAll('Exception: ', '');
                        ToastService().showToast(
                          context,
                          errorMsg,
                          type: ToastType.error,
                        );
                      }
                    } finally {
                      if (mounted) {
                        setState(() {
                          _isLoading = false;
                        });
                      }
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    final screenSize = ref.watch(screenSizeProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: screenSize.responsivePadding(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: kSmallTitleM.copyWith(
              color: const Color(0xFF0A0A0A),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: screenSize.responsivePadding(16)),
          Text(
            value.isNotEmpty ? value : '-',
            style: kSmallTitleL.copyWith(color: const Color(0xFF373737)),
          ),
          SizedBox(height: screenSize.responsivePadding(16)),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
        ],
      ),
    );
  }
}
