import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wsa_new/providers/app_state.dart';
import 'package:wsa_new/services/api_service.dart';
import 'package:wsa_new/services/emergency_service.dart';
import 'package:wsa_new/models/app_user.dart';
import 'package:flutter/services.dart';
import 'package:wsa_new/services/voice_service.dart';
import 'package:wsa_new/theme/app_theme.dart';
import 'package:wsa_new/services/notification_service.dart';

class UserHomeWrapper extends StatefulWidget {
  const UserHomeWrapper({Key? key}) : super(key: key);

  @override
  State<UserHomeWrapper> createState() => _UserHomeWrapperState();
}

class _UserHomeWrapperState extends State<UserHomeWrapper> {
  int _currentIndex = 0;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _startCommandPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startCommandPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      final appState = Provider.of<AppState>(context, listen: false);
      final user = appState.currentUser;
      if (user == null) return;

      final commands = await ApiService().getPendingCommands(user.id);
      
      // Safety Check: If user is safe, do NOT process any remote commands.
      // This ensures Guardians can only trigger camera/location during active SOS.
      if (user.isSafe) return;

      for (var cmd in commands) {
        final String type = cmd['commandType'];
        if (type == 'CAPTURE_FRONT' || type == 'CAPTURE_BACK') {
          final isFront = type == 'CAPTURE_FRONT';
          await EmergencyService.triggerSilentPhoto(
            userId: user.id,
            userName: user.name,
            isFront: isFront,
          );
          await ApiService().markCommandDone(cmd['_id']);
        } else if (type == 'CAPTURE_LOCATION') {
          await EmergencyService.triggerSilentLocation(
            userId: user.id,
            userName: user.name,
          );
          await ApiService().markCommandDone(cmd['_id']);
        }
      }
    });
  }

  final List<Widget> _pages = [
    const UserEmergencyPage(),
    const UserContactsPage(),
    const UserProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05), width: 1)),
        ),
        child: BottomNavigationBar(
          backgroundColor: AppTheme.backgroundColor,
          selectedItemColor: AppTheme.primaryColor,
          unselectedItemColor: Colors.white38,
          currentIndex: _currentIndex,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.home_outlined),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.home),
              ),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.contact_phone_outlined),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.contact_phone),
              ),
              label: 'Contacts',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.person_outline),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.person),
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class UserEmergencyPage extends StatefulWidget {
  const UserEmergencyPage({Key? key}) : super(key: key);

  @override
  State<UserEmergencyPage> createState() => _UserEmergencyPageState();
}

class _UserEmergencyPageState extends State<UserEmergencyPage> {
  late VoiceTriggerService _voiceService;

  @override
  void initState() {
    super.initState();
    _voiceService = VoiceTriggerService(onTriggered: _triggerEmergency);
  }

