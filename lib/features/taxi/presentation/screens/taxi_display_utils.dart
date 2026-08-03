class TaxiDisplayInfo {
  const TaxiDisplayInfo({
    required this.plate,
    required this.label,
    required this.ownerName,
    required this.driverName,
    required this.isActive,
  });

  final String plate;
  final String label;
  final String ownerName;
  final String driverName;
  final bool isActive;

  factory TaxiDisplayInfo.fromMap(Map<String, dynamic> taxi) {
    final plate = (taxi['plate_number'] as String?) ??
        (taxi['plate'] as String?) ??
        '—';
    final brand = (taxi['brand'] as String?) ?? '';
    final model = (taxi['model'] as String?) ?? '';
    final color = (taxi['color'] as String?) ?? '';
    final vehicleLabel = [brand, model].where((value) => value.isNotEmpty).join(' ');

    final owner = taxi['owner'] as Map<String, dynamic>?;
    final ownerName = owner != null
        ? '${owner['first_name'] ?? ''} ${owner['last_name'] ?? ''}'.trim()
        : '—';

    final activeDriver = taxi['active_driver'] as Map<String, dynamic>?;
    final driverUser = activeDriver?['user'] as Map<String, dynamic>?;
    final driverName = driverUser != null
        ? '${driverUser['first_name'] ?? ''} ${driverUser['last_name'] ?? ''}'.trim()
        : '—';

    final labelParts = <String>[];
    if (vehicleLabel.isNotEmpty) {
      labelParts.add(vehicleLabel);
    }
    if (color.isNotEmpty) {
      labelParts.add(color);
    }

    return TaxiDisplayInfo(
      plate: plate,
      label: labelParts.join(' • '),
      ownerName: ownerName.isEmpty ? '—' : ownerName,
      driverName: driverName.isEmpty ? '—' : driverName,
      isActive: taxi['is_active'] as bool? ?? false,
    );
  }
}
