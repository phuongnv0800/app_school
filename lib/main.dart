import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:gdsc_bloc/blocs/app_functionality/user/user_cubit.dart';
import 'package:gdsc_bloc/blocs/minimal_functonality/show_twitter_spaces/show_spaces_cubit.dart';
import 'package:gdsc_bloc/data/services/repositories/notifications_repository.dart';
import 'package:gdsc_bloc/data/services/repositories/remote_config_repository.dart';
import 'package:gdsc_bloc/utilities/Widgets/not_found/no_internet_page.dart';
import 'package:gdsc_bloc/utilities/Widgets/splash_page.dart';
import 'package:gdsc_bloc/utilities/route_generator.dart';

import 'package:gdsc_bloc/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gdsc_bloc/utilities/themes.dart';
import 'package:gdsc_bloc/views/authentication/login_page.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';

import 'blocs/auth/authentication_bloc/authentication_bloc.dart';
import 'blocs/minimal_functonality/network_observer/network_bloc.dart';
import 'blocs/minimal_functonality/theme/theme_bloc.dart';
import 'data/services/providers/notification_providers.dart';

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await NotificationProviders().showImportantNotification(
    message: message.notification!.body!,
    title: message.notification!.title!,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await RemoteConfigRepository().setConfigSettings();
  FirebaseFirestore.instance.settings = Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  final directory =
      await getApplicationDocumentsDirectory(); // from path provider

  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: HydratedStorageDirectory(directory.path),
  );
  SystemChannels.textInput.invokeMethod('TextInput.hide');
  await NotificationProviders().initializeNotifications();
  await NotificationProviders().initializeFirebaseMessaging();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  FirebaseMessaging.instance.subscribeToTopic(kReleaseMode ? "prod" : 'dev');

  await NotificationProviders().getFirebaseMessagingToken();

  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(
          NotificationsRepository().notificationChannel);

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  NotificationProviders().initializeFirebaseMessaging();
  runApp(const MyApp());
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          lazy: false,
          create: (context) => NetworkBloc()..add(NetworkObserve()),
        ),
        BlocProvider(
          lazy: false,
          create: (context) => AuthenticationBloc()..add(AppStarted()),
        ),
        BlocProvider(lazy: false, create: (context) => UserCubit()..getUser()),
        BlocProvider(
            lazy: false, create: (context) => ThemeBloc()..add(GetTheme())),
        BlocProvider(
            lazy: false,
            create: (context) => ShowSpacesCubit()..showTwitterSpaces()),
      ],
      child: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, state) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: state is AppTheme && state.isDark
                ? ThemeMode.dark
                : ThemeMode.light,
            onGenerateRoute: (settings) {
              return RouteGenerator.generateRoute(settings);
            },
            debugShowCheckedModeBanner: false,
            home: BlocBuilder<NetworkBloc, NetworkState>(
              builder: (context, state) {
                if (state is NetworkFailure) {
                  return NoInternet();
                } else if (state is NetworkSuccess) {
                  return BlocBuilder<AuthenticationBloc, AuthenticationState>(
                    builder: (context, state) {
                      if (state is AuthenticationAuthenticated) {
                        return const SplashPage();
                      } else if (state is AuthenticationUnauthenticated) {
                        return LoginPage();
                      } else {
                        return const SizedBox.shrink();
                      }
                    },
                  );
                } else {
                  return const SizedBox.shrink();
                }
              },
            ),
          );
        },
      ),
    );
  }
}
