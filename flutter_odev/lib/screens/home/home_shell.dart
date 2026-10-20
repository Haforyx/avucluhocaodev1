import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/pomodoro_engine.dart';
import '../../state/focus_controller.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import '../courses/courses_screen.dart';
import '../focus/focus_screen.dart';
import '../stats/stats_screen.dart';
import '../tasks/tasks_screen.dart';
import 'dashboard_screen.dart';

/// Sekmeler.
enum HomeTab { dashboard, tasks, focus, courses, stats }

/// Giriş sonrası alt menülü ana iskelet.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  HomeTab _tab = HomeTab.dashboard;
  StreamSubscription<FocusEvent>? _focusEvents;

  @override
  void initState() {
    super.initState();
    _focusEvents = context.read<FocusController>().events.listen(_onFocusEvent);
  }

  @override
  void dispose() {
    _focusEvents?.cancel();
    super.dispose();
  }

  void _goTo(HomeTab tab) => setState(() => _tab = tab);

  /// Odak/mola bitince hangi sekmede olunursa olunsun bildirim göster.
  void _onFocusEvent(FocusEvent event) {
    if (!mounted) return;
    final r = event.result;
    final String message;
    if (r.phase == FocusPhase.focus) {
      message = event.session == null
          ? 'Odak bitti.'
          : '${formatMinutes(event.session!.minutes)} çalışma kaydedildi. ${event.nextPhase.label} zamanı!';
    } else {
      message = 'Mola bitti, yeni bir odağa hazır mısın?';
    }
    showSnack(
      context,
      message,
      action: _tab == HomeTab.focus
          ? null
          : SnackBarAction(label: 'Sayaca git', onPressed: () => _goTo(HomeTab.focus)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final focusRunning = context.select<FocusController, bool>((f) => f.isRunning);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: IndexedStack(
          index: _tab.index,
          children: [
            DashboardScreen(onNavigate: _goTo),
            const TasksScreen(),
            const FocusScreen(),
            const CoursesScreen(),
            const StatsScreen(),
          ],
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
          ),
          child: NavigationBar(
            selectedIndex: _tab.index,
            onDestinationSelected: (i) => _goTo(HomeTab.values[i]),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Ana Sayfa',
              ),
              const NavigationDestination(
                icon: Icon(Icons.task_alt_outlined),
                selectedIcon: Icon(Icons.task_alt_rounded),
                label: 'Görevler',
              ),
              NavigationDestination(
                // Sayaç çalışırken sekmede küçük bir nokta görünür.
                icon: Badge(isLabelVisible: focusRunning, smallSize: 8, child: const Icon(Icons.timer_outlined)),
                selectedIcon: Badge(
                  isLabelVisible: focusRunning,
                  smallSize: 8,
                  child: const Icon(Icons.timer_rounded),
                ),
                label: 'Odak',
              ),
              const NavigationDestination(
                icon: Icon(Icons.class_outlined),
                selectedIcon: Icon(Icons.class_rounded),
                label: 'Dersler',
              ),
              const NavigationDestination(
                icon: Icon(Icons.insights_outlined),
                selectedIcon: Icon(Icons.insights_rounded),
                label: 'İstatistik',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
