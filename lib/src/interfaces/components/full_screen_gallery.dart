import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/constants/color_constants.dart';
import '../../data/constants/style_constants.dart';
import '../../data/models/business_info.dart';
import '../../data/providers/screen_size_provider.dart';
import 'advanced_network_image.dart';
import 'home/video_banner_player.dart';

class FullScreenGallery extends ConsumerStatefulWidget {
  final List<BusinessMediaItem> media;
  final int initialIndex;

  FullScreenGallery({
    super.key,
    required List<String> images,
    required this.initialIndex,
  }) : media = images.map(BusinessMediaItem.fromUrl).toList();

  const FullScreenGallery.media({
    super.key,
    required this.media,
    required this.initialIndex,
  });

  @override
  ConsumerState<FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends ConsumerState<FullScreenGallery> {
  late PageController _pageController;
  late int _currentIndex;
  int _pointerCount = 0;
  bool _isZoomed = false;
  final Map<int, TransformationController> _transformControllers = {};

  bool get _pagingLocked => _pointerCount > 1 || _isZoomed;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(
      0,
      widget.media.isEmpty ? 0 : widget.media.length - 1,
    );
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    for (final controller in _transformControllers.values) {
      controller.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  TransformationController _controllerFor(int index) {
    return _transformControllers.putIfAbsent(
      index,
      TransformationController.new,
    );
  }

  void _resetZoomAt(int index) {
    final controller = _transformControllers[index];
    if (controller != null && controller.value != Matrix4.identity()) {
      controller.value = Matrix4.identity();
    }
  }

  void _handlePointerCountChange(int delta) {
    final next = (_pointerCount + delta).clamp(0, 20);
    if (next == _pointerCount) return;
    setState(() => _pointerCount = next);
  }

  void _syncZoomState(int index) {
    final scale = _controllerFor(index).value.getMaxScaleOnAxis();
    final zoomed = scale > 1.01;
    if (zoomed == _isZoomed) return;
    setState(() => _isZoomed = zoomed);
  }

  Widget _thumbFor(BusinessMediaItem item) {
    if (item.isVideo) {
      final thumb = item.thumbnailUrl;
      if (thumb != null && thumb.isNotEmpty) {
        return AdvancedNetworkImage(imageUrl: thumb, fit: BoxFit.cover);
      }
      return const ColoredBox(
        color: Color(0xFF1F2937),
        child: Center(
          child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
        ),
      );
    }
    return AdvancedNetworkImage(imageUrl: item.url, fit: BoxFit.cover);
  }

  Widget _buildZoomableImage(BusinessMediaItem item, int index) {
    final controller = _controllerFor(index);

    return Hero(
      tag: 'gallery_image_${item.url}_$index',
      child: Listener(
        onPointerDown: (_) => _handlePointerCountChange(1),
        onPointerUp: (_) {
          _handlePointerCountChange(-1);
          _syncZoomState(index);
        },
        onPointerCancel: (_) {
          _handlePointerCountChange(-1);
          _syncZoomState(index);
        },
        child: InteractiveViewer(
          transformationController: controller,
          minScale: 1.0,
          maxScale: 4.0,
          onInteractionEnd: (_) => _syncZoomState(index),
          child: Center(
            child: AdvancedNetworkImage(
              imageUrl: item.url,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = ref.watch(screenSizeProvider);
    final items = widget.media;

    return Scaffold(
      backgroundColor: kBlack,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            physics: _pagingLocked
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            itemCount: items.length,
            onPageChanged: (index) {
              _resetZoomAt(_currentIndex);
              setState(() {
                _currentIndex = index;
                _isZoomed = false;
                _pointerCount = 0;
              });
            },
            itemBuilder: (context, index) {
              final item = items[index];
              if (item.isVideo) {
                return Center(
                  child: VideoBannerPlayer(
                    key: ValueKey('gallery_video_${item.url}_$index'),
                    videoUrl: item.url,
                    thumbnailUrl: item.thumbnailUrl,
                    isActivePage: index == _currentIndex,
                    autoplay: true,
                    loop: true,
                    muted: false,
                    showControls: true,
                  ),
                );
              }

              return _buildZoomableImage(item, index);
            },
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: screenSize.responsivePadding(16),
                vertical: screenSize.responsivePadding(8),
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    kBlack.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: kWhite),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text(
                    '${_currentIndex + 1} / ${items.length}',
                    style: kBodyTitleM.copyWith(color: kWhite),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
          Positioned(
            bottom:
                MediaQuery.paddingOf(context).bottom +
                screenSize.responsivePadding(20),
            left: 0,
            right: 0,
            child: SizedBox(
              height: screenSize.responsivePadding(60),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: screenSize.responsivePadding(16),
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final isSelected = _currentIndex == index;
                  final item = items[index];
                  return GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.only(
                        right: screenSize.responsivePadding(8),
                      ),
                      width: isSelected
                          ? screenSize.responsivePadding(60)
                          : screenSize.responsivePadding(50),
                      height: isSelected
                          ? screenSize.responsivePadding(60)
                          : screenSize.responsivePadding(50),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected ? kWhite : Colors.transparent,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _thumbFor(item),
                          if (item.isVideo)
                            const Align(
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.play_circle_fill_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          if (!isSelected)
                            Container(
                              color: kBlack.withValues(alpha: 0.4),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
