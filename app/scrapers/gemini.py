from typing import List
from .base import BaseScraper, Article


class GeminiArticle(Article):
    pass


class GeminiScraper(BaseScraper):
    @property
    def rss_urls(self) -> List[str]:
        return ["https://blog.google/technology/ai/rss/"]

    def get_articles(self, hours: int = 24) -> List[GeminiArticle]:
        return [GeminiArticle(**article.model_dump()) for article in super().get_articles(hours)]


if __name__ == "__main__":
    scraper = GeminiScraper()
    articles = scraper.get_articles(hours=168)
    for a in articles:
        print(f"Title: {a.title}\nURL: {a.url}\nDate: {a.published_at}\n")
