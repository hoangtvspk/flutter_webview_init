import 'package:firebase_core/firebase_core.dart';

const Map<String, Map<String, FirebaseOptions>> firebaseConfigs = {
  'testing': {
    'android': FirebaseOptions(
      apiKey: 'AIzaSyAucfJrw3E3FaZZ0ScmlgJB64olBagfFEg',
      appId: '1:539861984523:android:832fe560599991765d6e0e',
      messagingSenderId: '539861984523',
      projectId: 'ezsale-dev',
      storageBucket: 'ezsale-dev.firebasestorage.app',
    ),
    'ios': FirebaseOptions(
      apiKey: 'AIzaSyA3ZEz7F_Vo6CpDamTo-DnaJe2URnb4Dco',
      appId: '1:539861984523:ios:89e4b4078ff89bc65d6e0e',
      messagingSenderId: '539861984523',
      projectId: 'ezsale-dev',
      storageBucket: 'ezsale-dev.firebasestorage.app',
    ),
  },
  'production': {
    'android': FirebaseOptions(
      apiKey: 'AIzaSyCbtSni-8lEdVAFxV0Me9dioi-XLvGQcnQ',
      appId: '1:791650251315:android:6a41ed7443983d7e93e946',
      messagingSenderId: '791650251315',
      projectId: 'easysales-38bc2',
      storageBucket: 'easysales-38bc2.firebasestorage.app',
    ),
    'ios': FirebaseOptions(
      apiKey: 'AIzaSyD-g3gHAZ-mzrK3DQMKe9UdbUa15yT4KoE',
      appId: '1:791650251315:ios:e06aa60014f4dce293e946',
      messagingSenderId: '791650251315',
      projectId: 'easysales-38bc2',
      storageBucket: 'easysales-38bc2.firebasestorage.app',
    ),
  },
};
