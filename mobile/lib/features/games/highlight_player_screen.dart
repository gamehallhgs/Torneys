import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../widgets/gh_widgets.dart';
import 'game_models.dart';

/// Reprodutor simples de um vídeo de destaque (até 1 minuto).
class HighlightPlayerScreen extends StatefulWidget {
  const HighlightPlayerScreen({super.key, required this.highlight});

  final Highlight highlight;

  @override
  State<HighlightPlayerScreen> createState() => _HighlightPlayerScreenState();
}

class _HighlightPlayerScreenState extends State<HighlightPlayerScreen> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final uri = Uri.parse(widget.highlight.url);
      if (uri.scheme != 'https' && uri.scheme != 'http') {
        throw FormatException('Endereço inválido: ${widget.highlight.url}');
      }
      final controller = VideoPlayerController.networkUrl(uri);
      _controller = controller;
      controller.addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
      await controller.initialize();
      await controller.setLooping(false);
      await controller.play();
      if (mounted) {
        setState(() {});
      }
    } catch (e, st) {
      debugPrint('[GameHall] vídeo falhou: $e\n$st');
      if (mounted) {
        setState(() => _failed = true);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final ready = c != null && c.value.isInitialized && !_failed;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(widget.highlight.title ?? 'Destaque',
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: Center(
          child: _failed
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: GhBanner.error('Não foi possível reproduzir o vídeo. Verifica a ligação e tenta novamente.'),
                )
              : !ready
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AspectRatio(
                          aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
                          child: VideoPlayer(c),
                        ),
                        VideoProgressIndicator(c, allowScrubbing: true),
                        const SizedBox(height: 12),
                        IconButton(
                          iconSize: 48,
                          tooltip: c.value.isPlaying ? 'Pausa' : 'Reproduzir',
                          icon: Icon(c.value.isPlaying ? Icons.pause_circle : Icons.play_circle),
                          onPressed: () {
                            if (c.value.isPlaying) {
                              c.pause();
                            } else if (c.value.position >= c.value.duration) {
                              c.seekTo(Duration.zero).then((_) => c.play());
                            } else {
                              c.play();
                            }
                          },
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
