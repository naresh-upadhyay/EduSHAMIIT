import urllib.request
import json
import pytest

BASE_URL = "http://localhost:8082/api/v1/devices"

def test_types_and_profiles_kpis():
    req = urllib.request.Request(f"{BASE_URL}/types-and-profiles/kpis")
    with urllib.request.urlopen(req) as resp:
        kpis = json.loads(resp.read().decode())
        assert kpis["total_device_types"] == 24
        assert kpis["active_profiles"] == 76
        assert kpis["default_profiles"] == 24
        assert kpis["custom_profiles"] == 52
        assert kpis["mapped_devices"] == 8742
        assert kpis["compliance_rate"] == 95.4

def test_list_device_types_pagination():
    req = urllib.request.Request(f"{BASE_URL}/types?page=1&page_size=10")
    with urllib.request.urlopen(req) as resp:
        tdata = json.loads(resp.read().decode())
        assert tdata['total'] == 24
        assert len(tdata['types']) == 10
        assert tdata['types'][0]['name'] == "CCTV"
        assert tdata['types'][0]['mapped_devices_count'] == 1284
        assert tdata['types'][0]['profiles_count'] == 6

def test_get_device_type_detail():
    req = urllib.request.Request(f"{BASE_URL}/types?page=1&page_size=10")
    with urllib.request.urlopen(req) as resp:
        cctv_id = json.loads(resp.read().decode())['types'][0]['id']
    
    req2 = urllib.request.Request(f"{BASE_URL}/types/{cctv_id}")
    with urllib.request.urlopen(req2) as resp2:
        cctv_detail = json.loads(resp2.read().decode())['type']
        assert cctv_detail['name'] == "CCTV"
        assert len(cctv_detail['profiles']) == 6

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
