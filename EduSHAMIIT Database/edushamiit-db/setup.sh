#!/bin/bash

# EduSHAMIIT Database Setup Script
# ================================
# This script sets up the complete EduSHAMIIT database with all tables,
# functions, stored procedures, RLS policies, and sample data.

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

# Default values
POSTGRES_HOST=${POSTGRES_HOST:-localhost}
POSTGRES_PORT=${POSTGRES_PORT:-5432}
POSTGRES_DB=${POSTGRES_DB:-edushamiit}
POSTGRES_USER=${POSTGRES_USER:-postgres}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-postgres_password_2026}

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         EduSHAMIIT Database Setup                         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to check if Docker is running
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        echo -e "${RED}Error: Docker is not running. Please start Docker first.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Docker is running${NC}"
}

# Function to start Docker containers
start_containers() {
    echo -e "\n${YELLOW}Starting Docker containers...${NC}"
    docker-compose up -d
    echo -e "${GREEN}✓ Docker containers started${NC}"
    
    echo -e "\n${YELLOW}Waiting for PostgreSQL to be ready...${NC}"
    until docker exec edushamiit-postgres pg_isready -U $POSTGRES_USER > /dev/null 2>&1; do
        sleep 2
    done
    echo -e "${GREEN}✓ PostgreSQL is ready${NC}"
}

# Function to run SQL migrations
run_migrations() {
    echo -e "\n${YELLOW}Running database migrations...${NC}"
    
    # Get list of migration files sorted numerically
    MIGRATION_FILES=$(ls -1 migrations/*.sql 2>/dev/null | sort -V)
    
    if [ -z "$MIGRATION_FILES" ]; then
        echo -e "${RED}Error: No migration files found in migrations/ directory${NC}"
        exit 1
    fi
    
    # Counter for progress
    TOTAL=$(echo "$MIGRATION_FILES" | wc -l)
    CURRENT=0
    
    for migration in $MIGRATION_FILES; do
        CURRENT=$((CURRENT + 1))
        FILENAME=$(basename "$migration")
        echo -e "${BLUE}[$CURRENT/$TOTAL]${NC} Running ${FILENAME}..."
        
        # Run the migration
        docker exec -i edushamiit-postgres psql -U $POSTGRES_USER -d $POSTGRES_DB < "$migration" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}  ✓ ${FILENAME} completed${NC}"
        else
            echo -e "${YELLOW}  ⚠ ${FILENAME} had warnings (may be expected for CREATE IF NOT EXISTS)${NC}"
        fi
    done
    
    echo -e "\n${GREEN}✓ All migrations completed${NC}"
}

# Function to verify database setup
verify_setup() {
    echo -e "\n${YELLOW}Verifying database setup...${NC}"
    
    # Check tables count
    TABLE_COUNT=$(docker exec edushamiit-postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | tr -d ' ')
    echo -e "${GREEN}✓ Tables created: ${TABLE_COUNT}${NC}"
    
    # Check functions count
    FUNCTION_COUNT=$(docker exec edushamiit-postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -t -c "SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema = 'public';" 2>/dev/null | tr -d ' ')
    echo -e "${GREEN}✓ Functions created: ${FUNCTION_COUNT}${NC}"
    
    # Check sample data
    SCHOOL_COUNT=$(docker exec edushamiit-postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -t -c "SELECT COUNT(*) FROM schools;" 2>/dev/null | tr -d ' ')
    echo -e "${GREEN}✓ Schools in database: ${SCHOOL_COUNT}${NC}"
    
    STUDENT_COUNT=$(docker exec edushamiit-postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -t -c "SELECT COUNT(*) FROM profiles WHERE role = 'student';" 2>/dev/null | tr -d ' ')
    echo -e "${GREEN}✓ Students in database: ${STUDENT_COUNT}${NC}"
}

# Function to display connection info
show_connection_info() {
    echo -e "\n${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         Database Setup Complete!                          ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}Connection Information:${NC}"
    echo -e "  PostgreSQL: ${YELLOW}postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}${NC}"
    echo -e "  Redis:      ${YELLOW}redis://:${REDIS_PASSWORD}@localhost:${REDIS_PORT:-6379}${NC}"
    echo -e "  RabbitMQ:   ${YELLOW}amqp://${RABBITMQ_USER:-guest}:${RABBITMQ_PASSWORD:-guest}@localhost:${RABBITMQ_PORT:-5672}${NC}"
    echo ""
    echo -e "${GREEN}Management UIs:${NC}"
    echo -e "  RabbitMQ:   ${YELLOW}http://localhost:15672${NC}"
    echo ""
    echo -e "${GREEN}Useful Commands:${NC}"
    echo -e "  Connect to DB:  ${YELLOW}docker exec -it edushamiit-postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DB}${NC}"
    echo -e "  View logs:      ${YELLOW}docker-compose logs -f${NC}"
    echo -e "  Stop services:  ${YELLOW}docker-compose down${NC}"
    echo -e "  Reset database: ${YELLOW}docker-compose down -v && ./setup.sh${NC}"
    echo ""
}

# Main execution
main() {
    check_docker
    start_containers
    run_migrations
    verify_setup
    show_connection_info
}

# Run main function
main