import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:furnexa/features/documents/data/repositories/documents_repository_impl.dart';
import 'package:furnexa/features/documents/domain/entities/document_entity.dart';
import 'package:furnexa/features/documents/domain/entities/document_definition.dart';
import 'package:furnexa/features/documents/domain/repositories/documents_repository.dart';
import 'package:furnexa/features/documents/presentation/pages/document_preview_page.dart';

class DocumentHistoryPage extends StatefulWidget {
  const DocumentHistoryPage({super.key, this.repository});
  final DocumentsRepository? repository;
  @override
  State<DocumentHistoryPage> createState() => _DocumentHistoryPageState();
}

class _DocumentHistoryPageState extends State<DocumentHistoryPage> {
  late final DocumentsRepository _repository =
      widget.repository ?? DocumentsRepositoryImpl();
  List<DocumentEntity> _documents = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await _repository.history();
      if (mounted)
        setState(() {
          _documents = values;
          _loading = false;
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _error = error.toString();
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('سجل المستندات'),
      actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(child: Text(_error!))
        : _documents.isEmpty
        ? const Center(child: Text('لا توجد مستندات'))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _documents.length,
            itemBuilder: (context, index) {
              final document = _documents[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text('${document.documentNumber} • ${document.title}'),
                  subtitle: Text(
                    '${document.status.value} • ${DateFormat('dd/MM/yyyy').format(document.createdAt)}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.visibility_outlined),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DocumentPreviewPage(
                          document: document,
                          repository: _repository,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
  );
}
