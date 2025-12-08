class WebPostMessage {
  WebPostMessage({
    required this.type,
    required this.messageData,
  });

  final String? type;
  final MessageData? messageData;

  factory WebPostMessage.fromJson(Map<String, dynamic> json) {
    return WebPostMessage(
      type: json["type"],
      messageData: json["messageData"] == null
          ? null
          : MessageData.fromJson(json["messageData"]),
    );
  }

  Map<String, dynamic> toJson() => {
        "type": type,
        "messageData": messageData?.toJson(),
      };
}

class MessageData {
  MessageData({
    required this.url,
    required this.title,
  });

  final String? url;
  final String? title;

  factory MessageData.fromJson(Map<String, dynamic> json) {
    return MessageData(
      url: json["url"],
      title: json["title"],
    );
  }

  Map<String, dynamic> toJson() => {
        "url": url,
        "title": title,
      };
}
