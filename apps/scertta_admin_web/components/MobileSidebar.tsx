"use client";

import { useState, useEffect, type ReactNode } from "react";
import { useTheme } from "@/components/ThemeProvider";
import { Menu, X, ChevronRight } from "lucide-react";

export interface NavItem {
  id: string;
  label: string;
  icon: ReactNode;
  badge?: string;
  onClick?: () => void;
}

interface MobileSidebarProps {
  items: NavItem[];
  activeId?: string;
  headerLabel: string;
  headerSub?: string;
  onNavigate?: (id: string) => void;
  children: ReactNode;
}

export function MobileSidebar({
  items,
  activeId,
  headerLabel,
  headerSub,
  onNavigate,
  children,
}: MobileSidebarProps) {
  const [open, setOpen] = useState(false);
  const { theme } = useTheme();
  const isDark = theme === "dark";

  // Close sidebar on route change / resize to desktop
  useEffect(() => {
    const onResize = () => {
      if (window.innerWidth >= 768) setOpen(false);
    };
    window.addEventListener("resize", onResize);
    return () => window.removeEventListener("resize", onResize);
  }, []);

  // Lock body scroll when mobile sidebar is open
  useEffect(() => {
    document.body.style.overflow = open ? "hidden" : "";
    return () => { document.body.style.overflow = ""; };
  }, [open]);

  const handleNav = (item: NavItem) => {
    if (item.onClick) item.onClick();
    if (onNavigate) onNavigate(item.id);
    setOpen(false);
  };

  // ── Tokens per mode ──
  const s = {
    sidebar: isDark
      ? "bg-rutmy-deep border-r border-white/10"
      : "bg-white border-r border-rutmy-slate/10 shadow-sm",
    headerLabel: isDark ? "text-white" : "text-rutmy-deep",
    headerSub: isDark ? "text-white/50" : "text-rutmy-stone",
    item: (active: boolean) =>
      active
        ? isDark
          ? "bg-white/10 text-white border-r-2 border-rutmy-agua"
          : "bg-rutmy-deep text-white border-r-2 border-rutmy-agua"
        : isDark
          ? "text-white/60 hover:bg-white/5 hover:text-white"
          : "text-rutmy-slate hover:bg-rutmy-sand hover:text-rutmy-deep",
    badge: isDark
      ? "bg-rutmy-agua/20 text-rutmy-agua text-[10px] px-1.5 py-px rounded-full"
      : "bg-rutmy-agua/15 text-rutmy-agua text-[10px] px-1.5 py-px rounded-full font-medium",
    overlay: "bg-black/60 backdrop-blur-sm",
    hamburger: isDark
      ? "text-white/80 hover:text-white hover:bg-white/10"
      : "text-rutmy-deep hover:bg-rutmy-sand",
    logo: isDark ? "text-rutmy-agua" : "text-rutmy-agua",
    logoBg: isDark ? "bg-white/10" : "bg-rutmy-deep",
  };

  return (
    <div className="flex h-screen overflow-hidden">
      {/* ── DESKTOP SIDEBAR (≥768px) ── */}
      <aside
        className={`hidden md:flex md:flex-col md:w-60 lg:w-64 shrink-0 ${s.sidebar}`}
      >
        {/* Header */}
        <div className="px-5 py-5 border-b border-inherit">
          <div className="flex items-center gap-3">
            <div
              className={`flex h-9 w-9 items-center justify-center rounded-lg ${s.logoBg}`}
            >
              <span className={`text-sm font-black ${s.logo}`}>R</span>
            </div>
            <div className="min-w-0">
              <p
                className={`text-sm font-bold truncate ${s.headerLabel}`}
              >
                {headerLabel}
              </p>
              {headerSub && (
                <p className={`text-[11px] truncate ${s.headerSub}`}>
                  {headerSub}
                </p>
              )}
            </div>
          </div>
        </div>

        {/* Nav items */}
        <nav className="flex-1 overflow-y-auto py-2">
          {items.map((item) => (
            <button
              key={item.id}
              onClick={() => handleNav(item)}
              className={`w-full flex items-center gap-3 px-5 py-3 text-sm font-medium transition-all truncate ${s.item(activeId === item.id)}`}
            >
              <span className="shrink-0">{item.icon}</span>
              <span className="truncate">{item.label}</span>
              {item.badge && (
                <span className={`shrink-0 ml-auto ${s.badge}`}>
                  {item.badge}
                </span>
              )}
              {activeId === item.id && (
                <ChevronRight size={14} className="shrink-0 ml-auto opacity-50" />
              )}
            </button>
          ))}
        </nav>

        {/* Footer */}
        <div className={`px-5 py-3 border-t text-[10px] ${s.headerSub}`}>
          Scertta v3 · Rutmy
        </div>
      </aside>

      {/* ── MOBILE HAMBURGER (<768px) ── */}
      <div className="md:hidden fixed top-0 left-0 right-0 z-40">
        <div
          className={`flex items-center justify-between px-4 py-3 ${
            isDark ? "bg-rutmy-deep/95 backdrop-blur" : "bg-white/95 backdrop-blur border-b border-rutmy-slate/10"
          }`}
        >
          <div className="flex items-center gap-2">
            <div
              className={`flex h-7 w-7 items-center justify-center rounded-md ${s.logoBg}`}
            >
              <span className={`text-xs font-black ${s.logo}`}>R</span>
            </div>
            <span className={`text-sm font-bold truncate max-w-[160px] ${s.headerLabel}`}>
              {headerLabel}
            </span>
          </div>
          <button
            onClick={() => setOpen(!open)}
            className={`p-2 rounded-lg transition ${s.hamburger}`}
            aria-label={open ? "Cerrar menú" : "Abrir menú"}
          >
            {open ? <X size={20} /> : <Menu size={20} />}
          </button>
        </div>
      </div>

      {/* ── MOBILE OVERLAY ── */}
      {open && (
        <div
          className="md:hidden fixed inset-0 z-50 flex"
          onClick={(e) => {
            if (e.target === e.currentTarget) setOpen(false);
          }}
        >
          {/* Backdrop */}
          <div className={`absolute inset-0 ${s.overlay}`} />
          {/* Slide-in panel */}
          <div
            className={`relative w-64 max-w-[80vw] h-full overflow-y-auto animate-in slide-in-from-left ${s.sidebar}`}
          >
            <div className="flex items-center justify-between px-5 py-4 border-b border-inherit">
              <div className="flex items-center gap-3">
                <div className={`flex h-8 w-8 items-center justify-center rounded-lg ${s.logoBg}`}>
                  <span className={`text-sm font-black ${s.logo}`}>R</span>
                </div>
                <span className={`text-sm font-bold ${s.headerLabel}`}>
                  {headerLabel}
                </span>
              </div>
              <button
                onClick={() => setOpen(false)}
                className={`p-1.5 rounded-lg transition ${s.hamburger}`}
              >
                <X size={18} />
              </button>
            </div>
            <nav className="py-2">
              {items.map((item) => (
                <button
                  key={item.id}
                  onClick={() => handleNav(item)}
                  className={`w-full flex items-center gap-3 px-5 py-3 text-sm font-medium transition-all ${s.item(activeId === item.id)}`}
                >
                  <span className="shrink-0">{item.icon}</span>
                  <span className="truncate">{item.label}</span>
                  {item.badge && (
                    <span className={`shrink-0 ml-auto ${s.badge}`}>
                      {item.badge}
                    </span>
                  )}
                </button>
              ))}
            </nav>
          </div>
        </div>
      )}

      {/* ── MAIN CONTENT ── */}
      <main className="flex-1 overflow-y-auto pt-14 md:pt-0">
        {children}
      </main>
    </div>
  );
}
