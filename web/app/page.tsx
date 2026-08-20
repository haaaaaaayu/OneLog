"use client";

import {
  ArrowUp,
  Bell,
  CalendarDays,
  Check,
  ChevronLeft,
  ChevronRight,
  Clock3,
  CookingPot,
  Ellipsis,
  Heart,
  LogOut,
  MapPin,
  Navigation,
  Plus,
  Search,
  Send,
  Sparkles,
  Trash2,
  WalletCards,
  X,
} from "lucide-react";
import { useEffect, useLayoutEffect, useState } from "react";
import { deleteOneLogAccount, observeOneLogAuth, signOutOneLog, startOnThisDevice, startWithGoogle } from "../lib/firebase-client";

type Tab = "home" | "recipe" | "meals" | "share";
type Route =
  | { kind: "main" }
  | { kind: "recipe"; id: string }
  | { kind: "favorites" }
  | { kind: "plan"; step: number }
  | { kind: "ai" }
  | { kind: "shopping" }
  | { kind: "cooking"; id: string }
  | { kind: "cooked"; id: string }
  | { kind: "leftovers" }
  | { kind: "profile" }
  | { kind: "settings" }
  | { kind: "notifications" }
  | { kind: "notificationSettings" }
  | { kind: "neighborhood" }
  | { kind: "schedule"; id: string }
  | { kind: "legal"; document: "terms" | "privacy" | "licenses" }
  | { kind: "weekly" }
  | { kind: "createShare" }
  | { kind: "requests" }
  | { kind: "shareChat" };

type Preferences = {
  birth: string;
  neighborhood: string;
  skill: string;
  cookTime: string;
  tools: string[];
  dislikes: string[];
  allergies: string[];
  neighborhoodVerified: boolean;
};

type Recipe = {
  id: string;
  title: string;
  image: string;
  meal: string;
  cuisine: string;
  minutes: number;
  ingredients: string[];
  steps: string[];
};

const A = "/assets/";

const defaultPreferences: Preferences = {
  birth: "2003 . 03 . 27",
  neighborhood: "서울 성동구 성수동",
  skill: "중수",
  cookTime: "20분 이하",
  tools: ["프라이팬", "전자레인지", "냄비"],
  dislikes: ["오이", "버섯"],
  allergies: ["견과류"],
  neighborhoodVerified: false,
};

function scrollToTop() {
  window.scrollTo({ top: 0, left: 0, behavior: "auto" });
  document.documentElement.scrollTop = 0;
  document.body.scrollTop = 0;
}

function authErrorMessage(error: unknown) {
  const code = typeof error === "object" && error && "code" in error ? String(error.code) : "";
  if (code.includes("popup-closed-by-user") || code.includes("cancelled-popup-request")) return "로그인이 취소됐어요. 다시 시도해 주세요.";
  if (code.includes("popup-blocked")) return "팝업이 차단됐어요. Safari의 팝업 차단을 잠시 해제해 주세요.";
  if (code.includes("unauthorized-domain")) return "이 주소에서는 Google 로그인을 사용할 수 없어요.";
  if (code.includes("network-request-failed")) return "네트워크 연결을 확인하고 다시 시도해 주세요.";
  return "로그인을 완료하지 못했어요. 잠시 후 다시 시도해 주세요.";
}

const recipes: Recipe[] = [
  {
    id: "chicken",
    title: "간장 닭다리 덮밥",
    image: `${A}RecipeChickenDonburi.webp`,
    meal: "점심",
    cuisine: "일식",
    minutes: 20,
    ingredients: ["닭다리살 120g", "양파 1/4개", "진간장 1큰술", "밥 1공기"],
    steps: ["닭다리살과 양파를 먹기 좋게 썰어요.", "팬에 닭을 노릇하게 굽고 양파를 넣어요.", "간장 양념을 졸인 뒤 밥 위에 올려요."],
  },
  {
    id: "tofu",
    title: "두부 김치",
    image: `${A}RecipeTofuKimchi.webp`,
    meal: "점심",
    cuisine: "한식",
    minutes: 15,
    ingredients: ["두부 1/2모", "김치 120g", "대파 10g", "참기름 1작은술"],
    steps: ["두부를 데워 물기를 빼요.", "김치와 대파를 팬에 볶아요.", "접시에 두부와 볶은 김치를 함께 담아요."],
  },
  {
    id: "tuna",
    title: "참치 마요 주먹밥",
    image: `${A}RecipeTunaMayoRice.webp`,
    meal: "아침",
    cuisine: "한식",
    minutes: 10,
    ingredients: ["밥 1공기", "참치 1/2캔", "마요네즈 1큰술", "김가루 5g"],
    steps: ["참치의 기름을 빼요.", "밥과 재료를 골고루 섞어요.", "한입 크기로 동그랗게 빚어요."],
  },
  {
    id: "cabbage",
    title: "양배추 달걀볶음",
    image: `${A}RecipeCabbageEgg.webp`,
    meal: "저녁",
    cuisine: "한식",
    minutes: 12,
    ingredients: ["양배추 120g", "달걀 2개", "소금 1꼬집", "식용유 1작은술"],
    steps: ["양배추를 가늘게 썰어요.", "팬에 양배추를 볶아요.", "달걀을 넣고 부드럽게 익혀요."],
  },
  {
    id: "kimchi",
    title: "김치 볶음밥",
    image: `${A}RecipeKimchiFriedRice.webp`,
    meal: "저녁",
    cuisine: "한식",
    minutes: 15,
    ingredients: ["밥 1공기", "김치 100g", "달걀 1개", "대파 10g"],
    steps: ["김치와 대파를 잘게 썰어요.", "팬에 김치를 볶고 밥을 넣어요.", "달걀 프라이를 올려 완성해요."],
  },
  {
    id: "cucumber",
    title: "오이 참치 비빔밥",
    image: `${A}RecipeCucumberTuna.webp`,
    meal: "점심",
    cuisine: "한식",
    minutes: 10,
    ingredients: ["오이 1/2개", "참치 1/2캔", "밥 1공기", "고추장 1큰술"],
    steps: ["오이를 얇게 썰어요.", "참치의 기름을 빼요.", "밥 위에 재료와 양념을 올려 비벼요."],
  },
];

const menu = [
  { tab: "home" as Tab, label: "홈", icon: "NavHome.svg" },
  { tab: "recipe" as Tab, label: "레시피", icon: "NavRecipe.svg" },
  { tab: "meals" as Tab, label: "식단관리", icon: "NavPlan.svg" },
  { tab: "share" as Tab, label: "재료소분", icon: "NavShare.svg" },
];

function asset(name: string) {
  return `${A}${name}`;
}

function won(value: number) {
  return `${value.toLocaleString("ko-KR")}원`;
}

function Brand({ compact = false }: { compact?: boolean }) {
  return (
    <div className={compact ? "brand compact" : "brand"}>
      <img src={asset("BrandWordmark.png")} alt="한끼로그" />
      <span>내 취향 한끼부터, 남은 재료까지</span>
    </div>
  );
}

function PrimaryButton({ children, onClick, dark = false, disabled = false }: { children: React.ReactNode; onClick?: () => void; dark?: boolean; disabled?: boolean }) {
  return (
    <button className={`primary-button ${dark ? "dark" : ""}`} onClick={onClick} disabled={disabled}>
      {children}
    </button>
  );
}

function RoundBack({ onClick }: { onClick: () => void }) {
  return (
    <button className="round-back" onClick={onClick} aria-label="뒤로">
      <ChevronLeft size={26} strokeWidth={2.3} />
    </button>
  );
}

function BottomNav({ active, onSelect }: { active: Tab; onSelect: (tab: Tab) => void }) {
  return (
    <nav className="bottom-nav" aria-label="주 메뉴">
      {menu.map((item) => (
        <button key={item.tab} className={active === item.tab ? "active" : ""} onClick={() => onSelect(item.tab)}>
          <span className="nav-icon"><img src={asset(item.icon)} alt="" /></span>
          <span>{item.label}</span>
        </button>
      ))}
    </nav>
  );
}

const neighborhoodResults = [
  ["성수동1가", "서울특별시 성동구 성수동1가"],
  ["성수동2가", "서울특별시 성동구 성수동2가"],
  ["성수1가제1동", "서울특별시 성동구 성수1가제1동"],
  ["성수1가제2동", "서울특별시 성동구 성수1가제2동"],
  ["서울숲2길", "서울특별시 성동구 서울숲2길"],
];

function NeighborhoodVerification({ close, complete }: { close: () => void; complete: (neighborhood: string) => void }) {
  const [stage, setStage] = useState<"search" | "confirm">("search");
  const [query, setQuery] = useState("");
  const [locationStatus, setLocationStatus] = useState("");
  const results = neighborhoodResults.filter(([name, address]) => !query.trim() || `${name} ${address}`.includes(query.trim()));
  const useCurrentLocation = () => {
    if (!navigator.geolocation) {
      setLocationStatus("이 브라우저에서는 위치 확인을 지원하지 않아요. 검색으로 선택해 주세요.");
      return;
    }
    setLocationStatus("현재 위치를 한 번 확인하고 있어요…");
    navigator.geolocation.getCurrentPosition(
      () => setStage("confirm"),
      () => setLocationStatus("위치 권한 없이도 동네를 검색해 인증할 수 있어요."),
      { enableHighAccuracy: false, timeout: 10000, maximumAge: 600000 },
    );
  };
  useLayoutEffect(scrollToTop, [stage]);

  if (stage === "confirm") {
    return (
      <main className="detail-screen neighborhood-screen">
        <header className="overlay-header"><RoundBack onClick={() => setStage("search")} /><h1>동네 인증</h1><span /></header>
        <section className="neighborhood-map" aria-label="성수동 반경 1km 지도 미리보기">
          <i /><i /><i /><i />
          <span className="map-radius">반경 1km</span>
          <div className="map-circle"><b>성수동</b><MapPin fill="#ffca12" /></div>
        </section>
        <section className="neighborhood-confirm-card"><h2>서울 성동구 성수동</h2><p>이 위치가 맞으면 인증을 완료해 주세요.</p></section>
        <div className="sticky-button"><PrimaryButton dark onClick={() => complete("서울 성동구 성수동")}>이 동네로 인증하기</PrimaryButton></div>
      </main>
    );
  }

  return (
    <main className="detail-screen neighborhood-screen">
      <header className="overlay-header"><RoundBack onClick={close} /><h1>동네 인증</h1><span /></header>
      <section className="neighborhood-search-content">
        <label className="neighborhood-search"><Search size={18} /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="동네, 도로명, 건물명으로 검색" /></label>
        <button className="location-button" onClick={useCurrentLocation}><Navigation size={18} fill="currentColor" />현재 위치로 찾기</button>
        <p className="location-copy">{locationStatus || "위치 권한을 허용하면 지금 있는 동네로 바로 인증돼요."}</p>
        <h2>검색 결과</h2>
        <div className="neighborhood-results">{results.map(([name, address]) => <button key={name} onClick={() => setStage("confirm")}><MapPin size={17} fill="#ffca12" /><span><b>{name}</b><small>{address}</small></span><ChevronRight size={16} /></button>)}</div>
        <p className="neighborhood-footnote">인증한 동네 반경 1km 이웃과 재료를 나눌 수 있어요.</p>
      </section>
    </main>
  );
}

