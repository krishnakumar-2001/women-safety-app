import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wsa_new/providers/app_state.dart';
import 'package:wsa_new/services/api_service.dart';
import 'package:wsa_new/models/app_user.dart';
import 'package:wsa_new/models/emergency_alert.dart';
import 'dart:convert';
import 'dart:async';
import 'package:wsa_new/theme/app_theme.dart';

class GuardianHomeWrapper extends StatefulWidget {
  const GuardianHomeWrapper({Key? key}) : super(key: key);

  @override
  State<GuardianHomeWrapper> createState() => _GuardianHomeWrapperState();
}

class _GuardianHomeWrapperState extends State<GuardianHomeWrapper> {
  int _currentIndex = 0;
  Timer? _pollingTimer;
  Map<String, bool> _previousSafetyStatus = {};
  bool _isInit = true;

  @override
  void initState() {
    super.initState();
    _startEmergencyPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startEmergencyPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      final appState = Provider.of<AppState>(context, listen: false);
      final currentUser = appState.currentUser;
      if (currentUser == null) return;

      try {
        final users = await ApiService().fetchProtectedUsers(currentUser.phone);
        for (var user in users) {
          final wasSafe = _previousSafetyStatus[user.id] ?? true;
          if (wasSafe && !user.isSafe && !_isInit) {
            _showEmergencyNotification(user);
          }
          _previousSafetyStatus[user.id] = user.isSafe;
        }
        _isInit = false;
      } catch (e) {
        print("Guardian Polling Error: $e");
      }
    });
  }

  void _showEmergencyNotification(AppUser user) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF7F1D1D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white, size: 30),
            SizedBox(width: 10),
            Text('EMERGENCY ALERT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          '${user.name} has triggered an emergency alert! Please check their location immediately.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('DISMISS', style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _currentIndex = 1);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF7F1D1D)),
            child: const Text('VIEW GALLERY'),
          ),
        ],
      ),
    );
  }

  final List<Widget> _pages = [
    const GuardianControlPage(),
    const GuardianGalleryPage(),
    const GuardianProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppTheme.backgroundColor,
        selectedItemColor: AppTheme.primaryColor,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.settings_remote_outlined), activeIcon: Icon(Icons.settings_remote), label: 'Control'),
          BottomNavigationBarItem(icon: Icon(Icons.photo_library_outlined), activeIcon: Icon(Icons.photo_library), label: 'Gallery'),
          BottomNavigationBarItem(icon: Icon(Icons.person_pin_outlined), activeIcon: Icon(Icons.person_pin), label: 'Profile'),
        ],
      ),
    );
  }
}

class GuardianControlPage extends StatefulWidget {
  const GuardianControlPage({Key? key}) : super(key: key);

  @override
  State<GuardianControlPage> createState() => _GuardianControlPageState();
}

class _GuardianControlPageState extends State<GuardianControlPage> {
  late Future<List<AppUser>> _protectedUsersFuture;

  @override
  void initState() {
    super.initState();
    _refreshUsers();
  }

  void _refreshUsers() {
    final currentUser = Provider.of<AppState>(context, listen: false).currentUser;
    _protectedUsersFuture = ApiService().fetchProtectedUsers(currentUser!.phone);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Remote Control')),
      body: FutureBuilder<List<AppUser>>(
        future: _protectedUsersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('You are not guarding anyone yet.', style: TextStyle(color: Colors.white38)));
          }

          final users = snapshot.data!;
          return ListView.builder(
            itemCount: users.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final user = users[index];
              final isEmergency = !user.isSafe;
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isEmergency ? Colors.redAccent.withOpacity(0.5) : Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        radius: 25,
                        backgroundColor: isEmergency ? const Color(0xFF450A0A) : const Color(0xFF064E3B).withOpacity(0.3),
                        child: Icon(isEmergency ? Icons.warning : Icons.shield, color: isEmergency ? Colors.redAccent : Colors.greenAccent),
                      ),
                      title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      subtitle: Text(user.phone, style: const TextStyle(color: Colors.white38)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isEmergency ? Colors.redAccent.withOpacity(0.1) : Colors.greenAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isEmergency ? "EMERGENCY" : "SAFE",
                          style: TextStyle(color: isEmergency ? Colors.redAccent : Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 10),
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: Colors.white10),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildRemoteAction(context, user, 'CAPTURE_FRONT', Icons.camera_front, 'Front Cam'),
                          _buildRemoteAction(context, user, 'CAPTURE_BACK', Icons.camera_rear, 'Rear Cam'),
                          _buildRemoteAction(context, user, 'CAPTURE_LOCATION', Icons.location_on, 'Location'),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _refreshUsers()),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  Widget _buildRemoteAction(BuildContext context, AppUser user, String cmd, IconData icon, String label) {
    return TextButton.icon(
      onPressed: !user.isSafe
          ? () async {
              final currentUser = Provider.of<AppState>(context, listen: false).currentUser;
              await ApiService().sendCommand(user.id, cmd, currentUser!.phone);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Request sent to ${user.name}')));
            }
          : () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User is marked as SAFE.'))),
      icon: Icon(icon, size: 20, color: user.isSafe ? Colors.white24 : AppTheme.secondaryColor),
      label: Text(label, style: TextStyle(color: user.isSafe ? Colors.white24 : Colors.white70, fontSize: 12)),
    );
  }
}

