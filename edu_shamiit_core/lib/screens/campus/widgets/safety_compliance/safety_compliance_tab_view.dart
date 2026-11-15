import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/safety_compliance_models.dart';
import '../../providers/safety_compliance_provider.dart';
import 'safety_compliance_kpis_bar.dart';
import 'safety_compliance_left_panel.dart';
import 'safety_compliance_center_panel.dart';
import 'safety_compliance_right_panel.dart';
import 'dialogs/report_incident_dialog.dart';
import 'dialogs/log_inspection_dialog.dart';
import 'dialogs/add_certificate_dialog.dart';
import 'dialogs/schedule_drill_dialog.dart';
import 'dialogs/safety_details_drawer.dart';

class SafetyComplianceTabView extends ConsumerStatefulWidget {
  const SafetyComplianceTabView({super.key});

  @override
  ConsumerState<SafetyComplianceTabView> createState() => _SafetyComplianceTabViewState();
}

class _SafetyComplianceTabViewState extends ConsumerState<SafetyComplianceTabView> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(safetyComplianceProvider);
    final notifier = ref.read(safetyComplianceProvider.notifier);

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isDesktop = screenWidth >= 1200;
        final isTablet = screenWidth >= 800 && screenWidth < 1200;
        
        return Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Top KPI Cards Row
                  const SafetyComplianceKpisBar(),
                  const SizedBox(height: 16),

                  // 2. Responsive Multi-Panel Grid
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column (250px)
                        SizedBox(
                          width: 250,
                          child: SafetyComplianceLeftPanel(
                            onOpenReportIncident: () => _openReportIncidentModal(context),
                            onOpenLogInspection: () => _openLogInspectionModal(context),
                            onOpenScheduleDrill: () => _openScheduleDrillModal(context),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Center Column (Flex Expanded)
                        Expanded(
                          child: SafetyComplianceCenterPanel(
                            onOpenLogInspection: () => _openLogInspectionModal(context),
                            onOpenReportIncident: () => _openReportIncidentModal(context),
                            onOpenAddCertificate: () => _openAddCertificateModal(context),
                            onOpenScheduleDrill: () => _openScheduleDrillModal(context),
                            onInspectItem: (item) => notifier.selectItem(item),
                            onEditItem: (item) => _handleEditItem(context, item),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Right Column (280px)
                        SafetyComplianceRightPanel(
                          width: 280,
                          onOpenScheduleDrill: () => _openScheduleDrillModal(context),
                          onOpenAddCertificate: () => _openAddCertificateModal(context),
                          onOpenReportIncident: () => _openReportIncidentModal(context),
                        ),
                      ],
                    )
                  else if (isTablet)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Navigation Column (230px)
                        SizedBox(
                          width: 230,
                          child: SafetyComplianceLeftPanel(
                            onOpenReportIncident: () => _openReportIncidentModal(context),
                            onOpenLogInspection: () => _openLogInspectionModal(context),
                            onOpenScheduleDrill: () => _openScheduleDrillModal(context),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Center + Right Stacked Column (Expanded)
                        Expanded(
                          child: Column(
                            children: [
                              SafetyComplianceCenterPanel(
                                onOpenLogInspection: () => _openLogInspectionModal(context),
                                onOpenReportIncident: () => _openReportIncidentModal(context),
                                onOpenAddCertificate: () => _openAddCertificateModal(context),
                                onOpenScheduleDrill: () => _openScheduleDrillModal(context),
                                onInspectItem: (item) => notifier.selectItem(item),
                                onEditItem: (item) => _handleEditItem(context, item),
                              ),
                              const SizedBox(height: 16),
                              SafetyComplianceRightPanel(
                                onOpenScheduleDrill: () => _openScheduleDrillModal(context),
                                onOpenAddCertificate: () => _openAddCertificateModal(context),
                                onOpenReportIncident: () => _openReportIncidentModal(context),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    // Mobile (Single Column Stack)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SafetyComplianceLeftPanel(
                          onOpenReportIncident: () => _openReportIncidentModal(context),
                          onOpenLogInspection: () => _openLogInspectionModal(context),
                          onOpenScheduleDrill: () => _openScheduleDrillModal(context),
                        ),
                        const SizedBox(height: 16),
                        SafetyComplianceCenterPanel(
                          onOpenLogInspection: () => _openLogInspectionModal(context),
                          onOpenReportIncident: () => _openReportIncidentModal(context),
                          onOpenAddCertificate: () => _openAddCertificateModal(context),
                          onOpenScheduleDrill: () => _openScheduleDrillModal(context),
                          onInspectItem: (item) => notifier.selectItem(item),
                          onEditItem: (item) => _handleEditItem(context, item),
                        ),
                        const SizedBox(height: 16),
                        SafetyComplianceRightPanel(
                          onOpenScheduleDrill: () => _openScheduleDrillModal(context),
                          onOpenAddCertificate: () => _openAddCertificateModal(context),
                          onOpenReportIncident: () => _openReportIncidentModal(context),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Slide-over Details Drawer
            if (state.selectedItem != null)
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                child: Material(
                  elevation: 16,
                  child: SafetyDetailsDrawer(
                    item: state.selectedItem,
                    onClose: () => notifier.clearSelectedItem(),
                    onEdit: () => _handleEditItem(context, state.selectedItem),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _openReportIncidentModal(BuildContext context, {SafetyIncidentItem? item}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReportIncidentDialog(existingIncident: item),
    );
  }

  void _openLogInspectionModal(BuildContext context, {SafetyInspectionItem? item}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => LogInspectionDialog(existingInspection: item),
    );
  }

  void _openAddCertificateModal(BuildContext context, {ComplianceCertificateItem? item}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddCertificateDialog(existingCertificate: item),
    );
  }

  void _openScheduleDrillModal(BuildContext context, {SafetyDrillItem? item}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ScheduleDrillDialog(existingDrill: item),
    );
  }

  void _handleEditItem(BuildContext context, dynamic item) {
    if (item is SafetyInspectionItem) {
      _openLogInspectionModal(context, item: item);
    } else if (item is SafetyIncidentItem) {
      _openReportIncidentModal(context, item: item);
    } else if (item is ComplianceCertificateItem) {
      _openAddCertificateModal(context, item: item);
    } else if (item is SafetyDrillItem) {
      _openScheduleDrillModal(context, item: item);
    }
  }
}
