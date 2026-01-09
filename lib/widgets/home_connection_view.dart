import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/server_node.dart';
import '../utils/node_utils.dart';
import 'connection_button.dart' show ConnectionButtonStatus;

/// 主页连接视图 - 中心区域
class HomeConnectionView extends StatefulWidget {
  final ConnectionButtonStatus status;
  final VoidCallback? onConnectTap;
  final bool isLoading;
  final ServerNode? selectedNode;

  const HomeConnectionView({
    super.key,
    required this.status,
    required this.onConnectTap,
    this.isLoading = false,
    this.selectedNode,
  });

  @override
  State<HomeConnectionView> createState() => _HomeConnectionViewState();
}

class _HomeConnectionViewState extends State<HomeConnectionView>
    with TickerProviderStateMixin {
  double _buttonScale = 1.0;
  late AnimationController _loopController;

  @override
  void initState() {
    super.initState();
    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.status == ConnectionButtonStatus.connecting || widget.isLoading) {
      _loopController.repeat();
    }
  }

  @override
  void didUpdateWidget(HomeConnectionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasBusy = oldWidget.isLoading ||
        oldWidget.status == ConnectionButtonStatus.connecting;
    final isBusy =
        widget.isLoading || widget.status == ConnectionButtonStatus.connecting;
    if (wasBusy != isBusy) {
      if (isBusy) {
        _loopController.repeat();
      } else {
        _loopController.stop();
        _loopController.reset();
      }
    }
  }

  @override
  void dispose() {
    _loopController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _buttonScale = 0.96);
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _buttonScale = 1.0);
  }

  void _handleTapCancel() {
    setState(() => _buttonScale = 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final isBusy =
        widget.isLoading || widget.status == ConnectionButtonStatus.connecting;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final style = widget.isLoading &&
            widget.status == ConnectionButtonStatus.disconnected
        ? const _StatusStyle(
            accent: Color(0xFFB8C0CC),
            action: '同步中',
          )
        : _statusStyle(widget.status);
    if (reduceMotion && _loopController.isAnimating) {
      _loopController.stop();
    } else if (!reduceMotion &&
        (widget.isLoading ||
            widget.status == ConnectionButtonStatus.connecting) &&
        !_loopController.isAnimating) {
      _loopController.repeat();
    }
    final buttonDuration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 220);
    final textDuration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 180);
    return LayoutBuilder(
      builder: (context, constraints) {
        final buttonWidth =
            (constraints.maxWidth * 0.68).clamp(220.0, 320.0);
        final indicatorTarget =
            widget.status == ConnectionButtonStatus.connecting ? 1.0 : 0.0;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: _getStatusText(widget.status),
              button: true,
              enabled: true,
              child: GestureDetector(
                onTapDown: _handleTapDown,
                onTapUp: _handleTapUp,
                onTapCancel: _handleTapCancel,
                onTap: widget.onConnectTap,
                child: AnimatedScale(
                  scale: _buttonScale,
                  duration: buttonDuration,
                  curve: Curves.easeOutCubic,
                  child: RepaintBoundary(
                    child: AnimatedContainer(
                      duration: buttonDuration,
                      curve: Curves.easeOutCubic,
                      width: buttonWidth,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: _surfaceColor(widget.status),
                        border: Border.all(
                          color: style.accent.withValues(alpha: isBusy ? 0.25 : 0.45),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 18,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (isBusy && !reduceMotion)
                            _buildBusyEffects(style, buttonWidth),
                          Positioned(
                            bottom: 12,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(end: indicatorTarget),
                              duration: reduceMotion
                                  ? Duration.zero
                                  : const Duration(milliseconds: 420),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) {
                                return Container(
                                  width: (buttonWidth - 80) * value,
                                  height: 1.2,
                                  decoration: BoxDecoration(
                                    color: style.accent.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                );
                              },
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedSwitcher(
                                duration: textDuration,
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(
                                  opacity: animation,
                                  child: ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  ),
                                ),
                                child:
                                    _buildIndicator(style, isBusy, reduceMotion),
                              ),
                              const SizedBox(width: 14),
                              AnimatedSwitcher(
                                duration: textDuration,
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.2),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                ),
                                child: Text(
                                  style.action,
                                  key: ValueKey(style.action),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.8,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: AnimatedOpacity(
                duration: textDuration,
                opacity: widget.selectedNode != null ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: widget.selectedNode == null,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: widget.selectedNode != null
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0B0F16),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.public,
                                  size: 16,
                                  color: Color(0xFFCDD2DB),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  NodeUtils.extractCountry(
                                      widget.selectedNode!.name),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFD7DCE5),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                if (widget.selectedNode!.latency != null) ...[
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A212E),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${widget.selectedNode!.latency}ms',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: _latencyColor(
                                            widget.selectedNode!.latency!),
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _getStatusText(ConnectionButtonStatus status) {
    switch (status) {
      case ConnectionButtonStatus.connected:
        return '已连接';
      case ConnectionButtonStatus.connecting:
        return '连接中...';
      case ConnectionButtonStatus.error:
        return '连接失败';
      default:
        return '点击连接';
    }
  }

  _StatusStyle _statusStyle(ConnectionButtonStatus status) {
    switch (status) {
      case ConnectionButtonStatus.connected:
        return const _StatusStyle(
          accent: Color(0xFFB7C1CD),
          action: '断开连接',
        );
      case ConnectionButtonStatus.connecting:
        return const _StatusStyle(
          accent: Color(0xFF8FA3BF),
          action: '连接中',
        );
      case ConnectionButtonStatus.error:
        return const _StatusStyle(
          accent: Color(0xFFC19A9A),
          action: '重试',
        );
      default:
        return const _StatusStyle(
          accent: Color(0xFFAEB6C4),
          action: '连接',
        );
    }
  }

  Color _latencyColor(int latency) {
    if (latency < 100) return const Color(0xFF9FD1FF);
    if (latency < 300) return const Color(0xFFC9B77D);
    return const Color(0xFFC18C8C);
  }

  Widget _buildIndicator(
      _StatusStyle style, bool isBusy, bool reduceMotion) {
    final showCheck = widget.status == ConnectionButtonStatus.connected;
    final base = AnimatedContainer(
      key: ValueKey(showCheck),
      duration: const Duration(milliseconds: 180),
      width: showCheck ? 18 : 12,
      height: showCheck ? 18 : 12,
      decoration: BoxDecoration(
        color: style.accent,
        borderRadius: BorderRadius.circular(showCheck ? 6 : 999),
      ),
      child: showCheck
          ? const Icon(
              Icons.check_rounded,
              size: 14,
              color: Colors.black,
            )
          : null,
    );
    if (!isBusy || reduceMotion) {
      return base;
    }
    return AnimatedBuilder(
      animation: _loopController,
      builder: (context, child) {
        final pulse =
            0.94 + 0.06 * math.sin(_loopController.value * math.pi * 2);
        return Transform.scale(
          scale: pulse,
          child: child,
        );
      },
      child: base,
    );
  }

  Widget _buildBusyEffects(_StatusStyle style, double buttonWidth) {
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AnimatedBuilder(
          animation: _loopController,
          builder: (context, child) {
            final t = _loopController.value;
            final sweepOffset = (t * 2 - 1) * buttonWidth;
            final glow = 0.03 + 0.02 * math.sin(t * math.pi * 2);
            return Stack(
              children: [
                Opacity(
                  opacity: glow,
                  child: Container(
                    decoration: BoxDecoration(
                      color: style.accent,
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(sweepOffset, 0),
                  child: Container(
                    width: 90,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.transparent,
                          style.accent.withValues(alpha: 0.12),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Color _surfaceColor(ConnectionButtonStatus status) {
    switch (status) {
      case ConnectionButtonStatus.connected:
        return const Color(0xFF0C1016);
      case ConnectionButtonStatus.connecting:
        return const Color(0xFF0D1118);
      case ConnectionButtonStatus.error:
        return const Color(0xFF151015);
      default:
        return const Color(0xFF0E1320);
    }
  }

}

class _StatusStyle {
  final Color accent;
  final String action;

  const _StatusStyle({
    required this.accent,
    required this.action,
  });
}
