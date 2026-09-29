import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/unit_summary.dart';
import '../../../state/game_session.dart';

/// Weight classes of the BattleTech rules, as ton ranges.
const _weightClasses = <(String, double, double)>[
  ('Light', 20, 35),
  ('Medium', 40, 55),
  ('Heavy', 60, 75),
  ('Assault', 80, 1000),
];

const _unitTypes = <(String, String)>[
  ('Mek', 'Mech'),
  ('Tank', 'Vehicle'),
  ('VTOL', 'VTOL'),
  ('Infantry', 'Infantry'),
  ('BattleArmor', 'Battle Armor'),
  ('ProtoMek', 'ProtoMech'),
];

/// Modal bottom sheet: search MegaMek's unit database (with filters) and add
/// units to a roster - the local player's own (`targetBotName == null`) or a
/// connected bot's (`targetBotName` set). The sheet stays open after adding
/// so a whole force can be assembled in one go.
class MechCatalogSheet extends ConsumerStatefulWidget {
  const MechCatalogSheet({super.key, this.targetBotName});

  final String? targetBotName;

  @override
  ConsumerState<MechCatalogSheet> createState() => _MechCatalogSheetState();
}

class _MechCatalogSheetState extends ConsumerState<MechCatalogSheet> {
  final _searchController = TextEditingController();
  final _minYear = TextEditingController();
  final _maxYear = TextEditingController();
  Timer? _debounce;

  String _unitType = 'Mek';
  final Set<int> _weights = {};
  String? _techBase;
  RangeValues _bv = const RangeValues(0, 3000);
  bool _showMore = false;
  final List<String> _added = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _search());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _minYear.dispose();
    _maxYear.dispose();
    super.dispose();
  }

  void _searchSoon() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _search);
  }

  void _search() {
    if (!mounted) {
      return;
    }
    double? minTons;
    double? maxTons;
    if (_weights.isNotEmpty) {
      minTons = _weights
          .map((i) => _weightClasses[i].$2)
          .reduce((a, b) => a < b ? a : b);
      maxTons = _weights
          .map((i) => _weightClasses[i].$3)
          .reduce((a, b) => a > b ? a : b);
      if (maxTons >= 1000) {
        maxTons = null;
      }
    }
    final text = _searchController.text.trim();
    ref
        .read(gameSessionProvider.notifier)
        .searchUnitCatalog(
          text: text.isEmpty ? null : text,
          unitType: _unitType,
          techBase: _techBase,
          minTons: minTons,
          maxTons: maxTons,
          minBv: _bv.start > 0 ? _bv.start.round() : null,
          maxBv: _bv.end < 3000 ? _bv.end.round() : null,
          minYear: int.tryParse(_minYear.text),
          maxYear: int.tryParse(_maxYear.text),
          limit: 100,
        );
  }

  void _add(UnitSummary unit) {
    final notifier = ref.read(gameSessionProvider.notifier);
    if (widget.targetBotName == null) {
      notifier.sendAddUnit(unit.ref);
    } else {
      notifier.sendAddBotUnit(
        botName: widget.targetBotName!,
        unitRef: unit.ref,
      );
    }
    setState(() => _added.add('${unit.chassis} ${unit.model}'));
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(gameSessionProvider);
    final target = widget.targetBotName ?? 'you';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              key: const Key('catalog-search'),
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search units (name, model)',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: Icon(_showMore ? Icons.expand_less : Icons.tune),
                  tooltip: 'Filters',
                  onPressed: () => setState(() => _showMore = !_showMore),
                ),
              ),
              onChanged: (_) => _searchSoon(),
              onSubmitted: (_) => _search(),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (final t in _unitTypes)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(t.$2),
                      selected: _unitType == t.$1,
                      onSelected: (_) {
                        setState(() => _unitType = t.$1);
                        _search();
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (_showMore) _filters(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${session.catalogResults.length} of ${session.catalogTotalMatches} matches'
                    '${_added.isEmpty ? '' : ' · added ${_added.length} for $target'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
          if (_added.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Last added: ${_added.last}',
                  key: const Key('catalog-last-added'),
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              itemCount: session.catalogResults.length,
              itemBuilder: (context, index) {
                final unit = session.catalogResults[index];
                return Card(
                  child: ListTile(
                    key: Key('catalog-${unit.ref}'),
                    title: Text('${unit.chassis} ${unit.model}'),
                    subtitle: Text(
                      '${unit.tons.toStringAsFixed(0)} t · BV ${unit.bv} · '
                      '${unit.year} · ${unit.techBase}',
                    ),
                    trailing: const Icon(Icons.add_circle_outline),
                    onTap: () => _add(unit),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            children: [
              for (var i = 0; i < _weightClasses.length; i++)
                FilterChip(
                  label: Text(_weightClasses[i].$1),
                  selected: _weights.contains(i),
                  onSelected: (on) {
                    setState(() => on ? _weights.add(i) : _weights.remove(i));
                    _search();
                  },
                ),
            ],
          ),
          Wrap(
            spacing: 6,
            children: [
              for (final t in const [
                (null, 'Any tech'),
                ('Inner Sphere', 'Inner Sphere'),
                ('Clan', 'Clan'),
              ])
                ChoiceChip(
                  label: Text(t.$2),
                  selected: _techBase == t.$1,
                  onSelected: (_) {
                    setState(() => _techBase = t.$1);
                    _search();
                  },
                ),
            ],
          ),
          Text(
            'BV ${_bv.start.round()} - ${_bv.end >= 3000 ? '3000+' : _bv.end.round()}',
            style: const TextStyle(fontSize: 12),
          ),
          RangeSlider(
            values: _bv,
            min: 0,
            max: 3000,
            divisions: 60,
            onChanged: (v) => setState(() => _bv = v),
            onChangeEnd: (_) => _search(),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minYear,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Year from',
                    isDense: true,
                  ),
                  onChanged: (_) => _searchSoon(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _maxYear,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Year to',
                    isDense: true,
                  ),
                  onChanged: (_) => _searchSoon(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
