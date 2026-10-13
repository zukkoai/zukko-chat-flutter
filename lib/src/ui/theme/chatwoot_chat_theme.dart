import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';

/// Chat theme as a [ThemeExtension]: register it in `ThemeData.extensions` or
/// pass it to `ChatwootChatOptions.theme`. When neither is given the theme is
/// derived from the ambient [ColorScheme] (dark mode works out of the box).
///
/// flutter_chat_ui 2.x `ChatTheme` is a small sealed class, so [toChatTheme]
/// maps this theme onto it; the remaining fields are used by the SDK's own
/// message and composer builders.
@immutable
class ChatwootChatTheme extends ThemeExtension<ChatwootChatTheme> {
  final Color backgroundColor;
  final Color primaryColor;
  final Color onPrimaryColor;

  /// Background of received messages.
  final Color secondaryColor;
  final Color inputBackgroundColor;
  final Color inputTextColor;

  /// Dot shown next to the title when the conversation is online.
  final Color onlineIndicatorColor;
  final BorderRadius inputBorderRadius;
  final double messageBorderRadius;

  /// Horizontal gap between the screen edge and the message list.
  final double horizontalPadding;
  final TextStyle sentMessageBodyTextStyle;
  final TextStyle receivedMessageBodyTextStyle;
  final TextStyle sentMessageCaptionTextStyle;
  final TextStyle receivedMessageCaptionTextStyle;
  final TextStyle userNameTextStyle;

  /// Footer ("Powered by ...") text style.
  final TextStyle brandingTextStyle;

  /// Avatar background colors; the author id picks one, so colors are stable.
  final List<Color> userAvatarNameColors;
  final Widget? sendButtonIcon;

  const ChatwootChatTheme({
    required this.backgroundColor,
    required this.primaryColor,
    required this.onPrimaryColor,
    required this.secondaryColor,
    required this.inputBackgroundColor,
    required this.inputTextColor,
    required this.onlineIndicatorColor,
    required this.sentMessageBodyTextStyle,
    required this.receivedMessageBodyTextStyle,
    required this.sentMessageCaptionTextStyle,
    required this.receivedMessageCaptionTextStyle,
    required this.userNameTextStyle,
    required this.brandingTextStyle,
    required this.userAvatarNameColors,
    this.inputBorderRadius = const BorderRadius.all(Radius.circular(10)),
    this.messageBorderRadius = 20.0,
    this.horizontalPadding = 16.0,
    this.sendButtonIcon,
  });

  /// Derives every token from [scheme].
  factory ChatwootChatTheme.fromColorScheme(ColorScheme scheme) {
    TextStyle style(
      Color color,
      double size,
      FontWeight weight,
      double height,
    ) => TextStyle(
      color: color,
      fontSize: size,
      fontWeight: weight,
      height: height,
    );
    return ChatwootChatTheme(
      backgroundColor: scheme.surfaceContainerLow,
      primaryColor: scheme.primary,
      onPrimaryColor: scheme.onPrimary,
      secondaryColor: scheme.surfaceContainerHighest,
      inputBackgroundColor: scheme.surfaceContainerHighest,
      inputTextColor: scheme.onSurface,
      onlineIndicatorColor: Colors.green,
      sentMessageBodyTextStyle: style(
        scheme.onPrimary,
        16,
        FontWeight.w500,
        1.5,
      ),
      receivedMessageBodyTextStyle: style(
        scheme.onSurface,
        16,
        FontWeight.w500,
        1.5,
      ),
      sentMessageCaptionTextStyle: style(
        scheme.onPrimary.withValues(alpha: 0.7),
        12,
        FontWeight.w500,
        1.333,
      ),
      receivedMessageCaptionTextStyle: style(
        scheme.onSurfaceVariant,
        12,
        FontWeight.w500,
        1.333,
      ),
      userNameTextStyle: style(scheme.onSurface, 12, FontWeight.w800, 1.333),
      brandingTextStyle: style(
        scheme.onSurfaceVariant,
        12,
        FontWeight.w400,
        1.333,
      ),
      userAvatarNameColors: [scheme.primary],
    );
  }

