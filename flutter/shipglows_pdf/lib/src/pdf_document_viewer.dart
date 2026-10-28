import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';

/// Where a PDF reading stands, as reported by [PdfDocumentViewer]: `mode`
/// (`page`, `full` or `automatic`), `visiblePages`, `zoom`, then `page` in
/// page mode or `offset` in scroll modes. Store it as is and hand it back
/// as `initialPosition`.
typedef DocumentPosition = Map<String, Object?>;

// Values of the design tokens this viewer used. They are copied, not
// imported, so the package has no dependency on a design system.
const double _space2 = 8;
const double _space4 = 16;
const double _space16 = 64;
const double _toolIconSize = 20;
const Duration _durationFast = Duration(milliseconds: 120);
const Duration _durationSlow = Duration(milliseconds: 300);
const Cubic _curveStandard = Cubic(0.2, 0.0, 0.0, 1.0);

/// Zero when the system asks for less motion, otherwise [duration].
Duration _motionDuration(BuildContext context, Duration duration) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;

enum _PdfScrollMode { page, full, automatic }

class PdfDocumentViewer extends StatefulWidget {
  const PdfDocumentViewer({
    required this.path,
    required this.title,
    this.initialPosition,
    this.onPositionChanged,
    this.toolbarBuilder,
    super.key,
  });
  final String path;
  final String title;

  /// Where the reading resumes, as last reported by [onPositionChanged];
  /// null to open on the first page.
  final DocumentPosition? initialPosition;

  /// Receives the reading mode, pages shown, zoom and page or scroll offset
  /// after each change.
  final ValueChanged<DocumentPosition>? onPositionChanged;

  /// Wraps the viewer's toolbar row, for a host that shows it elsewhere (for
  /// example in a dock). Null keeps the row in place, as built by the viewer.
  final Widget Function(BuildContext context, Widget toolbar)? toolbarBuilder;

  @override
  State<PdfDocumentViewer> createState() => _PdfDocumentViewerState();
}

