"use client";

import { useState } from "react";
import Map, { NavigationControl } from "react-map-gl/mapbox";
import "mapbox-gl/dist/mapbox-gl.css";

interface MapaScerttaProps {
  className?: string;
}

export default function MapaScertta({ className = "" }: MapaScerttaProps) {
  const [viewState, setViewState] = useState({
    longitude: -58.44,
    latitude: -34.60,
    zoom: 12,
  });

  const mapboxToken = process.env.NEXT_PUBLIC_MAPBOX_ACCESS_TOKEN;

  if (!mapboxToken) {
    return (
      <div className={`flex items-center justify-center bg-zinc-900 ${className}`}>
        <p className="text-red-500 font-semibold">
          Error: Token de Mapbox no configurado
        </p>
      </div>
    );
  }

  return (
    <div className={`relative ${className}`} style={{ width: "100%", height: "100%" }}>
      <Map
        {...viewState}
        onMove={(evt) => setViewState(evt.viewState)}
        mapStyle="mapbox://styles/mapbox/dark-v11"
        mapboxAccessToken={mapboxToken}
        style={{ width: "100%", height: "100%" }}
      >
        <NavigationControl position="top-right" />
      </Map>
    </div>
  );
}
