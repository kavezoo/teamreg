/*
 * A dátum, a térképcél, a névsor-sorrend és a HTML-szöveg ellenőrzése.
 * Nem indít widgetet, csak a tiszta függvényeket hívja.
 */
import 'package:flutter_test/flutter_test.dart';
import 'package:teamreg/format.dart';
import 'package:teamreg/models.dart';

void main() {
  test('a határidő napja még nyitott', () {
    final now = DateTime(2026, 11, 7, 18);
    expect(registrationClosed(DateTime(2026, 11, 7), now), isFalse);
    expect(registrationClosed(DateTime(2026, 11, 6, 23), now), isTrue);
    expect(registrationClosed(null, now), isFalse);
  });

  test('a térkép címéből cél lesz', () {
    expect(
      mapDestination('https://maps.google.com/?q=Ibafa+klub'),
      'Ibafa klub',
    );
    expect(
      mapDestination('https://www.google.com/maps/place/Ibafa/@46.15,17.92,15z'),
      '46.15,17.92',
    );
  });

  test('a névsor előbb csoport, aztán név szerint áll', () {
    expect(
      compareByAssignment(
        name: 'Kiss Anna',
        team: 'Második',
        teamPos: 2,
        otherName: 'Nagy Béla',
        otherTeam: 'Első',
        otherTeamPos: 1,
      ),
      greaterThan(0),
    );
    expect(
      compareByAssignment(
        name: 'Alma',
        team: 'Első',
        teamPos: 1,
        otherName: 'Zoltán',
        otherTeam: 'Első',
        otherTeamPos: 1,
      ),
      lessThan(0),
    );
    expect(
      compareByAssignment(
        name: 'Áron',
        team: '',
        otherName: 'Béla',
        otherTeam: 'Első',
        otherTeamPos: 5,
      ),
      greaterThan(0),
    );
  });

  test('a leírásból sima szöveg lesz', () {
    expect(plainText('<p>Első<br>második</p>'), 'Első\nmásodik');
  });

  test('a közelebbi látható verseny marad a névsorban', () {
    final later = _competition(1, DateTime(2026, 12, 1, 18));
    final sooner = _competition(2, DateTime(2026, 11, 20, 18));
    final past = _competition(3, DateTime(2026, 10, 1, 18));
    final hidden = Competition(
      id: 4,
      name: 'Rejtett',
      comment: '',
      description: '',
      mapUrl: null,
      dateCompetition: DateTime(2026, 11, 8, 18),
      dateFrom: null,
      dateDeadline: null,
      visible: false,
      pos: 0,
      created: null,
      titles: const {},
    );
    final current = currentRosterCompetition(
      [later, past, hidden, sooner],
      DateTime(2026, 11, 7),
    );
    expect(current?.id, 2);
  });
}

/// Látható tesztverseny a megadott versenyidővel.
Competition _competition(int id, DateTime when) {
  return Competition(
    id: id,
    name: 'Verseny $id',
    comment: '',
    description: '',
    mapUrl: null,
    dateCompetition: when,
    dateFrom: null,
    dateDeadline: null,
    visible: true,
    pos: 0,
    created: null,
    titles: const {},
  );
}
