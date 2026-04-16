import 'package:wsa_new/models/emergency_alert.dart';
import 'package:wsa_new/services/location_service.dart';
import 'package:wsa_new/services/sms_service.dart';
import 'package:wsa_new/services/camera_service.dart';
import 'package:wsa_new/services/api_service.dart';

class EmergencyService {
  static Future<void> triggerAlert({
    required String userId,
    required String userName,
    required List<String> guardianPhones,
  }) async {
    print('Starting Emergency Sequence...');
    
    // 0. Update safety status to NOT safe
    await ApiService().updateSafeStatus(userId, false);

    // 1. Get Location
    final position = await LocationService.getCurrentLocation();
    if (position == null) {
      print('Could not get location');
      return;
    }

    // 2. Capture Photos (Front & Back)
    final photos = await CameraService.captureEmergencyPhotos();

    // 3. Save to API Server to get URLs
    final alert = EmergencyAlert(
      id: '', // Server handles ID
      userId: userId,
      userName: userName,
      latitude: position.latitude,
      longitude: position.longitude,
      imageBase64List: photos,
      timestamp: DateTime.now(),
    );

    final savedAlert = await ApiService().saveAlert(alert);

    // 4. Send SMS to all guardians
    print('🚨 SOS: Found ${guardianPhones.length} guardians to alert.');
    
    // Get the back camera link. Usually back camera is index 0 in captureEmergencyPhotos.
    String? backCameraUrl;
    if (savedAlert != null && savedAlert.imageBase64List.isNotEmpty) {
      final host = ApiService.baseUrl.replaceFirst('/api', '');
      backCameraUrl = host + savedAlert.imageBase64List[0];
    }

    int successCount = 0;
    for (String phone in guardianPhones) {
      final success = await SMSService.sendSOS(
        phone, 
        position.latitude, 
        position.longitude, 
        imageUrl: backCameraUrl
      );
      if (success) successCount++;
    }
    print('🚨 SOS: Total SMS messages sent: $successCount / ${guardianPhones.length}');
    print('Emergency Alert Package Processed!');
  }

  static Future<void> triggerSilentPhoto({
    required String userId,
    required String userName,
    required bool isFront,
  }) async {
    print('Starting Remote Silent Capture (Front: $isFront)...');

    // 1. Get Location
    final position = await LocationService.getCurrentLocation();
    if (position == null) {
      print('Could not get location');
      return;
    }

    // 2. Capture specific photo
    final photo = await CameraService.captureSpecificCamera(isFront: isFront);
    if (photo == null) {
      print('Could not capture photo');
      return;
    }

    // 3. Save to API Server (no SMS sent)
    final alert = EmergencyAlert(
      id: '',
      userId: userId,
      userName: userName,
      latitude: position.latitude,
      longitude: position.longitude,
      imageBase64List: [photo],
      timestamp: DateTime.now(),
    );

    await ApiService().saveAlert(alert);
    print('Remote Photo Request Processed and Saved!');
  }

  static Future<void> triggerSilentLocation({
    required String userId,
    required String userName,
  }) async {
    print('Starting Remote Silent Location...');

    // 1. Get Location
    final position = await LocationService.getCurrentLocation();
    if (position == null) {
      print('Could not get location');
      return;
    }

    // 2. Save Location Alert to API Server (no images)
    final alert = EmergencyAlert(
      id: '',
      userId: userId,
      userName: userName,
      latitude: position.latitude,
      longitude: position.longitude,
      imageBase64List: [],
      timestamp: DateTime.now(),
    );

    await ApiService().saveAlert(alert);
    print('Remote Location Request Processed and Saved!');
  }
}
