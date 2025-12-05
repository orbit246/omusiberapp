import 'package:flutter/material.dart';
import 'package:omusiber/backend/news_fetcher.dart';
import 'package:omusiber/widgets/news/fetch_news_button.dart';
import 'package:omusiber/widgets/news/news_card.dart';

class NewsTabView extends StatelessWidget {
  const NewsTabView({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: const PageStorageKey('news_tab'),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: FutureBuilder(
              future: NewsFetcher().fetchLatestNews(),
              builder: (context, asyncSnapshot) {
                return Column(
                  children: [
                    const SizedBox(height: 16),
                    Center(
                      child: FetchNewsButton(
                        onFetch: () async {
                          await Future.delayed(const Duration(seconds: 5));
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (asyncSnapshot.connectionState == ConnectionState.waiting)
                      const CircularProgressIndicator()
                    else if (asyncSnapshot.hasError)
                      Text("Haberler yüklenirken hata: ${asyncSnapshot.error}")
                    else if (asyncSnapshot.hasData)
                      ...asyncSnapshot.data!
                          .map((newsView) => Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: NewsCard(view: newsView),
                              ))
                          .toList(),
                    const SizedBox(height: 80),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}