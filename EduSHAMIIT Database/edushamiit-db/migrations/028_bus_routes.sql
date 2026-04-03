CREATE TABLE IF NOT EXISTS bus_routes (  
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),  
  school_id UUID REFERENCES schools(id),  
  route_name TEXT NOT NULL,  
  bus_number TEXT,  
  driver_name TEXT,  
  driver_phone TEXT,  
  total_capacity INT DEFAULT 40,  
  current_passengers INT DEFAULT 0,  
  status TEXT DEFAULT 'active'  
); 
