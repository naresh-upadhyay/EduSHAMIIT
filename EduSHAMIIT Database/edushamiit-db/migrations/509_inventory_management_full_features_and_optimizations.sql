-- ============================================================================
-- Migration 509: Enterprise Inventory Management Optimizations & Edge Cases
-- Features & Enhancements:
-- 1. Dynamic Stock Overview Aggregations by Time Range ('30d', '6m', '1y')
-- 2. Rolling 6-Month Real Purchase & Sales Trend Calculations
-- 3. Unfiltered Global Tenant KPIs vs Filtered View Totals
-- 4. Atomic Purchase Order & Sales Order Cancellation Stored Procedures
--    (Releases reservations and restores stock states cleanly)
-- 5. Export Selected IDs Support & Query Optimizations
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Cancel Purchase Order Procedure
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_inventory_cancel_purchase_order(
    p_school_id UUID,
    p_po_id UUID,
    p_reason TEXT DEFAULT 'Cancelled by procurement authority'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_po RECORD;
BEGIN
    SELECT * INTO v_po
    FROM public.inventory_purchase_orders
    WHERE id = p_po_id AND school_id = p_school_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Purchase order not found.');
    END IF;

    IF v_po.status IN ('Delivered', 'Completed', 'Received') THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Cannot cancel a purchase order that has already been received/delivered.');
    END IF;

    IF v_po.status = 'Cancelled' THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Purchase order is already cancelled.');
    END IF;

    UPDATE public.inventory_purchase_orders
    SET 
        status = 'Cancelled',
        notes = COALESCE(notes || E'\n[Cancelled]: ' || p_reason, '[Cancelled]: ' || p_reason),
        updated_at = NOW()
    WHERE id = p_po_id AND school_id = p_school_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'po_id', p_po_id,
        'po_number', v_po.po_number,
        'status', 'Cancelled',
        'message', 'Purchase order cancelled successfully.'
    );
END;
$function$;

-- ----------------------------------------------------------------------------
-- 2. Cancel Sales Order Procedure (With Stock Reservation Release)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_inventory_cancel_sales_order(
    p_school_id UUID,
    p_so_id UUID,
    p_reason TEXT DEFAULT 'Cancelled by sales department'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_so RECORD;
    v_item RECORD;
BEGIN
    SELECT * INTO v_so
    FROM public.inventory_sales_orders
    WHERE id = p_so_id AND school_id = p_school_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Sales order not found.');
    END IF;

    IF v_so.status IN ('Delivered', 'Completed', 'Fulfilled') THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Cannot cancel a sales order that has already been delivered/fulfilled.');
    END IF;

    IF v_so.status = 'Cancelled' THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Sales order is already cancelled.');
    END IF;

    -- Release reservations for all items in this SO
    FOR v_item IN 
        SELECT item_id, quantity_ordered
        FROM public.inventory_sales_order_items
        WHERE so_id = p_so_id
    LOOP
        UPDATE public.inventory_stock_balances
        SET 
            quantity_reserved = GREATEST(0, quantity_reserved - v_item.quantity_ordered),
            last_updated_at = NOW()
        WHERE item_id = v_item.item_id 
          AND school_id = p_school_id
          AND (v_so.store_id IS NULL OR store_id = v_so.store_id);
    END LOOP;

    UPDATE public.inventory_sales_orders
    SET 
        status = 'Cancelled',
        notes = COALESCE(notes || E'\n[Cancelled]: ' || p_reason, '[Cancelled]: ' || p_reason),
        updated_at = NOW()
    WHERE id = p_so_id AND school_id = p_school_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'so_id', p_so_id,
        'so_number', v_so.so_number,
        'status', 'Cancelled',
        'message', 'Sales order cancelled and reserved stock balances released.'
    );
END;
$function$;

