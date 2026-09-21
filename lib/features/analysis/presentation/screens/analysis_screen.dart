import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:fieldapp/core/database/database_service.dart';
import '../../../calibration/domain/calibration_result.dart';
import '../../data/kit_repository.dart';
import '../../domain/analysis_result.dart';
import '../../domain/color_classifier.dart';
import '../../domain/hsv_extractor.dart';
import '../../providers/analysis_providers.dart';
import '../../domain/cnn_classifier.dart';
import '../../domain/fusion_service.dart';
import '../../domain/fusion_result.dart';
import '../../domain/saliency_generator.dart';
import '../../domain/tflite_service.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'dart:io';

class AnalysisScreen extends ConsumerStatefulWidget {
  final CalibrationResult calibrationResult;

  const AnalysisScreen({super.key, required this.calibrationResult});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  String? _selectedKitId;
  FusionResult? _fusionResult;
  bool _isAnalyzing = false;
  
  bool _saliencyLoading = false;
  String? _gradCamImagePath;

  double _greenThreshold = 0.8;
  double _yellowThreshold = 0.5;

  late final TFLiteService _tfliteService;

  @override
  void initState() {
    super.initState();
    _tfliteService = TFLiteService();
    _loadPreferences();
    _loadPersistedKit();
  }

  @override
  void dispose() {
    _tfliteService.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final db = await DatabaseService().database;
    final greenResult = await db.query('app_preferences', where: 'key = ?', whereArgs: ['confidence_green_threshold']);
    if (greenResult.isNotEmpty) {
      _greenThreshold = double.tryParse(greenResult.first['value'] as String) ?? 0.8;
    }
    final yellowResult = await db.query('app_preferences', where: 'key = ?', whereArgs: ['confidence_yellow_threshold']);
    if (yellowResult.isNotEmpty) {
      _yellowThreshold = double.tryParse(yellowResult.first['value'] as String) ?? 0.5;
    }
  }

  Future<void> _loadPersistedKit() async {
    final db = await DatabaseService().database;
    final result = await db.query('app_preferences', where: 'key = ?', whereArgs: ['last_kit_id']);
    if (result.isNotEmpty && mounted) {
      setState(() {
        _selectedKitId = result.first['value'] as String;
      });
      _runAnalysisIfReady();
    }
  }

