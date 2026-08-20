import 'package:fpdart/fpdart.dart';
import 'package:zard/zard.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/user_profile.dart';

/// O `.nullable()` do zard 0.0.26 só seta uma flag — `Schema.parse()` ignora
/// essa flag e lança em qualquer valor `null`, mesmo com o campo marcado
/// nullable, antes de rodar validador ou transform. Como o PostgREST manda
/// `display_name: null` explícito para conta sem nome, o campo precisa de um
/// schema que intercepte o `null` antes de delegar ao `ZString` interno — o
/// mesmo recurso que o `ZDefault` da própria lib usa para tratar `null` no
/// seu próprio `parse()`.
class _NullableString extends Schema<String?> {
  _NullableString(this._inner) {
    nullish();
  }

  final ZString _inner;

  @override
  String? parse(dynamic value, {String path = ''}) {
    if (value == null) return null;
    return _inner.parse(value, path: path);
  }
}

/// `email` não mora em `public.profiles` — vem da sessão do GoTrue, já
/// tipado pelo SDK, então quem chama passa o valor pronto em vez de
/// validá-lo de novo aqui.
abstract final class ProfileModel {
  static final _schema = z.map({
    'id': z.string(),
    'display_name': _NullableString(z.string()),
    'timezone': z.string(),
  });

  static Either<Failure, UserProfile> fromMap(
    Map<String, dynamic> map, {
    required String email,
  }) {
    final result = _schema.safeParse(map);
    if (!result.success || result.data == null) {
      return const Left(ValidationFailure('Perfil em formato inesperado.'));
    }

    final data = result.data!;
    return Right(
      UserProfile(
        id: data['id'] as String,
        email: email,
        displayName: data['display_name'] as String?,
        timezone: data['timezone'] as String,
      ),
    );
  }
}
