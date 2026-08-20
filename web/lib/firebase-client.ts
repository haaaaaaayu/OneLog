import { getApp, getApps, initializeApp, type FirebaseOptions } from "firebase/app";
import {
  browserLocalPersistence,
  deleteUser,
  getAuth,
  GoogleAuthProvider,
  onAuthStateChanged,
  setPersistence,
  signInAnonymously,
  signInWithPopup,
  signOut,
  type Auth,
  type User,
} from "firebase/auth";

const firebaseConfig: FirebaseOptions = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
};

function configured() {
  return Object.values(firebaseConfig).every((value) => typeof value === "string" && value.length > 0);
}

export function getOneLogAuth(): Auth {
  if (!configured()) {
    throw new Error("Firebase 웹 설정이 없습니다.");
  }
  const app = getApps().length ? getApp() : initializeApp(firebaseConfig);
  return getAuth(app);
}

async function prepareAuth() {
  const auth = getOneLogAuth();
  await setPersistence(auth, browserLocalPersistence);
  return auth;
}

export async function startWithGoogle() {
  // Open the OAuth window in the same user gesture. Waiting on persistence first
  // causes iOS Safari to treat the popup as unsolicited and block it.
  const auth = getOneLogAuth();
  const provider = new GoogleAuthProvider();
  provider.setCustomParameters({ prompt: "select_account" });
  const result = await signInWithPopup(auth, provider);
  return result.user;
}

export async function startOnThisDevice() {
  const auth = await prepareAuth();
  const result = await signInAnonymously(auth);
  return result.user;
}

export async function signOutOneLog() {
  await signOut(getOneLogAuth());
}

export async function deleteOneLogAccount() {
  const user = getOneLogAuth().currentUser;
  if (user) await deleteUser(user);
}

export function observeOneLogAuth(callback: (user: User | null) => void) {
  return onAuthStateChanged(getOneLogAuth(), callback);
}
