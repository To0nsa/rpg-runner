import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:rpg_runner/firebase_app_check_bootstrap.dart';
import 'package:rpg_runner/firebase_options.dart';

const String _resultPrefix = 'APP_CHECK_NATIVE_SMOKE ';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final result = <String, Object?>{
    'tokenExchangeSucceeded': false,
    'tokenPrinted': false,
  };

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    result['activationOutcome'] = (await activateFirebaseAppCheck()).name;

    final token = await FirebaseAppCheck.instance.getToken(true);
    result['tokenExchangeSucceeded'] = token != null && token.isNotEmpty;
    result['tokenLength'] = token?.length ?? 0;
    if (token == null || token.isEmpty) {
      result['failure'] = 'empty_app_check_token';
    } else {
      try {
        await FirebaseFunctions.instanceFor(
          region: 'europe-west1',
        ).httpsCallable('playerProfileLoad').call<void>(const <String, Object?>{
          'userId': 'native-attestation-smoke',
          'sessionId': 'native-attestation-smoke',
        });
        result['callableReachedAuthGate'] = false;
        result['callableUnexpectedlySucceeded'] = true;
      } on FirebaseFunctionsException catch (error) {
        result['callableErrorCode'] = error.code;
        result['callableReachedAuthGate'] = error.code == 'unauthenticated';
      }
    }
  } on FirebaseException catch (error) {
    result['firebasePlugin'] = error.plugin;
    result['firebaseErrorCode'] = error.code;
  } on PlatformException catch (error) {
    result['platformErrorCode'] = error.code;
  } catch (error) {
    result['errorType'] = error.runtimeType.toString();
  } finally {
    // The prefix makes the single privacy-safe result easy to extract from
    // release device logs without printing the App Check token itself.
    // ignore: avoid_print
    print('$_resultPrefix${jsonEncode(result)}');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await SystemNavigator.pop();
  }
}
