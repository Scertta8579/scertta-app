module.exports = {
  forbidden: [
    {
      name: "no-circular",
      severity: "warn",
      from: {},
      to: { circular: true }
    }
  ],
  options: {
    doNotFollow: { path: ["node_modules", ".next", ".dart_tool", "build"] },
    tsPreCompilationDeps: true,
    tsConfig: { fileName: "apps/scertta_admin_web/tsconfig.json" }
  }
};
