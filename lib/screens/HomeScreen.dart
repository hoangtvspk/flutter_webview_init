import 'package:webview_base/provider/savedCookieProvider.dart';
import 'package:flutter/material.dart';
import 'package:webview_base/widgets/webview/index.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  final String url;
  final bool mainPage;
  final bool showDevToolButton;
  final int? windowId;
  const HomeScreen(this.url,
      {Key? key,
      this.mainPage = true,
      this.windowId,
      this.showDevToolButton = false})
      : super(key: key);
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin<HomeScreen>, TickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  late AnimationController navigationContainerAnimationController =
      AnimationController(
          vsync: this, duration: const Duration(milliseconds: 500));

  @override
  void dispose() {
    navigationContainerAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SavedCookieProvider>(context, listen: false);
    super.build(context);
    return WebViewContainer(
        url: provider.savedCookie == null ? widget.url : widget.url,
        webUrl: true,
        showDevToolButton: widget.showDevToolButton);
  }
}
