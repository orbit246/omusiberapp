import 'package:flutter/material.dart';

class NewsCardItemIconButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Color? color;
  final double iconSize;
  final IconData favoriteIcon;
  final IconData favoriteBorderIcon;

  const NewsCardItemIconButton({
    super.key,
    this.onPressed,
    this.color,
    this.iconSize = 22,
    this.favoriteIcon = Icons.favorite,
    this.favoriteBorderIcon = Icons.favorite_border,
  });

  @override
  _NewsCardItemIconButtonState createState() => _NewsCardItemIconButtonState();
}

class _NewsCardItemIconButtonState extends State<NewsCardItemIconButton> {
  bool isFavorite = false;

  void _toggleFavorite() {
    setState(() {
      isFavorite = !isFavorite;
    });
    if (widget.onPressed != null) {
      widget.onPressed!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _toggleFavorite,
      icon: Icon(isFavorite ? widget.favoriteIcon : widget.favoriteBorderIcon),
      color: widget.color ?? Theme.of(context).colorScheme.onSurface,
      iconSize: widget.iconSize,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
      highlightColor: Colors.transparent,
    );
  }
}
