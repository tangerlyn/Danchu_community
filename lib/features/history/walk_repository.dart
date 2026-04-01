import '../history/walk_model.dart';
import '../history/database_helper.dart';

class WalkRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<Walk>> getAllWalks() async {
    return await _dbHelper.readAllWalks();
  }

  Future<List<Walk>> getWalksByDateRange(DateTime start, DateTime end) async {
    final allWalks = await _dbHelper.readAllWalks();
    return allWalks.where((w) =>
        w.startTime.isAfter(start.subtract(const Duration(seconds: 1))) && 
        w.startTime.isBefore(end.add(const Duration(seconds: 1)))
    ).toList();
  }
}
