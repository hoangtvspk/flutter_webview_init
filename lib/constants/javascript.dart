const listenRouterChange = """
        // Listen for pushState and replaceState events in SPA
        (function() {
          let lastUrl = location.href;
          new MutationObserver(() => {
            const currentUrl = location.href;
            if (currentUrl !== lastUrl) {
              lastUrl = currentUrl;
              window.flutter_inappwebview.callHandler('onRouteChanged', currentUrl);
            }
          }).observe(document, { subtree: true, childList: true });
        })();
      """;

String navigate(String path) {
  return """
        (function() {
          try{
              webviewNavigate('$path');
          } catch(e){
              window.location.href = '$path';
          }
        })();
      """;
}

String setContacts(String payload) {
  return """
        (function() {
          setContacts('$payload');
        })();
      """;
}

String handleException(String message) {
  return """
        (function() {
          handleException('$message');
        })();
      """;
}
