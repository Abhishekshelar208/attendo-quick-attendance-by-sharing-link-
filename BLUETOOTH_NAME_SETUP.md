# Bluetooth Device Name Setup

## Overview
This feature automatically sets the teacher's Bluetooth device name to **"Attendo: Teachers Device"** when they activate Bluetooth for attendance sessions. This makes it much easier for students to identify the correct teacher device among many Bluetooth devices.

## Implementation Details

### 1. Flutter Service Layer
**File:** `lib/services/bluetooth_name_service.dart`

This service provides a platform channel to communicate with native Android code for setting/getting the Bluetooth device name.

### 2. Native Android Implementation
**File:** `android/app/src/main/java/com/example/attendo/MainActivity.java`

The native Android code uses the `BluetoothAdapter` API to:
- Set the device Bluetooth name
- Get the current Bluetooth name
- Handle Android 12+ (API 31+) permission requirements

### 3. UI Integration
**File:** `lib/pages/ShareAttendanceScreen.dart`

When the teacher clicks "Activate Bluetooth":
1. Bluetooth permissions are requested
2. Bluetooth adapter state is checked
3. Device name is set to "Attendo: Teachers Device"
4. Firebase is updated with `bluetooth_active: true`
5. UI displays the device name for reference

## User Experience

### Before Activation
- Teacher sees an info card explaining the device will be renamed
- Clear message: "Your device will be renamed to: 'Attendo: Teachers Device'"
- Warning to ensure Bluetooth is ON and discoverable

### After Activation
- Success message confirms Bluetooth is active
- Device name is displayed prominently: "Attendo: Teachers Device"
- Students are informed to look for this specific name

### For Students
- When scanning for Bluetooth devices, students will see "Attendo: Teachers Device" instead of random device names
- Easy identification reduces confusion and connection errors

## Android Permissions Required

The following permissions in `AndroidManifest.xml` enable this feature:

```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

## Technical Notes

### Android Version Compatibility
- **Android 11 and below:** Uses legacy Bluetooth permissions
- **Android 12+ (API 31+):** Uses new granular Bluetooth permissions (BLUETOOTH_CONNECT, BLUETOOTH_SCAN, BLUETOOTH_ADVERTISE)

### Error Handling
- If the name cannot be set (due to permissions or device limitations), the app continues normally
- A warning is logged but doesn't block the Bluetooth activation
- The feature gracefully degrades to using the device's default name

### Device Name Persistence
- The Bluetooth name change persists even after the app is closed
- Teachers may want to manually restore their original device name after the session
- This is a system-level change, not app-specific

## Testing

To test this feature:

1. **Build and install the app** on the teacher's Android device
2. **Navigate to Create Attendance** and start a session
3. **Click "Activate Bluetooth"** in the session screen
4. **Check the device name**:
   - Open device Settings → Bluetooth
   - Verify the device name shows "Attendo: Teachers Device"
5. **Student side**: Scan for Bluetooth devices and confirm "Attendo: Teachers Device" appears

## Future Enhancements

Possible improvements:
- Option for teacher to customize the device name
- Automatic restoration of original device name when session ends
- Support for iOS devices (requires different implementation)
- Display teacher's name in the Bluetooth device name (e.g., "Attendo: Prof. Smith")
