// ignore_for_file: library_private_types_in_public_api
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:country_picker/country_picker.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:mobile/constants/api_endpoints.dart';
import 'package:mobile/constants/app_colors.dart';
import 'package:mobile/constants/app_theme.dart';
import 'package:mobile/screens/login_screen.dart';
import 'package:mobile/screens/main_screen.dart';
import 'package:mobile/screens/game_play_screen.dart';
import 'package:mobile/screens/game_legends_screen.dart';
import 'package:mobile/screens/live_duel_spectator_screen.dart';
import 'package:mobile/screens/messages_screen.dart';
import 'package:mobile/screens/profile_screen.dart';
import 'package:mobile/screens/profile_settings_screen.dart';
import 'package:mobile/screens/shop_screen.dart';
import 'package:mobile/screens/product_screen.dart';
import 'package:mobile/services/cart_service.dart';
import 'package:mobile/screens/create_product_screen.dart';
import 'package:mobile/screens/create_shop_screen.dart';
import 'package:mobile/screens/create_story_screen.dart';
import 'package:mobile/screens/stories_screen.dart';
import 'package:mobile/screens/reels_screen.dart';
import 'package:mobile/screens/create_reel_screen.dart';
import 'package:mobile/screens/live_screen.dart';
import 'package:mobile/screens/ar_effects_screen.dart';
import 'package:mobile/screens/create_event_screen.dart';
import 'package:mobile/screens/create_job_screen.dart';
import 'package:mobile/screens/map_screen.dart';
import 'package:mobile/screens/collaboration_screen.dart';
import 'package:mobile/screens/producer_dashboard_screen.dart';
import 'package:mobile/screens/shops_screen.dart';
import 'package:mobile/screens/chat_screen.dart';
import 'package:mobile/screens/cart_screen.dart';
import 'package:mobile/screens/edit_profile_screen.dart';
import 'package:mobile/screens/notifications_screen.dart';
import 'package:mobile/screens/advanced_search_screen.dart';
import 'package:mobile/screens/groups_screen.dart';
import 'package:mobile/screens/create_group_screen.dart';
import 'package:mobile/screens/user_profile_screen.dart';
import 'package:mobile/widgets/responsive_app_frame.dart';
import 'package:mobile/widgets/chat_window_host.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/app_locale_service.dart';
import 'package:mobile/services/app_theme_service.dart';
import 'package:mobile/services/story_offline_service.dart';
import 'package:mobile/services/offline_data_service.dart';
import 'package:mobile/services/notification_sound_service.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/models/shop.dart';
import 'package:mobile/models/user.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await StoryOfflineService.initialize(publishStory: ApiService.createStory);
  await OfflineDataService.initialize();
  await CartService.initialize();
  await AppLocaleService.initialize();
  await AppThemeService.initialize();
  await NotificationSoundService.initialize();

  if (!kIsWeb && Platform.isIOS) {
    final envSimulator = isIosSimulatorFromEnv(Platform.environment);
    final home = Platform.environment['HOME'];
    bool isSimulator = envSimulator;

    try {
      final iosInfo = await DeviceInfoPlugin().iosInfo;
      final physicalDevice = iosInfo.isPhysicalDevice;
      final machine = iosInfo.utsname.machine.toLowerCase();

      isSimulator = !physicalDevice || envSimulator;

      debugPrint(
        'iOS device info: isPhysicalDevice=$physicalDevice, '
        'machine=$machine, envSimulator=$envSimulator, isSimulator=$isSimulator',
      );
    } catch (error) {
      debugPrint('Failed to detect iOS simulator via DeviceInfoPlugin: $error');
    }

    ApiEndpoints.setIosSimulator(isSimulator);
    debugPrint(
      'Detected iOS simulator final value: $isSimulator, '
      'HOME=${home ?? 'null'}',
    );
  }

  debugPrint('ApiEndpoints.baseUrl = ${ApiEndpoints.baseUrl}');
  debugPrint('ApiEndpoints.wsUrl = ${ApiEndpoints.wsUrl}');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: AppLocaleService.locale,
      builder: (context, locale, _) => ValueListenableBuilder<bool>(
        valueListenable: AppThemeService.isDarkMode,
        builder: (context, isDarkMode, _) => MaterialApp(
          title: 'FopCam',
          locale: locale,
          supportedLocales: AppLocaleService.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            CountryLocalizations.delegate,
          ],
          theme: buildAppTheme(isDark: false),
          darkTheme: buildAppTheme(),
          themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
          builder: (context, child) => ChatWindowHost.wrap(
            ResponsiveAppFrame(child: child ?? const SizedBox.shrink()),
          ),
          initialRoute: '/',
          routes: {
            '/': (ctx) => const AuthWrapper(),
            '/login': (ctx) => const LoginScreen(),
            '/home': (ctx) => const MainScreen(),
            '/explorer': (ctx) => const MainScreen(initialIndex: 1),
            '/create': (ctx) => const MainScreen(initialIndex: 2),
            '/game': (ctx) {
              final args = ModalRoute.of(ctx)?.settings.arguments as Map?;
              final challengeId = args?['challengeId'];
              return GamePlayScreen(
                challengeId: challengeId is int ? challengeId : null,
              );
            },
            '/game/legends': (ctx) => const GameLegendsScreen(),
            '/game/spectate': (ctx) {
              final args = ModalRoute.of(ctx)?.settings.arguments as Map?;
              final challengeId = args?['challengeId'];
              return challengeId is int
                  ? LiveDuelSpectatorScreen(challengeId: challengeId)
                  : const Scaffold(
                      body: Center(child: Text('Duel indisponible.')),
                    );
            },
            '/profile': (ctx) => const ProfileScreen(),
            '/profile/settings': (ctx) => const ProfileSettingsScreen(),
            '/messages': (ctx) => const MessagesScreen(),
            '/shop': (ctx) {
              final route = ModalRoute.of(ctx);
              final args = route?.settings.arguments as Map?;
              final shopId = args != null && args['shopId'] != null
                  ? args['shopId'] as int
                  : 0;
              return ShopScreen(shopId: shopId);
            },
            '/shops': (ctx) => const ShopsScreen(),
            '/product': (ctx) {
              final productId = ModalRoute.of(ctx)?.settings.arguments;
              return ProductScreen(productId: productId is int ? productId : 0);
            },
            '/create_product': (ctx) => const CreateProductScreen(),
            '/create_shop': (ctx) {
              final args = ModalRoute.of(ctx)?.settings.arguments as Map?;
              final shop = args?['shop'];
              return CreateShopScreen(shop: shop is Shop ? shop : null);
            },
            '/create_story': (ctx) {
              final selection = ModalRoute.of(ctx)?.settings.arguments;
              return CreateStoryScreen(
                initialMediaSelection: selection is StoryMediaSelection
                    ? selection
                    : null,
              );
            },
            '/stories': (ctx) => const StoriesScreen(),
            '/create_event': (ctx) => const CreateEventScreen(),
            '/create_job': (ctx) {
              final initialTab = ModalRoute.of(ctx)?.settings.arguments;
              return CreateJobScreen(
                initialTab: initialTab is int ? initialTab : 1,
              );
            },
            '/create_reel': (ctx) => const CreateReelScreen(),
            '/reels': (ctx) => const ReelsScreen(),
            '/live': (ctx) => const LiveScreen(),
            '/ar_effects': (ctx) {
              final route = ModalRoute.of(ctx);
              final args = route?.settings.arguments as String?;
              return AREffectsScreen(initialFilter: args);
            },
            '/map': (ctx) => const MapScreen(),
            '/collaboration': (ctx) => const CollaborationScreen(),
            '/producer_dashboard': (ctx) => const ProducerDashboardScreen(),
            '/cart': (ctx) => const CartScreen(),
            '/edit_profile': (ctx) => const EditProfileScreen(),
            '/chat': (ctx) {
              final route = ModalRoute.of(ctx);
              final arguments = route?.settings.arguments;
              final roomValue = arguments is Map
                  ? arguments['roomId'] ??
                        arguments['room_id'] ??
                        arguments['room']
                  : arguments;
              final roomId = roomValue?.toString().trim() ?? '';
              final title = arguments is Map
                  ? arguments['title']?.toString()
                  : null;
              return ChatScreen(roomId: roomId, initialTitle: title);
            },
            '/notifications': (ctx) => const NotificationsScreen(),
            '/advanced_search': (ctx) => const AdvancedSearchScreen(),
            '/groups': (ctx) => const GroupsScreen(),
            '/create_group': (ctx) => const CreateGroupScreen(),
            '/user_profile': (ctx) {
              final user = ModalRoute.of(ctx)?.settings.arguments;
              if (user is! User) {
                return const Scaffold(
                  body: Center(child: Text('Profil utilisateur indisponible.')),
                );
              }
              return UserProfileScreen(user: user);
            },
          },
          onGenerateRoute: (settings) {
            final uri = Uri.tryParse(settings.name ?? '');
            if (uri == null) return null;
            if (uri.path == '/shop') {
              final shopId = int.tryParse(uri.queryParameters['shopId'] ?? '');
              if (shopId != null) {
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) => ShopScreen(shopId: shopId),
                );
              }
            }
            if (uri.path == '/product') {
              final productId = int.tryParse(
                uri.queryParameters['productId'] ?? '',
              );
              if (productId != null) {
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) => ProductScreen(productId: productId),
                );
              }
            }
            return null;
          },
        ),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late Future<bool> _isLoggedInFuture;

  @override
  void initState() {
    super.initState();
    _isLoggedInFuture = _validateSessionAndLoadLanguage();
  }

  Future<bool> _validateSessionAndLoadLanguage() async {
    final isLoggedIn = await AuthService.validateSession();
    if (!isLoggedIn) return false;
    final result = await AuthService.getProfile();
    if (result['success'] == true && result['data'] is User) {
      final user = result['data'] as User;
      await AppLocaleService.applyAccountPreference(
        preferredLanguage: user.preferredLanguage,
        countryCode: user.countryCode,
      );
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isLoggedInFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data == true) {
          return const MainScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
