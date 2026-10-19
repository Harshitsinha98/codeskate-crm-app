import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Codeskate premium UI kit — motion-first primitives inspired by Framer
/// Motion / 21st.dev patterns: spring press, staggered reveal, aurora glow,
/// glass surfaces, animated numbers.
/// ─────────────────────────────────────────────────────────────────────────

extension StaggerX on Widget {
  /// Framer-style staggered entrance (fade + rise + subtle blur-free scale).
  Widget stagger(int index, {int stepMs = 45, int maxSteps = 12}) => animate(
        delay: Duration(milliseconds: stepMs * math.min(index, maxSteps)),
      )
          .fadeIn(duration: 380.ms, curve: Curves.easeOutCubic)
          .slideY(begin: 0.12, end: 0, duration: 420.ms, curve: Curves.easeOutCubic)
          .scaleXY(begin: 0.985, end: 1, duration: 420.ms, curve: Curves.easeOutCubic);
}

/// Animated aurora: slow drifting ember/orange glows. Use on dark (midnight)
/// heroes or as a soft warm glow on cream.
class AuroraBackground extends StatefulWidget {
  final Widget? child;
  final bool dark;
  final double intensity;
  final BorderRadius? borderRadius;

  const AuroraBackground({
    super.key,
    this.child,
    this.dark = true,
    this.intensity = 1,
    this.borderRadius,
  });

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.dark ? AppColors.midnight900 : AppColors.cream100;
    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(child: ColoredBox(color: base)),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(
                painter: _AuroraPainter(t: _c.value, dark: widget.dark, intensity: widget.intensity),
              ),
            ),
          ),
          if (widget.dark)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, AppColors.midnight950.withValues(alpha: 0.35)],
                    ),
                  ),
                ),
              ),
            ),
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double t;
  final bool dark;
  final double intensity;
  _AuroraPainter({required this.t, required this.dark, required this.intensity});

  void _blob(Canvas canvas, Size size, Offset center, double radius, Color color) {
    final paint = Paint()
      ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)]).createShader(
        Rect.fromCircle(center: center, radius: radius),
      );
    canvas.drawCircle(center, radius, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final a = t * 2 * math.pi;
    final w = size.width, h = size.height;
    final k = intensity;
    final o1 = dark ? 0.42 : 0.30;
    final o2 = dark ? 0.30 : 0.22;
    _blob(canvas, size, Offset(w * (0.18 + 0.08 * math.sin(a)), h * (0.15 + 0.10 * math.cos(a))), w * 0.62,
        AppColors.orange500.withValues(alpha: o1 * k));
    _blob(canvas, size, Offset(w * (0.88 + 0.06 * math.cos(a * 1.3)), h * (0.35 + 0.12 * math.sin(a * 0.8))), w * 0.55,
        AppColors.ember500.withValues(alpha: o2 * k));
    _blob(canvas, size, Offset(w * (0.55 + 0.12 * math.sin(a * 0.7)), h * (1.0 + 0.05 * math.cos(a))), w * 0.50,
        AppColors.orange300.withValues(alpha: (dark ? 0.18 : 0.20) * k));
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.t != t;
}

/// Spring-press wrapper with haptic tick (the "whileTap" of Framer Motion).
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptic;

  const Pressable({super.key, required this.child, this.onTap, this.onLongPress, this.scale = 0.965, this.haptic = true});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: Duration(milliseconds: _down ? 90 : 260),
        curve: _down ? Curves.easeOut : Curves.elasticOut,
        child: widget.child,
      ),
    );
  }
}

enum GlowVariant { primary, dark, ghost, whatsapp, danger }

