import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';

/// Ay bazlı, bağımlılıksız takvim widget'ı.
///
/// - Seçili aya göre günleri hesaplar (artık yıl / ay uzunluğu dahil).
/// - **Bugün** her zaman belirgin şekilde vurgulanır (dolgulu daire).
/// - Etkinliği olan günlerin altında nokta gösterilir.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.focusedMonth,
    required this.selectedDay,
    required this.events,
    required this.onDaySelected,
    required this.onMonthChanged,
  });

  final DateTime focusedMonth;
  final DateTime selectedDay;
  final List<CalendarEvent> events;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onMonthChanged;

  static const List<String> _weekdayLabels = <String>[
    'Pzt',
    'Sal',
    'Çar',
    'Per',
    'Cum',
    'Cmt',
    'Paz',
  ];

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<CalendarEvent> _eventsOn(DateTime day) =>
      events.where((CalendarEvent e) => _isSameDay(e.date, day)).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTime today = DateTime.now();

    // Ayın ilk gününün haftanın kaçıncı günü olduğu (1 = Pazartesi)
    final DateTime firstDayOfMonth = DateTime(focusedMonth.year, focusedMonth.month);
    final int leadingEmptyDays = firstDayOfMonth.weekday - 1;
    // Bir sonraki ayın 0. günü = bu ayın son günü
    final int daysInMonth = DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    final int totalCells = leadingEmptyDays + daysInMonth;
    final int rowCount = (totalCells / 7).ceil();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
        child: Column(
          children: <Widget>[
            // --- Ay başlığı ve gezinme -----------------------------------
            Row(
              children: <Widget>[
                IconButton(
                  onPressed: () => onMonthChanged(
                    DateTime(focusedMonth.year, focusedMonth.month - 1),
                  ),
                  icon: const Icon(Icons.chevron_left_rounded),
                  tooltip: 'Önceki ay',
                ),
                Expanded(
                  child: Text(
                    toBeginningOfSentenceCase(
                          DateFormat.yMMMM('tr_TR').format(focusedMonth),
                        ) ??
                        '',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: () => onMonthChanged(
                    DateTime(focusedMonth.year, focusedMonth.month + 1),
                  ),
                  icon: const Icon(Icons.chevron_right_rounded),
                  tooltip: 'Sonraki ay',
                ),
              ],
            ),
            const SizedBox(height: 4),

            // --- Hafta günleri başlığı -----------------------------------
            Row(
              children: <Widget>[
                for (final String label in _weekdayLabels)
                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),

            // --- Gün ızgarası --------------------------------------------
            for (int row = 0; row < rowCount; row++)
              Row(
                children: <Widget>[
                  for (int col = 0; col < 7; col++)
                    Expanded(
                      child: Builder(
                        builder: (BuildContext context) {
                          final int dayNumber = row * 7 + col - leadingEmptyDays + 1;
                          if (dayNumber < 1 || dayNumber > daysInMonth) {
                            return const SizedBox(height: 44);
                          }
                          final DateTime day = DateTime(
                            focusedMonth.year,
                            focusedMonth.month,
                            dayNumber,
                          );
                          return _DayCell(
                            day: day,
                            isToday: _isSameDay(day, today),
                            isSelected: _isSameDay(day, selectedDay),
                            hasEvent: _eventsOn(day).isNotEmpty,
                            onTap: () => onDaySelected(day),
                          );
                        },
                      ),
                    ),
                ],
              ),

            // --- Seçili günün maçları ------------------------------------
            _SelectedDayEvents(day: selectedDay, events: _eventsOn(selectedDay)),
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.hasEvent,
    required this.onTap,
  });

  final DateTime day;
  final bool isToday;
  final bool isSelected;
  final bool hasEvent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    // Bugün: dolgulu daire. Seçili (bugün değilse): çerçeveli daire.
    final Color background = isToday
        ? scheme.primary
        : (isSelected ? scheme.primary.withValues(alpha: 0.12) : Colors.transparent);
    final Color foreground = isToday
        ? scheme.onPrimary
        : (isSelected ? scheme.primary : scheme.onSurface);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: SizedBox(
        height: 44,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: background,
                shape: BoxShape.circle,
                border: isSelected && !isToday
                    ? Border.all(color: scheme.primary, width: 1.4)
                    : null,
              ),
              child: Text(
                '${day.day}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: foreground,
                  fontWeight: isToday || isSelected ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasEvent
                    ? (isToday ? scheme.primary : scheme.tertiary)
                    : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedDayEvents extends StatelessWidget {
  const _SelectedDayEvents({required this.day, required this.events});

  final DateTime day;
  final List<CalendarEvent> events;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String dayLabel = DateFormat('d MMMM EEEE', 'tr_TR').format(day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 8),
        const Divider(height: 1),
        const SizedBox(height: 10),
        Text(
          dayLabel,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        if (events.isEmpty)
          Text(
            'Bu güne planlanmış maçınız yok.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          )
        else
          for (final CalendarEvent event in events)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 4,
                    height: 34,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'vs ${event.title}',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          event.subtitle,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
