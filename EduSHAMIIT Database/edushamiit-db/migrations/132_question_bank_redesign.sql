-- 1. Convert multiple_choice options object to array
UPDATE exam_questions
SET options = jsonb_build_array(options->>'A', options->>'B', options->>'C', options->>'D')
WHERE question_type = 'multiple_choice' AND jsonb_typeof(options) = 'object';

UPDATE exam_questions
SET options = jsonb_build_array(options->>'T', options->>'F'),
    correct_answer = 'A'
WHERE question_type = 'true_false' AND jsonb_typeof(options) = 'object';

-- 2. Populate null options for true_false questions with ["True", "False"]
UPDATE exam_questions
SET options = '["True", "False"]'::jsonb,
    correct_answer = 'A'
WHERE question_type = 'true_false' AND options IS NULL;

UPDATE question_bank
SET options = '["True", "False"]'::jsonb,
    correct_answer = 'A'
WHERE question_type = 'true_false' AND options IS NULL;

-- 3. Convert correct answers of MCQs/True-False/Single Correct/Assertion Reason to option letters (A, B, C, D...)
WITH updated_answers AS (
    SELECT DISTINCT ON (q.id)
        q.id,
        chr(65 + (pos.ord - 1)::int) AS letter_ans
    FROM exam_questions q
    CROSS JOIN LATERAL jsonb_array_elements_text(q.options) WITH ORDINALITY AS pos(elem, ord)
    WHERE q.question_type IN ('mcq', 'true_false', 'assertion_reason', 'single_correct')
      AND q.options IS NOT NULL 
      AND q.correct_answer IS NOT NULL
      AND jsonb_typeof(q.options) = 'array'
      AND trim(lower(pos.elem)) = trim(lower(q.correct_answer))
)
UPDATE exam_questions eq
SET correct_answer = ua.letter_ans
FROM updated_answers ua
WHERE eq.id = ua.id;

WITH updated_answers_bank AS (
    SELECT DISTINCT ON (q.id)
        q.id,
        chr(65 + (pos.ord - 1)::int) AS letter_ans
    FROM question_bank q
    CROSS JOIN LATERAL jsonb_array_elements_text(q.options) WITH ORDINALITY AS pos(elem, ord)
    WHERE q.question_type IN ('mcq', 'true_false')
      AND q.options IS NOT NULL 
      AND q.correct_answer IS NOT NULL
      AND jsonb_typeof(q.options) = 'array'
      AND trim(lower(pos.elem)) = trim(lower(q.correct_answer))
)
UPDATE question_bank qb
SET correct_answer = uab.letter_ans
FROM updated_answers_bank uab
WHERE qb.id = uab.id;

-- 4. Update question types to the standard ones
UPDATE exam_questions 
SET question_type = 'single_select' 
WHERE question_type IN ('mcq', 'true_false', 'assertion_reason', 'single_correct', 'multiple_choice');

UPDATE exam_questions 
SET question_type = 'subjective' 
WHERE question_type IN ('short_answer', 'long_answer', 'numerical', 'fill_in_the_blank', 'descriptive');

UPDATE question_bank 
SET question_type = 'single_select' 
WHERE question_type IN ('mcq', 'true_false');

UPDATE question_bank 
SET question_type = 'subjective' 
WHERE question_type IN ('short_answer', 'long_answer');

-- 5. Alter default question type in exam_questions
ALTER TABLE exam_questions ALTER COLUMN question_type SET DEFAULT 'single_select';

-- 6. Add Check Constraints
ALTER TABLE exam_questions 
ADD CONSTRAINT chk_exam_question_type 
CHECK (question_type IN ('single_select', 'multi_select', 'subjective'));

ALTER TABLE question_bank 
ADD CONSTRAINT chk_question_bank_type 
CHECK (question_type IN ('single_select', 'multi_select', 'subjective'));
