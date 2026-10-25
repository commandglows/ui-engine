import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shipglows_icons/shipglows_icons.dart';

import 'onboarding_page.dart';
import 'onboarding_strings.dart';
import 'onboarding_theme.dart';

/// First-run introduction: one fixed two-column card — texts and actions on
/// the left, the page's preview on the right — under a segmented progress
/// bar. Narrow windows get one scrolling column without preview.
///
/// The pages are rebuilt by the app (a new language after the language page,
/// a status that loads); the current page is kept by index.
///
/// The flow moves between pages by itself, unless the app gives [index]: the
/// app then owns the page, for example when signing in moves the flow on.
/// Every move (Next, Back, Skip, a progress segment, a language) is then
/// asked through [onIndexChanged], and the app answers with a new [index].
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    required this.pages,
    required this.strings,
    required this.onFinish,
    this.index,
    this.onIndexChanged,
    this.progressNavigation = true,
  });

  final List<OnboardingPage> pages;
  final OnboardingStrings strings;

  /// Primary action of the last page.
  final VoidCallback onFinish;

  /// Page shown when the app owns the navigation.
  final int? index;

  /// A move asked by the user, with the page it leads to.
  final ValueChanged<int>? onIndexChanged;

  /// Lets done progress segments reopen their page.
  final bool progressNavigation;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  int _index = 0;
  int? _hoveredOption;
  final _titleFocus = FocusNode(debugLabel: 'onboarding-title');

  List<OnboardingPage> get _pages => widget.pages;
  int get _current => (widget.index ?? _index).clamp(0, _pages.length - 1);
  OnboardingPage get _page => _pages[_current];
  bool get _isLast => _current == _pages.length - 1;

  @override
  void dispose() {
    _titleFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant OnboardingFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != null && widget.index != oldWidget.index) {
      _focusTitle();
    }
  }

  void _go(int index) {
    final target = index.clamp(0, _pages.length - 1);
    if (widget.index != null) {
      widget.onIndexChanged?.call(target);
      return;
    }
    setState(() => _index = target);
    widget.onIndexChanged?.call(target);
    _focusTitle();
  }

  // Keyboard and screen-reader focus follow each page change.
  void _focusTitle() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _titleFocus.requestFocus();
    });
  }

  void _next() => _isLast ? widget.onFinish() : _go(_current + 1);

  void _selectLanguage(OnboardingLanguagePage page, Locale locale) {
    _go(_current + 1);
    page.onSelected(locale);
  }

  void _selectTheme(OnboardingThemePage page, ThemeMode mode) {
    _go(_current + 1);
    page.onSelected(mode);
  }

  bool get _isChoice =>
      _page is OnboardingLanguagePage || _page is OnboardingThemePage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final look = OnboardingThemeData.of(context);
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < look.narrowWidth!;
    final pad = (size.width * 0.04).clamp(32.0, 56.0);
    final preview = _page.preview;

    final pane = Padding(
      padding: EdgeInsets.fromLTRB(pad, pad + 32, pad, pad),
      child: _buildPage(context, look, narrow),
    );

    final Widget card;
    if (narrow) {
      card = pane;
    } else {
      card = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 115, child: pane),
          Expanded(
            flex: 100,
            child: ExcludeSemantics(
              child: Container(
                decoration: BoxDecoration(
                  color: look.previewColor,
                  border: BorderDirectional(
                    start: BorderSide(color: scheme.outlineVariant),
                  ),
                ),
                padding: const EdgeInsets.all(48),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AnimatedSwitcher(
                    duration: look.motionDuration!,
                    switchInCurve: look.motionCurve!,
                    child: KeyedSubtree(
                      key: ValueKey(_page.id),
                      child: switch (_page) {
                        final OnboardingLanguagePage page => _LanguageSpecimen(
                          page: page,
                          active: _hoveredOption ?? 0,
                        ),
                        final OnboardingThemePage page => _ThemeSpecimen(
                          page: page,
                          active: _hoveredOption,
                        ),
                        _ => preview?.call(context) ?? const SizedBox.shrink(),
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Semantics(
              scopesRoute: true,
              explicitChildNodes: true,
              child: Container(
                width: math.min(look.maxCardWidth!, size.width - 32),
                height: narrow
                    ? null
                    : math.min(look.maxCardHeight!, size.height - 64),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: look.cardColor,
                  borderRadius: BorderRadius.circular(look.cardRadius!),
                  border: Border.fromBorderSide(look.cardBorder!),
                  boxShadow: look.cardShadows,
                ),
                child: Stack(
                  children: [
                    card,
                    PositionedDirectional(
                      top: pad,
                      start: pad,
                      end: pad,
                      // Many pages on a phone: the bar shrinks to the card.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: _ProgressBar(
                          current: _current,
                          total: _pages.length,
                          label: widget.strings.progress,
                          stepLabel: (i) => widget.strings.goToStep
                              .replaceAll('{step}', '${i + 1}'),
                          onTap: widget.progressNavigation ? _go : null,
                          look: look,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Left pane
  // ---------------------------------------------------------------------------

  Widget _buildPage(
    BuildContext context,
    OnboardingThemeData look,
    bool narrow,
  ) {
    final page = _page;
    final body = switch (page) {
      final OnboardingLanguagePage page => _choiceBody(
        page,
        look,
        [
          for (final option in page.options)
            (
              key: 'onboarding-language-${option.locale.languageCode}',
              label: option.label,
              onTap: () => _selectLanguage(page, option.locale),
            ),
        ],
      ),
      final OnboardingThemePage page => _choiceBody(
        page,
        look,
        [
          for (final option in page.options)
            (
              key: 'onboarding-theme-${option.mode.name}',
              label: option.label,
              onTap: () => _selectTheme(page, option.mode),
            ),
        ],
      ),
      _ => _textBody(context, page, look),
    };
    final back = page.showBack && _current > 0
        ? TextButton(
            key: const Key('onboarding-back'),
            onPressed: () => _go(_current - 1),
            child: Text(widget.strings.back),
          )
        : null;
    final actions = _isChoice || (back == null && !page.showPrimary)
        ? null
        : _Actions(
            back: back,
            skip: page.showSkip && page.showPrimary && !_isLast
                ? TextButton(
                    key: const Key('onboarding-skip'),
                    onPressed: () => _go(_pages.length - 1),
                    style: TextButton.styleFrom(
                      foregroundColor: look.skipStyle!.color,
                      textStyle: look.skipStyle,
                    ),
                    child: Text(
                      widget.strings.skip,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                  )
                : null,
            primary: page.showPrimary
                ? _primaryButton(
                    page.primaryLabel ??
                        (_isLast ? widget.strings.finish : widget.strings.next),
                    arrow: page.primaryArrow ?? !_isLast,
                  )
                : null,
          );

    final switcher = AnimatedSwitcher(
      duration: look.motionDuration!,
      switchInCurve: look.motionCurve!,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.topStart,
        children: [...previous, ?current],
      ),
      child: KeyedSubtree(key: ValueKey(page.id), child: body),
    );

    // Narrow layouts scroll with an unbounded height, so the body sizes itself
    // there instead of filling the fixed-height card.
    return Column(
      mainAxisSize: narrow ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (narrow) switcher else Expanded(child: switcher),
        ?actions,
      ],
    );
  }

  Widget _title(String text, OnboardingThemeData look) {
    return Focus(
      focusNode: _titleFocus,
      child: Semantics(
        header: true,
        child: Text(text, style: look.titleStyle),
      ),
    );
  }

  /// The title, with the page's icon badge before it on the same line.
  Widget _heading(OnboardingPage page, OnboardingThemeData look) {
    final title = _title(page.title!, look);
    final leading = page.leading;
    if (leading == null) return title;
    return Row(
      children: [
        leading,
        const SizedBox(width: 16),
        Flexible(child: title),
      ],
    );
  }

  Widget _description(String text, OnboardingThemeData look, {int? lines}) {
    final style = look.descriptionStyle!;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: lines != null ? 416 : 480,
        minHeight: lines != null
            ? lines * (style.fontSize ?? 16) * (style.height ?? 1.55)
            : 0,
      ),
      child: Text(text, style: style),
    );
  }

  Widget _textBody(
    BuildContext context,
    OnboardingPage page,
    OnboardingThemeData look,
  ) {
    final content = Column(
      mainAxisAlignment: page.centered
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      mainAxisSize: page.scrollable ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (page.eyebrow != null) ...[
          Text(page.eyebrow!.toUpperCase(), style: look.eyebrowStyle),
          const SizedBox(height: 16),
        ],
        if (page.title != null)
          _heading(page, look)
        else if (page.leading != null) ...[
          page.leading!,
          const SizedBox(height: 16),
        ],
        if (page.description != null) ...[
          const SizedBox(height: 16),
          _description(page.description!, look, lines: page.descriptionLines),
        ],
        if (page.note != null) ...[
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Text(
              page.note!,
              style: look.descriptionStyle!.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
        if (page.body != null) ...[const SizedBox(height: 24), page.body!],
      ],
    );
    if (!page.scrollable) return content;
    // The card has a fixed height on wide layouts, so a growing page scrolls
    // inside it. Narrow layouts are unbounded and scroll as a whole.
    return LayoutBuilder(
      builder: (context, constraints) => constraints.hasBoundedHeight
          ? SingleChildScrollView(child: content)
          : content,
    );
  }

  /// Language and theme pages: heading, then one button per option.
  Widget _choiceBody(
    OnboardingPage page,
    OnboardingThemeData look,
    List<({String key, String label, VoidCallback onTap})> options,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(page, look),
        if (page.description != null) ...[
          const SizedBox(height: 16),
          _description(page.description!, look),
        ],
        const SizedBox(height: 24),
        for (final (i, option) in options.indexed) ...[
          if (i > 0) const SizedBox(height: 8),
          MouseRegion(
            onEnter: (_) => setState(() => _hoveredOption = i),
            onExit: (_) => setState(() => _hoveredOption = null),
            child: _ChoiceButton(
              key: Key(option.key),
              label: option.label,
              radius: look.buttonRadius!,
              style: look.descriptionStyle!,
              onTap: option.onTap,
              onFocusChange: (focused) =>
                  setState(() => _hoveredOption = focused ? i : null),
            ),
          ),
        ],
      ],
    );
  }

  Widget _primaryButton(String label, {required bool arrow}) {
    return FilledButton(
      key: Key(_isLast ? 'onboarding-finish' : 'onboarding-primary'),
      onPressed: _next,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (arrow) ...[
            const SizedBox(width: 8),
            const Icon(ShipglowsIcons.forward, size: 18),
          ],
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Building blocks
// -----------------------------------------------------------------------------

class _Actions extends StatelessWidget {
  const _Actions({this.back, this.skip, this.primary});

  final Widget? back;
  final Widget? skip;
  final Widget? primary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: skip == null
          // Without a skip action the primary label can wrap at large text
          // scales instead of overflowing the row.
          ? Row(
              mainAxisAlignment: back == null
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.spaceBetween,
              children: [?back, if (primary != null) Flexible(child: primary!)],
            )
          : Row(
              children: [
                ?back,
                // Skip sits quietly just before the primary action, right-aligned.
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: skip,
                  ),
                ),
                const SizedBox(width: 12),
                ?primary,
              ],
            ),
    );
  }
}

/// Segmented progress: one bar per page; done pages can be revisited.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.current,
    required this.total,
    required this.label,
    required this.stepLabel,
    required this.onTap,
    required this.look,
  });

  final int current;
  final int total;
  final String label;
  final String Function(int index) stepLabel;

  /// Null keeps the done segments still.
  final ValueChanged<int>? onTap;
  final OnboardingThemeData look;

  @override
  Widget build(BuildContext context) {
    final duration = look.motionDuration!;
    final curve = look.motionCurve!;
    final gradient = look.progressGradient;
    final accent = Theme.of(context).colorScheme.primary;
    bool revisitable(int i) => onTap != null && i < current;
    // Each bar is drawn twice: a neutral track that owns taps and semantics,
    // and a fill layer, recolored by one gradient spanning the whole row when
    // the theme gives one. Fills are sized in pixels so they stay visible at
    // any zoom.
    Widget segment(int i, {required bool fill}) {
      final width = i == current ? 36.0 : 28.0;
      final radius = BorderRadius.circular(999);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
        child: AnimatedContainer(
          duration: duration,
          curve: curve,
          width: width,
          height: 3,
          alignment: AlignmentDirectional.centerStart,
          decoration: BoxDecoration(
            color: fill ? Colors.transparent : look.progressTrackColor,
            borderRadius: radius,
          ),
          child: fill
              ? AnimatedContainer(
                  duration: duration,
                  curve: curve,
                  width: i <= current ? width : 0,
                  height: 3,
                  decoration: BoxDecoration(
                    color: gradient != null ? Colors.white : accent,
                    borderRadius: radius,
                  ),
                )
              : null,
        ),
      );
    }

    final fills = Row(
      children: [for (var i = 0; i < total; i++) segment(i, fill: true)],
    );
    return Semantics(
      label: label,
      container: true,
      child: Stack(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < total; i++)
                Semantics(
                  button: revisitable(i),
                  selected: i == current,
                  label: stepLabel(i),
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: revisitable(i) ? () => onTap!(i) : null,
                    child: MouseRegion(
                      cursor: revisitable(i)
                          ? SystemMouseCursors.click
                          : MouseCursor.defer,
                      child: segment(i, fill: false),
                    ),
                  ),
                ),
            ],
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: gradient == null
                    ? fills
                    : ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: gradient.createShader,
                        child: fills,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    super.key,
    required this.label,
    required this.radius,
    required this.style,
    required this.onTap,
    this.onFocusChange,
  });

  final String label;
  final double radius;
  final TextStyle style;
  final VoidCallback onTap;
  final ValueChanged<bool>? onFocusChange;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        onFocusChange: onFocusChange,
        style: OutlinedButton.styleFrom(
          alignment: AlignmentDirectional.centerStart,
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: style.copyWith(
            height: 1.2,
            fontWeight: FontWeight.w500,
            color: scheme.onSurface,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

/// The greetings of every language, the hovered or focused one inked.
class _LanguageSpecimen extends StatelessWidget {
  const _LanguageSpecimen({required this.page, required this.active});

  final OnboardingLanguagePage page;
  final int active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = OnboardingThemeData.of(context).specimenStyle!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, option) in page.options.indexed)
          Text(
            option.greeting,
            style: style.copyWith(
              color: i == active
                  ? scheme.onSurface
                  : scheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
      ],
    );
  }
}

