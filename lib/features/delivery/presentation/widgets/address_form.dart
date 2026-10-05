import 'package:flutter/material.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/features/auth/domain/value_objects/malagasy_phone.dart';
import 'package:majichrono/features/delivery/domain/entities/address.dart';
import 'package:majichrono/features/delivery/domain/entities/majunga_places.dart';
import 'package:majichrono/features/delivery/domain/value_objects/geo_point.dart';
import 'package:majichrono/features/tracking/presentation/screens/pick_location_screen.dart';
import 'package:majichrono/l10n/app_localizations.dart';

/// Saisie d'une adresse composite (EXI-C02, differenciant D3).
///
/// L'ordre des champs traduit l'exigence : **quartier, puis point de repere,
/// puis telephone** — les trois obligatoires — et la rue tout en bas, marquee
/// facultative. Un formulaire qui commencerait par « rue et numero » inviterait
/// l'utilisateur a remplir le champ le moins utile et a bacler celui dont le
/// livreur a reellement besoin (§4.3).
class AddressForm extends StatefulWidget {
  const AddressForm({required this.onChanged, this.initial, super.key});

  /// Emet l'adresse des qu'elle est complete, `null` sinon.
  final ValueChanged<Address?> onChanged;
  final Address? initial;

  @override
  State<AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends State<AddressForm> {
  late final TextEditingController _district = TextEditingController(
    text: widget.initial?.district,
  );
  late final TextEditingController _landmark = TextEditingController(
    text: widget.initial?.landmark,
  );
  late final TextEditingController _phone = TextEditingController(
    text: widget.initial?.contactPhone.displayNational,
  );
  late final TextEditingController _name = TextEditingController(
    text: widget.initial?.contactName,
  );
  late final TextEditingController _street = TextEditingController(
    text: widget.initial?.street,
  );

  bool _showErrors = false;

  /// Point GPS de l'adresse. Il commence au centre de Majunga et n'est
  /// reellement pose que lorsque l'utilisateur le place sur la carte, ou
  /// touche un lieu connu.
  late GeoPoint _point = widget.initial?.point ?? GeoPoint.mahajanga;
  late bool _pointPicked = widget.initial != null;

  Future<void> _pickPoint() async {
    final picked = await Navigator.of(context).push<GeoPoint>(
      MaterialPageRoute(builder: (_) => PickLocationScreen(initial: _point)),
    );
    if (picked == null) return;
    setState(() {
      _point = picked;
      _pointPicked = true;
    });
    _notify();
  }

  /// Un lieu connu remplit d'un geste le point, le quartier et le repere :
  /// « au Bazary Be » suffit a un livreur de Majunga. Le telephone reste a
  /// saisir, et le repere peut etre precise (« porte verte »).
  void _usePlace(MajungaPlace place) {
    _point = place.point;
    _pointPicked = true;
    _district.text = place.district;
    _landmark.text = place.name;
    _notify();
  }

  @override
  void dispose() {
    _district.dispose();
    _landmark.dispose();
    _phone.dispose();
    _name.dispose();
    _street.dispose();
    super.dispose();
  }

  Address? _build() {
    final phone = MalagasyPhone.tryParse(_phone.text);
    if (_district.text.trim().isEmpty ||
        _landmark.text.trim().isEmpty ||
        phone == null) {
      return null;
    }

    if (!_point.isInMadagascar) return null;
    return Address(
      point: _point,
      district: _district.text.trim(),
      landmark: _landmark.text.trim(),
      contactPhone: phone,
      contactName: _name.text.trim().isEmpty ? null : _name.text.trim(),
      street: _street.text.trim().isEmpty ? null : _street.text.trim(),
    );
  }

  void _notify() {
    setState(() {});
    widget.onChanged(_build());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final phoneInvalid =
        _phone.text.isNotEmpty && MalagasyPhone.tryParse(_phone.text) == null;

    String? requiredError(TextEditingController controller) =>
        _showErrors && controller.text.trim().isEmpty
        ? l10n.addrRequired
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.addrKnownPlaces,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: MajungaZone.places.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (_, i) {
              final place = MajungaZone.places[i];
              return ActionChip(
                avatar: Icon(_placeIcon(place.category), size: 18),
                label: Text(place.name),
                onPressed: () => _usePlace(place),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: _pickPoint,
          icon: Icon(
            _pointPicked ? Icons.check_circle_outline : Icons.map_outlined,
          ),
          label: Text(
            _pointPicked ? l10n.pickLocationSet : l10n.pickLocationAction,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.pickLocationHelp,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _district,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: l10n.addrDistrict,
            hintText: l10n.addrDistrictHint,
            prefixIcon: const Icon(Icons.location_city_outlined),
            errorText: requiredError(_district),
          ),
          onChanged: (_) => _notify(),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _landmark,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: l10n.addrLandmark,
            hintText: l10n.addrLandmarkHint,
            helperText: l10n.addrLandmarkHelp,
            helperMaxLines: 2,
            prefixIcon: const Icon(Icons.push_pin_outlined),
            errorText: requiredError(_landmark),
          ),
          onChanged: (_) => _notify(),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: l10n.addrContactPhone,
            hintText: l10n.authPhoneHint,
            prefixIcon: const Icon(Icons.phone_outlined),
            errorText: phoneInvalid
                ? l10n.authPhoneInvalid
                : (_showErrors && _phone.text.isEmpty
                      ? l10n.addrRequired
                      : null),
          ),
          onChanged: (_) => _notify(),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: '${l10n.addrContactName} (${l10n.addrOptional})',
            prefixIcon: const Icon(Icons.person_outline),
          ),
          onChanged: (_) => _notify(),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _street,
          decoration: InputDecoration(
            // Le caractere facultatif est ecrit dans le libelle, pas seulement
            // sous-entendu : c'est ce qui autorise l'utilisateur a passer.
            labelText: '${l10n.addrStreet} (${l10n.addrOptional})',
            prefixIcon: const Icon(Icons.signpost_outlined),
          ),
          onChanged: (_) => _notify(),
        ),
      ],
    );
  }

  /// Affiche les erreurs des champs obligatoires restes vides.
  void showErrors() => setState(() => _showErrors = true);

  static IconData _placeIcon(PlaceCategory category) => switch (category) {
    PlaceCategory.landmark => Icons.park_outlined,
    PlaceCategory.market => Icons.storefront_outlined,
    PlaceCategory.transport => Icons.directions_bus_outlined,
    PlaceCategory.health => Icons.local_hospital_outlined,
    PlaceCategory.education => Icons.school_outlined,
    PlaceCategory.beach => Icons.beach_access_outlined,
    PlaceCategory.district => Icons.location_city_outlined,
  };
}