function Onboarding({ onDone, initialStep = 0, initialMode = "dislike", initialPreferences = defaultPreferences }: { onDone: (nickname: string, preferences: Preferences) => void; initialStep?: number; initialMode?: "dislike" | "allergy"; initialPreferences?: Preferences }) {
  const [step, setStep] = useState(initialStep);
  const [nickname, setNickname] = useState("");
  const [birth, setBirth] = useState(initialPreferences.birth);
  const [neighborhood, setNeighborhood] = useState(initialPreferences.neighborhood);
  const [skill, setSkill] = useState(initialPreferences.skill);
  const [cookTime, setCookTime] = useState(initialPreferences.cookTime);
  const [tools, setTools] = useState(initialPreferences.tools);
  const [dislikes, setDislikes] = useState(initialPreferences.dislikes);
  const [allergies, setAllergies] = useState(initialPreferences.allergies);
  const [neighborhoodVerified, setNeighborhoodVerified] = useState(initialPreferences.neighborhoodVerified);
  const [neighborhoodOpen, setNeighborhoodOpen] = useState(false);
  const [authLoading, setAuthLoading] = useState<"google" | "device" | "">("");
  const [authError, setAuthError] = useState("");
  const [customExclusion, setCustomExclusion] = useState("");

  const toggleIn = (value: string, setter: React.Dispatch<React.SetStateAction<string[]>>) => setter((old) => old.includes(value) ? old.filter((item) => item !== value) : [...old, value]);
  const preferences = { birth, neighborhood, skill, cookTime, tools, dislikes, allergies, neighborhoodVerified };
  const finish = () => onDone(nickname || "한끼", preferences);
  const addCustomExclusion = () => {
    const value = customExclusion.trim();
    if (!value || selected.includes(value)) return;
    setter((old) => [...old, value]);
    setCustomExclusion("");
  };

  useLayoutEffect(() => {
    scrollToTop();
  }, [step]);

  const beginGoogle = async () => {
    setAuthError("");
    setAuthLoading("google");
    try {
      const user = await startWithGoogle();
      setNickname(user.displayName?.trim() || "");
      setStep(1);
    } catch (error) {
      setAuthError(authErrorMessage(error));
    } finally {
      setAuthLoading("");
    }
  };

  const beginOnDevice = async () => {
    setAuthError("");
    setAuthLoading("device");
    try {
      await startOnThisDevice();
      setStep(1);
    } catch (error) {
      setAuthError(authErrorMessage(error));
    } finally {
      setAuthLoading("");
    }
  };

  if (neighborhoodOpen) return <NeighborhoodVerification close={() => setNeighborhoodOpen(false)} complete={(value) => { setNeighborhood(value); setNeighborhoodVerified(true); setNeighborhoodOpen(false); }} />;

  if (step === 0) {
    return (
      <main className="onboarding login-screen">
        <img className="login-mascot" src={asset("LoginMascot.png")} alt="" />
        <h1>한끼로그를 시작해볼까요?</h1>
        <p>예산에 맞춰 식단부터 장보기,<br />남은 재료 활용까지 계획해드려요.</p>
        <div className="login-actions">
          <button className="google-button" onClick={beginGoogle} disabled={Boolean(authLoading)}><img src={asset("IconGoogle.svg")} alt="" />{authLoading === "google" ? "Google 연결 중…" : "Google 계정으로 시작하기"}</button>
          <button className="device-button" onClick={beginOnDevice} disabled={Boolean(authLoading)}>{authLoading === "device" ? "기기 계정 준비 중…" : "기기 전용 계정으로 시작"}</button>
          {authError && <p className="auth-error" role="alert">{authError}</p>}
          <small>계속하면 이용약관 및 개인정보처리방침에 동의하게 됩니다.</small>
        </div>
      </main>
    );
  }

  const progress = Math.min(step, 3);
  const header = (
    <>
      <header className="onboarding-header">
        <button onClick={() => setStep(step - 1)} aria-label="뒤로"><ChevronLeft size={24} /></button>
        <span>{progress} / 3</span>
      </header>
      <div className="segments">{[1, 2, 3].map((item) => <i className={item <= progress ? "filled" : ""} key={item} />)}</div>
    </>
  );

  if (step === 1) {
    return (
      <main className="onboarding form-screen profile-onboarding">
        {header}
        <section className="form-copy"><h1>기본 정보를 알려주세요</h1><p>딱 맞는 식단을 추천하는 데 쓰는 정보예요.</p></section>
        <div className="profile-form-fields">
          <label>이름<input value={nickname} placeholder="닉네임을 입력해 주세요" onChange={(event) => setNickname(event.target.value)} /></label>
          <label>생년월일<input value={birth} placeholder="YYYY . MM . DD" inputMode="numeric" onChange={(event) => setBirth(event.target.value)} /></label>
          <div className="profile-field"><span className="field-label">거주지</span><button className={`neighborhood-auth ${neighborhoodVerified ? "verified" : ""}`} onClick={() => setNeighborhoodOpen(true)}><MapPin size={19} fill="#ffca12" /><b>{neighborhoodVerified ? neighborhood : "동네 인증하기"}</b>{neighborhoodVerified ? <Check size={18} /> : <ChevronRight size={18} />}</button><small>현재 위치는 동네 확인에만 한 번 사용해요</small></div>
          <fieldset className="profile-field"><legend>요리 숙련도</legend><div className="onboarding-chips three">{["하수", "중수", "고수"].map((item) => <button className={skill === item ? "selected" : ""} key={item} onClick={() => setSkill(item)}>{item}</button>)}</div></fieldset>
          <fieldset className="profile-field"><legend>선호 조리 시간</legend><div className="onboarding-chips time">{["10분 이하", "20분 이하", "30분 이상", "상관없어요"].map((item) => <button className={cookTime === item ? "selected" : ""} key={item} onClick={() => setCookTime(item)}>{item}</button>)}</div></fieldset>
        </div>
        <div className="bottom-cta onboarding-bottom"><PrimaryButton onClick={() => setStep(2)}>다음</PrimaryButton><button className="onboarding-skip" onClick={() => setStep(2)}>나중에 설정할게요</button></div>
      </main>
    );
  }

  if (step === 2) {
    return (
      <main className="onboarding form-screen tools-onboarding">
        {header}
        <section className="form-copy"><h1>어떤 조리도구가 있나요?</h1><p>선택한 도구로 만들 수 있는 레시피만 추천해요.</p></section>
        <div className="tools-count"><span>{tools.length}개 선택됨</span><button onClick={() => setTools(["프라이팬", "전자레인지", "에어프라이어", "오븐", "냄비", "믹서기"])}>전체 선택</button></div>
        <div className="tool-grid">
          {[["프라이팬", "ToolPan.svg"], ["전자레인지", "ToolMicrowave.svg"], ["에어프라이어", "ToolAirfryer.svg"], ["오븐", "ToolOven.svg"], ["냄비", "ToolPot.svg"], ["믹서기", "ToolBlender.svg"]].map(([label, icon]) => (
            <button key={label} onClick={() => toggleIn(label, setTools)} className={tools.includes(label) ? "selected" : ""}><span className="tool-icon"><img src={asset(icon)} alt="" /></span><b>{label}</b>{tools.includes(label) && <i><Check size={13} /></i>}</button>
          ))}
        </div>
        <div className="bottom-cta onboarding-bottom"><PrimaryButton onClick={() => setStep(3)}>다음</PrimaryButton><button className="onboarding-skip" onClick={() => setStep(3)}>나중에 설정할게요</button></div>
      </main>
    );
  }

  const isAllergy = step === 4 || initialMode === "allergy";
  const selected = isAllergy ? allergies : dislikes;
  const setter = isAllergy ? setAllergies : setDislikes;
  const baseValues = isAllergy ? ["해산물", "유제품", "견과류", "계란", "밀(글루텐)", "갑각류"] : ["오이", "버섯", "가지", "고수", "당근", "대파", "양파"];
  const values = [...baseValues, ...selected.filter((item) => !baseValues.includes(item))];
  return (
    <main className="onboarding form-screen exclusions-onboarding">
      {header}
      <section className="form-copy"><h1>빼고 싶은 재료가 있나요?</h1><p>{isAllergy ? "알레르기·못 먹는 재료는 레시피에서 완전히 제외됩니다." : "고른 재료가 들어간 레시피는 추천에서 빼드릴게요."}</p></section>
      <div className={`exclusion-grid ${isAllergy ? "danger" : ""}`}>{values.map((item) => <button className={selected.includes(item) ? "selected" : ""} key={item} onClick={() => toggleIn(item, setter)}>{item}</button>)}</div>
      <div className={`custom-exclusion ${isAllergy ? "danger" : ""}`}><span>＋</span><input value={customExclusion} onChange={(event) => setCustomExclusion(event.target.value)} onKeyDown={(event) => event.key === "Enter" && addCustomExclusion()} placeholder="직접 입력하기" aria-label={isAllergy ? "알레르기 재료 직접 입력" : "안 좋아하는 재료 직접 입력"} /><button onClick={addCustomExclusion}>추가</button></div>
      <p className="exclusion-hint">{isAllergy ? "안 좋아하는 재료는 이 탭에서 따로 골라주세요." : "알레르기·못 먹는 재료는 위 탭에서 따로 골라주세요."}</p>
      <div className="bottom-cta onboarding-bottom"><PrimaryButton onClick={isAllergy ? finish : () => setStep(4)}>{isAllergy ? "한끼로그 시작하기" : "다음"}</PrimaryButton><button className="onboarding-skip" onClick={isAllergy ? finish : () => setStep(4)}>{isAllergy ? "선택 없이 시작할게요" : "나중에 설정할게요"}</button></div>
    </main>
  );
}

function Home({ nickname, open, goTab, hasPlan }: { nickname: string; open: (route: Route) => void; goTab: (tab: Tab) => void; hasPlan: boolean }) {
  const [selectedDate, setSelectedDate] = useState(0);
  return (
    <main className="screen home-screen with-nav">
      <header className="brand-header"><Brand /><button onClick={() => open({ kind: "profile" })}><img src={asset("IconProfile.svg")} alt="마이페이지" /></button></header>
      <section className="home-hero">
        <img src={asset("HomeMascot.webp")} alt="" />
        <small>HANKKI LOG</small>
        <h1><b>{nickname}님</b>, 안녕하세요.</h1>
        <p>{hasPlan ? "오늘은 식단 2일차 입니다!" : "첫 식단을 계획하고 남는 재료까지 이어 써보세요."}</p>
        <button onClick={() => hasPlan ? goTab("meals") : open({ kind: "plan", step: 1 })}>{hasPlan ? "요리 만들러 가기" : "새 식단 만들기"}</button>
      </section>
      <section className="saving-card">
        <div><small>이번 달 한끼로그로</small><strong>{hasPlan ? "18,400원" : "0원"}</strong><b>절약했어요</b></div>
        <div className="saving-count"><b>{hasPlan ? "5끼" : "0끼"}</b><span>요리 완료</span></div>
      </section>
      <div className="section-heading"><div><h2><b>{nickname}님</b>의 오늘 식단</h2></div><button onClick={() => goTab("meals")}>전체 보기 ›</button></div>
      <div className="date-strip">{[["월", "17", hasPlan ? "2끼" : "0끼"], ["화", "18", hasPlan ? "1끼" : "0끼"], ["수", "19", hasPlan ? "1끼" : "0끼"], ["목", "20", hasPlan ? "1끼" : "0끼"], ["금", "21", hasPlan ? "2끼" : "0끼"]].map((date, index) => <button className={index === selectedDate ? "selected" : ""} aria-pressed={index === selectedDate} onClick={() => setSelectedDate(index)} key={date[1]}>{date.map((v) => <span key={v}>{v}</span>)}</button>)}</div>
      {hasPlan ? <div className="home-meals">
        <MealMini type="아침" title="참치 마요 주먹밥" image={asset("RecipeTunaMayoRice.webp")} meta="재료 4개 · 10분" done />
        <MealMini type="점심" title="두부 김치" image={asset("RecipeTofuKimchi.webp")} meta="재료 4개 · 15분" onClick={() => open({ kind: "cooking", id: "tofu" })} />
        <MealMini type="저녁" title="양배추 달걀볶음" image={asset("RecipeCabbageEgg.webp")} meta="재료 4개 · 12분" onClick={() => open({ kind: "cooking", id: "cabbage" })} />
      </div> : <button className="empty-home-plan" onClick={() => open({ kind: "plan", step: 1 })}>아직 식단을 계획하지 않았어요!</button>}
    </main>
  );
}

