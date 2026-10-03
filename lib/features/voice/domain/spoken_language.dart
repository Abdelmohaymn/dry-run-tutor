/// One language the platform recogniser can be asked for.
///
/// [name] is the recogniser's own display name for the locale, not a
/// string this app authors — which is why it is exempt from
/// `no_string_literals_in_widgets` when rendered.
class SpokenLanguage {
  const SpokenLanguage({required this.localeId, required this.name});

  final String localeId;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is SpokenLanguage && other.localeId == localeId && other.name == name;

  @override
  int get hashCode => Object.hash(localeId, name);
}
