import 'package:bee_admin/api_service.dart';
import 'package:flutter/material.dart';

class UserDetailsPage extends StatefulWidget {
  final int userId;
  final String userName;

  const UserDetailsPage({
    Key? key,
    required this.userId,
    required this.userName,
  }) : super(key: key);

  @override
  State<UserDetailsPage> createState() => _UserDetailsPageState();
}

class _UserDetailsPageState extends State<UserDetailsPage> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _hives = [];

  @override
  void initState() {
    super.initState();
    _loadUserHives();
  }

  Future<void> _loadUserHives() async {
    setState(() => _isLoading = true);
    try {
      final hives = await _apiService.getUserHives(widget.userId);
      setState(() {
        _hives = hives;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      
      // Show detailed error in debug mode
      String errorMessage = 'خطأ في تحميل الخلايا';
      if (e.toString().contains('Failed to load user hives')) {
        errorMessage = 'فشل تحميل بيانات الخلايا. تأكد من اتصال الخادم.';
      }
      
      print('Error loading user hives: $e'); // Debug print
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          action: SnackBarAction(
            label: 'إعادة المحاولة',
            onPressed: _loadUserHives,
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _showAddHiveDialog() {
    final hiveIdController = TextEditingController();
    final nameController = TextEditingController();
    final latitudeController = TextEditingController();
    final longitudeController = TextEditingController();
    bool isActive = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة خلية جديدة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: hiveIdController,
                  decoration: const InputDecoration(
                    labelText: 'معرف الخلية',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الخلية',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: latitudeController,
                  decoration: const InputDecoration(
                    labelText: 'خط العرض',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: longitudeController,
                  decoration: const InputDecoration(
                    labelText: 'خط الطول',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('نشط'),
                  value: isActive,
                  onChanged: (value) {
                    setDialogState(() {
                      isActive = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (hiveIdController.text.isEmpty || nameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى ملء الحقول المطلوبة')),
                  );
                  return;
                }

                try {
                  final hiveData = {
                    'hive_id': hiveIdController.text,
                    'name': nameController.text,
                    'is_active': isActive,
                    'owner_id': widget.userId,
                  };

                  // Add latitude/longitude only if provided
                  if (latitudeController.text.isNotEmpty) {
                    hiveData['latitude'] = double.parse(latitudeController.text);
                  }
                  if (longitudeController.text.isNotEmpty) {
                    hiveData['longitude'] = double.parse(longitudeController.text);
                  }

                  await _apiService.addHive(hiveData);
                  Navigator.pop(context);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم إضافة الخلية بنجاح'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  
                  // Reload hives after a short delay
                  await Future.delayed(const Duration(milliseconds: 500));
                  _loadUserHives();
                } catch (e) {
                  print('Error adding hive: $e'); // Debug print
                  Navigator.pop(context); // Close dialog first
                  
                  String errorMsg = 'خطأ في إضافة الخلية';
                  if (e.toString().contains('Status: 403')) {
                    errorMsg = 'ليس لديك صلاحيات لإضافة خلايا. يجب أن تكون مدير.';
                  } else if (e.toString().contains('Status: 400')) {
                    errorMsg = 'بيانات غير صحيحة. تحقق من المدخلات.';
                  }
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(errorMsg),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.userName,
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddHiveDialog,
        backgroundColor: const Color(0xFFE67E22),
        icon: const Icon(Icons.add),
        label: const Text('إضافة خلية'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserHives,
              child: _hives.isEmpty
                  ? const Center(
                      child: Text('لا يوجد خلايا لهذا المستخدم'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _hives.length,
                      itemBuilder: (context, index) {
                        final hive = _hives[index];
                        return _buildHiveCard(hive);
                      },
                    ),
            ),
    );
  }

  Widget _buildHiveCard(Map<String, dynamic> hiveData) {
    // Handle both direct hive data and nested structure
    final hive = hiveData['hive'] ?? hiveData;
    final latestReading = hive['latest_reading'];
    final status = hive['status'] ?? 'unknown';
    final activeAlerts = hive['active_alerts_count'] ?? 0;
    final sensorStats = hiveData['sensor_stats'];

    Color statusColor;
    String statusText;
    switch (status) {
      case 'online':
        statusColor = Colors.green;
        statusText = 'متصل';
        break;
      case 'offline':
        statusColor = Colors.red;
        statusText = 'غير متصل';
        break;
      case 'never_connected':
        statusColor = Colors.grey;
        statusText = 'لم يتصل أبدا';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'غير معروف';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hive['name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hive['hive_id'] ?? '',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (latestReading != null) ...[
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'آخر قراءة:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildSensorValue(
                      'درجة الحرارة',
                      '${latestReading['temperature']?.toStringAsFixed(1)}°C',
                      Icons.thermostat,
                    ),
                  ),
                  Expanded(
                    child: _buildSensorValue(
                      'الرطوبة',
                      '${latestReading['humidity']?.toStringAsFixed(1)}%',
                      Icons.water_drop,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildSensorValue(
                      'الوزن',
                      '${latestReading['weight']?.toStringAsFixed(1)} kg',
                      Icons.scale,
                    ),
                  ),
                  Expanded(
                    child: _buildSensorValue(
                      'CO2',
                      '${latestReading['co2']?.toStringAsFixed(0)} ppm',
                      Icons.air,
                    ),
                  ),
                ],
              ),
              if (sensorStats != null) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                const Text(
                  'إحصائيات المستشعرات:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                _buildStatsRow(
                  'درجة الحرارة',
                  sensorStats['temperature'],
                  '°C',
                ),
                const SizedBox(height: 8),
                _buildStatsRow(
                  'الرطوبة',
                  sensorStats['humidity'],
                  '%',
                ),
                const SizedBox(height: 8),
                _buildStatsRow(
                  'الوزن',
                  sensorStats['weight'],
                  'kg',
                ),
              ],
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
            if (activeAlerts > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
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
                      '$activeAlerts تنبيهات نشطة',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSensorValue(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: Colors.grey[700]),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(String label, Map<String, dynamic>? stats, String unit) {
    if (stats == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('متوسط', stats['avg'], unit, Colors.blue),
              _buildStatItem('أدنى', stats['min'], unit, Colors.green),
              _buildStatItem('أعلى', stats['max'], unit, Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, dynamic value, String unit, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${value?.toStringAsFixed(1) ?? 'N/A'}$unit',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}