function MealMini({ type, title, image, meta, done, onClick }: { type: string; title: string; image: string; meta: string; done?: boolean; onClick?: () => void }) {
  return <button className="meal-mini" onClick={onClick}><img src={image} alt="" /><i /><div><span>{type}</span><em className={done ? "done" : ""}>{done ? "완료" : "예정"}</em></div><strong>{title}</strong><small>{meta}</small></button>;
}

function RecipeHome({ favorites, toggleFavorite, open }: { favorites: string[]; toggleFavorite: (id: string) => void; open: (route: Route) => void }) {
  const [query, setQuery] = useState("");
  const [quick, setQuick] = useState("추천");
  const [type, setType] = useState("");
  const results = recipes.filter((recipe) => {
    const searchMatch = !query || `${recipe.title} ${recipe.ingredients.join(" ")}`.includes(query);
    const quickMatch = quick === "추천" || (quick === "15분 이내" && recipe.minutes <= 15) || (quick === "밥요리" && recipe.title.includes("밥")) || quick === "간단";
    const typeMatch = !type || recipe.meal === type || recipe.cuisine === type;
    return searchMatch && quickMatch && typeMatch;
  });
  return (
    <main className="screen recipe-screen with-nav">
      <header className="recipe-header"><Brand /><button onClick={() => open({ kind: "favorites" })}><img src={asset("IconHeartFilled.svg")} alt="찜한 레시피" /></button></header>
      <section className="taste-card">
        <img src={asset("HeroVeggies.webp")} alt="" />
        <h1>찜으로 알아가는 나의 입맛</h1><p>찜할수록 취향 키워드가 구체화돼요</p>
        <label><Search size={19} /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="레시피나 재료를 검색해보세요" /></label>
      </section>
      {!query && <section className="filter-area"><ChipRow title="빠르게 찾기" values={["추천", "15분 이내", "간단", "밥요리", "국물요리", "매운요리", "다이어트"]} selected={quick} onSelect={setQuick} /><ChipRow title="종류와 끼니" values={["아침", "점심", "저녁", "한식", "양식"]} selected={type} onSelect={(value) => setType(type === value ? "" : value)} /></section>}
      <section className="recipe-results">
        <div className="results-heading"><div><h2>취향을 더 알아볼게요</h2><p>먹고 싶은 레시피에 하트를 눌러주세요</p></div><span>추천 {results.length}개</span></div>
        {results.length === 0 ? <div className="empty-search"><img src={asset("EmptySearchMascot.webp")} alt="" /><h3>검색 결과가 없어요</h3><p>다른 레시피나 재료로 검색해보세요.</p></div> : <div className="recipe-grid">{results.map((recipe) => <RecipeCard key={recipe.id} recipe={recipe} liked={favorites.includes(recipe.id)} onLike={() => toggleFavorite(recipe.id)} onOpen={() => open({ kind: "recipe", id: recipe.id })} />)}</div>}
      </section>
    </main>
  );
}

function ChipRow({ title, values, selected, onSelect }: { title: string; values: string[]; selected: string; onSelect: (value: string) => void }) {
  return <div className="chip-row"><span>{title}</span><div>{values.map((value) => <button className={selected === value ? "selected" : ""} onClick={() => onSelect(value)} key={value}>{value}</button>)}</div></div>;
}

function RecipeCard({ recipe, liked, onLike, onOpen }: { recipe: Recipe; liked: boolean; onLike: () => void; onOpen: () => void }) {
  return (
    <article className="recipe-card">
      <button className="recipe-image-button" onClick={onOpen} aria-label={`${recipe.title} 상세 보기`}><img className="recipe-image" src={recipe.image} alt="" /></button>
      <button className={`heart-button ${liked ? "liked" : ""}`} onClick={onLike} aria-label={liked ? "찜 해제" : "찜하기"}><Heart size={22} fill={liked ? "currentColor" : "none"} /></button>
      <button className="recipe-copy" onClick={onOpen}><small>{recipe.meal} · {recipe.cuisine}</small><strong>{recipe.title}</strong><span><i />{recipe.minutes}분 · 상세 보기 ›</span></button>
    </article>
  );
}

function RecipeDetail({ id, favorites, toggleFavorite, close, cook }: { id: string; favorites: string[]; toggleFavorite: (id: string) => void; close: () => void; cook: () => void }) {
  const recipe = recipes.find((item) => item.id === id) ?? recipes[0];
  return (
    <main className="detail-screen">
      <header className="overlay-header"><RoundBack onClick={close} /><h1>레시피</h1><button onClick={() => toggleFavorite(recipe.id)} aria-label={favorites.includes(recipe.id) ? "찜 해제" : "찜하기"}><Heart fill={favorites.includes(recipe.id) ? "currentColor" : "none"} /></button></header>
      <img className="detail-hero" src={recipe.image} alt="" />
      <section className="detail-copy"><small>{recipe.meal} · {recipe.cuisine}</small><h2>{recipe.title}</h2><div><span><Clock3 size={16} />{recipe.minutes}분</span><span><CookingPot size={16} />1인분</span></div></section>
      <section className="white-section"><h3>재료</h3>{recipe.ingredients.map((item) => <div className="ingredient-row" key={item}><span>{item.split(" ")[0]}</span><b>{item.split(" ").slice(1).join(" ")}</b></div>)}</section>
      <section className="white-section"><h3>조리 순서</h3>{recipe.steps.map((step, index) => <div className="step-row" key={step}><i>{index + 1}</i><p>{step}</p></div>)}</section>
      <div className="sticky-button"><PrimaryButton onClick={cook}>이 레시피로 요리하기</PrimaryButton></div>
    </main>
  );
}

function Favorites({ favorites, open, close, toggleFavorite }: { favorites: string[]; open: (route: Route) => void; close: () => void; toggleFavorite: (id: string) => void }) {
  const list = recipes.filter((recipe) => favorites.includes(recipe.id));
  return <main className="detail-screen favorites-screen"><header className="overlay-header"><RoundBack onClick={close} /><h1>찜한 레시피</h1><span /></header><section className="taste-note"><img src={asset("TasteNoteMascot.webp")} alt="" /><h2>나의 취향 노트</h2><p>한식과 15분 이내 간단 요리를 좋아해요.</p></section><div className="favorite-list">{(list.length ? list : recipes.slice(0, 2)).map((recipe) => <div key={recipe.id}><img src={recipe.image} alt="" /><button onClick={() => open({ kind: "recipe", id: recipe.id })}><b>{recipe.title}</b><span>{recipe.minutes}분 · {recipe.cuisine}</span></button><button onClick={() => toggleFavorite(recipe.id)}><Heart fill="currentColor" /></button></div>)}</div></main>;
}

function PlanFlow({ initialStep, close, openAI, complete }: { initialStep: number; close: () => void; openAI: () => void; complete: () => void }) {
  const [step, setStep] = useState(initialStep);
  const [duration, setDuration] = useState(5);
  const [budget, setBudget] = useState(30000);
  const [choice, setChoice] = useState(0);
  const [stock, setStock] = useState(["가지", "감자"]);
  const [selectedMeals, setSelectedMeals] = useState(() => Array.from({ length: 7 }, (_, day) => ["아침", "점심", "저녁"].map((meal) => `${day}-${meal}`)).flat());
  useLayoutEffect(() => {
    scrollToTop();
  }, [step]);
  const next = () => setStep((value) => Math.min(12, value + 1));
  const back = () => step === 1 ? close() : setStep((value) => value - 1);
  return (
    <main className={`plan-screen step-${step}`}>
      <header className="plan-header"><RoundBack onClick={back} /><h1>식단 만들기</h1><span>{step} / 12</span></header>
      <div className="plan-progress"><i style={{ width: `${(step / 12) * 100}%` }} /></div>
      <div className="plan-content">
        {step === 1 && <PlanDuration duration={duration} setDuration={setDuration} />}
        {step === 2 && <PlanMeals duration={duration} selectedMeals={selectedMeals} toggleMeal={(key) => setSelectedMeals((old) => old.includes(key) ? old.filter((item) => item !== key) : [...old, key])} />}
        {step === 3 && <PlanBudget budget={budget} setBudget={setBudget} />}
        {step === 4 && <PlanAnalyzing />}
        {step === 5 && <PlanOptions choice={choice} setChoice={setChoice} />}
        {step === 6 && <PlanEdit openAI={openAI} />}
        {step === 7 && <PlanFinal budget={budget} />}
        {step === 8 && <PlanIngredients />}
        {step === 9 && <PlanStock stock={stock} setStock={setStock} />}
        {step === 10 && <PlanPrice budget={budget} />}
        {step === 11 && <PlanUpgrade />}
        {step === 12 && <PlanShopping />}
      </div>
      <div className="plan-footer">{step === 4 ? <PrimaryButton onClick={next}>식단안 보기</PrimaryButton> : <PrimaryButton dark={step !== 7} onClick={step === 12 ? complete : next}>{["", "다음", "다음", "다음", "식단안 보기", "이 식단 선택", "다음", "이 식단으로 확정", "다음", "다음", "다음", "다음", "확인"][step]}</PrimaryButton>}</div>
    </main>
  );
}

