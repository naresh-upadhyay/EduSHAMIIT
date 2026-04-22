import psycopg2
from dotenv import load_dotenv
load_dotenv('.env')
DB = {'host':'127.0.0.1','port':54322,'dbname':'postgres','user':'postgres','password':'postgres'}
conn = psycopg2.connect(**DB)
cur = conn.cursor()
tables = [
    'schools', 'courses', 'documents', 'event_registrations', 'exam_questions',
    'exam_sessions', 'exam_submissions', 'grading_policies', 'group_members',
    'iot_devices', 'iot_device_states', 'iot_control_log', 'iot_scheduled_actions',
    'knowledge_base', 'live_class_comments', 'password_resets', 'payments',
    'salary', 'study_materials', 'user_settings', 'bus_locations'
]
print(f"{'TABLE':<30} {'ROWS':>6}")
print("-" * 38)
for t in tables:
    cur.execute(f"SELECT COUNT(*) FROM {t}")
    n = cur.fetchone()[0]
    print(f"  {t:<28} {n:>6}")
conn.close()
