with open('edu_shamiit_core/lib/screens/work_management/widgets/board/work_board_tab_view.dart', 'r', encoding='utf-8') as f:
    text = f.read()

import re
m = re.search(r'void _reloadBoard', text)
if m:
    print(text[m.start():m.start()+1500])
