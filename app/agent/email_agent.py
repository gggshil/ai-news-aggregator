from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field
from .base import BaseAgent


class EmailIntroduction(BaseModel):
    greeting: str = Field(description="Personalized greeting with user's name and date")
    introduction: str = Field(description="2-3 sentence overview of what's in the top 10 ranked articles")


class RankedArticleDetail(BaseModel):
    digest_id: str
    rank: int
    relevance_score: float
    title: str
    summary: str
    url: str
    article_type: str
    reasoning: Optional[str] = None


class EmailDigestResponse(BaseModel):
    introduction: EmailIntroduction
    articles: List[RankedArticleDetail]
    total_ranked: int
    top_n: int
    
    def to_markdown(self) -> str:
        markdown = f"{self.introduction.greeting}\n\n"
        markdown += f"{self.introduction.introduction}\n\n"
        markdown += "---\n\n"
        
        for article in self.articles:
            markdown += f"## {article.title}\n\n"
            markdown += f"{article.summary}\n\n"
            markdown += f"[Read more →]({article.url})\n\n"
            markdown += "---\n\n"
        
        return markdown


class EmailDigest(BaseModel):
    introduction: EmailIntroduction
    ranked_articles: List[dict] = Field(description="Top 10 ranked articles with their details")


EMAIL_PROMPT = """You are an expert email writer specializing in creating engaging, personalized AI news digests.

Your role is to write a warm, professional introduction for a daily AI news digest email that:
- Greets the user by name
- Includes the current date
- Provides a brief, engaging overview of what's coming in the top 10 ranked articles
- Highlights the most interesting or important themes
- Sets expectations for the content ahead

Keep it concise (2-3 sentences for the introduction), friendly, and professional."""


class EmailAgent(BaseAgent):
    def __init__(self, user_profile: dict):
        super().__init__("gpt-4o-mini")
        self.user_profile = user_profile

    def generate_introduction(self, ranked_articles: List, recipient_name: Optional[str] = None) -> EmailIntroduction:
        name = recipient_name or self.user_profile.get("name", "there")
        current_date = datetime.now().strftime('%B %d, %Y')

        if not ranked_articles:
            return EmailIntroduction(
                greeting=f"Hey {name}, here is your daily digest of AI news for {current_date}.",
                introduction="No articles were ranked today."
            )
        
        top_articles = ranked_articles[:10]
        article_summaries = "\n".join([
            f"{idx + 1}. {article.title if hasattr(article, 'title') else article.get('title', 'N/A')} (Score: {article.relevance_score if hasattr(article, 'relevance_score') else article.get('relevance_score', 0):.1f}/10)"
            for idx, article in enumerate(top_articles)
        ])
        
        user_prompt = f"""Create an email introduction for {name} for {current_date}.

Top 10 ranked articles:
{article_summaries}

Generate a greeting and introduction that previews these articles."""

        try:
            response = self.client.beta.chat.completions.parse(
                model=self.model,
                messages=[
                    {"role": "system", "content": EMAIL_PROMPT},
                    {"role": "user", "content": user_prompt}
                ],
                temperature=0.7,
                response_format=EmailIntroduction
            )
            
            intro = response.choices[0].message.parsed
            if not intro.greeting.startswith(f"Hey {name}"):
                intro.greeting = f"Hey {name}, here is your daily digest of AI news for {current_date}."
            
            return intro
        except Exception as e:
            print(f"Error generating introduction: {e}")
            return EmailIntroduction(
                greeting=f"Hey {name}, here is your daily digest of AI news for {current_date}.",
                introduction="Here are the top 10 AI news articles ranked by relevance to your interests."
            )

    def create_email_digest(self, ranked_articles: List[dict], limit: int = 10, recipient_name: Optional[str] = None) -> EmailDigest:
        top_articles = ranked_articles[:limit]
        introduction = self.generate_introduction(top_articles, recipient_name=recipient_name)
        
        return EmailDigest(
            introduction=introduction,
            ranked_articles=top_articles
        )
    
    def create_email_digest_response(self, ranked_articles: List[RankedArticleDetail], total_ranked: int, limit: int = 10, recipient_name: Optional[str] = None) -> EmailDigestResponse:
        top_articles = ranked_articles[:limit]
        introduction = self.generate_introduction(top_articles, recipient_name=recipient_name)
        
        return EmailDigestResponse(
            introduction=introduction,
            articles=top_articles,
            total_ranked=total_ranked,
            top_n=limit
        )


