import asyncio
import asyncpg

async def check():
    conn = await asyncpg.connect('postgresql://postgres:eduSHAMIIT2026_pg@localhost:54322/postgres')
    row = await conn.fetchrow('SELECT COUNT(*) FROM device_types;')
    print('device_types count:', row[0])
    row2 = await conn.fetchrow('SELECT COUNT(*) FROM device_profiles;')
    print('device_profiles count:', row2[0])
    cols = await conn.fetch("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'device_types';")
    print('device_types cols:', [c['column_name'] for c in cols])
    pcols = await conn.fetch("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'device_profiles';")
    print('device_profiles cols:', [c['column_name'] for c in pcols])
    cats = await conn.fetch("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'device_categories';")
    print('device_categories cols:', [c['column_name'] for c in cats])
    await conn.close()

asyncio.run(check())
