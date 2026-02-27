import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import 'devices_page.dart';

final supabase = Supabase.instance.client;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _userName = 'User';
  List<Map<String, dynamic>> _houses = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadHouses();
  }

  Future<void> _loadUserProfile() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final profile = await supabase
            .from('user_profiles')
            .select('full_name')
            .eq('id', userId)
            .single();

        setState(() {
          _userName = profile['full_name'] ?? 'User';
        });
      }
    } catch (e) {
      print('Error loading profile: $e');
    }
  }

  Future<void> _loadHouses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get all houses the user has access to
      final response = await supabase
          .from('houses')
          .select('id, name, address, city, state, thumbnail_url, description')
          .eq('is_active', true)
          .order('name');

      setState(() {
        _houses = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    final authService = AuthService(supabase);
    await authService.signOut();
  }

  void _navigateToDevices(Map<String, dynamic> house) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DevicesPage(house: house),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Houses'),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading houses',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _loadHouses,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _houses.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.home, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'No houses found',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Contact your administrator to get access to houses.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadHouses,
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 300,
                          childAspectRatio: 0.85,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: _houses.length,
                        itemBuilder: (context, index) {
                          final house = _houses[index];
                          return _buildHouseCard(house);
                        },
                      ),
                    ),
    );
  }

  Widget _buildHouseCard(Map<String, dynamic> house) {
    final thumbnailUrl = house['thumbnail_url'] as String?;
    final name = house['name'] as String;
    final address = house['address'] as String?;
    final city = house['city'] as String?;
    final state = house['state'] as String?;

    String locationText = '';
    if (address != null) locationText += address;
    if (city != null && state != null) {
      if (locationText.isNotEmpty) locationText += '\n';
      locationText += '$city, $state';
    }

    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _navigateToDevices(house),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail
            Expanded(
              flex: 3,
              child: thumbnailUrl != null && thumbnailUrl.isNotEmpty
                  ? Image.network(
                      thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: const Color(0xFF667eea).withOpacity(0.1),
                          child: const Icon(
                            Icons.home,
                            size: 64,
                            color: Color(0xFF667eea),
                          ),
                        );
                      },
                    )
                  : Container(
                      color: const Color(0xFF667eea).withOpacity(0.1),
                      child: const Icon(
                        Icons.home,
                        size: 64,
                        color: Color(0xFF667eea),
                      ),
                    ),
            ),
            // House info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (locationText.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        locationText,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Devices Page (moveOmeters in a house)
