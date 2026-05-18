import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CoordinatorWorkspaceService {
  static const String _announcementsKey = 'coordinator_announcements_v1';
  static const String _approvalsKey = 'coordinator_approvals_v1';
  static const String _notificationsKey = 'coordinator_notifications_v1';
  static const String _reportsKey = 'company_reports_to_university_v1';
  static const String _studentSelectionsKey = 'student_company_selections_v1';
  static const String _manualPlacementsKey = 'coordinator_manual_placements_v1';
  static const Duration _studentChoiceWindow = Duration(hours: 48);

  Future<List<Map<String, dynamic>>> getAnnouncements({
    String? audience,
    String? universityId,
    String? universityName,
    List<String>? institutionIds,
    List<String>? institutionNames,
  }) async {
    final announcements = await _readList(_announcementsKey);
    final normalizedUniversityId = universityId?.trim() ?? '';
    final validInstitutionIds = institutionIds
        ?.map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    final validInstitutionNames = institutionNames
        ?.map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    final normalizedAudience = audience?.trim().toLowerCase();
    final shouldRequireUniversityMatch =
        normalizedAudience == 'student' || normalizedAudience == 'students';
    final filtered = announcements
        .where((announcement) {
          if (audience != null &&
              !_audienceMatches(
                targetAudience: '${announcement['audience'] ?? 'all'}',
                role: audience,
              )) {
            return false;
          }

          final announcementUniversityId =
              '${announcement['university_id'] ?? ''}'.trim();
          final announcementUniversityName =
              '${announcement['university_name'] ?? ''}'.trim();
          final hasUniversityTarget =
              announcementUniversityId.isNotEmpty ||
              announcementUniversityName.isNotEmpty;

          if (validInstitutionIds != null && validInstitutionIds.isNotEmpty) {
            if (announcementUniversityId.isNotEmpty) {
              if (!_matchesAnyValue(
                announcementUniversityId,
                validInstitutionIds,
              )) {
                return false;
              }
            } else if (!_matchesAnyInstitution(
              announcementUniversityName,
              validInstitutionNames ?? const <String>[],
            )) {
              return false;
            }
          } else if (normalizedUniversityId.isNotEmpty) {
            if (announcementUniversityId.isNotEmpty) {
              if (!_sameValue(
                announcementUniversityId,
                normalizedUniversityId,
              )) {
                return false;
              }
            } else if (validInstitutionNames != null &&
                validInstitutionNames.isNotEmpty &&
                !_matchesAnyInstitution(
                  announcementUniversityName,
                  validInstitutionNames,
                )) {
              return false;
            } else if (universityName != null &&
                universityName.trim().isNotEmpty) {
              if (!_sameInstitution(
                announcementUniversityName,
                universityName,
              )) {
                return false;
              }
            } else if (hasUniversityTarget) {
              return false;
            }
          } else if (validInstitutionNames != null &&
              validInstitutionNames.isNotEmpty) {
            if (!_matchesAnyInstitution(
              announcementUniversityName,
              validInstitutionNames,
            )) {
              return false;
            }
          } else if (universityName != null &&
              universityName.trim().isNotEmpty) {
            if (!_sameInstitution(announcementUniversityName, universityName)) {
              return false;
            }
          } else if (shouldRequireUniversityMatch && hasUniversityTarget) {
            return false;
          }

          return true;
        })
        .toList(growable: false);

    filtered.sort(
      (left, right) => _sortByDateDesc(left['created_at'], right['created_at']),
    );
    return filtered;
  }

  Future<void> createAnnouncement({
    required String title,
    required String message,
    required String audience,
    String? universityId,
    required String universityName,
    required String coordinatorName,
  }) async {
    final announcements = await _readList(_announcementsKey);
    final now = DateTime.now().toUtc().toIso8601String();
    final announcementId = _generateId('announcement');

    announcements.add({
      'id': announcementId,
      'title': title.trim(),
      'message': message.trim(),
      'audience': audience.trim().isEmpty ? 'all' : audience.trim(),
      'university_id': universityId?.trim() ?? '',
      'university_name': universityName.trim(),
      'coordinator_name': coordinatorName.trim(),
      'created_at': now,
      'updated_at': now,
    });

    await _writeList(_announcementsKey, announcements);
    await _appendNotification({
      'notification_id': _generateId('notification'),
      'source_id': announcementId,
      'title': title.trim(),
      'message': message.trim(),
      'type': 'coordinator_announcement',
      'audience': audience.trim().isEmpty ? 'all' : audience.trim(),
      'university_id': universityId?.trim() ?? '',
      'university_name': universityName.trim(),
      'coordinator_name': coordinatorName.trim(),
      'created_at': now,
      'is_read': false,
    });
  }

  Future<List<Map<String, dynamic>>> getStudentSelections() async {
    await _expirePendingMultiOfferSelections();
    final selections = await _readList(_studentSelectionsKey);
    selections.sort(
      (left, right) => _sortByDateDesc(left['updated_at'], right['updated_at']),
    );
    return selections;
  }

  Future<Map<String, dynamic>?> getStudentSelection(String studentEmail) async {
    if (studentEmail.trim().isEmpty) return null;
    final selections = await getStudentSelections();
    for (final selection in selections) {
      if (_sameValue(selection['student_email'], studentEmail)) {
        return selection;
      }
    }
    return null;
  }

  Future<void> confirmStudentCompanySelection({
    required String studentName,
    required String studentEmail,
    required String universityName,
    required String chosenApplicationId,
    required String chosenCompanyName,
    required String chosenTrainingTitle,
    String? reportingStartDate,
    String? reportingEndDate,
    required List<Map<String, dynamic>> acceptedApplications,
  }) async {
    final normalizedEmail = studentEmail.trim();
    if (normalizedEmail.isEmpty) return;

    final existing = await getStudentSelection(normalizedEmail);
    final alreadyConfirmedSameSelection =
        existing != null &&
        _sameValue(existing['selected_application_id'], chosenApplicationId);
    if (existing != null && !alreadyConfirmedSameSelection) {
      throw StateError('Student has already confirmed another company.');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final selections = await _readList(_studentSelectionsKey);
    selections.removeWhere(
      (selection) => _sameValue(selection['student_email'], normalizedEmail),
    );
    selections.add({
      'id': existing == null ? _generateId('selection') : existing['id'],
      'student_name': studentName.trim(),
      'student_email': normalizedEmail,
      'university_name': universityName.trim(),
      'selected_application_id': chosenApplicationId,
      'selected_company_name': chosenCompanyName.trim(),
      'selected_training_title': chosenTrainingTitle.trim(),
      'confirmed_at': alreadyConfirmedSameSelection
          ? (existing['confirmed_at'] ?? now)
          : now,
      'updated_at': now,
    });
    await _writeList(_studentSelectionsKey, selections);

    final approvals = await _readList(_approvalsKey);
    approvals.removeWhere(
      (approval) =>
          _sameValue(approval['student_email'], normalizedEmail) &&
          !_sameValue(approval['application_id'], chosenApplicationId),
    );
    final existingApprovalIndex = approvals.indexWhere(
      (approval) => _sameValue(approval['application_id'], chosenApplicationId),
    );
    final existingApproval = existingApprovalIndex == -1
        ? null
        : approvals[existingApprovalIndex];
    final existingCoordinatorStatus =
        '${existingApproval?['coordinator_status'] ?? ''}'.trim().toLowerCase();
    final normalizedCoordinatorStatus =
        existingCoordinatorStatus == 'approved' ||
            existingCoordinatorStatus == 'rejected' ||
            existingCoordinatorStatus == 'pending'
        ? existingCoordinatorStatus
        : 'pending';
    final shouldNotifyStakeholders =
        !(alreadyConfirmedSameSelection &&
            existingApproval != null &&
            _sameValue(existingApproval['student_choice_status'], 'confirmed'));
    final approvalRecord = {
      'id': existingApprovalIndex == -1
          ? _generateId('approval')
          : approvals[existingApprovalIndex]['id'],
      'application_id': chosenApplicationId,
      'student_name': studentName.trim(),
      'student_email': normalizedEmail,
      'university_name': universityName.trim(),
      'company_name': chosenCompanyName.trim(),
      'training_title': chosenTrainingTitle.trim(),
      'company_selection_status': 'accepted',
      'student_choice_status': 'confirmed',
      'coordinator_status': normalizedCoordinatorStatus,
      'coordinator_name': existingApproval == null
          ? ''
          : '${existingApproval['coordinator_name'] ?? ''}',
      'coordinator_notes': existingApprovalIndex == -1
          ? ''
          : '${approvals[existingApprovalIndex]['coordinator_notes'] ?? ''}',
      'reporting_start_date': reportingStartDate?.trim() ?? '',
      'reporting_end_date': reportingEndDate?.trim() ?? '',
      'confirmed_at': alreadyConfirmedSameSelection
          ? (existingApproval?['confirmed_at'] ?? now)
          : now,
      'created_at': existingApprovalIndex == -1
          ? now
          : '${approvals[existingApprovalIndex]['created_at'] ?? now}',
      'updated_at': now,
    };
    if (existingApprovalIndex == -1) {
      approvals.add(approvalRecord);
    } else {
      approvals[existingApprovalIndex] = approvalRecord;
    }
    await _writeList(_approvalsKey, approvals);

    if (!shouldNotifyStakeholders) {
      return;
    }

    await _appendNotification({
      'notification_id': _generateId('notification'),
      'source_id': chosenApplicationId,
      'title': 'Company confirmation received',
      'message': 'You confirmed $chosenCompanyName for $chosenTrainingTitle.',
      'type': 'student_company_confirmed',
      'audience': 'student',
      'target_email': normalizedEmail,
      'university_name': universityName.trim(),
      'created_at': now,
      'is_read': false,
    });

    await _appendNotification({
      'notification_id': _generateId('notification'),
      'source_id': chosenApplicationId,
      'title': 'Student confirmed your company',
      'message':
          '$studentName has confirmed $chosenCompanyName for $chosenTrainingTitle and the university coordinator has been notified.',
      'type': 'student_company_confirmed',
      'audience': 'company',
      'target_company_name': chosenCompanyName.trim(),
      'created_at': now,
      'is_read': false,
    });

    await _appendNotification({
      'notification_id': _generateId('notification'),
      'source_id': chosenApplicationId,
      'title': 'Student confirmed a company placement',
      'message':
          '$studentName confirmed $chosenCompanyName for $chosenTrainingTitle. Review the selection in the coordinator queue.',
      'type': 'student_company_confirmed',
      'audience': 'university',
      'target_email': normalizedEmail,
      'university_name': universityName.trim(),
      'company_name': chosenCompanyName.trim(),
      'created_at': now,
      'is_read': false,
    });

    for (final application in acceptedApplications) {
      final applicationId = '${application['application_id'] ?? ''}'.trim();
      final companyName = '${application['company_name'] ?? ''}'.trim();
      if (applicationId.isEmpty ||
          companyName.isEmpty ||
          _sameValue(applicationId, chosenApplicationId)) {
        continue;
      }

      await _appendNotification({
        'notification_id': _generateId('notification'),
        'source_id': applicationId,
        'title': 'Student chose another company',
        'message':
            '$studentName has already confirmed placement with $chosenCompanyName, so this selection is no longer active.',
        'type': 'student_confirmed_other_company',
        'audience': 'company',
        'target_company_name': companyName,
        'created_at': now,
        'is_read': false,
      });
    }
  }

  Future<List<Map<String, dynamic>>> getApprovalRecords({
    String? universityName,
  }) async {
    await _expirePendingMultiOfferSelections();
    final approvals = await _readList(_approvalsKey);
    final filtered = approvals
        .where((approval) {
          if (universityName == null || universityName.trim().isEmpty) {
            return true;
          }

          return _sameInstitution(approval['university_name'], universityName);
        })
        .toList(growable: false);

    filtered.sort(
      (left, right) => _sortByDateDesc(
        left['updated_at'] ?? left['created_at'],
        right['updated_at'] ?? right['created_at'],
      ),
    );
    return filtered;
  }

  Future<List<Map<String, dynamic>>> getManualPlacements({
    String? universityName,
  }) async {
    final placements = await _readList(_manualPlacementsKey);
    final filtered = placements
        .where((placement) {
          if (universityName == null || universityName.trim().isEmpty) {
            return true;
          }

          return _sameInstitution(placement['university_name'], universityName);
        })
        .toList(growable: false);

    filtered.sort(
      (left, right) => _sortByDateDesc(
        left['updated_at'] ?? left['assigned_at'] ?? left['created_at'],
        right['updated_at'] ?? right['assigned_at'] ?? right['created_at'],
      ),
    );
    return filtered;
  }

  Future<void> assignManualPlacement({
    required String studentName,
    required String studentEmail,
    String? studentPhone,
    String? registrationNumber,
    String? department,
    String? studentId,
    required String universityName,
    required String coordinatorName,
    required String companyName,
    required String trainingTitle,
    required String placementLocation,
    String? startDate,
    String? endDate,
    String? coordinatorNotes,
  }) async {
    final normalizedEmail = studentEmail.trim();
    if (normalizedEmail.isEmpty) {
      throw StateError('Student email is required to send placement updates.');
    }

    final placements = await _readList(_manualPlacementsKey);
    final now = DateTime.now().toUtc().toIso8601String();
    final existingIndex = placements.indexWhere(
      (placement) =>
          _sameValue(placement['student_email'], normalizedEmail) &&
          _sameInstitution(placement['university_name'], universityName),
    );

    final record = {
      'id': existingIndex == -1
          ? _generateId('manual-placement')
          : placements[existingIndex]['id'],
      'student_name': studentName.trim(),
      'student_email': normalizedEmail,
      'student_phone': studentPhone?.trim() ?? '',
      'registration_number': registrationNumber?.trim() ?? '',
      'department': department?.trim() ?? '',
      'student_id': studentId?.trim() ?? '',
      'university_name': universityName.trim(),
      'coordinator_name': coordinatorName.trim(),
      'company_name': companyName.trim(),
      'training_title': trainingTitle.trim(),
      'placement_location': placementLocation.trim(),
      'start_date': startDate?.trim() ?? '',
      'end_date': endDate?.trim() ?? '',
      'coordinator_notes': coordinatorNotes?.trim() ?? '',
      'assigned_at': existingIndex == -1
          ? now
          : '${placements[existingIndex]['assigned_at'] ?? now}',
      'created_at': existingIndex == -1
          ? now
          : '${placements[existingIndex]['created_at'] ?? now}',
      'updated_at': now,
    };

    if (existingIndex == -1) {
      placements.add(record);
    } else {
      placements[existingIndex] = record;
    }

    await _writeList(_manualPlacementsKey, placements);

    final message = StringBuffer()
      ..write(
        '$coordinatorName from $universityName assigned you to $companyName as $trainingTitle',
      );
    if (placementLocation.trim().isNotEmpty) {
      message.write(' at $placementLocation');
    }
    message.write('.');
    if ((startDate ?? '').trim().isNotEmpty) {
      message.write(' Start date: ${startDate!.trim()}.');
    }
    if ((endDate ?? '').trim().isNotEmpty) {
      message.write(' End date: ${endDate!.trim()}.');
    }
    if ((coordinatorNotes ?? '').trim().isNotEmpty) {
      message.write(' Notes: ${coordinatorNotes!.trim()}');
    }

    await _appendNotification({
      'notification_id': _generateId('notification'),
      'source_id': record['id'],
      'title': 'New field placement assigned',
      'message': message.toString(),
      'type': 'coordinator_manual_assignment',
      'audience': 'student',
      'target_email': normalizedEmail,
      'university_name': universityName.trim(),
      'company_name': companyName.trim(),
      'created_at': now,
      'is_read': false,
    });

    await _appendNotification({
      'notification_id': _generateId('notification'),
      'source_id': record['id'],
      'title': 'Placement assigned to $studentName',
      'message':
          '$coordinatorName assigned $studentName to $companyName as $trainingTitle.',
      'type': 'coordinator_manual_assignment',
      'audience': 'university',
      'university_name': universityName.trim(),
      'target_email': normalizedEmail,
      'company_name': companyName.trim(),
      'created_at': now,
      'is_read': false,
    });
  }

  Future<void> queueApprovalFromCompany({
    required String applicationId,
    required String studentName,
    required String studentEmail,
    required String universityName,
    required String companyName,
    required String trainingTitle,
    String? reportingStartDate,
    String? reportingEndDate,
  }) async {
    final approvals = await _readList(_approvalsKey);
    final now = DateTime.now().toUtc().toIso8601String();
    final existingIndex = approvals.indexWhere(
      (approval) => '${approval['application_id'] ?? ''}' == applicationId,
    );
    final existingApproval = existingIndex == -1
        ? null
        : approvals[existingIndex];
    final existingChoiceStatus = _normalizedStatus(
      existingApproval?['student_choice_status'],
      fallback: 'pending',
    );
    final acceptedAt =
        '${existingApproval?['accepted_at'] ?? existingApproval?['created_at'] ?? now}';
    final acceptedAtDate =
        _parseDateTimeValue(acceptedAt) ?? DateTime.now().toUtc();
    final confirmationExpiresAt = acceptedAtDate
        .toUtc()
        .add(_studentChoiceWindow)
        .toIso8601String();
    final nextChoiceStatus = existingChoiceStatus == 'confirmed'
        ? 'confirmed'
        : 'pending';

    final record = {
      'id': existingIndex == -1
          ? _generateId('approval')
          : approvals[existingIndex]['id'],
      'application_id': applicationId,
      'student_name': studentName.trim(),
      'student_email': studentEmail.trim(),
      'university_name': universityName.trim(),
      'company_name': companyName.trim(),
      'training_title': trainingTitle.trim(),
      'company_selection_status': 'accepted',
      'student_choice_status': nextChoiceStatus,
      'coordinator_status': 'pending',
      'coordinator_notes': existingIndex == -1
          ? ''
          : '${approvals[existingIndex]['coordinator_notes'] ?? ''}',
      'reporting_start_date': reportingStartDate?.trim() ?? '',
      'reporting_end_date': reportingEndDate?.trim() ?? '',
      'accepted_at': acceptedAtDate.toUtc().toIso8601String(),
      'confirmation_expires_at': confirmationExpiresAt,
      'expired_at': nextChoiceStatus == 'pending'
          ? ''
          : '${existingApproval?['expired_at'] ?? ''}',
      'created_at': existingIndex == -1
          ? now
          : '${approvals[existingIndex]['created_at'] ?? now}',
      'updated_at': now,
    };

    if (existingIndex == -1) {
      approvals.add(record);
    } else {
      approvals[existingIndex] = record;
    }

    await _writeList(_approvalsKey, approvals);
  }

  Future<void> queueApprovalFromOrganization({
    required String applicationId,
    required String studentName,
    required String studentEmail,
    required String universityName,
    required String organizationName,
    required String jobTitle,
    String? reportingStartDate,
    String? reportingEndDate,
  }) async {
    // Delegate to queueApprovalFromCompany with organization name mapped to company name
    return queueApprovalFromCompany(
      applicationId: applicationId,
      studentName: studentName,
      studentEmail: studentEmail,
      universityName: universityName,
      companyName: organizationName,
      trainingTitle: jobTitle,
      reportingStartDate: reportingStartDate,
      reportingEndDate: reportingEndDate,
    );
  }

  Future<void> _expirePendingMultiOfferSelections() async {
    final approvals = await _readList(_approvalsKey);
    if (approvals.isEmpty) return;

    final selections = await _readList(_studentSelectionsKey);
    final confirmedEmails = selections
        .map(
          (selection) =>
              '${selection['student_email'] ?? ''}'.trim().toLowerCase(),
        )
        .where((email) => email.isNotEmpty)
        .toSet();

    final pendingOfferIndexesByStudent = <String, List<int>>{};
    for (var index = 0; index < approvals.length; index++) {
      final approval = approvals[index];
      final studentEmail = '${approval['student_email'] ?? ''}'
          .trim()
          .toLowerCase();
      if (studentEmail.isEmpty || confirmedEmails.contains(studentEmail)) {
        continue;
      }

      final companySelectionStatus = _normalizedStatus(
        approval['company_selection_status'],
      );
      final studentChoiceStatus = _normalizedStatus(
        approval['student_choice_status'],
        fallback: 'pending',
      );

      if (companySelectionStatus != 'accepted' ||
          studentChoiceStatus != 'pending') {
        continue;
      }

      pendingOfferIndexesByStudent
          .putIfAbsent(studentEmail, () => <int>[])
          .add(index);
    }

    final now = DateTime.now().toUtc();
    final nowIso = now.toIso8601String();
    var hasChanges = false;

    for (final entry in pendingOfferIndexesByStudent.entries) {
      if (entry.value.length <= 1) {
        continue;
      }

      for (final index in entry.value) {
        final approval = approvals[index];
        final acceptedAt = _parseDateTimeValue(
          approval['accepted_at'] ??
              approval['created_at'] ??
              approval['updated_at'],
        );
        if (acceptedAt == null) {
          continue;
        }

        final expiresAt = acceptedAt.toUtc().add(_studentChoiceWindow);
        final expiresAtIso = expiresAt.toIso8601String();
        final currentExpiresAt = '${approval['confirmation_expires_at'] ?? ''}'
            .trim();

        if (now.isAfter(expiresAt)) {
          approvals[index] = {
            ...approval,
            'company_selection_status': 'expired',
            'student_choice_status': 'expired',
            'confirmation_expires_at': expiresAtIso,
            'expired_at': '${approval['expired_at'] ?? ''}'.trim().isEmpty
                ? nowIso
                : '${approval['expired_at']}',
            'updated_at': nowIso,
          };
          hasChanges = true;
        } else if (currentExpiresAt != expiresAtIso) {
          approvals[index] = {
            ...approval,
            'confirmation_expires_at': expiresAtIso,
          };
          hasChanges = true;
        }
      }
    }

    if (hasChanges) {
      await _writeList(_approvalsKey, approvals);
    }
  }

  Future<void> updateApprovalStatus({
    required String approvalId,
    required String status,
    required String coordinatorName,
    String? coordinatorNotes,
  }) async {
    final approvals = await _readList(_approvalsKey);
    final index = approvals.indexWhere(
      (approval) => '${approval['id']}' == approvalId,
    );
    if (index == -1) return;

    final now = DateTime.now().toUtc().toIso8601String();
    final current = approvals[index];
    final normalizedStatus = status.trim().toLowerCase();

    approvals[index] = {
      ...current,
      'coordinator_status': normalizedStatus,
      'coordinator_notes': coordinatorNotes?.trim() ?? '',
      'coordinator_name': coordinatorName.trim(),
      'updated_at': now,
    };

    await _writeList(_approvalsKey, approvals);

    final studentName = '${current['student_name'] ?? 'Student'}'.trim();
    final companyName = '${current['company_name'] ?? 'Company'}'.trim();
    final trainingTitle = '${current['training_title'] ?? 'placement'}'.trim();
    final universityName = '${current['university_name'] ?? 'University'}'
        .trim();
    final notesText = (coordinatorNotes ?? '').trim();
    final outcomeText = normalizedStatus == 'approved'
        ? 'approved'
        : 'rejected';
    final message = StringBuffer()
      ..write(
        'University coordinator has $outcomeText $studentName for $trainingTitle at $companyName.',
      );
    if (notesText.isNotEmpty) {
      message.write(' Notes: $notesText');
    }

    await _appendNotification({
      'notification_id': _generateId('notification'),
      'source_id': approvalId,
      'title': 'University decision for $studentName',
      'message': message.toString(),
      'type': normalizedStatus == 'approved'
          ? 'university_approval_approved'
          : 'university_approval_rejected',
      'audience': 'student',
      'target_email': '${current['student_email'] ?? ''}'.trim(),
      'university_name': universityName,
      'company_name': companyName,
      'created_at': now,
      'is_read': false,
    });

    await _appendNotification({
      'notification_id': _generateId('notification'),
      'source_id': approvalId,
      'title': 'University decision for company selection',
      'message':
          '$universityName coordinator has $outcomeText the selection for $studentName on $trainingTitle.',
      'type': normalizedStatus == 'approved'
          ? 'university_approval_approved'
          : 'university_approval_rejected',
      'audience': 'company',
      'target_company_name': companyName,
      'created_at': now,
      'is_read': false,
    });
  }

  Future<List<Map<String, dynamic>>> getNotificationsForRole({
    required String role,
    String? studentEmail,
    String? companyName,
    String? universityId,
    String? universityName,
    List<String>? institutionIds,
    List<String>? institutionNames,
  }) async {
    final notifications = await _readList(_notificationsKey);
    final normalizedUniversityId = universityId?.trim() ?? '';
    final validInstitutionIds = institutionIds
        ?.map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    final validInstitutionNames = institutionNames
        ?.map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    final filtered = notifications
        .where((notification) {
          if (!_audienceMatches(
            targetAudience: '${notification['audience'] ?? 'all'}',
            role: role,
          )) {
            return false;
          }

          final targetEmail = '${notification['target_email'] ?? ''}'.trim();
          if (role == 'student' &&
              targetEmail.isNotEmpty &&
              !_sameValue(targetEmail, studentEmail)) {
            return false;
          }

          final targetUniversityId = '${notification['university_id'] ?? ''}'
              .trim();
          final targetUniversity = '${notification['university_name'] ?? ''}'
              .trim();
          final isGeneralStudentAnnouncement =
              role == 'student' &&
              targetEmail.isEmpty &&
              (('${notification['type'] ?? ''}' ==
                      'coordinator_announcement') ||
                  _sameValue(notification['audience'], 'student') ||
                  _sameValue(notification['audience'], 'students'));
          final requiresUniversityMatch =
              role == 'university' || isGeneralStudentAnnouncement;
          if (requiresUniversityMatch &&
              (targetUniversityId.isNotEmpty || targetUniversity.isNotEmpty)) {
            if (validInstitutionIds != null && validInstitutionIds.isNotEmpty) {
              if (targetUniversityId.isNotEmpty) {
                if (!_matchesAnyValue(
                  targetUniversityId,
                  validInstitutionIds,
                )) {
                  return false;
                }
              } else if (!_matchesAnyInstitution(
                targetUniversity,
                validInstitutionNames ?? const <String>[],
              )) {
                return false;
              }
            } else if (normalizedUniversityId.isNotEmpty) {
              if (targetUniversityId.isNotEmpty) {
                if (!_sameValue(targetUniversityId, normalizedUniversityId)) {
                  return false;
                }
              } else if (validInstitutionNames != null &&
                  validInstitutionNames.isNotEmpty &&
                  !_matchesAnyInstitution(
                    targetUniversity,
                    validInstitutionNames,
                  )) {
                return false;
              } else if (!_sameInstitution(targetUniversity, universityName)) {
                return false;
              }
            } else if (validInstitutionNames != null &&
                validInstitutionNames.isNotEmpty) {
              if (!_matchesAnyInstitution(
                targetUniversity,
                validInstitutionNames,
              )) {
                return false;
              }
            } else {
              return false;
            }
          }

          final targetCompanyName =
              '${notification['target_company_name'] ?? ''}'.trim();
          if (role == 'company' &&
              targetCompanyName.isNotEmpty &&
              !_sameValue(targetCompanyName, companyName)) {
            return false;
          }

          return true;
        })
        .toList(growable: false);

    filtered.sort(
      (left, right) => _sortByDateDesc(left['created_at'], right['created_at']),
    );
    return filtered;
  }

  Future<Map<String, dynamic>> submitCompanyReport({
    required String applicationId,
    required String studentName,
    required String studentEmail,
    required String universityName,
    required String companyName,
    required String trainingTitle,
    required String issueType,
    required String description,
  }) async {
    try {
      final reports = await _readList(_reportsKey);
      final now = DateTime.now().toUtc().toIso8601String();

      reports.add({
        'id': _generateId('report'),
        'application_id': applicationId,
        'student_name': studentName.trim(),
        'student_email': studentEmail.trim(),
        'university_name': universityName.trim(),
        'company_name': companyName.trim(),
        'training_title': trainingTitle.trim(),
        'issue_type': issueType.trim(),
        'description': description.trim(),
        'status': 'new',
        'created_at': now,
        'updated_at': now,
      });

      await _writeList(_reportsKey, reports);

      await _appendNotification({
        'notification_id': _generateId('notification'),
        'source_id': applicationId,
        'title': 'Student report from company',
        'message':
            '$companyName reported $studentName for $trainingTitle. Issue: $issueType. $description',
        'type': 'company_report',
        'audience': 'university',
        'university_name': universityName.trim(),
        'target_email': studentEmail.trim(),
        'company_name': companyName.trim(),
        'created_at': now,
        'is_read': false,
      });

      return {'success': true, 'message': 'Report sent successfully.'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to send report: $e'};
    }
  }

  Future<Map<String, dynamic>> submitOrganizationReport({
    required String applicationId,
    required String studentName,
    required String studentEmail,
    required String universityName,
    required String organizationName,
    required String jobTitle,
    required String issueType,
    required String description,
  }) async {
    // Delegate to submitCompanyReport with organization name mapped to company name
    return submitCompanyReport(
      applicationId: applicationId,
      studentName: studentName,
      studentEmail: studentEmail,
      universityName: universityName,
      companyName: organizationName,
      trainingTitle: jobTitle,
      issueType: issueType,
      description: description,
    );
  }

  Future<List<Map<String, dynamic>>> getReportsForUniversity({
    String? universityName,
  }) async {
    final reports = await _readList(_reportsKey);
    final filtered = reports
        .where((report) {
          if (universityName == null || universityName.trim().isEmpty) {
            return true;
          }

          return _sameInstitution(report['university_name'], universityName);
        })
        .toList(growable: false);

    filtered.sort(
      (left, right) => _sortByDateDesc(left['created_at'], right['created_at']),
    );
    return filtered;
  }

  Future<void> markNotificationRead(String notificationId) async {
    final notifications = await _readList(_notificationsKey);
    final updated = notifications
        .map((notification) {
          if ('${notification['notification_id'] ?? ''}' != notificationId) {
            return notification;
          }

          return {...notification, 'is_read': true};
        })
        .toList(growable: false);

    await _writeList(_notificationsKey, updated);
  }

  Future<void> markAllNotificationsReadForRole({
    required String role,
    String? studentEmail,
    String? companyName,
    String? universityId,
    String? universityName,
    List<String>? institutionIds,
    List<String>? institutionNames,
  }) async {
    final notifications = await _readList(_notificationsKey);
    final normalizedUniversityId = universityId?.trim() ?? '';
    final validInstitutionIds = institutionIds
        ?.map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    final validInstitutionNames = institutionNames
        ?.map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    final updated = notifications
        .map((notification) {
          final matchesRole = _audienceMatches(
            targetAudience: '${notification['audience'] ?? 'all'}',
            role: role,
          );
          if (!matchesRole) {
            return notification;
          }

          final targetEmail = '${notification['target_email'] ?? ''}'.trim();
          if (role == 'student' &&
              targetEmail.isNotEmpty &&
              !_sameValue(targetEmail, studentEmail)) {
            return notification;
          }

          final targetUniversityId = '${notification['university_id'] ?? ''}'
              .trim();
          final targetUniversity = '${notification['university_name'] ?? ''}'
              .trim();
          final isGeneralStudentAnnouncement =
              role == 'student' &&
              targetEmail.isEmpty &&
              (('${notification['type'] ?? ''}' ==
                      'coordinator_announcement') ||
                  _sameValue(notification['audience'], 'student') ||
                  _sameValue(notification['audience'], 'students'));
          final requiresUniversityMatch =
              role == 'university' || isGeneralStudentAnnouncement;
          if (requiresUniversityMatch &&
              (targetUniversityId.isNotEmpty || targetUniversity.isNotEmpty)) {
            if (validInstitutionIds != null && validInstitutionIds.isNotEmpty) {
              if (targetUniversityId.isNotEmpty) {
                if (!_matchesAnyValue(
                  targetUniversityId,
                  validInstitutionIds,
                )) {
                  return notification;
                }
              } else if (!_matchesAnyInstitution(
                targetUniversity,
                validInstitutionNames ?? const <String>[],
              )) {
                return notification;
              }
            } else if (normalizedUniversityId.isNotEmpty) {
              if (targetUniversityId.isNotEmpty) {
                if (!_sameValue(targetUniversityId, normalizedUniversityId)) {
                  return notification;
                }
              } else if (validInstitutionNames != null &&
                  validInstitutionNames.isNotEmpty &&
                  !_matchesAnyInstitution(
                    targetUniversity,
                    validInstitutionNames,
                  )) {
                return notification;
              } else if (!_sameInstitution(targetUniversity, universityName)) {
                return notification;
              }
            } else if (validInstitutionNames != null &&
                validInstitutionNames.isNotEmpty) {
              if (!_matchesAnyInstitution(
                targetUniversity,
                validInstitutionNames,
              )) {
                return notification;
              }
            } else {
              return notification;
            }
          }

          final targetCompanyName =
              '${notification['target_company_name'] ?? ''}'.trim();
          if (role == 'company' &&
              targetCompanyName.isNotEmpty &&
              !_sameValue(targetCompanyName, companyName)) {
            return notification;
          }

          return {...notification, 'is_read': true};
        })
        .toList(growable: false);

    await _writeList(_notificationsKey, updated);
  }

  Future<void> deleteNotification(String notificationId) async {
    final notifications = await _readList(_notificationsKey);
    notifications.removeWhere(
      (notification) =>
          '${notification['notification_id'] ?? ''}' == notificationId,
    );
    await _writeList(_notificationsKey, notifications);
  }

  Future<List<Map<String, dynamic>>> _readList(String key) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(key);
    if (raw == null || raw.trim().isEmpty) {
      return <Map<String, dynamic>>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <Map<String, dynamic>>[];
      }

      return decoded
          .whereType<Map>()
          .map((item) => item.map((key, value) => MapEntry('$key', value)))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _writeList(String key, List<Map<String, dynamic>> items) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(key, jsonEncode(items));
  }

  Future<void> _appendNotification(Map<String, dynamic> notification) async {
    final notifications = await _readList(_notificationsKey);
    notifications.add(notification);
    await _writeList(_notificationsKey, notifications);
  }

  bool _audienceMatches({
    required String targetAudience,
    required String role,
  }) {
    final normalizedAudience = targetAudience.trim().toLowerCase();
    final normalizedRole = role.trim().toLowerCase();

    if (normalizedAudience == 'all') return true;
    if (normalizedRole == 'student' &&
        (normalizedAudience == 'student' || normalizedAudience == 'students')) {
      return true;
    }
    if (normalizedRole == 'company' &&
        (normalizedAudience == 'company' ||
            normalizedAudience == 'companies')) {
      return true;
    }
    if (normalizedRole == 'university' && normalizedAudience == 'university') {
      return true;
    }

    return false;
  }

  bool _sameValue(Object? left, Object? right) {
    return '$left'.trim().toLowerCase() == '$right'.trim().toLowerCase();
  }

  String _normalizedStatus(Object? value, {String fallback = ''}) {
    final normalized = '$value'.trim().toLowerCase();
    return normalized.isEmpty ? fallback : normalized;
  }

  bool _matchesAnyValue(Object? value, List<String> candidates) {
    for (final candidate in candidates) {
      if (_sameValue(value, candidate)) {
        return true;
      }
    }
    return false;
  }

  bool _sameInstitution(Object? left, Object? right) {
    final leftRaw = '$left'.trim();
    final rightRaw = '$right'.trim();
    if (leftRaw.isEmpty || rightRaw.isEmpty) return false;
    if (_sameValue(leftRaw, rightRaw)) return true;

    final leftNormalized = _normalizeInstitutionName(leftRaw);
    final rightNormalized = _normalizeInstitutionName(rightRaw);
    if (leftNormalized.isEmpty || rightNormalized.isEmpty) return false;
    if (leftNormalized == rightNormalized) return true;
    if (leftNormalized.contains(rightNormalized) ||
        rightNormalized.contains(leftNormalized)) {
      return true;
    }

    final leftTokens = leftNormalized
        .split(' ')
        .where((t) => t.isNotEmpty)
        .toSet();
    final rightTokens = rightNormalized
        .split(' ')
        .where((t) => t.isNotEmpty)
        .toSet();
    if (leftTokens.isEmpty || rightTokens.isEmpty) return false;

    final overlap = leftTokens.intersection(rightTokens).length;
    final requiredOverlap =
        (leftTokens.length < rightTokens.length
            ? leftTokens.length
            : rightTokens.length) -
        1;

    return overlap >= 2 && overlap >= requiredOverlap;
  }

  bool _matchesAnyInstitution(Object? institution, List<String> candidates) {
    for (final candidate in candidates) {
      if (_sameInstitution(institution, candidate)) {
        return true;
      }
    }
    return false;
  }

  String _normalizeInstitutionName(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll('&', ' and ')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  int _sortByDateDesc(Object? leftDate, Object? rightDate) {
    final left = DateTime.tryParse('${leftDate ?? ''}') ?? DateTime(1970);
    final right = DateTime.tryParse('${rightDate ?? ''}') ?? DateTime(1970);
    return right.compareTo(left);
  }

  DateTime? _parseDateTimeValue(Object? value) {
    final normalized = '$value'.trim();
    if (normalized.isEmpty) return null;
    return DateTime.tryParse(normalized);
  }

  String _generateId(String prefix) {
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}';
  }
}