/// One small window per theme, the hovered or focused one inked.
class _ThemeSpecimen extends StatelessWidget {
  const _ThemeSpecimen({required this.page, required this.active});

  final OnboardingThemePage page;
  final int? active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final look = OnboardingThemeData.of(context);
    final label = look.descriptionStyle!.copyWith(fontSize: 14);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, option) in page.options.indexed) ...[
          if (i > 0) const SizedBox(width: 20),
          AnimatedOpacity(
            duration: look.motionDuration!,
            opacity: i == (active ?? 0) ? 1 : 0.45,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MiniWindow(
                  mode: option.mode,
                  accent: scheme.primary,
                  selected: i == (active ?? 0),
                ),
                const SizedBox(height: 12),
                Text(option.label, style: label),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// A window drawn in light or dark ink; system splits it on the diagonal.
class _MiniWindow extends StatelessWidget {
  const _MiniWindow({
    required this.mode,
    required this.accent,
    required this.selected,
  });

  final ThemeMode mode;
  final Color accent;
  final bool selected;

  static const _light = (
    background: Color(0xFFFAFAF7),
    line: Color(0xFFDADAD4),
    ink: Color(0xFF2B2B2B),
  );
  static const _dark = (
    background: Color(0xFF1C1C1E),
    line: Color(0xFF3A3A3C),
    ink: Color(0xFFE5E5E5),
  );

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    Widget window(bool dark) {
      final ink = dark ? _dark : _light;
      return Container(
        color: ink.background,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  _Bar(color: ink.line, width: 6, height: 6),
                ],
              ],
            ),
            const SizedBox(height: 14),
            _Bar(color: ink.ink, width: 56, height: 6),
            const SizedBox(height: 8),
            _Bar(color: ink.line, width: 88, height: 5),
            const SizedBox(height: 6),
            _Bar(color: ink.line, width: 72, height: 5),
            const Spacer(),
            _Bar(color: accent, width: 36, height: 10),
          ],
        ),
      );
    }

    return Container(
      width: 132,
      height: 100,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: selected ? accent : _light.line,
          width: selected ? 2 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: switch (mode) {
          ThemeMode.light => window(false),
          ThemeMode.dark => window(true),
          ThemeMode.system => Stack(
            fit: StackFit.expand,
            children: [
              window(false),
              ClipPath(clipper: const _DiagonalClipper(), child: window(true)),
            ],
          ),
        },
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.color, required this.width, required this.height});

  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

/// Lower-right half of the box.
class _DiagonalClipper extends CustomClipper<Path> {
  const _DiagonalClipper();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(size.width, 0)
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
