// rules-check.js
// tries the writes the rules are supposed to stop, and the ones they allow
// run the emulators and tools/seed.js first, then: node tools/rules-check.js

const AUTH = 'http://localhost:9099';
const FIRESTORE = 'http://localhost:8080';
const PROJECT = 'message-board-hw02-4360';
const DB = '%28default%29';
const BASE = `${FIRESTORE}/v1/projects/${PROJECT}/databases/${DB}`;
const DOCS = `${BASE}/documents`;

async function tokenFor(email, password) {
  const res = await fetch(
    `${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    },
  );
  const data = await res.json();
  if (!data.idToken) {
    throw new Error('sign in failed for ' + email);
  }
  return { token: data.idToken, uid: data.localId };
}

function headers(token) {
  const h = { 'Content-Type': 'application/json' };
  if (token) {
    h.Authorization = 'Bearer ' + token;
  }
  return h;
}

async function code(res) {
  return res.status;
}

async function main() {
  const ada = await tokenFor('ada@test.com', 'test1234');
  const grace = await tokenFor('grace@test.com', 'test1234');

  // find a message that belongs to grace
  const list = await fetch(`${DOCS}/messages`, { headers: headers(ada.token) });
  const docs = (await list.json()).documents || [];
  const graceDoc = docs.find(
    (d) => d.fields.authorUid.stringValue === grace.uid,
  );
  const adaDoc = docs.find((d) => d.fields.authorUid.stringValue === ada.uid);
  if (!graceDoc || !adaDoc) {
    throw new Error('seed the emulator first: node tools/seed.js');
  }

  const cases = [];

  // signed out read
  cases.push([
    'signed-out read of messages',
    await code(await fetch(`${DOCS}/messages`)),
    403,
  ]);

  // signed out create
  cases.push([
    'signed-out create of a message',
    await code(
      await fetch(`${DOCS}/messages`, {
        method: 'POST',
        headers: headers(null),
        body: JSON.stringify({ fields: { text: { stringValue: 'nope' } } }),
      }),
    ),
    403,
  ]);

  // ada updates grace's message
  cases.push([
    'update another user\'s message',
    await code(
      await fetch(`${DOCS}/${graceDoc.name.split('/documents/')[1]}?updateMask.fieldPaths=text`, {
        method: 'PATCH',
        headers: headers(ada.token),
        body: JSON.stringify({ fields: { text: { stringValue: 'taken over' } } }),
      }),
    ),
    403,
  ]);

  // ada deletes grace's message
  cases.push([
    'delete another user\'s message',
    await code(
      await fetch(`${DOCS}/${graceDoc.name.split('/documents/')[1]}`, {
        method: 'DELETE',
        headers: headers(ada.token),
      }),
    ),
    403,
  ]);

  // ada creates a message that claims grace wrote it
  cases.push([
    'create with a forged authorUid',
    await code(
      await fetch(`${BASE}/documents:commit`, {
        method: 'POST',
        headers: headers(ada.token),
        body: JSON.stringify({
          writes: [
            {
              update: {
                name: `projects/${PROJECT}/databases/(default)/documents/messages/forged-${Date.now()}`,
                fields: {
                  text: { stringValue: 'written by ada, signed by grace' },
                  authorUid: { stringValue: grace.uid },
                  authorName: { stringValue: 'Grace Hopper' },
                  editedAt: { nullValue: null },
                  schemaVersion: { integerValue: '1' },
                },
              },
              updateTransforms: [
                { fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' },
              ],
            },
          ],
        }),
      }),
    ),
    403,
  ]);

  // ada sends her own timestamp instead of the server clock
  cases.push([
    'create with a client timestamp',
    await code(
      await fetch(`${BASE}/documents:commit`, {
        method: 'POST',
        headers: headers(ada.token),
        body: JSON.stringify({
          writes: [
            {
              update: {
                name: `projects/${PROJECT}/databases/(default)/documents/messages/backdated-${Date.now()}`,
                fields: {
                  text: { stringValue: 'backdated' },
                  authorUid: { stringValue: ada.uid },
                  authorName: { stringValue: 'Ada Lovelace' },
                  createdAt: { timestampValue: '2020-01-01T00:00:00Z' },
                  editedAt: { nullValue: null },
                  schemaVersion: { integerValue: '1' },
                },
              },
            },
          ],
        }),
      }),
    ),
    403,
  ]);

  // ada posts 501 characters
  cases.push([
    'create with 501 characters',
    await code(
      await fetch(`${BASE}/documents:commit`, {
        method: 'POST',
        headers: headers(ada.token),
        body: JSON.stringify({
          writes: [
            {
              update: {
                name: `projects/${PROJECT}/databases/(default)/documents/messages/long-${Date.now()}`,
                fields: {
                  text: { stringValue: 'x'.repeat(501) },
                  authorUid: { stringValue: ada.uid },
                  authorName: { stringValue: 'Ada Lovelace' },
                  editedAt: { nullValue: null },
                  schemaVersion: { integerValue: '1' },
                },
              },
              updateTransforms: [
                { fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' },
              ],
            },
          ],
        }),
      }),
    ),
    403,
  ]);

  // ada reads grace's user document
  cases.push([
    'read another user\'s user document',
    await code(await fetch(`${DOCS}/users/${grace.uid}`, { headers: headers(ada.token) })),
    403,
  ]);

  // control: ada reads her own user document
  cases.push([
    'read own user document (should pass)',
    await code(await fetch(`${DOCS}/users/${ada.uid}`, { headers: headers(ada.token) })),
    200,
  ]);

  // control: ada edits her own message
  cases.push([
    'edit own message (should pass)',
    await code(
      await fetch(`${DOCS}/${adaDoc.name.split('/documents/')[1]}?updateMask.fieldPaths=text`, {
        method: 'PATCH',
        headers: headers(ada.token),
        body: JSON.stringify({ fields: { text: { stringValue: 'first message on the board' } } }),
      }),
    ),
    200,
  ]);

  let bad = 0;
  for (const [name, got, want] of cases) {
    const ok = got === want;
    if (!ok) {
      bad++;
    }
    console.log(`${ok ? 'ok  ' : 'FAIL'}  ${String(got).padEnd(4)} (want ${want})  ${name}`);
  }
  console.log('');
  console.log(`${cases.length - bad}/${cases.length} as expected`);
  if (bad > 0) {
    process.exit(1);
  }
}

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
