import 'package:flutter/material.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_address.dart';
import 'package:tmail_ui_user/features/numberinbox/phone_number_parser.dart';
import 'package:tmail_ui_user/main/localizations/app_localizations.dart';
import 'country.dart';

class CountryPickerSheet extends StatefulWidget {
  const CountryPickerSheet({
    super.key,
    required this.selectedCountry,
    required this.onSelected,
    this.headerNumber,
    this.headerName,
    this.validateSelection,
    this.validationErrorText,
  });

  /// Currently selected country, shown with a check mark. Null means no
  /// preselection, used when resolving an unvalidated phone recipient.
  final Country? selectedCountry;
  final void Function(Country) onSelected;

  /// Optional header identifying the number being resolved.
  final String? headerNumber;
  final String? headerName;

  /// Optional per-tap validation. When it returns false the sheet stays
  /// open and shows [validationErrorText] inline instead of selecting.
  final bool Function(Country)? validateSelection;
  final String? validationErrorText;

  @override
  State<CountryPickerSheet> createState() => CountryPickerSheetState();
}

class CountryPickerSheetState extends State<CountryPickerSheet> {
  String _query = '';
  String? _error;

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
            if (widget.headerNumber != null || widget.headerName != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  children: [
                    if (widget.headerName != null)
                      Text(
                        widget.headerName!,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    if (widget.headerNumber != null)
                      Text(
                        widget.headerNumber!,
                        key: const Key('country_sheet_number'),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                  ],
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  _error!,
                  key: const Key('country_validation_error'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
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
                  final selected = c.code == widget.selectedCountry?.code;
                  return ListTile(
                    key: Key('country_${c.code}'),
                    leading: Text(c.flag, style: const TextStyle(fontSize: 24)),
                    title: Text(c.name),
                    subtitle: Text(c.dialCode),
                    trailing: selected
                        ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                        : null,
                    onTap: () {
                      if (widget.validateSelection != null &&
                          !widget.validateSelection!(c)) {
                        setState(() => _error = widget.validationErrorText);
                        return;
                      }
                      widget.onSelected(c);
                    },
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
  required Country? selectedCountry,
  required void Function(Country) onSelected,
  String? headerNumber,
  String? headerName,
  bool Function(Country)? validateSelection,
  String? validationErrorText,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => CountryPickerSheet(
      selectedCountry: selectedCountry,
      headerNumber: headerNumber,
      headerName: headerName,
      validateSelection: validateSelection,
      validationErrorText: validationErrorText,
      onSelected: (c) {
        onSelected(c);
        Navigator.pop(context);
      },
    ),
  );
}

/// Shared country-resolution flow for unresolved phone recipients.
///
/// Shows the country sheet with no preselected country and the raw number
/// plus contact name as a header. Each tapped country is validated with the
/// strict recipient parser: failure keeps the sheet open with a localized
/// inline error and creates nothing; success closes the sheet and returns
/// the resolved recipient with the name retained and a canonical
/// `+E164@numberinbox.com` address. Dismissing the sheet cancels and
/// returns null.
Future<EmailAddress?> resolvePhoneRecipient(
  BuildContext context,
  EmailAddress recipient,
) async {
  final raw = recipient.email?.trim() ?? '';
  if (raw.isEmpty) return null;

  final parser = PhoneNumberParser();
  String? resolvedAddress;
  await showCountryPicker(
    context: context,
    selectedCountry: null,
    headerNumber: raw,
    headerName: (recipient.name ?? '').trim().isEmpty ? null : recipient.name,
    validationErrorText:
        AppLocalizations.of(context).thisEmailAddressInvalid,
    validateSelection: (country) {
      final e164 = parser.parseRecipientToE164(
        raw,
        selectedRegion: country.code,
      );
      if (e164 == null) return false;
      resolvedAddress = '$e164@numberinbox.com';
      return true;
    },
    onSelected: (_) {},
  );

  if (resolvedAddress == null) return null;
  return EmailAddress(recipient.name, resolvedAddress);
}
