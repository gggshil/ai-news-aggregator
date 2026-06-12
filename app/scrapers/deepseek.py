from typing import List
from .base import BaseScraper, Article


class DeepseekArticle(Article):
    pass


class DeepseekScraper(BaseScraper):
    @property
    def rss_urls(self) -> List[str]:
        return [
            "https://github.com/deepseek-ai/DeepSeek-V3/releases.atom",
            "https://github.com/deepseek-ai/DeepSeek-R1/releases.atom",
            "https://github.com/deepseek-ai/DeepSeek-Coder/releases.atom"
        ]

    def get_articles(self, hours: int = 24) -> List[DeepseekArticle]:
        return [DeepseekArticle(**article.model_dump()) for article in super().get_articles(hours)]


if __name__ == "__main__":
    scraper = DeepseekScraper()
    articles = scraper.get_articles(hours=1680)
    for a in articles:
        print(f"Title: {a.title}\nURL: {a.url}\nDate: {a.published_at}\n")