function PlanDuration({ duration, setDuration }: { duration: number; setDuration: (value: number) => void }) {
  const [open, setOpen] = useState(false);
  const [cursor, setCursor] = useState({ year: 2026, month: 5 });
  const [startDay, setStartDay] = useState(15);
  const days = Array.from({ length: new Date(cursor.year, cursor.month + 1, 0).getDate() }, (_, index) => index + 1);
  const firstWeekday = new Date(cursor.year, cursor.month, 1).getDay();
  const startDate = new Date(cursor.year, cursor.month, startDay);
  const endDate = new Date(cursor.year, cursor.month, startDay + duration - 1);
  const moveMonth = (delta: number) => setCursor((old) => {
    const next = new Date(old.year, old.month + delta, 1);
    setStartDay(1);
    return { year: next.getFullYear(), month: next.getMonth() };
  });
  const dateLabel = (date: Date) => `${date.getMonth() + 1}.${date.getDate()}`;
  return (
    <section className="calendar-step">
      <img src={asset("PlanMascotDuration.webp")} alt="" />
      <small>STEP 1</small><h2>며칠 동안 준비할까요?</h2><p>시작일과 기간(최대 7일)을 골라 주세요.</p>
      <div className="calendar-card">
        <label>기간<button onClick={() => setOpen((value) => !value)} aria-expanded={open}><span>{duration}일</span><span>⌄</span></button>{open && <div className="duration-menu">{Array.from({ length: 7 }, (_, index) => index + 1).map((value) => <button className={duration === value ? "selected" : ""} onClick={() => { setDuration(value); setOpen(false); }} key={value}>{duration === value && <Check size={15} />}{value}일</button>)}</div>}</label>
        <div className="calendar-month"><button onClick={() => moveMonth(-1)} aria-label="이전 달">‹</button><b>{cursor.year}년 {cursor.month + 1}월</b><button onClick={() => moveMonth(1)} aria-label="다음 달">›</button></div>
        <div className="calendar-grid"><span className="sun">일</span><span>월</span><span>화</span><span>수</span><span>목</span><span>금</span><span className="sat">토</span>{Array.from({ length: firstWeekday }, (_, index) => <i key={`blank-${index}`} />)}{days.map((day) => { const current = new Date(cursor.year, cursor.month, day); const selected = current >= startDate && current <= endDate; return <button onClick={() => setStartDay(day)} className={`${day === startDay ? "start" : selected ? "range" : ""} ${current.getDay() === 0 ? "sun" : current.getDay() === 6 ? "sat" : ""}`} aria-pressed={day === startDay} key={day}>{day}</button>; })}</div>
        <div className="calendar-summary"><b>{cursor.month + 1}월 {startDay}일부터 {duration}일간</b><span>~ {dateLabel(endDate)}</span></div>
      </div>
      <p className="calendar-help">시작일과 기간(최대 7일)을 골라 주세요.</p>
    </section>
  );
}

function PlanMeals({ duration, selectedMeals, toggleMeal }: { duration: number; selectedMeals: string[]; toggleMeal: (key: string) => void }) {
  const counts = ["아침", "점심", "저녁"].map((meal) => selectedMeals.filter((key) => key.endsWith(meal)).length);
  return <section className="plan-form meals-step"><img className="plan-mascot-small" src={asset("PlanMascotMeals.webp")} alt="" /><small>STEP 2</small><h2>몇 끼 드실 거예요?</h2><p>일차마다 아침·점심·저녁을 선택해 주세요.</p><div className="day-meal-table"><b>일차별 끼니</b><span /><span>아침</span><span>점심</span><span>저녁</span>{Array.from({ length: duration }, (_, index) => <div className="day-meal-row" key={index}><strong>{index + 1}일차</strong>{["아침", "점심", "저녁"].map((meal) => { const key = `${index}-${meal}`; const selected = selectedMeals.includes(key); return <button className={selected ? "selected" : ""} aria-label={`${index + 1}일차 ${meal}`} aria-pressed={selected} onClick={() => toggleMeal(key)} key={meal}>{selected ? <Check size={14} /> : null}</button>; })}</div>)}</div><p className="meal-counts">아침 {counts[0]}회 · 점심 {counts[1]}회 · 저녁 {counts[2]}회로 선택했어요.</p></section>;
}

function PlanBudget({ budget, setBudget }: { budget: number; setBudget: (value: number) => void }) {
  return <section className="plan-intro budget-step"><img src={asset("PlanMascotBudget.webp")} alt="" /><small>STEP 3</small><h2>장보기를 알려주세요</h2><p>장보기 예산에 맞춰 식단을 구성해줄게요.</p><div className="budget-input"><strong>{budget.toLocaleString("ko-KR")}</strong><span>원</span></div><h3>빠른 선택</h3><div className="preset-row">{[30000, 40000, 50000].map((value) => <button className={budget === value ? "selected" : ""} onClick={() => setBudget(value)} key={value}>{value / 10000}만원</button>)}</div><div className="budget-note"><WalletCards /><b>실제 구매 비용은 더 낮아질 수 있어요</b><span>보유 재료를 확인한 뒤 남은 예산까지 계산해요.</span></div></section>;
}

function PlanAnalyzing() {
  return <section className="analyzing"><img src={asset("PlanMascotAnalyzing.webp")} alt="" /><h2>취향에 맞는 식단을<br />조합하고 있어요</h2><div className="analyzing-subtitle"><div className="loader" /><p>찜한 레시피와 선택한 조건을 함께 분석해요.</p></div><div className="analysis-card"><h3>이렇게 반영하고 있어요</h3><span><Heart size={19} />찜한 레시피와 취향<em>한식 · 밥 요리 선호</em></span><span><Sparkles size={19} />가벼운 아침 메뉴<em>부담 없는 메뉴 우선</em></span><span><WalletCards size={19} />3만원 예산<em>보유 재료 고려 예정</em></span></div></section>;
}

function PlanOptions({ choice, setChoice }: { choice: number; setChoice: (value: number) => void }) {
  const options = [{ name: "균형 중심", body: "찜과 재료 재사용을 고르게 반영", cost: 27800 }, { name: "절약 중심", body: "보유 재료를 가장 많이 활용", cost: 24300 }, { name: "간편 중심", body: "15분 안팎 메뉴를 우선", cost: 29100 }];
  return <section className="plan-form options-step"><img className="options-mascot" src={asset("PlanMascotOptions.png")} alt="" /><small>STEP 5 · 식단안</small><h2>세 가지 식단안을 준비했어요</h2><p>원하는 기준의 식단을 직접 골라주세요.</p><div className="option-list">{options.map((option, index) => <button className={choice === index ? "selected" : ""} onClick={() => setChoice(index)} key={option.name}><i>{choice === index && <span />}</i><div><b>찜 · {option.name}</b><p>{option.body}</p><strong>{won(option.cost)}</strong></div><ChevronRight /></button>)}</div></section>;
}

function PlanEdit({ openAI }: { openAI: () => void }) {
  return <section className="plan-form edit-step"><small>STEP 6 · 수정</small><h2>식단안을 확인해 주세요</h2><p>메뉴를 직접 바꾸거나 AI에게 요청할 수 있어요.</p><button className="ai-entry" onClick={openAI}><img src={asset("PlanCareMascot.webp")} alt="" /><div><small>한끼로그 AI</small><b>식단 수정 도와줘</b><span>원하는 메뉴나 조건을 말해보세요.</span></div><ChevronRight /></button><div className="meal-plan-card">{["1일차", "2일차", "3일차"].map((day, index) => <div key={day}><b>{day}</b><span>아침 · {index === 0 ? "참치 마요 주먹밥" : "양배추 달걀볶음"}</span><span>점심 · {index === 1 ? "간장 닭다리 덮밥" : "두부 김치"}</span><span>저녁 · 김치 볶음밥</span></div>)}</div></section>;
}

function PlanFinal({ budget }: { budget: number }) {
  return <section className="final-step"><img src={asset("PlanMascotFinal.png")} alt="" /><h2>이 식단으로 확정할까요?</h2><p>남는 재료를 돌려 쓰는 5일 식단이에요.</p><div className="final-selection"><h3>선택 내용</h3><div><CalendarDays /><span>식단 기간</span><b>5일</b></div><div><CookingPot /><span>선택 끼니</span><b>아침 3 · 점심 0 · 저녁 4</b></div><div><WalletCards /><span>전체 예산</span><b>{won(budget)}</b></div></div></section>;
}

const ingredientRows = [["가지", "60g"], ["감자", "115g"], ["달걀", "5개"], ["두부", "300g"], ["김치", "240g"], ["양배추", "240g"], ["참치", "2캔"]];

function PlanIngredients() {
  return <section className="plan-form ingredient-step"><small>STEP 8 · 전체 재료</small><h2>필요한 재료를 모았어요</h2><p>같은 재료는 하나로 합산했어요.</p><div className="yellow-summary"><b>5일 식단 · 15끼</b><span>총 18개 재료</span></div><div className="ingredient-list">{ingredientRows.map(([name, amount]) => <div key={name}><span>{name}</span><b>{amount}</b></div>)}</div></section>;
}

function PlanStock({ stock, setStock }: { stock: string[]; setStock: (items: string[]) => void }) {
  return <section className="plan-form ingredient-step"><small>STEP 9 · 보유 재료</small><h2>집에 있는 재료를 확인해 주세요</h2><p>현재 식단에 필요한 재료만 물어볼게요.</p><div className="ingredient-list selectable">{ingredientRows.map(([name, amount]) => { const selected = stock.includes(name); return <button className={selected ? "selected" : ""} onClick={() => setStock(selected ? stock.filter((item) => item !== name) : [...stock, name])} key={name}><i>{selected && <Check size={14} />}</i><span>{name}<small>필요 {amount}</small></span><b>{selected ? "보유 중" : "없어요"}</b></button>; })}</div></section>;
}

function PlanPrice({ budget }: { budget: number }) {
  const rows = [["양배추", "1/4통", "2,500원"], ["팽이버섯", "1봉", "1,500원"], ["차돌박이", "200g", "9,800원"], ["순두부", "1봉", "2,000원"], ["모차렐라 치즈", "100g", "3,500원"], ["식빵", "1봉", "3,000원"], ["달걀", "12구 1팩", "5,200원"]];
  return <section className="price-step"><div className="price-hero"><div><span>보유 재료 덕분에</span><b>4개 재료를 활용했어요</b></div><img src={asset("PlanCareMascot.webp")} alt="" /></div><div className="purchase-card"><header><b>사야 할 재료</b><span>7개</span></header>{rows.map((row) => <div key={row[0]}><b>{row[0]}</b><span>{row[1]}</span><strong>{row[2]}</strong></div>)}<footer><b>구매 예상</b><strong>27,500원</strong></footer></div><div className="budget-remain"><span>계획 예산 {won(budget)}</span><b>잔여 {won(budget - 27500)}</b></div></section>;
}

function PlanShopping() {
  return <section className="plan-form shopping-step"><div className="yellow-summary"><b>장보기 리스트가 완성됐어요</b><span>현재 식단의 7개 구매 재료를 판매 단위로 담았어요.</span></div><ShoppingRows compact /><p className="shopping-note">남은 식빵과 계란은 다음 아침 식단에 이어서 활용해요.</p></section>;
}

function PlanUpgrade() {
  const [selected, setSelected] = useState(0);
  const options = [["점심 · 순두부 그라탕", "해물 듬뿍 순두부 그라탕", "+2,500원"], ["1일차 아침 · 요거트 과일볼", "그릭요거트 그래놀라 볼", "+1,000원"]];
  return <section className="plan-form upgrade-step"><div className="upgrade-hero"><span>잔여 예산 <b>2,500원</b></span><h2>남은 예산으로 한 끼를 더 알차게 바꿔볼까요?</h2></div>{options.map((option, index) => <article className={selected === index ? "selected" : ""} key={option[0]}><small>{option[0]}</small><span>조금만 바꾸면</span><div><b>↑ &nbsp;{option[1]}</b><em>{option[2]}</em></div><button onClick={() => setSelected(index)}>{selected === index ? "바꿨어요 ✓" : "이걸로 바꾸기"}</button></article>)}<p>바꾸지 않아도 괜찮아요. 잔여 예산은 그대로 남아요.</p></section>;
}

type ChatMessage = { role: "user" | "assistant"; text: string; candidates?: string[] };

