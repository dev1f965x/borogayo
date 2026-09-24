import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";
import { localPhotos } from "./storage/photos";
import { localStore } from "./storage/store";

const root = document.getElementById("root");
if (!root) throw new Error("index.html is missing #root");

ReactDOM.createRoot(root).render(
  <React.StrictMode>
    <App store={localStore} photos={localPhotos} />
  </React.StrictMode>,
);
