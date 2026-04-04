from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    # App
    ENVIRONMENT: str = "development"
    DEBUG: bool = True
    APP_ENV: str = "development"
    APP_SECRET_KEY: str = "eduSHAMIIT-secret-key-2026"

    # Database
    DATABASE_URL: str = "postgresql://postgres:postgres_password_2026@localhost:5432/edushamiit"
    POSTGRES_HOST: str = "localhost"
    POSTGRES_PORT: int = 5432
    POSTGRES_DB: str = "edushamiit"
    POSTGRES_USER: str = "postgres"
    POSTGRES_PASSWORD: str = "postgres_password_2026"

    # Supabase
    SUPABASE_URL: str = "http://localhost:54321"
    SUPABASE_ANON_KEY: str = "your-supabase-anon-key"
    SUPABASE_SERVICE_ROLE_KEY: str = "your-supabase-service-role-key"
    SUPABASE_JWT_SECRET: str = "eduSHAMIIT-jwt-secret-2026"

    # Redis
    REDIS_URL: str = "redis://localhost:6379"
    REDIS_HOST: str = "localhost"
    REDIS_PORT: int = 6379
    REDIS_PASSWORD: str = "redis_password_2026"

    # RabbitMQ
    RABBITMQ_URL: str = "amqp://guest:guest@localhost:5672"
    RABBITMQ_HOST: str = "localhost"
    RABBITMQ_PORT: int = 5672
    RABBITMQ_USER: str = "guest"
    RABBITMQ_PASSWORD: str = "guest"

    # JWT
    JWT_SECRET: str = "eduSHAMIIT-jwt-secret-2026"
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRATION_MINUTES: int = 10080

    # AI Models
    OPENAI_API_KEY: str = "sk-placeholder-openai-key"
    ANTHROPIC_API_KEY: str = "sk-ant-placeholder-anthropic-key"
    GOOGLE_API_KEY: str = "AIza-placeholder-google-key"

    # Payments
    UPI_MERCHANT_ID: str = "eduSHAMIIT-school@upi"
    UPI_MERCHANT_NAME: str = "EduSHAMIIT Academy"
    RAZORPAY_KEY_ID: str = "rzp_test_placeholder"
    RAZORPAY_SECRET: str = "razorpay_placeholder_secret"

    # WhatsApp
    WHATSAPP_API_KEY: str = "placeholder_whatsapp_key"
    WHATSAPP_NUMBER: str = "917000000000"

    # MQTT / IoT
    MQTT_BROKER_HOST: str = "localhost"
    MQTT_BROKER_PORT: int = 1883

    # TTS
    GOOGLE_TTS_API_KEY: str = "placeholder_tts_key"
    ELEVENLABS_API_KEY: str = "placeholder_elevenlabs_key"

    # Email Configuration
    SMTP_HOST: str = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USER: str = "binaftab936@gmail.com"
    SMTP_PASSWORD: str = ""
    EMAIL_FROM: str = "binaftab936@gmail.com"
    EMAIL_RETRY_ATTEMPTS: int = 3
    EMAIL_RETRY_DELAY: int = 1  # seconds (will be multiplied exponentially)

    # OTP Configuration
    OTP_LENGTH: int = 6
    OTP_EXPIRATION_MINUTES: int = 15
    OTP_RATE_LIMIT_PER_HOUR: int = 3

    class Config:
        env_file = "../../.env"
        case_sensitive = True
        extra = "ignore"


settings = Settings()