import 'chit_create_api.dart';

class ChitCreateRepository {
  // -------------------- DRAFT --------------------
  Future<String> createDraft({
    required String groupName,
    required int chitAmount,
    required int totalMembers,
    required int durationMonths,
  }) async {
    final res = await ChitCreateApi.createDraft(
      groupName: groupName,
      chitAmount: chitAmount,
      totalMembers: totalMembers,
      durationMonths: durationMonths,
    );
    return res["id"];
  }

  // -------------------- CONFIGURED --------------------
  Future<void> configureChit(String chitGroupId, Map<String, dynamic> settings) async {
    await ChitCreateApi.configureChit(chitGroupId, settings);
  }

  // -------------------- ACTIVE --------------------
  Future<void> activateChit(String chitGroupId) async {
    await ChitCreateApi.activateChit(chitGroupId);
  }

  Future<void> addMemberWithCatchup({
    required String chitGroupId,
    required String name,
    required String mobile,
    required int memberNo,
  }) async {
    await ChitCreateApi.addMemberWithCatchup(
      chitGroupId: chitGroupId,
      name: name,
      mobile: mobile,
      memberNo: memberNo,
    );
  }


  Future<List<dynamic>> listMembers(String chitGroupId) async {
    return await ChitCreateApi.listMembers(chitGroupId);
  }

  // -------------------- RUNNING --------------------
  Future<void> startChit(String chitGroupId) async {
    await ChitCreateApi.startChit(chitGroupId);
  }

  // -------------------- AUCTION --------------------
  Future<String> openAuction(String chitGroupId, int monthNo) async {
    final res = await ChitCreateApi.openAuction(
      chitGroupId: chitGroupId,
      monthNo: monthNo,
    );
    return res["id"];
  }

  Future<void> closeAuction({
    required String auctionRoundId,
    required String winningMemberId,
    required int winningBidAmount,
  }) async {
    await ChitCreateApi.closeAuction(
      auctionRoundId: auctionRoundId,
      winningMemberId: winningMemberId,
      winningBidAmount: winningBidAmount,
    );
  }

  Future<Map<String, dynamic>?> getLiveAuction(String chitGroupId) async {
    return await ChitCreateApi.getLiveAuction(chitGroupId);
  }
}