  /// [override] if given, else the theme registered in [ThemeData.extensions],
  /// else one derived from the ambient color scheme.
  static ChatwootChatTheme resolve(
    BuildContext context, [
    ChatwootChatTheme? override,
  ]) {
    final theme = Theme.of(context);
    return override ??
        theme.extension<ChatwootChatTheme>() ??
        ChatwootChatTheme.fromColorScheme(theme.colorScheme);
  }

  /// Avatar colour of [userId]. Stable across runs and Dart versions
  /// (`String.hashCode` is neither).
  Color avatarColorFor(String userId) {
    final hash = userId.codeUnits.fold<int>(
      0,
      (h, c) => (h * 31 + c) & 0x7fffffff,
    );
    return userAvatarNameColors[hash % userAvatarNameColors.length];
  }

  /// Maps this theme to a flutter_chat_ui 2.x [ChatTheme].
  ChatTheme toChatTheme() => ChatTheme(
    colors: ChatColors(
      primary: primaryColor,
      onPrimary: onPrimaryColor,
      surface: backgroundColor,
      onSurface: receivedMessageBodyTextStyle.color ?? inputTextColor,
      surfaceContainer: secondaryColor,
      surfaceContainerLow: inputBackgroundColor,
      surfaceContainerHigh: secondaryColor,
    ),
    typography: ChatTypography.standard().copyWith(
      bodyMedium: receivedMessageBodyTextStyle,
      labelSmall: receivedMessageCaptionTextStyle,
    ),
    shape: BorderRadius.circular(messageBorderRadius),
  );

  @override
  ChatwootChatTheme copyWith({
    Color? backgroundColor,
    Color? primaryColor,
    Color? onPrimaryColor,
    Color? secondaryColor,
    Color? inputBackgroundColor,
    Color? inputTextColor,
    Color? onlineIndicatorColor,
    BorderRadius? inputBorderRadius,
    double? messageBorderRadius,
    double? horizontalPadding,
    TextStyle? sentMessageBodyTextStyle,
    TextStyle? receivedMessageBodyTextStyle,
    TextStyle? sentMessageCaptionTextStyle,
    TextStyle? receivedMessageCaptionTextStyle,
    TextStyle? userNameTextStyle,
    TextStyle? brandingTextStyle,
    List<Color>? userAvatarNameColors,
    Widget? sendButtonIcon,
  }) => ChatwootChatTheme(
    backgroundColor: backgroundColor ?? this.backgroundColor,
    primaryColor: primaryColor ?? this.primaryColor,
    onPrimaryColor: onPrimaryColor ?? this.onPrimaryColor,
    secondaryColor: secondaryColor ?? this.secondaryColor,
    inputBackgroundColor: inputBackgroundColor ?? this.inputBackgroundColor,
    inputTextColor: inputTextColor ?? this.inputTextColor,
    onlineIndicatorColor: onlineIndicatorColor ?? this.onlineIndicatorColor,
    inputBorderRadius: inputBorderRadius ?? this.inputBorderRadius,
    messageBorderRadius: messageBorderRadius ?? this.messageBorderRadius,
    horizontalPadding: horizontalPadding ?? this.horizontalPadding,
    sentMessageBodyTextStyle:
        sentMessageBodyTextStyle ?? this.sentMessageBodyTextStyle,
    receivedMessageBodyTextStyle:
        receivedMessageBodyTextStyle ?? this.receivedMessageBodyTextStyle,
    sentMessageCaptionTextStyle:
        sentMessageCaptionTextStyle ?? this.sentMessageCaptionTextStyle,
    receivedMessageCaptionTextStyle:
        receivedMessageCaptionTextStyle ?? this.receivedMessageCaptionTextStyle,
    userNameTextStyle: userNameTextStyle ?? this.userNameTextStyle,
    brandingTextStyle: brandingTextStyle ?? this.brandingTextStyle,
    userAvatarNameColors: userAvatarNameColors ?? this.userAvatarNameColors,
    sendButtonIcon: sendButtonIcon ?? this.sendButtonIcon,
  );

