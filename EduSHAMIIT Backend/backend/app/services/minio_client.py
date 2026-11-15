import os
import json
import boto3
from botocore.client import Config
import httpx

class StorageClient:
    """
    S3 & Supabase Storage Client for managing live class recordings and media assets.
    Provides backward compatibility with MinIO interfaces while natively targeting Supabase Storage.
    """
    def __init__(self):
        raw_endpoint = os.environ.get("STORAGE_S3_ENDPOINT", os.environ.get("MINIO_ENDPOINT", "storage:5000/s3"))
        if raw_endpoint.startswith("http://") or raw_endpoint.startswith("https://"):
            self.endpoint_url = raw_endpoint
        else:
            self.endpoint_url = f"http://{raw_endpoint}"

        self.access_key = os.environ.get("STORAGE_S3_ACCESS_KEY", os.environ.get("S3_PROTOCOL_ACCESS_KEY_ID", os.environ.get("MINIO_ROOT_USER", "625729a08b95bf1b7ff351a663f3a23c")))
        self.secret_key = os.environ.get("STORAGE_S3_SECRET_KEY", os.environ.get("S3_PROTOCOL_ACCESS_KEY_SECRET", os.environ.get("MINIO_ROOT_PASSWORD", "850181e4652dd023b7a98c58ae0d2d34bd487ee0cc3254aed6eda37307425907")))
        self.bucket_name = os.environ.get("STORAGE_BUCKET", os.environ.get("MINIO_BUCKET", "live-classes"))
        
        # Configure S3 client pointing to Supabase Storage S3 protocol gateway
        try:
            self.s3 = boto3.client(
                "s3",
                endpoint_url=self.endpoint_url,
                aws_access_key_id=self.access_key,
                aws_secret_access_key=self.secret_key,
                config=Config(signature_version="s3v4", s3={"addressing_style": "path"}),
                region_name="us-east-1"
            )
        except Exception as e:
            print(f"[Storage] Boto3 client initialization error: {e}")
            self.s3 = None

    def ensure_bucket_and_public_policy(self):
        """Ensure the target bucket exists and has public read access in Supabase Storage."""
        # 1. Try via Supabase Storage REST API
        try:
            supabase_url = os.environ.get("SUPABASE_URL", "http://kong:8000").rstrip("/")
            service_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", os.environ.get("SERVICE_ROLE_KEY", ""))
            headers = {"Authorization": f"Bearer {service_key}", "apikey": service_key}
            with httpx.Client(timeout=5.0) as client:
                res = client.post(
                    f"{supabase_url}/storage/v1/bucket",
                    headers=headers,
                    json={
                        "id": self.bucket_name,
                        "name": self.bucket_name,
                        "public": True,
                        "file_size_limit": 5368709120
                    }
                )
                if res.status_code in (200, 201):
                    print(f"[Storage] Bucket '{self.bucket_name}' created in Supabase Storage.")
                elif res.status_code == 400 or "already exists" in res.text.lower():
                    print(f"[Storage] Bucket '{self.bucket_name}' already exists in Supabase Storage.")
                else:
                    print(f"[Storage] Supabase Storage bucket create status: {res.status_code} - {res.text}")
        except Exception as e:
            print(f"[Storage] REST bucket creation attempt: {e}")

        # 2. Try via S3 Protocol Gateway
        if self.s3:
            try:
                self.s3.head_bucket(Bucket=self.bucket_name)
            except Exception:
                try:
                    self.s3.create_bucket(Bucket=self.bucket_name)
                    print(f"[Storage] S3 Gateway: Bucket '{self.bucket_name}' ensured.")
                except Exception as e:
                    print(f"[Storage] S3 Gateway head/create bucket check: {e}")

    def check_file_exists_and_get_size(self, class_id: str):
        """Check if recording MP4 exists in bucket and return (exists, size)."""
        filename = f"{class_id}.mp4"
        # 1. Try S3 head_object
        if self.s3:
            try:
                res = self.s3.head_object(Bucket=self.bucket_name, Key=filename)
                size = res.get("ContentLength", 0)
                return True, size
            except Exception:
                pass

        # 2. Try direct HTTP check on Supabase Storage
        for base_url in [
            os.environ.get("SUPABASE_PUBLIC_URL", "http://localhost:8000").rstrip("/"),
            os.environ.get("SUPABASE_URL", "http://kong:8000").rstrip("/"),
            "http://storage:5000"
        ]:
            try:
                path = f"{base_url}/storage/v1/object/public/{self.bucket_name}/{filename}" if "5000" not in base_url else f"{base_url}/object/public/{self.bucket_name}/{filename}"
                with httpx.Client(timeout=3.0) as client:
                    resp = client.head(path)
                    if resp.status_code == 200:
                        size = int(resp.headers.get("Content-Length", 0))
                        return True, size
            except Exception:
                continue

        return False, 0

    def delete_file(self, filename: str):
        """Delete a file from Supabase Storage."""
        success = False
        if self.s3:
            try:
                self.s3.delete_object(Bucket=self.bucket_name, Key=filename)
                print(f"[Storage] S3: File '{filename}' deleted.")
                success = True
            except Exception as e:
                print(f"[Storage] S3 delete failed for '{filename}': {e}")

        # Also try via Supabase Storage REST API
        try:
            supabase_url = os.environ.get("SUPABASE_URL", "http://kong:8000").rstrip("/")
            service_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", os.environ.get("SERVICE_ROLE_KEY", ""))
            headers = {"Authorization": f"Bearer {service_key}", "apikey": service_key}
            with httpx.Client(timeout=5.0) as client:
                res = client.delete(
                    f"{supabase_url}/storage/v1/object/{self.bucket_name}/{filename}",
                    headers=headers
                )
                if res.status_code in (200, 204):
                    success = True
        except Exception:
            pass

        return success

