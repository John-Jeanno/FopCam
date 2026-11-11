import 'package:flutter/material.dart';
import 'package:mobile/utils/media_url_helper.dart';

class ProductImageGallery extends StatefulWidget {
  const ProductImageGallery({
    super.key,
    required this.images,
    this.aspectRatio = 1.25,
    this.height,
    this.backgroundColor = const Color(0xFF1F2937),
    this.fit = BoxFit.contain,
    this.enableFullscreenViewer = false,
  });

  final List<String> images;
  final double aspectRatio;
  final double? height;
  final Color backgroundColor;
  final BoxFit fit;
  final bool enableFullscreenViewer;

  @override
  State<ProductImageGallery> createState() => _ProductImageGalleryState();
}

class _ProductImageGalleryState extends State<ProductImageGallery> {
  late final PageController _controller;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gallery = widget.images
        .map((image) => normalizeMediaUrl(image))
        .whereType<String>()
        .toList(growable: false);

    final content = Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: widget.backgroundColor,
          child: gallery.isEmpty
              ? const Center(
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: Colors.white54,
                    size: 48,
                  ),
                )
              : PageView.builder(
                  controller: _controller,
                  itemCount: gallery.length,
                  onPageChanged: (index) => setState(() {
                    _currentIndex = index;
                  }),
                  itemBuilder: (context, index) => Image.network(
                    gallery[index],
                    fit: widget.fit,
                    width: double.infinity,
                    errorBuilder: (_, _, _) => const Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.white54,
                        size: 48,
                      ),
                    ),
                  ),
                ),
        ),
        if (gallery.length > 1)
          Positioned(
            right: 10,
            bottom: 10,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                child: Text(
                  '${_currentIndex + 1}/${gallery.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        if (widget.enableFullscreenViewer && gallery.isNotEmpty)
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              tooltip: 'Agrandir les images',
              onPressed: () => _openFullscreenViewer(gallery),
              icon: const Icon(Icons.open_in_full, color: Colors.white),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                minimumSize: const Size(36, 36),
              ),
            ),
          ),
      ],
    );

    final interactiveContent = widget.enableFullscreenViewer
        ? GestureDetector(
            onTap: gallery.isEmpty
                ? null
                : () => _openFullscreenViewer(gallery),
            child: content,
          )
        : content;

    if (widget.height != null) {
      return SizedBox(height: widget.height, child: interactiveContent);
    }
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: interactiveContent,
    );
  }

  Future<void> _openFullscreenViewer(List<String> gallery) => showDialog<void>(
    context: context,
    builder: (_) => _ProductImageViewer(
      images: gallery,
      initialIndex: _currentIndex,
      backgroundColor: widget.backgroundColor,
    ),
  );
}

class _ProductImageViewer extends StatefulWidget {
  const _ProductImageViewer({
    required this.images,
    required this.initialIndex,
    required this.backgroundColor,
  });

  final List<String> images;
  final int initialIndex;
  final Color backgroundColor;

  @override
  State<_ProductImageViewer> createState() => _ProductImageViewerState();
}

class _ProductImageViewerState extends State<_ProductImageViewer> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _currentIndex = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    backgroundColor: Colors.black,
    child: SafeArea(
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: widget.backgroundColor,
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.images.length,
                onPageChanged: (index) => setState(() {
                  _currentIndex = index;
                }),
                itemBuilder: (context, index) => InteractiveViewer(
                  child: Image.network(
                    widget.images[index],
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.white54,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              tooltip: 'Fermer la galerie',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                minimumSize: const Size(44, 44),
              ),
            ),
          ),
          if (widget.images.length > 1)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Text(
                      '${_currentIndex + 1}/${widget.images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
