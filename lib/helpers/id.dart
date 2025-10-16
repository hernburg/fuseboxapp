// lib/helpers/id.dart
import 'dart:math';

String rid() => Random().nextInt(1 << 32).toString();