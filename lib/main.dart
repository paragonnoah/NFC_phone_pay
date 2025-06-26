import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NFC Phone Pay',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.greenAccent,
        scaffoldBackgroundColor: const Color(0xFF18191A),
        fontFamily: 'FiraMono', // Use a monospace/hacker font if available
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.greenAccent, fontFamily: 'FiraMono'),
          bodyLarge: TextStyle(color: Colors.greenAccent, fontFamily: 'FiraMono'),
          titleLarge: TextStyle(color: Colors.greenAccent, fontFamily: 'FiraMono'),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF101010),
          titleTextStyle: TextStyle(color: Colors.greenAccent, fontFamily: 'FiraMono', fontSize: 22),
          iconTheme: IconThemeData(color: Colors.greenAccent),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.greenAccent,
          foregroundColor: Colors.black,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: MaterialStatePropertyAll(Colors.greenAccent),
            foregroundColor: MaterialStatePropertyAll(Colors.black),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF23272A),
          border: OutlineInputBorder(),
          labelStyle: TextStyle(color: Colors.greenAccent),
        ),
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}