/// Primary call-to-action: gradient, glow, spring press, loading state.
class GlowButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final GlowVariant variant;
  final bool expand;
  final double height;

  const GlowButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.variant = GlowVariant.primary,
    this.expand = true,
    this.height = 54,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;
    Gradient? gradient;
    Color? solid;
    Color fg = Colors.white;
    List<BoxShadow>? shadow;
    Border? border;
    switch (variant) {
      case GlowVariant.primary:
        gradient = AppColors.primaryGradient;
        shadow = disabled ? null : AppColors.glow();
        break;
      case GlowVariant.dark:
        solid = AppColors.midnight900;
        shadow = disabled ? null : AppColors.glow(AppColors.midnight900, 0.25);
        break;
      case GlowVariant.whatsapp:
        gradient = const LinearGradient(colors: [Color(0xFF2BE07A), AppColors.whatsappDark]);
        shadow = disabled ? null : AppColors.glow(AppColors.whatsapp, 0.3);
        break;
      case GlowVariant.danger:
        solid = AppColors.error;
        break;
      case GlowVariant.ghost:
        solid = AppColors.surface;
        fg = AppColors.textPrimary;
        border = Border.all(color: AppColors.border);
        break;
    }
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
        else ...[
          if (icon != null) ...[Icon(icon, size: 19, color: fg), const SizedBox(width: 8)],
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(size: 15, weight: FontWeight.w700, color: fg)),
          ),
        ],
      ],
    );
    return Pressable(
      onTap: disabled ? null : onPressed,
      child: AnimatedOpacity(
        duration: 200.ms,
        opacity: disabled && !loading ? 0.5 : 1,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            gradient: gradient,
            color: solid,
            borderRadius: BorderRadius.circular(height / 2.6),
            boxShadow: shadow,
            border: border,
          ),
          child: content,
        ),
      ),
    );
  }
}

/// White card with hairline border and warm layered shadow.
class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final Color? color;
  final double radius;
  final Color? borderColor;

  const PremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.gradient,
    this.color,
    this.radius = 22,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final box = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? AppColors.surface) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? AppColors.border.withValues(alpha: 0.8)),
        boxShadow: AppColors.cardShadow,
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Pressable(onTap: onTap, scale: 0.98, child: box);
  }
}

/// Frosted glass panel — for content sitting on aurora / midnight heroes.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double opacity;

  const GlassPanel({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.radius = 20, this.opacity = 0.08});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Number that counts up when it appears or changes.
class AnimatedCount extends StatelessWidget {
  final num value;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final int decimals;
  final Duration duration;

  const AnimatedCount({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.decimals = 0,
    this.duration = const Duration(milliseconds: 900),
  });

  static String compact(num v, {int decimals = 0}) {
    if (v.abs() >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v.abs() >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v.abs() >= 10000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(decimals);
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutExpo,
      builder: (context, v, _) => Text(
        '$prefix${compact(v, decimals: decimals)}$suffix',
        style: style ?? AppText.display(size: 26),
      ),
    );
  }
}

/// Rounded tinted icon tile.
class IconBubble extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final bool gradient;

  const IconBubble({super.key, required this.icon, this.color = AppColors.primary, this.size = 40, this.gradient = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient ? LinearGradient(colors: [color.withValues(alpha: 0.95), Color.lerp(color, Colors.black, 0.18)!]) : null,
        color: gradient ? null : color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: gradient ? AppColors.glow(color, 0.28) : null,
      ),
      child: Icon(icon, size: size * 0.5, color: gradient ? Colors.white : color),
    );
  }
}

/// Initials avatar with a deterministic warm gradient.
class GradientAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Widget? badge;

  const GradientAvatar({super.key, required this.name, this.size = 44, this.badge});

  static const _palettes = [
    [AppColors.orange400, AppColors.orange600],
    [AppColors.ember400, AppColors.ember600],
    [Color(0xFFFFAC70), AppColors.ember500],
    [Color(0xFF6F665E), AppColors.midnight800],
    [Color(0xFFF59E0B), AppColors.orange600],
  ];

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts[0].characters.first + parts[1].characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final p = _palettes[name.hashCode.abs() % _palettes.length];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: p, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(size * 0.36),
          ),
          child: Text(initials, style: AppText.display(size: size * 0.36, color: Colors.white, weight: FontWeight.w700, letterSpacing: 0)),
        ),
        if (badge != null) Positioned(right: -2, bottom: -2, child: badge!),
      ],
    );
  }
}

