import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "한끼로그 | 남은 재료를 다음 한 끼로",
  description: "먹고 싶은 요리부터 남은 재료 활용까지 연결하는 식사 플래너",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="ko">
      <body>{children}</body>
    </html>
  );
}
