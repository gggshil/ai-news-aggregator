
import os
from sqlalchemy import create_engine
from dotenv import load_dotenv

load_dotenv()


def get_environment() -> str:
    return os.getenv("ENVIRONMENT", "LOCAL").upper()


def get_database_url() -> str:
    # Support both DATABASE_URL and Vercel's POSTGRES_URL
    database_url = os.getenv("DATABASE_URL") or os.getenv("POSTGRES_URL")
    if database_url:
        if database_url.startswith("postgres://"):
            database_url = database_url.replace("postgres://", "postgresql://", 1)
        return database_url

    postgres_host = os.getenv("POSTGRES_HOST")
    if not postgres_host:
        return "sqlite:///data/ai_news.db"

    user = os.getenv("POSTGRES_USER", "postgres")
    password = os.getenv("POSTGRES_PASSWORD", "postgres")
    host = postgres_host
    port = os.getenv("POSTGRES_PORT", "5432")
    # Support both POSTGRES_DB and Vercel's POSTGRES_DATABASE
    db = os.getenv("POSTGRES_DB") or os.getenv("POSTGRES_DATABASE", "ai_news_aggregator")
    return f"postgresql://{user}:{password}@{host}:{port}/{db}"


def get_database_info() -> dict:
    url = get_database_url()
    env = get_environment()

    if (
        "render.com" in url.lower()
        or "amazonaws.com" in url.lower()
        or env == "PRODUCTION"
    ):
        env_type = "PRODUCTION"
    else:
        env_type = "LOCAL"

    masked_url = url
    if "@" in url:
        parts = url.split("@")
        if len(parts) == 2:
            masked_url = f"{parts[0].split('://')[0]}://***@{parts[1]}"

    return {
        "environment": env_type,
        "url_masked": masked_url,
        "host": url.split("@")[-1].split("/")[0] if "@" in url else "localhost",
    }


from sqlalchemy.orm import sessionmaker, scoped_session

# Configure DB Engine and automatically create SQLite directories if needed
db_url = get_database_url()
if db_url.startswith("sqlite:///"):
    # In Vercel (read‑only) environment we cannot write to SQLite files.
    # If the environment is not explicitly LOCAL, raise an informative error.
    if get_environment() != "LOCAL":
        raise RuntimeError(
            "SQLite database not supported on Vercel. "
            "Ensure Postgres environment variables are set."
        )
    db_path = db_url.replace("sqlite:///", "")
    db_dir = os.path.dirname(db_path)
    if db_dir and not os.path.exists(db_dir):
        try:
            os.makedirs(db_dir, exist_ok=True)
        except OSError as e:
            print(f"Warning: Could not create SQLite directory ({e}). This is expected on read‑only environments like Vercel.")

connect_args = {"check_same_thread": False} if db_url.startswith("sqlite") else {}
engine = create_engine(db_url, connect_args=connect_args)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
db_session = scoped_session(SessionLocal)


def get_session():
    return db_session()