  @override
  ChatwootChatTheme lerp(ThemeExtension<ChatwootChatTheme>? other, double t) {
    if (other is! ChatwootChatTheme) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    TextStyle s(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return ChatwootChatTheme(
      backgroundColor: c(backgroundColor, other.backgroundColor),
      primaryColor: c(primaryColor, other.primaryColor),
      onPrimaryColor: c(onPrimaryColor, other.onPrimaryColor),
      secondaryColor: c(secondaryColor, other.secondaryColor),
      inputBackgroundColor: c(inputBackgroundColor, other.inputBackgroundColor),
      inputTextColor: c(inputTextColor, other.inputTextColor),
      onlineIndicatorColor: c(onlineIndicatorColor, other.onlineIndicatorColor),
      inputBorderRadius: BorderRadius.lerp(
        inputBorderRadius,
        other.inputBorderRadius,
        t,
      )!,
      messageBorderRadius: lerpDouble(
        messageBorderRadius,
        other.messageBorderRadius,
        t,
      )!,
      horizontalPadding: lerpDouble(
        horizontalPadding,
        other.horizontalPadding,
        t,
      )!,
      sentMessageBodyTextStyle: s(
        sentMessageBodyTextStyle,
        other.sentMessageBodyTextStyle,
      ),
      receivedMessageBodyTextStyle: s(
        receivedMessageBodyTextStyle,
        other.receivedMessageBodyTextStyle,
      ),
      sentMessageCaptionTextStyle: s(
        sentMessageCaptionTextStyle,
        other.sentMessageCaptionTextStyle,
      ),
      receivedMessageCaptionTextStyle: s(
        receivedMessageCaptionTextStyle,
        other.receivedMessageCaptionTextStyle,
      ),
      userNameTextStyle: s(userNameTextStyle, other.userNameTextStyle),
      brandingTextStyle: s(brandingTextStyle, other.brandingTextStyle),
      userAvatarNameColors: t < 0.5
          ? userAvatarNameColors
          : other.userAvatarNameColors,
      sendButtonIcon: t < 0.5 ? sendButtonIcon : other.sendButtonIcon,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ChatwootChatTheme &&
      other.backgroundColor == backgroundColor &&
      other.primaryColor == primaryColor &&
      other.onPrimaryColor == onPrimaryColor &&
      other.secondaryColor == secondaryColor &&
      other.inputBackgroundColor == inputBackgroundColor &&
      other.inputTextColor == inputTextColor &&
      other.onlineIndicatorColor == onlineIndicatorColor &&
      other.inputBorderRadius == inputBorderRadius &&
      other.messageBorderRadius == messageBorderRadius &&
      other.horizontalPadding == horizontalPadding &&
      other.sentMessageBodyTextStyle == sentMessageBodyTextStyle &&
      other.receivedMessageBodyTextStyle == receivedMessageBodyTextStyle &&
      other.sentMessageCaptionTextStyle == sentMessageCaptionTextStyle &&
      other.receivedMessageCaptionTextStyle ==
          receivedMessageCaptionTextStyle &&
      other.userNameTextStyle == userNameTextStyle &&
      other.brandingTextStyle == brandingTextStyle &&
      listEquals(other.userAvatarNameColors, userAvatarNameColors) &&
      other.sendButtonIcon == sendButtonIcon;

  @override
  int get hashCode => Object.hash(
    backgroundColor,
    primaryColor,
    onPrimaryColor,
    secondaryColor,
    inputBackgroundColor,
    inputTextColor,
    onlineIndicatorColor,
    inputBorderRadius,
    messageBorderRadius,
    horizontalPadding,
    sentMessageBodyTextStyle,
    receivedMessageBodyTextStyle,
    sentMessageCaptionTextStyle,
    receivedMessageCaptionTextStyle,
    userNameTextStyle,
    brandingTextStyle,
    Object.hashAll(userAvatarNameColors),
    sendButtonIcon,
  );
}
