library edu_shamiit_core;

// Config
export 'config/app_config.dart';
export 'config/app_config_host.dart';

// Constants
export 'constants/app_fonts.dart';
export 'constants/app_gradients.dart';
export 'constants/student_colors.dart';
export 'constants/teacher_colors.dart';
export 'constants/mock_data.dart';

// Theme
export 'theme/responsive_dialog_padding.dart';
export 'theme/student_theme.dart';
export 'theme/teacher_theme.dart';

// Models
export 'models/document_model.dart';
export 'models/student_models.dart';
export 'models/teacher_models.dart';

// Services
export 'services/api_service.dart';
export 'services/supabase_service.dart';
export 'services/cache_service.dart';
export 'services/websocket_service.dart';
export 'services/biometric_service.dart';
export 'services/tts_service.dart';
export 'services/notification_service.dart';
export 'services/lookup_event_bus.dart';

// Providers
export 'providers/settings_provider.dart';
export 'providers/role_provider.dart';
export 'providers/api_provider.dart';
export 'providers/cache_provider.dart';
export 'providers/auth_provider.dart';
export 'providers/profile_provider.dart' hide DocumentModel;
export 'providers/teacher_profile_provider.dart';
export 'providers/system_config_provider.dart';

// Utils
export 'utils/responsive.dart';
export 'utils/validators.dart';
export 'utils/date_formatter.dart';
export 'utils/math_formatter.dart';
export 'utils/l10n.dart';
export 'utils/download_helper.dart';

// Widgets
export 'widgets/ai_fab.dart';
export 'widgets/calendar_picker.dart';
export 'widgets/responsive_content.dart';
export 'widgets/in_app_notification_overlay.dart';
export 'widgets/image_preview_dialog.dart';
export 'widgets/public_footer.dart';
export 'widgets/public_drawer.dart';

// Shared Auth Screens
export 'screens/auth/login_screen.dart';
export 'screens/auth/unauthorized_role_screen.dart';
export 'screens/auth/not_found_screen.dart';
export 'screens/auth/forgot_password_screen.dart';
export 'screens/auth/otp_verification_screen.dart';
export 'screens/auth/reset_password_screen.dart';
export 'screens/auth/password_reset_success_screen.dart';
export 'screens/auth/contact_us_screen.dart';
export 'screens/auth/home_screen.dart';
export 'screens/auth/privacy_policy_screen.dart';
export 'screens/auth/terms_conditions_screen.dart';
export 'screens/auth/get_started_screen.dart';
export 'screens/auth/faq_screen.dart';
export 'screens/auth/user_guides_screen.dart';
export 'screens/auth/help_center_screen.dart';
export 'screens/auth/careers_screen.dart';
export 'screens/auth/job_details_screen.dart';

// Shared Calendar Module
export 'screens/calendar/universal_calendar_screen.dart';
export 'screens/calendar/models/calendar_models.dart';
export 'screens/calendar/providers/calendar_provider.dart';

// Shared Notices & Circulars Module
export 'screens/notices/universal_notices_screen.dart';
export 'screens/notices/models/notice_models.dart';
export 'screens/notices/providers/notice_provider.dart';
export 'screens/notices/services/notice_api_service.dart';

// Shared Lookup Management Module
export 'screens/lookups/lookup_management_screen.dart';
export 'screens/lookups/models/lookup_models.dart';
export 'screens/lookups/providers/lookup_provider.dart';
export 'screens/lookups/services/lookup_api_service.dart';

// Shared Academic Class Management Module
export 'screens/classes/class_management_screen.dart';
export 'screens/classes/models/class_models.dart';
export 'screens/classes/providers/class_provider.dart';
export 'screens/classes/services/class_api_service.dart';

