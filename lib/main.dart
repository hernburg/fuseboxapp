import 'package:flutter/material.dart';
import 'screens/projects_home.dart';
import 'theme/palette.dart';
import 'screens/calculator_screen.dart';
import 'screens/log_viewer.dart';   // ← 💛 добавлено

void main() {
  ErrorWidget.builder = (FlutterErrorDetails d) =>
      MaterialApp(home: Scaffold(body: Center(child: Text(d.exceptionAsString()))));
  FlutterError.onError = (d) { FlutterError.dumpErrorToConsole(d); };
  runApp(const FuseboxApp());
}

class FuseboxApp extends StatelessWidget {
  const FuseboxApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'GOST',
        scaffoldBackgroundColor: kBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kGradA,
          brightness: Brightness.dark,
        ).copyWith(
          surface: kBg,
          onSurface: kWhite,
          primary: kGradA,
          onPrimary: kWhite,
        ),
        textTheme: const TextTheme().apply(
          fontFamily: 'GOST',
          bodyColor: kWhite,
          displayColor: kWhite,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kBg,
          foregroundColor: kWhite,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'GOST',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: kWhite,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white.withValues(alpha: 0.08),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: const TextStyle(fontFamily: 'GOST', color: kWhite),
          hintStyle:  const TextStyle(fontFamily: 'GOST', color: kWhite),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: kWhite.withValues(alpha: 0.35)),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: kWhite, width: 1.4),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: kBg,
          indicatorColor: kWhite.withValues(alpha: .12),
          iconTheme: const WidgetStatePropertyAll(IconThemeData(color: kWhite)),
          labelTextStyle: const WidgetStatePropertyAll(
            TextStyle(fontFamily: 'GOST', color: kWhite),
          ),
        ),
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _idx = 0;

  late final List<Widget> _pages = [
    const ProjectsHome(),
    const CalculatorScreen(),
    const _Stub(title: 'Редактор'),
    const _Stub(title: 'Профиль'),
  ];

  @override
  Widget build(BuildContext context) {
    if (_idx >= _pages.length) _idx = _pages.length - 1;

    return Scaffold(
      body: IndexedStack(index: _idx, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) =>
            setState(() => _idx = i.clamp(0, _pages.length - 1).toInt()),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.folder), label: 'Проекты'),
          NavigationDestination(icon: Icon(Icons.calculate), label: 'Калькулятор'),
          NavigationDestination(icon: Icon(Icons.developer_board), label: 'Редактор'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Профиль'),
        ],
      ),
    );
  }
}

class _Stub extends StatelessWidget {
  final String title;
  const _Stub({required this.title});
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text(title)), body: const Center(child: Text('MVP')));
  }
}
