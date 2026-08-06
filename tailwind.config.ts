import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    "./lib/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        ink: "#172018",
        sage: "#dce8d5",
        leaf: "#356b43",
        tomato: "#c75c3b",
        cream: "#fbfaf5",
        mustard: "#e1ad4f",
      },
      boxShadow: {
        soft: "0 16px 40px rgba(35, 54, 36, 0.08)",
      },
    },
  },
  plugins: [],
};

export default config;