# Backward compatibility aliases
MinioClient = StorageClient
minio_client = StorageClient()

async def delete_live_class_recordings_from_storage(sb, live_class_id: str):
    try:
        recs_res = await sb.table("live_class_recordings").select("recording_url").eq("live_class_id", live_class_id).aexecute()
        if recs_res.data:
            for rec in recs_res.data:
                recording_url = rec.get("recording_url")
                if recording_url and "/live-classes/" in recording_url:
                    filename = recording_url.split("/live-classes/")[-1]
                    minio_client.delete_file(filename)
    except Exception as e:
        print(f"[Storage Cleanup] Failed to cleanup recordings for class {live_class_id}: {e}")

async def cleanup_orphaned_recordings_from_storage():
    try:
        from app.services.supabase_client import get_supabase
        from datetime import datetime, timezone, timedelta
        
        sb = get_supabase()
        contents = []

        # 1. List files
        if minio_client.s3:
            try:
                res = minio_client.s3.list_objects_v2(Bucket=minio_client.bucket_name)
                contents = res.get('Contents', [])
            except Exception as e:
                print(f"[Storage Cleanup] S3 list_objects error: {e}")

        if not contents:
            print("[Storage Cleanup] No files found in bucket or S3 listing skipped.")
            return
            
        print(f"[Storage Cleanup] Found {len(contents)} files in bucket. Checking for orphans...")
        
        # 2. Get all recording URLs from database
        rec_res = await sb.table("live_class_recordings").select("recording_url").aexecute()
        db_urls = {r.get("recording_url") for r in (rec_res.data or []) if r.get("recording_url")}
        
        lc_res = await sb.table("live_classes").select("recording_url").aexecute()
        lc_urls = {r.get("recording_url") for r in (lc_res.data or []) if r.get("recording_url")}
        
        all_active_urls = db_urls.union(lc_urls)
        
        # 3. Filter and delete orphans (older than 1 hour)
        deleted_count = 0
        now = datetime.now(timezone.utc)
        for obj in contents:
            key = obj['Key']
            if key.endswith(".mp4"):
                last_modified = obj.get("LastModified")
                if last_modified:
                    if now - last_modified < timedelta(hours=1):
                        continue
                
                is_active = any(key in url for url in all_active_urls)
                if not is_active:
                    print(f"[Storage Cleanup] Purging orphaned recording file: {key}")
                    minio_client.delete_file(key)
                    deleted_count += 1
                    
        print(f"[Storage Cleanup] Completed. Purged {deleted_count} orphaned files.")
    except Exception as e:
        print(f"[Storage Cleanup] Error while running orphaned recordings cleanup: {e}")
