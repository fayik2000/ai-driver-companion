import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../logic/demand.dart';
import '../state/app_state.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../util/format.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  String service = services.first;
  int horizon = 0;
  LatLng? me;
  final mapCtrl = MapController();

  Color _color(int score) =>
      score >= 70 ? AppColors.primary : (score >= 45 ? AppColors.accent : const Color(0xFFB9C4BD));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: AppState.I,
        builder: (context, _) {
          final s = AppState.I;
          final city = cityByName(s.profile?['city'] as String?);
          final historical = horizon == 3;
          final hour = (nowWib().hour + nowWib().minute / 60 + const [0.0, 0.5, 1.0, 0.0][horizon]).toDouble();
          final zones = historical ? <Zone>[] : simulateZones(city: city, service: service, hourWib: hour);
          final kmpl = s.fuel.kmPerL ?? (s.profile?['fuelKmPerL'] as num?)?.toDouble();
          final kmplFromProfile = s.fuel.kmPerL == null && kmpl != null;
          final evals = evaluateZones(
            zones: zones,
            fromLat: me?.latitude,
            fromLng: me?.longitude,
            kmPerL: kmpl,
            pricePerL: s.priceFor(s.fuelType),
          );
          return Scaffold(
            appBar: AppBar(title: const Text('Peta Peluang')),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.warnBg, borderRadius: BorderRadius.circular(12)),
                  child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.science_outlined, color: AppColors.warn, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Data Simulasi — untuk demonstrasi. Peta ini TIDAK menampilkan pesanan nyata dari Gojek, Grab, '
                        'atau platform lain karena belum ada integrasi resmi.',
                        style: TextStyle(fontSize: 12.5, color: AppColors.warn, height: 1.35),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: [for (final sv in services) ButtonSegment(value: sv, label: Text(sv))],
                  selected: {service},
                  onSelectionChanged: (v) => setState(() => service = v.first),
                  showSelectedIcon: false,
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (var i = 0; i < horizons.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(horizons[i]),
                          selected: horizon == i,
                          onSelected: (_) => setState(() => horizon = i),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 300,
                    child: FlutterMap(
                      mapController: mapCtrl,
                      options: MapOptions(
                        initialCenter: LatLng(city.lat, city.lng),
                        initialZoom: 13,
                        onTap: (_, p) => setState(() => me = p),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'id.aidriver.ai_driver_companion',
                        ),
                        CircleLayer(circles: [
                          for (final z in zones)
                            CircleMarker(
                              point: LatLng(z.lat, z.lng),
                              radius: 550,
                              useRadiusInMeter: true,
                              color: _color(z.score).withValues(alpha: 0.35),
                              borderColor: _color(z.score),
                              borderStrokeWidth: 2,
                            ),
                        ]),
                        MarkerLayer(markers: [
                          for (final z in zones)
                            Marker(
                              point: LatLng(z.lat, z.lng),
                              width: 64,
                              height: 24,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: Colors.white, borderRadius: BorderRadius.circular(8)),
                                  child: Text('${z.name.split(' ').last} ${z.score}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ),
                          if (me != null)
                            Marker(
                              point: me!,
                              width: 36,
                              height: 36,
                              child: const Icon(Icons.my_location, color: Colors.blue, size: 30),
                            ),
                        ]),
                        RichAttributionWidget(attributions: [
                          TextSourceAttribution('© kontributor OpenStreetMap'),
                        ]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  me == null
                      ? 'Ketuk peta untuk menandai posisi Anda agar jarak, waktu, dan biaya bisa diperkirakan.'
                      : 'Posisi Anda ditandai. Jarak adalah perkiraan kasar (garis lurus × 1,3), bukan rute jalan.',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                if (historical)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: EmptyNote(
                      'Pola historis belum tersedia. Fitur ini butuh data permintaan nyata per wilayah, '
                      'yang belum terhubung ke aplikasi.',
                      icon: Icons.history,
                    ),
                  )
                else ...[
                  SectionTitle('Rekomendasi zona', trailing: Pill(sourceLabel(DataSource.simulasi),
                      color: AppColors.warn, bg: AppColors.warnBg)),
                  for (final (i, e) in evals.take(4).indexed) _ZoneCard(e, rank: i + 1, me: me, kmplFromProfile: kmplFromProfile),
                  const SizedBox(height: 4),
                  const Text(
                    'Tingkat keyakinan rendah karena berasal dari data simulasi. Selalu pertimbangkan biaya dan waktu '
                    'menuju lokasi sebelum berpindah.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ],
            ),
          );
        },
      );
}

class _ZoneCard extends StatelessWidget {
  const _ZoneCard(this.e, {required this.rank, required this.me, required this.kmplFromProfile});
  final ZoneEval e;
  final int rank;
  final LatLng? me;
  final bool kmplFromProfile;

  @override
  Widget build(BuildContext context) {
    final z = e.zone;
    final why = StringBuffer('${z.name} memiliki potensi ${z.levelLabel.toLowerCase()} (skor ${z.score}/100) '
        'berdasarkan data simulasi untuk layanan ini.');
    if (me != null) {
      why.write(' Perkiraan perjalanan ${e.minutes} menit (±${fmtNum(e.km)} km).');
      if (e.fuelCost != null) {
        why.write(' Perkiraan biaya BBM menuju lokasi ${rupiah(e.fuelCost!)}'
            '${kmplFromProfile ? ' (dari konsumsi BBM di profil)' : ''}.');
      } else {
        why.write(' Biaya BBM belum bisa dihitung karena konsumsi km/liter belum diketahui.');
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.goodBg,
            child: Text('$rank', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(z.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                Pill('Potensi ${z.levelLabel}'),
              ]),
              const SizedBox(height: 6),
              Text(why.toString(), style: const TextStyle(fontSize: 13, height: 1.35)),
              const SizedBox(height: 4),
              const Text('Keyakinan: Rendah (data simulasi)', style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ]),
          ),
        ]),
      ),
    );
  }
}
