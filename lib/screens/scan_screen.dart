import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../services/ocr_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/big_button.dart';
import 'ocr_edit_screen.dart';

/// 2. 教科書スキャン画面。
/// カメラ起動・撮影・再撮影・OCR実行・撮影ガイド枠。
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  CameraController? _controller;
  Future<void>? _initFuture;
  final OcrService _ocr = OcrService();

  String? _capturedPath; // 撮影した画像
  bool _processing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'カメラが みつかりませんでした');
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );
      _initFuture = controller.initialize();
      await _initFuture;
      if (mounted) setState(() => _controller = controller);
    } catch (e) {
      if (mounted) setState(() => _error = 'カメラを ひらけませんでした: $e');
    }
  }

  Future<void> _capture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      final file = await c.takePicture();
      setState(() => _capturedPath = file.path);
    } catch (e) {
      setState(() => _error = 'しゃしんが とれませんでした: $e');
    }
  }

  void _retake() {
    setState(() {
      _capturedPath = null;
      _error = null;
    });
  }

  Future<void> _runOcr() async {
    final path = _capturedPath;
    if (path == null) return;
    setState(() => _processing = true);
    try {
      final text = await _ocr.recognizeFromFile(path);
      // camera が返すファイルはキャッシュ上にあり、OS が掃除することがあります。
      // OCR 結果と紐付ける画像はアプリ専用領域へコピーして残します。
      final savedImagePath = await _keepCapturedImage(path);
      if (!mounted) return;
      final saved = await context.read<AppState>().createText(
            title: '',
            body: text,
            sourceImagePath: savedImagePath,
          );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OcrEditScreen(
            existing: saved,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _error = 'よみとりに しっぱいしました: $e';
        _processing = false;
      });
    }
  }

  Future<String> _keepCapturedImage(String path) async {
    final documents = await getApplicationDocumentsDirectory();
    final imageDir =
        Directory('${documents.path}${Platform.pathSeparator}scans');
    await imageDir.create(recursive: true);

    final source = File(path);
    final extension =
        path.contains('.') ? path.substring(path.lastIndexOf('.')) : '.jpg';
    final fileName = 'scan_${DateTime.now().microsecondsSinceEpoch}$extension';
    return (await source
            .copy('${imageDir.path}${Platform.pathSeparator}$fileName'))
        .path;
  }

  @override
  void dispose() {
    _controller?.dispose();
    _ocr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('きょうかしょを とる',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.black,
      ),
      body: _error != null
          ? _buildError()
          : _capturedPath != null
              ? _buildPreview()
              : _buildCamera(),
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sentiment_satisfied_alt,
                  color: Colors.white, size: 60),
              const SizedBox(height: 16),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 18)),
              const SizedBox(height: 24),
              BigButton(
                  label: 'もどる', onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
      );

  Widget _buildCamera() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(c),
        // 撮影ガイド枠
        _buildGuideFrame(),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('わくの中に ぶんしょうを いれてね',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _capture,
                  child: Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primary, width: 6),
                    ),
                    child: const Icon(Icons.camera_alt,
                        color: AppTheme.primary, size: 34),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuideFrame() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 90),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.accent, width: 4),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(File(_capturedPath!), fit: BoxFit.contain),
        if (_processing)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text('もじを よみとっているよ…',
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
            ),
          ),
        if (!_processing)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: BigButton(
                      label: 'とりなおす',
                      icon: Icons.refresh,
                      color: AppTheme.secondary,
                      onPressed: _retake,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BigButton(
                      label: 'よみとる',
                      icon: Icons.text_fields,
                      onPressed: _runOcr,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
