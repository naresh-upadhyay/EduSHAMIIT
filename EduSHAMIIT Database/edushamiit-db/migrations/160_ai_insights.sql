-- Database migration: 160_ai_insights.sql
-- Define schema for AI insights, recommendations, predictions, and chat history.

CREATE TABLE IF NOT EXISTS public.ai_insights (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES schools(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('positive', 'critical', 'warning', 'info')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.ai_recommendations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES schools(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('Server', 'Fee', 'Attendance', 'Content')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.ai_predictions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES schools(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    probability INT NOT NULL CHECK (probability BETWEEN 0 AND 100),
    expected_date DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.ai_chat_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    response TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_ai_insights_school ON public.ai_insights(school_id);
CREATE INDEX IF NOT EXISTS idx_ai_recommendations_school ON public.ai_recommendations(school_id);
CREATE INDEX IF NOT EXISTS idx_ai_predictions_school ON public.ai_predictions(school_id);
CREATE INDEX IF NOT EXISTS idx_ai_chat_history_user ON public.ai_chat_history(user_id);

-- Seed dynamic mock data
INSERT INTO public.ai_insights (title, description, type, created_at) VALUES
('Increase in Student Admissions', 'Admissions are up by 18.6% compared to last month across all institutions.', 'positive', NOW() - INTERVAL '2 hours'),
('High Server Load Detected', 'Server load is reaching 85% during peak hours (10 AM - 12 PM).', 'critical', NOW() - INTERVAL '1 hour'),
('Fee Collection Below Target', 'Fee collection is 12% below the expected target for this month.', 'warning', NOW() - INTERVAL '4 hours'),
('Low Attendance Alert', 'Average student attendance is 78%, which is below the ideal threshold.', 'info', NOW() - INTERVAL '5 hours')
ON CONFLICT DO NOTHING;

INSERT INTO public.ai_recommendations (title, description, category, created_at) VALUES
('Optimize Server Performance', 'Consider scaling resources between 10 AM - 12 PM to handle high load.', 'Server', NOW()),
('Improve Fee Collection', 'Send automated reminders to pending fee payers.', 'Fee', NOW()),
('Boost Attendance', 'Engage with absent students and notify parents automatically.', 'Attendance', NOW()),
('Content Engagement', 'More students are using digital resources. Consider adding more.', 'Content', NOW())
ON CONFLICT DO NOTHING;

INSERT INTO public.ai_predictions (title, description, probability, expected_date, created_at) VALUES
('High Server Load', 'Expected on May 27, 2025 between 10:00 AM - 12:00 PM', 85, '2025-05-27', NOW()),
('Fee Collection Drop', 'If current trend continues, collection may drop by 15% next month.', 60, '2025-06-15', NOW()),
('Storage Almost Full', 'Database storage will reach 90% by June 5, 2025.', 75, '2025-06-05', NOW())
ON CONFLICT DO NOTHING;