/// Small tinted pill.
class Pill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool solid;

  const Pill({super.key, required this.label, this.color = AppColors.primary, this.icon, this.solid = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 11.5, color: solid ? Colors.white : color), const SizedBox(width: 4)],
        Text(label, style: AppText.body(size: 11, weight: FontWeight.w700, color: solid ? Colors.white : color, height: 1.1)),
      ]),
    );
  }
}

/// Animated segmented control (sliding pill).
class SegmentTabs<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  final Map<T, int>? counts;
  final bool dark;

  const SegmentTabs({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
    this.counts,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: values.map((v) {
          final active = v == selected;
          final c = counts?[v];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Pressable(
              onTap: () => onChanged(v),
              child: AnimatedContainer(
                duration: 260.ms,
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  gradient: active ? AppColors.primaryGradient : null,
                  color: active ? null : (dark ? Colors.white.withValues(alpha: 0.08) : AppColors.surface),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: active ? Colors.transparent : (dark ? Colors.white12 : AppColors.border)),
                  boxShadow: active ? AppColors.glow(AppColors.orange500, 0.25) : null,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(label(v),
                      style: AppText.body(
                          size: 13,
                          weight: FontWeight.w600,
                          color: active ? Colors.white : (dark ? AppColors.textOnDark : AppColors.textSecondary))),
                  if (c != null && c > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: active ? Colors.white.withValues(alpha: 0.25) : AppColors.orange100,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(c > 99 ? '99+' : '$c',
                          style: AppText.body(size: 10.5, weight: FontWeight.w700, color: active ? Colors.white : AppColors.primaryDark)),
                    ),
                  ],
                ]),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Search input with brand styling.
class SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final bool dark;

  const SearchField({super.key, this.hint = 'Search', required this.onChanged, this.controller, this.dark = false});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: AppText.body(size: 14.5, color: dark ? Colors.white : AppColors.textPrimary),
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppText.body(size: 14, color: dark ? AppColors.textOnDarkMuted : AppColors.textTertiary),
        prefixIcon: Icon(Icons.search_rounded, size: 20, color: dark ? AppColors.textOnDarkMuted : AppColors.textTertiary),
        filled: true,
        fillColor: dark ? Colors.white.withValues(alpha: 0.08) : AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: dark ? Colors.white12 : AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

/// Premium dark app bar for module screens (midnight + aurora glow).
class PremiumAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? bottom;
  final double bottomHeight;
  final bool showBack;

  const PremiumAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.bottom,
    this.bottomHeight = 0,
    this.showBack = true,
  });

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (subtitle != null ? 14 : 0) + bottomHeight);

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: AuroraBackground(
        intensity: 0.8,
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: kToolbarHeight + (subtitle != null ? 14 : 0),
                child: Row(
                  children: [
                    if (showBack && canPop)
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19, color: Colors.white),
                        onPressed: () => Navigator.of(context).maybePop(),
                      )
                    else
                      const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.display(size: 19, color: Colors.white, weight: FontWeight.w700)),
                          if (subtitle != null)
                            Text(subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.body(size: 12, color: AppColors.textOnDarkMuted)),
                        ],
                      ),
                    ),
                    if (actions != null)
                      IconTheme(data: const IconThemeData(color: Colors.white), child: Row(children: actions!)),
                    const SizedBox(width: 6),
                  ],
                ),
              ),
              if (bottom != null) SizedBox(height: bottomHeight, child: bottom),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section title + optional action.
class SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;
  final Widget? trailing;

  const SectionTitle(this.title, {super.key, this.action, this.onAction, this.trailing, this.padding = const EdgeInsets.fromLTRB(20, 22, 20, 10)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(children: [
        Expanded(child: Text(title, style: AppText.display(size: 17, weight: FontWeight.w700, letterSpacing: -0.3))),
        if (trailing != null) trailing!,
        if (action != null)
          Pressable(
            onTap: onAction,
            child: Row(children: [
              Text(action!, style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.primaryDark)),
              const Icon(Icons.arrow_forward_rounded, size: 15, color: AppColors.primaryDark),
            ]),
          ),
      ]),
    );
  }
}

/// Empty state with floating icon.
class PremiumEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const PremiumEmpty({super.key, required this.icon, required this.title, this.message, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 48),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.orange100, AppColors.cream200]),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Icon(icon, size: 34, color: AppColors.primary),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(begin: -4, end: 4, duration: 2200.ms, curve: Curves.easeInOut),
          const SizedBox(height: 18),
          Text(title, textAlign: TextAlign.center, style: AppText.display(size: 18, weight: FontWeight.w700)),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, textAlign: TextAlign.center, style: AppText.body(size: 13.5, color: AppColors.textTertiary)),
          ],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ]),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.06),
    );
  }
}

/// Shimmer skeleton list placeholder.
class SkeletonList extends StatelessWidget {
  final int count;
  final double height;
  final EdgeInsetsGeometry padding;

  const SkeletonList({super.key, this.count = 6, this.height = 74, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: ListView.separated(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => Container(
          height: height,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }
}

/// KPI tile (light) with animated number.
class KpiTile extends StatelessWidget {
  final String label;
  final num value;
  final IconData icon;
  final Color color;
  final String suffix;
  final String? hint;
  final VoidCallback? onTap;

  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.primary,
    this.suffix = '',
    this.hint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconBubble(icon: icon, color: color, size: 34),
          const Spacer(),
          if (onTap != null) const Icon(Icons.north_east_rounded, size: 15, color: AppColors.textTertiary),
        ]),
        const SizedBox(height: 12),
        AnimatedCount(value: value, suffix: suffix, style: AppText.display(size: 24, weight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.textTertiary)),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(hint!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 11, color: color, weight: FontWeight.w600)),
        ],
      ]),
    );
  }
}

/// Brand mark: the orange "skate" glyph used on splash/login.
class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.orange400, AppColors.orange600, AppColors.ember500],
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(color: AppColors.orange500.withValues(alpha: 0.55), blurRadius: size * 0.6, spreadRadius: -size * 0.12, offset: Offset(0, size * 0.15)),
        ],
      ),
      child: CustomPaint(painter: _SkateMarkPainter()),
    );
  }
}

class _SkateMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width * 0.1
      ..strokeCap = StrokeCap.round;
    // Stylised "C" swoosh + deck line.
    final rect = Rect.fromCircle(center: Offset(s.width * 0.52, s.height * 0.46), radius: s.width * 0.22);
    canvas.drawArc(rect, math.pi * 0.25, math.pi * 1.5, false, p);
    final deck = Path()
      ..moveTo(s.width * 0.24, s.height * 0.76)
      ..quadraticBezierTo(s.width * 0.5, s.height * 0.86, s.width * 0.78, s.height * 0.74);
    canvas.drawPath(deck, p..strokeWidth = s.width * 0.075);
    final dot = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(s.width * 0.34, s.height * 0.86), s.width * 0.045, dot);
    canvas.drawCircle(Offset(s.width * 0.68, s.height * 0.86), s.width * 0.045, dot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Feedback helpers ─────────────────────────────────────────────────────

class AppToast {
  AppToast._();

  static void _show(BuildContext context, String msg, IconData icon, Color color) {
    final m = ScaffoldMessenger.maybeOf(context);
    if (m == null) return;
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: const Duration(seconds: 3),
      content: Row(children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
    ));
  }

  static void success(BuildContext c, String msg) {
    HapticFeedback.lightImpact();
    _show(c, msg, Icons.check_rounded, const Color(0xFF34D399));
  }

  static void error(BuildContext c, String msg) {
    HapticFeedback.mediumImpact();
    _show(c, msg, Icons.error_outline_rounded, const Color(0xFFF87171));
  }

  static void info(BuildContext c, String msg) => _show(c, msg, Icons.info_outline_rounded, AppColors.orange300);
}

