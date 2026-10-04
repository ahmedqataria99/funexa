import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/documents/data/models/document_record_model.dart';
import 'package:furnexa/features/documents/domain/entities/document_definition.dart';
import 'package:furnexa/features/documents/domain/entities/document_entity.dart';
import 'package:furnexa/features/documents/domain/entities/document_number.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'package:furnexa/features/users_roles_permissions/domain/entities/security_entities.dart';

class DocumentsLocalDataSource {
  DocumentsLocalDataSource({SecurityLocalDataSource? security})
    : security = security ?? SecurityLocalDataSource();
  final SecurityLocalDataSource security;
  Future<Database> get _db async => FurnexaDatabase.instance.database;
  static int _sequence = 0;

  Future<DocumentNumber> nextNumber(DocumentType type, {DateTime? date}) async {
    _require(type.permission);
    final target = date ?? DateTime.now();
    final year = target.year;
    final db = await _db;
    late DocumentNumber number;
    await db.transaction((txn) async {
      number = await _nextNumberInTransaction(txn, type, year);
    });
    return number;
  }

  Future<DocumentNumber> _nextNumberInTransaction(
    DatabaseExecutor txn,
    DocumentType type,
    int year,
  ) async {
    late int sequence;
    final rows = await txn.query(
      'document_sequences',
      where: 'documentType = ? AND year = ?',
      whereArgs: [type.value, year],
      limit: 1,
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    if (rows.isEmpty) {
      sequence = 1;
      await txn.insert('document_sequences', {
        'id': 'sequence-${type.value}-$year',
        'documentType': type.value,
        'year': year,
        'lastNumber': sequence,
        'createdAt': now,
        'updatedAt': now,
      });
    } else {
      sequence = (rows.first['lastNumber'] as int) + 1;
      await txn.update(
        'document_sequences',
        {'lastNumber': sequence, 'updatedAt': now},
        where: 'id = ?',
        whereArgs: [rows.first['id']],
      );
    }
    return DocumentNumber(
      documentType: type.value,
      year: year,
      sequence: sequence,
      value: '${type.prefix}-${year}-${sequence.toString().padLeft(6, '0')}',
    );
  }

  Future<DocumentEntity> createDraft({
    required DocumentType type,
    required String title,
    required Map<String, Object?> metadata,
    String? sourceEntityType,
    String? sourceEntityId,
    String? factoryId,
    DocumentLanguage language = DocumentLanguage.arabic,
    DocumentTemplateType templateType = DocumentTemplateType.standard,
  }) async {
    _require(type.permission);
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'document-$now-${_sequence++}';
    final db = await _db;
    late DocumentNumber number;
    await db.transaction((txn) async {
      number = await _nextNumberInTransaction(
        txn,
        type,
        DateTime.fromMillisecondsSinceEpoch(now).year,
      );
      await txn.insert('document_records', {
        'documentId': id,
        'documentType': type.value,
        'documentNumber': number.value,
        'issueDate': now,
        'title': title,
        'language': language.value,
        'templateType': templateType.value,
        'status': DocumentStatus.draft.value,
        'sourceEntityType': sourceEntityType,
        'sourceEntityId': sourceEntityId,
        'factoryId': factoryId,
        'createdBy': security.session?.user.id,
        'createdAt': now,
        'metadata': jsonEncode(metadata),
      });
    });
    await security.audit(
      action: 'DOCUMENT_GENERATED',
      module: 'Documents',
      entityType: type.value,
      entityId: id,
      description: 'Document generated',
    );
    return (await getById(id))!;
  }

  Future<DocumentEntity> post(String id) async {
    final document = await _owned(id);
    if (document.status == DocumentStatus.cancelled)
      throw Exception('لا يمكن ترحيل مستند ملغى');
    if (document.status == DocumentStatus.posted) return document;
    await (await _db).update(
      'document_records',
      {'status': DocumentStatus.posted.value},
      where: 'documentId = ?',
      whereArgs: [id],
    );
    await security.audit(
      action: 'DOCUMENT_POSTED',
      module: 'Documents',
      entityType: document.documentType.value,
      entityId: id,
      description: 'Document posted',
    );
    return (await getById(id))!;
  }

  Future<DocumentEntity?> getById(String id) async {
    final rows = await (await _db).query(
      'document_records',
      where: 'documentId = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final document = DocumentRecordModel.fromMap(rows.first);
    _require(document.documentType.permission);
    _enforceScope(document);
    return document;
  }

  Future<List<DocumentEntity>> history({DocumentType? type}) async {
    _require('AUDIT_VIEW');
    final rows = await (await _db).query(
      'document_records',
      where: type == null ? null : 'documentType = ?',
      whereArgs: type == null ? null : [type.value],
      orderBy: 'createdAt DESC',
    );
    final session = security.session!;
    if (session.isSystemAdmin) {
      return rows.map(DocumentRecordModel.fromMap).toList();
    }
    final result = <DocumentEntity>[];
    for (final row in rows) {
      final document = DocumentRecordModel.fromMap(row);
      if (!session.can(document.documentType.permission)) continue;
      try {
        _enforceScope(document);
        result.add(document);
      } on Exception {
        continue;
      }
    }
    return result;
  }

  Future<DocumentEntity> duplicateAsDraft(String id) async {
    final source = await _owned(id);
    return createDraft(
      type: source.documentType,
      title: source.title,
      metadata: source.metadata,
      sourceEntityType: source.sourceEntityType,
      sourceEntityId: source.sourceEntityId,
      factoryId: source.factoryId,
      language: source.language,
      templateType: source.templateType,
    );
  }

  Future<DocumentEntity> _owned(String id) async {
    final document = await getById(id);
    if (document == null) throw Exception('المستند غير موجود');
    _require(document.documentType.permission);
    return document;
  }

  void _require(String permission) => security.require(permission);

  void _enforceScope(DocumentEntity document) {
    final warehouseId = document.metadata['warehouseId'];
    if (warehouseId is String && warehouseId.isNotEmpty) {
      security.requireScope(ScopeType.warehouse, warehouseId);
    }
    final workshopId = document.metadata['workshopId'];
    if (workshopId is String && workshopId.isNotEmpty) {
      security.requireScope(ScopeType.workshop, workshopId);
    }
    final stageId = document.metadata['productionStageId'];
    if (stageId is String && stageId.isNotEmpty) {
      security.requireScope(ScopeType.productionStage, stageId);
    }
  }
}
