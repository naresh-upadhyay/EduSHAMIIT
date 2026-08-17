SELECT * FROM public.calendar_resources;
select * FROM public.live_class_resources;
select * FROM public.resource_bookings;
select * FROM public.schedule_recurrence;
select * FROM public.schedules WHERE start_time < '2026-08-10 10:00:00+00';

select * FROM public.app_roles;


SELECT *  FROM public.schedules 
JOIN public.calendars cal ON calendar_id=cal.id
where cal.name LIKE '%FLEET%' or  cal.name LIKE '%monk%' 