class _PdfDocumentViewerState extends State<PdfDocumentViewer>
    with SingleTickerProviderStateMixin {
  /// Speed of the automatic scroll, in logical pixels per second.
  static const double _autoScrollSpeed = 20;

  late final Future<PdfDocument> _document = PdfDocument.openFile(widget.path);
  int _page = 1;
  int _visiblePages = 1;
  double _zoom = 1;
  _PdfScrollMode _mode = _PdfScrollMode.page;
  late final PageController _pageController;
  late final ScrollController _scrollController;
  Ticker? _autoScroll;
  double _autoScrollStart = 0;
  double _dragDistance = 0;
  double? _manualScrollTarget;
  int _scrollAnimationGeneration = 0;

  @override
  void initState() {
    super.initState();
    var offset = 0.0;
    if (widget.initialPosition case final saved?) {
      // The automatic scroll resumes as a plain scroll: it never starts alone.
      _mode = switch (saved['mode']) {
        'full' || 'automatic' => _PdfScrollMode.full,
        _ => _PdfScrollMode.page,
      };
      if (saved['visiblePages'] case final int count
          when count >= 1 && count <= 4) {
        _visiblePages = count;
      }
      if (saved['zoom'] case final num zoom) {
        _zoom = zoom.toDouble().clamp(1, 3).toDouble();
      }
      if (saved['page'] case final int page
          when page >= 1 && _mode == _PdfScrollMode.page) {
        _page = ((page - 1) ~/ _visiblePages) * _visiblePages + 1;
      }
      if (saved['offset'] case final num saved
          when saved > 0 && _mode != _PdfScrollMode.page) {
        offset = saved.toDouble();
      }
    }
    _pageController = PageController(initialPage: (_page - 1) ~/ _visiblePages);
    _scrollController = ScrollController(initialScrollOffset: offset)
      ..addListener(_reportPosition);
    // A file that lost pages since reopens on its last ones.
    unawaited(
      _document.then<void>((document) {
        final total = document.pagesCount;
        if (!mounted || total < 1 || _page <= total) return;
        setState(
          () => _page = ((total - 1) ~/ _visiblePages) * _visiblePages + 1,
        );
      }, onError: (Object _, StackTrace __) {}),
    );
  }

  /// Reports where the reading is to [PdfDocumentViewer.onPositionChanged].
  void _reportPosition() {
    final report = widget.onPositionChanged;
    if (report == null) return;
    report({
      'mode': _mode.name,
      'visiblePages': _visiblePages,
      'zoom': _zoom,
      if (_mode == _PdfScrollMode.page)
        'page': _page
      else if (_scrollController.hasClients)
        'offset': _scrollController.offset,
    });
  }

  @override
  void dispose() {
    _autoScroll?.dispose();
    _pageController.dispose();
    _scrollController.dispose();
    _viewerFocus.dispose();
    unawaited(
      _document
          .then<void>((document) async {
            await _PdfPageTileState.waitForPendingRenders();
            if (!document.isClosed) await document.close();
          }, onError: (Object _, StackTrace __) {})
          .catchError((Object _) {}),
    );
    super.dispose();
  }

  void _setZoom(double zoom) {
    setState(() => _zoom = zoom.clamp(1, 3).toDouble());
    _reportPosition();
  }

  void _setMode(_PdfScrollMode mode) {
    _autoScroll?.stop();
    _scrollAnimationGeneration++;
    _manualScrollTarget = null;
    setState(() {
      _mode = mode;
      _page = 1;
    });
    _reportPosition();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (mode == _PdfScrollMode.page && _pageController.hasClients) {
        _pageController.jumpToPage(0);
      } else if (mode != _PdfScrollMode.page && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
        _manualScrollTarget = 0;
      }
      if (mode == _PdfScrollMode.automatic) {
        _autoScrollStart = _scrollController.hasClients
            ? _scrollController.position.pixels
            : 0;
        (_autoScroll ??= createTicker(_onAutoScrollTick)).start();
      }
    });
  }

  /// Moves the automatic scroll one frame on: a ticker, so the motion is
  /// frame-synchronous instead of a 20 Hz timer, and stops at the end.
  void _onAutoScrollTick(Duration elapsed) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final target =
        _autoScrollStart +
        _autoScrollSpeed *
            elapsed.inMicroseconds /
            Duration.microsecondsPerSecond;
    if (target >= position.maxScrollExtent) {
      _scrollController.jumpTo(position.maxScrollExtent);
      _autoScroll?.stop();
      return;
    }
    _scrollController.jumpTo(target.clamp(0, position.maxScrollExtent));
  }

  void _setVisiblePages(int count, int total) {
    _scrollAnimationGeneration++;
    _manualScrollTarget = null;
    final firstPage = _mode == _PdfScrollMode.page
        ? ((_page - 1) ~/ count) * count + 1
        : 1;
    setState(() {
      _visiblePages = count;
      _page = firstPage.clamp(1, total).toInt();
    });
    _reportPosition();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_mode == _PdfScrollMode.page && _pageController.hasClients) {
        _pageController.jumpToPage((_page - 1) ~/ _visiblePages);
      } else if (_mode != _PdfScrollMode.page && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
        _manualScrollTarget = 0;
      }
    });
  }

  final FocusNode _viewerFocus = FocusNode(debugLabel: 'Partition PDF');

  /// Height of the pages' viewport, for a Page ↓ that scrolls one screen.
  double _viewportHeight = 0;

  /// Keyboard reading of the pages: one group per key in page mode, a step
  /// or a screen in scroll modes. Space stays with the transport.
  KeyEventResult _onViewerKey(KeyEvent event, int total) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isControlPressed) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final forward =
        key == LogicalKeyboardKey.pageDown ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowRight;
    final backward =
        key == LogicalKeyboardKey.pageUp ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowLeft;
    final home = key == LogicalKeyboardKey.home;
    final end = key == LogicalKeyboardKey.end;
    if (!forward && !backward && !home && !end) return KeyEventResult.ignored;
    if (_mode == _PdfScrollMode.page) {
      if (home || end) {
        final lastGroup = (total - 1) ~/ _visiblePages;
        final target = home ? 0 : lastGroup;
        final current = (_page - 1) ~/ _visiblePages;
        if (target != current) _movePageGroup(target - current, total);
      } else {
        _movePageGroup(forward ? 1 : -1, total);
      }
      return KeyEventResult.handled;
    }
    if (!_scrollController.hasClients) return KeyEventResult.handled;
    final position = _scrollController.position;
    final page =
        key == LogicalKeyboardKey.pageDown || key == LogicalKeyboardKey.pageUp;
    final step = page ? _viewportHeight * 0.9 : _space16 + _space4;
    final current = _manualScrollTarget ?? position.pixels;
    final target = home
        ? 0.0
        : end
        ? position.maxScrollExtent
        : current + (forward ? step : -step);
    _animateManualScroll(target);
    return KeyEventResult.handled;
  }

  void _movePageGroup(int direction, int total) {
    if (!_pageController.hasClients) return;
    final currentGroup = (_page - 1) ~/ _visiblePages;
    final lastGroup = (total - 1) ~/ _visiblePages;
    final nextGroup = (currentGroup + direction).clamp(0, lastGroup);
    if (nextGroup == currentGroup) return;
    _pageController.animateToPage(
      nextGroup,
      duration: _motionDuration(context, _durationSlow),
      curve: _curveStandard,
    );
  }

  void _animateManualScroll(
    double target, {
    Duration duration = _durationSlow,
  }) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final boundedTarget = target.clamp(0, position.maxScrollExtent).toDouble();
    _manualScrollTarget = boundedTarget;
    final generation = ++_scrollAnimationGeneration;
    unawaited(
      _scrollController
          .animateTo(
            boundedTarget,
            duration: _motionDuration(context, duration),
            curve: _curveStandard,
          )
          .whenComplete(() {
            if (generation == _scrollAnimationGeneration) {
              _manualScrollTarget = null;
            }
          }),
    );
  }

  void _handleFullScrollSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        event.scrollDelta.dy == 0 ||
        !_scrollController.hasClients) {
      return;
    }
    final current = _manualScrollTarget ?? _scrollController.offset;
    _animateManualScroll(current + event.scrollDelta.dy);
  }

  void _handleFullDragStart() {
    _scrollAnimationGeneration++;
    _manualScrollTarget = _scrollController.hasClients
        ? _scrollController.offset
        : null;
  }

  void _handleFullDragUpdate(DragUpdateDetails details) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final current = _manualScrollTarget ?? position.pixels;
    final target = (current - (details.primaryDelta ?? 0))
        .clamp(0, position.maxScrollExtent)
        .toDouble();
    _manualScrollTarget = target;
    _scrollController.jumpTo(target);
  }

  void _handleFullDragEnd(DragEndDetails details) {
    if (!_scrollController.hasClients) return;
    final projected =
        _scrollController.offset - details.velocity.pixelsPerSecond.dy * 0.14;
    // A fling glides longer than a wheel step.
    _animateManualScroll(projected, duration: _durationSlow + _durationFast);
  }

  // Disable partial PageView wheel motion and map each scroll or swipe to one
  // complete group so the selected pages always move together.
  void _handlePageScrollSignal(PointerSignalEvent event, int total) {
    if (event is! PointerScrollEvent || event.scrollDelta.dy == 0) return;
    _movePageGroup(event.scrollDelta.dy > 0 ? 1 : -1, total);
  }

  void _handlePageDragUpdate(DragUpdateDetails details) {
    _dragDistance += details.primaryDelta ?? 0;
  }

  void _handlePageDragEnd(DragEndDetails details, int total) {
    final velocity = details.velocity.pixelsPerSecond.dy;
    final direction = velocity.abs() > 100
        ? (velocity < 0 ? 1 : -1)
        : (_dragDistance.abs() > 48 ? (_dragDistance < 0 ? 1 : -1) : 0);
    _dragDistance = 0;
    if (direction != 0) _movePageGroup(direction, total);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<PdfDocument>(
    future: _document,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(child: Text("Impossible d'ouvrir ce PDF."));
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final total = snapshot.data!.pagesCount;
      final lastVisiblePage = (_page + _visiblePages - 1).clamp(1, total);
      final toolbar = Padding(
        padding: const EdgeInsets.fromLTRB(_space4, _space2, _space4, _space2),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: _space4,
          runSpacing: _space2,
          children: [
            SegmentedButton<_PdfScrollMode>(
              segments: const [
                ButtonSegment(
                  value: _PdfScrollMode.page,
                  label: Text('Page par page'),
                ),
                ButtonSegment(
                  value: _PdfScrollMode.full,
                  label: Text('Scroll complet'),
                ),
                ButtonSegment(
                  value: _PdfScrollMode.automatic,
                  label: Text('Automatique'),
                ),
              ],
              selected: {_mode},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => _setMode(selection.first),
            ),
            SegmentedButton<int>(
              segments: [
                for (var count = 1; count <= 4; count++)
                  ButtonSegment(value: count, label: Text('$count')),
              ],
              selected: {_visiblePages},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  _setVisiblePages(selection.first, total),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Réduire le zoom',
                  onPressed: _zoom > 1 ? () => _setZoom(_zoom - 0.25) : null,
                  icon: const Icon(Icons.zoom_out, size: _toolIconSize),
                ),
                Text(
                  '${(_zoom * 100).round()} %',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                IconButton(
                  tooltip: 'Réinitialiser le zoom',
                  onPressed: _zoom == 1 ? null : () => _setZoom(1),
                  icon: const Icon(Icons.fit_screen, size: _toolIconSize),
                ),
                IconButton(
                  tooltip: 'Agrandir',
                  onPressed: _zoom < 3 ? () => _setZoom(_zoom + 0.25) : null,
                  icon: const Icon(Icons.zoom_in, size: _toolIconSize),
                ),
              ],
            ),
            if (_mode == _PdfScrollMode.page)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Page avant',
                    onPressed: _page > 1
                        ? () => _movePageGroup(-1, total)
                        : null,
                    icon: const Icon(Icons.chevron_left, size: _toolIconSize),
                  ),
                  Text(
                    _page == lastVisiblePage
                        ? '$_page / $total'
                        : '$_page–$lastVisiblePage / $total',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  IconButton(
                    tooltip: 'Page suivante',
                    onPressed: _page + _visiblePages <= total
                        ? () => _movePageGroup(1, total)
                        : null,
                    icon: const Icon(Icons.chevron_right, size: _toolIconSize),
                  ),
                ],
              ),
          ],
        ),
      );
      return Column(
        children: [
          // One toolbar row in the dock: view mode, pages per screen,
          // zoom, pager.
          widget.toolbarBuilder?.call(context, toolbar) ?? toolbar,
          Expanded(
            // Keyboard reading: Page ↑/↓ and the arrows turn or scroll
            // the pages, Début/Fin go to the ends; a click on the pages
            // gives them the focus.
            child: Focus(
              focusNode: _viewerFocus,
              onKeyEvent: (node, event) => _onViewerKey(event, total),
              child: Semantics(
                label: _mode == _PdfScrollMode.page
                    ? 'Partition, pages $_page à $lastVisiblePage sur '
                          '$total. Page suivante et précédente au clavier.'
                    : 'Partition, $total pages. Défilement au clavier.',
                onScrollUp: _mode == _PdfScrollMode.page
                    ? () => _movePageGroup(1, total)
                    : null,
                onScrollDown: _mode == _PdfScrollMode.page
                    ? () => _movePageGroup(-1, total)
                    : null,
                child: Listener(
                  onPointerDown: (_) => _viewerFocus.requestFocus(),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      _viewportHeight = constraints.maxHeight;
                      final pageMode = _mode == _PdfScrollMode.page;
                      if (pageMode) {
                        const spacing = _space2;
                        final pageWidth =
                            (constraints.maxWidth -
                                spacing * (_visiblePages - 1)) /
                            _visiblePages;
                        return Listener(
                          onPointerSignal: (event) =>
                              _handlePageScrollSignal(event, total),
                          child: GestureDetector(
                            onVerticalDragStart: (_) => _dragDistance = 0,
                            onVerticalDragUpdate: _handlePageDragUpdate,
                            onVerticalDragEnd: (details) =>
                                _handlePageDragEnd(details, total),
                            child: PageView.builder(
                              controller: _pageController,
                              physics: const NeverScrollableScrollPhysics(),
                              scrollDirection: Axis.vertical,
                              itemCount:
                                  (total + _visiblePages - 1) ~/ _visiblePages,
                              onPageChanged: (group) {
                                setState(
                                  () => _page = group * _visiblePages + 1,
                                );
                                _reportPosition();
                              },
                              itemBuilder: (context, group) {
                                final firstPage = group * _visiblePages + 1;
                                return Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    for (
                                      var index = 0;
                                      index < _visiblePages;
                                      index++
                                    )
                                      Expanded(
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                            right: index < _visiblePages - 1
                                                ? spacing
                                                : 0,
                                          ),
                                          child: firstPage + index <= total
                                              ? _PdfPageTile(
                                                  key: ValueKey(
                                                    '${firstPage + index}-${pdfWidthStep(constraints.maxWidth)}',
                                                  ),
                                                  document: snapshot.data!,
                                                  pageNumber: firstPage + index,
                                                  width: pageWidth,
                                                  zoom: _zoom,
                                                )
                                              : const SizedBox.shrink(),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        );
                      }
                      const spacing = _space2;
                      final pageWidth =
                          (constraints.maxWidth -
                              spacing * (_visiblePages - 1)) /
                          _visiblePages;
                      final grid = GridView.builder(
                        controller: _scrollController,
                        physics: _mode == _PdfScrollMode.full
                            ? const NeverScrollableScrollPhysics()
                            : null,
                        padding: const EdgeInsets.all(_space2),
                        itemCount: total,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _visiblePages,
                          crossAxisSpacing: spacing,
                          mainAxisSpacing: _space2,
                          childAspectRatio: 0.707,
                        ),
                        itemBuilder: (context, index) {
                          final page = index + 1;
                          return _PdfPageTile(
                            key: ValueKey(
                              '$page-${pdfWidthStep(constraints.maxWidth)}',
                            ),
                            document: snapshot.data!,
                            pageNumber: page,
                            width: pageWidth,
                            zoom: _zoom,
                          );
                        },
                      );
                      if (_mode != _PdfScrollMode.full) return grid;
                      return Listener(
                        onPointerSignal: _handleFullScrollSignal,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragStart: (_) => _handleFullDragStart(),
                          onVerticalDragUpdate: _handleFullDragUpdate,
                          onVerticalDragEnd: _handleFullDragEnd,
                          child: grid,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _PdfPageTile extends StatefulWidget {
  const _PdfPageTile({
    required this.document,
    required this.pageNumber,
    required this.width,
    required this.zoom,
    super.key,
  });

  final PdfDocument document;
  final int pageNumber;
  final double width;
  final double zoom;

  @override
  State<_PdfPageTile> createState() => _PdfPageTileState();
}

class _PdfPageTileState extends State<_PdfPageTile> {
  static Future<void> _renderQueue = Future<void>.value();
  late final Future<Uint8List?> _image = _render();
  late final TransformationController _transformationController =
      TransformationController();

  @override
  void didUpdateWidget(covariant _PdfPageTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.zoom != widget.zoom) {
      _transformationController.value = Matrix4.diagonal3Values(
        widget.zoom,
        widget.zoom,
        1,
      );
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  static Future<void> waitForPendingRenders() => _renderQueue;

  Future<Uint8List?> _render() {
    final task = _renderQueue.then((_) async {
      final page = await widget.document.getPage(widget.pageNumber);
      try {
        final width = (widget.width * 2).roundToDouble();
        final image = await page.render(
          width: width,
          height: width * page.height / page.width,
          format: PdfPageImageFormat.png,
          backgroundColor: '#FFFFFF',
        );
        return image?.bytes;
      } finally {
        await page.close();
      }
    });
    _renderQueue = task.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return task;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: _image,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(child: Text('Page ${widget.pageNumber} illisible'));
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final theme = Theme.of(context);
      final image = Image.memory(
        snapshot.data!,
        fit: BoxFit.contain,
        semanticLabel: 'Page ${widget.pageNumber}',
      );
      // Own layer: the dark-mode colour filter of one page never
      // re-rasterises its neighbours.
      return RepaintBoundary(
        child: InteractiveViewer(
          transformationController: _transformationController,
          alignment: Alignment.center,
          panEnabled: widget.zoom > 1,
          scaleEnabled: false,
          minScale: 1,
          maxScale: 3,
          boundaryMargin: const EdgeInsets.all(1000),
          child: SizedBox.expand(
            child: ColoredBox(
              color: theme.colorScheme.surfaceContainerHighest,
              child: theme.brightness == Brightness.dark
                  ? ColorFiltered(
                      colorFilter: _darkModeFilter(
                        theme.colorScheme.surfaceContainerHigh,
                        theme.colorScheme.onSurface,
                      ),
                      child: image,
                    )
                  : image,
            ),
          ),
        ),
      );
    },
  );
}

/// Width bucket of a page tile: a tile is re-rendered only when the width
/// crosses a 32 px step, not on every pixel of a window resize.
int pdfWidthStep(double width) => (width / 32).round();

/// Dark-mode filter: maps the page's paper to [paperColor] and its ink to
/// [inkColor], channel by channel.
ColorFilter _darkModeFilter(Color paperColor, Color inkColor) {
  final paper = paperColor.toARGB32();
  final ink = inkColor.toARGB32();
  final paperRed = (paper >> 16) & 0xff;
  final paperGreen = (paper >> 8) & 0xff;
  final paperBlue = paper & 0xff;
  final inkRed = (ink >> 16) & 0xff;
  final inkGreen = (ink >> 8) & 0xff;
  final inkBlue = ink & 0xff;

  double channelScale(int foreground, int background) =>
      (background - foreground) / 255;

  return ColorFilter.matrix([
    channelScale(inkRed, paperRed),
    0,
    0,
    0,
    inkRed.toDouble(),
    0,
    channelScale(inkGreen, paperGreen),
    0,
    0,
    inkGreen.toDouble(),
    0,
    0,
    channelScale(inkBlue, paperBlue),
    0,
    inkBlue.toDouble(),
    0,
    0,
    0,
    1,
    0,
  ]);
}
