with open('edu_shamiit_core/lib/screens/work_management/widgets/board/work_board_tab_view.dart', 'r', encoding='utf-8') as f:
    text = f.read()

import re
matches = [m.start() for m in re.finditer(r'kpi|count|total|boardProvider|boardState', text, re.IGNORECASE)]
print(f'Total matches in board view: {len(matches)}')
m = re.search(r'class WorkBoardTabView', text)
if m:
    print(text[m.start():m.start()+2500])
