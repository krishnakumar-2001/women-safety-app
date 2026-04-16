import 'package:telephony/telephony.dart';

class SMSService {
  static final Telephony _telephony = Telephony.instance;

  static Future<bool> sendSOS(
    String phoneNumber,
    double lat,
    double lon, {
    String? imageUrl,
  }) async {
    try {
      bool? permissionsGranted = await _telephony.requestPhoneAndSmsPermissions;
      print('🔍 SMS: Permissions Granted: $permissionsGranted');

      if (permissionsGranted == true) {
        final googleMapsUrl =
            'https://www.google.com/maps/search/?api=1&query=$lat,$lon';
        String message = ' $googleMapsUrl';
        if (imageUrl != null) {
          message += ' Back Camera: $imageUrl';
        }

        await _telephony.sendSms(to: phoneNumber, message: message);
        print('✅ SMS: Sent successfully to $phoneNumber');
        return true;
      } else {
        print('❌ SMS: Permissions denied by user.');
        return false;
      }
    } catch (e) {
      print('💥 SMS: CRITICAL ERROR sending to $phoneNumber: $e');
      return false;
    }
  }
}
