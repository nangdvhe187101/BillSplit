import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../data/models/user_model.dart';

// --- EVENTS ---
abstract class AuthEvent {}

class AuthCheckRequested extends AuthEvent {}

class AuthLoginSubmitted extends AuthEvent {
  final String identifier;
  final String password;
  AuthLoginSubmitted({required this.identifier, required this.password});
}

class AuthRegisterSubmitted extends AuthEvent {
  final String phoneNumber;
  final String email;
  final String password;
  final String fullName;
  final String bankBin;
  final String bankAccountNo;
  final String bankAccountName;

  AuthRegisterSubmitted({
    required this.phoneNumber,
    required this.email,
    required this.password,
    required this.fullName,
    required this.bankBin,
    required this.bankAccountNo,
    required this.bankAccountName,
  });
}

class AuthLogoutRequested extends AuthEvent {}

// --- STATES ---
abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class Authenticated extends AuthState {
  final UserModel user;
  final String token;
  Authenticated({required this.user, required this.token});
}

class Unauthenticated extends AuthState {}

class AuthFailure extends AuthState {
  final String message;
  AuthFailure(this.message);
}

// --- BLOC ---
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final DioClient dioClient;
  final LocalStorageService localStorage;

  AuthBloc({
    required this.dioClient,
    required this.localStorage,
  }) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLoginSubmitted>(_onAuthLoginSubmitted);
    on<AuthRegisterSubmitted>(_onAuthRegisterSubmitted);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    final token = await localStorage.getToken();
    if (token == null || token.isEmpty) {
      emit(Unauthenticated());
      return;
    }

    // Đọc lại thông tin User đã cache lúc đăng nhập/đăng ký thành công, không gọi
    // API kiểm tra (Backend chưa có GET /users/profile - Module 2 chưa triển khai).
    // Token hết hạn sẽ tự lộ ra ở lần gọi API thật đầu tiên sau đó (401 Unauthorized).
    final userJson = await localStorage.getUserJson();
    if (userJson == null || userJson.isEmpty) {
      await localStorage.clearToken();
      emit(Unauthenticated());
      return;
    }

    try {
      final user = UserModel.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      emit(Authenticated(user: user, token: token));
    } catch (_) {
      await localStorage.clearToken();
      await localStorage.clearUserJson();
      emit(Unauthenticated());
    }
  }

  Future<void> _onAuthLoginSubmitted(
    AuthLoginSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final response = await dioClient.dio.post(
        '/auth/login',
        data: {
          'identifier': event.identifier,
          'password': event.password,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final token = data['token'] as String;
        final userJson = data['user'] as Map<String, dynamic>;
        final user = UserModel.fromJson(userJson);

        await localStorage.saveToken(token);
        await localStorage.saveUserJson(jsonEncode(userJson));
        emit(Authenticated(user: user, token: token));
      } else {
        emit(AuthFailure('Đăng nhập không thành công.'));
      }
    } on DioException catch (e) {
      final message = e.response?.data?['message']?.toString() ??
          'Lỗi kết nối đến máy chủ. Vui lòng thử lại.';
      emit(AuthFailure(message));
    } catch (e) {
      emit(AuthFailure('Đã xảy ra lỗi không xác định: $e'));
    }
  }

  Future<void> _onAuthRegisterSubmitted(
    AuthRegisterSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final response = await dioClient.dio.post(
        '/auth/register',
        data: {
          'phoneNumber': event.phoneNumber,
          'email': event.email,
          'password': event.password,
          'fullName': event.fullName,
          'bankBin': event.bankBin,
          'bankAccountNo': event.bankAccountNo,
          'bankAccountName': event.bankAccountName,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final token = data['token'] as String;
        final userJson = data['user'] as Map<String, dynamic>;
        final user = UserModel.fromJson(userJson);

        await localStorage.saveToken(token);
        await localStorage.saveUserJson(jsonEncode(userJson));
        emit(Authenticated(user: user, token: token));
      } else {
        emit(AuthFailure('Đăng ký không thành công.'));
      }
    } on DioException catch (e) {
      final message = e.response?.data?['message']?.toString() ??
          'Lỗi kết nối đến máy chủ. Vui lòng thử lại.';
      emit(AuthFailure(message));
    } catch (e) {
      emit(AuthFailure('Đã xảy ra lỗi: $e'));
    }
  }

  Future<void> _onAuthLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await localStorage.clearToken();
    await localStorage.clearUserJson();
    emit(Unauthenticated());
  }
}
