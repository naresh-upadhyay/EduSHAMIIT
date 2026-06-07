import os
import json
import boto3
from botocore.client import Config
import httpx

class MinioClient:
    def __init__(self):
        self.endpoint = os.environ.get("MINIO_ENDPOINT", "minio:9000")
        self.access_key = os.environ.get("MINIO_ROOT_USER", "minio_admin")
        self.secret_key = os.environ.get("MINIO_ROOT_PASSWORD", "minio_password_2026")
        
        # Configure client
        self.s3 = boto3.client(
            "s3",
            endpoint_url=f"http://{self.endpoint}",
            aws_access_key_id=self.access_key,
            aws_secret_access_key=self.secret_key,
            config=Config(signature_version="s3v4"),
            region_name="us-east-1"
        )
        self.bucket_name = "live-classes"

    def ensure_bucket_and_public_policy(self):
        try:
            # Check if bucket exists
            self.s3.head_bucket(Bucket=self.bucket_name)
        except Exception:
            try:
                # Create bucket
                self.s3.create_bucket(Bucket=self.bucket_name)
                
                # Set public read policy
                policy = {
                    "Version": "2012-10-17",
                    "Statement": [
                        {
                            "Sid": "PublicRead",
                            "Effect": "Allow",
                            "Principal": "*",
                            "Action": ["s3:GetObject"],
                            "Resource": [f"arn:aws:s3:::{self.bucket_name}/*"]
                        }
                    ]
                }
                self.s3.put_bucket_policy(Bucket=self.bucket_name, Policy=json.dumps(policy))
                print(f"[MinIO] Bucket '{self.bucket_name}' created with public read policy.")
            except Exception as e:
                print(f"[MinIO] Failed to create bucket/policy: {e}")

    def check_file_exists_and_get_size(self, class_id: str):
        try:
            res = self.s3.head_object(Bucket=self.bucket_name, Key=f"{class_id}.mp4")
            return True, res.get("ContentLength", 0)
        except Exception:
            return False, 0

    def delete_file(self, filename: str):
        try:
            self.s3.delete_object(Bucket=self.bucket_name, Key=filename)
            print(f"[MinIO] File '{filename}' deleted successfully.")
            return True
        except Exception as e:
            print(f"[MinIO] Failed to delete file '{filename}': {e}")
            return False

minio_client = MinioClient()

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
        print(f"[MinIO Cleanup] Failed to cleanup recordings for class {live_class_id}: {e}")

async def cleanup_orphaned_recordings_from_storage():
    try:
        from app.services.supabase_client import get_supabase
        from datetime import datetime, timezone, timedelta
        
        sb = get_supabase()
        
        # 1. List files in MinIO
        res = minio_client.s3.list_objects_v2(Bucket=minio_client.bucket_name)
        contents = res.get('Contents', [])
        if not contents:
            print("[MinIO Cleanup] No files found in bucket.")
            return
            
        print(f"[MinIO Cleanup] Found {len(contents)} files in bucket. Checking for orphans...")
        
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
                
                is_active = False
                for url in all_active_urls:
                    if key in url:
                        is_active = True
                        break
                
                if not is_active:
                    print(f"[MinIO Cleanup] Purging orphaned recording file: {key}")
                    minio_client.delete_file(key)
                    deleted_count += 1
                    
        print(f"[MinIO Cleanup] Completed. Purged {deleted_count} orphaned files.")
    except Exception as e:
        print(f"[MinIO Cleanup] Error while running orphaned recordings cleanup: {e}")