  void _triggerEmergency() {
    final appState = Provider.of<AppState>(context, listen: false);
    
    // ⚠️ CRITICAL: DO NOT TRIGGER SOS IMMEDIATELY
    // Show high-priority notification with 5s countdown
    NotificationService.showSOSCountdown(
      onCancel: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SOS Alert CANCELLED'),
            backgroundColor: Colors.grey,
          ),
        );
      },
      onComplete: () {
        // Set status to NOT safe to activate SOS UI and remote control
        appState.updateSafeStatus(false);

        EmergencyService.triggerAlert(
          userId: appState.currentUser?.id ?? 'guest_id',
          userName: appState.currentUser?.name ?? 'Guest',
          guardianPhones: appState.guardianPhones,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SOS Alert Sent to Guardians!'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = appState.currentUser;
    final bool isEmergency = user?.isSafe == false;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Women Safety App'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Status Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: BoxDecoration(
                  color: isEmergency ? const Color(0xFF450A0A) : const Color(0xFF064E3B).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isEmergency ? Colors.redAccent : const Color(0xFF22C55E).withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isEmergency ? Icons.warning_amber_rounded : Icons.shield,
                      color: isEmergency ? Colors.redAccent : const Color(0xFF22C55E),
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEmergency ? 'EMERGENCY ACTIVE' : 'Status: You are Safe',
                      style: TextStyle(
                        fontSize: 16,
                        color: isEmergency ? Colors.redAccent : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 80),

              // SOS Button
              GestureDetector(
                onTap: _triggerEmergency,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFEF4444),
                        const Color(0xFF991B1B),
                      ],
                      center: Alignment.center,
                      radius: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEF4444).withOpacity(0.35),
                        blurRadius: 50,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.touch_app, size: 70, color: Colors.white),
                        const SizedBox(height: 12),
                        const Text(
                          'EMERGENCY',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 80),

              // Bottom Cards
              Row(
                children: [
                  // Voice SOS Button (Always Visible)
                  Expanded(
                    flex: isEmergency ? 1 : 2,
                    child: GestureDetector(
                      onTap: () => setState(() => _voiceService.toggleListening()),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        decoration: BoxDecoration(
                          color: AppTheme.cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _voiceService.isListening ? AppTheme.secondaryColor : Colors.white.withOpacity(0.05),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _voiceService.isListening ? Icons.mic : Icons.mic_none,
                              color: _voiceService.isListening ? AppTheme.secondaryColor : Colors.white70,
                              size: 32,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Voice SOS',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _voiceService.isListening ? 'Listening...' : 'Keyword: "HELP"',
                              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  if (isEmergency) ...[
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async => await appState.updateSafeStatus(true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF064E3B).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.2)),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 32),
                              SizedBox(height: 12),
                              Text(
                                'I am Safe',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Clear Alert',
                                style: TextStyle(fontSize: 12, color: Colors.white38),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class UserContactsPage extends StatelessWidget {
  const UserContactsPage({Key? key}) : super(key: key);

  void _showContactDialog(BuildContext context, {dynamic contact}) {
    final nameController = TextEditingController(text: contact?.name ?? '');
    final phoneController = TextEditingController(text: contact?.phone ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24, right: 24, top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              contact == null ? 'Add Guardian' : 'Edit Guardian',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(hintText: 'Guardian Name', prefixIcon: Icon(Icons.person_outline)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(hintText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined)),
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                if (phoneController.text.length != 10) return;
                final appState = Provider.of<AppState>(context, listen: false);
                if (contact == null) {
                  appState.addContact(nameController.text, phoneController.text);
                } else {
                  contact.name = nameController.text;
                  contact.phone = phoneController.text;
                  await appState.updateContact(contact);
                }
                Navigator.pop(context);
              },
              child: Text(contact == null ? 'Add Guardian' : 'Save Changes'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Guardians'),
      ),
      body: appState.contacts.isEmpty
          ? const Center(
              child: Text(
                'No guardians added yet.\nAdd someone you trust.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: appState.contacts.length,
              itemBuilder: (context, index) {
                final contact = appState.contacts[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: const CircleAvatar(
                      backgroundColor: AppTheme.primaryColor,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    title: Text(contact.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(contact.phone, style: const TextStyle(color: Colors.white38)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: AppTheme.secondaryColor),
                          onPressed: () => _showContactDialog(context, contact: contact),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppTheme.primaryColor),
                          onPressed: () => appState.removeContact(contact.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showContactDialog(context),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class UserProfilePage extends StatelessWidget {
  const UserProfilePage({Key? key}) : super(key: key);

  void _showEditProfile(BuildContext context, AppUser user) {
    final nameController = TextEditingController(text: user.name);
    final emailController = TextEditingController(text: user.email);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24, right: 24, top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Edit Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(hintText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(hintText: 'Email ID', prefixIcon: Icon(Icons.email_outlined)),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                final appState = Provider.of<AppState>(context, listen: false);
                await appState.updateProfile(nameController.text, emailController.text, user.phone);
                Navigator.pop(context);
              },
              child: const Text('Save Changes'),
            ),
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
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50, 
                    backgroundColor: AppTheme.primaryColor,
                    child: Icon(Icons.person, size: 55, color: Colors.white),
                  ),
                  const SizedBox(height: 32),
                  _buildProfileTile('User Name', user.name, Icons.person_outline),
                  _buildProfileTile('Email', user.email, Icons.email_outlined),
                  _buildProfileTile('Phone', user.phone, Icons.phone_outlined),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _showEditProfile(context, user),
                      child: const Text('Change Details'),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'ACCOUNT MANAGEMENT',
                      style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          onTap: () {
                            appState.logout();
                            Navigator.pushReplacementNamed(context, '/roles');
                          },
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
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
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
        content: const Text('This will permanently delete your profile and emergency data.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await appState.deleteAccount();
              Navigator.pushReplacementNamed(context, '/roles');
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
