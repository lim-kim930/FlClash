import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

class ConnectionsSetting extends StatelessWidget {
  const ConnectionsSetting({
    super.key,
    required this.sortController,
    required this.columns,
  });

  final ValueNotifier<RecordSort?> sortController;
  final List<RecordColumn<TrackerInfo>> columns;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final sortable = columns.where((column) => column.sortKey != null).toList();
    return SingleChildScrollView(
      padding: EdgeInsets.only(top: context.contentTopPadding, bottom: 32),
      child: ValueListenableBuilder<RecordSort?>(
        valueListenable: sortController,
        builder: (_, sort, _) => generateSection(
          title: l.settings,
          items: [
            ListItem<String?>.options(
              leading: const GlyphIcon(AppGlyphs.sort),
              title: Text(l.sortBy),
              options: [null, ...sortable.map((column) => column.id)],
              value: sort?.columnId,
              textBuilder: (id) => switch (id) {
                null => l.defaultText,
                'downloadSpeed' => l.downloadSpeed,
                'uploadSpeed' => l.uploadSpeed,
                _ =>
                  sortable.firstWhere((column) => column.id == id).layout.label,
              },
              onChanged: (id) {
                sortController.value = id == null
                    ? null
                    : (
                        columnId: id,
                        descending:
                            sort?.descending ??
                            sortable
                                .firstWhere((column) => column.id == id)
                                .descendingFirst,
                      );
              },
            ),
            if (sort != null)
              ListItem<bool>.options(
                leading: GlyphIcon(
                  sort.descending ? AppGlyphs.arrowDown : AppGlyphs.arrowUp,
                ),
                title: Text(l.sortDirection),
                options: const [false, true],
                value: sort.descending,
                textBuilder: (descending) =>
                    descending ? l.sortDesc : l.sortAsc,
                onChanged: (descending) {
                  sortController.value = (
                    columnId: sort.columnId,
                    descending: descending,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
