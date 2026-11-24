with open('edu_shamiit_core/lib/screens/work_management/widgets/list/work_list_tab_view.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

for i in range(360, 440):
    print(f'{i+1}: {lines[i]}', end='')