function AIChat({ close, apply }: { close: () => void; apply: () => void }) {
  const [messages, setMessages] = useState<ChatMessage[]>(() => {
    const greeting: ChatMessage = { role: "assistant", text: "안녕하세요! 어떤 식사를 바꿔드릴까요?" };
    if (typeof window !== "undefined" && new URLSearchParams(window.location.search).get("screen") === "ai") {
      return [
        greeting,
        { role: "user", text: "2일차 저녁을 더 가벼운 메뉴로 변경하고 싶어" },
        { role: "assistant", text: "네, 그렇다면 양배추 달걀볶음은 어떠신가요?", candidates: ["cabbage"] },
      ];
    }
    return [greeting];
  });
  const [input, setInput] = useState("");
  const [loading, setLoading] = useState(false);
  const send = async () => {
    const text = input.trim();
    if (!text || loading) return;
    setInput(""); setLoading(true); setMessages((old) => [...old, { role: "user", text }]);
    try {
      const response = await fetch("/api/ai-chat", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ message: text }) });
      const data = await response.json();
      setMessages((old) => [...old, { role: "assistant", text: data.reply, candidates: data.candidates }]);
    } catch {
      setMessages((old) => [...old, { role: "assistant", text: "요청에 맞는 간단한 메뉴를 골랐어요.", candidates: ["cabbage", "tuna"] }]);
    } finally { setLoading(false); }
  };
  return <main className="chat-screen ai-chat"><header><button onClick={close} aria-label="AI 채팅 닫기"><ChevronLeft /></button><img src={asset("LoginMascot.png")} alt="" /><div><h1>한끼로그 AI</h1></div><Ellipsis aria-hidden="true" /></header><div className="ai-note-pill">AI가 식단 수정을 도와드려요</div><section className="chat-status"><div><b>찜 · 균형 중심</b><span>5일 식단 · 총 12끼 · 시작 8월 20일 (목)</span></div><em>진행 중</em></section><div className="messages">{messages.map((message, index) => <div className={`message ${message.role}`} key={index}><p>{message.text}</p>{message.candidates && <div className="candidate-list">{message.candidates.map((id) => { const recipe = recipes.find((item) => item.id === id) ?? recipes[0]; return <article key={id}><div><b>{recipe.title}</b><span>{recipe.minutes}분 · 재료 {recipe.ingredients.length}개</span><button onClick={apply}>레시피 상세보기</button></div></article>; })}</div>}</div>)}{loading && <div className="message assistant"><p className="typing"><i /><i /><i /></p></div>}</div><div className="chat-composer"><input value={input} onChange={(event) => setInput(event.target.value)} onKeyDown={(event) => event.key === "Enter" && send()} placeholder="식단 수정을 입력해보세요" aria-label="식단 수정 요청" /><button onClick={send} disabled={!input.trim() || loading} aria-label="식단 수정 요청 보내기"><Send size={20} /></button></div></main>;
}

function Meals({ nickname, open }: { nickname: string; open: (route: Route) => void }) {
  const [selectedDay, setSelectedDay] = useState(1);
  return <main className="screen meals-screen with-nav"><div className="meals-gradient"><header className="simple-brand-header"><Brand /><button onClick={() => open({ kind: "profile" })} aria-label="마이페이지"><img src={asset("IconProfile.svg")} alt="" /></button></header><div className="meals-date-strip">{[["17", "월"], ["18", "오늘"], ["19", "수"], ["20", "목"], ["21", "금"]].map((date, index) => <button className={index === selectedDay ? "selected" : ""} aria-pressed={index === selectedDay} onClick={() => setSelectedDay(index)} key={date[0]}><b>{date[0]}</b><span>{date[1]}</span></button>)}</div><section className="meals-overview"><div className="overview-cards"><article><span>이번 식단</span><b>2 <small>/ 7끼 완료</small></b><i><em /></i></article><article><span>남은 재료</span><b>7개</b><button onClick={() => open({ kind: "leftovers" })}>보러가기 ›</button></article></div><div className="overview-mascot"><h1><span>{nickname}님,</span><br /><span>계획대로 잘하고 있어요!</span></h1><p>“오늘 저녁도 계획대로 준비해봐요!”</p><img src={asset("HomeMascot.webp")} alt="" /></div></section></div><div className="meals-heading"><h2><b>{nickname}님</b>의 {selectedDay === 1 ? "오늘" : `${17 + selectedDay}일`} 식단</h2><button onClick={() => open({ kind: "weekly" })}>전체 보기 ›</button></div><div className="meals-photo-row"><MealMini type="아침" title="참치 마요 주먹밥" image={asset("RecipeTunaMayoRice.webp")} meta="재료 4개 · 10분" done /><MealMini type="점심" title="두부 김치" image={asset("RecipeTofuKimchi.webp")} meta="재료 4개 · 15분" onClick={() => open({ kind: "cooking", id: "tofu" })} /><MealMini type="저녁" title="양배추 달걀볶음" image={asset("RecipeCabbageEgg.webp")} meta="재료 4개 · 12분" onClick={() => open({ kind: "cooking", id: "cabbage" })} /></div><button className="shopping-progress" onClick={() => open({ kind: "shopping" })}><div><b>장보기 리스트</b><span>6 / 9개 준비 ›</span></div><i><em /></i></button></main>;
}

function WeeklyMeals({ close, open }: { close: () => void; open: (route: Route) => void }) {
  const [day, setDay] = useState(1);
  const schedule = [
    ["참치 마요 주먹밥", "tuna"],
    [day % 2 ? "두부 김치" : "간장 닭다리 덮밥", day % 2 ? "tofu" : "chicken"],
    [day % 2 ? "양배추 달걀볶음" : "김치 볶음밥", day % 2 ? "cabbage" : "kimchi"],
  ];
  return <main className="detail-screen weekly-screen"><header className="overlay-header"><RoundBack onClick={close} /><h1>주간 식단</h1><span /></header><section className="meal-summary"><small>8월 17일–21일</small><h1>이번 식단</h1><p>총 7끼 중 2끼를 완료했어요.</p><strong>29%</strong><span><i style={{ width: "29%" }} /></span></section><div className="week-strip">{[["월", "17"], ["화", "18"], ["수", "19"], ["목", "20"], ["금", "21"]].map((date, index) => <button className={day === index ? "selected" : ""} aria-pressed={day === index} onClick={() => setDay(index)} key={date[1]}><span>{date[0]}</span><span>{date[1]}</span></button>)}</div><section className="daily-plan"><div className="daily-heading"><div><h2>8월 {17 + day}일 식단</h2><p>예정된 메뉴를 눌러 요리를 시작해요.</p></div><button onClick={() => open({ kind: "shopping" })}>장보기<ChevronRight size={14} /></button></div>{["아침", "점심", "저녁"].map((meal, index) => <button className={`meal-row ${day === 0 && index === 0 ? "done" : ""}`} onClick={() => open({ kind: "cooking", id: schedule[index][1] })} key={meal}><div><small>{meal}</small><b>{schedule[index][0]}</b><span>{day === 0 && index === 0 ? "완료" : "예정"}</span></div></button>)}</section><button className="schedule-entry" onClick={() => open({ kind: "schedule", id: schedule[2][1] })}>오늘 식단 변경하기<ChevronRight size={15} /></button><button className="leftover-entry" onClick={() => open({ kind: "leftovers" })}><div><CookingPot /><span><b>남은 재료 7개</b><small>먼저 쓸 재료를 확인해 보세요</small></span></div><ChevronRight /></button></main>;
}

function Cooking({ id, close, done }: { id: string; close: () => void; done: () => void }) {
  const recipe = recipes.find((item) => item.id === id) ?? recipes[0];
  return <main className="detail-screen cooking-screen"><header className="overlay-header"><RoundBack onClick={close} /><h1>요리하기</h1><button onClick={close}>닫기</button></header><section className="cooking-title"><h2>{recipe.title}</h2><p>계획한 수량으로 재고가 반영돼요.</p></section><section className="white-section"><h3>필요한 재료</h3>{recipe.ingredients.map((item) => <div className="ingredient-row" key={item}><span>{item.split(" ")[0]}</span><b>{item.split(" ").slice(1).join(" ")}</b></div>)}</section><section className="white-section"><h3>조리 순서</h3>{recipe.steps.map((step, index) => <div className="step-row" key={step}><i>{index + 1}</i><p>{step}</p></div>)}</section><div className="sticky-button"><PrimaryButton onClick={done}>요리 완료하기</PrimaryButton></div></main>;
}

function Cooked({ id, close, leftovers }: { id: string; close: () => void; leftovers: () => void }) {
  const recipe = recipes.find((item) => item.id === id) ?? recipes[0];
  return <main className="detail-screen cooked-screen"><div className="done-hero"><img src={asset("CookingDoneMascot.webp")} alt="" /><h1>맛있는 한 끼를<br />완성했어요!</h1><p>{recipe.title}에 사용한 재료를 반영했어요.</p></div><section className="used-card"><h2>사용한 재료</h2>{recipe.ingredients.slice(0, 4).map((item) => <div key={item}><span>{item.split(" ")[0]}</span><b>{item.split(" ").slice(1).join(" ")}</b><Check /></div>)}</section><div className="double-cta"><PrimaryButton onClick={leftovers}>남은 재료 보기</PrimaryButton><button onClick={close}>식단으로 돌아가기</button></div></main>;
}

function Leftovers({ close, open }: { close: () => void; open: (route: Route) => void }) {
  return <main className="detail-screen leftover-screen"><header className="overlay-header"><RoundBack onClick={close} /><h1>남은 재료</h1><span /></header><section className="leftover-hero"><h2>먼저 사용하면 좋아요</h2><p>남은 양과 사용 예정일을 기준으로 정리했어요.</p></section>{[["두부", "150g 남음", "개봉 후 냉장 보관", "tofu"], ["양배추", "1/2통 남음", "밀폐해 냉장 보관", "cabbage"], ["참치", "1캔 남음", "서늘한 곳에 보관", "tuna"]].map((item) => <article className="leftover-card" key={item[0]}><div><b>{item[0]}</b><strong>{item[1]}</strong><span>{item[2]}</span></div><button onClick={() => open({ kind: "recipe", id: item[3] })}>다음 메뉴 보기<ChevronRight size={15} /></button></article>)}</main>;
}

function ShoppingRows({ compact = false }: { compact?: boolean }) {
  const [checked, setChecked] = useState<string[]>([]);
  const rows = [["양배추", "필요 240g", "1/4통 구매"], ["팽이버섯", "필요 1봉", "1봉 구매"], ["차돌박이", "필요 180g", "200g 구매"], ["순두부", "필요 1봉", "1봉 구매"], ["모차렐라 치즈", "필요 80g", "100g 구매"], ["식빵", "필요 6장", "1봉 구매"], ["달걀", "필요 5개", "12구 1팩 구매"]];
  return <div className={`shopping-rows ${compact ? "compact" : ""}`}>{rows.map(([name, need, buy]) => <button className={checked.includes(name) ? "checked" : ""} onClick={() => setChecked((old) => old.includes(name) ? old.filter((item) => item !== name) : [...old, name])} key={name}><i>{checked.includes(name) && <Check size={16} />}</i><span><b>{name}</b><small>{need}</small></span><strong>{buy}</strong></button>)}</div>;
}

