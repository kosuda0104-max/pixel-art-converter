import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const PixelArtConverterApp());
}

class PixelArtConverterApp extends StatelessWidget {
  const PixelArtConverterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pixel Art Converter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

enum PixelSizeMode {
  normal,
  square,
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  Uint8List? _processedBytes;

  String selectedPreset = 'レトロ';
  int selectedDotSize = 32;
  int selectedColorCount = 16;
  bool isProcessing = false;
  bool showGrid = false;
  PixelSizeMode pixelSizeMode = PixelSizeMode.normal;

  int? _imageWidth;
  int? _imageHeight;

  final List<String> presets = <String>[
    'レトロ',
    'モノクロ',
    'ファミコン風',
    'ゲームボーイ風',
  ];

  final List<int> dotSizes = <int>[16, 32, 64, 128];
  final List<int> colorCounts = <int>[2, 4, 8, 16, 32];

  final List<List<int>> famicomPalette = <List<int>>[
    <int>[124, 124, 124],
    <int>[0, 0, 252],
    <int>[0, 0, 188],
    <int>[68, 40, 188],
    <int>[148, 0, 132],
    <int>[168, 0, 32],
    <int>[168, 16, 0],
    <int>[136, 20, 0],
    <int>[80, 48, 0],
    <int>[0, 120, 0],
    <int>[0, 104, 0],
    <int>[0, 88, 0],
    <int>[0, 64, 88],
    <int>[0, 0, 0],
    <int>[188, 188, 188],
    <int>[0, 120, 248],
    <int>[60, 188, 252],
    <int>[104, 136, 252],
    <int>[152, 120, 248],
    <int>[248, 120, 248],
    <int>[248, 88, 152],
    <int>[248, 120, 88],
    <int>[252, 160, 68],
    <int>[248, 184, 0],
    <int>[184, 248, 24],
    <int>[88, 216, 84],
    <int>[88, 248, 152],
    <int>[0, 232, 216],
    <int>[120, 120, 120],
    <int>[0, 0, 0],
    <int>[252, 252, 252],
  ];

  final List<List<int>> gameBoyPalette = <List<int>>[
    <int>[15, 56, 15],
    <int>[48, 98, 48],
    <int>[139, 172, 15],
    <int>[155, 188, 15],
  ];

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
      );

      if (pickedFile == null) {
        return;
      }

      final Uint8List bytes = await File(pickedFile.path).readAsBytes();
      final img.Image? decoded = img.decodeImage(bytes);

