// lib/screens/project_editor.dart
import 'package:flutter/material.dart';
import '../widgets/floor_preview.dart';
import '../data/mem_repo.dart';
import '../models/project.dart';
import '../api/calc_api.dart';
import '../widgets/fake_progress.dart';
import 'assembly_preview.dart';
import 'floor_editor.dart'; // переход в рисовалку этажа

class ProjectEditor extends StatefulWidget {
  final Project project;
  const ProjectEditor({super.key, required this.project});

  @override
  State<ProjectEditor> createState() => _ProjectEditorState();
}

class _ProjectEditorState extends State<ProjectEditor> {
  late Project p;
  bool _busy = false;

  List get _floors => (p.payload['floors'] as List);

  @override
  void initState() {
    super.initState();
    p = widget.project;

    // Дефолтный payload если пустой
    if (p.payload.isEmpty) {
      p = p.copyWith(
        payload: {
          "settings": {
            "phases": 1,
            "mainBreakerA": 63,
            "railWidthModules": 12,
            "voltageStd": 220
          },
          "devices": {
            "voltageRelay": true,
            "spdClass2": false,
            "afdd": false,
            "contactor": false,
            "meter": false,
            "dinSocket": false,
            "fireRCD": true,
            "nonDisconnectable": false
          },
          "grouping": {
            "perGroup": {"sockets": 2, "lights": 2},
            "perFloorOverride": false,
            "floorRCD": false
          },
          "floors": [
            {
              "title": "Этаж 1",
              // превью этажа будет рисоваться виджетом FloorPreview
              "plan": {},
            }
          ]
        },
      );
      MemRepo().upsert(p);
    }
  }

  void _save() => MemRepo().upsert(p);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        _save();
        if (!didPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: TextField(
            controller: TextEditingController(text: p.title)
              ..selection = TextSelection.collapsed(offset: p.title.length),
            decoration: const InputDecoration(border: InputBorder.none),
            onChanged: (v) {
              p = p.copyWith(title: v);
              _save();
            },
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              _save();
              Navigator.pop(context);
            },
          ),
          // ВАЖНО: никаких actions — верхней кнопки «добавить этаж» БОЛЬШЕ НЕТ
        ),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // СПИСОК ЭТАЖЕЙ (карточками)
            for (int i = 0; i < _floors.length; i++) _floorCard(i),
            const SizedBox(height: 24),

            // Кнопки "Трассировка" и "Рассчитать"
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.route),
                    label: const Text('Трассировка'),
                    onPressed: () {
                      final snack = ScaffoldMessenger.of(context);
                      snack.showSnackBar(const SnackBar(
                        content: Text('Трассировка открывается из редактора этажа'),
                      ));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.calculate),
                    label: Text(_busy ? 'Считаю…' : 'Рассчитать'),
                    onPressed: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            Map<String, dynamic>? result;

                            await showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => FakeProgress(
                                minDelay: const Duration(seconds: 11),
                                task: () async {
                                  result = await CalcApi.calc(p.payload);
                                },
                                onDone: () => Navigator.of(context).pop(),
                              ),
                            );

                            if (!context.mounted) return;
                            setState(() => _busy = false);

                            if (result == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Ошибка расчёта')),
                              );
                              return;
                            }

                            final cheap =
                                result!['cheap'] as Map<String, dynamic>? ?? {};
                            if (cheap.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Пустой результат (cheap)')),
                              );
                              return;
                            }

                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AssemblyPreview(cheap: cheap),
                              ),
                            );
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 100), // отступ под нижнюю плавающую кнопку
          ],
        ),

        // ЕДИНСТВЕННАЯ кнопка добавления этажа — снизу справа, красная
        floatingActionButton: _AddFloorFab(
          onTap: () {
            setState(() {
              _floors.add({
                "title": "Этаж ${_floors.length + 1}",
                "plan": {},
              });
              _save();
            });
          },
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  /* ---------- Карточка этажа ---------- */
  Widget _floorCard(int i) {
    final Map floor = _floors[i] as Map;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // заголовок + удалить
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: TextEditingController(
                        text: (floor['title'] ?? '').toString())
                      ..selection = TextSelection.collapsed(
                          offset: (floor['title'] ?? '').toString().length),
                    decoration: const InputDecoration(labelText: 'Название этажа'),
                    onChanged: (v) {
                      floor['title'] = v;
                      _save();
                      setState(() {});
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    setState(() {
                      _floors.removeAt(i);
                      _save();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ПРЕВЬЮ ПЛАНА ЭТАЖА
            Align(
              alignment: Alignment.centerLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: FloorPreview(
                    plan: floor['plan'] as Map?, // можно и null — нарисует пустое превью
                    width: 160,
                    height: 120,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // открыть редактор этажа
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FloorEditor(),
                    ),
                  );
                  setState(() {}); // обновить превью/названия после возврата
                },
                icon: const Icon(Icons.edit),
                label: const Text('Открыть редактор'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------- FAB «+ Этаж» (красная) ---------- */
class _AddFloorFab extends StatelessWidget {
  final VoidCallback onTap;
  const _AddFloorFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onTap,
      icon: const Icon(Icons.add),
      label: const Text('Этаж'),
      backgroundColor: const Color(0xFFB3261E),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}
