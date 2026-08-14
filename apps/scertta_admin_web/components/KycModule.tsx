// KYC Frontend — Componentes React para el módulo de validación
// Arquitectura: 3 pantallas: Upload (conductor) + Bandeja (operario) + Visor (operario)

// ============================================================
// PANTALLA 1: UPLOAD DE DOCUMENTOS (CONDUCTOR)
// ============================================================

export function KycUploadScreen({ conductorId }: { conductorId: string }) {
  const documentos = [
    { id: 'dni_frente', label: 'DNI — Frente', icon: '📄', required: true },
    { id: 'dni_dorso', label: 'DNI — Dorso', icon: '📄', required: true },
    { id: 'licencia_frente', label: 'Licencia — Frente', icon: '🪪', required: true },
    { id: 'licencia_dorso', label: 'Licencia — Dorso', icon: '🪪', required: true },
    { id: 'cedula_vehiculo', label: 'Cédula del Vehículo', icon: '🚗', required: true },
    { id: 'vtv_rto', label: 'VTV / RTO vigente', icon: '🔧', required: true },
    { id: 'seguro', label: 'Seguro Obligatorio', icon: '🛡️', required: true },
  ];

  return (
    <div className="kyc-upload-container">
      <h2>📋 Verificación de Identidad</h2>
      <p className="kyc-subtitle">Subí cada documento para validar tu cuenta</p>
      
      <div className="kyc-grid">
        {documentos.map(doc => (
          <KycDocumentCard key={doc.id} documento={doc} conductorId={conductorId} />
        ))}
      </div>
      
      <KycProgressBar conductorId={conductorId} />
    </div>
  );
}

// Tarjeta individual por documento
function KycDocumentCard({ documento, conductorId }) {
  const [estado, setEstado] = useState<'pendiente'|'en_proceso'|'aprobado'|'rechazado'>('pendiente');
  const [motivoRechazo, setMotivoRechazo] = useState('');
  
  const estadoColors = {
    pendiente: 'bg-slate-100 border-slate-300',
    en_proceso: 'bg-cyan-50 border-cyan-400',
    aprobado: 'bg-emerald-50 border-emerald-500',
    rechazado: 'bg-red-50 border-red-400',
  };

  const estadoLabels = {
    pendiente: '⏳ Pendiente',
    en_proceso: '🔄 Analizando...',
    aprobado: '✅ Aprobado',
    rechazado: '❌ Rechazado',
  };

  return (
    <div className={`kyc-card ${estadoColors[estado]}`}>
      <div className="kyc-card-header">
        <span className="kyc-card-icon">{documento.icon}</span>
        <span className="kyc-card-label">{documento.label}</span>
        {documento.required && <span className="kyc-required">*</span>}
      </div>
      
      {estado === 'pendiente' && (
        <div className="kyc-upload-zone">
          <input type="file" accept="image/*,application/pdf" 
            onChange={(e) => handleUpload(e, documento.id, conductorId)} />
          <p>📸 Tomar foto o elegir archivo</p>
        </div>
      )}
      
      {estado === 'rechazado' && (
        <div className="kyc-rechazo-info">
          <p className="kyc-motivo">{motivoRechazo}</p>
          <button className="kyc-reupload-btn" onClick={() => setEstado('pendiente')}>
            🔄 Re-subir documento
          </button>
        </div>
      )}
      
      <div className="kyc-card-status">{estadoLabels[estado]}</div>
    </div>
  );
}

// Barra de progreso general
function KycProgressBar({ conductorId }) {
  const [docs, setDocs] = useState([]);
  const aprobados = docs.filter(d => d.estado === 'aprobado').length;
  const total = docs.length || 7;
  const pct = Math.round((aprobados / total) * 100);
  
  return (
    <div className="kyc-progress">
      <div className="kyc-progress-bar">
        <div className="kyc-progress-fill" style={{ width: `${pct}%` }} />
      </div>
      <span className="kyc-progress-text">{aprobados}/{total} documentos • {pct}%</span>
    </div>
  );
}

// ============================================================
// PANTALLA 2: BANDEJA DEL OPERADOR
// ============================================================

export function KycBandejaScreen() {
  const [filtro, setFiltro] = useState<'todos'|'pendientes'|'aprobados'|'rechazados'>('pendientes');
  const [documentos, setDocumentos] = useState([]);
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  
  const filtros = [
    { id: 'todos', label: 'Todos', count: '—' },
    { id: 'pendientes', label: 'Pendientes', count: '(3)', badge: 'amber' },
    { id: 'aprobados', label: 'Aprobados', count: '(12)', badge: 'emerald' },
    { id: 'rechazados', label: 'Rechazados', count: '(1)', badge: 'red' },
  ];

  return (
    <div className="kyc-bandeja">
      <div className="kyc-bandeja-header">
        <h2>📋 Validación de Documentos</h2>
        <div className="kyc-search">
          <input type="text" placeholder="🔍 Buscar por DNI o nombre..." 
            value={search} onChange={e => setSearch(e.target.value)} />
        </div>
      </div>
      
      <div className="kyc-filtros">
        {filtros.map(f => (
          <button key={f.id} className={`kyc-filtro ${filtro === f.id ? 'active' : ''}`}
            onClick={() => setFiltro(f.id)}>
            {f.label} <span className={`badge-${f.badge}`}>{f.count}</span>
          </button>
        ))}
      </div>
      
      <div className="kyc-tabla">
        {documentos.map(doc => (
          <KycBandejaRow key={doc.id} documento={doc} />
        ))}
      </div>
      
      <div className="kyc-pagination">
        <button disabled={page === 1}>← Anterior</button>
        <span>Página {page}</span>
        <button>Siguiente →</button>
      </div>
    </div>
  );
}