-- ----------------------------------------------------------------------------
-- 3. Upgrade fn_inventory_get_overview with Dynamic Interval ('30d', '6m', '1y')
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_inventory_get_overview(
    p_school_id UUID,
    p_interval TEXT DEFAULT '6m'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_total_items INT := 0;
    v_total_stock_value NUMERIC(15, 2) := 0.0;
    v_total_stock_qty NUMERIC(15, 2) := 0.0;
    v_available_qty NUMERIC(15, 2) := 0.0;
    v_reserved_qty NUMERIC(15, 2) := 0.0;
    v_pending_purchase NUMERIC(15, 2) := 0.0;
    v_low_stock_count INT := 0;
    v_out_of_stock_count INT := 0;
    v_categories JSONB := '[]'::jsonb;
    v_low_stock_list JSONB := '[]'::jsonb;
    v_recent_activities JSONB := '[]'::jsonb;
    v_monthly_trend JSONB := '[]'::jsonb;
    v_palette TEXT[] := ARRAY['#2563EB', '#10B981', '#F59E0B', '#8B5CF6', '#EC4899', '#06B6D4', '#64748B'];
    v_start_date DATE;
    v_step_interval INTERVAL;
BEGIN
    -- 1. Total items count
    SELECT COUNT(*) INTO v_total_items
    FROM public.inventory_items
    WHERE school_id = p_school_id AND is_active = TRUE;

    -- 2. Total stock valuation & quantities
    SELECT 
        COALESCE(SUM(b.quantity_on_hand * i.purchase_price), 0.0),
        COALESCE(SUM(b.quantity_on_hand), 0.0),
        COALESCE(SUM(b.quantity_on_hand - b.quantity_reserved), 0.0),
        COALESCE(SUM(b.quantity_reserved), 0.0)
    INTO 
        v_total_stock_value,
        v_total_stock_qty,
        v_available_qty,
        v_reserved_qty
    FROM public.inventory_stock_balances b
    JOIN public.inventory_items i ON b.item_id = i.id
    WHERE b.school_id = p_school_id AND i.is_active = TRUE;

    -- 3. Pending Purchase Orders Value
    SELECT COALESCE(SUM(total_amount), 0.0) INTO v_pending_purchase
    FROM public.inventory_purchase_orders
    WHERE school_id = p_school_id AND status IN ('Pending', 'Processing', 'Partial');

    -- 4. Low stock & Out of stock counts (Aggregated across stores per item)
    WITH item_balances AS (
        SELECT item_id, SUM(quantity_on_hand) AS total_qty
        FROM public.inventory_stock_balances
        WHERE school_id = p_school_id
        GROUP BY item_id
    )
    SELECT 
        COUNT(CASE WHEN COALESCE(b.total_qty, 0) <= i.min_stock AND COALESCE(b.total_qty, 0) > 0 THEN 1 END),
        COUNT(CASE WHEN COALESCE(b.total_qty, 0) <= 0 THEN 1 END)
    INTO 
        v_low_stock_count,
        v_out_of_stock_count
    FROM public.inventory_items i
    LEFT JOIN item_balances b ON i.id = b.item_id
    WHERE i.school_id = p_school_id AND i.is_active = TRUE;

    -- 5. Category breakdown
    SELECT COALESCE(jsonb_agg(sub.cat), '[]'::jsonb)
    INTO v_categories
    FROM (
        WITH cat_counts AS (
            SELECT 
                COALESCE(NULLIF(TRIM(i.category), ''), 'General') AS category,
                COUNT(DISTINCT i.id) AS item_count,
                COALESCE(SUM(b.quantity_on_hand), 0.0) AS total_qty,
                COALESCE(SUM(b.quantity_on_hand * i.purchase_price), 0.0) AS total_val,
                ROW_NUMBER() OVER (ORDER BY COUNT(DISTINCT i.id) DESC) AS rn
            FROM public.inventory_items i
            LEFT JOIN public.inventory_stock_balances b ON i.id = b.item_id AND b.school_id = p_school_id
            WHERE i.school_id = p_school_id AND i.is_active = TRUE
            GROUP BY 1
        ),
        totals AS (
            SELECT COALESCE(SUM(item_count), 0) AS total_items FROM cat_counts
        )
        SELECT jsonb_build_object(
            'category', c.category,
            'item_count', c.item_count,
            'total_qty', c.total_qty,
            'total_val', c.total_val,
            'percentage', CASE WHEN t.total_items > 0 THEN ROUND((c.item_count::NUMERIC / t.total_items) * 100, 1) ELSE 0 END,
            'color', v_palette[((c.rn - 1) % array_length(v_palette, 1)) + 1]
        ) AS cat
        FROM cat_counts c, totals t
        ORDER BY c.item_count DESC
    ) sub;

    -- 6. Low stock alerts list
    SELECT COALESCE(jsonb_agg(sub.alert), '[]'::jsonb)
    INTO v_low_stock_list
    FROM (
        WITH item_balances AS (
            SELECT item_id, SUM(quantity_on_hand) AS total_qty
            FROM public.inventory_stock_balances
            WHERE school_id = p_school_id
            GROUP BY item_id
        )
        SELECT jsonb_build_object(
            'id', i.id,
            'item_name', i.item_name,
            'sku', i.sku,
            'category', i.category,
            'current_stock', COALESCE(b.total_qty, 0),
            'min_stock', i.min_stock,
            'unit', i.unit,
            'alert_text', CASE 
                WHEN COALESCE(b.total_qty, 0) <= 0 THEN 'Out of Stock'
                ELSE 'Only ' || COALESCE(b.total_qty, 0)::TEXT || ' ' || COALESCE(i.unit, 'Pcs') || ' Left'
            END,
            'severity', CASE WHEN COALESCE(b.total_qty, 0) <= 0 THEN 'critical' ELSE 'warning' END
        ) AS alert
        FROM public.inventory_items i
        LEFT JOIN item_balances b ON i.id = b.item_id
        WHERE i.school_id = p_school_id AND i.is_active = TRUE
          AND COALESCE(b.total_qty, 0) <= i.min_stock
        ORDER BY COALESCE(b.total_qty, 0) ASC
        LIMIT 6
    ) sub;

    -- 7. Recent activities list
    SELECT COALESCE(jsonb_agg(sub.act), '[]'::jsonb)
    INTO v_recent_activities
    FROM (
        SELECT jsonb_build_object(
            'id', m.id,
            'type', m.transaction_type,
            'title', CASE 
                WHEN m.transaction_type = 'Purchase' THEN 'Purchase Order Received'
                WHEN m.transaction_type = 'Stock In' THEN 'Stock Added'
                WHEN m.transaction_type = 'Sale' THEN 'Items Sold'
                WHEN m.transaction_type = 'Stock Out' THEN 'Items Issued'
                WHEN m.transaction_type = 'Transfer' THEN 'Stock Transferred'
                ELSE 'Stock Adjusted'
            END,
            'description', i.item_name || ' (' || ABS(m.quantity)::TEXT || ' ' || m.unit || ')',
            'created_at', m.created_at,
            'created_at_raw', m.created_at::TEXT,
            'formatted_time', TO_CHAR(m.created_at, 'DD Mon, HH:MI AM'),
            'color', CASE 
                WHEN m.transaction_type IN ('Purchase', 'Stock In') THEN '#10B981'
                WHEN m.transaction_type = 'Sale' THEN '#2563EB'
                WHEN m.transaction_type = 'Stock Out' THEN '#8B5CF6'
                WHEN m.transaction_type = 'Transfer' THEN '#06B6D4'
                ELSE '#F59E0B'
            END
        ) AS act
        FROM public.inventory_stock_movements m
        JOIN public.inventory_items i ON m.item_id = i.id
        WHERE m.school_id = p_school_id
        ORDER BY m.created_at DESC
        LIMIT 6
    ) sub;

    -- 8. Dynamic Rolling Trend based on p_interval
    IF LOWER(p_interval) IN ('30d', 'last 30 days', '30 days') THEN
        v_start_date := CURRENT_DATE - INTERVAL '30 days';
        v_step_interval := INTERVAL '5 days';
    ELSIF LOWER(p_interval) IN ('1y', 'last 1 year', '1 year', '12m') THEN
        v_start_date := DATE_TRUNC('month', CURRENT_DATE - INTERVAL '11 months');
        v_step_interval := INTERVAL '1 month';
    ELSE
        -- Default: Last 6 Months
        v_start_date := DATE_TRUNC('month', CURRENT_DATE - INTERVAL '5 months');
        v_step_interval := INTERVAL '1 month';
    END IF;

    SELECT COALESCE(jsonb_agg(sub.trend), '[]'::jsonb)
    INTO v_monthly_trend
    FROM (
        WITH months_series AS (
            SELECT 
                DATE_TRUNC('month', d) AS m_date,
                TO_CHAR(d, 'Mon') AS month_name
            FROM generate_series(
                v_start_date,
                DATE_TRUNC('month', CURRENT_DATE),
                v_step_interval
            ) d
        ),
        m_stats AS (
            SELECT 
                DATE_TRUNC('month', created_at) AS m_date,
                COALESCE(SUM(CASE WHEN transaction_type IN ('Stock In', 'Purchase', 'Opening') THEN total_value ELSE 0 END), 0.0) AS in_val,
                COALESCE(SUM(CASE WHEN transaction_type IN ('Stock Out', 'Sale', 'Issue') THEN total_value ELSE 0 END), 0.0) AS issued_val
            FROM public.inventory_stock_movements
            WHERE school_id = p_school_id
              AND created_at >= v_start_date
            GROUP BY 1
        )
        SELECT jsonb_build_object(
            'month', s.month_name,
            'total_stock', COALESCE(SUM(m.in_val) OVER (ORDER BY s.m_date), v_total_stock_value),
            'issued', COALESCE(m.issued_val, 0.0)
        ) AS trend
        FROM months_series s
        LEFT JOIN m_stats m ON s.m_date = m.m_date
        ORDER BY s.m_date ASC
    ) sub;

    RETURN jsonb_build_object(
        'success', TRUE,
        'kpis', jsonb_build_object(
            'total_items', v_total_items,
            'total_stock_value', v_total_stock_value,
            'total_stock_quantity', v_total_stock_qty,
            'available_quantity', v_available_qty,
            'reserved_quantity', v_reserved_qty,
            'pending_purchase_value', v_pending_purchase,
            'low_stock_items', v_low_stock_count,
            'out_of_stock_items', v_out_of_stock_count
        ),
        'category_stock', v_categories,
        'low_stock_alerts', v_low_stock_list,
        'recent_activities', v_recent_activities,
        'monthly_trend', v_monthly_trend,
        'interval', p_interval
    );
END;
$function$;

-- ----------------------------------------------------------------------------
-- 4. Upgrade fn_inventory_get_purchase_orders with Continuous 6-Month Rolling Trend
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_inventory_get_purchase_orders(
    p_school_id uuid,
    p_search text DEFAULT NULL::text,
    p_status text DEFAULT NULL::text,
    p_supplier text DEFAULT NULL::text,
    p_start_date date DEFAULT NULL::date,
    p_end_date date DEFAULT NULL::date,
    p_page integer DEFAULT 1,
    p_page_size integer DEFAULT 10,
    p_sort_by text DEFAULT 'order_date'::text,
    p_sort_order text DEFAULT 'desc'::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_offset INT := (GREATEST(1, p_page) - 1) * GREATEST(1, p_page_size);
    v_total_records INT := 0;
    v_pos JSONB := '[]'::jsonb;
    v_total_pos INT := 0;
    v_completed_pos INT := 0;
    v_pending_pos INT := 0;
    v_cancelled_pos INT := 0;
    v_total_spend NUMERIC(14,2) := 0.0;
    v_purchase_trend JSONB := '[]'::jsonb;
    v_status_distribution JSONB := '[]'::jsonb;
    v_top_suppliers JSONB := '[]'::jsonb;
BEGIN
    -- Unfiltered Overall Tenant PO Metrics
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE status = 'Delivered'),
        COUNT(*) FILTER (WHERE status = 'Pending'),
        COUNT(*) FILTER (WHERE status = 'Cancelled'),
        COALESCE(SUM(total_amount), 0.0)
    INTO 
        v_total_pos,
        v_completed_pos,
        v_pending_pos,
        v_cancelled_pos,
        v_total_spend
    FROM public.inventory_purchase_orders
    WHERE school_id = p_school_id;

    -- Filtered matching count
    SELECT COUNT(*) INTO v_total_records
    FROM public.inventory_purchase_orders po
    WHERE po.school_id = p_school_id
      AND (p_search IS NULL OR p_search = '' OR po.po_number ILIKE '%' || p_search || '%' OR po.supplier_name ILIKE '%' || p_search || '%')
      AND (p_status IS NULL OR p_status = '' OR p_status = 'All Status' OR po.status ILIKE p_status)
      AND (p_supplier IS NULL OR p_supplier = '' OR p_supplier = 'All Suppliers' OR po.supplier_name ILIKE p_supplier)
      AND (p_start_date IS NULL OR po.order_date >= p_start_date)
      AND (p_end_date IS NULL OR po.order_date <= p_end_date);

    -- Paginated Rows
    SELECT COALESCE(jsonb_agg(sub.po), '[]'::jsonb)
    INTO v_pos
    FROM (
        SELECT jsonb_build_object(
            'id', po.id,
            'po_id', po.id,
            'po_number', po.po_number,
            'date', TO_CHAR(po.order_date, 'DD Mon YYYY'),
            'order_date_raw', po.order_date::TEXT,
            'supplier', po.supplier_name,
            'supplier_name', po.supplier_name,
            'supplier_id', po.supplier_id,
            'supplier_gstin', COALESCE(po.supplier_gstin, 'N/A'),
            'store_id', po.store_id,
            'department', COALESCE(po.department, 'Administration'),
            'shipping_address', COALESCE(po.shipping_address, 'Main Campus Store'),
            'items_count', po.total_items,
            'items_text', po.total_items::TEXT || ' Items',
            'subtotal', COALESCE(po.subtotal, po.total_amount),
            'tax_amount', COALESCE(po.tax_amount, 0.0),
            'shipping_amount', COALESCE(po.shipping_amount, 0.0),
            'total_amount', po.total_amount,
            'status', po.status,
            'delivery_date', CASE WHEN po.delivery_date IS NOT NULL THEN TO_CHAR(po.delivery_date, 'DD Mon YYYY') ELSE 'N/A' END,
            'delivery_date_raw', po.delivery_date::TEXT,
            'payment_terms', COALESCE(po.payment_terms, 'Net 30 Days'),
            'notes', po.notes,
            'terms_conditions', po.terms_conditions,
            'created_at', po.created_at,
            'created_at_raw', po.created_at::TEXT,
            'items', COALESCE((
                SELECT jsonb_agg(jsonb_build_object(
                    'id', poi.id,
                    'po_item_id', poi.id,
                    'item_id', poi.item_id,
                    'item_name', poi.item_name,
                    'sku', poi.sku,
                    'quantity', poi.quantity_ordered,
                    'quantity_ordered', poi.quantity_ordered,
                    'received_quantity', poi.quantity_received,
                    'quantity_received', poi.quantity_received,
                    'unit', COALESCE(poi.unit, 'Pcs'),
                    'unit_price', poi.unit_price,
                    'tax_rate', COALESCE(poi.tax_rate, 18.0),
                    'total_price', poi.line_total,
                    'line_total', poi.line_total
                ))
                FROM public.inventory_purchase_order_items poi
                WHERE poi.po_id = po.id
            ), '[]'::jsonb)
        ) AS po
        FROM public.inventory_purchase_orders po
        WHERE po.school_id = p_school_id
          AND (p_search IS NULL OR p_search = '' OR po.po_number ILIKE '%' || p_search || '%' OR po.supplier_name ILIKE '%' || p_search || '%')
          AND (p_status IS NULL OR p_status = '' OR p_status = 'All Status' OR po.status ILIKE p_status)
          AND (p_supplier IS NULL OR p_supplier = '' OR p_supplier = 'All Suppliers' OR po.supplier_name ILIKE p_supplier)
          AND (p_start_date IS NULL OR po.order_date >= p_start_date)
          AND (p_end_date IS NULL OR po.order_date <= p_end_date)
        ORDER BY
            CASE WHEN LOWER(COALESCE(p_sort_by, '')) = 'po_number' AND LOWER(COALESCE(p_sort_order, 'asc')) = 'asc' THEN po.po_number END ASC,
            CASE WHEN LOWER(COALESCE(p_sort_by, '')) = 'po_number' AND LOWER(COALESCE(p_sort_order, 'desc')) = 'desc' THEN po.po_number END DESC,
            CASE WHEN (p_sort_by IS NULL OR p_sort_by = '' OR LOWER(p_sort_by) IN ('order_date', 'date')) AND LOWER(COALESCE(p_sort_order, 'desc')) = 'asc' THEN po.order_date END ASC,
            CASE WHEN (p_sort_by IS NULL OR p_sort_by = '' OR LOWER(p_sort_by) IN ('order_date', 'date')) AND LOWER(COALESCE(p_sort_order, 'desc')) = 'desc' THEN po.order_date END DESC,
            CASE WHEN LOWER(COALESCE(p_sort_by, '')) IN ('supplier', 'supplier_name') AND LOWER(COALESCE(p_sort_order, 'asc')) = 'asc' THEN po.supplier_name END ASC,
            CASE WHEN LOWER(COALESCE(p_sort_by, '')) IN ('supplier', 'supplier_name') AND LOWER(COALESCE(p_sort_order, 'desc')) = 'desc' THEN po.supplier_name END DESC,
            CASE WHEN LOWER(COALESCE(p_sort_by, '')) IN ('items', 'total_items') AND LOWER(COALESCE(p_sort_order, 'asc')) = 'asc' THEN po.total_items END ASC,
            CASE WHEN LOWER(COALESCE(p_sort_by, '')) IN ('items', 'total_items') AND LOWER(COALESCE(p_sort_order, 'desc')) = 'desc' THEN po.total_items END DESC,
            CASE WHEN LOWER(COALESCE(p_sort_by, '')) IN ('total_amount', 'amount') AND LOWER(COALESCE(p_sort_order, 'asc')) = 'asc' THEN po.total_amount END ASC,
            CASE WHEN LOWER(COALESCE(p_sort_by, '')) IN ('total_amount', 'amount') AND LOWER(COALESCE(p_sort_order, 'desc')) = 'desc' THEN po.total_amount END DESC,
            CASE WHEN LOWER(COALESCE(p_sort_by, '')) = 'status' AND LOWER(COALESCE(p_sort_order, 'asc')) = 'asc' THEN po.status END ASC,
            CASE WHEN LOWER(COALESCE(p_sort_by, '')) = 'status' AND LOWER(COALESCE(p_sort_order, 'desc')) = 'desc' THEN po.status END DESC,
            CASE WHEN LOWER(COALESCE(p_sort_by, '')) IN ('delivery_date', 'expected_delivery') AND LOWER(COALESCE(p_sort_order, 'asc')) = 'asc' THEN po.delivery_date END ASC,
            CASE WHEN LOWER(COALESCE(p_sort_by, '')) IN ('delivery_date', 'expected_delivery') AND LOWER(COALESCE(p_sort_order, 'desc')) = 'desc' THEN po.delivery_date END DESC,
            po.created_at DESC
        LIMIT p_page_size OFFSET v_offset
    ) sub;

    -- Continuous 6-Month Rolling Purchase Trend
    SELECT COALESCE(jsonb_agg(sub.trend), '[]'::jsonb)
    INTO v_purchase_trend
    FROM (
        WITH months_series AS (
            SELECT 
                DATE_TRUNC('month', d) AS m_date,
                TO_CHAR(d, 'Mon') AS month_name
            FROM generate_series(
                DATE_TRUNC('month', CURRENT_DATE - INTERVAL '5 months'),
                DATE_TRUNC('month', CURRENT_DATE),
                INTERVAL '1 month'
            ) d
        ),
        m_purchases AS (
            SELECT 
                DATE_TRUNC('month', order_date) AS m_date,
                COALESCE(SUM(total_amount), 0.0) AS val,
                COUNT(*) AS cnt
            FROM public.inventory_purchase_orders
            WHERE school_id = p_school_id
            GROUP BY 1
        )
        SELECT jsonb_build_object(
            'month', s.month_name,
            'value', COALESCE(p.val, 0.0),
            'order_count', COALESCE(p.cnt, 0)
        ) AS trend
        FROM months_series s
        LEFT JOIN m_purchases p ON s.m_date = p.m_date
        ORDER BY s.m_date ASC
    ) sub;

    -- Status Distribution
    SELECT COALESCE(jsonb_agg(sub.stat), '[]'::jsonb)
    INTO v_status_distribution
    FROM (
        SELECT jsonb_build_object(
            'status', status,
            'count', COUNT(*),
            'total_amount', COALESCE(SUM(total_amount), 0.0)
        ) AS stat
        FROM public.inventory_purchase_orders
        WHERE school_id = p_school_id
        GROUP BY status
        ORDER BY COUNT(*) DESC
    ) sub;

    -- Top Suppliers
    SELECT COALESCE(jsonb_agg(sub.supp), '[]'::jsonb)
    INTO v_top_suppliers
    FROM (
        SELECT jsonb_build_object(
            'name', supplier_name,
            'order_count', COUNT(*),
            'total_amount', COALESCE(SUM(total_amount), 0.0)
        ) AS supp
        FROM public.inventory_purchase_orders
        WHERE school_id = p_school_id
        GROUP BY supplier_name
        ORDER BY SUM(total_amount) DESC
        LIMIT 5
    ) sub;

    RETURN jsonb_build_object(
        'success', TRUE,
        'page', p_page,
        'page_size', p_page_size,
        'total', v_total_records,
        'total_pages', CEIL(v_total_records::NUMERIC / GREATEST(1, p_page_size)),
        'purchase_orders', v_pos,
        'kpis', jsonb_build_object(
            'total_pos', v_total_pos,
            'completed_pos', v_completed_pos,
            'pending_pos', v_pending_pos,
            'cancelled_pos', v_cancelled_pos,
            'total_spend', v_total_spend
        ),
        'purchase_trend', v_purchase_trend,
        'monthly_trend', v_purchase_trend,
        'status_distribution', v_status_distribution,
        'top_suppliers', v_top_suppliers
    );
END;
$function$;

-- ----------------------------------------------------------------------------
-- 5. Upgrade fn_inventory_get_sales_orders with Continuous 6-Month Rolling Trend
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_inventory_get_sales_orders(
    p_school_id uuid,
    p_search text DEFAULT NULL::text,
    p_status text DEFAULT NULL::text,
    p_customer text DEFAULT NULL::text,
    p_start_date date DEFAULT NULL::date,
    p_end_date date DEFAULT NULL::date,
    p_page integer DEFAULT 1,
    p_page_size integer DEFAULT 10,
    p_sort_by text DEFAULT 'order_date'::text,
    p_sort_order text DEFAULT 'desc'::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_offset INT := (GREATEST(1, p_page) - 1) * GREATEST(1, p_page_size);
    v_total_records INT := 0;
    v_sos JSONB := '[]'::jsonb;
    v_total_orders INT := 0;
    v_completed_orders INT := 0;
    v_pending_orders INT := 0;
    v_processing_orders INT := 0;
    v_cancelled_orders INT := 0;
    v_total_sales_val NUMERIC(14,2) := 0.0;
    v_sales_trend JSONB := '[]'::jsonb;
    v_status_distribution JSONB := '[]'::jsonb;
    v_top_customers JSONB := '[]'::jsonb;
BEGIN
    -- Unfiltered Overall Tenant SO Metrics
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE status = 'Delivered'),
        COUNT(*) FILTER (WHERE status = 'Pending'),
        COUNT(*) FILTER (WHERE status = 'Processing'),
        COUNT(*) FILTER (WHERE status = 'Cancelled'),
        COALESCE(SUM(total_amount), 0.0)
    INTO 
        v_total_orders,
        v_completed_orders,
        v_pending_orders,
        v_processing_orders,
        v_cancelled_orders,
        v_total_sales_val
    FROM public.inventory_sales_orders
    WHERE school_id = p_school_id;

    -- Filtered matching count
    SELECT COUNT(*) INTO v_total_records
    FROM public.inventory_sales_orders so
    WHERE so.school_id = p_school_id
      AND (p_search IS NULL OR p_search = '' OR so.so_number ILIKE '%' || p_search || '%' OR so.customer_name ILIKE '%' || p_search || '%')
      AND (p_status IS NULL OR p_status = '' OR p_status = 'All Status' OR so.status ILIKE p_status)
      AND (p_customer IS NULL OR p_customer = '' OR p_customer = 'All Customers' OR so.customer_name ILIKE p_customer)
      AND (p_start_date IS NULL OR so.order_date >= p_start_date)
      AND (p_end_date IS NULL OR so.order_date <= p_end_date);

    -- Paginated Rows
    SELECT COALESCE(jsonb_agg(sub.so), '[]'::jsonb)
    INTO v_sos
    FROM (
        SELECT jsonb_build_object(
            'id', so.id,
            'so_id', so.id,
            'so_number', so.so_number,
            'date', TO_CHAR(so.order_date, 'DD Mon YYYY'),
            'order_date_raw', so.order_date::TEXT,
            'customer', so.customer_name,
            'customer_name', so.customer_name,
            'customer_id', so.customer_id,
            'customer_type', COALESCE(so.customer_type, 'Student'),
            'customer_gstin', COALESCE(so.customer_gstin, 'N/A'),
            'contact_phone', so.contact_phone,
            'contact_email', so.contact_email,
            'store_id', so.store_id,
            'department', COALESCE(so.department, 'Sales & Distribution'),
            'shipping_address', COALESCE(so.shipping_address, 'Distribution Center'),
            'items_count', so.total_items,
            'items_text', so.total_items::TEXT || ' Items',
            'subtotal', COALESCE(so.subtotal, so.total_amount),
            'tax_amount', COALESCE(so.tax_amount, 0.0),
            'discount_amount', COALESCE(so.discount_amount, 0.0),
            'total_amount', so.total_amount,
            'paid_amount', COALESCE(so.paid_amount, so.total_amount),
            'status', so.status,
            'payment_terms', COALESCE(so.payment_terms, 'Due on Receipt'),
            'delivery_date', CASE WHEN so.delivery_date IS NOT NULL THEN TO_CHAR(so.delivery_date, 'DD Mon YYYY') ELSE 'N/A' END,
            'delivery_date_raw', so.delivery_date::TEXT,
            'notes', so.notes,
            'terms_conditions', so.terms_conditions,
            'created_at', so.created_at,
            'created_at_raw', so.created_at::TEXT,
            'items', COALESCE((
                SELECT jsonb_agg(jsonb_build_object(
                    'id', soi.id,
                    'so_item_id', soi.id,
                    'item_id', soi.item_id,
                    'item_name', soi.item_name,
                    'sku', soi.sku,
                    'quantity', soi.quantity_ordered,
                    'quantity_ordered', soi.quantity_ordered,
                    'delivered_quantity', soi.quantity_fulfilled,
                    'quantity_fulfilled', soi.quantity_fulfilled,
                    'unit', COALESCE(soi.unit, 'Pcs'),
                    'unit_price', soi.unit_price,
                    'tax_rate', COALESCE(soi.tax_rate, 5.0),
                    'total_price', soi.line_total,
                    'line_total', soi.line_total
                ))
                FROM public.inventory_sales_order_items soi
                WHERE soi.so_id = so.id
            ), '[]'::jsonb)
        ) AS so
        FROM public.inventory_sales_orders so
        WHERE so.school_id = p_school_id
          AND (p_search IS NULL OR p_search = '' OR so.so_number ILIKE '%' || p_search || '%' OR so.customer_name ILIKE '%' || p_search || '%')
          AND (p_status IS NULL OR p_status = '' OR p_status = 'All Status' OR so.status ILIKE p_status)
          AND (p_customer IS NULL OR p_customer = '' OR p_customer = 'All Customers' OR so.customer_name ILIKE p_customer)
          AND (p_start_date IS NULL OR so.order_date >= p_start_date)
          AND (p_end_date IS NULL OR so.order_date <= p_end_date)
        ORDER BY
            CASE WHEN LOWER(COALESCE(p_sort_by, '')) = 'so_number' AND LOWER(COALESCE(p_sort_order, 'asc')) = 'asc' THEN so.so_number END ASC,
            CASE WHEN LOWER(COALESCE(p_sort_by, '')) = 'so_number' AND LOWER(COALESCE(p_sort_order, 'desc')) = 'desc' THEN so.so_number END DESC,
            CASE WHEN (p_sort_by IS NULL OR p_sort_by = '' OR LOWER(p_sort_by) IN ('order_date', 'date')) AND LOWER(COALESCE(p_sort_order, 'desc')) = 'asc' THEN so.order_date END ASC,
            CASE WHEN (p_sort_by IS NULL OR p_sort_by = '' OR LOWER(p_sort_by) IN ('order_date', 'date')) AND LOWER(COALESCE(p_sort_order, 'desc')) = 'desc' THEN so.order_date END DESC,
            CASE WHEN LOWER(COALESCE(p_sort_by, '')) IN ('customer', 'customer_name') AND LOWER(COALESCE(p_sort_order, 'asc')) = 'asc' THEN so.customer_name END ASC,
            CASE WHEN LOWER(COALESCE(p_sort_by, '')) IN ('customer', 'customer_name') AND LOWER(COALESCE(p_sort_order, 'desc')) = 'desc' THEN so.customer_name END DESC,
            CASE WHEN LOWER(COALESCE(p_sort_by, '')) IN ('items', 'total_items') AND LOWER(COALESCE(p_sort_order, 'asc')) = 'asc' THEN so.total_items END ASC,
            CASE WHEN LOWER(COALESCE(p_sort_by, '')) IN ('items', 'total_items') AND LOWER(COALESCE(p_sort_order, 'desc')) = 'desc' THEN so.total_items END DESC,
            CASE WHEN LOWER(COALESCE(p_sort_by, '')) IN ('total_amount', 'amount') AND LOWER(COALESCE(p_sort_order, 'asc')) = 'asc' THEN so.total_amount END ASC,
            CASE WHEN LOWER(COALESCE(p_sort_by, '')) IN ('total_amount', 'amount') AND LOWER(COALESCE(p_sort_order, 'desc')) = 'desc' THEN so.total_amount END DESC,
            CASE WHEN LOWER(COALESCE(p_sort_by, '')) = 'status' AND LOWER(COALESCE(p_sort_order, 'asc')) = 'asc' THEN so.status END ASC,
            CASE WHEN LOWER(COALESCE(p_sort_by, '')) = 'status' AND LOWER(COALESCE(p_sort_order, 'desc')) = 'desc' THEN so.status END DESC,
            CASE WHEN LOWER(COALESCE(p_sort_by, '')) IN ('delivery_date', 'expected_delivery') AND LOWER(COALESCE(p_sort_order, 'asc')) = 'asc' THEN so.delivery_date END ASC,
            CASE WHEN LOWER(COALESCE(p_sort_by, '')) IN ('delivery_date', 'expected_delivery') AND LOWER(COALESCE(p_sort_order, 'desc')) = 'desc' THEN so.delivery_date END DESC,
            so.created_at DESC
        LIMIT p_page_size OFFSET v_offset
    ) sub;

    -- Continuous 6-Month Rolling Sales Trend
    SELECT COALESCE(jsonb_agg(sub.trend), '[]'::jsonb)
    INTO v_sales_trend
    FROM (
        WITH months_series AS (
            SELECT 
                DATE_TRUNC('month', d) AS m_date,
                TO_CHAR(d, 'Mon') AS month_name
            FROM generate_series(
                DATE_TRUNC('month', CURRENT_DATE - INTERVAL '5 months'),
                DATE_TRUNC('month', CURRENT_DATE),
                INTERVAL '1 month'
            ) d
        ),
        m_sales AS (
            SELECT 
                DATE_TRUNC('month', order_date) AS m_date,
                COALESCE(SUM(total_amount), 0.0) AS val,
                COUNT(*) AS cnt
            FROM public.inventory_sales_orders
            WHERE school_id = p_school_id
            GROUP BY 1
        )
        SELECT jsonb_build_object(
            'month', s.month_name,
            'value', COALESCE(sl.val, 0.0),
            'order_count', COALESCE(sl.cnt, 0)
        ) AS trend
        FROM months_series s
        LEFT JOIN m_sales sl ON s.m_date = sl.m_date
        ORDER BY s.m_date ASC
    ) sub;

    -- Status Distribution
    SELECT COALESCE(jsonb_agg(sub.stat), '[]'::jsonb)
    INTO v_status_distribution
    FROM (
        SELECT jsonb_build_object(
            'status', status,
            'count', COUNT(*),
            'total_amount', COALESCE(SUM(total_amount), 0.0)
        ) AS stat
        FROM public.inventory_sales_orders
        WHERE school_id = p_school_id
        GROUP BY status
        ORDER BY COUNT(*) DESC
    ) sub;

    -- Top Customers
    SELECT COALESCE(jsonb_agg(sub.cust), '[]'::jsonb)
    INTO v_top_customers
    FROM (
        SELECT jsonb_build_object(
            'name', customer_name,
            'order_count', COUNT(*),
            'total_amount', COALESCE(SUM(total_amount), 0.0)
        ) AS cust
        FROM public.inventory_sales_orders
        WHERE school_id = p_school_id
        GROUP BY customer_name
        ORDER BY SUM(total_amount) DESC
        LIMIT 5
    ) sub;

    RETURN jsonb_build_object(
        'success', TRUE,
        'page', p_page,
        'page_size', p_page_size,
        'total', v_total_records,
        'total_pages', CEIL(v_total_records::NUMERIC / GREATEST(1, p_page_size)),
        'sales_orders', v_sos,
        'kpis', jsonb_build_object(
            'total_orders', v_total_orders,
            'completed_orders', v_completed_orders,
            'pending_orders', v_pending_orders,
            'processing_orders', v_processing_orders,
            'cancelled_orders', v_cancelled_orders,
            'total_sales_value', v_total_sales_val
        ),
        'sales_trend', v_sales_trend,
        'monthly_trend', v_sales_trend,
        'status_distribution', v_status_distribution,
        'top_customers', v_top_customers
    );
END;
$function$;
