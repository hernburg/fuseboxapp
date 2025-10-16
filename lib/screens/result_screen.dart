import 'package:flutter/material.dart';

class ResultScreen extends StatelessWidget {
  final Map<String, dynamic> result;
  const ResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Результат расчёта'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Дешёвый'),
            Tab(text: 'Оптимальный'),
            Tab(text: 'Максимум'),
          ]),
        ),
        body: TabBarView(children: [
          _VariantView(data: result['cheap'] as Map<String, dynamic>),
          _VariantView(data: result['optimal'] as Map<String, dynamic>),
          _VariantView(data: result['max'] as Map<String, dynamic>),
        ]),
      ),
    );
  }
}

class _VariantView extends StatelessWidget {
  final Map<String, dynamic> data;
  const _VariantView({required this.data});

  @override
  Widget build(BuildContext context) {
    final main = data['main'] as Map<String, dynamic>;
    final lines = (data['lines'] as List).cast<Map<String, dynamic>>();
    final extras = (data['bomExtras'] as List?)?.cast<String>() ?? const [];

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 1 + lines.length + (extras.isEmpty ? 0 : 1),
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return Card(
            child: ListTile(
              title: const Text('Ввод'),
              subtitle: Text('In=${main['In']} A, RCD=${main['rcd_mA']} мА'),
            ),
          );
        }
        if (i <= lines.length) {
          final l = lines[i - 1];
          final rcd = l['rcd_mA'];
          return Card(
            child: ListTile(
              leading: Icon(
                l['type'] == 'lights'
                    ? Icons.lightbulb
                    : l['type'] == 'sockets'
                        ? Icons.power_outlined
                        : Icons.memory,
              ),
              title: Text(l['title']),
              subtitle: Text('Автомат: ${l['breaker_In']} A ${l['breaker_char']}'
                  '${rcd != null ? ', RCD=$rcd мА' : ''}'),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('Доп. устройства: ${extras.join(', ')}'),
        );
      },
    );
  }
}