  Future<void> _savePersistedKit(String kitId) async {
    final db = await DatabaseService().database;
    await db.insert('app_preferences', {'key': 'last_kit_id', 'value': kitId}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _runAnalysisIfReady() async {
    if (_selectedKitId == null) return;
    
    final kits = ref.read(availableKitsProvider).value;
    if (kits == null) return;
    
    final kit = kits.firstWhere((k) => k.kitId == _selectedKitId, orElse: () => kits.first);

    setState(() {
      _isAnalyzing = true;
      _gradCamImagePath = null;
      _saliencyLoading = false;
    });
    
    try {
      final bytes = await File(widget.calibrationResult.calibratedImagePath).readAsBytes();
      final calibratedMat = cv.imdecode(bytes, 1);
      
      // 1. HSV Analysis
      final extractor = HsvExtractor();
      final extracted = extractor.extract(calibratedMat);
      
      final colorClassifier = ColorClassifier();
      final hsvResult = colorClassifier.classify(
        kit.kitId, 
        kit, 
        extracted.hsv, 
        extracted.lab, 
        widget.calibrationResult,
      );
      
      // 2. CNN Analysis
      final cnnClassifier = CnnClassifier(_tfliteService);
      final cnnResult = await cnnClassifier.classify(calibratedMat, kit.kitId);
      
      // 3. Fusion
      final fusionService = FusionService();
      final fusionResult = fusionService.classify(hsvResult, cnnResult, kit.version, "1.0.0");
      
      if (mounted) {
        setState(() {
          _fusionResult = fusionResult;
          _isAnalyzing = false;
        });
      }

      // 4. Async Saliency
      if (cnnResult != null) {
        setState(() => _saliencyLoading = true);
        final saliencyGenerator = SaliencyGenerator(cnnClassifier);
        saliencyGenerator.generate(calibratedMat, kit.kitId).then((path) {
          if (mounted) {
            setState(() {
              _gradCamImagePath = path;
              _saliencyLoading = false;
            });
          }
        });
      }
      
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  Color _hsvToFlutterColor(List<double> hsvOpenCV) {
    return HSVColor.fromAHSV(
      1.0,
      (hsvOpenCV[0] * 2.0).clamp(0.0, 360.0),
      (hsvOpenCV[1] / 255.0).clamp(0.0, 1.0),
      (hsvOpenCV[2] / 255.0).clamp(0.0, 1.0),
    ).toColor();
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
  
  Color _getConfidenceColor(double confidence) {
    if (confidence >= _greenThreshold) return Colors.green;
    if (confidence >= _yellowThreshold) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final kitsAsync = ref.watch(availableKitsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Analysis & Fusion')),
      body: kitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
        data: (kits) {
          if (kits.isEmpty) {
            return const Center(child: Text('No kits found.'));
          }
          
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                value: _selectedKitId,
                decoration: const InputDecoration(labelText: 'Select Kit'),
                items: kits.map((kit) {
                  final enabled = kit.references.isNotEmpty;
                  return DropdownMenuItem(
                    value: kit.kitId,
                    enabled: enabled,
                    child: Text(enabled ? kit.kitName : '${kit.kitName} (coming soon)'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedKitId = val;
                    });
                    _savePersistedKit(val);
                    _runAnalysisIfReady();
                  }
                },
              ),
              const SizedBox(height: 24),
              if (_isAnalyzing)
                const Center(child: CircularProgressIndicator())
              else if (_fusionResult != null)
                _buildResults(_fusionResult!),
            ],
          );
        },
      ),
    );
  }

  Widget _buildResults(FusionResult result) {
    if (result.hsvResult.topMatches.isEmpty) {
      return const Text('No reference data available for this kit.', style: TextStyle(color: Colors.red));
    }

    final detectedColor = _hsvToFlutterColor(result.hsvResult.extractedHSV);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (result.isInconclusive)
          Container(
            color: Colors.red.withOpacity(0.2),
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            child: const Text('INCONCLUSIVE RESULT: Conflicting or low-quality data', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
          )
        else if (result.isUnknown)
          Container(
            color: Colors.orange.withOpacity(0.2),
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            child: const Text('UNKNOWN SUBSTANCE', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Final Decision: ${result.finalSubstance}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: result.finalConfidence,
                          minHeight: 12,
                          color: _getConfidenceColor(result.finalConfidence),
                          backgroundColor: Colors.grey[300],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${(result.finalConfidence * 100).toStringAsFixed(1)}%'),
                  ],
                ),
                if (result.isSingleLayerFallback)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text('Model absent. Single-layer (HSV) fallback used.', style: TextStyle(color: Colors.orange, fontStyle: FontStyle.italic)),
                  ),
                const Divider(height: 32),
                
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const Text('HSV Detected'),
                          const SizedBox(height: 4),
                          Container(height: 50, color: detectedColor),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          Text(result.hsvResult.topMatches.first.substance),
                          const SizedBox(height: 4),
                          Container(height: 50, color: _hexToColor(result.hsvResult.topMatches.first.colorHex)),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                const Text('Saliency Heatmap:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_saliencyLoading)
                  const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                else if (_gradCamImagePath != null)
                  Center(child: Image.file(File(_gradCamImagePath!), height: 150, fit: BoxFit.contain))
                else
                  const Center(child: Text('No heatmap available')),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            // Placeholder for Part 07 Record construction
          },
          child: const Text('Confirm & Proceed'),
        ),
      ],
    );
  }
}
