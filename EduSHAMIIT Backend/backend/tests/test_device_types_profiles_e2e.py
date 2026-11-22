import urllib.request
import json
import pytest

BASE_URL = "http://localhost:8082/api/v1/devices"

def test_types_and_profiles_kpis():
    req = urllib.request.Request(f"{BASE_URL}/types-and-profiles/kpis")
    with urllib.request.urlopen(req) as resp:
        kpis = json.loads(resp.read().decode())
        assert kpis["total_device_types"] >= 24
        assert kpis["active_profiles"] >= 76
        assert kpis["default_profiles"] >= 24
        assert kpis["custom_profiles"] >= 52
        assert kpis["mapped_devices"] >= 200
        assert kpis["compliance_rate"] > 0

def test_list_device_types_pagination():
    req = urllib.request.Request(f"{BASE_URL}/types?page=1&page_size=10")
    with urllib.request.urlopen(req) as resp:
        tdata = json.loads(resp.read().decode())
        assert tdata['total'] >= 24
        assert len(tdata['types']) == 10
        first = tdata['types'][0]
        assert first['name']
        assert first['mapped_devices_count'] >= 0
        assert first['profiles_count'] >= 0

def test_get_device_type_detail():
    req = urllib.request.Request(f"{BASE_URL}/types?page=1&page_size=10")
    with urllib.request.urlopen(req) as resp:
        first_type = json.loads(resp.read().decode())['types'][0]
        dev_id = first_type['id']
        dev_name = first_type['name']
    
    req2 = urllib.request.Request(f"{BASE_URL}/types/{dev_id}")
    with urllib.request.urlopen(req2) as resp2:
        dev_detail = json.loads(resp2.read().decode())['type']
        assert dev_detail['name'] == dev_name
        assert 'profiles' in dev_detail

def test_capabilities_library():
    req = urllib.request.Request(f"{BASE_URL}/capabilities/library")
    with urllib.request.urlopen(req) as resp:
        cdata = json.loads(resp.read().decode())
        assert len(cdata['capabilities']) >= 10

def test_protocols_mappings():
    req = urllib.request.Request(f"{BASE_URL}/protocols/mappings")
    with urllib.request.urlopen(req) as resp:
        mdata = json.loads(resp.read().decode())
        assert len(mdata['protocols']) >= 5

if __name__ == "__main__":
    test_types_and_profiles_kpis()
    test_list_device_types_pagination()
    test_get_device_type_detail()
    test_capabilities_library()
    test_protocols_mappings()
    print("All pytest tests passed!")
