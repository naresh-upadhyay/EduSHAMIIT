SELECT * FROM public.student_trip_logs;
SELECT * FROM public.vehicle_trips;
select * from public.trip_stop_logs;
select * from public.transport_routes;
select * from public.transport_route_stops;



SELECT * FROM public.vehicle_trips order by scheduled_start asc;

select count(1) FROM public.vehicle_trips ;