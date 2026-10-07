import 'package:flutter/material.dart';

class OneShotMarquee extends StatefulWidget {
  const OneShotMarquee(this.text, {super.key, this.style, this.animate = true});
  final String text;
  final TextStyle? style;
  final bool animate;

  @override
  State<OneShotMarquee> createState() => _OneShotMarqueeState();
}

class _OneShotMarqueeState extends State<OneShotMarquee>
    with SingleTickerProviderStateMixin {
  late final motion = AnimationController(vsync: this);
  Object? signature;
  static final path = TweenSequence<double>([
    TweenSequenceItem(tween: ConstantTween(0), weight: 10),
    TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 55),
    TweenSequenceItem(tween: ConstantTween(1), weight: 10),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 0.0,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 25,
    ),
  ]);

  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final animate = widget.animate && !MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          textDirection: direction,
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        final width = constraints.maxWidth;
        final distance = (painter.width - width).clamp(0.0, double.infinity);
        final next = (widget.text, style, direction, scaler, width, animate);
        if (next != signature) {
          signature = next;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || signature != next) return;
            motion.reset();
            if (animate && distance > 0) {
              motion.duration = Duration(
                milliseconds: (distance * 28 + 1600).clamp(2400, 7000).round(),
              );
              motion.forward();
            }
          });
        }
        final height = painter.height;
        final textWidth = painter.width;
        painter.dispose();
        return Semantics(
          label: widget.text,
          child: ExcludeSemantics(
            child: SizedBox(
              height: height,
              child: AnimatedBuilder(
                animation: motion,
                builder: (context, _) {
                  final offset = distance * path.transform(motion.value);
                  final rtl = direction == TextDirection.rtl;
                  final text = ClipRect(
                    child: OverflowBox(
                      minWidth: 0,
                      maxWidth: double.infinity,
                      alignment: AlignmentDirectional.centerStart,
                      child: Transform.translate(
                        offset: Offset(rtl ? offset : -offset, 0),
                        child: SizedBox(
                          width: textWidth,
                          child: Text(
                            widget.text,
                            style: style,
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ),
                      ),
                    ),
                  );
                  if (distance <= 0) return text;
                  return ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (bounds) => LinearGradient(
                      begin: rtl ? Alignment.centerRight : Alignment.centerLeft,
                      end: rtl ? Alignment.centerLeft : Alignment.centerRight,
                      colors: [
                        offset > 0 ? Colors.transparent : Colors.white,
                        Colors.white,
                        Colors.white,
                        offset < distance ? Colors.transparent : Colors.white,
                      ],
                      stops: const [0, .12, .82, 1],
                    ).createShader(bounds),
                    child: text,
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
