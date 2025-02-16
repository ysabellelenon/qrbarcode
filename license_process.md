# License Activation Process

## Overview
This document outlines the license activation process for the QR Barcode application. The application is designed to work offline after initial activation, with internet connectivity required only for the first-time license activation. All valid licenses are lifetime/indefinite, with no expiration date or duration limits.

## Process Flow

### 1. First-Time App Launch
- When the app is launched for the first time, it checks the local database for stored license information
- If no license is found locally, the app displays the license activation screen
- Internet connectivity is required for this step to access Firestore

### 2. License Activation Screen
- Users must enter their license key that was emailed to them by the developer
- The system automatically detects and includes the hardware ID of the device
- Both the license key and hardware ID are required for activation

### 3. Firestore Validation Process
- The application connects to Firestore to validate the license
- Simple validation criteria:
  - Checks if Document ID (license key) exists in Firestore
  - Checks if hardware_id field is null (indicating license hasn't been used)
- Validation rules:
  - If the license key (Document ID) is not found: Activation fails
  - If the license key is found but has a hardware_id: Activation fails (already in use)
  - If the license key is found and hardware_id is null: Activation proceeds
- No additional checks needed for:
  - License duration
  - Expiration date
  - License status
  - Any other fields

### 4. License Activation
- Upon finding a valid, unused license:
  - The hardware_id field is updated in Firestore for that license
  - The license key is stored in the local database
  - User is notified of successful activation

### 5. Subsequent App Usage
- For all subsequent app launches:
  - App checks local database for license information
  - No internet connection required
  - App functions fully offline

## Technical Implementation Notes

### Firestore Operation
The license validation and update uses a simple transaction to check and update the hardware_id:

```dart
// Simplified Firestore operation for lifetime licenses
Future<bool> activateLicense(String licenseKey, String hardwareId) async {
  try {
    return await FirebaseFirestore.instance.runTransaction((transaction) async {
      final licenseDoc = await transaction.get(
        FirebaseFirestore.instance.collection('licenses').doc(licenseKey)
      );

      if (!licenseDoc.exists) {
        throw 'Invalid license key';
      }

      if (licenseDoc.data()['hardware_id'] != null) {
        throw 'License already in use';
      }

      // Update only the hardware_id
      transaction.update(licenseDoc.reference, {
        'hardware_id': hardwareId
      });

      return true;
    });
  } catch (e) {
    return false;
  }
}
```

### Local Storage
Simple local storage of just the essential information:

```dart
// Minimal local storage for lifetime license
await database.insert('licenses', {
  'license_key': licenseKey,
  'hardware_id': hardwareId
});
```

## Error Handling

The following error scenarios should be handled:
1. No internet connection during activation
2. Invalid license key
3. License already in use
4. Database errors (both Firestore and local)
5. Hardware ID mismatch on subsequent launches

## Security Considerations

1. All communication with Firestore should be secured
2. Hardware ID generation should be consistent and unique
3. Local license storage should be encrypted
4. Implement measures to prevent tampering with local license data 