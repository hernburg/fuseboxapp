import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/palette.dart';

class FakeProgress extends StatefulWidget {
  final Duration minDelay;
  final String message;
  final Future<void> Function() task;
  final VoidCallback onDone;
  const FakeProgress({
    super.key,
    required this.task,
    required this.onDone,
    this.minDelay = const Duration(seconds: 11),
    this.message = 'Считаем… оптимизируем…',
  });

  @override
  State<FakeProgress> createState() => _FakeProgressState();
}

class _FakeProgressState extends State<FakeProgress> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  double _p = 0;

  @override
  void initState() {
    super.initState();
    // «растущий» прогресс
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return false;
      setState(() => _p = min(1.0, _p + 0.03 + Random().nextDouble() * 0.04));
      return _p < .94;
    });

    Future.wait([widget.task(), Future.delayed(widget.minDelay)]).then((_) {
      if (!mounted) return;
      setState(() => _p = 1);
      Future.delayed(const Duration(milliseconds: 400), widget.onDone);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kBg,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RotationTransition(
                turns: _c,
                child: const Icon(Icons.sync, size: 42, color: kWhite),
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _p < .98 ? _p : null,
                minHeight: 6,
                color: kWhite,
                backgroundColor: Colors.white24,
              ),
              const SizedBox(height: 12),
              Text(widget.message, style: const TextStyle(color: kWhite)),
            ],
          ),
        ),
      ),
    );
  }
}