import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart'; // Import for kIsWeb

class QRScannerScreen extends StatefulWidget {
  final Function(String) onQRCodeScanned;
  const QRScannerScreen({Key? key, required this.onQRCodeScanned})
    : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen>
    with WidgetsBindingObserver {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool isScanning = true;
  bool hasPermission = false;
  // Text controller for mobile code input dialog
  final TextEditingController _mobileCodeController = TextEditingController();

  // Check if running on desktop platform (Windows, macOS, Linux)
  bool get isDesktop =>
      kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!isDesktop) {
      _requestCameraPermission();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    _mobileCodeController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (controller == null) return;

    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        controller?.resumeCamera();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      controller?.pauseCamera();
    } else if (state == AppLifecycleState.detached) {
      controller?.dispose();
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller?.pauseCamera();
    }
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && controller != null) {
        controller!.resumeCamera();
      }
    });
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (mounted) {
      setState(() {
        hasPermission = status.isGranted;
      });

      if (!hasPermission) {
        _showPermissionDeniedAlert();
      }
    }
  }

  void _showPermissionDeniedAlert() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Camera Permission Required'),
            content: const Text(
              'This app needs camera access to scan QR codes. Please grant camera permission in your device settings.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(
                    context,
                  ).pop(); // Return to previous screen (MainMenuScreen)
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.resumeCamera();
    controller.scannedDataStream.listen((scanData) {
      if (!isScanning || !mounted) return;

      setState(() {
        isScanning = false;
      });
      controller.pauseCamera();
      widget.onQRCodeScanned(scanData.code ?? "");
      // Navigator.of(context).pop(scanData.code); // Pop with the scanned code
    });
  }

  void _showEnterCodeDialog() {
    _mobileCodeController.clear();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Enter Room ID Manually'),
            content: TextField(
              controller: _mobileCodeController,
              decoration: const InputDecoration(hintText: 'Enter Room ID'),
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  if (_mobileCodeController.text.trim().isNotEmpty) {
                    widget.onQRCodeScanned(_mobileCodeController.text.trim());
                    // Navigator.of(context).pop(_mobileCodeController.text.trim());
                  }
                },
                child: const Text('Join'),
              ),
            ],
          ),
    );
  }

  void _showInvalidQRCodeMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
    setState(() {
      isScanning = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (controller != null && mounted) {
        controller!.resumeCamera();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isDesktop ? 'Enter Room ID' : 'Scan QR Code'),
        actions: [
          if (!isDesktop) ...[
            IconButton(
              icon: const Icon(Icons.keyboard),
              onPressed: _showEnterCodeDialog,
              tooltip: 'Enter Room ID Manually',
            ),
            IconButton(
              icon: const Icon(Icons.flash_on),
              onPressed:
                  hasPermission
                      ? () async => await controller?.toggleFlash()
                      : null,
            ),
            IconButton(
              icon: const Icon(Icons.flip_camera_ios),
              onPressed:
                  hasPermission
                      ? () async => await controller?.flipCamera()
                      : null,
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          if (!isDesktop) ...[
            if (hasPermission)
              QRView(
                key: qrKey,
                onQRViewCreated: _onQRViewCreated,
                overlay: QrScannerOverlayShape(
                  borderColor: Colors.red,
                  borderRadius: 10,
                  borderLength: 30,
                  borderWidth: 10,
                  cutOutSize: MediaQuery.of(context).size.width * 0.8,
                ),
                formatsAllowed: const [BarcodeFormat.qrcode],
              )
            else
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Camera permission is required to scan QR codes. Please grant permission in settings.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
          ] else
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller:
                        _mobileCodeController, // Re-using for desktop input
                    decoration: const InputDecoration(
                      labelText: 'Enter Room ID',
                      border: OutlineInputBorder(),
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, letterSpacing: 2),
                    textCapitalization: TextCapitalization.characters,
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        widget.onQRCodeScanned(value.trim());
                        // Navigator.of(context).pop(value.trim());
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      if (_mobileCodeController.text.trim().isNotEmpty) {
                        widget.onQRCodeScanned(
                          _mobileCodeController.text.trim(),
                        );
                        // Navigator.of(context).pop(_mobileCodeController.text.trim());
                      }
                    },
                    child: const Text('Join Room'),
                  ),
                ],
              ),
            ),
          if (!isDesktop && hasPermission)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.all(8.0),
                color: Colors.black54,
                child: const Text(
                  'Align QR code within the frame to scan',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
