import 'package:flutter/material.dart';

class StackedPushingExpansionWidget extends StatefulWidget {
  const StackedPushingExpansionWidget({
    Key? key,
    required this.header,
    required this.content,
  }) : super(key: key);

  /// The widget to display as the top card (the header).
  final Widget header;

  /// The content to display inside the bottom card when it's expanded.
  final Widget content;

  @override
  _StackedPushingExpansionWidgetState createState() => _StackedPushingExpansionWidgetState();
}

class _StackedPushingExpansionWidgetState extends State<StackedPushingExpansionWidget> {
  bool _isExpanded = false;

  // --- Customizable Values ---
  // Note: _collapsedHeight must be > 0 for the bottom card to peek out.
  final double _collapsedHeight = 5.0; 
  final double _expandedContentHeight = 250.0;
  final double _headerHeight = 50.0;
  final double _overlap = 10.0; // How much the header overlaps the body
  final Duration _animationDuration = const Duration(milliseconds: 300);
  final Curve _animationCurve = Curves.easeInOut;
  // --------------------------

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  // Calculates the final height of the AnimatedContainer
  double get _currentContainerHeight {
    if (_isExpanded) {
      // Expanded height includes the content height + the initial collapsed height
      // and accounts for the padding inside the card.
      return _expandedContentHeight + _collapsedHeight;
    } else {
      // Collapsed height is just the collapsed height
      return _collapsedHeight;
    }
  }

  @override
  Widget build(BuildContext context) {
    // We use a Column to allow the widget's size to change and push other widgets.
    return Column(
      mainAxisSize: MainAxisSize.min, // Important: only take the vertical space needed
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // --- 1. The main stacking area ---
        Stack(
          alignment: Alignment.topCenter,
          children: [
            // A) The Bottom (Expandable) Card - Controls the space
            AnimatedContainer(
              duration: _animationDuration,
              curve: _animationCurve,
              // The top margin pushes the bottom card down enough for the header card to sit on top.
              margin: EdgeInsets.only(top: _headerHeight - _overlap),
              
              // The height determines the final size and is what pushes elements down.
              height: _currentContainerHeight,
              width: 300,
              
              child: Card(
                elevation: 4.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.0),
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(), // Content is clipped, so scrolling is not needed here
                    child: Padding(
                      // This padding ensures the content starts below the overlap area.
                      padding: EdgeInsets.only(
                        top: _collapsedHeight + 16, // Padding accounts for the initial visible strip + Card padding
                        left: 16.0,
                        right: 16.0,
                        bottom: 16.0,
                      ),
                      
                      // *** Offstage and AnimatedSize to handle content rendering ***
                      child: AnimatedSize(
                        duration: _animationDuration,
                        curve: _animationCurve,
                        child: Offstage(
                          offstage: !_isExpanded,
                          child: widget.content,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // B) The Top (Header) Card - Always visible and tappable
            GestureDetector(
              onTap: _toggleExpansion,
              child: SizedBox(
                height: _headerHeight,
                width: 280,
                child: Card(
                  elevation: 6.0,
                  color: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Center(child: widget.header),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}