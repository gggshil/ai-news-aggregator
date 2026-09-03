from datetime import datetime
from sqlalchemy import Column, String, DateTime, Text, Boolean, ForeignKey
from sqlalchemy.orm import declarative_base

Base = declarative_base()


class YouTubeVideo(Base):
    __tablename__ = "youtube_videos"

    video_id = Column(String, primary_key=True)
    title = Column(String, nullable=False)
    url = Column(String, nullable=False)
    channel_id = Column(String, nullable=False)
    published_at = Column(DateTime, nullable=False)
    description = Column(Text)
    transcript = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)


class OpenAIArticle(Base):
    __tablename__ = "openai_articles"

    guid = Column(String, primary_key=True)
    title = Column(String, nullable=False)
    url = Column(String, nullable=False)
    description = Column(Text)
    published_at = Column(DateTime, nullable=False)
    category = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)


class AnthropicArticle(Base):
    __tablename__ = "anthropic_articles"

    guid = Column(String, primary_key=True)
    title = Column(String, nullable=False)
    url = Column(String, nullable=False)
    description = Column(Text)
    published_at = Column(DateTime, nullable=False)
    category = Column(String, nullable=True)
    markdown = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)


class GeminiArticle(Base):
    __tablename__ = "gemini_articles"

    guid = Column(String, primary_key=True)
    title = Column(String, nullable=False)
    url = Column(String, nullable=False)
    description = Column(Text)
    published_at = Column(DateTime, nullable=False)
    category = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)


class XaiArticle(Base):
    __tablename__ = "xai_articles"

    guid = Column(String, primary_key=True)
    title = Column(String, nullable=False)
    url = Column(String, nullable=False)
    description = Column(Text)
    published_at = Column(DateTime, nullable=False)
    category = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)


class DeepseekArticle(Base):
    __tablename__ = "deepseek_articles"

    guid = Column(String, primary_key=True)
    title = Column(String, nullable=False)
    url = Column(String, nullable=False)
    description = Column(Text)
    published_at = Column(DateTime, nullable=False)
    category = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)


class Digest(Base):
    __tablename__ = "digests"

    id = Column(String, primary_key=True)
    article_type = Column(String, nullable=False)
    article_id = Column(String, nullable=False)
    url = Column(String, nullable=False)
    title = Column(String, nullable=False)
    summary = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    sent_at = Column(DateTime, nullable=True)


class Subscriber(Base):
    __tablename__ = "subscribers"

    id = Column(String, primary_key=True)
    email = Column(String, unique=True, nullable=False, index=True)
    password_hash = Column(String, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    id = Column(String, primary_key=True)  # JTI (UUID)
    subscriber_id = Column(String, ForeignKey("subscribers.id", ondelete="CASCADE"), nullable=False, index=True)
    token_hash = Column(String, nullable=False, index=True)
    expires_at = Column(DateTime, nullable=False, index=True)
    revoked = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    user_agent = Column(String, nullable=True)
    ip_address = Column(String, nullable=True)