// Shared Attendance Management Module
export 'screens/attendance/attendance_management_screen.dart';
export 'screens/attendance/models/attendance_models.dart';
export 'screens/attendance/providers/attendance_provider.dart';
export 'screens/attendance/services/attendance_api_service.dart';
export 'screens/attendance/widgets/daily_attendance_tab.dart';
export 'screens/attendance/widgets/staff_attendance_tab.dart';
export 'screens/attendance/widgets/leave_permissions_tab.dart';
export 'screens/attendance/widgets/bulk_operations_tab.dart';
export 'screens/attendance/widgets/attendance_insights_tab.dart';
export 'screens/attendance/widgets/attendance_settings_tab.dart';
export 'screens/attendance/widgets/drawers/student_attendance_drawer.dart';
export 'screens/attendance/widgets/dialogs/attendance_override_dialog.dart';
export 'screens/attendance/widgets/dialogs/attendance_confirmation_dialog.dart';

// Shared Library Management Module
export 'screens/library/library_management_screen.dart';
export 'screens/library/models/book_models.dart';
export 'screens/library/providers/book_provider.dart';
export 'screens/library/services/library_api_service.dart';
export 'screens/library/widgets/book_header_bar.dart';
export 'screens/library/widgets/book_kpi_cards.dart';
export 'screens/library/widgets/book_filter_bar.dart';
export 'screens/library/widgets/book_table.dart';
export 'screens/library/widgets/book_details_drawer.dart';
export 'screens/library/widgets/dialogs/add_edit_book_dialog.dart';
export 'screens/library/widgets/dialogs/add_copy_dialog.dart';
export 'screens/library/widgets/dialogs/barcode_qr_dialog.dart';
export 'screens/library/widgets/dialogs/import_books_dialog.dart';
export 'screens/library/widgets/dialogs/scan_book_dialog.dart';
export 'screens/library/widgets/dialogs/advanced_filter_dialog.dart';
export 'screens/library/widgets/dialogs/bulk_operations_dialog.dart';

// URL & Navigation Sync
export 'utils/tab_url_sync.dart';
export 'utils/nav_helper.dart';

// Messaging & AI Chat
export 'screens/messaging/messaging_screen.dart';
export 'screens/ai_chat/ai_chat_screen.dart';

// Documents
export 'screens/documents/documents_screen.dart';

// Profile
export 'screens/profile/my_profile_screen.dart';

// Exams Module
export 'screens/exams/exams_management_screen.dart';
export 'screens/exams/screens/create_exam_screen.dart';
export 'screens/exams/screens/question_bank_screen.dart';
export 'screens/exams/screens/assign_exam_screen.dart';
export 'screens/exams/screens/exam_analytics_screen.dart';
export 'screens/exams/screens/exam_paper_builder_screen.dart';
export 'screens/exams/screens/exam_prestart_screen.dart';
export 'screens/exams/screens/manual_evaluation_screen.dart';
export 'screens/exams/screens/publish_result_screen.dart';
export 'screens/exams/screens/take_exam_screen.dart';
export 'screens/exams/screens/live_monitoring_screen.dart';

// Live Classes
export 'screens/live_classes/live_class_management_screen.dart';
export 'screens/live_classes/utils/live_class_theme.dart';

// Hostel Module
export 'screens/hostel/hostel_management_screen.dart';

// Campus Module
export 'screens/campus/campus_management_screen.dart';
export 'screens/campus/models/campus_models.dart';
export 'screens/campus/models/space_booking_models.dart';
export 'screens/campus/providers/campus_provider.dart';

// Visitors Module
export 'screens/visitors/visitors_management_screen.dart';

// Work Management Module
export 'screens/work_management/work_management_screen.dart';

// Inventory Module
export 'screens/inventory/inventory_management_screen.dart';

// Payment / Finance Module
export 'screens/payment_management/student_fee_management_screen.dart';
export 'screens/payment_management/staff_salary_management_screen.dart';
export 'screens/payment_management/models/student_fee_models.dart';
export 'screens/payment_management/models/staff_salary_models.dart';
export 'screens/payment_management/providers/student_fee_provider.dart';
export 'screens/payment_management/providers/staff_salary_provider.dart';
export 'screens/payment_management/services/payment_management_api_service.dart';
export 'screens/payment_management/services/payment_lookup_helper.dart';

// Calls & Overlay
export 'services/call_service.dart';
export 'widgets/call_notification_overlay.dart';



