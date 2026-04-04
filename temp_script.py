lines = [
"import 'package:flutter/material.dart';",
"import 'package:flutter_riverpod/flutter_riverpod.dart';",
"import 'package:go_router/go_router.dart';",
"",
"class StudentExamsScreen extends ConsumerStatefulWidget {",
"  const StudentExamsScreen({super.key});",
"  @override",
"  ConsumerState<StudentExamsScreen> createState() => _StudentExamsScreenState();",
"}"
]

import os
os.path.join('edushamiitai', 'lib', 'features', 'student', 'exams', 'screens', 'student_exams.dart')
os.makedirs(os.path.dirname(target), exist_ok=True)
with open(target, 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))