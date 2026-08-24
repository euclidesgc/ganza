import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/modules/transactions_module/domain/entities/category.dart';
import 'package:ganza/modules/transactions_module/domain/repositories/categories_repository.dart';
import 'package:ganza/modules/transactions_module/domain/usecases/list_categories.dart';
import 'package:mocktail/mocktail.dart';

class MockCategoriesRepository extends Mock implements CategoriesRepository {}

void main() {
  late MockCategoriesRepository repository;
  late ListCategories useCase;

  final category = Category(id: 'c1', name: 'Alimentação');

  setUp(() {
    repository = MockCategoriesRepository();
    useCase = ListCategories(repository);
  });

  test('devolve Right com as categorias do repositório', () async {
    when(() => repository.list()).thenAnswer((_) async => Right([category]));

    final result = await useCase();

    result.fold(
      (failure) => fail('esperava Right, veio $failure'),
      (list) => expect(list, [category]),
    );
  });

  test('propaga o Left do repositório na falha', () async {
    const failure = NetworkFailure();
    when(() => repository.list()).thenAnswer((_) async => const Left(failure));

    final result = await useCase();

    result.fold(
      (value) => expect(value, failure),
      (_) => fail('esperava Left'),
    );
  });
}
