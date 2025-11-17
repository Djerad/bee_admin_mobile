// Add to pubspec.yaml:
// flutter_map: ^6.1.0
// latlong2: ^0.9.0

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Add this page to your existing app
class HiveMapPage extends StatefulWidget {
  const HiveMapPage({Key? key}) : super(key: key);

  @override
  State<HiveMapPage> createState() => _HiveMapPageState();
}

class _HiveMapPageState extends State<HiveMapPage> {
  final MapController _mapController = MapController();
  final List<Marker> _markers = [];
  bool _isLoading = true;
  List<dynamic> _hives = [];
  String _filterStatus = 'all';
  
  // Default center (Algeria center)
  static const LatLng _defaultCenter = LatLng(28.0339, 1.6596);
  LatLng _currentCenter = _defaultCenter;

  @override
  void initState() {
    super.initState();
    _loadHives();
  }

  Future<void> _loadHives() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await http.get(
        Uri.parse('http://ip:8000/api/dashboard/stats/'),
        headers: {
          'Authorization': 'Token $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final hives = data['hives']['recent'] as List;
        
        setState(() {
          _hives = hives;
          _isLoading = false;
        });
        
        _createMarkers();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الخلايا: $e')),
        );
      }
    }
  }

  void _createMarkers() {
    _markers.clear();
    
    bool hasValidLocation = false;
    double sumLat = 0;
    double sumLng = 0;
    int validCount = 0;

    for (var hive in _hives) {
      // Apply filter
      if (_filterStatus != 'all' && hive['status'] != _filterStatus) {
        continue;
      }

      final lat = hive['latitude'];
      final lng = hive['longitude'];
      
      if (lat != null && lng != null) {
        try {
          final latitude = double.parse(lat.toString());
          final longitude = double.parse(lng.toString());
          
          hasValidLocation = true;
          sumLat += latitude;
          sumLng += longitude;
          validCount++;

          final status = hive['status'] ?? 'unknown';
          Color markerColor;
          
          switch (status) {
            case 'online':
              markerColor = Colors.green;
              break;
            case 'offline':
              markerColor = Colors.red;
              break;
            default:
              markerColor = Colors.orange;
          }

          _markers.add(
            Marker(
              point: LatLng(latitude, longitude),
              width: 40,
              height: 40,
              child: GestureDetector(
                onTap: () => _showHiveDetails(hive),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: markerColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.hive,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        } catch (e) {
          print('Error parsing coordinates for hive ${hive['hive_id']}: $e');
        }
      }
    }

    // Calculate center based on hive locations
    if (hasValidLocation && validCount > 0) {
      setState(() {
        _currentCenter = LatLng(sumLat / validCount, sumLng / validCount);
      });
      
      // Move camera to center
      Future.delayed(const Duration(milliseconds: 100), () {
        _mapController.move(_currentCenter, 12);
      });
    }

    setState(() {});
  }

  void _showHiveDetails(Map<String, dynamic> hive) {
    final latestReading = hive['latest_reading'];
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE67E22).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.hive,
                    color: Color(0xFFE67E22),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hive['name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        hive['hive_id'] ?? '',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(hive['status']),
              ],
            ),
            const SizedBox(height: 16),
            
            // Owner info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'المالك: ${hive['owner_name'] ?? 'Unknown'}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            
            // Location info
            if (hive['latitude'] != null && hive['longitude'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, size: 20, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'الإحداثيات: ${double.parse(hive['latitude'].toString()).toStringAsFixed(4)}, ${double.parse(hive['longitude'].toString()).toStringAsFixed(4)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            if (latestReading != null) ...[
              const SizedBox(height: 16),
              const Text(
                'آخر قراءة:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              
              // Sensor readings grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2,
                children: [
                  _buildSensorTile(
                    'درجة الحرارة',
                    '${latestReading['temperature']?.toStringAsFixed(1)}°C',
                    Icons.thermostat,
                    Colors.red,
                  ),
                  _buildSensorTile(
                    'الرطوبة',
                    '${latestReading['humidity']?.toStringAsFixed(1)}%',
                    Icons.water_drop,
                    Colors.blue,
                  ),
                  _buildSensorTile(
                    'الوزن',
                    '${latestReading['weight']?.toStringAsFixed(1)} kg',
                    Icons.scale,
                    Colors.orange,
                  ),
                  _buildSensorTile(
                    'CO2',
                    '${latestReading['co2']?.toStringAsFixed(0)} ppm',
                    Icons.air,
                    Colors.green,
                  ),
                ],
              ),
            ] else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'لا توجد قراءات متاحة',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            
            if (hive['active_alerts_count'] != null && hive['active_alerts_count'] > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${hive['active_alerts_count']} تنبيهات نشطة',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Close Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE67E22),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'إغلاق',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String? status) {
    Color color;
    String text;
    
    switch (status) {
      case 'online':
        color = Colors.green;
        text = 'متصل';
        break;
      case 'offline':
        color = Colors.red;
        text = 'غير متصل';
        break;
      case 'never_connected':
        color = Colors.grey;
        text = 'لم يتصل';
        break;
      default:
        color = Colors.grey;
        text = 'غير معروف';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildSensorTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'خريطة الخلايا',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFFE67E22),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHives,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _filterStatus = value;
                _createMarkers();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('الكل')),
              const PopupMenuItem(value: 'online', child: Text('متصل')),
              const PopupMenuItem(value: 'offline', child: Text('غير متصل')),
              const PopupMenuItem(value: 'never_connected', child: Text('لم يتصل')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentCenter,
                    initialZoom: 6.0,
                    minZoom: 3.0,
                    maxZoom: 18.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.bee_admin',
                      maxZoom: 19,
                    ),
                    MarkerLayer(
                      markers: _markers,
                    ),
                  ],
                ),
                
                // Legend
                Positioned(
                  bottom: 20,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'الحالة:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildLegendItem(Colors.green, 'متصل'),
                        const SizedBox(height: 4),
                        _buildLegendItem(Colors.red, 'غير متصل'),
                        const SizedBox(height: 4),
                        _buildLegendItem(Colors.orange, 'لم يتصل'),
                      ],
                    ),
                  ),
                ),
                
                // Hive count
                Positioned(
                  top: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE67E22),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.hive,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_markers.length} خلية',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Zoom controls
                Positioned(
                  right: 20,
                  top: 100,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'zoom_in',
                        onPressed: () {
                          final currentZoom = _mapController.camera.zoom;
                          _mapController.move(
                            _mapController.camera.center,
                            currentZoom + 1,
                          );
                        },
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.add, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'zoom_out',
                        onPressed: () {
                          final currentZoom = _mapController.camera.zoom;
                          _mapController.move(
                            _mapController.camera.center,
                            currentZoom - 1,
                          );
                        },
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.remove, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'my_location',
                        onPressed: () {
                          _mapController.move(_currentCenter, 12);
                        },
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.my_location, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}