/// Spring bottom sheet with drag handle and title.
Future<T?> showPremiumSheet<T>(
  BuildContext context, {
  required Widget Function(BuildContext) builder,
  String? title,
  String? subtitle,
  bool scrollable = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.cream50,
    sheetAnimationStyle: const AnimationStyle(duration: Duration(milliseconds: 420), curve: Curves.easeOutCubic),
    builder: (ctx) {
      final body = Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 10),
          Center(
            child: Container(width: 42, height: 5, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(9))),
          ),
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: AppText.display(size: 20, weight: FontWeight.w700)),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle, style: AppText.body(size: 13, color: AppColors.textTertiary)),
                ],
              ]),
            ),
          Flexible(
            child: scrollable
                ? SingleChildScrollView(padding: const EdgeInsets.fromLTRB(22, 12, 22, 24), child: builder(ctx))
                : Padding(padding: const EdgeInsets.fromLTRB(22, 12, 22, 24), child: builder(ctx)),
          ),
        ]),
      );
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.92),
        child: body,
      );
    },
  );
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message, style: AppText.body(size: 14)),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: AppColors.error) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Labeled form field wrapper used inside sheets.
class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7, top: 14),
        child: Text(text.toUpperCase(), style: AppText.body(size: 11, weight: FontWeight.w700, color: AppColors.textTertiary).copyWith(letterSpacing: 0.7)),
      );
}

/// Selectable chip row.
class ChoiceChips<T> extends StatelessWidget {
  final List<T> options;
  final T? selected;
  final String Function(T) label;
  final ValueChanged<T> onSelected;
  final Color Function(T)? colorOf;

  const ChoiceChips({super.key, required this.options, required this.selected, required this.label, required this.onSelected, this.colorOf});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final active = o == selected;
        final c = colorOf?.call(o) ?? AppColors.primary;
        return Pressable(
          onTap: () => onSelected(o),
          child: AnimatedContainer(
            duration: 220.ms,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: active ? c.withValues(alpha: 0.12) : AppColors.surface,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: active ? c : AppColors.border, width: active ? 1.5 : 1),
            ),
            child: Text(label(o), style: AppText.body(size: 13, weight: FontWeight.w600, color: active ? c : AppColors.textSecondary)),
          ),
        );
      }).toList(),
    );
  }
}

/// List row used in hubs / settings.
class PremiumTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool gradientIcon;

  const PremiumTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.color = AppColors.primary,
    this.gradientIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.985,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(children: [
          IconBubble(icon: icon, color: color, size: 38, gradient: gradientIcon),
          const SizedBox(width: 13),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppText.body(size: 14.5, weight: FontWeight.w600, color: AppColors.textPrimary)),
              if (subtitle != null)
                Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.body(size: 12.2, color: AppColors.textTertiary)),
            ]),
          ),
          trailing ?? (onTap != null ? const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary) : const SizedBox.shrink()),
        ]),
      ),
    );
  }
}

/// Horizontal metric bar (label · value · fill).
class MetricBar extends StatelessWidget {
  final String label;
  final num value;
  final num max;
  final Color color;
  final String? trailing;

  const MetricBar({super.key, required this.label, required this.value, required this.max, this.color = AppColors.primary, this.trailing});

  @override
  Widget build(BuildContext context) {
    final f = max <= 0 ? 0.0 : (value / max).clamp(0, 1).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.textPrimary))),
          Text(trailing ?? '$value', style: AppText.mono(size: 12.5)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: Stack(children: [
            Container(height: 7, color: AppColors.surfaceVariant),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: f),
              duration: 900.ms,
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => FractionallySizedBox(
                widthFactor: v,
                child: Container(height: 7, decoration: BoxDecoration(gradient: LinearGradient(colors: [color.withValues(alpha: 0.75), color]))),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
