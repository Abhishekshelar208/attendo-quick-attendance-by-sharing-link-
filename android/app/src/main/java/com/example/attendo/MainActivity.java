package com.example.attendo;

import android.bluetooth.BluetoothAdapter;
import android.os.Build;
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.attendo/bluetooth";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
            .setMethodCallHandler(
                (call, result) -> {
                    if (call.method.equals("setBluetoothName")) {
                        String name = call.argument("name");
                        boolean success = setBluetoothName(name);
                        result.success(success);
                    } else if (call.method.equals("getBluetoothName")) {
                        String name = getBluetoothName();
                        result.success(name);
                    } else {
                        result.notImplemented();
                    }
                }
            );
    }

    private boolean setBluetoothName(String name) {
        try {
            BluetoothAdapter bluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
            if (bluetoothAdapter == null) {
                return false;
            }
            
            // For Android 12+ (API 31+), we need BLUETOOTH_CONNECT permission
            // This should already be granted via the manifest and runtime permissions
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // Check if we have the permission
                if (checkSelfPermission(android.Manifest.permission.BLUETOOTH_CONNECT) 
                    != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                    return false;
                }
            }
            
            bluetoothAdapter.setName(name);
            return true;
        } catch (SecurityException e) {
            e.printStackTrace();
            return false;
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    private String getBluetoothName() {
        try {
            BluetoothAdapter bluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
            if (bluetoothAdapter == null) {
                return null;
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (checkSelfPermission(android.Manifest.permission.BLUETOOTH_CONNECT) 
                    != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                    return null;
                }
            }
            
            return bluetoothAdapter.getName();
        } catch (SecurityException e) {
            e.printStackTrace();
            return null;
        } catch (Exception e) {
            e.printStackTrace();
            return null;
        }
    }
}
