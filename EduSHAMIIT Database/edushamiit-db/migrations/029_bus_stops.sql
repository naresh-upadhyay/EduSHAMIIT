CREATE TABLE IF NOT EXISTS bus_stops (  
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),  
  school_id UUID REFERENCES schools(id),  
  route_id UUID REFERENCES bus_routes(id) ON DELETE CASCADE,  
  stop_name TEXT NOT NULL,  
  latitude DECIMAL(10,8) NOT NULL,  
  longitude DECIMAL(11,8) NOT NULL,  
  stop_order INT NOT NULL,  
  estimated_arrival TIME,  
  is_student_stop BOOLEAN DEFAULT FALSE  
); 
