import '../domain/portfolio_content.dart';

String portfolioContactCategoryLabel(SocialLinkKind kind) => switch (kind) {
  SocialLinkKind.github => 'GitHub',
  SocialLinkKind.linkedin => 'LinkedIn',
  SocialLinkKind.email => 'Почта',
  SocialLinkKind.phone => 'Телефон',
  SocialLinkKind.telegram => 'Telegram',
  SocialLinkKind.website => 'Сайт',
  SocialLinkKind.other => 'Другое',
};

String portfolioContactIconName(SocialLinkKind kind) => switch (kind) {
  SocialLinkKind.github => 'github',
  SocialLinkKind.linkedin => 'linkedin',
  SocialLinkKind.email => 'mail',
  SocialLinkKind.phone => 'phone',
  SocialLinkKind.telegram => 'send',
  SocialLinkKind.website => 'globe',
  SocialLinkKind.other => 'link',
};
