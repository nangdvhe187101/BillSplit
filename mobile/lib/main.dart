import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'core/network/dio_client.dart';
import 'core/storage/local_storage_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/register_page.dart';
import 'features/friends/presentation/pages/friends_page.dart';
import 'features/groups/presentation/pages/groups_page.dart';
import 'features/home/presentation/pages/home_page.dart';
import 'features/payment/presentation/pages/qr_payment_page.dart';
import 'features/split/presentation/pages/split_bill_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final localStorage = LocalStorageService();
  final dioClient = DioClient();

  runApp(
    BillSplitApp(
      localStorage: localStorage,
      dioClient: dioClient,
    ),
  );
}

class BillSplitApp extends StatelessWidget {
  final LocalStorageService localStorage;
  final DioClient dioClient;

  const BillSplitApp({
    super.key,
    required this.localStorage,
    required this.dioClient,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: localStorage),
        RepositoryProvider.value(value: dioClient),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => AuthBloc(
              dioClient: dioClient,
              localStorage: localStorage,
            )..add(AuthCheckRequested()),
          ),
        ],
        child: MaterialApp.router(
          title: 'Sổ Nợ',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          routerConfig: _createRouter(localStorage),
        ),
      ),
    );
  }
}

GoRouter _createRouter(LocalStorageService localStorage) {
  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) async {
      final token = await localStorage.getToken();
      final isAuthRoute = state.matchedLocation == '/login' || state.matchedLocation == '/register';

      // Nếu đã có token và đang ở trang đăng nhập/đăng ký thì chuyển thẳng về trang chủ
      if (token != null && token.isNotEmpty && isAuthRoute) {
        return '/home';
      }

      // Khách vãng lai (chưa đăng nhập) được phép vào /home và /split để tính toán chia tiền nhanh
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/split',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return SplitBillPage(
            initialAmount: extra?['initialAmount'] as double?,
            initialTitle: extra?['initialTitle'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/qr-payment',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return QrPaymentPage(
            debtId: extra['debtId'] as String?,
            debtorName: extra['debtorName'] as String? ?? '',
            amount: (extra['amount'] as num?)?.toDouble() ?? 0.0,
            debtCode: extra['debtCode'] as String? ?? '',
            title: extra['title'] as String? ?? 'Mã QR nhận tiền',
          );
        },
      ),
      GoRoute(
        path: '/friends',
        builder: (context, state) => const FriendsPage(),
      ),
      GoRoute(
        path: '/groups',
        builder: (context, state) => const GroupsPage(),
      ),
    ],
  );
}
