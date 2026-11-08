import 'package:flutter/material.dart';

Future<void> showPrivacy(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.88,
        child: const PrivacyStatement(),
      );
    },
  );
}

class PrivacyStatement extends StatelessWidget {
  const PrivacyStatement({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        Text('Adatkezelési nyilatkozat', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        const _P(
          'Az Ibafai Pipaklub üzemelteti a teamreg.vzsfoto.hu oldalt a Lassúsági Pipaszívó Verseny jelentkezéseihez. Ez a nyilatkozat azt írja le, milyen személyes adatot tartunk nyilván, miért, ki láthatja, és meddig.',
        ),
        const _H('Milyen adatot tartunk nyilván'),
        const _P(
          'A Google-belépésből a vezetéknevet, a keresztnevet, az e-mail-címet, a profilképet és a fiók technikai azonosítóját. A jelszavadat nem kapjuk meg, és nem tároljuk.',
        ),
        const _P(
          'A saját adatlapról a mentett nevet, valamint azt, hogy a klubtagsági kérelem folyamatban van, vagy a klubelnök jelezte, hogy az illető nem tag. A profil mentésekor azt is rögzítjük, hogy az adatkezelési nyilatkozatot elfogadtad, és ennek az időpontját. Itt tároljuk azt is, hogy melyik e-mail-fajtát kérted.',
        ),
        const _P(
          'A versenyre jelentkezésből azt, hogy melyik versenyre szól a nevezés, a kiírásban kért darabszámokat, a megjegyzést, és a csapatbesorolást, amit a klubelnök állít be.',
        ),
        const _P(
          'A működéshez a belépés időpontját, a fiók szerepét, a munkamenetet, valamint a kiküldött emlékeztető levél időpontját és szövegét is megőrizzük. Különleges adatot, például egészségügyi adatot nem kérünk.',
        ),
        const _H('Mire használjuk'),
        const _B('beléptetésre'),
        const _B('a klubtagsági kérelem elbírálására'),
        const _B('a verseny létszámának és a csapatok összeállítására'),
        const _B('értesítésre a jelentkezésről, a besorolásról, az új jelentkezőről és a többi, lent felsorolt eseményről'),
        const _P(
          'A bejelentkezett tagok az aktuális verseny jelentkezőinek nevét és csapatát látják, hogy a nevezés átlátható legyen. A profilkép ott jelenik meg, ahol a szerver elküldi.',
        ),
        const _H('E-mailek'),
        const _P(
          'Minden ilyen eseményről e-mailt küldünk a saját címedre, amíg a saját adatlapodon bekapcsolva hagyod az adott levélfajtát. A jelölés alapból be van kapcsolva. A kikapcsolt fajtából nem küldünk levelet.',
        ),
        const _B('a klubtagság elfogadásáról és elutasításáról'),
        const _B('a saját versenyjelentkezésedről'),
        const _B('az alcsoportba sorolásról'),
        const _B('az új verseny kiírásáról'),
        const _B('emlékeztetőről, ha egy nyitott versenyre még nem jelentkeztél'),
        const _P(
          'A klubelnök e-mailt kap az új klubjelentkezőről, a saját adatait törlő jelentkezőről, valamint arról, ha valaki jelentkezik egy versenyre vagy lemondja a nevezését. Ezeket a levélfajtákat a klubelnök a saját adatlapján kapcsolhatja ki.',
        ),
        const _H('Harmadik fél'),
        const _P('Az adatokat nem adjuk ki harmadik félnek, nem értékesítjük, és nem használjuk reklámra.'),
        const _P(
          'A belépés a Google azonosításával történik. A Google a saját oldalán kezeli a fiókot, és átadja nekünk a nevet, az e-mail-címet és a profilképet. A verseny adatait nem küldjük a Google-nak.',
        ),
        const _P(
          'A klub levelét a klub levelezése kézbesíti a címzettnek. A levél a megszólítást és a versennyel kapcsolatos szöveget tartalmazza. A címlistát más szervezetnek nem adjuk át.',
        ),
        const _H('Ki láthatja'),
        const _B('mindenki a saját adatait és a saját nevezését'),
        const _B('a bejelentkezett tagok az aktuális verseny jelentkezőinek nevét és csapatát'),
        const _B('a klubelnök és az admin a tagsági kérelmeket és a szervezéshez szükséges nevezéseket'),
        const _H('Meddig őrizzük'),
        const _P(
          'Az új jelentkező az Az adataim törlése gombbal törölheti a fiókját és a hozzá tartozó adatokat. A törlés egyben kijelentkeztet.',
        ),
        const _P(
          'A tag neve és nevezése addig marad meg, amíg a fiók és a nevezés az oldalon van. A nevezés a jelentkezési határidő lejárta előtt visszavonható. A fiók törlését a klubelnöktől lehet kérni.',
        ),
        const _H('Jogalap és jogok'),
        const _P(
          'Az adatkezelés a klubtagság és a versenyre jelentkezés teljesítéséhez, valamint a verseny megszervezésének jogos érdekéhez kell.',
        ),
        const _P(
          'Kérhető a tájékoztatás, a hozzáférés, a helyesbítés, a törlés, a kezelés korlátozása és tiltakozás a jogos érdeken alapuló kezelés ellen. A kérelmet a klubelnökhöz lehet eljuttatni. Panasszal a Nemzeti Adatvédelmi és Információszabadság Hatósághoz lehet fordulni (1055 Budapest, Falk Miksa utca 9-11., ugyfelszolgalat@naih.hu).',
        ),
        const _P('Hatályos: 2026. november 7.'),
      ],
    );
  }
}

class _H extends StatelessWidget {
  const _H(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _P extends StatelessWidget {
  const _P(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text),
    );
  }
}

class _B extends StatelessWidget {
  const _B(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
