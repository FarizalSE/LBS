import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lbs/models/triger_model.dart'; // Sesuaikan dengan path-mu

class LBS extends StatefulWidget {
  const LBS({super.key});

  @override
  State<LBS> createState() => _LBSState();
}

class _LBSState extends State<LBS> {
  Position? _currentPosition;
  String _statusMessage = 'Menunggu lokasi...';
  GoogleMapController? _mapController;
  LatLng _initialCameraPosition = const LatLng(-6.200000, 106.816666);

  Set<Marker> _markers = {};
  List<String> _triggerStatus = [];

  @override
  void initState() {
    super.initState();
    _deteksiLokasi();
  }

  Future<void> _deteksiLokasi() async {
    setState(() {
      _statusMessage = 'Mendeteksi lokasi...';
      _triggerStatus.clear();
    });

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _statusMessage = 'Layanan lokasi tidak aktif';
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _statusMessage = 'Izin lokasi ditolak';
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _statusMessage = 'Izin lokasi ditolak permanen';
      });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _initialCameraPosition = LatLng(position.latitude, position.longitude);
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_initialCameraPosition, 16),
      );

      _cekTrigger();
    } catch (e) {
      setState(() {
        _statusMessage = 'Gagal mendapatkan lokasi: $e';
      });
    }
  }

  void _cekTrigger() {
    if (_currentPosition == null) return;

    List<Marker> markerList = [];

    markerList.add(
      Marker(
        markerId: const MarkerId("lokasi_saya"),
        position: LatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        ),
        infoWindow: const InfoWindow(title: "Lokasi Saya"),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    );

    for (var lokasiTrigger in triggerListLocation) {
      var lokasi = lokasiTrigger.lokasi;
      if (lokasi == null || lokasi.lokasiBising == null) continue;

      for (var bising in lokasi.lokasiBising!) {
        if (bising.latitude == null || bising.longitude == null) continue;

        double distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          bising.latitude!,
          bising.longitude!,
        );

        String status = "";
        double hue = BitmapDescriptor.hueGreen;

        double radius = bising.triggerRadiusMeter ?? 50;

        if (distance <= 20) {
          status = "🔴 ${bising.nama} dalam radius 20m (MERAH)";
          hue = BitmapDescriptor.hueRed;
        } else if (distance <= 30) {
          status = "🟡 ${bising.nama} dalam radius 30m (KUNING)";
          hue = BitmapDescriptor.hueYellow;
        } else if (distance <= radius) {
          status = "🟢 ${bising.nama} dalam radius ${radius.toInt()}m (HIJAU)";
          hue = BitmapDescriptor.hueGreen;
        }

        if (status.isNotEmpty) {
          _triggerStatus.add(status);
        }

        _markers.add(
          Marker(
            markerId: MarkerId(bising.nama ?? bising.hashCode.toString()),
            position: LatLng(bising.latitude!, bising.longitude!),
            infoWindow: InfoWindow(
              title: bising.nama,
              snippet: bising.keterangan,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          ),
        );
      }
    }

    setState(() {
      _markers = {...markerList, ..._markers}; // Gabungkan semua marker
      _statusMessage =
          _triggerStatus.isEmpty
              ? "Tidak ada lokasi dalam radius 50 meter"
              : "${_triggerStatus.length} lokasi terdeteksi!";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Deteksi Lokasi LBS"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _initialCameraPosition,
                zoom: 15,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              onMapCreated: (controller) {
                _mapController = controller;
              },
              markers: _markers,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_statusMessage, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _deteksiLokasi,
                    icon: const Icon(Icons.refresh),
                    label: const Text("Refresh Lokasi"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_triggerStatus.isNotEmpty)
                    ..._triggerStatus.map(
                      (status) =>
                          Text(status, style: const TextStyle(fontSize: 14)),
                    ),
                  const SizedBox(height: 10),
                  const Divider(),
                  const Text(
                    "📍 Semua Lokasi Bising:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  ...triggerListLocation.expand((lokasiTrigger) {
                    final lokasi = lokasiTrigger.lokasi;
                    if (lokasi == null || lokasi.lokasiBising == null)
                      return [];
                    return lokasi.lokasiBising!.map((bising) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "• ${bising.nama ?? "Tanpa Nama"}",
                            style: const TextStyle(fontSize: 14),
                          ),
                          if (bising.tingkatKebisinganEstimasi != null)
                            Text(
                              "  Estimasi Kebisingan: ${bising.tingkatKebisinganEstimasi}",
                            ),
                          if (bising.latitude != null &&
                              bising.longitude != null)
                            Text(
                              "  Koordinat: (${bising.latitude}, ${bising.longitude})",
                            ),
                          if (bising.keterangan != null &&
                              bising.keterangan!.isNotEmpty)
                            Text("  Keterangan: ${bising.keterangan}"),
                          const SizedBox(height: 6),
                        ],
                      );
                    });
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
