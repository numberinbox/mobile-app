import 'package:flutter/material.dart';
import 'country.dart';

class CountryPickerSheet extends StatefulWidget {
  const CountryPickerSheet({
    super.key,
    required this.selectedCountry,
    required this.onSelected,
  });

  final Country selectedCountry;
  final void Function(Country) onSelected;

  @override
  State<CountryPickerSheet> createState() => CountryPickerSheetState();
}

class CountryPickerSheetState extends State<CountryPickerSheet> {
  String _query = '';

  List<Country> get _filtered {
    if (_query.isEmpty) return countries;
    final q = _query.toLowerCase();
    return countries.where((c) =>
      c.name.toLowerCase().contains(q) ||
      c.dialCode.contains(q) ||
      c.code.toLowerCase().contains(q)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                key: const Key('country_search'),
                decoration: const InputDecoration(
                  hintText: 'Search country...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final c = _filtered[index];
                  final selected = c.code == widget.selectedCountry.code;
                  return ListTile(
                    key: Key('country_${c.code}'),
                    leading: Text(c.flag, style: const TextStyle(fontSize: 24)),
                    title: Text(c.name),
                    subtitle: Text(c.dialCode),
                    trailing: selected
                        ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                        : null,
                    onTap: () => widget.onSelected(c),
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

Future<void> showCountryPicker({
  required BuildContext context,
  required Country selectedCountry,
  required void Function(Country) onSelected,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => CountryPickerSheet(
      selectedCountry: selectedCountry,
      onSelected: (c) {
        onSelected(c);
        Navigator.pop(context);
      },
    ),
  );
}
