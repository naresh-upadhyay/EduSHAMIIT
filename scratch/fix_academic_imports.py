import os
import re

core_files = {
    'app_config.dart', 'app_config_host.dart', 'app_fonts.dart', 'app_gradients.dart',
    'mock_data.dart', 'student_colors.dart', 'teacher_colors.dart', 'document_model.dart',
    'student_models.dart', 'teacher_models.dart', 'api_provider.dart', 'auth_provider.dart',
    'cache_provider.dart', 'role_provider.dart', 'settings_provider.dart', 'api_service.dart',
    'biometric_service.dart', 'cache_service.dart', 'notification_service.dart',
    'supabase_service.dart', 'tts_service.dart', 'websocket_service.dart'
}

academic_lib = r'e:\EduSHAMIIT\edu_shamiit_academic\lib'

for root, dirs, files in os.walk(academic_lib):
    for f in files:
        if f.endswith('.dart'):
            filepath = os.path.join(root, f)
            with open(filepath, 'r', encoding='utf-8') as file:
                lines = file.readlines()
            
            new_lines = []
            modified = False
            has_core_import = False
            
            for line in lines:
                if 'package:edu_shamiit_core/edu_shamiit_core.dart' in line:
                    has_core_import = True
            
            for line in lines:
                is_target = False
                if line.strip().startswith('import '):
                    for cf in core_files:
                        if cf in line and 'package:edu_shamiit_core' not in line:
                            is_target = True
                            break
                
                if is_target:
                    modified = True
                    if not has_core_import:
                        new_lines.append("import 'package:edu_shamiit_core/edu_shamiit_core.dart';\n")
                        has_core_import = True
                else:
                    new_lines.append(line)
            
            if modified:
                with open(filepath, 'w', encoding='utf-8') as file:
                    file.writelines(new_lines)
                print(f"Fixed imports in {f}")

print("Done fixing academic imports.")
