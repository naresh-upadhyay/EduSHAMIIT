import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'models/campus_models.dart';
import 'providers/campus_provider.dart';
import 'providers/facilities_provider.dart';
import 'services/campus_api_service.dart';
import 'widgets/campus_header_bar.dart';
import 'widgets/campus_tabs_bar.dart';
import 'widgets/campus_kpi_cards.dart';
import 'widgets/buildings/building_left_panel.dart';
import 'widgets/buildings/building_center_panel.dart';
import 'widgets/buildings/building_right_details_panel.dart';
import 'widgets/dialogs/add_edit_building_dialog.dart';
import 'widgets/dialogs/add_edit_building_document_dialog.dart';
import 'widgets/dialogs/add_edit_building_maintenance_dialog.dart';
import 'widgets/dialogs/add_edit_building_occupancy_dialog.dart';
import 'widgets/dialogs/assign_class_section_dialog.dart';
import 'widgets/dialogs/add_edit_floor_dialog.dart';
import 'widgets/dialogs/add_edit_room_dialog.dart';
import 'widgets/dialogs/bulk_create_rooms_dialog.dart';
import 'widgets/dialogs/bulk_import_rooms_dialog.dart';
import 'widgets/dialogs/room_equipment_dialog.dart';
import 'widgets/dialogs/room_details_drawer.dart';
import 'widgets/space_booking/space_booking_tab_view.dart';
import 'widgets/maintenance/maintenance_tab_view.dart';
import 'widgets/safety_compliance/safety_compliance_tab_view.dart';
import 'widgets/device_management/device_management_tab_view.dart';
import 'widgets/facilities/facilities_tab_view.dart';
import 'widgets/utilities/utilities_services_tab_view.dart';
import 'widgets/reports/campus_reports_tab_view.dart';
import 'services/space_booking_api_service.dart';
import 'services/maintenance_api_service.dart';
import 'services/safety_compliance_api_service.dart';
import 'services/device_management_api_service.dart';
import 'widgets/facilities/dialogs/add_edit_facility_dialog.dart';
import 'widgets/space_booking/dialogs/create_edit_booking_dialog.dart';
import 'widgets/maintenance/dialogs/create_edit_maintenance_dialog.dart';
import 'widgets/maintenance/dialogs/maintenance_plan_dialog.dart';
import 'widgets/safety_compliance/dialogs/report_incident_dialog.dart';
import 'widgets/safety_compliance/dialogs/schedule_drill_dialog.dart';
import 'widgets/device_management/dialogs/add_device_wizard_dialog.dart';
import 'widgets/utilities/dialogs/log_utility_reading_dialog.dart';
import 'providers/safety_compliance_provider.dart';
import '../../utils/tab_url_sync.dart';

class CampusManagementScreen extends ConsumerStatefulWidget {
  final int initialTab;

  const CampusManagementScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  ConsumerState<CampusManagementScreen> createState() => _CampusManagementScreenState();
}

