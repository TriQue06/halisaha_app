import 'package:flutter/material.dart';

import '../../../core/constants/izmir_districts.dart';
import '../../../core/theme/app_theme.dart';

/// Tam genişlikte "İlçe Seçiniz..." butonu.
///
/// Chip yerine tek bir geniş buton; basıldığında ilçeler **alfabetik**
/// sırayla bir BottomSheet içinde yukarıdan aşağıya listelenir.
class DistrictSelectorButton extends StatelessWidget {
  const DistrictSelectorButton({
    super.key,
    required this.selectedDistrict,
    required this.onChanged,
  });

  /// null ise "İlçe Seçiniz..." metni gösterilir.
  final String? selectedDistrict;
  final ValueChanged<String?> onChanged;

  Future<void> _openPicker(BuildContext context) async {
    final String? result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) =>
          _DistrictPickerSheet(selectedDistrict: selectedDistrict),
    );

    // Sheet kapatılmadan (barrier) çıkıldıysa seçim değişmez.
    if (result == null) return;
    // '' -> "Tüm İlçeler" seçildi.
    onChanged(result.isEmpty ? null : result);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasSelection = selectedDistrict != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: () => _openPicker(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: hasSelection ? theme.colorScheme.primary : theme.colorScheme.outline,
              width: hasSelection ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.place_outlined,
                size: 20,
                color: hasSelection
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  selectedDistrict ?? 'İlçe Seçiniz...',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: hasSelection ? FontWeight.w700 : FontWeight.w500,
                    color: hasSelection
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (hasSelection)
                IconButton(
                  onPressed: () => onChanged(null),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: 'Filtreyi temizle',
                  visualDensity: VisualDensity.compact,
                )
              else
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// İzmir ilçelerinin alfabetik listesi.
class _DistrictPickerSheet extends StatefulWidget {
  const _DistrictPickerSheet({required this.selectedDistrict});

  final String? selectedDistrict;

  @override
  State<_DistrictPickerSheet> createState() => _DistrictPickerSheetState();
}

class _DistrictPickerSheetState extends State<_DistrictPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    // Kaynak liste zaten Türkçe alfabetik; arama sonrası sırayı koruyoruz.
    final List<String> districts = IzmirDistricts.sorted(
      IzmirDistricts.all.where(
        (String d) => IzmirDistricts.toLowerTr(d).contains(IzmirDistricts.toLowerTr(_query)),
      ),
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (BuildContext context, ScrollController scrollController) {
        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'İlçe Seçiniz',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    autofocus: false,
                    onChanged: (String value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                      hintText: 'İlçe ara...',
                      prefixIcon: Icon(Icons.search_rounded),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.only(bottom: 24),
                // +1: en üstteki "Tüm İlçeler" seçeneği
                itemCount: districts.length + 1,
                itemBuilder: (BuildContext context, int index) {
                  if (index == 0) {
                    return _DistrictTile(
                      label: 'Tüm İlçeler',
                      isSelected: widget.selectedDistrict == null,
                      icon: Icons.public_rounded,
                      onTap: () => Navigator.of(context).pop(''),
                    );
                  }
                  final String district = districts[index - 1];
                  return _DistrictTile(
                    label: district,
                    isSelected: district == widget.selectedDistrict,
                    onTap: () => Navigator.of(context).pop(district),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DistrictTile extends StatelessWidget {
  const _DistrictTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListTile(
      onTap: onTap,
      leading: Icon(
        icon ?? Icons.location_on_outlined,
        size: 20,
        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        label,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
          color: isSelected ? theme.colorScheme.primary : null,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 20)
          : null,
    );
  }
}
