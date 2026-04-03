CREATE TABLE IF NOT EXISTS bus_locations (  
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),  
  school_id UUID REFERENCES schools(id),  
  route_id UUID REFERENCES bus_routes(id) ON DELETE CASCADE,  
  latitude DECIMAL(10,8) NOT NULL,  
  longitude DECIMAL(11,8) NOT NULL,  
  speed DECIMAL(5,2),  
  heading DECIMAL(5,2),  
  eta_minutes INT,  
  recorded_at TIMESTAMPTZ DEFAULT NOW()  
); 
