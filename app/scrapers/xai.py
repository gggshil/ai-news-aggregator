from typing import List
from .base import BaseScraper, Article


class XaiArticle(Article):
    pass


class XaiScraper(BaseScraper):
    @property
    def rss_urls(self) -> List[str]:
        return ["https://raw.githubusercontent.com/Olshansk/rss-feeds/main/feeds/feed_xainews.xml"]

    def get_articles(self, hours: int = 24) -> List[XaiArticle]:
        return [XaiArticle(**article.model_dump()) for article in super().get_articles(hours)]


if __name__ == "__main__":
    scraper = XaiScraper()
    articles = scraper.get_articles(hours=168)
    for a in articles:
        print(f"Title: {a.title}\nURL: {a.url}\nDate: {a.published_at}\n")