class GuardianGalleryPage extends StatefulWidget {
  const GuardianGalleryPage({Key? key}) : super(key: key);

  @override
  State<GuardianGalleryPage> createState() => _GuardianGalleryPageState();
}

class _GuardianGalleryPageState extends State<GuardianGalleryPage> {
  late Future<List<EmergencyAlert>> _alertsFuture;

  @override
  void initState() {
    super.initState();
    _refreshAlerts();
  }

  void _refreshAlerts() {
    final currentUser = Provider.of<AppState>(context, listen: false).currentUser;
    _alertsFuture = ApiService().fetchGuardianAlerts(currentUser!.phone);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Emergency Gallery')),
      body: FutureBuilder<List<EmergencyAlert>>(
        future: _alertsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No emergency images found yet.', style: TextStyle(color: Colors.white38)));
          }

          final alerts = snapshot.data!;
          return ListView.builder(
            itemCount: alerts.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final alert = alerts[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      title: Text('Alert by ${alert.userName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Time: ${alert.timestamp.toLocal().toString().split('.')[0]}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.white24),
                        onPressed: () => _confirmDelete(alert.id),
                      ),
                    ),
                    if (alert.imageBase64List.isNotEmpty)
                      SizedBox(
                        height: 180,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: alert.imageBase64List.length,
                          itemBuilder: (context, imgIndex) {
                            final imgData = alert.imageBase64List[imgIndex];
                            final isNetwork = imgData.startsWith('/images');
                            final host = ApiService.baseUrl.replaceFirst('/api', '');
                            final fullUrl = host + imgData;

                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => FullScreenImageViewer(imageUrl: isNetwork ? fullUrl : null, base64Data: isNetwork ? null : imgData))),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: isNetwork 
                                    ? Image.network(fullUrl, fit: BoxFit.cover, width: 140, errorBuilder: (c, e, s) => const Icon(Icons.broken_image))
                                    : Image.memory(base64Decode(imgData), fit: BoxFit.cover, width: 140),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: InkWell(
                        onTap: () async {
                          final url = 'https://www.google.com/maps/search/?api=1&query=${alert.latitude},${alert.longitude}';
                          if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.blueAccent.withOpacity(0.3))),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.map, color: Colors.blueAccent, size: 20),
                              SizedBox(width: 10),
                              Text('View Location on Google Maps', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _refreshAlerts()),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Delete Alert?'),
        content: const Text('This will permanently delete this alert record.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () async {
            await ApiService().deleteAlert(id);
            Navigator.pop(context);
            _refreshAlerts();
          }, child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final String? imageUrl;
  final String? base64Data;
  const FullScreenImageViewer({Key? key, this.imageUrl, this.base64Data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(
        child: InteractiveViewer(
          child: imageUrl != null ? Image.network(imageUrl!, fit: BoxFit.contain) : Image.memory(base64Decode(base64Data!), fit: BoxFit.contain),
        ),
      ),
    );
  }
}

class GuardianProfilePage extends StatelessWidget {
  const GuardianProfilePage({Key? key}) : super(key: key);

  void _showEditProfile(BuildContext context, AppUser user) {
    final nameController = TextEditingController(text: user.name);
    final emailController = TextEditingController(text: user.email);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Edit Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextField(controller: nameController, decoration: const InputDecoration(hintText: 'Full Name', prefixIcon: Icon(Icons.person_outline))),
            const SizedBox(height: 16),
            TextField(controller: emailController, decoration: const InputDecoration(hintText: 'Email ID', prefixIcon: Icon(Icons.email_outlined))),
            const SizedBox(height: 32),
            ElevatedButton(onPressed: () async {
              await Provider.of<AppState>(context, listen: false).updateProfile(nameController.text, emailController.text, user.phone);
              Navigator.pop(context);
            }, child: const Text('Save Changes')),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = appState.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Guardian Profile')),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const CircleAvatar(radius: 55, backgroundColor: AppTheme.primaryColor, child: Icon(Icons.security, size: 55, color: Colors.white)),
                  const SizedBox(height: 32),
                  _buildProfileTile('Guardian Name', user.name, Icons.person_outline),
                  _buildProfileTile('Email', user.email, Icons.email_outlined),
                  _buildProfileTile('Phone', user.phone, Icons.phone_outlined),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(onPressed: () => _showEditProfile(context, user), child: const Text('Change Details')),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      children: [
                        ListTile(
                          onTap: () { appState.logout(); Navigator.pushReplacementNamed(context, '/login'); },
                          leading: const Icon(Icons.logout, color: AppTheme.secondaryColor),
                          title: const Text('Logout'),
                          trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                        ),
                        const Divider(height: 1, color: Colors.white10, indent: 50),
                        ListTile(
                          onTap: () => _confirmDeleteAccount(context, appState),
                          leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                          title: const Text('Delete Account', style: TextStyle(color: Colors.redAccent)),
                          trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileTile(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Delete Account?'),
        content: const Text('This will permanently delete your profile.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () async { await appState.deleteAccount(); Navigator.pushReplacementNamed(context, '/'); }, child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
  }
}
