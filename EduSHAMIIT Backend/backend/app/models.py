from pydantic import BaseModel, EmailStr
from typing import Optional, List, Any, Dict
from datetime import datetime


# Auth Models
class UserLogin(BaseModel):
    email: str
    password: str
    role: Optional[str] = None


class UserRegister(BaseModel):
    email: str
    password: str
    full_name: str
    role: str
    school_id: str
    class_name: Optional[str] = None


class SendOTPRequest(BaseModel):
    identifier: str  # email or user_id
    user_name: Optional[str] = None


class VerifyOTPRequest(BaseModel):
    identifier: str  # email or user_id
    otp: str


class ResetPasswordRequest(BaseModel):
    identifier: str  # email or user_id
    otp: str
    new_password: str


class OTPResponse(BaseModel):
    success: bool
    message: str
    expires_in: Optional[int] = None  # seconds


class ResetPasswordResponse(BaseModel):
    success: bool
    message: str


class TokenResponse(BaseModel):
    token: str
    refresh_token: str
    user: Dict[str, Any]


class AuthResponse(BaseModel):
    success: bool
    school_id: Optional[str] = None
    data: Optional[Dict[str, Any]] = None
    message: Optional[str] = None


# Student Dashboard Models
class DashboardResponse(BaseModel):
    success: bool
    school_id: Optional[str] = None
    data: Optional[Dict[str, Any]] = None


class TimetableResponse(BaseModel):
    success: bool
    school_id: Optional[str] = None
    data: Optional[Dict[str, Any]] = None


class HomeworkResponse(BaseModel):
    success: bool
    school_id: Optional[str] = None
    data: Optional[Dict[str, Any]] = None


class ResultsResponse(BaseModel):
    success: bool
    school_id: Optional[str] = None
    data: Optional[Dict[str, Any]] = None


class ExamResponse(BaseModel):
    success: bool
    school_id: Optional[str] = None
    data: Optional[Dict[str, Any]] = None


class AttendanceResponse(BaseModel):
    success: bool
    school_id: Optional[str] = None
    data: Optional[Dict[str, Any]] = None


class FeeResponse(BaseModel):
    success: bool
    school_id: Optional[str] = None
    data: Optional[Dict[str, Any]] = None


class TransportResponse(BaseModel):
    success: bool
    school_id: Optional[str] = None
    data: Optional[Dict[str, Any]] = None


class NoticeResponse(BaseModel):
    success: bool
    school_id: Optional[str] = None
    data: Optional[Dict[str, Any]] = None


class EventResponse(BaseModel):
    success: bool
    school_id: Optional[str] = None
    data: Optional[Dict[str, Any]] = None


class AchievementResponse(BaseModel):
    success: bool
    school_id: Optional[str] = None
    data: Optional[Dict[str, Any]] = None


# Chat Models
class ChatMessage(BaseModel):
    message: str
    session_id: Optional[str] = None


class ChatResponse(BaseModel):
    success: bool
    school_id: Optional[str] = None
    data: Optional[Dict[str, Any]] = None


class VoiceRequest(BaseModel):
    session_id: str


class ImageRequest(BaseModel):
    question: Optional[str] = "Describe this image"


# IoT Models
class IoTControlRequest(BaseModel):
    room: str
    device: str
    action: str


class IoTStatusResponse(BaseModel):
    success: bool
    school_id: Optional[str] = None
    data: Optional[Dict[str, Any]] = None


class IoTScheduleRequest(BaseModel):
    room: str
    device: str
    action: str
    time: str


# Payment Models
class PaymentRequest(BaseModel):
    fee_id: str
    amount: float
    description: Optional[str] = "EduSHAMIIT Fee Payment"


class PaymentResponse(BaseModel):
    success: bool
    school_id: Optional[str] = None
    data: Optional[Dict[str, Any]] = None


class PaymentVerifyRequest(BaseModel):
    payment_id: str
    upi_transaction_id: Optional[str] = None
    status: str = "success"


# RAG Models
class RAGIngestRequest(BaseModel):
    subject: str
    grade: str
    source: str


# Generic Models
class GenericResponse(BaseModel):
    success: bool
    school_id: Optional[str] = None
    data: Optional[Dict[str, Any]] = None
    message: Optional[str] = None


class ErrorResponse(BaseModel):
    success: bool = False
    detail: str
    school_id: Optional[str] = None


# Homework Submission
class HomeworkSubmitRequest(BaseModel):
    homework_id: str
    submission_text: Optional[str] = ""
    attachment_url: Optional[str] = None


# Leave Application
class LeaveApplyRequest(BaseModel):
    leave_type: str
    start_date: str
    end_date: str
    reason: str


# Attendance Mark
class AttendanceRecord(BaseModel):
    student_id: str
    status: str


class MarkAttendanceRequest(BaseModel):
    date: Optional[str] = None
    subject_id: Optional[str] = None
    attendance_records: List[AttendanceRecord]


# Homework Create
class CreateHomeworkRequest(BaseModel):
    subject_id: str
    title: str
    description: Optional[str] = ""
    due_date: str
    max_marks: Optional[int] = 25
    target_class: str


# Grade Submission
class GradeSubmissionRequest(BaseModel):
    submission_id: str
    marks: float
    grade: str
    remarks: Optional[str] = ""


# Create Exam
class CreateExamRequest(BaseModel):
    subject_id: str
    title: str
    exam_type: Optional[str] = "offline"
    exam_category: Optional[str] = None
    exam_date: str
    start_time: Optional[str] = None
    duration_minutes: Optional[int] = 90
    total_marks: Optional[int] = 100
    venue: Optional[str] = None
    target_classes: Optional[List[str]] = None


# Generate Questions
class GenerateQuestionsRequest(BaseModel):
    subject: str
    topic: str
    grade: str
    question_type: Optional[str] = "mixed"
    count: Optional[int] = 10
    difficulty: Optional[str] = "medium"
    total_marks: Optional[int] = 100
    num_mcq: Optional[int] = 10
    num_subjective: Optional[int] = 5


# Grading Config
class GradingConfigRequest(BaseModel):
    class_name: Optional[str] = None
    subject_id: Optional[str] = None
    mid_term_weight: Optional[float] = 30
    final_term_weight: Optional[float] = 40
    attendance_weight: Optional[float] = 5
    assignment_weight: Optional[float] = 10
    class_test_weight: Optional[float] = 10
    lab_weight: Optional[float] = 5


# Create Notice
class CreateNoticeRequest(BaseModel):
    title: str
    content: str
    category: Optional[str] = "General"
    is_urgent: Optional[bool] = False


# Upload Material
class UploadMaterialRequest(BaseModel):
    title: str
    description: Optional[str] = ""
    material_type: str
    target_class: str
    attachment_urls: Optional[List[str]] = None


# Messages
class SendMessageRequest(BaseModel):
    receiver_id: str
    content: str


# Groups
class CreateGroupRequest(BaseModel):
    name: str
    description: Optional[str] = ""


# Settings
class UpdateSettingsRequest(BaseModel):
    notifications_enabled: Optional[bool] = None
    dark_mode: Optional[bool] = None
    language: Optional[str] = None