import logging
from sqlalchemy import create_engine, text
from sqlalchemy.orm import declarative_base, sessionmaker
from app.config import settings

logger = logging.getLogger("cortex.database")
logging.basicConfig(level=logging.INFO)

Base = declarative_base()

def get_engine():
    mysql_url = settings.DATABASE_URL

    engine = create_engine(
        mysql_url,
        pool_recycle=3600,
        pool_pre_ping=True,
        connect_args={"connect_timeout": 3}
    )

    # Test MySQL connection
    with engine.connect() as conn:
        conn.execute(text("SELECT 1"))

    logger.info(
        f"Connected to MySQL database at "
        f"{settings.MYSQL_HOST}:{settings.MYSQL_PORT}/"
        f"{settings.MYSQL_DATABASE}"
    )

    return engine

engine = get_engine()
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
