abstract interface class PoleUploadApi {
  Future<int> createPoleRecord(Map<String, dynamic> record);

  Future<void> uploadPhoto({
    required int recordId,
    required String path,
    required String photoType,
    required DateTime takenAt,
  });
}
