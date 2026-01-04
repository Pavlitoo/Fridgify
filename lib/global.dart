import 'package:flutter/material.dart';

// Глобальні змінні для стану додатку
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
final ValueNotifier<String> languageNotifier = ValueNotifier('Українська');