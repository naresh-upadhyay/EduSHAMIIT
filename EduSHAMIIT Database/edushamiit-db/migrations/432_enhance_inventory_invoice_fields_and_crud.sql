-- ============================================================================
-- Migration 432: Enhance Inventory Purchase & Sales Orders with Invoice Fields
-- Adds GSTIN, Shipping Address, Payment Terms, Terms & Conditions to Orders,
-- and upgrades fn_inventory_get_purchase_orders and fn_inventory_get_sales_orders
-- to return comprehensive billing, counterparty, tax and dispatch attributes.
-- ============================================================================

-- 1. Add invoice columns to Purchase Orders
ALTER TABLE public.inventory_purchase_orders 
    ADD COLUMN IF NOT EXISTS supplier_gstin VARCHAR(50) DEFAULT '29AAACG1234F1Z8',
    ADD COLUMN IF NOT EXISTS shipping_address TEXT DEFAULT 'Main Campus Store, Greenwood High',
    ADD COLUMN IF NOT EXISTS terms_conditions TEXT DEFAULT '1. Goods must match the specifications outlined in this Purchase Order.
2. Materials subject to verification and quality control inspection at receiving bay.
3. Deliveries must include the official PO Number on all shipping labels and delivery challans.
4. Invoices must be submitted with accompanying Goods Received Note (GRN).';

