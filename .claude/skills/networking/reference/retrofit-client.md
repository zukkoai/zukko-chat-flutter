# retrofit — type-safe API client

Declare the API as an abstract interface. retrofit generates the implementation that handles serialization. Do not write `jsonDecode` or `try/catch` inside the interface — let DioExceptions propagate to the repository.

```dart
part 'api_client.g.dart';

@RestApi()
abstract class ApiClient {
  factory ApiClient(Dio dio, {String baseUrl}) = _ApiClient;

  @GET('/todos')
  Future<List<TodoDto>> getTodos(@Query('page') int page);

  @GET('/todos/{id}')
  Future<TodoDto> getTodo(@Path('id') String id);

  @POST('/todos')
  Future<TodoDto> createTodo(@Body() CreateTodoDto body);
}
```

Generate with `dart run build_runner build -d`. DTOs use `json_serializable`:

```dart
@JsonSerializable()
class TodoDto {
  TodoDto({required this.id, required this.title, required this.done});
  factory TodoDto.fromJson(Map<String, dynamic> json) => _$TodoDtoFromJson(json);
  final String id;
  final String title;
  final bool done;
  Map<String, dynamic> toJson() => _$TodoDtoToJson(this);

  Todo toDomain() => Todo(id: id, title: title, done: done);
}
```

Keep DTOs in the data layer; map them to domain models (`toDomain()`) in the repository so the rest of the app never sees JSON shapes.
