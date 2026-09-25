-- ============================================================================
-- Migration: 356_seed_hr_management_lookups.sql
-- Description:
--   Seeds universal HR Management lookup keys and standard enterprise lookup values
--   across all schools:
--     1. DEPARTMENT (Verification & Enhancement)
--     2. DESIGNATION
--     3. EMPLOYMENT_TYPE
--     4. WORK_MODE
--     5. RECRUITMENT_SOURCE
--     6. INTERVIEW_ROUND
--     7. INTERVIEW_MODE
--     8. ASSESSMENT_TYPE
--     9. RECRUITMENT_STAGE
--    10. TRAINING_CATEGORY
--    11. TRAINING_TYPE
--    12. TRAINING_MODE
--    13. TRAINING_ASSESSMENT_TYPE
--    14. POLICY_APPLICABILITY
--    15. POLICY_REVIEW_FREQUENCY
--    16. HR_DOCUMENT_TYPE
--    17. DOCUMENT_ACCESS_LEVEL
--    18. HR_TEMPLATE_TYPE
--    19. ONBOARDING_TASK_CATEGORY
-- ============================================================================

DO $$
DECLARE
    s RECORD;
    admin_id UUID;
    v_key_id UUID;
BEGIN
    FOR s IN SELECT id FROM public.schools LOOP
        SELECT id INTO admin_id FROM public.profiles WHERE school_id = s.id LIMIT 1;
        IF admin_id IS NULL THEN
            SELECT id INTO admin_id FROM public.profiles LIMIT 1;
        END IF;

        IF admin_id IS NOT NULL THEN
            -- ================================================================
            -- 1. DEPARTMENT (Ensure present and active)
            -- ================================================================
            INSERT INTO public.lookup_keys (
                school_id, key_name, key_code, description, key_type, icon, status, created_by
            ) VALUES (
                s.id, 'Department', 'DEPARTMENT', 'Institutional and academic departments across campus.',
                'SYSTEM', 'corporate_fare_rounded', 'ACTIVE', admin_id
            )
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL 
            DO UPDATE SET key_name = EXCLUDED.key_name, description = EXCLUDED.description
            RETURNING id INTO v_key_id;

            IF v_key_id IS NULL THEN
                SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s.id AND key_code = 'DEPARTMENT' AND deleted_at IS NULL LIMIT 1;
            END IF;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'Academic / Teaching', 'ACADEMIC', 'Instructional faculty and academic curriculum staff.', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Administration', 'ADMINISTRATION', 'Executive leadership and general school administration.', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Mathematics', 'MATHEMATICS', 'Mathematics faculty and numeric sciences.', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Science', 'SCIENCE', 'Physics, Chemistry, Biology and scientific laboratories.', 'ACTIVE', 4, admin_id),
                    (v_key_id, s.id, 'English / Languages', 'LANGUAGES', 'Language arts, literature and linguistic studies.', 'ACTIVE', 5, admin_id),
                    (v_key_id, s.id, 'Social Studies & Humanities', 'SOCIAL_STUDIES', 'History, Geography, Civics, and Social Sciences.', 'ACTIVE', 6, admin_id),
                    (v_key_id, s.id, 'Computer Science & IT', 'COMPUTER_SCIENCE', 'Information technology, programming, and computer labs.', 'ACTIVE', 7, admin_id),
                    (v_key_id, s.id, 'Finance & Accounts', 'FINANCE', 'Institutional accounting, tuition billing, and payroll.', 'ACTIVE', 8, admin_id),
                    (v_key_id, s.id, 'Human Resources', 'HR', 'Staff recruitment, employee welfare, and personnel records.', 'ACTIVE', 9, admin_id),
                    (v_key_id, s.id, 'Library & Information', 'LIBRARY', 'Learning resources center, book circulation, and digital media.', 'ACTIVE', 10, admin_id),
                    (v_key_id, s.id, 'Physical Education & Sports', 'SPORTS', 'Athletics, physical education, gymnasiums, and teams.', 'ACTIVE', 11, admin_id),
                    (v_key_id, s.id, 'Arts & Performing Arts', 'ARTS', 'Fine arts, music, dance, and creative drama studios.', 'ACTIVE', 12, admin_id),
                    (v_key_id, s.id, 'Transport & Fleet', 'TRANSPORT', 'Buses, vans, fleet routing, and driver coordination.', 'ACTIVE', 13, admin_id),
                    (v_key_id, s.id, 'Hostel & Residential', 'HOSTEL', 'Boarding facilities, wardens, and student residential care.', 'ACTIVE', 14, admin_id),
                    (v_key_id, s.id, 'Security & Safety', 'SECURITY', 'Campus surveillance, security guards, and emergency protocols.', 'ACTIVE', 15, admin_id),
                    (v_key_id, s.id, 'Medical & Health Clinic', 'HEALTH_CLINIC', 'Infirmary, campus medical staff, and student healthcare.', 'ACTIVE', 16, admin_id),
                    (v_key_id, s.id, 'Maintenance & Facilities', 'MAINTENANCE', 'Campus repairs, electricals, sanitation, and physical upkeep.', 'ACTIVE', 17, admin_id),
                    (v_key_id, s.id, 'Examination & Assessment', 'EXAMINATION', 'Standardized grading, test scheduling, and report cards.', 'ACTIVE', 18, admin_id),
                    (v_key_id, s.id, 'Student Affairs & Admissions', 'STUDENT_AFFAIRS', 'Enrollment, student counseling, and co-curriculars.', 'ACTIVE', 19, admin_id),
                    (v_key_id, s.id, 'General / Unassigned', 'GENERAL', 'Non-departmental staff or unassigned profiles.', 'ACTIVE', 20, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL 
                DO UPDATE SET value_name = EXCLUDED.value_name, description = EXCLUDED.description, status = 'ACTIVE';
            END IF;

            -- ================================================================
            -- 2. DESIGNATION
            -- ================================================================
            INSERT INTO public.lookup_keys (
                school_id, key_name, key_code, description, key_type, icon, status, created_by
            ) VALUES (
                s.id, 'Designation', 'DESIGNATION', 'Staff and faculty job designations and official academic ranks.',
                'SYSTEM', 'badge_outlined', 'ACTIVE', admin_id
            )
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL 
            DO UPDATE SET key_name = EXCLUDED.key_name, description = EXCLUDED.description
            RETURNING id INTO v_key_id;

            IF v_key_id IS NULL THEN
                SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s.id AND key_code = 'DESIGNATION' AND deleted_at IS NULL LIMIT 1;
            END IF;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'Principal / Head of School', 'PRINCIPAL', 'Executive academic head and institutional director.', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Vice Principal', 'VICE_PRINCIPAL', 'Deputy head of school and senior academic administrator.', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Head of Department (HOD)', 'HOD', 'Academic department supervisor and curriculum lead.', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Post Graduate Teacher (PGT)', 'PGT', 'Senior secondary faculty teaching Classes 11 and 12.', 'ACTIVE', 4, admin_id),
                    (v_key_id, s.id, 'Trained Graduate Teacher (TGT)', 'TGT', 'Secondary faculty teaching Classes 6 through 10.', 'ACTIVE', 5, admin_id),
                    (v_key_id, s.id, 'Primary Teacher (PRT)', 'PRT', 'Primary level faculty teaching Classes 1 through 5.', 'ACTIVE', 6, admin_id),
                    (v_key_id, s.id, 'Pre-Primary / Kindergarten Teacher', 'KINDERGARTEN_TEACHER', 'Early childhood education and preschool teacher.', 'ACTIVE', 7, admin_id),
                    (v_key_id, s.id, 'Activity / Arts / Music Teacher', 'ARTS_TEACHER', 'Creative arts, music, dance, and cultural instructor.', 'ACTIVE', 8, admin_id),
                    (v_key_id, s.id, 'Physical Education Instructor (PET)', 'PET', 'Sports master, athletics coach, and fitness educator.', 'ACTIVE', 9, admin_id),
                    (v_key_id, s.id, 'Special Educator / Counselor', 'COUNSELOR', 'Student behavioral counselor and learning disability specialist.', 'ACTIVE', 10, admin_id),
                    (v_key_id, s.id, 'Laboratory Assistant', 'LAB_ASSISTANT', 'Science and computer lab technician and practical supervisor.', 'ACTIVE', 11, admin_id),
                    (v_key_id, s.id, 'Librarian / Media Specialist', 'LIBRARIAN', 'Head of library, circulation manager, and cataloguer.', 'ACTIVE', 12, admin_id),
                    (v_key_id, s.id, 'Administrative Officer', 'ADMIN_OFFICER', 'Office manager and institutional operations supervisor.', 'ACTIVE', 13, admin_id),
                    (v_key_id, s.id, 'Accountant / Finance Executive', 'ACCOUNTANT', 'Tuition billing, cash handling, accounts, and ledger executive.', 'ACTIVE', 14, admin_id),
                    (v_key_id, s.id, 'Human Resources Executive', 'HR_EXECUTIVE', 'Recruitment, employee onboarding, attendance, and welfare executive.', 'ACTIVE', 15, admin_id),
                    (v_key_id, s.id, 'IT Support Engineer / System Admin', 'IT_ADMIN', 'Campus networking, computer maintenance, and ERP admin.', 'ACTIVE', 16, admin_id),
                    (v_key_id, s.id, 'Transport Incharge / Fleet Manager', 'FLEET_MANAGER', 'Bus operations, route planning, and driver coordinator.', 'ACTIVE', 17, admin_id),
                    (v_key_id, s.id, 'School Bus Driver', 'BUS_DRIVER', 'Licensed vehicle operator for student transit.', 'ACTIVE', 18, admin_id),
                    (v_key_id, s.id, 'Security Officer / Guard', 'SECURITY_GUARD', 'Campus gate security, visitor logging, and surveillance guard.', 'ACTIVE', 19, admin_id),
                    (v_key_id, s.id, 'Support Staff / Housekeeping', 'SUPPORT_STAFF', 'Campus sanitation, maintenance, and auxiliary assistance staff.', 'ACTIVE', 20, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL 
                DO UPDATE SET value_name = EXCLUDED.value_name, description = EXCLUDED.description, status = 'ACTIVE';
            END IF;

            -- ================================================================
            -- 3. EMPLOYMENT_TYPE
            -- ================================================================
            INSERT INTO public.lookup_keys (
                school_id, key_name, key_code, description, key_type, icon, status, created_by
            ) VALUES (
                s.id, 'Employment Type', 'EMPLOYMENT_TYPE', 'Contractual nature of employee engagement.',
                'SYSTEM', 'work_outline_rounded', 'ACTIVE', admin_id
            )
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL 
            DO UPDATE SET key_name = EXCLUDED.key_name, description = EXCLUDED.description
            RETURNING id INTO v_key_id;

            IF v_key_id IS NULL THEN
                SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s.id AND key_code = 'EMPLOYMENT_TYPE' AND deleted_at IS NULL LIMIT 1;
            END IF;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'Full-time', 'FULL_TIME', 'Standard permanent employment with full institutional benefits.', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Part-time', 'PART_TIME', 'Hourly or specified partial shift engagement.', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Contractual', 'CONTRACTUAL', 'Fixed-term contractual appointment.', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Temporary', 'TEMPORARY', 'Short-term or seasonal engagement.', 'ACTIVE', 4, admin_id),
                    (v_key_id, s.id, 'Visiting Faculty', 'VISITING_FACULTY', 'Guest lecturer or visiting specialist instructor.', 'ACTIVE', 5, admin_id),
                    (v_key_id, s.id, 'Internship', 'INTERNSHIP', 'Trainee or educational intern placement.', 'ACTIVE', 6, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL 
                DO UPDATE SET value_name = EXCLUDED.value_name, description = EXCLUDED.description, status = 'ACTIVE';
            END IF;

            -- ================================================================
            -- 4. WORK_MODE
            -- ================================================================
            INSERT INTO public.lookup_keys (
                school_id, key_name, key_code, description, key_type, icon, status, created_by
            ) VALUES (
                s.id, 'Work Mode', 'WORK_MODE', 'Physical and remote work operational arrangements.',
                'SYSTEM', 'location_on_outlined', 'ACTIVE', admin_id
            )
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL 
            DO UPDATE SET key_name = EXCLUDED.key_name, description = EXCLUDED.description
            RETURNING id INTO v_key_id;

            IF v_key_id IS NULL THEN
                SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s.id AND key_code = 'WORK_MODE' AND deleted_at IS NULL LIMIT 1;
            END IF;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'On-site', 'ON_SITE', 'Full-time physical presence on school campus required.', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Hybrid', 'HYBRID', 'Combination of scheduled campus presence and remote work.', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Remote', 'REMOTE', 'Fully remote or telecommuting engagement.', 'ACTIVE', 3, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL 
                DO UPDATE SET value_name = EXCLUDED.value_name, description = EXCLUDED.description, status = 'ACTIVE';
            END IF;

            -- ================================================================
            -- 5. RECRUITMENT_SOURCE
            -- ================================================================
            INSERT INTO public.lookup_keys (
                school_id, key_name, key_code, description, key_type, icon, status, created_by
            ) VALUES (
                s.id, 'Recruitment Source', 'RECRUITMENT_SOURCE', 'Candidate acquisition channels and recruitment origins.',
                'SYSTEM', 'share_outlined', 'ACTIVE', admin_id
            )
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL 
            DO UPDATE SET key_name = EXCLUDED.key_name, description = EXCLUDED.description
            RETURNING id INTO v_key_id;

            IF v_key_id IS NULL THEN
                SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s.id AND key_code = 'RECRUITMENT_SOURCE' AND deleted_at IS NULL LIMIT 1;
            END IF;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'Website', 'WEBSITE', 'Direct submission via school official careers portal.', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'LinkedIn', 'LINKEDIN', 'LinkedIn jobs posting or direct recruiter outreach.', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Referral', 'REFERRAL', 'Internal recommendation by current staff or faculty.', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Job Portal', 'JOB_PORTAL', 'External job boards (Naukri, Indeed, Glassdoor).', 'ACTIVE', 4, admin_id),
                    (v_key_id, s.id, 'Campus', 'CAMPUS', 'University campus placement drive or teacher education college.', 'ACTIVE', 5, admin_id),
                    (v_key_id, s.id, 'Direct Walk-in', 'WALK_IN', 'In-person resume submission at school administrative office.', 'ACTIVE', 6, admin_id),
                    (v_key_id, s.id, 'Recruitment Agency', 'AGENCY', 'Staffing partner or educational placement consultancy.', 'ACTIVE', 7, admin_id),
                    (v_key_id, s.id, 'Others', 'OTHERS', 'Other miscellaneous recruitment sources.', 'ACTIVE', 8, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL 
                DO UPDATE SET value_name = EXCLUDED.value_name, description = EXCLUDED.description, status = 'ACTIVE';
            END IF;

            -- ================================================================
            -- 6. INTERVIEW_ROUND
            -- ================================================================
            INSERT INTO public.lookup_keys (
                school_id, key_name, key_code, description, key_type, icon, status, created_by
            ) VALUES (
                s.id, 'Interview Round', 'INTERVIEW_ROUND', 'Recruitment evaluation and interview milestones.',
                'SYSTEM', 'timeline_rounded', 'ACTIVE', admin_id
            )
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL 
            DO UPDATE SET key_name = EXCLUDED.key_name, description = EXCLUDED.description
            RETURNING id INTO v_key_id;

            IF v_key_id IS NULL THEN
                SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s.id AND key_code = 'INTERVIEW_ROUND' AND deleted_at IS NULL LIMIT 1;
            END IF;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'Round 1 - Screening', 'ROUND_1_SCREENING', 'Initial resume screening and telephonic/HR check.', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Round 2 - Technical / Demo', 'ROUND_2_TECHNICAL', 'Subject matter assessment or classroom teaching demonstration.', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Round 3 - Panel Interview', 'ROUND_3_PANEL', 'Academic committee, HOD, and leadership panel evaluation.', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Round 4 - Final / HR Discussion', 'ROUND_4_FINAL', 'Principal discussion, compensation negotiation, and culture fit.', 'ACTIVE', 4, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL 
                DO UPDATE SET value_name = EXCLUDED.value_name, description = EXCLUDED.description, status = 'ACTIVE';
            END IF;

            -- ================================================================
            -- 7. INTERVIEW_MODE
            -- ================================================================
            INSERT INTO public.lookup_keys (
                school_id, key_name, key_code, description, key_type, icon, status, created_by
            ) VALUES (
                s.id, 'Interview Mode', 'INTERVIEW_MODE', 'Communication medium for candidate interviews.',
                'SYSTEM', 'video_camera_front_outlined', 'ACTIVE', admin_id
            )
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL 
            DO UPDATE SET key_name = EXCLUDED.key_name, description = EXCLUDED.description
            RETURNING id INTO v_key_id;

            IF v_key_id IS NULL THEN
                SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s.id AND key_code = 'INTERVIEW_MODE' AND deleted_at IS NULL LIMIT 1;
            END IF;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'In Person', 'IN_PERSON', 'On-campus interview in designated conference room or classroom.', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Online', 'ONLINE', 'Video conference via Google Meet / Zoom / Microsoft Teams.', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Phone', 'PHONE', 'Voice telephonic conversation.', 'ACTIVE', 3, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL 
                DO UPDATE SET value_name = EXCLUDED.value_name, description = EXCLUDED.description, status = 'ACTIVE';
            END IF;

            -- ================================================================
            -- 8. ASSESSMENT_TYPE
            -- ================================================================
            INSERT INTO public.lookup_keys (
                school_id, key_name, key_code, description, key_type, icon, status, created_by
            ) VALUES (
                s.id, 'Assessment Type', 'ASSESSMENT_TYPE', 'Candidate technical, pedagogical, and behavioral assessment formats.',
                'SYSTEM', 'assignment_outlined', 'ACTIVE', admin_id
            )
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL 
            DO UPDATE SET key_name = EXCLUDED.key_name, description = EXCLUDED.description
            RETURNING id INTO v_key_id;

            IF v_key_id IS NULL THEN
                SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s.id AND key_code = 'ASSESSMENT_TYPE' AND deleted_at IS NULL LIMIT 1;
            END IF;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'Teaching Demo', 'TEACHING_DEMO', 'Live classroom lecture demonstration evaluating pedagogy and student engagement.', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Written Test', 'WRITTEN_TEST', 'Subject knowledge and language proficiency written examination.', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Technical Test', 'TECHNICAL_TEST', 'Hands-on coding, laboratory experiment, or technical problem solving.', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Practical', 'PRACTICAL', 'Vocational, sports, arts, or laboratory demonstration.', 'ACTIVE', 4, admin_id),
                    (v_key_id, s.id, 'Psychometric', 'PSYCHOMETRIC', 'Behavioral, personality, and situational judgment evaluation.', 'ACTIVE', 5, admin_id),
                    (v_key_id, s.id, 'Other', 'OTHER', 'Custom or specialized assessment format.', 'ACTIVE', 6, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL 
                DO UPDATE SET value_name = EXCLUDED.value_name, description = EXCLUDED.description, status = 'ACTIVE';
            END IF;

            -- ================================================================
            -- 9. RECRUITMENT_STAGE
            -- ================================================================
            INSERT INTO public.lookup_keys (
                school_id, key_name, key_code, description, key_type, icon, status, created_by
            ) VALUES (
                s.id, 'Recruitment Stage', 'RECRUITMENT_STAGE', 'Recruitment pipeline workflow milestones.',
                'SYSTEM', 'view_kanban_outlined', 'ACTIVE', admin_id
            )
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL 
            DO UPDATE SET key_name = EXCLUDED.key_name, description = EXCLUDED.description
            RETURNING id INTO v_key_id;

            IF v_key_id IS NULL THEN
                SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s.id AND key_code = 'RECRUITMENT_STAGE' AND deleted_at IS NULL LIMIT 1;
            END IF;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'Applied', 'APPLIED', 'Candidate submitted application and awaiting preliminary review.', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Shortlisted', 'SHORTLISTED', 'Resume approved for interview scheduling.', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Interview', 'INTERVIEW', 'Active evaluations and panel interview rounds in progress.', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Selected', 'SELECTED', 'Candidate successfully cleared interviews; ready for offer.', 'ACTIVE', 4, admin_id),
                    (v_key_id, s.id, 'Offered', 'OFFERED', 'Formal job offer letter generated and dispatched.', 'ACTIVE', 5, admin_id),
                    (v_key_id, s.id, 'Hired', 'HIRED', 'Offer accepted; converted to employee and in onboarding.', 'ACTIVE', 6, admin_id),
                    (v_key_id, s.id, 'Rejected', 'REJECTED', 'Application disqualified or declined.', 'ACTIVE', 7, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL 
                DO UPDATE SET value_name = EXCLUDED.value_name, description = EXCLUDED.description, status = 'ACTIVE';
            END IF;

            -- ================================================================
            -- 10. TRAINING_CATEGORY
            -- ================================================================
            INSERT INTO public.lookup_keys (
                school_id, key_name, key_code, description, key_type, icon, status, created_by
            ) VALUES (
                s.id, 'Training Category', 'TRAINING_CATEGORY', 'Professional development and faculty training curriculum categories.',
                'SYSTEM', 'school_outlined', 'ACTIVE', admin_id
            )
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL 
            DO UPDATE SET key_name = EXCLUDED.key_name, description = EXCLUDED.description
            RETURNING id INTO v_key_id;

            IF v_key_id IS NULL THEN
                SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s.id AND key_code = 'TRAINING_CATEGORY' AND deleted_at IS NULL LIMIT 1;
            END IF;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'Digital & Technology', 'DIGITAL_TECH', 'EdTech tools, smart boards, AI in education, and digital classrooms.', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Professional Development', 'PROF_DEV', 'Pedagogical strategies, modern teaching methodologies, and subject mastery.', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Compliance & Regulatory', 'COMPLIANCE', 'POCSO, child protection, POSH, school safety guidelines, and CBSE norms.', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Soft Skills & Communication', 'SOFT_SKILLS', 'Classroom management, parent communication, and active listening.', 'ACTIVE', 4, admin_id),
                    (v_key_id, s.id, 'Health, Safety & Medical', 'HEALTH_SAFETY', 'First aid, fire drills, student CPR, and emergency campus evacuation.', 'ACTIVE', 5, admin_id),
                    (v_key_id, s.id, 'Leadership & Management', 'LEADERSHIP', 'Departmental administration, teacher leadership, and mentoring.', 'ACTIVE', 6, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL 
                DO UPDATE SET value_name = EXCLUDED.value_name, description = EXCLUDED.description, status = 'ACTIVE';
            END IF;

            -- ================================================================
            -- 11. TRAINING_TYPE
            -- ================================================================
            INSERT INTO public.lookup_keys (
                school_id, key_name, key_code, description, key_type, icon, status, created_by
            ) VALUES (
                s.id, 'Training Type', 'TRAINING_TYPE', 'Classification of training initiative scope.',
                'SYSTEM', 'category_outlined', 'ACTIVE', admin_id
            )
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL 
            DO UPDATE SET key_name = EXCLUDED.key_name, description = EXCLUDED.description
            RETURNING id INTO v_key_id;

            IF v_key_id IS NULL THEN
                SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s.id AND key_code = 'TRAINING_TYPE' AND deleted_at IS NULL LIMIT 1;
            END IF;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'Technical', 'TECHNICAL', 'Technical training on laboratory instruments, digital tools, and software.', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Professional Development', 'PROFESSIONAL', 'General pedagogical development and teacher training.', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Compliance', 'COMPLIANCE', 'Mandatory legal and regulatory compliance certification.', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Soft Skills', 'SOFT_SKILLS', 'Interpersonal skills and emotional intelligence in classroom.', 'ACTIVE', 4, admin_id),
                    (v_key_id, s.id, 'Safety', 'SAFETY', 'Physical campus safety, disaster response, and medical protocols.', 'ACTIVE', 5, admin_id),
                    (v_key_id, s.id, 'Orientation', 'ORIENTATION', 'New employee induction and cultural onboarding.', 'ACTIVE', 6, admin_id),
                    (v_key_id, s.id, 'Leadership', 'LEADERSHIP', 'Executive development for HODs, coordinators, and supervisors.', 'ACTIVE', 7, admin_id),
                    (v_key_id, s.id, 'Other', 'OTHER', 'Other specialized training types.', 'ACTIVE', 8, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL 
                DO UPDATE SET value_name = EXCLUDED.value_name, description = EXCLUDED.description, status = 'ACTIVE';
            END IF;

            -- ================================================================
            -- 12. TRAINING_MODE
            -- ================================================================
            INSERT INTO public.lookup_keys (
                school_id, key_name, key_code, description, key_type, icon, status, created_by
            ) VALUES (
                s.id, 'Training Mode', 'TRAINING_MODE', 'Delivery format for training sessions.',
                'SYSTEM', 'cast_for_education_outlined', 'ACTIVE', admin_id
            )
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL 
            DO UPDATE SET key_name = EXCLUDED.key_name, description = EXCLUDED.description
            RETURNING id INTO v_key_id;

            IF v_key_id IS NULL THEN
                SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s.id AND key_code = 'TRAINING_MODE' AND deleted_at IS NULL LIMIT 1;
            END IF;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'Online', 'ONLINE', 'Virtual webinar or e-learning platform.', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Offline', 'OFFLINE', 'Physical classroom or auditorium session.', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Hybrid', 'HYBRID', 'Simultaneous in-person and live streamed participation.', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Workshop', 'WORKSHOP', 'Interactive hands-on practical activity studio.', 'ACTIVE', 4, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL 
                DO UPDATE SET value_name = EXCLUDED.value_name, description = EXCLUDED.description, status = 'ACTIVE';
            END IF;

            -- ================================================================
            -- 13. TRAINING_ASSESSMENT_TYPE
            -- ================================================================
            INSERT INTO public.lookup_keys (
                school_id, key_name, key_code, description, key_type, icon, status, created_by
            ) VALUES (
                s.id, 'Training Assessment Type', 'TRAINING_ASSESSMENT_TYPE', 'Testing and comprehension verification following training.',
                'SYSTEM', 'quiz_outlined', 'ACTIVE', admin_id
            )
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL 
            DO UPDATE SET key_name = EXCLUDED.key_name, description = EXCLUDED.description
            RETURNING id INTO v_key_id;

            IF v_key_id IS NULL THEN
                SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s.id AND key_code = 'TRAINING_ASSESSMENT_TYPE' AND deleted_at IS NULL LIMIT 1;
            END IF;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'None', 'NONE', 'No post-training examination required; attendance certificate.', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Quiz', 'QUIZ', 'Multiple choice knowledge verification questionnaire.', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Assignment', 'ASSIGNMENT', 'Take-home submission or lesson plan creation.', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Evaluation', 'EVALUATION', 'Peer or supervisor observational review.', 'ACTIVE', 4, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL 
                DO UPDATE SET value_name = EXCLUDED.value_name, description = EXCLUDED.description, status = 'ACTIVE';
            END IF;

            -- ================================================================
            -- 14. POLICY_APPLICABILITY
            -- ================================================================
            INSERT INTO public.lookup_keys (
                school_id, key_name, key_code, description, key_type, icon, status, created_by
            ) VALUES (
                s.id, 'Policy Applicability', 'POLICY_APPLICABILITY', 'Target audience scope for institutional policies and handbooks.',
                'SYSTEM', 'groups_outlined', 'ACTIVE', admin_id
            )
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL 
            DO UPDATE SET key_name = EXCLUDED.key_name, description = EXCLUDED.description
            RETURNING id INTO v_key_id;

            IF v_key_id IS NULL THEN
                SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s.id AND key_code = 'POLICY_APPLICABILITY' AND deleted_at IS NULL LIMIT 1;
            END IF;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'Entire Institute', 'ENTIRE_INSTITUTE', 'Applies universally to all staff, faculty, and administration.', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Department', 'DEPARTMENT', 'Targeted specifically to one or more departments.', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Designation', 'DESIGNATION', 'Targeted specifically to staff holding specific job titles.', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Selected Users', 'SELECTED_USERS', 'Explicitly mapped to designated individual personnel.', 'ACTIVE', 4, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL 
                DO UPDATE SET value_name = EXCLUDED.value_name, description = EXCLUDED.description, status = 'ACTIVE';
            END IF;

            -- ================================================================
            -- 15. POLICY_REVIEW_FREQUENCY
            -- ================================================================
            INSERT INTO public.lookup_keys (
                school_id, key_name, key_code, description, key_type, icon, status, created_by
            ) VALUES (
                s.id, 'Policy Review Frequency', 'POLICY_REVIEW_FREQUENCY', 'Mandated audit and renewal cycles for policies.',
                'SYSTEM', 'update_rounded', 'ACTIVE', admin_id
            )
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL 
            DO UPDATE SET key_name = EXCLUDED.key_name, description = EXCLUDED.description
            RETURNING id INTO v_key_id;

            IF v_key_id IS NULL THEN
                SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s.id AND key_code = 'POLICY_REVIEW_FREQUENCY' AND deleted_at IS NULL LIMIT 1;
            END IF;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'Quarterly', 'QUARTERLY', 'Reviewed every 3 months.', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Semi-Annual', 'SEMI_ANNUAL', 'Reviewed every 6 months.', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Annual', 'ANNUAL', 'Reviewed every 12 months.', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Biennial', 'BIENNIAL', 'Reviewed every 2 years.', 'ACTIVE', 4, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL 
                DO UPDATE SET value_name = EXCLUDED.value_name, description = EXCLUDED.description, status = 'ACTIVE';
            END IF;

            -- ================================================================
            -- 16. HR_DOCUMENT_TYPE
            -- ================================================================
            INSERT INTO public.lookup_keys (
                school_id, key_name, key_code, description, key_type, icon, status, created_by
            ) VALUES (
                s.id, 'HR Document Type', 'HR_DOCUMENT_TYPE', 'Classification of personnel, legal, and compliance documents.',
                'SYSTEM', 'description_outlined', 'ACTIVE', admin_id
            )
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL 
            DO UPDATE SET key_name = EXCLUDED.key_name, description = EXCLUDED.description
            RETURNING id INTO v_key_id;

            IF v_key_id IS NULL THEN
                SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s.id AND key_code = 'HR_DOCUMENT_TYPE' AND deleted_at IS NULL LIMIT 1;
            END IF;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'Employee Document', 'EMPLOYEE_DOCUMENT', 'Personal employee dossier documents and submissions.', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'HR Document', 'HR_DOCUMENT', 'Internal Human Resources administrative letters and records.', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Compliance Document', 'COMPLIANCE_DOCUMENT', 'Statutory, government, or regulatory filings and affidavits.', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Certificate', 'CERTIFICATE', 'Educational degrees, professional certifications, and awards.', 'ACTIVE', 4, admin_id),
                    (v_key_id, s.id, 'Contract', 'CONTRACT', 'Employment contract, service bond, or consultancy agreement.', 'ACTIVE', 5, admin_id),
                    (v_key_id, s.id, 'Joining Document', 'JOINING_DOCUMENT', 'Completed joining checklist, declaration, and bank details.', 'ACTIVE', 6, admin_id),
                    (v_key_id, s.id, 'Identity / Verification', 'ID_VERIFICATION', 'Aadhaar, PAN card, passport, police verification report.', 'ACTIVE', 7, admin_id),
                    (v_key_id, s.id, 'Training Certificate', 'TRAINING_CERTIFICATE', 'Completion certificate from internal or external workshops.', 'ACTIVE', 8, admin_id),
                    (v_key_id, s.id, 'Legal Document', 'LEGAL_DOCUMENT', 'Non-disclosure agreements, dispute resolutions, and legal forms.', 'ACTIVE', 9, admin_id),
                    (v_key_id, s.id, 'Template', 'TEMPLATE', 'Standardized blank format for issuance to employees.', 'ACTIVE', 10, admin_id),
                    (v_key_id, s.id, 'Other', 'OTHER', 'Other miscellaneous HR documentation.', 'ACTIVE', 11, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL 
                DO UPDATE SET value_name = EXCLUDED.value_name, description = EXCLUDED.description, status = 'ACTIVE';
            END IF;

            -- ================================================================
            -- 17. DOCUMENT_ACCESS_LEVEL
            -- ================================================================
            INSERT INTO public.lookup_keys (
                school_id, key_name, key_code, description, key_type, icon, status, created_by
            ) VALUES (
                s.id, 'Document Access Level', 'DOCUMENT_ACCESS_LEVEL', 'Confidentiality and visibility classification for stored files.',
                'SYSTEM', 'lock_outlined', 'ACTIVE', admin_id
            )
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL 
            DO UPDATE SET key_name = EXCLUDED.key_name, description = EXCLUDED.description
            RETURNING id INTO v_key_id;

            IF v_key_id IS NULL THEN
                SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s.id AND key_code = 'DOCUMENT_ACCESS_LEVEL' AND deleted_at IS NULL LIMIT 1;
            END IF;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'Institute Wide', 'INSTITUTE_WIDE', 'Accessible to all authenticated staff and teachers.', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Department Only', 'DEPARTMENT', 'Restricted to members of the designated department.', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Designation Only', 'DESIGNATION', 'Restricted to holders of specific designations.', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Confidential HR', 'CONFIDENTIAL_HR', 'Strictly confidential; visible only to HR Directors & Super Admins.', 'ACTIVE', 4, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL 
                DO UPDATE SET value_name = EXCLUDED.value_name, description = EXCLUDED.description, status = 'ACTIVE';
            END IF;

            -- ================================================================
            -- 18. HR_TEMPLATE_TYPE
            -- ================================================================
            INSERT INTO public.lookup_keys (
                school_id, key_name, key_code, description, key_type, icon, status, created_by
            ) VALUES (
                s.id, 'HR Template Type', 'HR_TEMPLATE_TYPE', 'Types of official communication and letterhead templates.',
                'SYSTEM', 'drafts_outlined', 'ACTIVE', admin_id
            )
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL 
            DO UPDATE SET key_name = EXCLUDED.key_name, description = EXCLUDED.description
            RETURNING id INTO v_key_id;

            IF v_key_id IS NULL THEN
                SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s.id AND key_code = 'HR_TEMPLATE_TYPE' AND deleted_at IS NULL LIMIT 1;
            END IF;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'Offer Letter', 'OFFER_LETTER', 'Formal employment offer letter sent to selected candidates.', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Appointment Letter', 'APPOINTMENT_LETTER', 'Official appointment order confirming job commencement.', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Warning Letter', 'WARNING_LETTER', 'Disciplinary notice or formal performance warning.', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Experience Letter', 'EXPERIENCE_LETTER', 'Service certificate confirming tenure and designation.', 'ACTIVE', 4, admin_id),
                    (v_key_id, s.id, 'Relieving Letter', 'RELIEVING_LETTER', 'Formal clearance letter upon resignation or departure.', 'ACTIVE', 5, admin_id),
                    (v_key_id, s.id, 'NDA & Confidentiality', 'NDA', 'Non-disclosure and student data privacy agreement.', 'ACTIVE', 6, admin_id),
                    (v_key_id, s.id, 'Code of Conduct', 'CODE_OF_CONDUCT', 'Institutional staff ethics, behavior, and dress code policy.', 'ACTIVE', 7, admin_id),
                    (v_key_id, s.id, 'Joining Checklist', 'JOINING_CHECKLIST', 'Checklist of documents and onboarding tasks for day 1.', 'ACTIVE', 8, admin_id),
                    (v_key_id, s.id, 'HR Forms', 'HR_FORMS', 'Standard internal requisition, advance, or claim forms.', 'ACTIVE', 9, admin_id),
                    (v_key_id, s.id, 'Custom', 'CUSTOM', 'Custom institutional letter or template.', 'ACTIVE', 10, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL 
                DO UPDATE SET value_name = EXCLUDED.value_name, description = EXCLUDED.description, status = 'ACTIVE';
            END IF;

            -- ================================================================
            -- 19. ONBOARDING_TASK_CATEGORY
            -- ================================================================
            INSERT INTO public.lookup_keys (
                school_id, key_name, key_code, description, key_type, icon, status, created_by
            ) VALUES (
                s.id, 'Onboarding Task Category', 'ONBOARDING_TASK_CATEGORY', 'Responsible departments for employee onboarding workflow tasks.',
                'SYSTEM', 'task_alt_outlined', 'ACTIVE', admin_id
            )
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL 
            DO UPDATE SET key_name = EXCLUDED.key_name, description = EXCLUDED.description
            RETURNING id INTO v_key_id;

            IF v_key_id IS NULL THEN
                SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s.id AND key_code = 'ONBOARDING_TASK_CATEGORY' AND deleted_at IS NULL LIMIT 1;
            END IF;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'HR', 'HR', 'Human Resources paperwork, contracts, and benefit enrollment.', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'IT', 'IT', 'Email setup, ERP credentials, laptop/desktop, and smartboard access.', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Administration', 'ADMINISTRATION', 'Campus ID card, biometric registration, and desk allocation.', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Department', 'DEPARTMENT', 'HOD introduction, curriculum handover, and timetable assignment.', 'ACTIVE', 4, admin_id),
                    (v_key_id, s.id, 'Security', 'SECURITY', 'Campus parking sticker, security clearance, and emergency contacts.', 'ACTIVE', 5, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL 
                DO UPDATE SET value_name = EXCLUDED.value_name, description = EXCLUDED.description, status = 'ACTIVE';
            END IF;

        END IF;
    END LOOP;
END $$;
