"use client";
import "@/lib/pmtiles-setup";

import { useState } from "react";
import Map, { NavigationControl } from "react-map-gl/maplibre";
import "maplibre-gl/dist/maplibre-gl.css";

interface MapaScerttaProps {
  className?: string;
}

export default function MapaScertta({ className = "" }: MapaScerttaProps) {
  const [viewState, setViewState] = useState({
    longitude: -58.44,
    latitude: -34.60,
    zoom: 12,
  });

  return (
    <div className={`relative ${className}`} style={{ width: "100%", height: "100%" }}>
      <Map
        {...viewState}
        onMove={(evt) => setViewState(evt.viewState)}
        mapStyle="https://rutmy.com/style.json"
        style={{ width: "100%", height: "100%" }}
      >
        <NavigationControl position="top-right" />
      </Map>
    </div>
  );
}
