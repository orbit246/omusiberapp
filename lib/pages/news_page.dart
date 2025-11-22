import 'package:flutter/material.dart';
import 'package:omusiber/backend/news_fetcher.dart';
// You might not need the simple_appbar imports anymore if you use standard SliverAppBar,
// but keeping them just in case you want to use their widgets inside the title.
import 'package:omusiber/widgets/home/simple_appbar_no_back.dart';
import 'package:omusiber/widgets/news/fetch_news_button.dart';
import 'package:omusiber/widgets/news/news_card.dart';
import 'package:omusiber/widgets/shared/navbar.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 1. Remove the standard appBar parameter
      bottomNavigationBar: AppNavigationBar(),

      // 2. Use CustomScrollView for modern scrolling physics
      body: CustomScrollView(
        slivers: [
          // 3. The Dynamic AppBar
          SliverAppBar(
            // "floating: true" makes it appear immediately when you scroll UP
            floating: true,
            // "snap: true" makes it snap into view fully instead of partially
            snap: true,

            centerTitle: true,
            title: Text(
              "Haberler",
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            elevation: 5,
          ),

          // 4. Your content adapter
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: 12.0, right: 12.0),
              child: FutureBuilder(
                future: NewsFetcher().fetchLatestNews(),
                builder: (context, asyncSnapshot) {
                  return Column(
                    spacing:
                        8, // Note: 'spacing' is available in newer Flutter versions (Column)
                    children: [
                      const SizedBox(height: 12),
                      Center(
                        child: FetchNewsButton(
                          onFetch: () async {
                            await Future.delayed(const Duration(seconds: 5));
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (asyncSnapshot.connectionState ==
                          ConnectionState.waiting)
                        const CircularProgressIndicator()
                      else if (asyncSnapshot.hasError)
                        Text(
                          "Haberler yüklenirken bir hata oluştu.${asyncSnapshot.error}",
                        )
                      else if (asyncSnapshot.hasData)
                        ...asyncSnapshot.data!
                            .map((newsView) => NewsCard(view: newsView))
                            .toList(),

                      // Add some bottom padding so items aren't hidden behind the navbar
                      const SizedBox(height: 20),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

