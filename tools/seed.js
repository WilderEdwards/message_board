// seed.js
// fills the auth and firestore emulators with test users and messages
// run the emulators first, then: node tools/seed.js
//
// the app talks to the (default) database, so this has to as well

const AUTH = 'http://localhost:9099';
const FIRESTORE = 'http://localhost:8080';
const PROJECT = 'message-board-hw02-4360';
const DOCS = `${FIRESTORE}/v1/projects/${PROJECT}/databases/%28default%29/documents`;

const users = [
  { email: 'ada@test.com', password: 'test1234', firstName: 'Ada', lastName: 'Lovelace' },
  { email: 'grace@test.com', password: 'test1234', firstName: 'Grace', lastName: 'Hopper' },
];

async function makeUser(user) {
  let res = await fetch(
    `${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: user.email,
        password: user.password,
        returnSecureToken: true,
      }),
    },
  );

  let data = await res.json();

  // already seeded, sign in instead
  if (data.error && data.error.message === 'EMAIL_EXISTS') {
    res = await fetch(
      `${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: user.email,
          password: user.password,
          returnSecureToken: true,
        }),
      },
    );
    data = await res.json();
  }

  if (!data.localId) {
    throw new Error('could not make ' + user.email + ': ' + JSON.stringify(data));
  }

  // the emulator returns an empty display name, set a real one
  const full = `${user.firstName} ${user.lastName}`;
  await fetch(`${AUTH}/identitytoolkit.googleapis.com/v1/accounts:update?key=fake`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ idToken: data.idToken, displayName: full }),
  });

  return { ...user, uid: data.localId, full: full };
}

async function writeDoc(path, fields) {
  const res = await fetch(`${DOCS}/${path}`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      // the emulator treats this as an admin write
      Authorization: 'Bearer owner',
    },
    body: JSON.stringify({ fields }),
  });

  if (!res.ok) {
    throw new Error(path + ' failed: ' + (await res.text()));
  }
}

function text(value) {
  return { stringValue: value };
}

function stamp(value) {
  return { timestampValue: value };
}

async function main() {
  const made = [];
  for (const user of users) {
    made.push(await makeUser(user));
  }
  console.log('users:', made.map((u) => u.email + ' ' + u.uid).join(', '));

  // the user document the app writes on register, five fields
  for (const u of made) {
    await writeDoc(`users/${u.uid}`, {
      uid: text(u.uid),
      firstName: text(u.firstName),
      lastName: text(u.lastName),
      role: text('student'),
      registrationDateTime: stamp('2026-11-20T10:00:00Z'),
    });
  }

  await writeDoc('messages/seed-1', {
    text: text('first message on the board'),
    authorUid: text(made[0].uid),
    authorName: text(made[0].full),
    createdAt: stamp('2026-11-21T12:00:00Z'),
    editedAt: { nullValue: null },
    schemaVersion: { integerValue: '1' },
  });

  await writeDoc('messages/seed-2', {
    text: text('second message, from the other account'),
    authorUid: text(made[1].uid),
    authorName: text(made[1].full),
    createdAt: stamp('2026-11-21T12:05:00Z'),
    editedAt: { nullValue: null },
    schemaVersion: { integerValue: '1' },
  });

  await writeDoc('messages/seed-3', {
    text: text('a third one so the list is not empty'),
    authorUid: text(made[0].uid),
    authorName: text(made[0].full),
    createdAt: stamp('2026-11-21T12:10:00Z'),
    editedAt: { nullValue: null },
    schemaVersion: { integerValue: '1' },
  });

  console.log('user docs: 2');
  console.log('messages: seed-1, seed-2, seed-3');
}

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
