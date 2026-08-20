// Guardado só em memória: persistir em disco exigiria uma dependência de
// armazenamento nova e dado pessoal em repouso para cobrir um caso raro
// (reabrir o app depois de sair). Encerrar o app depois de sair volta o
// campo vazio — limitação conhecida e aceita.
class LastSignedInEmail {
  String? _email;

  void save(String email) {
    _email = email;
  }

  String? read() => _email;
}