-- Backfill existing rows if NULL
UPDATE public.inventory_purchase_orders
SET 
    supplier_gstin = COALESCE(supplier_gstin, '29AAACG1234F1Z8'),
    shipping_address = COALESCE(shipping_address, 'Main Campus Store, Greenwood High'),
    payment_terms = COALESCE(payment_terms, 'Net 30 Days'),
    terms_conditions = COALESCE(terms_conditions, '1. Goods must match the specifications outlined in this Purchase Order.
2. Materials subject to verification and quality control inspection at receiving bay.
3. Deliveries must include the official PO Number on all shipping labels and delivery challans.
4. Invoices must be submitted with accompanying Goods Received Note (GRN).');

-- 2. Add invoice columns to Sales Orders
ALTER TABLE public.inventory_sales_orders 
    ADD COLUMN IF NOT EXISTS customer_gstin VARCHAR(50) DEFAULT '29AAACG1234F1Z8',
    ADD COLUMN IF NOT EXISTS shipping_address TEXT DEFAULT 'Bangalore Center Distribution',
    ADD COLUMN IF NOT EXISTS payment_terms VARCHAR(100) DEFAULT 'Due on Receipt',
    ADD COLUMN IF NOT EXISTS terms_conditions TEXT DEFAULT '1. Certified that the particulars given above are true and correct.
2. Subject to Bangalore Jurisdiction.
3. Any discrepancies must be brought to notice within 7 days of delivery.
4. This is a computer generated tax invoice.';

-- Backfill existing rows if NULL
UPDATE public.inventory_sales_orders
SET 
    customer_gstin = COALESCE(customer_gstin, '29AAACG1234F1Z8'),
    shipping_address = COALESCE(shipping_address, 'Bangalore Center Distribution'),
    payment_terms = COALESCE(payment_terms, 'Due on Receipt'),
    terms_conditions = COALESCE(terms_conditions, '1. Certified that the particulars given above are true and correct.
2. Subject to Bangalore Jurisdiction.
3. Any discrepancies must be brought to notice within 7 days of delivery.
4. This is a computer generated tax invoice.');

-- 3. Upgrade fn_inventory_get_purchase_orders to return full invoice attributes
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

    SELECT COUNT(*) INTO v_total_records
    FROM public.inventory_purchase_orders po
    WHERE po.school_id = p_school_id
      AND (p_search IS NULL OR p_search = '' OR po.po_number ILIKE '%' || p_search || '%' OR po.supplier_name ILIKE '%' || p_search || '%')
      AND (p_status IS NULL OR p_status = '' OR p_status = 'All Status' OR po.status ILIKE p_status)
      AND (p_supplier IS NULL OR p_supplier = '' OR p_supplier = 'All Suppliers' OR po.supplier_name ILIKE p_supplier)
      AND (p_start_date IS NULL OR po.order_date >= p_start_date)
      AND (p_end_date IS NULL OR po.order_date <= p_end_date);

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
            'supplier_gstin', COALESCE(po.supplier_gstin, '29AAACG1234F1Z8'),
            'store_id', po.store_id,
            'department', COALESCE(po.department, 'Administration'),
            'shipping_address', COALESCE(po.shipping_address, 'Main Campus Store, Greenwood High'),
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
            'terms_conditions', COALESCE(po.terms_conditions, '1. Goods must match the specifications outlined in this Purchase Order.
2. Materials subject to verification and quality control inspection at receiving bay.
3. Deliveries must include the official PO Number on all shipping labels and delivery challans.
4. Invoices must be submitted with accompanying Goods Received Note (GRN).'),
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

    -- Dynamic Purchase Trend by Month from real POs
    SELECT COALESCE(jsonb_agg(sub.trend), '[]'::jsonb)
    INTO v_purchase_trend
    FROM (
        SELECT jsonb_build_object(
            'month', TO_CHAR(order_date, 'Mon'),
            'value', COALESCE(SUM(total_amount), 0.0),
            'order_count', COUNT(*)
        ) AS trend
        FROM public.inventory_purchase_orders
        WHERE school_id = p_school_id
        GROUP BY DATE_TRUNC('month', order_date), TO_CHAR(order_date, 'Mon')
        ORDER BY DATE_TRUNC('month', order_date) ASC
    ) sub;

    -- Dynamic Status Distribution
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

    -- Dynamic Top Suppliers
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
        'status_distribution', v_status_distribution,
        'top_suppliers', v_top_suppliers
    );
END;
$function$;

-- 4. Upgrade fn_inventory_get_sales_orders to return full invoice attributes
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
    v_total_sales_val NUMERIC(14,2) := 0.0;
    v_sales_trend JSONB := '[]'::jsonb;
    v_status_distribution JSONB := '[]'::jsonb;
    v_top_customers JSONB := '[]'::jsonb;
BEGIN
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE status = 'Delivered'),
        COUNT(*) FILTER (WHERE status = 'Pending'),
        COUNT(*) FILTER (WHERE status = 'Processing'),
        COALESCE(SUM(total_amount), 0.0)
    INTO 
        v_total_orders,
        v_completed_orders,
        v_pending_orders,
        v_processing_orders,
        v_total_sales_val
    FROM public.inventory_sales_orders
    WHERE school_id = p_school_id;

    SELECT COUNT(*) INTO v_total_records
    FROM public.inventory_sales_orders so
    WHERE so.school_id = p_school_id
      AND (p_search IS NULL OR p_search = '' OR so.so_number ILIKE '%' || p_search || '%' OR so.customer_name ILIKE '%' || p_search || '%')
      AND (p_status IS NULL OR p_status = '' OR p_status = 'All Status' OR so.status ILIKE p_status)
      AND (p_customer IS NULL OR p_customer = '' OR p_customer = 'All Customers' OR so.customer_name ILIKE p_customer)
      AND (p_start_date IS NULL OR so.order_date >= p_start_date)
      AND (p_end_date IS NULL OR so.order_date <= p_end_date);

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
            'customer_gstin', COALESCE(so.customer_gstin, '29AAACG1234F1Z8'),
            'contact_phone', so.contact_phone,
            'contact_email', so.contact_email,
            'store_id', so.store_id,
            'department', COALESCE(so.department, 'Sales & Distribution'),
            'shipping_address', COALESCE(so.shipping_address, 'Bangalore Center Distribution'),
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
            'terms_conditions', COALESCE(so.terms_conditions, '1. Certified that the particulars given above are true and correct.
2. Subject to Bangalore Jurisdiction.
3. Any discrepancies must be brought to notice within 7 days of delivery.
4. This is a computer generated tax invoice.'),
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

    -- Dynamic Sales Trend by Month from real SOs
    SELECT COALESCE(jsonb_agg(sub.trend), '[]'::jsonb)
    INTO v_sales_trend
    FROM (
        SELECT jsonb_build_object(
            'month', TO_CHAR(order_date, 'Mon'),
            'value', COALESCE(SUM(total_amount), 0.0),
            'order_count', COUNT(*)
        ) AS trend
        FROM public.inventory_sales_orders
        WHERE school_id = p_school_id
        GROUP BY DATE_TRUNC('month', order_date), TO_CHAR(order_date, 'Mon')
        ORDER BY DATE_TRUNC('month', order_date) ASC
    ) sub;

    -- Dynamic Status Distribution
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

    -- Dynamic Top Customers
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
            'total_sales_value', v_total_sales_val
        ),
        'sales_trend', v_sales_trend,
        'status_distribution', v_status_distribution,
        'top_customers', v_top_customers
    );
END;
$function$;
