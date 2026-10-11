import 'package:flutter/material.dart';

import '../../../shared/design_system/app_colors.dart';
import '../../../shared/design_system/widgets/primary_button.dart';
import '../../../shared/design_system/widgets/status_chip.dart';
import '../data/route_plan.dart';
import '../route_format.dart';

/// A single route stop: visiting-order badge, address, cumulative distance/ETA
/// and the Mark Delivered / Skip actions. Tapping the card centers the map.
class StopCard extends StatelessWidget {
  const StopCard({
    super.key,
    required this.stop,
    required this.active,
    required this.onTap,
    required this.onDeliver,
    required this.onSkip,
  });

  final OrderedStop stop;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onDeliver;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Container(
      decoration: BoxDecoration(
        color: active ? c.surfaceHigh : c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? c.accent : c.outline,
          width: active ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _OrderBadge(stop: stop, active: active),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stop.rawAddress.isEmpty ? 'Unnamed stop' : stop.rawAddress,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (stop.requiresPinConfirmation) ...[
                              Icon(Icons.warning_amber_rounded,
                                  size: 15, color: c.warning),
                              const SizedBox(width: 5),
                              Text(
                                'Confirm pin',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(color: c.warning),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Text(
                              stop.orderId != null
                                  ? 'Order ${stop.orderId}'
                                  : 'Stop ${stop.order}',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: c.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatMeters(stop.cumulativeMeters),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatEta(stop.etaSeconds),
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: c.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        Icons.near_me,
                        size: 14,
                        color: active ? c.accent : c.textMuted,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: c.outline, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: stop.isDone
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: stop.state == StopState.delivered
                        ? const StatusChip(
                            label: 'Delivered',
                            tone: StatusTone.success,
                            icon: Icons.check_circle_outline,
                          )
                        : const StatusChip(
                            label: 'Skipped',
                            tone: StatusTone.neutral,
                            icon: Icons.visibility_off_outlined,
                          ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          label: 'Mark Delivered',
                          icon: Icons.check_rounded,
                          height: 52,
                          onPressed: onDeliver,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 108,
                        child: PrimaryButton(
                          label: 'Skip',
                          height: 52,
                          variant: PrimaryButtonVariant.outlined,
                          onPressed: onSkip,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _OrderBadge extends StatelessWidget {
  const _OrderBadge({required this.stop, required this.active});

  final OrderedStop stop;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final Color background;
    final Color foreground;
    if (stop.isDone) {
      background = c.surfaceHigh;
      foreground = c.textMuted;
    } else if (active) {
      background = c.accent;
      foreground = c.onAccent;
    } else {
      background = c.surfaceHigh;
      foreground = c.textPrimary;
    }

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(
          color: active ? c.accent : c.outline,
          width: active ? 2 : 1,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '${stop.order}',
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: foreground, fontSize: 15),
      ),
    );
  }
}