function Shopping({ close }: { close: () => void }) {
  const [done, setDone] = useState(false);
  const [checked, setChecked] = useState(["달걀", "식빵", "양파", "파", "순두부", "팽이버섯"]);
  const rows = [["달걀 12구 1팩", "6,000원", "달걀"], ["식빵 1봉", "3,200원", "식빵"], ["양파 3입 1봉", "3,000원", "양파"], ["파 1단", "2,500원", "파"], ["순두부 1팩", "1,800원", "순두부"], ["팽이버섯 1봉", "1,000원", "팽이버섯"], ["차돌박이 200g", "7,000원", "차돌박이"], ["양배추 1/4통", "2,000원", "양배추"], ["슬라이스 치즈 1팩", "3,300원", "치즈"]];
  return <main className="detail-screen shopping-screen"><header className="shopping-header"><RoundBack onClick={close} /><h1>장보기 리스트</h1><span>{checked.length}/9</span></header><section className="shopping-list-card"><h2>이번 식단에 필요한 재료</h2><p>마트 판매 단위를 기준으로 정리했어요.</p>{rows.map(([label, price, id]) => { const selected = checked.includes(id); return <button className={selected ? "checked" : ""} key={id} onClick={() => setChecked((old) => selected ? old.filter((item) => item !== id) : [...old, id])}><i>{selected && <Check size={14} />}</i><span>{label}</span><b>{price}</b></button>; })}</section><div className="shopping-total"><article><span>예상 구매 금액</span><b>29,800원</b></article><article><span>남은 예산</span><b>200원</b></article></div><div className="shopping-finish"><PrimaryButton dark onClick={() => setDone(true)}>{done ? "장보기 완료됨" : "장보기 완료"}</PrimaryButton></div></main>;
}

function Share({ nickname, open }: { nickname: string; open: (route: Route) => void }) {
  return <main className="screen share-screen with-nav"><div className="share-gradient"><header className="simple-brand-header"><Brand /><button onClick={() => open({ kind: "profile" })} aria-label="마이페이지"><img src={asset("IconProfile.svg")} alt="" /></button></header><section className="share-welcome"><img src={asset("HomeMascot.webp")} alt="" /><div><p><b>성수동</b> · 반경 1km 이웃</p><h1><b>{nickname}님</b>, 이웃과 나눠보세요</h1><span>오늘은 식단 2일차 입니다!</span></div><button onClick={() => open({ kind: "createShare" })}><Plus size={17} />소분·공동구매 시작하기</button></section></div><section className="active-shares"><header><h2>진행 중인 나눔</h2><span>2건</span></header><button onClick={() => open({ kind: "shareChat" })}><i className="plain-avatar"><img src={asset("IconProfile.svg")} alt="" /></i><div><b>보리네</b><span>저녁 7시 성수점 앞에서 만나요</span></div><em>1</em><strong>채팅 ›</strong></button><button onClick={() => open({ kind: "shareChat" })}><i className="plain-avatar"><img src={asset("IconProfile.svg")} alt="" /></i><div><b>유진</b><span>네 좋아요! 그때 뵐게요 :)</span></div><strong>채팅 ›</strong></button></section></main>;
}

function CreateShare({ close, complete, openChat }: { close: () => void; complete: () => void; openChat: () => void }) {
  const [selected, setSelected] = useState(["계란", "대파"]);
  const [neighbor, setNeighbor] = useState("보리네");
  const [posted, setPosted] = useState(false);
  const [retrySent, setRetrySent] = useState(false);

  useLayoutEffect(() => {
    scrollToTop();
  }, [posted]);

  if (posted) {
    return <main className="detail-screen share-request-sent"><header className="overlay-header"><RoundBack onClick={complete} /><h1>소분 요청</h1><span /></header><section className="request-sent-hero"><img src={asset("LoginMascot.png")} alt="" /><h2>{neighbor}에게 요청을 보냈어요</h2><p>수락하면 알림으로 알려드릴게요.<br />보통 10분 안에 답이 와요.</p><span>● &nbsp; 수락 대기 중</span></section><section className="share-summary"><h3>이렇게 나눠요</h3><div><span><b>퍼핌님</b><small>계란 5개 · 대파 1.5대</small></span><i>½</i><span><b>{neighbor}</b><small>계란 5개 · 대파 1.5대</small></span></div><footer><span>각자 낼 돈</span><b>4,150원씩</b></footer></section><button className="share-retry" onClick={() => setRetrySent(true)} disabled={retrySent}>↻ &nbsp; {retrySent ? "지니렛님에게도 요청을 보냈어요" : "답이 늦으면 지니렛님에게도 함께 보내볼까요?"}<b>{retrySent ? "완료 ✓" : "보내기"}</b></button><div className="request-sent-actions"><button onClick={complete}>요청 취소</button><PrimaryButton dark onClick={openChat}>채팅 열기</PrimaryButton></div></main>;
  }

  const ingredients = [["계란", "계란 10구 1팩", "4개 쓰고 6개 남아요 → 반반 나누면 5개씩", "−1,700원"], ["대파", "대파 1단 (3대)", "1대 쓰고 2대 남아요", "−900원"], ["두부", "두부 1모", "겹치는 이웃 없음", ""]];
  return <main className="detail-screen share-create-screen"><header className="overlay-header"><RoundBack onClick={close} /><h1>공동구매·소분</h1><span /></header><section className="share-create-intro"><h2>혼자 다 못 쓸 재료, 이웃과 조금씩 나눠요</h2><p>지금 걸어서 8분 안에 같은 재료가 필요한 이웃 2명이 있어요</p><h3>나눌 재료를 골라주세요</h3></section><div className="share-options">{ingredients.map(([id, title, copy, saving]) => { const active = selected.includes(id); return <button className={active ? "selected" : ""} onClick={() => setSelected((old) => active ? old.filter((item) => item !== id) : [...old, id])} key={id}><i>{active && <Check size={14} />}</i><span><b>{title}</b><small>{copy}</small></span><strong>{saving}</strong></button>; })}</div><h3 className="neighbor-heading">계란·대파가 겹치는 이웃</h3><div className="neighbor-list">{[["보리네", "도보 4분", "2개 겹침"], ["지니렛", "도보 8분", "1개 겹침"]].map((item) => <button className={neighbor === item[0] ? "selected" : ""} onClick={() => setNeighbor(item[0])} key={item[0]}><i className="plain-avatar" /><span><b>{item[0]} · {item[1]}</b><small>계란 · 대파 필요 · 매너온도 42°</small></span><em>{item[2]}</em></button>)}</div><div className="share-create-footer"><span>나누면 아끼는 돈</span><b>2,600원</b><PrimaryButton onClick={() => setPosted(true)}>{neighbor}에게 소분 요청 보내기</PrimaryButton></div></main>;
}

function Requests({ close, accept }: { close: () => void; accept: () => void }) {
  const [rejected, setRejected] = useState(false);
  if (rejected) return <main className="detail-screen request-screen"><header className="overlay-header"><RoundBack onClick={close} /><h1>받은 소분 요청</h1><span /></header><section className="share-created"><Check size={32} /><h2>요청을 거절했어요</h2><p>상대방에게는 요청 상태만 알려드려요.</p><PrimaryButton onClick={close}>재료소분으로 돌아가기</PrimaryButton></section></main>;
  return <main className="detail-screen request-screen"><header className="overlay-header"><RoundBack onClick={close} /><h1>받은 소분 요청</h1><span /></header><section className="request-person"><div className="plain-avatar" /><div><h2>퍼핀님이 소분을 요청했어요</h2><p>도보 3분</p></div></section><section className="request-card"><div><span>재료</span><b>계란 · 10구 중 5구 소분</b></div><div><span>희망 시간</span><b>오늘 저녁 7시</b></div><div><span>만남 장소</span><b>성수동 · 성수점 앞</b></div><div><span>정산</span><b>각 2,600원</b></div></section><section className="request-message"><h3>요청 메시지</h3><p>오늘 저녁에 계란 나눠 가지시는 거 어때요?</p></section><div className="request-actions"><button onClick={() => setRejected(true)}>거절</button><PrimaryButton dark onClick={accept}>수락하고 채팅하기</PrimaryButton></div></main>;
}

function ShareChat({ close }: { close: () => void }) {
  const [input, setInput] = useState("");
  const [messages, setMessages] = useState(["안녕하세요! 계란이랑 대파 같이 나눠요 :)", "네 좋아요! 오늘 저녁 7시에 성수점 앞 괜찮으세요?", "좋아요. 제가 미리 사둘게요. 오시면 반 나눠드릴게요."]);
  const send = () => { if (input.trim()) { setMessages((old) => [...old, input.trim()]); setInput(""); } };
  return <main className="chat-screen share-chat"><header><button onClick={close} aria-label="채팅 닫기"><ChevronLeft /></button><div className="plain-avatar" /><div><h1>보리네</h1><span>● &nbsp;도보 4분 · 매너온도 42°</span></div><Ellipsis aria-hidden="true" /></header><div className="share-match-note">계란·대파 소분이 매칭되었어요</div><section className="chat-product"><div><b>우리동네 마트 · 성수점</b><span>계란 10구 5,900원 · 대파 1단 1,800원</span><small>각자 4,150원씩 · 두 집 동전 지점</small></div><em>확정 전</em></section><div className="messages">{messages.map((message, index) => <div className={`message ${index === 1 ? "user" : "assistant"}`} key={`${message}-${index}`}><p>{message}</p></div>)}</div><div className="chat-composer"><input value={input} onChange={(event) => setInput(event.target.value)} onKeyDown={(event) => event.key === "Enter" && send()} placeholder="메시지 보내기" aria-label="메시지 보내기" /><button onClick={send} aria-label="메시지 전송"><ArrowUp size={20} /></button></div></main>;
}

type ProfileSection = "identity" | "skill" | "time" | "tools" | "exclusions";

