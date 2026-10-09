import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// One look (Daur's red track, yellow, display numerals), two sets of controls: on iPhone the
/// parts follow Apple's design (action sheets, sliding segments, wheel date picker, chevron back,
/// a floating glass tab bar); on Android, Material's. Screens ask for the part, not the platform.
bool isIOS(BuildContext context) => Theme.of(context).platform == TargetPlatform.iOS;

/// One entry in a ⋯ menu; [onTap] null = shown disabled; [destructive] = red on iPhone.
class MenuItem {
  const MenuItem(this.label, this.onTap, {this.destructive = false});
  final String label;
  final VoidCallback? onTap;
  final bool destructive;
}

/// The ⋯ button. Android: ⋮ with a Material menu. iPhone: an ellipsis circle that opens an
/// action sheet from the bottom, with Cancel.
class MoreButton extends StatelessWidget {
  const MoreButton(this.items, {super.key, this.tooltip = 'More'});
  final List<MenuItem> items;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    if (!isIOS(context)) {
      return PopupMenuButton<int>(
        tooltip: tooltip,
        icon: Icon(Icons.more_vert, color: t.ink),
        onSelected: (i) => items[i].onTap?.call(),
        itemBuilder: (_) => [
          for (final (i, item) in items.indexed)
            PopupMenuItem(value: i, enabled: item.onTap != null, child: Text(item.label)),
        ],
      );
    }
    return IconButton(
      tooltip: tooltip,
      icon: Icon(CupertinoIcons.ellipsis_circle, color: t.ink),
      onPressed: () => showCupertinoModalPopup<void>(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          actions: [
            for (final item in items)
              if (item.onTap != null)
                CupertinoActionSheetAction(
                  isDestructiveAction: item.destructive,
                  onPressed: () {
                    Navigator.pop(ctx);
                    item.onTap!();
                  },
                  child: Text(item.label),
                ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ),
      ),
    );
  }
}

/// A row of choices. Android: Material segmented buttons. iPhone: the sliding segmented control.
/// Both: the chosen one in yellow. [onSheet] = drawn on the cream sheet instead of the red.
class Segments<T extends Object> extends StatelessWidget {
  const Segments({super.key, required this.items, required this.value, required this.onChanged, this.onSheet = false});
  final List<(T, String, IconData?)> items;
  final T value;
  final ValueChanged<T> onChanged;
  final bool onSheet;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final ink = onSheet ? t.sheetInk : t.ink;
    void pick(T v) {
      HapticFeedback.selectionClick();
      onChanged(v);
    }

    if (isIOS(context)) {
      return SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<T>(
          groupValue: value,
          thumbColor: t.accent,
          backgroundColor: onSheet ? t.sheetRule : t.infield,
          onValueChanged: (v) => v == null ? null : pick(v),
          children: {
            for (final (v, label, icon) in items)
              v: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 16, color: v == value ? t.onAccent : ink),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: v == value ? t.onAccent : ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          },
        ),
      );
    }
    return SegmentedButton<T>(
      segments: [
        for (final (v, label, icon) in items)
          ButtonSegment(value: v, label: Text(label), icon: icon == null ? null : Icon(icon)),
      ],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (v) => pick(v.first),
      style: SegmentedButton.styleFrom(
        foregroundColor: ink,
        selectedForegroundColor: t.onAccent,
        selectedBackgroundColor: t.accent,
        side: BorderSide(color: onSheet ? t.sheetRule : t.lane),
      ),
    );
  }
}

/// Picks a day. Android: the Material calendar. iPhone: the wheel picker in a bottom panel with Done.
Future<DateTime?> pickDate(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
  required String help,
}) async {
  if (!isIOS(context)) {
    return showDatePicker(context: context, initialDate: initial, firstDate: first, lastDate: last, helpText: help);
  }
  var picked = initial;
  final ok = await showCupertinoModalPopup<bool>(
    context: context,
    builder: (ctx) {
      final t = Daur.of(ctx);
      return Container(
        height: 320,
        color: t.sheet,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: Text(help, style: TextStyle(fontSize: 15, color: t.sheetInk2)),
                  ),
                  const Spacer(),
                  CupertinoButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(
                      'Done',
                      style: TextStyle(fontWeight: FontWeight.w700, color: t.sheetRed),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initial,
                  minimumDate: first,
                  maximumDate: last,
                  onDateTimeChanged: (d) => picked = d,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  return ok == true ? picked : null;
}

/// The back (or close) icon: Android's arrow, iPhone's chevron.
IconData backIcon(BuildContext context, {bool close = false}) => isIOS(context)
    ? (close ? CupertinoIcons.chevron_down : CupertinoIcons.back)
    : (close ? Icons.keyboard_arrow_down_rounded : Icons.arrow_back);

/// The bottom tabs. Android: the Material navigation bar. iPhone: a floating Liquid Glass bar,
/// a frosted capsule above the home indicator that the page scrolls under.
class Tabs extends StatelessWidget {
  const Tabs({super.key, required this.index, required this.onTap, required this.items});
  final int index;
  final ValueChanged<int> onTap;
  final List<(IconData, IconData, String)> items; // icon, selected icon, label

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    if (!isIOS(context)) {
      return NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onTap,
        destinations: [
          for (final (icon, sel, label) in items)
            NavigationDestination(icon: Icon(icon), selectedIcon: Icon(sel), label: label),
        ],
      );
    }
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: 62,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: t.infield.withValues(alpha: .62),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: t.ink.withValues(alpha: .16)),
              ),
              child: Row(
                children: [
                  for (final (i, (icon, sel, label)) in items.indexed)
                    Expanded(
                      child: Semantics(
                        selected: i == index,
                        button: true,
                        label: label,
                        excludeSemantics: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onTap(i);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            decoration: BoxDecoration(
                              color: i == index ? t.ink.withValues(alpha: .18) : Colors.transparent,
                              borderRadius: BorderRadius.circular(27),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(i == index ? sel : icon, size: 22, color: t.ink),
                                const SizedBox(height: 2),
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                                    color: t.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the app's menu: the drawer on Android, the More page on iPhone. Set by the shell.
VoidCallback? menuOpener;
void openMenu(BuildContext context) => menuOpener?.call();
