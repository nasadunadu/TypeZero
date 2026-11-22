import React from "react";
import ReactDOM from "react-dom/client";
import { FloatingPill } from "./components/FloatingPill";
import "./theme.css";

ReactDOM.createRoot(document.getElementById("pill-root")!).render(
  <React.StrictMode>
    <FloatingPill />
  </React.StrictMode>,
);
