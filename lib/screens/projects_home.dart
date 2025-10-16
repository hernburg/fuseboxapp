import 'package:flutter/material.dart';
import '../data/mem_repo.dart';
import '../models/project.dart';
import 'project_editor.dart';

class ProjectsHome extends StatefulWidget {
  const ProjectsHome({super.key});
  @override State<ProjectsHome> createState() => _ProjectsHomeState();
}

class _ProjectsHomeState extends State<ProjectsHome> {
  final repo = MemRepo();

  @override
  Widget build(BuildContext context) {
    final items = repo.all();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Проекты'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final p = repo.create();
              await Navigator.push(context,
                MaterialPageRoute(builder: (_) => ProjectEditor(project: p)));
              setState(() {}); // обновить список после возврата
            },
          ),
        ],
      ),
      body: items.isEmpty
          ? const Center(child: Text('Нет проектов. Нажми +'))
          : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (ctx, i) => _tile(items[i]),
            ),
    );
  }

  Widget _tile(Project p) {
    return ListTile(
      leading: const Icon(Icons.folder),
      title: Text(p.title.isEmpty ? 'Без названия' : p.title),
      subtitle: Text('${(p.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)).toLocal()}'.split('.').first),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () { setState(() => MemRepo().delete(p.id)); },
      ),
      onTap: () async {
        await Navigator.push(context,
          MaterialPageRoute(builder: (_) => ProjectEditor(project: p)));
        setState(() {});
      },
    );
  }
}