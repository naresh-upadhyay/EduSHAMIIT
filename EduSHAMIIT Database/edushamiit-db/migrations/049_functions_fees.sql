-- Function: get_student_outstanding_balance
-- Calculates a student's total outstanding balance dynamically in the database
CREATE OR REPLACE FUNCTION get_student_outstanding_balance(p_student_id UUID, p_school_id UUID)
RETURNS NUMERIC AS $$
DECLARE
    v_balance NUMERIC;
BEGIN
    SELECT COALESCE(SUM(amount + COALESCE(late_fine, 0) - COALESCE(discount, 0) - COALESCE(amount_paid, 0)), 0.00)
    INTO v_balance
    FROM fees
    WHERE student_id = p_student_id 
      AND school_id = p_school_id 
      AND status != 'paid';
      
    RETURN v_balance;
END;
$$ LANGUAGE plpgsql;
