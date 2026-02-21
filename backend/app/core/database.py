from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
# Import the central settings
from app.core.config import settings 

# We pull the DATABASE_URL dynamically from your .env via the settings object
engine = create_engine(
    settings.DATABASE_URL, 
    echo=True
)

# SessionLocal is our session factory
SessionLocal = sessionmaker(
    bind=engine, 
    autoflush=False, 
    autocommit=False
)

# Base class for our database models
Base = declarative_base()

# Dependency to get the DB session in your routes
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()