class _CampusManagementScreenState extends ConsumerState<CampusManagementScreen> {
  bool _showKpis = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (widget.initialTab != 0) {
          ref.read(campusProvider.notifier).setActiveCampusTab(widget.initialTab);
        }
        ref.read(campusProvider.notifier).loadAll();
      }
    });
  }

  @override
  void didUpdateWidget(covariant CampusManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(campusProvider.notifier).setActiveCampusTab(widget.initialTab);
        }
      });
    }
  }

  // Dialog Helpers
  void _openAddBuildingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEditBuildingDialog(
        onSaved: () {
          ref.read(campusProvider.notifier).loadAll();
          _showSnackbar('Building created successfully!');
        },
      ),
    );
  }

  void _openEditBuildingDialog(BuildingModel building) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEditBuildingDialog(
        building: building,
        onSaved: () {
          ref.read(campusProvider.notifier).loadAll();
          _showSnackbar('Building updated successfully!');
        },
      ),
    );
  }

  void _archiveBuilding(BuildingModel building) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Archive ${building.name}?'),
        content: const Text(
          'Archiving this building preserves all historical rooms, timetables, and student allocations while marking it inactive for new assignments. Proceed?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
            child: const Text('Archive Building'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final res = await CampusApiService.instance.archiveBuilding(building.id);
      if (res['success'] == true) {
        ref.read(campusProvider.notifier).loadAll();
        _showSnackbar('Building successfully archived.');
      } else {
        _showSnackbar(res['message'] ?? 'Failed to archive building.', isError: true);
      }
    }
  }

  void _deleteBuilding(BuildingModel building) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${building.name}?'),
        content: const Text(
          'Are you sure you want to delete this building? Note: Buildings with active rooms or historical assignments cannot be deleted and must be archived instead.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete Building'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final res = await CampusApiService.instance.deleteBuilding(building.id);
      if (res['success'] == true) {
        ref.read(campusProvider.notifier).loadAll();
        _showSnackbar('Building deleted successfully.');
      } else {
        _showSnackbar(res['message'] ?? 'Cannot delete building.', isError: true);
      }
    }
  }

  void _openAddFloorDialog(BuildingModel building) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEditFloorDialog(
        buildingId: building.id,
        onSaved: () {
          ref.read(campusProvider.notifier).loadBuildingDetails(building.id);
          _showSnackbar('Floor added successfully!');
        },
      ),
    );
  }

  void _openEditFloorDialog(BuildingModel building, BuildingFloorModel floor) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEditFloorDialog(
        buildingId: building.id,
        floor: floor,
        onSaved: () {
          ref.read(campusProvider.notifier).loadBuildingDetails(building.id);
          _showSnackbar('Floor updated successfully!');
        },
      ),
    );
  }

  void _deleteFloor(BuildingModel building, BuildingFloorModel floor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Floor ${floor.name}?'),
        content: const Text(
          'Are you sure you want to delete this floor? Floors containing active rooms cannot be deleted.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete Floor'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final res = await CampusApiService.instance.deleteFloor(floor.id);
      if (res['success'] == true) {
        ref.read(campusProvider.notifier).loadBuildingDetails(building.id);
        _showSnackbar('Floor deleted successfully.');
      } else {
        _showSnackbar(res['message'] ?? 'Cannot delete floor.', isError: true);
      }
    }
  }

  void _openAddRoomDialog(BuildingModel building, List<BuildingFloorModel> floors) {
    if (floors.isEmpty) {
      _showSnackbar('Please add at least one floor before creating rooms.', isError: true);
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEditRoomDialog(
        building: building,
        floors: floors,
        onSavedWithFloor: (floorId) {
          ref.read(campusProvider.notifier).onRoomCreated(building.id, targetFloorId: floorId);
          _showSnackbar('Room created successfully!');
        },
      ),
    );
  }

  void _openEditRoomDialog(BuildingModel building, List<BuildingFloorModel> floors, RoomModel room) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEditRoomDialog(
        building: building,
        floors: floors,
        room: room,
        onSavedWithFloor: (floorId) async {
          await ref.read(campusProvider.notifier).onRoomCreated(building.id, targetFloorId: floorId);
          // Real-time update of inspectedRoom in the right sidebar
          final freshRooms = ref.read(campusProvider).rooms;
          final updated = freshRooms.cast<RoomModel?>().firstWhere(
            (r) => r?.id == room.id,
            orElse: () => null,
          );
          if (updated != null) {
            ref.read(campusProvider.notifier).inspectRoom(updated);
          }
          _showSnackbar('Room updated successfully!');
        },
      ),
    );
  }

  void _openRaiseMaintenanceForRoom(BuildingModel building, RoomModel room) {
    final location = '${building.name} / ${room.floorName ?? "Floor"} / Room ${room.roomNumber} - ${room.name}';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreateEditMaintenanceDialog(
        initialBuildingId: building.id,
        initialFloorId: room.floorId,
        initialRoomId: room.id,
        initialLocation: location,
        initialTitle: 'Room ${room.roomNumber} Maintenance - ${room.name}',
        onSaved: () {
          ref.read(campusProvider.notifier).loadBuildingMaintenance(building.id);
          _showSnackbar('Maintenance request raised successfully for Room ${room.roomNumber}!');
        },
      ),
    );
  }

  void _deleteRoom(BuildingModel building, RoomModel room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Room ${room.roomNumber}?'),
        content: const Text('Are you sure you want to delete this room? This action will mark it inactive.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete Room'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final res = await CampusApiService.instance.deleteRoom(room.id);
      if (res['success'] == true) {
        ref.read(campusProvider.notifier).loadBuildingDetails(building.id);
        _showSnackbar('Room deleted successfully.');
      } else {
        _showSnackbar(res['message'] ?? 'Cannot delete room.', isError: true);
      }
    }
  }

  void _openBulkCreateDialog(BuildingModel building, List<BuildingFloorModel> floors) {
    if (floors.isEmpty) {
      _showSnackbar('Please add at least one floor before creating rooms.', isError: true);
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BulkCreateRoomsDialog(
        building: building,
        floors: floors,
        onSaved: () {
          ref.read(campusProvider.notifier).loadBuildingDetails(building.id);
          _showSnackbar('Rooms successfully created in bulk!');
        },
      ),
    );
  }

  void _openBulkImportDialog(BuildingModel? building) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BulkImportRoomsDialog(
        onImportCompleted: () {
          if (building != null) {
            ref.read(campusProvider.notifier).loadBuildingDetails(building.id);
          } else {
            ref.read(campusProvider.notifier).loadAll();
          }
          _showSnackbar('Import processed successfully!');
        },
      ),
    );
  }

  void _openEquipmentDialog(RoomModel room) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => RoomEquipmentDialog(
        room: room,
        onUpdated: () {
          if (ref.read(campusProvider).selectedBuilding != null) {
            ref.read(campusProvider.notifier).reloadRooms();
          }
        },
      ),
    );
  }

  Future<Uint8List?> _cropBuildingImage(String sourcePath) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Building Image',
          toolbarColor: const Color(0xFF0F172A),
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.ratio16x9,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: 'Crop Building Image',
          aspectRatioLockEnabled: false,
        ),
        WebUiSettings(
          context: context,
          presentStyle: WebPresentStyle.dialog,
          size: const CropperSize(width: 520, height: 320),
          zoomable: true,
          rotatable: true,
          scalable: true,
        ),
      ],
    );
    if (croppedFile != null) {
      return await croppedFile.readAsBytes();
    }
    return null;
  }

  void _updateBuildingPhoto(BuildingModel building) async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        imageQuality: 90,
      );
      if (picked == null || !mounted) return;

      Uint8List? croppedBytes;
      try {
        croppedBytes = await _cropBuildingImage(picked.path);
      } catch (cropErr) {
        debugPrint('ImageCropper error, falling back to raw image bytes: $cropErr');
        croppedBytes = await picked.readAsBytes();
      }
      if (croppedBytes == null || !mounted) return;

      String filename = picked.name;
      if (!filename.contains('.')) {
        filename += '.jpg';
      }

      _showSnackbar('Uploading cropped building image...');
      final uploadedUrl = await CampusApiService.instance.uploadImage(croppedBytes, filename);
      String? photoUrl = (uploadedUrl != null && uploadedUrl.isNotEmpty) ? uploadedUrl : null;
      if (photoUrl == null) {
        final b64 = base64Encode(croppedBytes);
        final ext = filename.split('.').last.toLowerCase();
        final mime = ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
        photoUrl = 'data:$mime;base64,$b64';
      }

      final saveRes = await CampusApiService.instance.updateBuildingPhoto(building.id, photoUrl);
      if (saveRes['success'] == true || saveRes['status'] == 'success') {
        ref.read(campusProvider.notifier).updateBuildingImage(building.id, photoUrl);
        await ref.read(campusProvider.notifier).loadAll();
        ref.read(campusProvider.notifier).updateBuildingImage(building.id, photoUrl);
        _showSnackbar('Building photo updated successfully!');
      } else {
        _showSnackbar(saveRes['message'] ?? 'Failed to save building photo. Please try again.', isError: true);
      }
    } catch (e) {
      _showSnackbar('Failed to update image: $e', isError: true);
    }
  }

  // Occupancy CRUD Dialogs
  void _openAddOccupancyDialog(BuildingModel building, List<RoomModel> rooms) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AssignClassSectionDialog(
        building: building,
        rooms: rooms,
        onSaved: () {
          ref.read(campusProvider.notifier).loadBuildingOccupancy(building.id);
          _showSnackbar('Class/Section successfully allocated to space via Space Booking!');
        },
      ),
    );
  }

  void _openEditOccupancyDialog(BuildingModel building, List<RoomModel> rooms, BuildingOccupancyModel occupancy) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEditBuildingOccupancyDialog(
        building: building,
        rooms: rooms,
        occupancy: occupancy,
        onSaved: () {
          ref.read(campusProvider.notifier).loadBuildingOccupancy(building.id);
          _showSnackbar('Allocation updated successfully!');
        },
      ),
    );
  }

  void _deleteOccupancy(BuildingModel building, BuildingOccupancyModel occupancy) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Release Allocation for ${occupancy.referenceName}?'),
        content: const Text('Are you sure you want to release this space assignment?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Release Space'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref.read(campusProvider.notifier).deleteBuildingOccupancy(building.id, occupancy.id);
      if (success) {
        _showSnackbar('Space assignment released.');
      } else {
        _showSnackbar('Failed to release space assignment.', isError: true);
      }
    }
  }

  // Maintenance CRUD Dialogs
  void _openAddMaintenanceDialog(BuildingModel building, List<BuildingFloorModel> floors, List<RoomModel> rooms) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEditBuildingMaintenanceDialog(
        building: building,
        floors: floors,
        rooms: rooms,
        onSaved: () {
          ref.read(campusProvider.notifier).loadBuildingMaintenance(building.id);
          _showSnackbar('Maintenance request logged successfully!');
        },
      ),
    );
  }

  void _openEditMaintenanceDialog(BuildingModel building, List<BuildingFloorModel> floors, List<RoomModel> rooms, BuildingMaintenanceModel m) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEditBuildingMaintenanceDialog(
        building: building,
        floors: floors,
        rooms: rooms,
        maintenance: m,
        onSaved: () {
          ref.read(campusProvider.notifier).loadBuildingMaintenance(building.id);
          _showSnackbar('Maintenance request updated successfully!');
        },
      ),
    );
  }

  void _deleteMaintenance(BuildingModel building, BuildingMaintenanceModel m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Request ${m.requestCode}?'),
        content: const Text('Are you sure you want to delete this maintenance request?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete Request'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref.read(campusProvider.notifier).deleteBuildingMaintenance(building.id, m.id);
      if (success) {
        _showSnackbar('Maintenance request deleted.');
      } else {
        _showSnackbar('Failed to delete maintenance request.', isError: true);
      }
    }
  }

  void _quickUpdateMaintenanceStatus(BuildingModel building, BuildingMaintenanceModel m, String status) async {
    final success = await ref.read(campusProvider.notifier).updateBuildingMaintenanceStatus(building.id, m.id, status);
    if (success) {
      _showSnackbar('Request status updated to $status.');
    } else {
      _showSnackbar('Failed to update status.', isError: true);
    }
  }

  // Documents CRUD Dialogs
  void _openAddDocumentDialog(BuildingModel building) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEditBuildingDocumentDialog(
        building: building,
        onSaved: () {
          ref.read(campusProvider.notifier).loadBuildingDocuments(building.id);
          _showSnackbar('Document uploaded successfully!');
        },
      ),
    );
  }

  void _openEditDocumentDialog(BuildingModel building, BuildingDocumentModel doc) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEditBuildingDocumentDialog(
        building: building,
        document: doc,
        onSaved: () {
          ref.read(campusProvider.notifier).loadBuildingDocuments(building.id);
          _showSnackbar('Document updated successfully!');
        },
      ),
    );
  }

  void _deleteDocument(BuildingModel building, BuildingDocumentModel doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${doc.documentName}?'),
        content: const Text('Are you sure you want to delete this document attachment?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete Document'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref.read(campusProvider.notifier).deleteBuildingDocument(building.id, doc.id);
      if (success) {
        _showSnackbar('Document deleted.');
      } else {
        _showSnackbar('Failed to delete document.', isError: true);
      }
    }
  }

  // Multi-Tab Action Dialogs
  void _openAddFacilityModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEditFacilityDialog(
        onSaved: () {
          ref.read(facilitiesProvider.notifier).loadData();
          _showSnackbar('Facility registered successfully!');
        },
      ),
    );
  }

  void _openBookSpaceModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CreateEditBookingDialog(),
    );
  }

  void _openRaiseMaintenanceRequestModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CreateEditMaintenanceDialog(),
    );
  }

  void _openMaintenancePlanModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const MaintenancePlanDialog(),
    );
  }

  void _openReportSafetyIncidentModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ReportIncidentDialog(),
    );
  }

  void _openScheduleDrillModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ScheduleDrillDialog(),
    );
  }

  void _openAddDeviceModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddDeviceWizardDialog(
        onSaved: () => _showSnackbar('Device registered successfully!'),
      ),
    );
  }

  void _openLogUtilityReadingModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => LogUtilityReadingDialog(
        onSaved: () => _showSnackbar('Utility reading logged successfully!'),
      ),
    );
  }

  void _handleTabExport(int activeTab, BuildingModel? currentBuilding) {
    switch (activeTab) {
      case 1:
        CampusApiService.instance.exportData('facilities');
        _showSnackbar('Exporting campus facilities CSV...');
        break;
      case 2:
        SpaceBookingApiService.instance.exportCsv(buildingId: currentBuilding?.id);
        _showSnackbar('Exporting space bookings CSV...');
        break;
      case 3:
        MaintenanceApiService.instance.exportCsv();
        _showSnackbar('Exporting maintenance requests CSV...');
        break;
      case 4:
        SafetyComplianceApiService.instance.exportCsv('inspections');
        _showSnackbar('Exporting safety compliance inspections CSV...');
        break;
      case 5:
        DeviceManagementApiService.instance.exportDevicesCsv();
        _showSnackbar('Exporting smart campus devices CSV...');
        break;
      case 6:
        CampusApiService.instance.exportCampusReport(reportType: 4);
        _showSnackbar('Exporting campus energy & utilities CSV...');
        break;
      case 7:
        CampusApiService.instance.exportCampusReport(reportType: 0, buildingId: currentBuilding?.id);
        _showSnackbar('Exporting campus executive report CSV...');
        break;
      default:
        CampusApiService.instance.exportData('rooms', buildingId: currentBuilding?.id);
        _showSnackbar('Exporting campus rooms CSV...');
    }
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildCenterPanel(BuildingModel bld, CampusState state, CampusNotifier notifier) {
    return BuildingCenterPanel(
      building: bld,
      buildingDetails: state.selectedBuildingDetails,
      activeSubTab: state.activeBuildingSubTab,
      onSubTabChanged: notifier.setActiveBuildingSubTab,
      onEditBuilding: () => _openEditBuildingDialog(bld),
      onArchiveBuilding: () => _archiveBuilding(bld),
      onDeleteBuilding: () => _deleteBuilding(bld),
      floors: state.floors,
      isFloorsLoading: state.isFloorsLoading,
      onAddFloor: () => _openAddFloorDialog(bld),
      onEditFloor: (f) => _openEditFloorDialog(bld, f),
      onDeleteFloor: (f) => _deleteFloor(bld, f),
      onViewRoomsOnFloor: (f) {
        notifier.setFilterFloor(f.id);
        notifier.setActiveBuildingSubTab(1);
      },
      totalFloorsCount: state.totalFloorsCount,
      floorsPage: state.floorsPage,
      floorsPageSize: state.floorsPageSize,
      onFloorsPageChanged: notifier.setFloorsPage,
      onFloorsPageSizeChanged: notifier.setFloorsPageSize,
      floorsSortBy: state.floorsSortBy,
      floorsSortOrder: state.floorsSortOrder,
      onFloorsSortChanged: notifier.setFloorSort,
      rooms: state.rooms,
      isRoomsLoading: state.isRoomsLoading,
      roomsViewMode: state.roomsViewMode,
      onRoomsViewModeChanged: notifier.setRoomsViewMode,
      roomSearchQuery: state.roomSearchQuery,
      onRoomSearch: notifier.setRoomSearch,
      filterFloorId: state.filterFloorId,
      onFilterFloor: notifier.setFilterFloor,
      filterRoomType: state.filterRoomType,
      onFilterRoomType: notifier.setFilterRoomType,
      filterStatus: state.filterRoomStatus,
      onFilterStatus: notifier.setFilterRoomStatus,
      onClearRoomFilters: notifier.clearFilters,
      onAddRoom: () => _openAddRoomDialog(bld, state.floors),
      onBulkCreateRooms: () => _openBulkCreateDialog(bld, state.floors),
      onInspectRoom: notifier.inspectRoom,
      onEditRoom: (r) => _openEditRoomDialog(bld, state.floors, r),
      onManageEquipment: _openEquipmentDialog,
      onDeleteRoom: (r) => _deleteRoom(bld, r),
      totalRoomsCount: state.totalRoomsCount,
      roomsPage: state.roomsPage,
      roomsPageSize: state.roomsPageSize,
      onRoomsPageChanged: notifier.setRoomsPage,
      onRoomsPageSizeChanged: notifier.setRoomsPageSize,
      roomsSortBy: state.roomsSortBy,
      roomsSortOrder: state.roomsSortOrder,
      onRoomsSortChanged: notifier.setRoomSort,
      occupancyList: state.buildingOccupancy,
      isOccupancyLoading: state.isOccupancyLoading,
      onAddOccupancy: () => _openAddOccupancyDialog(bld, state.rooms),
      onEditOccupancy: (occ) => _openEditOccupancyDialog(bld, state.rooms, occ),
      onDeleteOccupancy: (occ) => _deleteOccupancy(bld, occ),
      maintenanceList: state.buildingMaintenance,
      isMaintenanceLoading: state.isMaintenanceLoading,
      onAddMaintenance: () => _openAddMaintenanceDialog(bld, state.floors, state.rooms),
      onEditMaintenance: (m) => _openEditMaintenanceDialog(bld, state.floors, state.rooms, m),
      onDeleteMaintenance: (m) => _deleteMaintenance(bld, m),
      onQuickUpdateMaintenanceStatus: (m, status) => _quickUpdateMaintenanceStatus(bld, m, status),
      documentsList: state.buildingDocuments,
      isDocumentsLoading: state.isDocumentsLoading,
      onAddDocument: () => _openAddDocumentDialog(bld),
      onEditDocument: (d) => _openEditDocumentDialog(bld, d),
      onDeleteDocument: (d) => _deleteDocument(bld, d),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(campusProvider);
    final notifier = ref.read(campusProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Stack(
          children: [
            // Main Scrollable Dashboard View
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Campus Header Bar (Dynamically adapts actions & title to active tab)
                  CampusHeaderBar(
                    activeTab: state.activeCampusTab,
                    onAddBuilding: _openAddBuildingDialog,
                    onBulkImport: () => _openBulkImportDialog(state.selectedBuilding),
                    onExport: () => _handleTabExport(state.activeCampusTab, state.selectedBuilding),
                    onAddFacility: _openAddFacilityModal,
                    onBookSpace: _openBookSpaceModal,
                    onRaiseMaintenanceRequest: _openRaiseMaintenanceRequestModal,
                    onMaintenancePlan: _openMaintenancePlanModal,
                    onReportSafetyIncident: _openReportSafetyIncidentModal,
                    onScheduleDrill: _openScheduleDrillModal,
                    onAddDevice: _openAddDeviceModal,
                    onLogUtilityReading: _openLogUtilityReadingModal,
                    onExportReport: () => _handleTabExport(7, state.selectedBuilding),
                  ),
                  const SizedBox(height: 12),

                  // Campus Navigation Tabs Header (Buildings & Rooms [ACTIVE], Facilities, Space Booking, etc.)
                  CampusTabsBar(
                    activeIndex: state.activeCampusTab,
                    isKpisVisible: _showKpis,
                    onToggleKpis: () => setState(() => _showKpis = !_showKpis),
                    onTabSelected: (idx) {
                      notifier.setActiveCampusTab(idx);
                      updateTabUrl('/admin/campus', idx);
                    },
                  ),
                  const SizedBox(height: 8),

                  // Emergency Life Safety Incident Banner
                  Builder(
                    builder: (context) {
                      final critIncidents = ref.watch(safetyComplianceProvider).kpis.criticalIncidents;
                      if (critIncidents <= 0) return const SizedBox.shrink();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFDC2626).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'CRITICAL ALERT: $critIncidents Active Critical Safety Incident(s)! Immediate Review & Life Safety Interlock Available.',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                notifier.setActiveCampusTab(4); // Jump to Safety & Compliance tab
                                updateTabUrl('/admin/campus', 4);
                              },
                              child: const Text('View Safety Dashboard', style: TextStyle(color: Colors.white, decoration: TextDecoration.underline, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Collapsible Institutional KPI Cards Row (Visible across all tabs when Stats is toggled)
                  if (_showKpis) ...[
                    CampusKpiCards(kpis: state.kpis),
                    const SizedBox(height: 8),
                  ],

                  if (state.activeCampusTab == 1)
                    const Expanded(child: FacilitiesTabView())
                  else if (state.activeCampusTab == 2)
                    const Expanded(child: SpaceBookingTabView())
                  else if (state.activeCampusTab == 3)
                    const Expanded(child: MaintenanceTabView())
                  else if (state.activeCampusTab == 4)
                    const Expanded(child: SafetyComplianceTabView())
                  else if (state.activeCampusTab == 5)
                    const Expanded(child: DeviceManagementTabView())
                  else if (state.activeCampusTab == 6)
                    const Expanded(child: UtilitiesServicesTabView())
                  else if (state.activeCampusTab == 7)
                    const Expanded(child: CampusReportsTabView())
                  else ...[
                    // Three-Column Split Dashboard Area
                    Expanded(
                      child: LayoutBuilder(
                      builder: (context, constraints) {
                        final screenWidth = constraints.maxWidth;
                        final bld = state.selectedBuilding ?? (state.buildings.isNotEmpty ? state.buildings.first : null);
                        final primaryColor = Theme.of(context).colorScheme.primary;

                        if (state.isLoading) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Loading campus buildings and facilities...',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        if (bld == null) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.domain_disabled_rounded, size: 48, color: Color(0xFF94A3B8)),
                                const SizedBox(height: 12),
                                const Text('No buildings available. Click below to add the first building.', style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: _openAddBuildingDialog,
                                  icon: const Icon(Icons.add, color: Colors.white),
                                  label: const Text('Add Building', style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                                ),
                              ],
                            ),
                          );
                        }

                        if (screenWidth > 1200) {
                          // Desktop 3-Column Split
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left Building Selector Panel (width ~290px)
                              SizedBox(
                                width: 290,
                                child: BuildingLeftPanel(
                                  buildings: state.buildings,
                                  selectedBuilding: state.selectedBuilding,
                                  onSelectBuilding: notifier.selectBuilding,
                                  onAddBuilding: _openAddBuildingDialog,
                                  searchQuery: state.buildingSearchQuery,
                                  onSearch: notifier.setBuildingSearchQuery,
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Center Active Building Area (Flex expanded)
                              Expanded(
                                child: _buildCenterPanel(bld, state, notifier),
                              ),
                              const SizedBox(width: 14),

                              // Right Building Details & Quick Actions Panel (width ~290px)
                              SizedBox(
                                width: 290,
                                child: BuildingRightDetailsPanel(
                                  building: bld,
                                  onUpdateImage: () => _updateBuildingPhoto(bld),
                                  onAddRoom: () => _openAddRoomDialog(bld, state.floors),
                                  onRaiseMaintenance: () => _openRaiseMaintenanceRequestModal(),
                                  onRoomSetup: () => notifier.setActiveBuildingSubTab(1),
                                  onImportRooms: () => _openBulkImportDialog(bld),
                                  onExportList: () => CampusApiService.instance.exportData('rooms', buildingId: bld.id),
                                  onRoomReport: () => _showSnackbar('Generating institutional infrastructure report...'),
                                ),
                              ),
                            ],
                          );
                        } else if (screenWidth >= 800) {
                          // Medium / Tablet Screen layout: Left panel + Center panel
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 240,
                                child: BuildingLeftPanel(
                                  buildings: state.buildings,
                                  selectedBuilding: state.selectedBuilding,
                                  onSelectBuilding: notifier.selectBuilding,
                                  onAddBuilding: _openAddBuildingDialog,
                                  searchQuery: state.buildingSearchQuery,
                                  onSearch: notifier.setBuildingSearchQuery,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildCenterPanel(bld, state, notifier),
                              ),
                            ],
                          );
                        } else {
                          // Mobile Single-Column Layout (< 800px)
                          return SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Mobile Building Selector Card
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.apartment_rounded, color: Color(0xFF2563EB), size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: bld.id,
                                            isExpanded: true,
                                            items: state.buildings.map((b) => DropdownMenuItem(
                                              value: b.id,
                                              child: Text(
                                                '${b.code} - ${b.name}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            )).toList(),
                                            onChanged: (val) {
                                              if (val != null) {
                                                final found = state.buildings.firstWhere((b) => b.id == val, orElse: () => bld);
                                                notifier.selectBuilding(found);
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        onPressed: _openAddBuildingDialog,
                                        icon: const Icon(Icons.add_circle, color: Color(0xFF2563EB)),
                                        tooltip: 'Add Building',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                ),
                                // Full-width BuildingCenterPanel
                                _buildCenterPanel(bld, state, notifier),
                              ],
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),

            // Slide-in Room Details Drawer (when a room is inspected)
            if (state.inspectedRoom != null && state.selectedBuilding != null)
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                child: Material(
                  elevation: 16,
                  child: RoomDetailsDrawer(
                    room: state.inspectedRoom!,
                    building: state.selectedBuilding!,
                    onClose: () => notifier.inspectRoom(null),
                    onEdit: () {
                      final r = state.inspectedRoom!;
                      _openEditRoomDialog(state.selectedBuilding!, state.floors, r);
                    },
                    onManageEquipment: () {
                      final r = state.inspectedRoom!;
                      _openEquipmentDialog(r);
                    },
                    onRaiseMaintenance: () {
                      final r = state.inspectedRoom!;
                      _openRaiseMaintenanceForRoom(state.selectedBuilding!, r);
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