// Fila de la bandeja
function KycBandejaRow({ documento }) {
  const scoreColor = documento.score_ia >= 90 ? 'text-emerald-600' : 
                     documento.score_ia >= 60 ? 'text-amber-600' : 'text-red-600';
  
  return (
    <div className="kyc-row" onClick={() => abrirVisor(documento.id)}>
      <div className="kyc-row-conductor">
        <span className="kyc-row-nombre">{documento.perfiles?.nombre} {documento.perfiles?.apellido}</span>
        <span className="kyc-row-dni">DNI: {documento.perfiles?.dni}</span>
      </div>
      <div className="kyc-row-doc">
        <span>{documento.tipo_documento.replace('_',' ')}</span>
      </div>
      <div className={`kyc-row-score ${scoreColor}`}>
        {documento.score_ia ? `${documento.score_ia}%` : '—'}
      </div>
      <div className="kyc-row-estado">
        <KycEstadoBadge estado={documento.estado} />
      </div>
      <div className="kyc-row-fecha">
        {new Date(documento.fecha_subida).toLocaleDateString()}
      </div>
    </div>
  );
}

// Badge de estado
function KycEstadoBadge({ estado }: { estado: string }) {
  const config = {
    pendiente:   { emoji: '⏳', bg: 'bg-slate-100', text: 'text-slate-700' },
    en_proceso:  { emoji: '🔄', bg: 'bg-cyan-50', text: 'text-cyan-700' },
    aprobado:    { emoji: '✅', bg: 'bg-emerald-50', text: 'text-emerald-700' },
    rechazado:   { emoji: '❌', bg: 'bg-red-50', text: 'text-red-700' },
  };
  const c = config[estado as keyof typeof config] || config.pendiente;
  
  return <span className={`kyc-badge ${c.bg} ${c.text}`}>{c.emoji} {estado.replace('_',' ')}</span>;
}

// ============================================================
// PANTALLA 3: VISOR DE REVISIÓN (OPERADOR)
// ============================================================

export function KycVisorScreen({ documentoId }: { documentoId: string }) {
  const [doc, setDoc] = useState<any>(null);
  const [accion, setAccion] = useState<'aprobar'|'rechazar'|null>(null);
  const [motivo, setMotivo] = useState('');
  
  const motivosRechazo = [
    'Documento borroso o ilegible',
    'Reflejo o sombra en el documento',
    'Datos no coinciden con el registro',
    'Documento vencido',
    'Selfie no coincide con foto del DNI',
    'Documento dañado o incompleto',
    'Tipo de documento incorrecto',
    'Otro (especificar)',
  ];

  return (
    <div className="kyc-visor">
      <div className="kyc-visor-main">
        {/* Panel IZQUIERDO: Imagen del documento */}
        <div className="kyc-visor-imagen">
          <img src={doc?.archivo_url} alt="Documento" className="kyc-doc-img" />
          <div className="kyc-visor-zoom">
            <button>🔍 +</button>
            <button>🔍 −</button>
            <button>↺ Rotar</button>
          </div>
        </div>
        
        {/* Panel DERECHO: Datos y acciones */}
        <div className="kyc-visor-panel">
          <div className="kyc-panel-header">
            <h3>{doc?.perfiles?.nombre} {doc?.perfiles?.apellido}</h3>
            <p>DNI: {doc?.perfiles?.dni}</p>
            <p>{doc?.tipo_documento?.replace(/_/g, ' ')}</p>
          </div>
          
          {/* Score de IA */}
          <div className="kyc-score-card">
            <h4>🤖 Análisis de IA (Gemma 4)</h4>
            <div className="kyc-score-value">{doc?.score_ia}%</div>
            <div className="kyc-score-bar">
              <div className="kyc-score-fill" style={{width: `${doc?.score_ia}%`}} />
            </div>
            <ul className="kyc-observaciones">
              {doc?.observaciones_ia?.map((obs: string, i: number) => (
                <li key={i}>{obs}</li>
              ))}
            </ul>
          </div>
          
          {/* Acciones del operador */}
          <div className="kyc-acciones">
            {!accion ? (
              <>
                <button className="kyc-btn-aprobar" onClick={() => setAccion('aprobar')}>
                  ✅ Aprobar documento
                </button>
                <button className="kyc-btn-rechazar" onClick={() => setAccion('rechazar')}>
                  ❌ Rechazar documento
                </button>
              </>
            ) : accion === 'rechazar' ? (
              <div className="kyc-rechazo-form">
                <h4>Motivo del rechazo (obligatorio)</h4>
                <select value={motivo} onChange={e => setMotivo(e.target.value)}>
                  <option value="">Seleccionar motivo...</option>
                  {motivosRechazo.map(m => <option key={m} value={m}>{m}</option>)}
                </select>
                <textarea placeholder="Detalles adicionales para el conductor..." />
                <button className="kyc-btn-confirmar-rechazo" disabled={!motivo}
                  onClick={() => confirmarAccion('rechazar', motivo)}>
                  Confirmar rechazo
                </button>
              </div>
            ) : (
              <button className="kyc-btn-confirmar" onClick={() => confirmarAccion('aprobar')}>
                ✅ Confirmar aprobación
              </button>
            )}
          </div>
        </div>
      </div>
      
      {/* Navegación entre documentos del mismo conductor */}
      <KycDocumentTabs conductorId={doc?.conductor_id} activeDoc={documentoId} />
    </div>
  );
}