      setState(() {
        _selectedImage = File(pickedFile.path);
        _processedBytes = null;
        _imageWidth = decoded?.width;
        _imageHeight = decoded?.height;
      });
    } catch (e) {
      if (!mounted) return;
      _showMessage('画像選択に失敗しました: $e');
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  bool get _usesCustomColorCount {
    return selectedPreset == 'レトロ' || selectedPreset == 'モノクロ';
  }

  List<int> _nearestColor(int r, int g, int b, List<List<int>> palette) {
    int bestIndex = 0;
    int bestDistance = 1 << 30;

    for (int i = 0; i < palette.length; i++) {
      final List<int> color = palette[i];
      final int distance =
          (r - color[0]) * (r - color[0]) +
          (g - color[1]) * (g - color[1]) +
          (b - color[2]) * (b - color[2]);

      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }

    return palette[bestIndex];
  }

  int _quantizeValue(int value, int levels) {
    if (levels <= 1) {
      return 0;
    }

    final double step = 255 / (levels - 1);
    final int quantized = (value / step).round();
    final int result = (quantized * step).round();
    return result.clamp(0, 255);
  }

  img.Image _centerCropSquare(img.Image source) {
    final int cropSize = math.min(source.width, source.height);
    final int offsetX = ((source.width - cropSize) / 2).floor();
    final int offsetY = ((source.height - cropSize) / 2).floor();

    return img.copyCrop(
      source,
      x: offsetX,
      y: offsetY,
      width: cropSize,
      height: cropSize,
    );
  }

  img.Image _pixelate(img.Image source, int targetWidth) {
    final int safeTargetWidth = targetWidth.clamp(8, 256);

    if (pixelSizeMode == PixelSizeMode.square) {
      final img.Image square = _centerCropSquare(source);

      final img.Image small = img.copyResize(
        square,
        width: safeTargetWidth,
        height: safeTargetWidth,
        interpolation: img.Interpolation.average,
      );

      final img.Image enlarged = img.copyResize(
        small,
        width: square.width,
        height: square.height,
        interpolation: img.Interpolation.nearest,
      );

      return enlarged;
    }

    final int targetHeight = math.max(
      1,
      (source.height * safeTargetWidth / source.width).round(),
    );

    final img.Image small = img.copyResize(
      source,
      width: safeTargetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.average,
    );

    final img.Image enlarged = img.copyResize(
      small,
      width: source.width,
      height: source.height,
      interpolation: img.Interpolation.nearest,
    );

    return enlarged;
  }

  img.Image _autoContrast(img.Image image) {
    int minLuma = 255;
    int maxLuma = 0;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        final int luma =
            (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round().clamp(0, 255);

        if (luma < minLuma) minLuma = luma;
        if (luma > maxLuma) maxLuma = luma;
      }
    }

    if (maxLuma <= minLuma) {
      return image;
    }

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);

        int stretch(int value) {
          final double normalized = (value - minLuma) / (maxLuma - minLuma);
          return (normalized * 255).round().clamp(0, 255);
        }

        image.setPixelRgba(
          x,
          y,
          stretch(p.r.toInt()),
          stretch(p.g.toInt()),
          stretch(p.b.toInt()),
          p.a.toInt(),
        );
      }
    }

    return image;
  }

  img.Image _enhance(img.Image image) {
    image = img.adjustColor(
      image,
      contrast: 1.18,
      brightness: 1.02,
      saturation: 1.08,
    );
    image = _autoContrast(image);
    return image;
  }

  img.Image _applyDitherRgb(img.Image image, int levels) {
    for (int y = 0; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        final p = image.getPixel(x, y);

        final int oldR = p.r.toInt();
        final int oldG = p.g.toInt();
        final int oldB = p.b.toInt();

        final int newR = _quantizeValue(oldR, levels);
        final int newG = _quantizeValue(oldG, levels);
        final int newB = _quantizeValue(oldB, levels);

        image.setPixelRgba(x, y, newR, newG, newB, p.a.toInt());

        final int errR = oldR - newR;
        final int errG = oldG - newG;
        final int errB = oldB - newB;

        void spread(int dx, int dy, double factor) {
          final np = image.getPixel(x + dx, y + dy);

          final int r = (np.r + errR * factor).round().clamp(0, 255);
          final int g = (np.g + errG * factor).round().clamp(0, 255);
          final int b = (np.b + errB * factor).round().clamp(0, 255);

          image.setPixelRgba(x + dx, y + dy, r, g, b, np.a.toInt());
        }

        spread(1, 0, 7 / 16);
        spread(-1, 1, 3 / 16);
        spread(0, 1, 5 / 16);
        spread(1, 1, 1 / 16);
      }
    }

    return image;
  }

  List<List<int>> _buildAdaptivePalette(img.Image image, int paletteSize) {
    final Map<int, int> buckets = <int, int>{};

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);

        final int r = (p.r.toInt() ~/ 32) * 32;
        final int g = (p.g.toInt() ~/ 32) * 32;
        final int b = (p.b.toInt() ~/ 32) * 32;

        final int key = (r << 16) | (g << 8) | b;
        buckets[key] = (buckets[key] ?? 0) + 1;
      }
    }

    final List<MapEntry<int, int>> sorted = buckets.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final List<List<int>> palette = <List<int>>[];

    for (final entry in sorted.take(paletteSize)) {
      final int key = entry.key;
      palette.add(<int>[
        (key >> 16) & 0xFF,
        (key >> 8) & 0xFF,
        key & 0xFF,
      ]);
    }

    if (palette.isEmpty) {
      palette.add(<int>[0, 0, 0]);
    }

    return palette;
  }

  img.Image _applyAdaptivePalette(img.Image image, int paletteSize) {
    final List<List<int>> palette = _buildAdaptivePalette(image, paletteSize);

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final List<int> nearest = _nearestColor(
          pixel.r.toInt(),
          pixel.g.toInt(),
          pixel.b.toInt(),
          palette,
        );

        image.setPixelRgba(
          x,
          y,
          nearest[0],
          nearest[1],
          nearest[2],
          pixel.a.toInt(),
        );
      }
    }

    return image;
  }

  img.Image _applyPalette(img.Image image, List<List<int>> palette) {
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final List<int> nearest = _nearestColor(
          pixel.r.toInt(),
          pixel.g.toInt(),
          pixel.b.toInt(),
          palette,
        );

        image.setPixelRgba(
          x,
          y,
          nearest[0],
          nearest[1],
          nearest[2],
          pixel.a.toInt(),
        );
      }
    }

    return image;
  }

  img.Image _applyRetro(img.Image image, int colorCount) {
    img.Image work = _applyAdaptivePalette(image, colorCount);
    work = _applyDitherRgb(work, math.min(colorCount, 16));
    return work;
  }

  img.Image _applyMono(img.Image image, int colorCount) {
    final img.Image grayscale = img.grayscale(image);
    final img.Image contrasted = _autoContrast(grayscale);

    for (int y = 0; y < contrasted.height; y++) {
      for (int x = 0; x < contrasted.width; x++) {
        final pixel = contrasted.getPixel(x, y);
        final int gray = _quantizeValue(pixel.r.toInt(), colorCount);
        contrasted.setPixelRgba(x, y, gray, gray, gray, pixel.a.toInt());
      }
    }

    return contrasted;
  }

  img.Image _applyFamicom(img.Image image) {
    img.Image work = img.adjustColor(
      image,
      contrast: 1.18,
      saturation: 1.28,
      brightness: 1.0,
    );
    work = _autoContrast(work);
    work = _applyPalette(work, famicomPalette);
    return work;
  }

  img.Image _applyGameBoy(img.Image image) {
    img.Image work = img.grayscale(image);
    work = _autoContrast(work);

    for (int y = 0; y < work.height; y++) {
      for (int x = 0; x < work.width; x++) {
        final p = work.getPixel(x, y);
        final int gray = p.r.toInt();

        List<int> color;
        if (gray < 64) {
          color = gameBoyPalette[0];
        } else if (gray < 128) {
          color = gameBoyPalette[1];
        } else if (gray < 192) {
          color = gameBoyPalette[2];
        } else {
          color = gameBoyPalette[3];
        }

        work.setPixelRgba(
          x,
          y,
          color[0],
          color[1],
          color[2],
          p.a.toInt(),
        );
      }
    }

    return work;
  }


  img.Image _applyEdgeEnhance(img.Image image) {
    final img.Image source = img.Image.from(image);

    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        final center = source.getPixel(x, y);
        final left = source.getPixel(x - 1, y);
        final right = source.getPixel(x + 1, y);
        final top = source.getPixel(x, y - 1);
        final bottom = source.getPixel(x, y + 1);

        int edgeValue(int c, int l, int r, int t, int b) {
          final int gx = (r - l).abs();
          final int gy = (b - t).abs();
          final int edge = ((gx + gy) * 0.35).round().clamp(0, 40);
          return (c - edge).clamp(0, 255);
        }

        final int nr = edgeValue(
          center.r.toInt(),
          left.r.toInt(),
          right.r.toInt(),
          top.r.toInt(),
          bottom.r.toInt(),
        );
        final int ng = edgeValue(
          center.g.toInt(),
          left.g.toInt(),
          right.g.toInt(),
          top.g.toInt(),
          bottom.g.toInt(),
        );
        final int nb = edgeValue(
          center.b.toInt(),
          left.b.toInt(),
          right.b.toInt(),
          top.b.toInt(),
          bottom.b.toInt(),
        );

        image.setPixelRgba(x, y, nr, ng, nb, center.a.toInt());
      }
    }

    return image;
  }
  img.Image _applyPreset(img.Image image) {
    switch (selectedPreset) {
      case 'モノクロ':
        return _applyMono(image, selectedColorCount);
      case 'ファミコン風':
        return _applyFamicom(image);
      case 'ゲームボーイ風':
        return _applyGameBoy(image);
      case 'レトロ':
      default:
        return _applyRetro(image, selectedColorCount);
    }
  }

  Future<void> _convertImage() async {
    if (_selectedImage == null) {
      _showMessage('先に画像を選択してください');
      return;
    }

    try {
      setState(() {
        isProcessing = true;
      });

      final Uint8List bytes = await _selectedImage!.readAsBytes();
      final img.Image? decoded = img.decodeImage(bytes);

      if (decoded == null) {
        throw Exception('画像の読み込みに失敗しました');
      }

      img.Image result = _pixelate(decoded, selectedDotSize);
      result = _enhance(result);
      result = _applyPreset(result);

      final Uint8List pngBytes = Uint8List.fromList(img.encodePng(result));

      setState(() {
        _processedBytes = pngBytes;
        _imageWidth = result.width;
        _imageHeight = result.height;
      });

      if (!mounted) return;
      _showMessage('変換しました');
    } catch (e) {
      if (!mounted) return;
      _showMessage('変換に失敗しました: $e');
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  Future<void> _saveImage() async {
    if (_processedBytes == null) {
      _showMessage('先に変換してください');
      return;
    }

    try {
      final Directory dir = await getApplicationDocumentsDirectory();
      final String fileName =
          'pixel_art_${DateTime.now().millisecondsSinceEpoch}.png';
      final File file = File('${dir.path}/$fileName');

      await file.writeAsBytes(_processedBytes!);

      if (!mounted) return;
      _showMessage('保存しました: ${file.path}');
    } catch (e) {
      if (!mounted) return;
      _showMessage('保存に失敗しました: $e');
    }
  }

  Widget _buildImageWidget() {
    if (isProcessing) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_processedBytes != null) {
      return Image.memory(
        _processedBytes!,
        fit: BoxFit.contain,
      );
    }

    if (_selectedImage != null) {
      return Image.file(
        _selectedImage!,
        fit: BoxFit.contain,
      );
    }

    return const Center(
      child: Text(
        'ここに画像プレビュー',
        style: TextStyle(fontSize: 16),
      ),
    );
  }

  Widget _buildPreview() {
    if (_imageWidth == null || _imageHeight == null) {
      return _buildImageWidget();
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double containerWidth = constraints.maxWidth;
        final double containerHeight = constraints.maxHeight;
        final double imageAspect = _imageWidth! / _imageHeight!;
        final double containerAspect = containerWidth / containerHeight;

        double drawWidth;
        double drawHeight;

        if (imageAspect > containerAspect) {
          drawWidth = containerWidth;
          drawHeight = drawWidth / imageAspect;
        } else {
          drawHeight = containerHeight;
          drawWidth = drawHeight * imageAspect;
        }

        final int rows = pixelSizeMode == PixelSizeMode.square
            ? selectedDotSize
            : math.max(
                1,
                (_imageHeight! * selectedDotSize / _imageWidth!).round(),
              );

        return Stack(
          children: [
            Center(
              child: SizedBox(
                width: drawWidth,
                height: drawHeight,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildImageWidget(),
                ),
              ),
            ),
            if (showGrid)
              Center(
                child: IgnorePointer(
                  child: SizedBox(
                    width: drawWidth,
                    height: drawHeight,
                    child: CustomPaint(
                      painter: PixelGridPainter(
                        columns: selectedDotSize,
                        rows: rows,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _presetHintText() {
    switch (selectedPreset) {
      case 'モノクロ':
        return '白黒ベースで階調を残して変換します';
      case 'ファミコン風':
        return '8bitカラー風の固定カラーに変換します';
      case 'ゲームボーイ風':
        return '明暗を4段階に分けて緑4色に変換します';
      case 'レトロ':
      default:
        return '画像に合った代表色へ減色してドット感を強めます';
    }
  }

  String _colorCountLabel() {
    switch (selectedPreset) {
      case 'ファミコン風':
        return '固定カラー';
      case 'ゲームボーイ風':
        return '4色固定';
      default:
        return '色の数';
    }
  }

  String _sizeLabelText() {
    return pixelSizeMode == PixelSizeMode.square ? 'サイズ' : '横のドット数';
  }

  String _sizeOptionText(int size) {
    return pixelSizeMode == PixelSizeMode.square
        ? '${size}×${size}'
        : '横${size}ドット';
  }

  String _modeDescriptionText() {
    return pixelSizeMode == PixelSizeMode.square
        ? '中央を基準に正方形へ切り取って変換します'
        : '横だけ固定し、縦は画像に合わせて自動調整します';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ドット絵変換アプリ'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade100,
              ),
              child: _buildPreview(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: isProcessing ? null : _pickImage,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_library_outlined),
                    SizedBox(width: 8),
                    Text('画像を選ぶ'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('ドットの枠を表示'),
              subtitle: const Text('ドットの区切りが見えるようになります'),
              value: showGrid,
              onChanged: (bool value) {
                setState(() {
                  showGrid = value;
                });
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'モード',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SegmentedButton<PixelSizeMode>(
              segments: const <ButtonSegment<PixelSizeMode>>[
                ButtonSegment<PixelSizeMode>(
                  value: PixelSizeMode.normal,
                  label: Text('通常'),
                ),
                ButtonSegment<PixelSizeMode>(
                  value: PixelSizeMode.square,
                  label: Text('正方形'),
                ),
              ],
              selected: <PixelSizeMode>{pixelSizeMode},
              onSelectionChanged: (Set<PixelSizeMode> value) {
                setState(() {
                  pixelSizeMode = value.first;
                });
              },
            ),
            const SizedBox(height: 8),
            Text(
              _modeDescriptionText(),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            const Text(
              'プリセット',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            DropdownButton<String>(
              value: selectedPreset,
              isExpanded: true,
              items: presets
                  .map(
                    (String preset) => DropdownMenuItem<String>(
                      value: preset,
                      child: Text(preset),
                    ),
                  )
                  .toList(),
              onChanged: isProcessing
                  ? null
                  : (String? value) {
                      if (value == null) return;
                      setState(() {
                        selectedPreset = value;
                      });
                    },
            ),
            const SizedBox(height: 4),
            Text(
              _presetHintText(),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Text(
              _sizeLabelText(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            DropdownButton<int>(
              value: selectedDotSize,
              isExpanded: true,
              items: dotSizes
                  .map(
                    (int size) => DropdownMenuItem<int>(
                      value: size,
                      child: Text(_sizeOptionText(size)),
                    ),
                  )
                  .toList(),
              onChanged: isProcessing
                  ? null
                  : (int? value) {
                      if (value == null) return;
                      setState(() {
                        selectedDotSize = value;
                      });
                    },
            ),
            const SizedBox(height: 24),
            Text(
              _colorCountLabel(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            DropdownButton<int>(
              value: selectedColorCount,
              isExpanded: true,
              items: colorCounts
                  .map(
                    (int count) => DropdownMenuItem<int>(
                      value: count,
                      child: Text('${count}色'),
                    ),
                  )
                  .toList(),
              onChanged: isProcessing || !_usesCustomColorCount
                  ? null
                  : (int? value) {
                      if (value == null) return;
                      setState(() {
                        selectedColorCount = value;
                      });
                    },
            ),
            if (!_usesCustomColorCount)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  selectedPreset == 'ファミコン風'
                      ? 'このプリセットは固定カラーを使います'
                      : 'このプリセットは4色固定です',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: isProcessing ? null : _convertImage,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_fix_high, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'ドット絵に変換する',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: (_processedBytes == null || isProcessing)
                    ? null
                    : _saveImage,
                child: const Text('保存する'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PixelGridPainter extends CustomPainter {
  final int columns;
  final int rows;

  PixelGridPainter({
    required this.columns,
    required this.rows,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..strokeWidth = 1;

    final double cellWidth = size.width / columns;
    final double cellHeight = size.height / rows;

    for (int i = 0; i <= columns; i++) {
      final double x = i * cellWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (int j = 0; j <= rows; j++) {
      final double y = j * cellHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant PixelGridPainter oldDelegate) {
    return oldDelegate.columns != columns || oldDelegate.rows != rows;
  }
}