function Profile({ nickname, preferences, profilePhoto, setProfilePhoto, close, save, open, authKind }: { nickname: string; preferences: Preferences; profilePhoto: string; setProfilePhoto: (value: string) => void; close: () => void; save: (nickname: string, preferences: Preferences) => void; open: (route: Route) => void; authKind: "google" | "device" | "" }) {
  const [section, setSection] = useState<ProfileSection | null>(null);
  const [draftName, setDraftName] = useState(nickname);
  const [draft, setDraft] = useState(preferences);
  const [photoError, setPhotoError] = useState("");
  useLayoutEffect(() => {
    scrollToTop();
  }, [section]);
  const toggleDraft = (key: "tools" | "dislikes" | "allergies", value: string) => setDraft((old) => ({ ...old, [key]: old[key].includes(value) ? old[key].filter((item) => item !== value) : [...old[key], value] }));
  const finish = () => {
    save(draftName.trim() || "한끼", draft);
    setSection(null);
  };
  const changePhoto = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;
    if (!file.type.startsWith("image/") || file.size > 2_000_000) {
      setPhotoError("2MB 이하 이미지 파일을 선택해 주세요.");
      return;
    }
    const reader = new FileReader();
    reader.onload = () => {
      if (typeof reader.result !== "string") return;
      setProfilePhoto(reader.result);
      setPhotoError("");
      try { window.localStorage.setItem("onelog-web-profile-photo", reader.result); } catch { setPhotoError("사진은 이번 화면에만 적용됐어요."); }
    };
    reader.readAsDataURL(file);
  };

  if (section === "identity") {
    return (
      <main className="detail-screen profile-edit-screen">
        <header className="overlay-header"><RoundBack onClick={() => setSection(null)} /><h1>내 정보 수정</h1><span /></header>
        <section className="profile-edit-content"><div className="profile-photo"><img src={profilePhoto} alt="프로필" /><label className="photo-change">사진 변경<input type="file" accept="image/*" onChange={changePhoto} /></label>{photoError && <small>{photoError}</small>}</div><label>닉네임<input value={draftName} maxLength={12} onChange={(event) => setDraftName(event.target.value)} /></label><label>생년월일<input value={draft.birth} onChange={(event) => setDraft((old) => ({ ...old, birth: event.target.value }))} /></label><label>거주지<button className="profile-field-button" onClick={() => open({ kind: "neighborhood" })}><span>{draft.neighborhood}</span><small>변경 ›</small></button></label><label>계정<button className="profile-field-button account" onClick={() => open({ kind: "settings" })}><img src={asset("IconGoogle.svg")} alt="" /><span>{authKind === "device" ? "기기 전용 계정" : "Google 계정으로 연동됨"}</span><small>관리 ›</small></button></label></section>
        <div className="sticky-button"><PrimaryButton dark onClick={finish}>저장하기</PrimaryButton></div>
      </main>
    );
  }

  const sheetTitle = section ? { skill: "요리 숙련도", time: "선호 조리 시간", tools: "보유 조리도구", exclusions: "불호 음식 · 알레르기" }[section] : "";
  return <main className="detail-screen profile-screen"><header className="overlay-header"><RoundBack onClick={close} /><h1>마이페이지</h1><span /></header><section className="profile-identity"><img src={profilePhoto} alt="" /><h2>{nickname}님</h2><button onClick={() => setSection("identity")}>내 정보 수정</button></section><section className="profile-saving"><p>이번 달 아낀 금액</p><div><span>밖에서 사먹는 거 보다</span><strong>18,400원</strong><b>아꼈어요!</b></div><i><em /></i><small>0원</small></section><h2 className="profile-section-title">나의 요리 설정</h2><section className="settings-list profile-settings"><button onClick={() => setSection("skill")}><span className="setting-symbol"><Sparkles /></span><span><b>요리 숙련도</b><small>{preferences.skill}</small></span><ChevronRight /></button><button onClick={() => setSection("time")}><span className="setting-symbol violet"><Clock3 /></span><span><b>선호 조리 시간</b><small>{preferences.cookTime}</small></span><ChevronRight /></button><button onClick={() => setSection("tools")}><span className="setting-symbol blue"><CookingPot /></span><span><b>보유 조리도구</b><small>{preferences.tools.join(" · ") || "설정 안 함"}</small></span><ChevronRight /></button><button onClick={() => setSection("exclusions")}><span className="setting-symbol red"><Heart /></span><span><b>불호 음식·알레르기</b><small>{[...preferences.dislikes, ...preferences.allergies].join(" · ") || "설정 안 함"}</small></span><ChevronRight /></button></section>{section && <div className="sheet-scrim" onClick={() => setSection(null)}><section className={`profile-sheet ${section}`} onClick={(event) => event.stopPropagation()}><i className="sheet-handle" /><header><h2>{sheetTitle}</h2><button onClick={() => setSection(null)} aria-label="닫기"><X size={19} /></button></header>{section === "skill" && <div className="editor-choices three">{["하수", "중수", "고수"].map((item) => <button className={draft.skill === item ? "selected" : ""} onClick={() => setDraft((old) => ({ ...old, skill: item }))} key={item}>{item}</button>)}</div>}{section === "time" && <div className="editor-choices three">{["15분 이내", "20분 안팎", "30분 이상", "상관없어요"].map((item) => <button className={draft.cookTime === item ? "selected" : ""} onClick={() => setDraft((old) => ({ ...old, cookTime: item }))} key={item}>{item}</button>)}</div>}{section === "tools" && <><p>여러 개 선택할 수 있어요</p><div className="editor-choices three">{["프라이팬", "전자레인지", "에어프라이어", "오븐", "냄비", "믹서기"].map((item) => <button className={draft.tools.includes(item) ? "selected" : ""} onClick={() => toggleDraft("tools", item)} key={item}>{item}</button>)}</div></>}{section === "exclusions" && <><h3>안 좋아하는 재료</h3><div className="editor-choices three">{["오이", "버섯", "가지", "고수", "당근", "대파"].map((item) => <button className={draft.dislikes.includes(item) ? "selected" : ""} onClick={() => toggleDraft("dislikes", item)} key={item}>{item}</button>)}</div><h3 className="allergy-title">● &nbsp;알레르기</h3><div className="editor-choices three danger">{["해산물", "유제품", "견과류", "계란", "밀(글루텐)", "갑각류"].map((item) => <button className={draft.allergies.includes(item) ? "selected" : ""} onClick={() => toggleDraft("allergies", item)} key={item}>{item}</button>)}</div></>}<PrimaryButton dark onClick={finish}>저장하기</PrimaryButton></section></div>}</main>;
}

function SettingsScreen({ close, open, reset, removeAccount, authKind }: { close: () => void; open: (route: Route) => void; reset: () => void; removeAccount: () => Promise<void>; authKind: "google" | "device" | "" }) {
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [deleteError, setDeleteError] = useState("");
  const remove = async () => {
    setDeleting(true);
    setDeleteError("");
    try {
      await removeAccount();
    } catch {
      setDeleting(false);
      setDeleteError("계정을 삭제하지 못했어요. 다시 로그인한 뒤 재시도해 주세요.");
    }
  };
  return (
    <main className="detail-screen settings-screen">
      <header className="overlay-header"><RoundBack onClick={close} /><h1>설정</h1><span /></header>
      <section>
        <h2>계정</h2>
        <div className="settings-card">
          <div className="account-status"><img src={asset("IconGoogle.svg")} alt="" /><span>{authKind === "device" ? "기기 전용 계정" : "Google 계정"}</span><small>{authKind === "device" ? "이 기기" : "연동됨"}</small></div>
          <button onClick={() => open({ kind: "notificationSettings" })}><Bell size={20} /><span>알림 설정</span><ChevronRight /></button>
        </div>
        <h2>약관·정책</h2>
        <div className="settings-card"><button onClick={() => open({ kind: "legal", document: "terms" })}><span>서비스 이용약관</span><ChevronRight /></button><button onClick={() => open({ kind: "legal", document: "privacy" })}><span>개인정보 처리방침</span><ChevronRight /></button><button onClick={() => open({ kind: "legal", document: "licenses" })}><span>오픈소스 라이선스</span><ChevronRight /></button><div className="settings-version"><span>버전 정보</span><small>1.0.0</small></div></div>
        <div className="settings-card account-actions"><button onClick={reset}><LogOut size={20} /><span>로그아웃</span><ChevronRight /></button><button className="danger" onClick={() => setConfirmDelete(true)}><Trash2 size={20} /><span>회원 탈퇴</span><ChevronRight /></button></div>
      </section>
      {confirmDelete && <div className="sheet-scrim delete-scrim" onClick={() => !deleting && setConfirmDelete(false)}><section className="delete-confirm" onClick={(event) => event.stopPropagation()}><Trash2 /><h2>계정을 삭제할까요?</h2><p>프로필과 웹에 저장된 식단 설정이 삭제되며 되돌릴 수 없어요.</p>{deleteError && <small role="alert">{deleteError}</small>}<div><button disabled={deleting} onClick={() => setConfirmDelete(false)}>취소</button><button disabled={deleting} onClick={remove}>{deleting ? "삭제 중…" : "계정 삭제"}</button></div></section></div>}
    </main>
  );
}

function NotificationSettings({ close }: { close: () => void }) {
  const [values, setValues] = useState({ request: true, chat: true, meal: true, shopping: false, report: true, marketing: false });
  const row = (key: keyof typeof values, title: string, copy?: string) => <button className="notification-toggle" onClick={() => setValues((old) => ({ ...old, [key]: !old[key] }))}><span><b>{title}</b>{copy && <small>{copy}</small>}</span><i className={values[key] ? "on" : ""}><em /></i></button>;
  return <main className="detail-screen notification-settings"><header className="overlay-header"><RoundBack onClick={close} /><h1>알림 설정</h1><span /></header><section><h2>재료 소분</h2><div className="settings-card">{row("request", "소분 요청 알림", "이웃의 소분·공동구매 요청")}{row("chat", "채팅 메시지 알림")}</div><h2>식단</h2><div className="settings-card">{row("meal", "오늘 식단 리마인더", "요리할 시간을 알려드려요")}{row("shopping", "장보기 리마인더")}{row("report", "주간 절약 리포트")}</div><h2>기타</h2><div className="settings-card">{row("marketing", "마케팅·혜택 알림", "이벤트, 할인 소식")}</div><p>기기 설정에서 한끼로그 알림이 꺼져 있으면<br />위 설정과 무관하게 알림이 오지 않아요.</p></section></main>;
}

function Notifications({ close, open }: { close: () => void; open: (route: Route) => void }) {
  const [read, setRead] = useState<string[]>([]);
  const items = [{ id: "request", title: "새 소분 요청", time: "10분 전", copy: "밀알님이 우유 2팩 공동구매를 요청했어요.", action: () => open({ kind: "requests" }) }, { id: "chat", title: "보리네님의 메시지", time: "1시간 전", copy: "오늘 저녁 7시 성수점 앞에서 만나요!", action: () => open({ kind: "shareChat" }) }, { id: "meal", title: "오늘 식단 알림", time: "오후 5:00", copy: "저녁 차돌박이 솥밥, 15분이면 완성돼요.", action: () => open({ kind: "cooking", id: "cabbage" }) }];
  const openItem = (item: typeof items[number]) => { setRead((old) => [...new Set([...old, item.id])]); item.action(); };
  return <main className="detail-screen notifications-screen"><header className="overlay-header"><RoundBack onClick={close} /><h1>알림</h1><button onClick={() => setRead(items.map((item) => item.id))}>모두 읽음</button></header><section><h2>오늘</h2><div className="notification-list">{items.map((item) => <button className={read.includes(item.id) ? "read" : ""} onClick={() => openItem(item)} key={item.id}><i /><span><b>{item.title}</b><small>{item.copy}</small></span><time>{item.time}</time>{!read.includes(item.id) && <em />}</button>)}</div><h2>이전</h2><div className="notification-list">{[["소분 완료", "감자님과 대파 나눔이 완료됐어요.", "어제"], ["절약 리포트", "이번 주 식비 12,000원을 아꼈어요!", "2일 전"]].map((item) => <article className="read" key={item[0]}><i /><span><b>{item[0]}</b><small>{item[1]}</small></span><time>{item[2]}</time></article>)}</div></section></main>;
}

function LegalScreen({ document, close }: { document: "terms" | "privacy" | "licenses"; close: () => void }) {
  const title = { terms: "서비스 이용약관", privacy: "개인정보 처리방침", licenses: "오픈소스 라이선스" }[document];
  return <main className="detail-screen legal-screen"><header className="overlay-header"><RoundBack onClick={close} /><h1>{title}</h1><span /></header><article><h2>{title}</h2><p>{document === "privacy" ? "한끼로그는 식단 추천과 계정 기능에 필요한 최소 정보만 처리합니다. 위치는 동네 인증 시 한 번 확인하며 약 100m 격자로 반올림한 값만 도보 시간 표시에 사용합니다." : document === "licenses" ? "이 웹 앱은 Next.js, React, Firebase 및 공개 라이선스 구성요소를 사용합니다. 각 구성요소의 라이선스와 저작권 고지는 배포 패키지의 원문을 따릅니다." : "한끼로그는 사용자가 선택한 레시피와 예산을 바탕으로 식단 계획을 돕습니다. 가격이 확인되지 않은 항목은 확정 금액으로 표시하지 않으며, 최종 선택과 구매 결정은 사용자에게 있습니다."}</p></article></main>;
}

