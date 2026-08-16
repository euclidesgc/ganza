import 'package:flutter/material.dart';

/// Os estados que o `ColorScheme` do Material não nomeia. Verde seco e
/// terracota carregam estado sem virar semáforo: num app aberto todo dia,
/// vermelho saturado transforma a tela num painel de alarmes e ensina o
/// usuário a ignorá-la.
@immutable
class GanzaColors extends ThemeExtension<GanzaColors> {
  const GanzaColors({
    required this.done,
    required this.doneSoft,
    required this.overdue,
    required this.overdueSoft,
    required this.forecast,
    required this.elevatedSurface,
    required this.outline,
    required this.mutedInk,
  });

  final Color done;
  final Color doneSoft;
  final Color overdue;
  final Color overdueSoft;

  /// Valor estimado ou ainda não confirmado pelo banco.
  final Color forecast;

  final Color elevatedSurface;
  final Color outline;
  final Color mutedInk;

  @override
  GanzaColors copyWith({
    Color? done,
    Color? doneSoft,
    Color? overdue,
    Color? overdueSoft,
    Color? forecast,
    Color? elevatedSurface,
    Color? outline,
    Color? mutedInk,
  }) {
    return GanzaColors(
      done: done ?? this.done,
      doneSoft: doneSoft ?? this.doneSoft,
      overdue: overdue ?? this.overdue,
      overdueSoft: overdueSoft ?? this.overdueSoft,
      forecast: forecast ?? this.forecast,
      elevatedSurface: elevatedSurface ?? this.elevatedSurface,
      outline: outline ?? this.outline,
      mutedInk: mutedInk ?? this.mutedInk,
    );
  }

  @override
  GanzaColors lerp(ThemeExtension<GanzaColors>? other, double t) {
    if (other is! GanzaColors) return this;
    return GanzaColors(
      done: Color.lerp(done, other.done, t)!,
      doneSoft: Color.lerp(doneSoft, other.doneSoft, t)!,
      overdue: Color.lerp(overdue, other.overdue, t)!,
      overdueSoft: Color.lerp(overdueSoft, other.overdueSoft, t)!,
      forecast: Color.lerp(forecast, other.forecast, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      mutedInk: Color.lerp(mutedInk, other.mutedInk, t)!,
    );
  }
}
