from app.services.supabase_client import get_supabase
from datetime import datetime


class ClassroomCamera:
    def __init__(self, rtsp_url: str, class_id: str, school_id: str):
        self.rtsp_url = rtsp_url
        self.class_id = class_id
        self.school_id = school_id
        self.face_db = f"/faces/{school_id}/{class_id}"

    async def take_attendance(self) -> dict:
        """Capture frame, detect faces, identify students, write attendance."""
        try:
            import cv2
            from deepface import DeepFace
            from ultralytics import YOLO

            yolo = YOLO("yolov8n.pt")

            cap = cv2.VideoCapture(self.rtsp_url)
            ret, frame = cap.read()
            cap.release()

            if not ret:
                return {"error": "camera feed unavailable"}

            # Step 1: Count people with YOLO (fast)
            results = yolo.predict(frame, classes=[0], verbose=False)
            headcount = len(results[0].boxes)

            # Step 2: Identify faces with DeepFace
            present_ids = []
            for box in results[0].boxes:
                x1, y1, x2, y2 = map(int, box.xyxy[0])
                face_crop = frame[y1:y2, x1:x2]
                try:
                    matches = DeepFace.find(
                        img_path=face_crop,
                        db_path=self.face_db,
                        model_name="ArcFace",
                        enforce_detection=False,
                        silent=True,
                    )
                    if matches and not matches[0].empty:
                        student_id = matches[0].iloc[0]["identity"].split("/")[-2]
                        present_ids.append(student_id)
                except Exception:
                    pass

            # Step 3: Write to Supabase
            today = datetime.now().strftime("%Y-%m-%d")
            sb = get_supabase()
            all_students = sb.table("profiles") \
                .select("id").eq("class", self.class_id).eq("role", "student").execute()
            all_ids = [s["id"] for s in all_students.data]

            records = []
            for sid in all_ids:
                records.append({
                    "student_id": sid,
                    "school_id": self.school_id,
                    "date": today,
                    "status": "present" if sid in present_ids else "absent",
                    "method": "camera_ai",
                })

            if records:
                sb.table("attendance").upsert(records).execute()

            return {
                "headcount": headcount,
                "identified": len(present_ids),
                "present_ids": present_ids,
                "date": today,
            }
        except Exception as e:
            return {"error": str(e)}