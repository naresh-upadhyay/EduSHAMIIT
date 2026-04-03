"""
Face Enrollment Script for EduSHAMIIT Camera Attendance System
Enrolls student face photos into the local face database for DeepFace recognition.

Usage:
    python enroll_faces.py --student-id <uuid> --class-id <class> --school-id <uuid> --photo <path>

All face processing runs on-premise. No student face images are sent to any cloud API.
"""
import os
import shutil
import argparse


def enroll_student(student_id: str, class_id: str, school_id: str, photo_path: str):
    """Save student face photo to local face database (one-time setup)."""
    face_dir = f"/faces/{school_id}/{class_id}/{student_id}"
    os.makedirs(face_dir, exist_ok=True)

    # Copy photo to face database
    dest_path = os.path.join(face_dir, "face_01.jpg")
    shutil.copy(photo_path, dest_path)

    print(f"Enrolled: {student_id} -> {face_dir}")
    print(f"Photo saved to: {dest_path}")
    print(f"Total photos for this student: {len(os.listdir(face_dir))}")


def bulk_enroll(class_id: str, school_id: str, photos_dir: str):
    """Bulk enroll all students from a directory of photos.
    
    Expected directory structure:
        photos_dir/
            student_name_1.jpg
            student_name_2.jpg
            ...
    
    Each filename should match the student_id in the database.
    """
    enrolled = 0
    failed = 0

    for filename in os.listdir(photos_dir):
        if filename.lower().endswith(('.jpg', '.jpeg', '.png')):
            student_id = os.path.splitext(filename)[0]
            photo_path = os.path.join(photos_dir, filename)

            try:
                enroll_student(student_id, class_id, school_id, photo_path)
                enrolled += 1
            except Exception as e:
                print(f"Failed to enroll {student_id}: {e}")
                failed += 1

    print(f"\nBulk enrollment complete: {enrolled} enrolled, {failed} failed")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Enroll student faces for camera attendance")
    parser.add_argument("--student-id", help="Student UUID")
    parser.add_argument("--class-id", required=True, help="Class ID (e.g., '10-A')")
    parser.add_argument("--school-id", required=True, help="School UUID")
    parser.add_argument("--photo", help="Path to student photo")
    parser.add_argument("--bulk-dir", help="Directory of photos for bulk enrollment")

    args = parser.parse_args()

    if args.bulk_dir:
        bulk_enroll(args.class_id, args.school_id, args.bulk_dir)
    elif args.student_id and args.photo:
        enroll_student(args.student_id, args.class_id, args.school_id, args.photo)
    else:
        print("Error: Provide either --student-id + --photo, or --bulk-dir")
        parser.print_help()