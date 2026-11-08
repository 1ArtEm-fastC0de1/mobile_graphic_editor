import 'package:flutter/material.dart';
import 'theme.dart';
import '../screens/home/home_screen.dart';

class GraphicEditorApp extends StatelessWidget {
  const GraphicEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Графічний редактор',
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}