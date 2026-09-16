/*
 *
 *  * Copyright (c) 2024 Mindful (https://github.com/akaMrNagar/Mindful)
 *  * Author : Pawan Nagar (https://github.com/akaMrNagar)
 *  *
 *  * This source code is licensed under the GPL-2.0 license license found in the
 *  * LICENSE file in the root directory of this source tree.
 *
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

@immutable
class ContextMenuAction {
  const ContextMenuAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
}

/// Wraps a card with the productivity long-press behaviour: a long press
/// lifts the card and opens a context menu; moving the finger turns the
/// gesture into a drag (when [dragData] is set) and hides the menu.
class ContextMenuCard<T extends Object> extends StatefulWidget {
  const ContextMenuCard({
    super.key,
    required this.child,
    required this.preview,
    required this.actions,
    this.dragData,
    this.onAccept,
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
  });

  /// The interactive card.
  final Widget child;

  /// A non-interactive copy of the card, used while lifted.
  final Widget preview;
  final List<ContextMenuAction> actions;

  /// Enables drag and drop when not null.
  final T? dragData;

  /// Called when another card is dropped on this one.
  final ValueChanged<T>? onAccept;
  final BorderRadius borderRadius;

  @override
  State<ContextMenuCard<T>> createState() => _ContextMenuCardState<T>();
}

class _ContextMenuCardState<T extends Object>
    extends State<ContextMenuCard<T>> {
  /// Finger travel after which a long press counts as a drag.
  static const _dragSlop = 12.0;

  OverlayEntry? _menuEntry;
  Offset? _dragOrigin;

  bool get _isMenuOpen => _menuEntry != null;

  @override
  void dispose() {
    _removeMenuEntry();
    super.dispose();
  }

  void _showMenu() {
    _removeMenuEntry();
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final anchor = box.localToGlobal(Offset.zero) & box.size;

    _menuEntry = OverlayEntry(
      builder: (_) => _ContextMenuOverlay(
        anchor: anchor,
        preview: widget.preview,
        onDismiss: _hideMenu,
        actions: [
          for (final action in widget.actions)
            ContextMenuAction(
              icon: action.icon,
              label: action.label,
              isDestructive: action.isDestructive,
              onTap: () {
                _hideMenu();
                action.onTap();
              },
            ),
        ],
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_menuEntry!);
    setState(() {});
  }

  void _removeMenuEntry() {
    _menuEntry?.remove();
    _menuEntry = null;
  }

  void _hideMenu() {
    if (!_isMenuOpen) return;
    _removeMenuEntry();
    if (mounted) setState(() {});
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final origin = _dragOrigin ??= details.globalPosition;
    if (_isMenuOpen && (details.globalPosition - origin).distance > _dragSlop) {
      _hideMenu();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dragData = widget.dragData;
    final content = dragData == null
        ? GestureDetector(
            onLongPress: () {
              HapticFeedback.mediumImpact();
              _showMenu();
            },
            child: widget.child,
          )
        : _buildDraggable(dragData);

    return PopScope(
      // Back closes the menu before leaving the screen
      canPop: !_isMenuOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _hideMenu();
      },
      // The menu draws its own copy of the card on top; hide this one so the
      // copy's blur does not ghost it
      child: Opacity(opacity: _isMenuOpen ? 0 : 1, child: content),
    );
  }

  Widget _buildDraggable(T dragData) => LayoutBuilder(
        builder: (context, constraints) => DragTarget<T>(
          onWillAcceptWithDetails: (details) => details.data != dragData,
          onAcceptWithDetails: (details) => widget.onAccept?.call(details.data),
          builder: (context, candidates, _) => LongPressDraggable<T>(
            data: dragData,
            hapticFeedbackOnStart: true,
            onDragStarted: () {
              _dragOrigin = null;
              _showMenu();
            },
            onDragUpdate: _onDragUpdate,
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: constraints.maxWidth,
                child: Transform.scale(scale: 1.04, child: widget.preview),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.25, child: widget.child),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                borderRadius: widget.borderRadius,
                border: Border.all(
                  width: 2,
                  color: candidates.isNotEmpty
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                ),
              ),
              child: widget.child,
            ),
          ),
        ),
      );
}

/// Menu shown over a dimmed screen, with the pressed card kept sharp in place
/// and the actions right below it (or above when space is short).
class _ContextMenuOverlay extends StatelessWidget {
  const _ContextMenuOverlay({
    required this.anchor,
    required this.preview,
    required this.actions,
    required this.onDismiss,
  });

  static const _menuWidth = 230.0;
  static const _actionHeight = 52.0;
  static const _gap = 8.0;
  static const _screenMargin = 16.0;

  final Rect anchor;
  final Widget preview;
  final List<ContextMenuAction> actions;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final screen = media.size;
    final menuHeight = actions.length * _actionHeight + 12;

    final left = anchor.left
        .clamp(_screenMargin, screen.width - _menuWidth - _screenMargin)
        .toDouble();
    final fitsBelow = anchor.bottom + _gap + menuHeight <=
        screen.height - media.padding.bottom - _screenMargin;
    final top = fitsBelow
        ? anchor.bottom + _gap
        : (anchor.top - _gap - menuHeight)
            .clamp(media.padding.top + _screenMargin, double.infinity)
            .toDouble();

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.35))
                .animate()
                .fadeIn(duration: 120.ms),
          ),
        ),
        Positioned.fromRect(
          rect: anchor,
          child: IgnorePointer(child: preview),
        ),
        Positioned(
          left: left,
          top: top,
          width: _menuWidth,
          child: Material(
            color: colors.surfaceContainerHigh,
            elevation: 8,
            shadowColor: Colors.black54,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final action in actions)
                    _MenuActionTile(action: action, height: _actionHeight),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 120.ms).scale(
                begin: const Offset(0.92, 0.92),
                alignment: fitsBelow ? Alignment.topLeft : Alignment.bottomLeft,
                duration: 160.ms,
                curve: Curves.easeOutCubic,
              ),
        ),
      ],
    );
  }
}

class _MenuActionTile extends StatelessWidget {
  const _MenuActionTile({required this.action, required this.height});

  final ContextMenuAction action;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color =
        action.isDestructive ? Theme.of(context).colorScheme.error : null;
    return InkWell(
      onTap: action.onTap,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Icon(action.icon, size: 22, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  action.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