function ScheduleChange({ close }: { id: string; close: () => void }) {
  const [selected, setSelected] = useState("다른 날로 미루기");
  const [done, setDone] = useState(false);
  const options = [["다른 날로 미루기", "5일 식단 안의 빈 끼니로 이동"], ["다른 메뉴로 바꾸기", "예산과 재료가 비슷한 메뉴 추천"], ["오늘만 비활성화", "재료는 차감하지 않고 그대로 보관"], ["식단에서 삭제", "남은 예산과 장보기 목록 다시 계산"]];
  return <main className="detail-screen schedule-screen"><header className="overlay-header"><RoundBack onClick={close} /><h1>식단 변경</h1><span /></header><section><h2>{done ? "변경을 반영했어요" : "차돌박이 솥밥을 어떻게 할까요?"}</h2><p>{done ? `${selected} 선택에 맞춰 장보기와 예산을 다시 계산했어요.` : "재료와 남은 예산은 선택에 맞춰 다시 계산돼요."}</p>{!done && <div>{options.map(([title, copy]) => <button className={selected === title ? "selected" : ""} onClick={() => setSelected(title)} key={title}><span><b>{title}</b><small>{copy}</small></span><ChevronRight /></button>)}</div>}<PrimaryButton dark onClick={done ? close : () => setDone(true)}>{done ? "식단으로 돌아가기" : "변경 완료"}</PrimaryButton></section></main>;
}

export default function OneLogPage() {
  const [mounted, setMounted] = useState(false);
  const [onboarded, setOnboarded] = useState(false);
  const [nickname, setNickname] = useState("한끼");
  const [tab, setTab] = useState<Tab>("home");
  const [route, setRoute] = useState<Route>({ kind: "main" });
  const [favorites, setFavorites] = useState(["chicken", "tofu"]);
  const [preferences, setPreferences] = useState(defaultPreferences);
  const [profilePhoto, setProfilePhoto] = useState(asset("ProfileAvatar.webp"));
  const [authKind, setAuthKind] = useState<"google" | "device" | "">("");
  const [hasPlan, setHasPlan] = useState(false);
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const screen = params.get("screen");
    const onboardingFixture = screen?.startsWith("onboarding") ?? false;
    const isFixture = Boolean(screen || params.get("demo") === "1");
    const restoreLocalState = () => {
      const saved = window.localStorage.getItem("onelog-web-onboarded") === "1";
      const savedName = window.localStorage.getItem("onelog-web-nickname");
      const savedPreferences = window.localStorage.getItem("onelog-web-preferences");
      const savedPhoto = window.localStorage.getItem("onelog-web-profile-photo");
      if (savedName) setNickname(savedName); else if (screen || params.get("demo") === "1") setNickname("퍼핑");
      if (savedPhoto) setProfilePhoto(savedPhoto);
      if (savedPreferences) {
        try { setPreferences({ ...defaultPreferences, ...JSON.parse(savedPreferences) }); } catch { window.localStorage.removeItem("onelog-web-preferences"); }
      }
      setHasPlan(isFixture ? screen !== "homeEmpty" : window.localStorage.getItem("onelog-web-plan-ready") === "1");
      return saved;
    };
    const applyFixtureRoute = () => {
      restoreLocalState();
      setAuthKind("google");
      if (onboardingFixture) setOnboarded(false); else setOnboarded(true);
      if (screen === "recipe") setTab("recipe");
      if (screen === "meals") setTab("meals");
      if (screen === "share") setTab("share");
      if (screen === "mypage") setRoute({ kind: "profile" });
      if (screen?.startsWith("plan")) setRoute({ kind: "plan", step: Number(screen.replace("plan", "")) || 1 });
      if (screen === "shopping") setRoute({ kind: "shopping" });
      if (screen === "ai") setRoute({ kind: "ai" });
      if (screen === "requests") setRoute({ kind: "requests" });
      if (screen === "shareChat") setRoute({ kind: "shareChat" });
      if (screen === "createShare") setRoute({ kind: "createShare" });
      if (screen === "weekly") setRoute({ kind: "weekly" });
      if (screen === "settings") setRoute({ kind: "settings" });
      if (screen === "notifications") setRoute({ kind: "notifications" });
      if (screen === "notificationSettings") setRoute({ kind: "notificationSettings" });
      if (screen === "neighborhood") setRoute({ kind: "neighborhood" });
      if (screen === "schedule") setRoute({ kind: "schedule", id: "cabbage" });
      setMounted(true);
    };
    if (isFixture) {
      if (screen !== "onboardingSplash") applyFixtureRoute();
      return;
    }

    let splashReady = false;
    let authReady = false;
    let currentUser: Parameters<Parameters<typeof observeOneLogAuth>[0]>[0] = null;
    let disposed = false;
    const finish = () => {
      if (disposed || !splashReady || !authReady) return;
      const saved = restoreLocalState();
      setOnboarded(Boolean(currentUser) && saved);
      setMounted(true);
    };
    const timer = window.setTimeout(() => { splashReady = true; finish(); }, 1100);
    let unsubscribe = () => {};
    try {
      unsubscribe = observeOneLogAuth((user) => {
        currentUser = user;
        authReady = true;
        setAuthKind(user ? (user.isAnonymous ? "device" : "google") : "");
        if (user?.displayName?.trim()) setNickname(user.displayName.trim());
        finish();
      });
    } catch {
      authReady = true;
      finish();
    }
    return () => { disposed = true; window.clearTimeout(timer); unsubscribe(); };
  }, []);
  useLayoutEffect(() => {
    if (mounted) scrollToTop();
  }, [mounted, route, tab]);
  const toggleFavorite = (id: string) => setFavorites((old) => old.includes(id) ? old.filter((item) => item !== id) : [...old, id]);
  const close = () => setRoute({ kind: "main" });
  const goTab = (next: Tab) => { setRoute({ kind: "main" }); setTab(next); };
  const saveProfile = (name: string, nextPreferences: Preferences) => {
    setNickname(name);
    setPreferences(nextPreferences);
    window.localStorage.setItem("onelog-web-nickname", name);
    window.localStorage.setItem("onelog-web-preferences", JSON.stringify(nextPreferences));
  };
  const clearLocalAccount = () => {
    window.localStorage.removeItem("onelog-web-onboarded");
    window.localStorage.removeItem("onelog-web-nickname");
    window.localStorage.removeItem("onelog-web-preferences");
    window.localStorage.removeItem("onelog-web-plan-ready");
    window.localStorage.removeItem("onelog-web-profile-photo");
    setNickname("한끼");
    setPreferences(defaultPreferences);
    setProfilePhoto(asset("ProfileAvatar.webp"));
    setOnboarded(false);
    close();
  };
  const resetAccount = async () => {
    try { await signOutOneLog(); } catch { /* The local account can still be reset offline. */ }
    clearLocalAccount();
  };
  const removeAccount = async () => {
    await deleteOneLogAccount();
    clearLocalAccount();
  };

  if (!mounted) return <div className="mobile-stage"><main className="launch-screen"><img className="launch-character" src={asset("OnboardingCharacter.png")} alt="" /><img className="launch-wordmark" src={asset("BrandWordmark.png")} alt="한끼로그" /></main></div>;
  if (!onboarded) {
    const fixture = new URLSearchParams(window.location.search).get("screen");
    const initialStep = fixture === "onboardingProfile" ? 1 : fixture === "onboardingTools" ? 2 : fixture === "onboardingDislikes" ? 3 : fixture === "onboardingAllergies" ? 4 : 0;
    return <div className="mobile-stage"><Onboarding initialStep={initialStep} initialMode={fixture === "onboardingAllergies" ? "allergy" : "dislike"} initialPreferences={preferences} onDone={(name, nextPreferences) => { saveProfile(name || "한끼", nextPreferences); window.localStorage.setItem("onelog-web-onboarded", "1"); setOnboarded(true); }} /></div>;
  }

  let content: React.ReactNode;
  if (route.kind === "recipe") content = <RecipeDetail id={route.id} favorites={favorites} toggleFavorite={toggleFavorite} close={close} cook={() => setRoute({ kind: "cooking", id: route.id })} />;
  else if (route.kind === "favorites") content = <Favorites favorites={favorites} open={setRoute} close={close} toggleFavorite={toggleFavorite} />;
  else if (route.kind === "plan") content = <PlanFlow initialStep={route.step} close={close} openAI={() => setRoute({ kind: "ai" })} complete={() => { window.localStorage.setItem("onelog-web-plan-ready", "1"); setHasPlan(true); setRoute({ kind: "main" }); setTab("meals"); }} />;
  else if (route.kind === "ai") content = <AIChat close={() => setRoute({ kind: "plan", step: 6 })} apply={() => setRoute({ kind: "plan", step: 6 })} />;
  else if (route.kind === "shopping") content = <Shopping close={close} />;
  else if (route.kind === "cooking") content = <Cooking id={route.id} close={close} done={() => setRoute({ kind: "cooked", id: route.id })} />;
  else if (route.kind === "cooked") content = <Cooked id={route.id} close={() => { close(); setTab("meals"); }} leftovers={() => setRoute({ kind: "leftovers" })} />;
  else if (route.kind === "leftovers") content = <Leftovers close={close} open={setRoute} />;
  else if (route.kind === "profile") content = <Profile nickname={nickname} preferences={preferences} profilePhoto={profilePhoto} setProfilePhoto={setProfilePhoto} close={close} save={saveProfile} open={setRoute} authKind={authKind} />;
  else if (route.kind === "settings") content = <SettingsScreen close={() => setRoute({ kind: "profile" })} open={setRoute} reset={resetAccount} removeAccount={removeAccount} authKind={authKind} />;
  else if (route.kind === "notifications") content = <Notifications close={close} open={setRoute} />;
  else if (route.kind === "notificationSettings") content = <NotificationSettings close={() => setRoute({ kind: "settings" })} />;
  else if (route.kind === "neighborhood") content = <NeighborhoodVerification close={() => setRoute({ kind: "profile" })} complete={(value) => { const nextPreferences = { ...preferences, neighborhood: value, neighborhoodVerified: true }; saveProfile(nickname, nextPreferences); setRoute({ kind: "profile" }); }} />;
  else if (route.kind === "schedule") content = <ScheduleChange id={route.id} close={() => setRoute({ kind: "weekly" })} />;
  else if (route.kind === "legal") content = <LegalScreen document={route.document} close={() => setRoute({ kind: "settings" })} />;
  else if (route.kind === "weekly") content = <WeeklyMeals close={close} open={setRoute} />;
  else if (route.kind === "createShare") content = <CreateShare close={close} complete={() => { close(); setTab("share"); }} openChat={() => setRoute({ kind: "shareChat" })} />;
  else if (route.kind === "requests") content = <Requests close={close} accept={() => setRoute({ kind: "shareChat" })} />;
  else if (route.kind === "shareChat") content = <ShareChat close={close} />;
  else content = <><div className="tab-content">{tab === "home" && <Home nickname={nickname} open={setRoute} goTab={goTab} hasPlan={hasPlan} />}{tab === "recipe" && <RecipeHome favorites={favorites} toggleFavorite={toggleFavorite} open={setRoute} />}{tab === "meals" && <Meals nickname={nickname} open={setRoute} />}{tab === "share" && <Share nickname={nickname} open={setRoute} />}</div><BottomNav active={tab} onSelect={goTab} /></>;
  return <div className="mobile-stage">{content}</div>;
}
