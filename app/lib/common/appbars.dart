import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tudo_app/extensions.dart';

class DiscreteAppBar extends StatelessWidget with PreferredSizeWidget {
  final String title;
  final String? subtitle;

  @override
  final Size preferredSize = const Size.fromHeight(kToolbarHeight);

  const DiscreteAppBar({Key? key, required this.title, this.subtitle})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      systemOverlayStyle: context.theme.brightness == Brightness.light
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      elevation: 0,
      foregroundColor: context.theme.textTheme.headline6!.color,
      backgroundColor: context.theme.canvasColor,
      centerTitle: true,
      title: Column(
        children: [
          Text(title),
          if (subtitle != null)
            Text(
              subtitle!,
              style: context.theme.textTheme.caption!
                  .copyWith(color: context.theme.primaryColor),
            ),
        ],
      ),
    );
  }
}
