# Ibafai Pipaklub

A mobilalkalmazás a [teamreg.vzsfoto.hu](https://teamreg.vzsfoto.hu) versenyjelentkezéshez készült. A tag a kiírt versenyekre nevez, a klubelnök a jelentkezőket, a versenyeket és a tagokat kezeli. A szerver külön projekt: a CakePHP API a `https://teamreg.vzsfoto.hu/api-v1` címen fut. Ehhez a mobilhoz nem kell helyben elindítani a weboldalt.

## Amire szükség van

- Git
- Flutter stable, Dart 3.13 vagy újabb. A `pubspec.yaml` ezt kéri: `sdk: ^3.13.7`
- Android SDK, benne a platform-tools (`adb`)
- JDK 17
- Android telefon USB-hibakereséssel, vagy egy emulátor

A Flutter telepítése után ellenőrizd a környezetet:

```powershell
flutter doctor
```

A doctor akkor jó, ha a Flutter és az Android toolchain pipás. Az iOS csak macOS-en fordítható, és az iOS-es Google belépés azonosítója még nincs beállítva.

## Leszedés és első indítás

1. Klónozd a repót:

```powershell
git clone https://github.com/kavezoo/teamreg.git
cd teamreg
```

2. Szedd le a csomagokat:

```powershell
flutter pub get
```

3. Csatlakoztasd a telefont, és engedélyezd rajta az USB-hibakeresést. Ellenőrizd, hogy a gép látja:

```powershell
adb devices
```

A sorban `device` álljon, ne `unauthorized`. Ha a telefon engedélyt kér, fogadd el.

4. Indítsd az alkalmazást a csatlakoztatott telefonon:

```powershell
flutter run
```

Ha több eszköz van, a `flutter devices` listájából válaszd ki az azonosítót:

```powershell
flutter run -d AZONOSITO
```

A hibakereső APK így készül és települ, ha a `flutter run` helyett csomagot szeretnél:

```powershell
flutter build apk --debug
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

## Google belépés egy másik gépen

A belépés a telefon saját Google-fiókját használja. A `lib/config.dart` fájlban a nyilvános webes ügyfélazonosító van. Titkot, jelszót vagy kulcsfájlt a repó nem tartalmaz, és nem is kell beletenni.

Minden gépen más a debug tanúsítvány. Az új gépen ki kell olvasni a SHA-1 ujjlenyomatot, és fel kell venni a Google Cloud Console-ban ahhoz az Android-ügyfélhez, amelynek a csomagneve `hu.vzsfoto.teamreg`.

```powershell
cd android
.\gradlew signingReport
```

A `Variant: debug` blokk `SHA1` sorát másold a konzolba. Enélkül a telefonon a Google belépés nem ad tokent, az alkalmazás pedig nem lép be.

A `android/local.properties`, a `key.properties` és a `*.keystore` / `*.jks` fájlok a gépen maradnak. A `.gitignore` kihagyja őket. Ne add hozzá a repóhoz.

## Hol lehet továbbfejleszteni

- A képernyők a `lib/screens` mappában vannak. A tag felülete a `member_home.dart`, az elnöké a `president_home.dart`.
- A szerverhívások az `lib/state/app_model.dart` és az `lib/api/api_client.dart` fájlban vannak.
- A szerver címe és a Google ügyfélazonosító a `lib/config.dart` fájlban van. Másik API-hoz csak a `baseUrl` értékét cseréld le.
- A világos és sötét színek a `lib/theme/club_theme.dart` fájlban vannak.
- Ellenőrzés módosítás után:

```powershell
flutter analyze
flutter test
```

## Ha az API-t is módosítod

A mobil a távoli API-t hívja. A végpont, a jogosultság vagy az adatbázis változása a `TeamRegistrationToCompetition` repóban készül. A telefon csak azután látja, ha a szerveren friss a kód:

```bash
git pull
bin/cake migrations migrate
```

Az utóbbi a `config/Migrations` mappában lévő új oszlopokat és táblákat hozza létre. Pull nélkül a régi API fut tovább, és az új hívások, például a korábbi versenyek listája, nem elérhetők.
