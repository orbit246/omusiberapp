import 'package:flutter/material.dart';
import 'package:omusiber/widgets/home/simple_appbar.dart';
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: SimpleAppbarNoBack(title: "Haberler"),
      ),
      bottomNavigationBar: AppNavigationBar(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(left: 12.0, right: 12.0),
          child: Column(
            spacing: 8,
            children: [
              SizedBox(height: 12),
              // Place this anywhere in your widget tree:
              Center(
                child: FetchNewsButton(
                  onFetch: () async {
                    await Future.delayed(const Duration(seconds: 5));
                    // Optionally show a SnackBar or update state outside.
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
