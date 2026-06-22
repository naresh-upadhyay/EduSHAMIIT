from enum import Enum
from pydantic import BaseModel, EmailStr, Field
from typing import Optional, List, Any, Dict
from datetime import datetime


# Auth Models
class LoginRequest(BaseModel):
    """Request model for user login"""
    email: str
    password: str
    role: Optional[str] = None

    class Config:
        json_schema_extra = {
            "example": {
                "email": "student@example.com",
                "password": "SecurePassword123",
                "role": "student"
            }
        }


class RegisterRequest(BaseModel):
    """Request model for user registration"""
    email: str
    password: str
    full_name: str
    role: str
    school_id: str
    class_name: Optional[str] = None

    class Config:
        json_schema_extra = {
            "example": {
                "email": "newstudent@example.com",
                "password": "NewPassword123",
                "full_name": "John Doe",
                "role": "student",
                "school_id": "11111111-1111-1111-1111-111111111111",
                "class_name": "10A"
            }
        }


class RefreshRequest(BaseModel):
    """Request model for token refresh"""
    refresh_token: str

    class Config:
        json_schema_extra = {
            "example": {
                "refresh_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9..."
            }
        }


class SendOtpRequest(BaseModel):
    """Request model for sending OTP"""
    identifier: str  # email or user_id
    user_name: Optional[str] = None

    class Config:
        json_schema_extra = {
            "example": {
                "identifier": "student@example.com",
                "user_name": "John Doe"
            },
            "description": "Send OTP to user. Identifier can be email or user_id (UUID)"
        }


class VerifyOtpRequest(BaseModel):
    """Request model for OTP verification"""
    identifier: str  # email or user_id
    otp: str

    class Config:
        json_schema_extra = {
            "example": {
                "identifier": "student@example.com",
                "otp": "123456"
            }
        }


class ResetPasswordRequest(BaseModel):
    """Request model for password reset"""
    identifier: str  # email or user_id
    otp: str
    new_password: str

    class Config:
        json_schema_extra = {
            "example": {
                "identifier": "student@example.com",
                "otp": "123456",
                "new_password": "NewSecurePassword123"
            }
        }


class LoginResponse(BaseModel):
    """Response model for login"""
    success: bool
    school_id: Optional[str]
    data: Optional[Dict[str, Any]]
    message: Optional[str] = None


class RegisterResponse(BaseModel):
    """Response model for registration"""
    success: bool
    message: str


class RefreshResponse(BaseModel):
    """Response model for token refresh"""
    success: bool
    data: Optional[Dict[str, Any]]
    message: Optional[str] = None


class OtpResponse(BaseModel):
    """Response model for OTP operations"""
    success: bool
    message: str
    expires_in: Optional[int] = None  # seconds


class VerifyOtpResponse(BaseModel):
    """Response model for OTP verification"""
    success: bool
    message: str


class ResetPasswordResponse(BaseModel):
    """Response model for password reset"""
    success: bool
    message: str


class ErrorResponse(BaseModel):
    """Standard error response model"""
    success: bool = False
    detail: str


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
    exam_date: Optional[str] = None
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
    num_single_select: Optional[int] = 10
    num_multi_select: Optional[int] = 5
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


class QuestionType(str, Enum):
    single_select = "single_select"
    multi_select = "multi_select"
    subjective = "subjective"


class QuestionBase(BaseModel):
    question_text: str = Field(..., description="The text of the question")
    question_type: QuestionType = Field(QuestionType.single_select, description="Type of the question")
    options: Optional[List[str]] = Field(None, description="List of options (only for select types)")
    correct_answer: Optional[str] = Field(None, description="Correct option index (A, B...) or comma-separated indices (A,C), or model answer text")
    marks: Optional[int] = Field(1, description="Marks assigned to the question")
    difficulty: Optional[str] = Field("Medium", description="Easy, Medium, or Hard")
    chapter: Optional[str] = Field(None, description="Optional chapter/topic grouping")


class CreateQuestionRequest(QuestionBase):
    pass


class UpdateQuestionRequest(BaseModel):
    question_text: Optional[str] = None
    question_type: Optional[QuestionType] = None
    options: Optional[List[str]] = None
    correct_answer: Optional[str] = None
    marks: Optional[int] = None
    difficulty: Optional[str] = None
    chapter: Optional[str] = None


class QuestionResponse(QuestionBase):
    id: str
    school_id: Optional[str] = None
    teacher_id: Optional[str] = None
    subject_id: Optional[str] = None
    created_at: datetime
    updated_at: Optional[datetime] = None


class ExamSubmitRequest(BaseModel):
    answers: Dict[str, str] = Field(..., description="Dictionary mapping question UUID to student answer text/letter")
    is_auto_save: Optional[bool] = False


# OTP Login Models
class SendLoginOtpRequest(BaseModel):
    identifier: str  # email or user_id


class VerifyLoginOtpRequest(BaseModel):
    identifier: str
    otp: str
    role: Optional[str] = None